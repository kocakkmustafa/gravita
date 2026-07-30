import 'dart:convert';
import 'dart:io';

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;

import 'harvest_reps.dart' show mandatoryFor, requiredFor;

/// FALLBACK CANLILIK SONDASI — aile reçetesi M-F-184/1'in Gravita bacağı.
///
/// Reçete: *"Bir fallback sınıfının VAR olması, tanımadığı girdinin ORAYA
/// DÜŞTÜĞÜ anlamına gelmez… ölçülmedikçe dekoratiftir."*
/// (`ventures/motion-core/workspace/FALLBACK-CANLILIK-RECETESI.md`)
///
/// ## Adım 1 — Gravita'nın sözlüğü ve fallback'i, İSİMLE
///
/// ⚠️ **Gravita'da "unclassified movement" sınıfı YOK ve olmaması bir kusur
/// değil, mimari bir olgu:** ürün *"bu hangi hareket?"* diye SORMUYOR —
/// kullanıcı dersi seçer, motor o hareketin config'iyle koşar. Dolayısıyla
/// sözlük-dışı girdinin düşecek iki yeri var:
///
///  * `refusalReason` — kimlik ön koşulu `derived` değilse motor HİÇ saymaz
///    (M-F-122). Bugün üretimde tek canlı hareket `push_up` ve onun ön koşulu
///    `derived`, yani bu yol **üretimde ERİŞİLEMEZ** (K8 zaten `live` +
///    `pending` birleşimini yasaklıyor). Beyan doğru, ama bugünkü ürün için
///    ölçülecek bir tetiklenme YOK — ve bunu "canlı" diye yazmamak gerekiyor.
///  * **Kimlik kapısı → `skippedFrames`** — asıl fallback yolu bu. `push_up`
///    config'i `torso_angle_from_vertical >= 60` şartını taşıyor (G-043);
///    şart sağlanmayan kare hüküm yoluna GİRMEZ, `skippedFrames`e yazılır.
///
/// ## Adım 2 — sözlük-dışı GERÇEK girdi (sentetik DEĞİL)
///
/// **27 gerçek squat tutorial'ının tam-video landmark'ı, `push_up` config'iyle
/// koşulur.** Squat, `push_up` sözlüğünün dışındadır (gövde DİKEY, yatay değil)
/// ama gerçek bir kayıttır: güven, görünürlük ve faz kapılarını gerçek bir
/// kullanıcı kaydı gibi zorlar. Reçetenin şartı buydu — sentetik girdi
/// fallback'e girer, çünkü onu girecek şekilde kurarsın.
///
/// ## POZİTİF KONTROL (M-F-194 ikiz kuralı)
///
/// Aynı hat, **27 gerçek push_up tutorial'ıyla** da koşulur. Bu olmadan
/// "squat'ta 0 tekrar" hiçbir şey kanıtlamaz: koşum düzeneği bozuk olsa da 0
/// çıkardı. İkiz, düzeneğin tekrar SAYABİLDİĞİNİ gösteriyor.
///
/// Çıktı: `content/harvest/fallback-liveness.json`
void main(List<String> args) {
  final String home = Platform.environment['HOME']!;
  final Directory oov = Directory(
      args.isNotEmpty ? args[0] : '$home/motion-harvest/gravita-squat/landmarks');
  final Directory control = Directory(
      args.length > 1 ? args[1] : '$home/motion-harvest/gravita/landmarks');

  final MovementConfig cfg = MovementConfig.parse(
      File('../../content/catalog/w1/push_up.json').readAsStringSync());

  // Adım 1'in beyanı ÖLÇÜLÜR, varsayılmaz: ön koşul durumu ve kapı şartı
  // rapora yazılır ki "fallback yolu neydi" sorusu kayıtta kalsın.
  final Map<String, dynamic> vocabulary = <String, dynamic>{
    'movement': cfg.id,
    'preconditionStatus': cfg.preconditionStatus,
    'preconditionDerived': cfg.preconditionDerived,
    r'$refusalReachableInProduction': cfg.preconditionDerived
        ? 'NO — precondition is derived, so refusalReason cannot fire for the '
            'only live movement. Declared, not reachable today.'
        : 'YES',
    r'$fallbackPath':
        'identity gate (movementConfig.precondition) → skippedFrames',
  };

  final Map<String, dynamic> report = <String, dynamic>{
    r'$recipe': 'FALLBACK-CANLILIK-RECETESI.md (M-F-184/1) adım 1-4',
    'vocabulary': vocabulary,
    'outOfVocabulary': _run(oov, cfg, 'squat footage → push_up config'),
    'positiveControl': _run(control, cfg, 'push_up footage → push_up config'),
  };

  // Adım 3 — ÜÇ sayacı BİRLİKTE oku ve teşhisi ADIYLA yaz.
  final Map<String, dynamic> o = report['outOfVocabulary'] as Map<String, dynamic>;
  final Map<String, dynamic> c = report['positiveControl'] as Map<String, dynamic>;
  final int oovReps = o['reps'] as int;
  final int oovSkipped = o['skippedFrames'] as int;
  final int oovJudged = o['judgedFrames'] as int;
  final int ctrlReps = c['reps'] as int;

  final int oovFiles = o['files'] as int;
  final int oovFilesWithReps = o['filesWithReps'] as int;
  final int oovGapReps = o['repsWithIdentityGap'] as int;

  final String diagnosis;
  if (ctrlReps == 0) {
    // İkiz ÖNCE okunur: düzenek saymıyorsa sözlük-dışı sonuç yorumlanamaz.
    diagnosis = 'INVALID — positive control counted 0 reps: the harness itself '
        'does not count. The out-of-vocabulary number means nothing.';
  } else if (oovReps == 0 && (oovSkipped > 0 || oovJudged == 0)) {
    diagnosis = 'GATE HOLDS — 0 reps from out-of-vocabulary footage and the '
        'frames were accounted for. Refusal, not silence.';
  } else if (oovReps == 0) {
    diagnosis = 'B: INVISIBILITY — 0 reps AND no rejection accounted for.';
  } else if (oovFilesWithReps * 3 <= oovFiles) {
    // ⚠️ İlk yazdığım hâl burada doğrudan "A: MISCLASSIFICATION" diyordu ve
    // FAZLA İDDİAYDI. Reçete §4: *"X videosu" ≠ "X olayı"* — bir squat/kalça
    // videosunun İÇİNDE gerçekten yatay-gövde bölümü olabilir. Sistematik
    // yanlış-sınıflama, tekrarların BÜTÜN dosyalara yayılmasını gerektirir;
    // YOĞUNLAŞMA (dosyaların ≤1/3'ü) bunun aksini söyler. Olay-başı ground
    // truth olmadan doğru cevap "A" değil "ATFEDİLEMEDİ"dir.
    diagnosis = 'INDETERMINATE (not A) — $oovReps reps from only '
        '$oovFilesWithReps of $oovFiles files: concentrated, not systematic. '
        'Per-event ground truth is absent, so these reps are UNATTRIBUTED — '
        'the distribution argues they are real horizontal-torso segments '
        'inside those videos rather than the target movement miscounted. '
        'Separately measured and REAL: $oovGapReps of $oovReps reps span '
        'frames where the identity gate was CLOSED (frame-level gate, '
        'rep-level claim).';
  } else {
    diagnosis = 'A: MISCLASSIFICATION — $oovReps reps spread across '
        '$oovFilesWithReps of $oovFiles files: systematic, not incidental.';
  }
  report['diagnosis'] = diagnosis;

  final File out = File('../../content/harvest/fallback-liveness.json');
  out.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n');

  stdout.writeln('SÖZLÜK: ${cfg.id} · precondition=${cfg.preconditionStatus} '
      '· üretimde refusalReason erişilebilir mi: '
      '${cfg.preconditionDerived ? "HAYIR" : "evet"}');
  for (final String k in <String>['outOfVocabulary', 'positiveControl']) {
    final Map<String, dynamic> r = report[k] as Map<String, dynamic>;
    stdout.writeln('$k (${r['label']}): ${r['files']} dosya · '
        'tekrar=${r['reps']} · hükümlü kare=${r['judgedFrames']} · '
        'atlanan=${r['skippedFrames']} · red=${r['refused']}');
  }
  stdout.writeln('TEŞHİS: $diagnosis');
  stdout.writeln('→ ${out.path}');
}

