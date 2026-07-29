import 'dart:convert';
import 'dart:io';

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;

import 'harvest_reps.dart' show mandatoryFor, requiredFor;

/// Hasat → REFERANS: eğitmen konsensüsü + varyans-türetimli tolerans (G-014).
///
/// Zincirin son halkası. Üç kapı sırayla geçilmeden referans üretilmez ve
/// üçü FARKLI şeyleri sorar — biri diğerinin yerine geçmez:
///
///  1. **Kimlik** (`engine.precondition`, G-043): bu kare bu hareketin mi?
///  2. **M-F-38 yeterlilik**: ≥3 EĞİTMEN × ≥3 temiz tekrar. Sayım birimi
///     eğitmendir, video değil (M-F-32) — aynı eğitmenin videoları HAVUZLANIR.
///  3. **M-F-47 anlaşma** (çekirdekte): kaynak tepe değerleri skorlama tabanı
///     içinde kümelenmeli. Sayı kapısı tek başına 23° ile 112°'nin ikisinin de
///     "içeride" olduğunu göremez.
///
/// ⚠️ **J-034 — MUTLAK TARAF ADI KULLANILMAZ.** Global ayna-ataması bir take'i
/// çevirdiğinde `left_elbow` adı aynı kalır ama işaret ettiği FİZİKSEL eklem
/// değişir. Çıktı bu yüzden `lead_*`/`off_*` soyutlamasıyla yazılır: ad, o
/// referansta hangi tarafın önde olduğuna göre çözülür.
void main(List<String> args) async {
  final Directory dir = Directory(args.isEmpty
      ? '${Platform.environment['HOME']}/motion-harvest/gravita/landmarks'
      : args[0]);
  final String movementId = args.length > 1 ? args[1] : 'push_up';

  final File cfgFile = <File>[
    File('../../content/catalog/w1/$movementId.json'),
    File('../../content/catalog/w2/$movementId.json'),
  ].firstWhere((File f) => f.existsSync(),
      orElse: () => throw StateError('config yok: $movementId'));
  final MovementConfig cfg = MovementConfig.parse(cfgFile.readAsStringSync());

  if (!cfg.preconditionDerived) {
    stderr.writeln('DURDU: ${cfg.id} kimlik ön koşulu türetilmemiş (G-043).');
    exit(65);
  }

  const JointAngleExtractor extractor = JointAngleExtractor();
  final Set<int> mandatory = mandatoryFor(cfg).toSet();
  final List<int> all = requiredFor(cfg);
  bool judge(PoseFrame f) {
    int ok = 0;
    for (final int i in all) {
      final PoseLandmark l = f.landmarks[i];
      final bool good =
          l.x >= 0 && l.x <= 1 && l.y >= 0 && l.y <= 1 && l.visibility >= 0.5;
      if (!good && mandatory.contains(i)) return false;
      if (good) ok++;
    }
    return ok >= all.length - 2;
  }

  /// EĞİTMEN başına take'ler — video başına DEĞİL (M-F-32 / G-049).
  final Map<String, List<ReferenceTake>> byInstructor =
      <String, List<ReferenceTake>>{};
  final Map<String, Set<String>> videosOf = <String, Set<String>>{};

  for (final File f in dir
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.json'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path))) {
    final Map<String, dynamic> fx =
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final Map<String, dynamic> meta = fx['recordingMeta'] as Map<String, dynamic>;
    final Map<String, dynamic> prov =
        (fx['provenance'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final String channel = (prov['channel'] as String?) ?? '?';
    final String src = f.uri.pathSegments.last.replaceAll('.full.json', '');
    final List<String> wh =
        ((meta['resolution'] as String?) ?? '1920x1080').split('x');
    final FrameSize size = FrameSize(int.parse(wh[0]), int.parse(wh[1]));
    final PoseNormalizer normalizer = PoseNormalizer();

    const int maxGapUs = 2000000;
    final List<List<PoseFrame>> windows = <List<PoseFrame>>[];
    List<PoseFrame> cur = <PoseFrame>[];
    int lastUs = -1 << 40;
    for (final dynamic raw in fx['frames'] as List<dynamic>) {
      final Map<String, dynamic> fr = raw as Map<String, dynamic>;
      if (fr['detected'] != true) continue;
      final List<dynamic> lm = fr['lm'] as List<dynamic>;
      if (lm.length != Lm.count) continue;
      final PoseFrame pf = PoseFrame(
        tUs: ((fr['t'] as num) * 1000).round(), // `t` MİLİSANİYE (G-040)
        landmarks: lm
            .map((dynamic p) => PoseLandmark(
                  ((p as List<dynamic>)[0] as num).toDouble(),
                  (p[1] as num).toDouble(),
                  (p[2] as num).toDouble(),
                  (p[3] as num).toDouble(),
                ))
            .toList(),
      );
      if (!judge(pf)) continue;
      if (pf.tUs - lastUs > maxGapUs && cur.isNotEmpty) {
        windows.add(cur);
        cur = <PoseFrame>[];
      }
      cur.add(pf);
      lastUs = pf.tUs;
    }
    if (cur.isNotEmpty) windows.add(cur);

    for (final List<PoseFrame> w in windows) {
      final RepEngine e = RepEngine(cfg, judge: judge);
      final List<({int tUs, JointAngleVector v})> trace =
          <({int tUs, JointAngleVector v})>[];
      for (final PoseFrame pf in w) {
        e.addFrame(pf, size);
        final PoseFrame iso = pf.toIsotropic(size);
        if (!StructuralValidator().check(iso).plausible) continue;
        trace.add((tUs: pf.tUs, v: extractor.extract(normalizer.normalize(iso))));
      }
      for (final Rep r in e.reps) {
        final List<JointAngleVector> frames = trace
            .where((({int tUs, JointAngleVector v}) t) =>
                t.tUs >= r.startUs && t.tUs <= r.endUs)
            .map((({int tUs, JointAngleVector v}) t) => t.v)
            .toList(growable: false);
        if (frames.length < 4) continue; // çerçeve yoksa hizalanacak şey yok
        final List<ReferenceTake> lst =
            byInstructor.putIfAbsent(channel, () => <ReferenceTake>[]);
        lst.add(ReferenceTake(
          id: '$channel#${lst.length + 1}',
          frames: frames,
          source: '$channel ($src)',
        ));
        videosOf.putIfAbsent(channel, () => <String>{}).add(src);
      }
    }
  }

  stdout.writeln('hareket: ${cfg.name}');
  stdout.writeln('${'eğitmen'.padRight(26)}${'video'.padLeft(7)}${'tekrar'.padLeft(8)}');
  final List<String> qualified = <String>[];
  for (final MapEntry<String, List<ReferenceTake>> e in byInstructor.entries) {
    stdout.writeln('${e.key.padRight(26).substring(0, 26)}'
        '${videosOf[e.key]!.length.toString().padLeft(7)}'
        '${e.value.length.toString().padLeft(8)}');
    if (e.value.length >= 3) qualified.add(e.key);
  }

  // ---- KAPI 2: M-F-38 yeterlilik (EĞİTMEN birimi) -------------------------
  // Çekirdeğin `minTakes`'i TEKRAR sayar; M-F-38 EĞİTMEN sayar. İkisi farklı
  // sorulardır ve biri diğerini karşılamaz: tek eğitmenin 12 tekrarı
  // `minTakes: 3`i geçer ama eğitmenler-arası varyans hakkında hiçbir şey
  // söylemez — tolerans tam olarak o varyanstan türetilir.
  stdout.writeln('\n≥3 temiz tekrar veren eğitmen: ${qualified.length} '
      '(${qualified.join(", ")})');
  if (qualified.length < 3) {
    stdout.writeln('→ M-F-38 KAPALI: referans ÜRETİLMEDİ, '
        'eşikler muhafazakâr + provisional kalır.');
    exit(0);
  }

  final List<ReferenceTake> takes = <ReferenceTake>[
    for (final String k in qualified) ...byInstructor[k]!,
  ];
  stdout.writeln('→ M-F-38 AÇIK: ${takes.length} take, '
      '${qualified.length} eğitmen\n');

  CanonicalReference? ref;
  try {
    ref = const ReferenceBuilder().build(takes);
  } on ReferenceAgreementError catch (e) {
    stdout.writeln('→ M-F-47 ANLAŞMA KAPISI KAPALI: $e');
    stdout.writeln('  Aykırı kaynak ORTALANMAZ; provenance ile raporlanır.');
    exit(0);
  }

  // ---- M-F-48: sıra bağımsızlığı -----------------------------------------
  // Global atama açgözlü-sıralı uzlaşmanın tohum bağımlılığını kaldırdı ama
  // "kaldırıldı" bir iddiadır; BU veride ölçülmeden kabul edilmez.
  final List<ReferenceTake> shuffled = takes.reversed.toList()
    ..insert(0, takes[takes.length ~/ 2]);
  final CanonicalReference alt = const ReferenceBuilder().build(shuffled);
  double maxDelta = 0;
  final int n = ref.frames.length < alt.frames.length
      ? ref.frames.length
      : alt.frames.length;
  for (int f = 0; f < n; f++) {
    for (int j = 0; j < ref.frames[f].values.length; j++) {
      final double a = ref.frames[f].values[j], b = alt.frames[f].values[j];
      if (a.isNaN || b.isNaN) continue;
      final double d = (a - b).abs() * 180 / 3.14159265358979;
      if (d > maxDelta) maxDelta = d;
    }
  }
  stdout.writeln('M-F-48 sıra doğrulaması: en büyük kare-eklem farkı '
      '${maxDelta.toStringAsFixed(2)}° · ayna kararlı: '
      '${ref.mirroredTakeIds.length == alt.mirroredTakeIds.length}');

  // ---- Çıktı: J-034 gereği lead/off, MUTLAK taraf adı YOK ----------------
  final List<JointSpec> specs = ref.frames.first.specs;
  final Map<String, dynamic> out = <String, dynamic>{
    'movement': movementId,
    'rule': 'M-F-38 + M-F-47; tolerans EĞİTMENLER-ARASI varyanstan türetilir',
    'instructors': qualified,
    'takes': ref.contributingTakes,
    'excludedOutlierIds': ref.excludedOutlierIds,
    'mirrorConfident': ref.mirrorConfident,
    'priorDisagreements': ref.priorDisagreements,
    'orderIndependenceMaxDeltaDeg': double.parse(maxDelta.toStringAsFixed(2)),
    r'$sideNaming': 'J-034: global ayna-ataması `left_*` adının işaret ettiği '
        'FİZİKSEL eklemi değiştirebilir. Toleranslar bu yüzden eklem-ÇİFTİ '
        'olarak yazılır; skorlayıcı tarafı kare başına görünen-taraf '
        'çözümüyle bağlar, ada göre DEĞİL.',
    'unreliableJoints': ref.unreliableJoints(),
    'tolerances': <String, dynamic>{},
  };
  final Set<String> pairs = <String>{
    for (final JointSpec s in specs)
      s.id.replaceFirst('left_', '').replaceFirst('right_', ''),
  };
  for (final String pair in pairs) {
    double free = 0;
    int cnt = 0;
    for (int j = 0; j < specs.length; j++) {
      if (!specs[j].id.endsWith(pair)) continue;
      for (int f = 0; f < ref.frames.length; f++) {
        final Tolerance t = ref.toleranceAt(f, j);
        // `Tolerance.free` RADYANDIR (degrees ctor dönüştürür) — derece sanmak
        // toleransı 57x küçültürdü.
        free += t.free * radToDeg;
        cnt++;
      }
    }
    if (cnt > 0) {
      (out['tolerances'] as Map<String, dynamic>)[pair] = <String, dynamic>{
        'meanFreeDeg': double.parse((free / cnt).toStringAsFixed(1)),
      };
    }
  }
  File('../../content/harvest/reference.$movementId.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(out)}\n');
  stdout.writeln('referans yazıldı: content/harvest/reference.$movementId.json');
}
