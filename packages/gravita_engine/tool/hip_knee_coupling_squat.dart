// ⚠️⚠️⚠️ RETIRED (G-065/M-F-96, 2026-07-29) — BU DOSYA ARTIK TÜKETİLMEZ. ⚠️⚠️⚠️
//
// Kanıt: bu aracın 2D-taraf-agnostik/düz-izotropik formülü kamera-açısına
// KIRILGAN çıktı — G-065 diferansiyel testinde TappBrothers'ta Lissom'un
// düzeltilmiş formülüyle (WORLD 3D + proximal-projeksiyon,
// `mocore.measures.evaluate(anatomical=true)`) 0,668'lik MADDİ bir fark
// ölçüldü (bu araç: r=0,150 RED; kanonik: r=0,818/0,642 GEÇER). Bu, G-061'in
// tüm gece bulduğu "kamera açısı 2D açıları bozar" deseninin hipKneeCoupling
// düzeyindeki tekrarıydı.
//
// Koordinatör mimari kararı: kimlik metriği HASAT ANINDA BİR KEZ, paylaşımlı
// `mocore` ile hesaplanır ve fixture provenance'ına DAMGALANIR — tüketiciler
// sayıyı OKUR, yeniden hesaplamaz (kopya-sürüklenmesi sınıfı kökten kapanır).
// Kanonik yerine geçen: `tools/hip_knee_coupling_canonical.py`
// (`mocore.measures.evaluate(anatomical=true)`, Lissom'un `lissom-metrics.
// v1.json`'undan BİREBİR metrik tanımı okuyor).
//
// Bu dosya SİLİNMEDİ — "aynı hatayı iki kez ölçme" kanıtı olarak arşivde
// kalıyor (M-F-57'nin "doğrulayıcının kendisi de denetlenmeli" dersinin bir
// örneği: yanlış formül bir GATE KARARINI (TappBrothers reddi) fiilen
// etkilemişti). Kanıt: docs/gates/G-065-HIPKNEECOUPLING-DIFERANSIYEL-TESTI.md,
// docs/gates/G-066-HIPKNEECOUPLING-KANONIK-DAMGA.md.
//
// -----------------------------------------------------------------------

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;

import 'harvest_reps.dart' show mandatoryFor, requiredFor;