Map<String, dynamic> _run(Directory dir, MovementConfig cfg, String label) {
  final Set<int> mandatory = mandatoryFor(cfg).toSet();
  final List<int> all = requiredFor(cfg);
  bool judge(PoseFrame f) {
    int ok = 0;
    for (final int i in all) {
      final PoseLandmark l = f.landmarks[i];
      final bool good = l.x >= 0 && l.x <= 1 && l.y >= 0 && l.y <= 1 &&
          l.visibility >= 0.5;
      if (!good && mandatory.contains(i)) return false;
      if (good) ok++;
    }
    return ok >= all.length - 2;
  }

  int files = 0, reps = 0, judged = 0, skipped = 0, refused = 0, detected = 0;
  int identityGapReps = 0, identityGapFrames = 0;
  // Reçete §4 kapısı: "X videosu" ≠ "X olayı". Dosya-başına dağılım, ZAMAN
  // DAMGASI ile birlikte kaydedilir — YOĞUNLAŞMA tek başına ucuz bir ayırt
  // edici: 27 videoya yayılmış tekrarlar sistematik yanlış-sınıflamayı
  // düşündürür, 2-3 videoda toplanmışsa o videolarda GERÇEKTEN yatay-gövde
  // bölümü (ısınma/plank/yer demosu) olma olasılığı yüksektir.
  final List<Map<String, dynamic>> perFile = <Map<String, dynamic>>[];
  final List<double> allTorsoVis = <double>[];
  if (!dir.existsSync()) {
    return <String, dynamic>{
      'label': label,
      r'$error': 'landmark dizini YOK: ${dir.path}',
      'files': 0,
      'reps': 0,
      'judgedFrames': 0,
      'skippedFrames': 0,
      'refused': 0,
    };
  }

  for (final File f in dir
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.json'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path))) {
    final Map<String, dynamic> fx =
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final Map<String, dynamic> meta =
        (fx['recordingMeta'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final List<String> wh = ((meta['resolution'] as String?) ?? '0x0').split('x');
    if (wh[0] == '0') continue;
    final FrameSize size =
        FrameSize(int.parse(wh[0]), int.parse(wh.length > 1 ? wh[1] : wh[0]));
    files++;

    // Pencereleme harvest_reps ile AYNI (2 sn histerezis): tutorial'da
    // kullanılabilir kareler videoya dağılmıştır ve tek akış vermek çevrimi
    // sürekli zaman aşımına uğratır — o zaman "0 tekrar" ölçüm değil, artefakt
    // olurdu.
    const int maxGapUs = 2000000;
    final List<List<PoseFrame>> windows = <List<PoseFrame>>[];
    List<PoseFrame> current = <PoseFrame>[];
    int lastUs = -1 << 40;
    for (final dynamic raw in fx['frames'] as List<dynamic>) {
      final Map<String, dynamic> fr = raw as Map<String, dynamic>;
      if (fr['detected'] != true) continue;
      final List<dynamic> lm = fr['lm'] as List<dynamic>;
      if (lm.length != Lm.count) continue;
      detected++;
      final PoseFrame pf = PoseFrame(
        tUs: ((fr['t'] as num) * 1000).round(),
        modelVersion: fx['modelVersion'] as String,
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
      if (pf.tUs - lastUs > maxGapUs && current.isNotEmpty) {
        windows.add(current);
        current = <PoseFrame>[];
      }
      current.add(pf);
      lastUs = pf.tUs;
    }
    if (current.isNotEmpty) windows.add(current);

    int fileReps = 0;
    final List<double> stampsS = <double>[];
    final List<double> torsoVis = <double>[];
    for (final List<PoseFrame> w in windows) {
      final RepEngine e = RepEngine(cfg, judge: judge);
      for (final PoseFrame pf in w) {
        e.addFrame(pf, size);
      }
      reps += e.repCount;
      fileReps += e.repCount;
      identityGapReps += e.repsWithIdentityGap;
      identityGapFrames += e.identityClosedFramesInCycle;
      skipped += e.skippedFrames;
      judged += w.length - e.skippedFrames;
      if (e.refusalReason != null) refused++;
      if (e.repCount > 0) {
        // Pencere başlangıcı: gözle doğrulamak isteyen için videodaki YER.
        stampsS.add((w.first.tUs / 1e6 * 10).round() / 10);
        // ⭐ GÖVDE GÖRÜNÜRLÜĞÜ: kimlik kapısı GERÇEK yatay gövdeyle mi geçti,
        // yoksa modelin TAHMİN ettiği gövdeyle mi? MediaPipe görmediği uzvun
        // güvenini düşürmez, makul bir konum UYDURUR (G-078 ailesi). Kapı
        // uydurulmuş geometriyle geçiyorsa "yanlış sınıflama" değil, "kapı
        // tahmine dayanıyor" deriz — farklı kusur, farklı panzehir.
        for (final PoseFrame pf in w) {
          torsoVis.addAll(<double>[
            pf.landmarks[Lm.leftShoulder].visibility,
            pf.landmarks[Lm.rightShoulder].visibility,
            pf.landmarks[Lm.leftHip].visibility,
            pf.landmarks[Lm.rightHip].visibility,
          ]);
        }
      }
    }
    if (fileReps > 0) {
      torsoVis.sort();
      perFile.add(<String, dynamic>{
        'file': f.uri.pathSegments.last.replaceAll('.full.json', ''),
        'reps': fileReps,
        'windowStartsS': stampsS,
        'torsoVisibilityMedian': torsoVis.isEmpty
            ? null
            : (torsoVis[torsoVis.length ~/ 2] * 1000).round() / 1000,
      });
      allTorsoVis.addAll(torsoVis);
    }
  }
  perFile.sort((Map<String, dynamic> a, Map<String, dynamic> b) =>
      (b['reps'] as int).compareTo(a['reps'] as int));

  return <String, dynamic>{
    'label': label,
    'files': files,
    'detectedFrames': detected,
    'reps': reps,
    'judgedFrames': judged,
    'skippedFrames': skipped,
    'refused': refused,
    // G-103: kimlik kapısı KARE düzeyinde, iddia TEKRAR düzeyinde.
    'repsWithIdentityGap': identityGapReps,
    'identityClosedFramesInsideCycles': identityGapFrames,
    'filesWithReps': perFile.length,
    'torsoVisibilityMedianOverRepWindows': allTorsoVis.isEmpty
        ? null
        : ((allTorsoVis..sort())[allTorsoVis.length ~/ 2] * 1000).round() / 1000,
    'perFile': perFile,
  };
}
