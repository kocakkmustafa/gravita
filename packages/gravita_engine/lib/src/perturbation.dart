import 'dart:math' as math;

import 'package:motion_core/motion_core.dart';

import 'metrics.dart';
import 'movement_config.dart';

/// Kasıtlı-hata fixture'ı üreteci (M-C-03).
///
/// Kurucu çekimi kalktığından beri hatalı örnekler ÇEKİLMİYOR, doğru referansın
/// **kontrollü bozulmasından** üretiliyor. Bozulmanın büyüklüğünü biz
/// belirlediğimiz için etiket bedavadır.
///
/// Kritik tasarım: üreteç bozulmayı **varsaymaz, ÖLÇER**. Config `targetValue`
/// beyan eder (G-015); üreteç bozulma parametresini o hedefe ulaşana kadar
/// arar ve ulaşamazsa **yüksek sesle başarısız olur**. Sessizce "yaklaşık"
/// bir fixture üretmek, C-011 tuzağının ta kendisidir: test yeşil yanar ama
/// hiçbir şey sınamaz.
///
/// Girdi/çıktı **izotropik** karelerdir (düzlemde döndürme ancak izotropik
/// uzayda gerçek bir döndürmedir). Motorlara verirken kare `FrameSize` kullan
/// (aspect 1 → `toIsotropic` kimlik).
final class Perturbation {
  const Perturbation._();

  /// Bir eklemin DİSTAL zinciri — o eklemden sonra gelen her şey.
  static const Map<String, List<int>> distalChain = <String, List<int>>{
    'hip': <int>[
      Lm.leftKnee, Lm.rightKnee, Lm.leftAnkle, Lm.rightAnkle,
      Lm.leftHeel, Lm.rightHeel, Lm.leftFootIndex, Lm.rightFootIndex,
    ],
    'knee': <int>[
      Lm.leftAnkle, Lm.rightAnkle, Lm.leftHeel, Lm.rightHeel,
      Lm.leftFootIndex, Lm.rightFootIndex,
    ],
    'shoulder': <int>[
      Lm.leftElbow, Lm.rightElbow, Lm.leftWrist, Lm.rightWrist,
      Lm.leftPinky, Lm.rightPinky, Lm.leftIndex, Lm.rightIndex,
      Lm.leftThumb, Lm.rightThumb,
    ],
    'elbow': <int>[
      Lm.leftWrist, Lm.rightWrist, Lm.leftPinky, Lm.rightPinky,
      Lm.leftIndex, Lm.rightIndex, Lm.leftThumb, Lm.rightThumb,
    ],
    'neck': <int>[
      Lm.nose, Lm.leftEye, Lm.rightEye, Lm.leftEyeInner, Lm.rightEyeInner,
      Lm.leftEyeOuter, Lm.rightEyeOuter, Lm.leftEar, Lm.rightEar,
      Lm.mouthLeft, Lm.mouthRight,
    ],
  };

  static ({double x, double y}) _pivot(PoseFrame f, String joint) =>
      switch (joint) {
        'hip' => (
            x: (f[Lm.leftHip].x + f[Lm.rightHip].x) / 2,
            y: (f[Lm.leftHip].y + f[Lm.rightHip].y) / 2
          ),
        'knee' => (
            x: (f[Lm.leftKnee].x + f[Lm.rightKnee].x) / 2,
            y: (f[Lm.leftKnee].y + f[Lm.rightKnee].y) / 2
          ),
        'elbow' => (
            x: (f[Lm.leftElbow].x + f[Lm.rightElbow].x) / 2,
            y: (f[Lm.leftElbow].y + f[Lm.rightElbow].y) / 2
          ),
        _ => (
            x: (f[Lm.leftShoulder].x + f[Lm.rightShoulder].x) / 2,
            y: (f[Lm.leftShoulder].y + f[Lm.rightShoulder].y) / 2
          ),
      };

