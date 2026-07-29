import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;

import 'harvest_reps.dart' show mandatoryFor, requiredFor;

/// G-056 İKİNCİL HİPOTEZ — ucuz sınama.
///
/// G-056 ANA hükmü zaten KAPALI (yapısal): şınav ayna-duyarsız bir malzeme,
/// sol-sağ eklem farkı (5,03°) sıra-bağımlılığı deltasına (4,67°) yakın —
/// kararsızlık malzemenin özelliği, kovalanacak bir kusur değil.
///
/// İKİNCİL soru bu hükmü SORGULAR: kararsızlık gerçekten malzemenin
/// simetrisinden mi geliyor, yoksa referans havuzundaki SIĞ tekrarların
/// (V16/G-054 anlamında: FSM'i saydı ama `romTarget`'a ulaşmadı) gürültüsü
/// mü kararsızlığı üretiyor? Sığ tekrarları çıkarıp `resolveMirroring`'i
/// yeniden koşturmak bunu ayırt eder:
///   * kararsızlık DEĞİŞMEZSE (hâlâ near-tie) → yapısal hüküm DOĞRULANIR
///     (alternatif açıklama elenir, G-056 kapanışı sağlamlaşır).
///   * kararlı hale GELİRSE → G-056'nın kapanışı EKSİK; sığ-tekrar gürültüsü
///     asıl kaynakmış, yeniden açılmalı.
///
/// Ürünün gerçek `ReferenceBuilder.resolveMirroring`'ini koşturur (M-F-21/25).
void main(List<String> args) {
  final Directory dir = Directory(args.isEmpty
      ? '${Platform.environment['HOME']}/motion-harvest/gravita/landmarks'
      : args[0]);
  const String movementId = 'push_up';

  final File cfgFile = File('../../content/catalog/w1/$movementId.json');
  final MovementConfig cfg = MovementConfig.parse(cfgFile.readAsStringSync());
  final double romTargetBottomMax = ((jsonDecode(cfgFile.readAsStringSync())
              as Map<String, dynamic>)['engine']
          as Map<String, dynamic>)['romTarget']['bottomAngleMax']
      .toDouble() as double;

  stdout.writeln('hareket: ${cfg.name} · romTarget.bottomAngleMax='
      '$romTargetBottomMax° (bunun ÜSTÜNDEKİ uç açı = SIĞ tekrar, V16/G-054)\n');

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

  const JointAngleExtractor extractor = JointAngleExtractor();
  final Map<String, List<ReferenceTake>> byInstructorAll =
      <String, List<ReferenceTake>>{};
  final Map<String, List<ReferenceTake>> byInstructorDeep =
      <String, List<ReferenceTake>>{};
  int shallowCount = 0, deepCount = 0;

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
        tUs: ((fr['t'] as num) * 1000).round(),
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
        if (frames.length < 4) continue;
        final ReferenceTake take = ReferenceTake(
          id: '$channel#${(byInstructorAll[channel]?.length ?? 0) + 1}',
          frames: frames,
          source: '$channel ($src)',
        );
        byInstructorAll.putIfAbsent(channel, () => <ReferenceTake>[]).add(take);
        final bool shallow = r.extremeAngleDeg > romTargetBottomMax;
        if (shallow) {
          shallowCount++;
        } else {
          deepCount++;
          byInstructorDeep.putIfAbsent(channel, () => <ReferenceTake>[]).add(take);
        }
      }
    }
  }

  stdout.writeln('toplam tekrar: ${shallowCount + deepCount}  '
      '(derin=$deepCount · sığ=$shallowCount)\n');

  ({List<ReferenceTake> takes, List<String> instructors}) qualify(
      Map<String, List<ReferenceTake>> byInstructor) {
    final List<String> qualified = <String>[
      for (final MapEntry<String, List<ReferenceTake>> e in byInstructor.entries)
        if (e.value.length >= 3) e.key,
    ]..sort();
    return (
      takes: <ReferenceTake>[for (final String k in qualified) ...byInstructor[k]!],
      instructors: qualified,
    );
  }

  final baseline = qualify(byInstructorAll);
  final deepOnly = qualify(byInstructorDeep);

  stdout.writeln('-- BASELINE (tüm tekrarlar) --');
  stdout.writeln('  ${baseline.instructors.length} eğitmen, ${baseline.takes.length} take: '
      '${baseline.instructors.join(", ")}');
  stdout.writeln('-- DERİN-YALNIZ (sığ tekrarlar çıkarıldı) --');
  stdout.writeln('  ${deepOnly.instructors.length} eğitmen, ${deepOnly.takes.length} take: '
      '${deepOnly.instructors.join(", ")}');
  final Set<String> droppedInstructors =
      baseline.instructors.toSet().difference(deepOnly.instructors.toSet());
  if (droppedInstructors.isNotEmpty) {
    stdout.writeln('  ⚠️ filtrelemeyle M-F-38 eşiğinin (≥3 take) ALTINA düşen '
        'eğitmen(ler): ${droppedInstructors.join(", ")}');
  }

  // ⚠️ GÜNCEL DURUM (v0.8.2, M-O-25 sonrası): n>18'de artık `confident`
  // SESSİZCE true DÖNMÜYOR — `gapMeasured:false` + `confident:false` +
  // `searchDecisive:false` dürüstçe raporlanıyor (koordinatör düzeltmesi).
  // AMA bu havuzların ikisi de (91 ve 52 take) hâlâ 18 tükenmez-arama
  // sınırının ÜSTÜNDE — yani `mirrorGapMeasured`/`mirrorSearchDecisive` HER
  // İKİ sette de sabit `false` çıkacak, aralarında AYRIM YAPAMAYACAK (aşağıda
  // ölçülüp doğrulanıyor). Bu yüzden asıl ayırt edici ölçüm hâlâ
  // build_reference.dart'ın KENDİ shuffle+yeniden-kur karşılaştırması +
  // `meanLeftRightDiffDeg` — n'den bağımsız çalışıyor, ikisini de burada
  // koşuyoruz.
  ({double meanLrDiffDeg, bool orderIndependent, bool sameMirrorSet,
      double maxDeltaDeg, int contributingTakes}) measure(
      List<ReferenceTake> takes, String label) {
    const ReferenceBuilder builder = ReferenceBuilder();
    final CanonicalReference ref = builder.build(takes);

    final int k = takes.length ~/ 3;
    final List<ReferenceTake> shuffled = <ReferenceTake>[
      ...takes.sublist(k).reversed,
      ...takes.sublist(0, k).reversed,
    ];
    final CanonicalReference alt = builder.build(shuffled);
    double maxDelta = 0;
    final int n = ref.frames.length < alt.frames.length
        ? ref.frames.length
        : alt.frames.length;
    for (int f = 0; f < n; f++) {
      for (int j = 0; j < ref.frames[f].values.length; j++) {
        final double a = ref.frames[f].values[j], b = alt.frames[f].values[j];
        if (a.isNaN || b.isNaN) continue;
        final double diff = math.atan2(math.sin(b - a), math.cos(b - a));
        final double d = diff.abs() * 180 / math.pi;
        if (d > maxDelta) maxDelta = d;
      }
    }
    final bool sameMirrorSet = ref.mirroredTakeIds.toSet().length ==
            alt.mirroredTakeIds.toSet().length &&
        ref.mirroredTakeIds.toSet().containsAll(alt.mirroredTakeIds);
    final bool orderIndependent = maxDelta < 0.01;

    final List<JointSpec> specs0 = ref.frames.first.specs;
    double symSum = 0;
    int symCnt = 0;
    for (int f = 0; f < ref.frames.length; f++) {
      for (int j = 0; j < specs0.length; j++) {
        final String id = specs0[j].id;
        if (!id.startsWith('left_')) continue;
        final int kk = specs0.indexWhere(
            (JointSpec sp) => sp.id == id.replaceFirst('left_', 'right_'));
        if (kk < 0) continue;
        final double a = ref.frames[f].values[j], b = ref.frames[f].values[kk];
        if (a.isNaN || b.isNaN) continue;
        symSum += math.atan2(math.sin(a - b), math.cos(a - b)).abs() * 180 / math.pi;
        symCnt++;
      }
    }
    final double meanLr = symCnt == 0 ? double.nan : symSum / symCnt;
    stdout.writeln('$label: contributingTakes=${ref.contributingTakes} · '
        'excluded=${ref.excludedOutlierIds.length} · '
        'meanLeftRightDiffDeg=${meanLr.toStringAsFixed(2)}° · '
        'orderIndependenceMaxDeltaDeg=${maxDelta.toStringAsFixed(3)}° · '
        'orderIndependent=$orderIndependent · sameMirrorSet=$sameMirrorSet');
    stdout.writeln('$label  (v0.8.2 alanları) mirrorConfident=${ref.mirrorConfident} · '
        'mirrorGapMeasured=${ref.mirrorGapMeasured} · '
        'mirrorSearchDecisive=${ref.mirrorSearchDecisive} · '
        'takes.length=${takes.length} (18 tükenmez-arama sınırı: '
        '${takes.length <= 18 ? "İÇİNDE" : "ÜSTÜNDE — gapMeasured beklenen: false"})');
    return (
      meanLrDiffDeg: meanLr,
      orderIndependent: orderIndependent,
      sameMirrorSet: sameMirrorSet,
      maxDeltaDeg: maxDelta,
      contributingTakes: ref.contributingTakes,
    );
  }

  stdout.writeln('\n-- G-056 ölçümü (meanLeftRightDiffDeg) + M-F-48 sıra-testi --');
  final baseM = measure(baseline.takes, 'BASELINE    ');
  final deepM = measure(deepOnly.takes, 'DERİN-YALNIZ');

  stdout.writeln('\n== YORUM ==');
  stdout.writeln('BASELINE    : sol-sağ farkı ${baseM.meanLrDiffDeg.toStringAsFixed(2)}° '
      'vs sıra-deltası ${baseM.maxDeltaDeg.toStringAsFixed(2)}° '
      '(oran ${(baseM.maxDeltaDeg / baseM.meanLrDiffDeg).toStringAsFixed(2)})');
  stdout.writeln('DERİN-YALNIZ: sol-sağ farkı ${deepM.meanLrDiffDeg.toStringAsFixed(2)}° '
      'vs sıra-deltası ${deepM.maxDeltaDeg.toStringAsFixed(2)}° '
      '(oran ${(deepM.maxDeltaDeg / deepM.meanLrDiffDeg).toStringAsFixed(2)})');
  final bool bothNearTie = (baseM.maxDeltaDeg / baseM.meanLrDiffDeg) > 0.5 &&
      (deepM.maxDeltaDeg / deepM.meanLrDiffDeg) > 0.5;
  if (bothNearTie) {
    stdout.writeln('\nSıra-deltası İKİ sette de sol-sağ farkının YARISINDAN '
        'fazlası — sığ tekrarları çıkarmak "yakın-beraberlik" desenini '
        'GİDERMİYOR. G-056 yapısal hükmü (kararsızlık malzemenin özelliği) '
        'İKİNCİL hipotezle de TUTARLI: sığ-tekrar gürültüsü ana kaynak '
        'DEĞİLMİŞ gibi görünüyor.');
  } else {
    stdout.writeln('\n⚠️ Sıra-deltası/sol-sağ-farkı oranı derin-yalnız sette '
        'ANLAMLI ölçüde düştü — sığ-tekrar gürültüsü kararsızlığa katkıda '
        'bulunuyor olabilir; G-056 kapanışı yeniden gözden geçirilmeli.');
  }
}
