import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;

import 'harvest_reps.dart' show mandatoryFor, requiredFor;

/// `kneeAngleAsymmetry` dağılım ölçümü — rig `perMovement.identity.kneeSymmetry`
/// eşiğinin kaynağı (M-F-60/63).
///
/// ⚠️ Bilinçli olarak `harvest_reps.dart`/`build_reference.dart`'ın
/// `preconditionDerived` kilidinden GEÇMEZ: bu araç kilidi AÇACAK ölçümü
/// üretiyor (tavuk-yumurta). Referans/yeterlilik iddiası YAPMAZ, tek bir
/// sayı yazmaz, dosyaya dokunmaz — yalnız dağılımı ekrana basar.
///
/// Kontaminasyon riski (G-043'ün aynısı): bir eğitmen videosu yalnızca
/// squat'tan ibaret değildir (giriş konuşması, kameraya yürüme, b-roll).
/// Tüm kareleri ayrım yapmadan ölçmek, "ayakta konuşurken diz simetrisi"yi
/// "squat'ta diz simetrisi" sanır. Bu yüzden ÜÇ kademe raporlanır, en gevşekten
/// en sıkıya, ki hangisinin seçildiği şeffaf olsun:
///   A) TÜM yargılanabilir kareler (temel/taban — kontaminasyona en açık)
///   B) Kesintisiz HAREKET pencereleri içindeki kareler (2sn boşluk kesimi)
///   C) Motorun KENDİ FSM'inin tamamladığı squat TEKRARLARI içindeki kareler
///      (stand 165°→bottom 116°→stand gerçek geçişi şart koşar — bir
///      konuşmacının ayakta durması bu FSM'i hiç tetiklemez)
///   D) C ∩ StructuralValidator.plausible
///   E) D ∩ BOTTOM-fazı (görünen-taraf diz açısı ≤ `bottom.angleMax`) —
///      koordinatör talimatı (G-061 sonrası): sınıf-ayrımı (squat'ta iki diz
///      BİRLİKTE dipte / lunge'da ayrışır) biyomekanik olarak en çok DİPTE
///      görünür; faz-geneli ölçüm (C/D) descent/ascent geçiş karelerini de
///      katıp gürültü ekliyor olabilir.
///
/// C, ürünün gerçek motorunu (RepEngine) koşturarak elde edilir — paralel bir
/// Python/heuristic yeniden yazımı DEĞİL (M-F-21/25).
void main(List<String> args) {
  final Directory dir = Directory(args.isEmpty
      ? '${Platform.environment['HOME']}/motion-harvest/gravita-squat/landmarks'
      : args[0]);
  const String movementId = 'bodyweight_squat';

  final File cfgFile = File('../../content/catalog/w1/$movementId.json');
  final MovementConfig cfg = MovementConfig.parse(cfgFile.readAsStringSync());
  final double bottomAngleMax = (((jsonDecode(cfgFile.readAsStringSync())
                  as Map<String, dynamic>)['engine'] as Map<String, dynamic>)
              ['phases'] as Map<String, dynamic>)['bottom']['angleMax']
      .toDouble() as double;

  stdout.writeln('hareket: ${cfg.name} — precondition.status='
      '${cfg.preconditionStatus} (bu araç bilinçli olarak bu kilidi atlar)');
  stdout.writeln('bottom.angleMax=$bottomAngleMax° (E kademesi: görünen-taraf '
      'diz açısı bu değerin ALTINDAYKEN alınan kareler)\n');

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

  final List<double> allFrames = <double>[];
  final List<double> windowFrames = <double>[];
  final List<double> repFrames = <double>[];
  final List<double> structuralRepFrames = <double>[];
  final List<double> bottomFrames = <double>[];
  final Map<String, List<double>> repFramesByInstructor = <String, List<double>>{};
  final Map<String, List<double>> structuralRepFramesByInstructor = <String, List<double>>{};
  final Map<String, List<double>> bottomFramesByInstructor = <String, List<double>>{};
  int fixtureCount = 0;
  int totalReps = 0;
  final Set<String> instructorsWithReps = <String>{};

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
    fixtureCount++;

    const int maxGapUs = 2000000; // G-041: aynı histerezis, harvest_reps ile tutarlı
    final List<List<PoseFrame>> windows = <List<PoseFrame>>[];
    List<PoseFrame> current = <PoseFrame>[];
    int lastUs = -1 << 40;
    for (final dynamic raw in fx['frames'] as List<dynamic>) {
      final Map<String, dynamic> fr = raw as Map<String, dynamic>;
      if (fr['detected'] != true) continue;
      final List<dynamic> lm = fr['lm'] as List<dynamic>;
      if (lm.length != Lm.count) continue;
      final PoseFrame pf = PoseFrame(
        tUs: ((fr['t'] as num) * 1000).round(), // fixture `t` MİLİSANİYE (G-040)
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
      // M-F-122 hüküm 1: motor artık `precondition.status != derived` ise
      // tekrar ÜRETMEZ. Bu HASAT yolu ve kimlik güvencesi kare-düzeyi ürün
      // ön koşulundan değil, take-düzeyi hasat-kimlik kapısından geliyor
      // (hipKneeCoupling, 12/16 eğitmen PASS — M-F-106/G-067). Hasat, ön
      // koşulu TÜRETECEK malzemeyi üreten yerdir; ondan "ön koşul zaten
      // türetilmiş olsun" istemek yumurta-tavuk olurdu. Muafiyet DEĞİL,
      // kapı DEĞİŞİMİ (G-039/G-048: farklı sorular, farklı kapılar).
      final RepEngine e =
          RepEngine(cfg, judge: judge, harvestIdentityAttested: true);
      // ⚠️ StructuralValidator SIRALI/AKAN kare bekler (boneLengthInstability +
      // temporalDiscontinuity önceki kareyle kıyaslar) — pencere başına TAZE
      // örnek gerekir (build_reference.dart'la aynı desen).
      final StructuralValidator sv = StructuralValidator();
      final List<({int tUs, double asym, bool structOk, double kneeAngle})> trace =
          <({int tUs, double asym, bool structOk, double kneeAngle})>[];
      for (final PoseFrame pf in w) {
        e.addFrame(pf, size);
        final PoseFrame iso = pf.toIsotropic(size);
        final MovementMetrics m = MovementMetrics.of(iso);
        final double a = m.kneeAngleAsymmetry;
        final bool structOk = sv.check(iso).plausible;
        allFrames.add(a);
        windowFrames.add(a);
        if (!a.isNaN) {
          trace.add((tUs: pf.tUs, asym: a, structOk: structOk, kneeAngle: m.kneeAngle));
        }
      }
      totalReps += e.repCount;
      if (e.repCount > 0) instructorsWithReps.add(channel);
      for (final Rep r in e.reps) {
        for (final ({int tUs, double asym, bool structOk, double kneeAngle}) t in trace) {
          if (t.tUs >= r.startUs && t.tUs <= r.endUs) {
            repFrames.add(t.asym);
            repFramesByInstructor.putIfAbsent(channel, () => <double>[]).add(t.asym);
            if (t.structOk) {
              structuralRepFrames.add(t.asym);
              structuralRepFramesByInstructor
                  .putIfAbsent(channel, () => <double>[])
                  .add(t.asym);
              if (!t.kneeAngle.isNaN && t.kneeAngle <= bottomAngleMax) {
                bottomFrames.add(t.asym);
                bottomFramesByInstructor
                    .putIfAbsent(channel, () => <double>[])
                    .add(t.asym);
              }
            }
          }
        }
      }
    }
  }

  ({double mean, double p50, double p90, double p95, double p99, double max, int n})
      stats(List<double> xs) {
    final List<double> clean = xs.where((double x) => !x.isNaN).toList()..sort();
    if (clean.isEmpty) {
      return (mean: double.nan, p50: double.nan, p90: double.nan, p95: double.nan,
          p99: double.nan, max: double.nan, n: 0);
    }
    double pct(double p) {
      final double idx = p * (clean.length - 1);
      final int lo = idx.floor(), hi = idx.ceil();
      if (lo == hi) return clean[lo];
      return clean[lo] + (clean[hi] - clean[lo]) * (idx - lo);
    }
    return (
      mean: clean.reduce((double a, double b) => a + b) / clean.length,
      p50: pct(0.50),
      p90: pct(0.90),
      p95: pct(0.95),
      p99: pct(0.99),
      max: clean.last,
      n: clean.length,
    );
  }

  void report(String label, List<double> xs) {
    final r = stats(xs);
    stdout.writeln('$label: n=${r.n}  mean=${r.mean.toStringAsFixed(2)}°  '
        'p50=${r.p50.toStringAsFixed(2)}°  p90=${r.p90.toStringAsFixed(2)}°  '
        'p95=${r.p95.toStringAsFixed(2)}°  p99=${r.p99.toStringAsFixed(2)}°  '
        'max=${r.max.toStringAsFixed(2)}°');
  }

  stdout.writeln('fixture sayısı: $fixtureCount');
  stdout.writeln('FSM-tamamlanmış squat tekrarı: $totalReps '
      '(${instructorsWithReps.length} eğitmende)\n');
  report('A) TÜM yargılanabilir kareler       ', allFrames);
  report('B) Hareket-penceresi kareleri       ', windowFrames);
  report('C) FSM-tamamlanmış TEKRAR kareleri  ', repFrames);
  report('D) C ∩ StructuralValidator.plausible', structuralRepFrames);
  report('E) D ∩ BOTTOM-fazı (≤${bottomAngleMax.toStringAsFixed(0)}°)     ', bottomFrames);

  stdout.writeln('\n-- C) eğitmen başına --');
  final List<String> chans = repFramesByInstructor.keys.toList()..sort();
  for (final String ch in chans) {
    final r = stats(repFramesByInstructor[ch]!);
    stdout.writeln('${ch.padRight(28).substring(0, math.min(28, ch.length))}'
        '  n=${r.n.toString().padLeft(5)}  mean=${r.mean.toStringAsFixed(2)}°'
        '  p95=${r.p95.toStringAsFixed(2)}°  max=${r.max.toStringAsFixed(2)}°');
  }

  stdout.writeln('\n-- D) eğitmen başına --');
  for (final String ch in chans) {
    final List<double>? xs = structuralRepFramesByInstructor[ch];
    if (xs == null) {
      stdout.writeln('${ch.padRight(28).substring(0, math.min(28, ch.length))}  n=0 (yapısal denetimden geçen kare yok)');
      continue;
    }
    final r = stats(xs);
    stdout.writeln('${ch.padRight(28).substring(0, math.min(28, ch.length))}'
        '  n=${r.n.toString().padLeft(5)}  mean=${r.mean.toStringAsFixed(2)}°'
        '  p95=${r.p95.toStringAsFixed(2)}°  max=${r.max.toStringAsFixed(2)}°');
  }

  stdout.writeln('\n-- E) eğitmen başına (bottom-fazı daraltması) --');
  for (final String ch in chans) {
    final List<double>? xs = bottomFramesByInstructor[ch];
    if (xs == null) {
      stdout.writeln('${ch.padRight(28).substring(0, math.min(28, ch.length))}  n=0 (bottom-fazı karesi yok)');
      continue;
    }
    final r = stats(xs);
    stdout.writeln('${ch.padRight(28).substring(0, math.min(28, ch.length))}'
        '  n=${r.n.toString().padLeft(5)}  mean=${r.mean.toStringAsFixed(2)}°'
        '  p95=${r.p95.toStringAsFixed(2)}°  max=${r.max.toStringAsFixed(2)}°');
  }

  stdout.writeln('\n-- E) havuzlanmış histogram (10° kutular) --');
  final List<double> bottomClean =
      bottomFrames.where((double x) => !x.isNaN).toList()..sort();
  if (bottomClean.isNotEmpty) {
    final List<int> bins = List<int>.filled(19, 0);
    for (final double x in bottomClean) {
      final int b = (x ~/ 10).clamp(0, 18);
      bins[b]++;
    }
    final int maxBin = bins.reduce(math.max);
    for (int i = 0; i < bins.length; i++) {
      final String bar = '#' * (maxBin == 0 ? 0 : bins[i] * 60 ~/ maxBin);
      stdout.writeln('${(i * 10).toString().padLeft(4)}-${(i * 10 + 10).toString().padLeft(4)}° : '
          '${bins[i].toString().padLeft(6)} $bar');
    }
  }
}