/// `hipKneeCoupling` — BEŞİNCİ SORU cevabı (M-F-73/80): Lissom bu sinyali rig
/// `identity`'ye yazdı (`deep_squat`, provisional r≥0,20) ama squat kimliği
/// artık bunun üstünde kapılanacağı hâlde TÜKETİCİSİ yoktu. Bu araç Gravita'nın
/// 27 squat fixture'ında AYNI sinyali ölçen İLK tüketici.
///
/// Metrik (Lissom `lissom-metrics.v1.json`): Pearson(hip_flexion, knee_flexion)
/// — squat'ta kalça ve diz BİRLİKTE bükülür (pozitif korelasyon); confounder'da
/// (yürüme, ayrı hareket) ayrışır (işaret döner/zayıflar). Lissom `RIGHT_*`
/// sabit uçlarla ölçtü; burada Gravita'nın taraf-agnostik (ADR-003) GÖRÜNEN-
/// taraf açılarıyla (`MovementMetrics.hipAngle`/`kneeAngle`) — kavramsal
/// olarak AYNI üçlü nokta seti, taraf seçimi farklı. ⚠️ Lissom hip_flexion'ı
/// `frameRef: proximal` (M-F-54 taksonomisi) ile ölçüyor; burada Gravita'nın
/// mevcut düz izotropik açısı kullanılıyor — TAM AYNI SAYI olmayabilir, ama
/// işaret/kategori ayrımı (Lissom'un kendi notu: "ayrım kategorik, ince eşik
/// ayarı değil") bu yaklaşıklıkla da anlamlı olmalı.
///
/// kneeSymmetry (advisory) YANINDA raporlanır, KAPI DEĞİLDİR (8765977 şeması
/// zaten zorluyor) — yalnız hipKneeCoupling kapı olarak uygulanır.
void main(List<String> args) {
  final Directory dir = Directory(args.isEmpty
      ? '${Platform.environment['HOME']}/motion-harvest/gravita-squat/landmarks'
      : args[0]);
  const String movementId = 'bodyweight_squat';
  const double coupleThreshold = 0.2; // Lissom provisional min

  final File cfgFile = File('../../content/catalog/w1/$movementId.json');
  final MovementConfig cfg = MovementConfig.parse(cfgFile.readAsStringSync());

  stdout.writeln('hareket: ${cfg.name} · hipKneeCoupling eşiği (Lissom '
      'provisional): pearson ≥ $coupleThreshold\n');

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

  final Map<String, List<double>> hipByInstructor = <String, List<double>>{};
  final Map<String, List<double>> kneeByInstructor = <String, List<double>>{};
  final Map<String, List<double>> asymByInstructor = <String, List<double>>{};

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
    final List<String> wh =
        ((meta['resolution'] as String?) ?? '1280x720').split('x');
    final FrameSize size =
        FrameSize(int.parse(wh[0]), int.parse(wh.length > 1 ? wh[1] : wh[0]));

    const int maxGapUs = 2000000;
    final List<List<PoseFrame>> windows = <List<PoseFrame>>[];
    List<PoseFrame> current = <PoseFrame>[];
    int lastUs = -1 << 40;
    for (final dynamic raw in fx['frames'] as List<dynamic>) {
      final Map<String, dynamic> fr = raw as Map<String, dynamic>;
      if (fr['detected'] != true) continue;
      final List<dynamic> lm = fr['lm'] as List<dynamic>;
      if (lm.length != Lm.count) continue;
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

    for (final List<PoseFrame> w in windows) {
      final RepEngine e = RepEngine(cfg, judge: judge);
      final StructuralValidator sv = StructuralValidator();
      final List<({int tUs, double hip, double knee, double asym})> trace =
          <({int tUs, double hip, double knee, double asym})>[];
      for (final PoseFrame pf in w) {
        e.addFrame(pf, size);
        final PoseFrame iso = pf.toIsotropic(size);
        if (!sv.check(iso).plausible) continue;
        final MovementMetrics m = MovementMetrics.of(iso);
        trace.add((tUs: pf.tUs, hip: m.hipAngle, knee: m.kneeAngle,
            asym: m.kneeAngleAsymmetry));
      }
      for (final Rep r in e.reps) {
        for (final ({int tUs, double hip, double knee, double asym}) t in trace) {
          if (t.tUs >= r.startUs && t.tUs <= r.endUs) {
            if (t.hip.isNaN || t.knee.isNaN) continue;
            hipByInstructor.putIfAbsent(channel, () => <double>[]).add(t.hip);
            kneeByInstructor.putIfAbsent(channel, () => <double>[]).add(t.knee);
            if (!t.asym.isNaN) {
              asymByInstructor.putIfAbsent(channel, () => <double>[]).add(t.asym);
            }
          }
        }
      }
    }
  }

  double pearson(List<double> xs, List<double> ys) {
    final int n = xs.length;
    if (n < 3) return double.nan;
    final double mx = xs.reduce((a, b) => a + b) / n;
    final double my = ys.reduce((a, b) => a + b) / n;
    double cov = 0, vx = 0, vy = 0;
    for (int i = 0; i < n; i++) {
      final double dx = xs[i] - mx, dy = ys[i] - my;
      cov += dx * dy;
      vx += dx * dx;
      vy += dy * dy;
    }
    if (vx <= 0 || vy <= 0) return double.nan;
    return cov / math.sqrt(vx * vy);
  }

  final Map<String, dynamic> gateResults = <String, dynamic>{};
  stdout.writeln('-- eğitmen başına hipKneeCoupling --');
  final List<String> chans = hipByInstructor.keys.toList()..sort();
  int pass = 0, fail = 0;
  for (final String ch in chans) {
    final List<double> hips = hipByInstructor[ch]!;
    final List<double> knees = kneeByInstructor[ch]!;
    final double r = pearson(hips, knees);
    final bool gatePass = !r.isNaN && r >= coupleThreshold;
    if (gatePass) {
      pass++;
    } else {
      fail++;
    }
    final List<double>? asym = asymByInstructor[ch];
    final double asymMean = (asym == null || asym.isEmpty)
        ? double.nan
        : asym.reduce((a, b) => a + b) / asym.length;
    stdout.writeln('${ch.padRight(28).substring(0, math.min(28, ch.length))}'
        '  n=${hips.length.toString().padLeft(5)}  r=${r.toStringAsFixed(3).padLeft(7)}'
        '  → ${gatePass ? "GEÇTİ" : "reddedildi"}'
        '  (kneeSymmetry advisory: mean=${asymMean.toStringAsFixed(1)}°)');
    gateResults[ch] = <String, dynamic>{
      'n': hips.length,
      'pearsonHipKnee': double.parse(r.isNaN ? '0' : r.toStringAsFixed(3)),
      'gate': gatePass ? 'pass' : 'fail',
      'kneeAsymmetryAdvisoryMeanDeg':
          asymMean.isNaN ? null : double.parse(asymMean.toStringAsFixed(1)),
    };
  }
  stdout.writeln('\nGEÇTİ: $pass · reddedildi: $fail (eşik r≥$coupleThreshold)');

  File('../../content/harvest/hip_knee_coupling.bodyweight_squat.json')
      .writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        'movement': movementId,
        r'$doc': 'Squat kimliğinin İLK gerçek kapısı (M-F-73/80): '
            'hipKneeCoupling (Lissom sinyali, rig identity, provisional '
            'r>=0.2) — Gravita 27-fixture squat havuzunda ölçüldü. '
            'kneeSymmetry (advisory) yanında raporlanır, KAPI DEĞİLDİR.',
        'gateThreshold': coupleThreshold,
        'passCount': pass,
        'failCount': fail,
        'instructors': gateResults,
      })}\n');
  stdout.writeln('\nyazıldı: content/harvest/hip_knee_coupling.bodyweight_squat.json');
}
