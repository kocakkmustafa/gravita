import 'dart:convert';
import 'dart:math' as math;
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
/// M-F-55(2) — DIŞLANANI ÖLÇ: aykırı take neden aykırı?
///
/// Anlaşma kapısı bir take'i eler ama NEDEN elediğini söylemez ve iki neden
/// taban tabana zıttır:
///
///  * **Kurulum/farklı hareket:** sapma BİRÇOK ekleme yayılmış. Take başka bir
///    şey yapıyor (G-043 sınıfı) — tolerans hakkında bilgi TAŞIMAZ, dışarıda
///    kalır. Toleransta fail-open, fail-closed'dan kötü sessiz-yanlıştır.
///  * **Stil:** sapma AZ eklemde yoğunlaşmış ve take BOYUNCA kararlı. Eğitmen
///    aynı hareketi kendi imzasıyla yapıyor — toleransın ölçmek İSTEDİĞİ şey,
///    ama otomatik katılmaz (eklem-yetkisi app-side, M-F-51): `styleSpreadDeg`
///    olarak DANIŞMA amaçlı yayınlanır.
({String kind, List<String> joints, double maxDevDeg, double stabilityDeg})
    classifyOutlier(
  List<JointAngleVector> refFrames,
  List<JointAngleVector> takeFrames,
  double toleranceDeg,
) {
  const Dtw dtw = Dtw();
  const AngularSimilarity sim = AngularSimilarity();
  final DtwResult r = dtw.align(refFrames.length, takeFrames.length,
      (int i, int j) => sim.distance(refFrames[i], takeFrames[j]));
  final List<JointSpec> specs = refFrames.first.specs;
  final List<String> offending = <String>[];
  double maxDev = 0, stabilityOfWorst = double.nan;

  for (int j = 0; j < specs.length; j++) {
    final List<double> devs = <double>[];
    for (int f = 0; f < refFrames.length; f++) {
      final double a = refFrames[f].values[j];
      final double b = takeFrames[r.refToLearner[f]].values[j];
      if (a.isNaN || b.isNaN) continue;
      // Dairesel fark (G-051): doğrusal çıkarma 179°/-179°'yi 358° sanar.
      devs.add(math.atan2(math.sin(b - a), math.cos(b - a)) * 180 / math.pi);
    }
    if (devs.isEmpty) continue;
    final double mean = devs.reduce((double x, double y) => x + y) / devs.length;
    if (mean.abs() <= toleranceDeg) continue;
    offending.add(specs[j].id);
    if (mean.abs() > maxDev) {
      maxDev = mean.abs();
      // Take İÇİ kararlılık: sapma sabit bir ofset mi (stil), yoksa
      // savruluyor mu (gürültü/başka hareket)?
      double v = 0;
      for (final double d in devs) {
        v += (d - mean) * (d - mean);
      }
      stabilityOfWorst = math.sqrt(v / devs.length);
    }
  }

  // BİRİNCİL EKSEN KARARLILIK, eklem sayısı değil.
  //
  // Gerekçe hem teorik hem ölçülmüş. Teorik: take BOYUNCA kararlı bir sapma
  // SİSTEMATİK bir farktır (duruş/kurulum/stil); savrulan bir sapma aynı
  // hareketin yapılmadığını söyler — kaç eklemde olduğu ikincildir.
  // Ölçülmüş: bu veride take-içi kararlılık BİMODAL — 5,4/6,2/8,2° kümesi ile
  // 27/30/38/40/52/67° kümesi arasında temiz bir boşluk var.
  //
  // Kararlı olanlar arasında eklem sayısı stili kurulumdan ayırır: birkaç
  // eklemde yoğunlaşmış = imza; gövdeye yayılmış = kamera açısı/kurulum.
  final bool stable =
      !stabilityOfWorst.isNaN && stabilityOfWorst <= toleranceDeg;
  final String kind = !stable
      ? 'setup' // savruluyor: aynı hareket değil, tolerans bilgisi taşımaz
      : (offending.length <= specs.length / 3 ? 'style' : 'setup');
  return (
    kind: kind,
    joints: offending,
    maxDevDeg: maxDev,
    stabilityDeg: stabilityOfWorst
  );
}

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

  // ---- KAPI 2b: M-F-47 SONRASI eğitmen sayımı (kendi minSources'umuz) ----
  // Anlaşma kapısı take eler; bir eğitmenin TÜM take'leri elenirse take sayısı
  // hâlâ yeterli görünür ama eğitmenler-arası varyans — toleransın TEK kaynağı —
  // artık daha az eğitmenden gelir. Çekirdek `minTakes` bunu göremez (M-F-53/2,
  // 0.5.1'de `minSources` geliyor); o gelene kadar burada fail-closed.
  final Set<String> survivingInstructors = <String>{
    for (final String src in ref.sources) src.split(' (').first,
  };
  if (survivingInstructors.length < 3) {
    stdout.writeln('→ M-F-47 SONRASI yalnız ${survivingInstructors.length} '
        'eğitmen kaldı (${survivingInstructors.join(", ")}) — referans '
        'ÜRETİLMEDİ. Take sayısı yeterli görünse de tolerans daha az '
        'eğitmenin varyansından türerdi.');
    exit(0);
  }

  // ---- M-F-48: sıra bağımsızlığı -----------------------------------------
  // Global atama açgözlü-sıralı uzlaşmanın tohum bağımlılığını kaldırdı ama
  // "kaldırıldı" bir iddiadır; BU veride ölçülmeden kabul edilmez.
  // ⚠️ GERÇEK PERMÜTASYON olmalı: ilk denememde `..insert(0, takes[n~/2])`
  // yazmıştım — bu bir eleman EKLER, 59 take'i 60 yapıp birini iki kez sayar.
  // Farklı bir çoklu-küme konsensüsü ve medoid'i haklı olarak kaydırır; ölçtüğü
  // şey sıra bağımlılığı DEĞİLDİR. Doğrulayıcının kendisi doğrulanmalı.
  final int k = takes.length ~/ 3;
  final List<ReferenceTake> shuffled = <ReferenceTake>[
    ...takes.sublist(k).reversed,
    ...takes.sublist(0, k).reversed,
  ];
  assert(shuffled.length == takes.length &&
      shuffled.map((ReferenceTake t) => t.id).toSet().length ==
          takes.map((ReferenceTake t) => t.id).toSet().length);
  final CanonicalReference alt = const ReferenceBuilder().build(shuffled);
  double maxDelta = 0;
  final int n = ref.frames.length < alt.frames.length
      ? ref.frames.length
      : alt.frames.length;
  for (int f = 0; f < n; f++) {
    for (int j = 0; j < ref.frames[f].values.length; j++) {
      final double a = ref.frames[f].values[j], b = alt.frames[f].values[j];
      if (a.isNaN || b.isNaN) continue;
      // ⚠️ AÇI FARKI DAİRESELDİR. `(a-b).abs()` +179,9° ile −179,9°'yi 359,8°
      // uzak sanar; oysa dairede 0,2°. İlk koşumda tam bu yüzden 359,69°
      // "fark" raporlandı — sıra bağımlılığı DEĞİL, benim aritmetiğim.
      // Çekirdeğin `circularStats` doc'u aynı tuzağı anlatıyor: 179° ile
      // −179°'nin ortalaması kimsenin girmediği bir poz olan 0°'dir.
      final double diff = math.atan2(math.sin(a - b), math.cos(a - b));
      final double d = diff.abs() * 180 / math.pi;
      if (d > maxDelta) maxDelta = d;
    }
  }
  // Ayna KÜMESİ değişip referans DEĞİŞMİYORSA bu belirsizlik değil,
  // DEJENERASYON: her şeyi birden çevirmek aynı konsensüsü verir (çekirdek
  // `MirrorResolution.confident` doc'u bu ayrımı açıkça istiyor). Farklı küme +
  // farklı referans ise gerçek kararsızlıktır ve M-F-46 kural 7 devreye girer.
  final bool sameMirrorSet = ref.mirroredTakeIds.toSet().length ==
          alt.mirroredTakeIds.toSet().length &&
      ref.mirroredTakeIds.toSet().containsAll(alt.mirroredTakeIds);
  final bool orderIndependent = maxDelta < 0.01;
  final String mirrorNote = sameMirrorSet
      ? 'ayna ataması AYNI'
      : (orderIndependent
          ? 'ayna kümesi farklı ama referans BİREBİR AYNI → dejenerasyon '
              '(global çevirme), kararsızlık DEĞİL'
          : 'ayna kümesi farklı VE referans değişiyor → GERÇEK kararsızlık, '
              'M-F-46 kural 7: taraf-bağımlı hüküm verilmez');
  stdout.writeln('M-F-48 sıra doğrulaması: en büyük kare-eklem farkı '
      '${maxDelta.toStringAsFixed(2)}° (dairesel) · $mirrorNote');
  stdout.writeln('M-F-47: ${ref.excludedOutlierIds.length} aykırı kaynak '
      'dışlandı · çekirdek ayna güveni: ${ref.mirrorConfident}');

  // ---- M-F-55(2): DIŞLANANI SINIFLANDIR ---------------------------------
  // %34 dışlama M-F-52 sağlık eşiğini tetikliyor; "çok eledi" tek başına iyi
  // ya da kötü değildir — NEYİ elediği belirler.
  final Map<String, ReferenceTake> byId = <String, ReferenceTake>{
    for (final ReferenceTake t in const ReferenceBuilder()
        .resolveMirroring(takes)
        .takes)
      t.id: t,
  };
  final Map<String, List<String>> styleJoints = <String, List<String>>{};
  final List<Map<String, dynamic>> outlierProfile = <Map<String, dynamic>>[];
  final Map<String, int> kindCount = <String, int>{};
  for (final String id in ref.excludedOutlierIds) {
    final ReferenceTake? t = byId[id];
    if (t == null) continue;
    final ({String kind, List<String> joints, double maxDevDeg,
            double stabilityDeg}) c =
        classifyOutlier(ref.frames, t.frames, 14);
    kindCount[c.kind] = (kindCount[c.kind] ?? 0) + 1;
    if (c.kind == 'style') {
      for (final String j in c.joints) {
        styleJoints.putIfAbsent(j, () => <String>[]).add(id);
      }
    }
    outlierProfile.add(<String, dynamic>{
      'id': id,
      'kind': c.kind,
      'joints': c.joints,
      'maxDevDeg': double.parse(c.maxDevDeg.toStringAsFixed(1)),
      'withinTakeStabilityDeg':
          c.stabilityDeg.isNaN ? null : double.parse(c.stabilityDeg.toStringAsFixed(1)),
    });
  }
  stdout.writeln('M-F-55 dışlama profili: $kindCount'
      '  (stil adayı eklemler: ${styleJoints.keys.join(", ")})');

  // ---- G-050 SINAMASI: taban-bağlılığı KAPININ eseri mi? ----------------
  // İddia şuydu: M-F-47 >14° sapanları elediği için kalanların dağılımı kapıyla
  // üstten sınırlı, dolayısıyla tolerans yapay dar. Sınaması basit — kapıyı
  // GENİŞLET ve dağılımın açılıp açılmadığına bak. Açılmıyorsa darlık kapının
  // eseri DEĞİL, eğitmenler gerçekten o kadar benziyor.
  final Map<String, dynamic> widened = <String, dynamic>{};
  try {
    final CanonicalReference wide =
        const ReferenceBuilder().build(takes, clusterToleranceDeg: 30);
    double sum = 0;
    int cnt = 0;
    for (int f = 0; f < wide.dispersion.length; f++) {
      for (final double sd in wide.dispersion[f]) {
        if (sd.isNaN) continue;
        sum += sd * radToDeg;
        cnt++;
      }
    }
    double sumN = 0;
    int cntN = 0;
    for (int f = 0; f < ref.dispersion.length; f++) {
      for (final double sd in ref.dispersion[f]) {
        if (sd.isNaN) continue;
        sumN += sd * radToDeg;
        cntN++;
      }
    }
    widened
      ..['clusterToleranceDeg'] = 30
      ..['takes'] = wide.contributingTakes
      ..['excluded'] = wide.excludedOutlierIds.length
      ..['meanDispersionDeg'] =
          double.parse((sum / cnt).toStringAsFixed(2))
      ..['baselineMeanDispersionDeg'] =
          double.parse((sumN / cntN).toStringAsFixed(2));
    stdout.writeln('G-050 sınaması — kapı 14° → 30°: '
        'take ${ref.contributingTakes}→${wide.contributingTakes} · '
        'ortalama dağılım ${(sumN / cntN).toStringAsFixed(2)}°→'
        '${(sum / cnt).toStringAsFixed(2)}°');
  } on ReferenceAgreementError catch (_) {
    widened['error'] = 'geniş kapıda da kümelenme yok';
  }

  // ---- Çıktı: J-034 gereği lead/off, MUTLAK taraf adı YOK ----------------
  final List<JointSpec> specs = ref.frames.first.specs;
  final Map<String, dynamic> out = <String, dynamic>{
    'movement': movementId,
    'rule': 'M-F-38 + M-F-47; tolerans EĞİTMENLER-ARASI varyanstan türetilir',
    r'$gateInteractionCaveat': 'G-050: M-F-47 konsensüsten >14° sapan take\'leri '
        'ELER, tolerans ise KALANLARIN varyansından türer — kalanlar tanım '
        'gereği ≤14° içinde olduğu için ölçülen dağılım KAPININ KENDİSİYLE '
        'üstten sınırlıdır. Yani sayı "eğitmenler ne kadar ayrışıyor"u değil, '
        '"kapıdan geçenler ne kadar benziyor"u ölçer. `source` alanı her eklemde '
        'değerin tabandan mı ölçümden mi geldiğini söyler; taban bağlıyorken '
        'tolerans VARYANS-TÜRETİMLİ SAYILMAZ.',
    'instructors': qualified,
    'takes': ref.contributingTakes,
    'excludedOutlierIds': ref.excludedOutlierIds,
    'outlierProfile': outlierProfile,
    'outlierKindCount': kindCount,
    r'$outlierProfileNote': 'M-F-55(2): dışlanan take NEDEN dışlandı? '
        'setup = sapma birçok ekleme yayılmış (farklı hareket/kurulum, '
        'tolerans bilgisi TAŞIMAZ) · style = az eklemde yoğunlaşmış + take '
        'içinde kararlı ofset (toleransın ölçmek İSTEDİĞİ şey, ama otomatik '
        'KATILMAZ — eklem-yetkisi app-side, M-F-51).',
    'styleExcluded': <String, dynamic>{
      for (final MapEntry<String, List<String>> e in styleJoints.entries)
        e.key: e.value,
    },
    'mirrorConfident': ref.mirrorConfident,
    'priorDisagreements': ref.priorDisagreements,
    'orderIndependenceMaxDeltaDeg': double.parse(maxDelta.toStringAsFixed(3)),
    'orderIndependent': orderIndependent,
    'mirrorSetStableAcrossOrder': sameMirrorSet,
    r'$mirrorNote': mirrorNote,
    r'$sideNaming': 'J-034: global ayna-ataması `left_*` adının işaret ettiği '
        'FİZİKSEL eklemi değiştirebilir. Toleranslar bu yüzden eklem-ÇİFTİ '
        'olarak yazılır; skorlayıcı tarafı kare başına görünen-taraf '
        'çözümüyle bağlar, ada göre DEĞİL.',
    'unreliableJoints': ref.unreliableJoints(),
    'g050WidenedGateProbe': widened,
    'tolerances': <String, dynamic>{},
  };
  final Set<String> pairs = <String>{
    for (final JointSpec s in specs)
      s.id.replaceFirst('left_', '').replaceFirst('right_', ''),
  };
  for (final String pair in pairs) {
    double free = 0, rawSd = 0;
    int cnt = 0;
    for (int j = 0; j < specs.length; j++) {
      if (!specs[j].id.endsWith(pair)) continue;
      for (int f = 0; f < ref.frames.length; f++) {
        final Tolerance t = ref.toleranceAt(f, j);
        // `Tolerance.free` RADYANDIR (degrees ctor dönüştürür) — derece sanmak
        // toleransı 57x küçültürdü.
        free += t.free * radToDeg;
        final double sd = ref.dispersion[f][j];
        if (!sd.isNaN) rawSd += sd * radToDeg;
        cnt++;
      }
    }
    if (cnt > 0) {
      // ⚠️ `toleranceAt` ölçülen dağılımı `freeFloorDeg` (8°) ile TABANLAR.
      // Yalnız sonucu yazmak, "8,2° tolerans ÖLÇTÜK" izlenimi verir; oysa
      // ölçülen dağılım tabanın altındaysa sayı ölçümden değil TABANDAN gelir.
      // Ham ortalama yanında durur ki hangisinin bağladığı görünsün.
      final double rawMean = rawSd / cnt;
      (out['tolerances'] as Map<String, dynamic>)[pair] = <String, dynamic>{
        'meanFreeDeg': double.parse((free / cnt).toStringAsFixed(1)),
        'measuredDispersionDeg': double.parse(rawMean.toStringAsFixed(1)),
        'floorBinding': rawMean < 8.0,
        // Sayının NEREDEN geldiği etiketlenir. "Varyans-türetimli tolerans"
        // demek, taban bağlıyorken YANLIŞ bir iddiadır (G-050).
        'source': rawMean < 8.0 ? 'floor' : 'variance',
      };
    }
  }
  File('../../content/harvest/reference.$movementId.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(out)}\n');
  stdout.writeln('referans yazıldı: content/harvest/reference.$movementId.json');
}