  /// [joint] etrafında distal zinciri [deltaDeg] döndürür.
  static PoseFrame rotateDistal(PoseFrame f, String joint, double deltaDeg) {
    final List<int>? chain = distalChain[joint];
    if (chain == null) {
      throw ArgumentError('bilinmeyen eklem: $joint');
    }
    final ({double x, double y}) p = _pivot(f, joint);
    final double a = deltaDeg * math.pi / 180;
    final double ca = math.cos(a), sa = math.sin(a);
    final Set<int> moving = chain.toSet();
    return PoseFrame(
      tUs: f.tUs,
      modelVersion: f.modelVersion,
      landmarks: List<PoseLandmark>.generate(Lm.count, (int i) {
        final PoseLandmark l = f.landmarks[i];
        if (!moving.contains(i)) return l;
        final double dx = l.x - p.x, dy = l.y - p.y;
        return PoseLandmark(
          p.x + dx * ca - dy * sa,
          p.y + dx * sa + dy * ca,
          l.z,
          l.visibility,
        );
      }),
    );
  }

  /// Hedef metriği [targetValue]'ya taşıyan bozulma açısını ARAR.
  ///
  /// Analitik ters çevirme yerine arama: metrik tanımları (vekiller, işaretli
  /// açılar, orta-hat hesapları) kapalı formda tersine çevrilebilir değil ve
  /// "yaklaşık doğru" bir formül sessizce hedefi ıskalayan fixture üretir.
  /// Arama sonucu ÖLÇÜLEREK doğrulanır.
  static double solveDelta(
    PoseFrame clean,
    String joint,
    String metric,
    double targetValue, {
    double searchDeg = 60,
    double tolerance = 0.25,
    int iterations = 60,
  }) {
    double at(double d) {
      final double? v =
          MovementMetrics.of(rotateDistal(clean, joint, d)).byName(metric);
      if (v == null || v.isNaN) return double.nan;
      return v;
    }

    final double v0 = at(0);
    if (v0.isNaN) {
      throw StateError('$metric temiz karede ölçülemiyor — perturbasyon üretilemez');
    }
    // Hedefe hangi yön yaklaştırıyor?
    double lo = -searchDeg, hi = searchDeg;
    final bool increasing = at(1) > v0;
    final bool needMore = targetValue > v0;
    if (increasing != needMore) {
      lo = -searchDeg;
      hi = 0;
    } else {
      lo = 0;
      hi = searchDeg;
    }
    for (int i = 0; i < iterations; i++) {
      final double mid = (lo + hi) / 2;
      final double v = at(mid);
      if (v.isNaN) break;
      if ((v - targetValue).abs() <= tolerance) return mid;
      final bool goUp = (v < targetValue) == increasing;
      if (goUp) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final double best = (lo + hi) / 2;
    final double got = at(best);
    throw StateError(
        '$metric hedefi $targetValue\'ya ulaşılamadı (en iyi: '
        '${got.toStringAsFixed(2)} @ ${best.toStringAsFixed(1)}°). '
        'Fixture sessizce toleransın içinde kalmasın diye ÜRETİLMEDİ (C-011).');
  }

  /// Temiz diziyi bozar: hata gerçekten tetiklenene kadar.
  static List<PoseFrame> corruptSequence(
    List<PoseFrame> clean,
    String joint,
    String metric,
    double targetValue,
  ) {
    if (clean.isEmpty) return clean;
    final double delta = solveDelta(clean.first, joint, metric, targetValue);
    return clean
        .map((PoseFrame f) => rotateDistal(f, joint, delta))
        .toList(growable: false);
  }

  /// Bir form hatasının fixture'ını üretir ve **tetiklendiğini doğrular**.
  static ({List<PoseFrame> frames, double measured}) forError(
    List<PoseFrame> clean,
    FormError error, {
    required String joint,
  }) {
    if (error.perturbationTarget == null || error.metric == null) {
      throw ArgumentError('${error.id}: perturbasyon hedefi veya metrik yok');
    }
    final List<PoseFrame> bad = corruptSequence(
        clean, joint, error.metric!, error.perturbationTarget!);
    final double measured =
        MovementMetrics.of(bad.first).byName(error.metric!)!;
    if (!error.fires(measured)) {
      throw StateError(
          '${error.id}: üretilen fixture hatayı TETİKLEMİYOR '
          '(ölçülen $measured, eşik ${error.op}${error.threshold}). '
          'Sınadığı toleransın içinde kalan fixture testi boşa düşürür.');
    }
    return (frames: bad, measured: measured);
  }
}
