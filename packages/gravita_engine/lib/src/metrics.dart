import 'dart:math' as math;

import 'package:motion_core/motion_core.dart';

import 'rep_engine.dart' show VisibleSide, resolveVisibleSide;

/// Poz → metrik katmanı: `content/schema/metrics.json` sözlüğünün Dart karşılığı.
///
/// Kural motoru pozla değil METRİKLE konuşur. Bu ayrım olmadan her form hatası
/// kendi geometrisini yeniden yazar ve 180 hareket 180 farklı "kalça düşük"
/// tanımına sahip olur.
///
/// ⚠️ Girdi **izotropik** kare olmalıdır (J-028 / M-F-30). Ham normalize
/// koordinatta hesaplanan her açı en-boy oranı kadar bozuktur; bu sınıf bunu
/// kontrol edemez, çağıranın `PoseFrame.toIsotropic` uygulamış olması gerekir.
final class MovementMetrics {
  MovementMetrics._(this._f, this._side);

  /// [isotropicFrame] ZORUNLU olarak izotropik uzayda olmalı.
  factory MovementMetrics.of(PoseFrame isotropicFrame) =>
      MovementMetrics._(isotropicFrame, resolveVisibleSide(isotropicFrame));

  final PoseFrame _f;
  final VisibleSide _side;

  bool get _left => _side == VisibleSide.left;

  int get _shoulder => _left ? Lm.leftShoulder : Lm.rightShoulder;
  int get _elbow => _left ? Lm.leftElbow : Lm.rightElbow;
  int get _wrist => _left ? Lm.leftWrist : Lm.rightWrist;
  int get _hip => _left ? Lm.leftHip : Lm.rightHip;
  int get _knee => _left ? Lm.leftKnee : Lm.rightKnee;
  int get _ankle => _left ? Lm.leftAnkle : Lm.rightAnkle;
  int get _heel => _left ? Lm.leftHeel : Lm.rightHeel;

  double _x(int i) => _f[i].x;
  double _y(int i) => _f[i].y;

  static double _angle(double ax, double ay, double bx, double by, double cx,
      double cy) {
    final double v1x = ax - bx, v1y = ay - by;
    final double v2x = cx - bx, v2y = cy - by;
    final double n = math.sqrt(v1x * v1x + v1y * v1y) *
        math.sqrt(v2x * v2x + v2y * v2y);
    if (n < 1e-12) return double.nan;
    return math.acos(math.max(-1, math.min(1, (v1x * v2x + v1y * v2y) / n))) *
        180 /
        math.pi;
  }

  double _jointAngle(int a, int b, int c) =>
      _angle(_x(a), _y(a), _x(b), _y(b), _x(c), _y(c));

  /// Omuz-kalça orta noktaları arası uzunluk — tüm mesafe metriklerinin ölçeği.
  double get torsoLength {
    final double sx = (_x(Lm.leftShoulder) + _x(Lm.rightShoulder)) / 2;
    final double sy = (_y(Lm.leftShoulder) + _y(Lm.rightShoulder)) / 2;
    final double hx = (_x(Lm.leftHip) + _x(Lm.rightHip)) / 2;
    final double hy = (_y(Lm.leftHip) + _y(Lm.rightHip)) / 2;
    return math.max(math.sqrt((sx - hx) * (sx - hx) + (sy - hy) * (sy - hy)), 1e-9);
  }

  double get elbowAngle => _jointAngle(_shoulder, _elbow, _wrist);
  double get kneeAngle => _jointAngle(_hip, _knee, _ankle);
  double get hipAngle => _jointAngle(_shoulder, _hip, _knee);
  double get shoulderAngle => _jointAngle(_hip, _shoulder, _elbow);

  /// İki kol arasındaki açı farkı. Taraf etiketine bağlanmaz: iki zinciri
  /// karşılaştırır, hangisinin "sol" olduğunu sormaz (ADR-003).
  double get elbowAngleAsymmetry {
    final double l = _jointAngle(Lm.leftShoulder, Lm.leftElbow, Lm.leftWrist);
    final double r = _jointAngle(Lm.rightShoulder, Lm.rightElbow, Lm.rightWrist);
    if (l.isNaN || r.isNaN) return double.nan;
    return (l - r).abs();
  }

  /// Gövde hattının düşeyden sapması (0 = dik).
  double get torsoAngleFromVertical {
    final double sx = (_x(Lm.leftShoulder) + _x(Lm.rightShoulder)) / 2;
    final double sy = (_y(Lm.leftShoulder) + _y(Lm.rightShoulder)) / 2;
    final double hx = (_x(Lm.leftHip) + _x(Lm.rightHip)) / 2;
    final double hy = (_y(Lm.leftHip) + _y(Lm.rightHip)) / 2;
    return _angle(sx, sy, hx, hy, hx, hy - 1);
  }

  /// Omuz-kalça-ayak bileği hattının düz hattan **işaretli** sapması.
  ///
  /// `+` = kalça hattın ALTINDA (sag), `−` = kalça hattın ÜSTÜNDE (pike).
  ///
  /// ⚠️ İşaret görüntü-y eksenine göre tanımlıdır, yani "aşağı" kameranın
  /// aşağısıdır. W1'de bu metriği kullanan hareketlerin hepsi yüzüstü/sırtüstü
  /// veya ayaktadır; TERS-DURUŞ hareketlerinde işaret yönelimle birlikte
  /// yorumlanmalıdır (ADR-001 zinciri) — o iş inversiyon motorunda.
  /// ORTA-HAT noktalarıyla hesaplanır (aile sözleşmesi M-L-04: türetilmiş
  /// `MID_SHOULDER`/`MID_HIP`). Yan landmark'lar kullanılırsa omuz genişliği ile
  /// kalça genişliğinin farkı yüzünden **kusursuz bir plank bile ~6,5° sapma**
  /// gösterir — ölçümle bulundu. Bu, 12°'lik toleransın yarısını taban gürültüye
  /// harcamak demekti.
  double get lineDeviationDeg {
    final double sx = (_x(Lm.leftShoulder) + _x(Lm.rightShoulder)) / 2;
    final double sy = (_y(Lm.leftShoulder) + _y(Lm.rightShoulder)) / 2;
    final double hx = (_x(Lm.leftHip) + _x(Lm.rightHip)) / 2;
    final double hy = (_y(Lm.leftHip) + _y(Lm.rightHip)) / 2;
    final double ax = (_x(Lm.leftAnkle) + _x(Lm.rightAnkle)) / 2;
    final double ay = (_y(Lm.leftAnkle) + _y(Lm.rightAnkle)) / 2;
    final double a = _angle(sx, sy, hx, hy, ax, ay);
    if (a.isNaN) return double.nan;
    final double magnitude = 180 - a;
    final double t = ((hx - sx) * (ax - sx) + (hy - sy) * (ay - sy)) /
        math.max((ax - sx) * (ax - sx) + (ay - sy) * (ay - sy), 1e-12);
    return hy > sy + t * (ay - sy) ? magnitude : -magnitude;
  }

  /// Bel fleksiyonu/ekstansiyonu vekili — omuz-kalça-diz açısının düzden sapması.
  /// **Omurga ölçümü DEĞİLDİR** (metrics.json'da da böyle etiketli).
  double get lumbarFlexionProxy {
    final double a = _jointAngle(_shoulder, _hip, _knee);
    return a.isNaN ? double.nan : (180 - a).abs();
  }

  double get lumbarExtensionProxy => lumbarFlexionProxy;

  /// Boyun sagittal açısı, İŞARETLİ: `+` fleksiyon (baş öne/aşağı),
  /// `−` ekstansiyon (baş geriye). Tek metrik iki yönü de taşır.
  double get neckFlexionProxy {
    final double sx = (_x(Lm.leftShoulder) + _x(Lm.rightShoulder)) / 2;
    final double sy = (_y(Lm.leftShoulder) + _y(Lm.rightShoulder)) / 2;
    final double hx = (_x(Lm.leftHip) + _x(Lm.rightHip)) / 2;
    final double hy = (_y(Lm.leftHip) + _y(Lm.rightHip)) / 2;
    final double a = _angle(_x(Lm.nose), _y(Lm.nose), sx, sy, hx, hy);
    if (a.isNaN) return double.nan;
    final double magnitude = (180 - a).abs();
    // Burun, gövde ekseninin önünde mi arkasında mı (çapraz çarpım işareti).
    final double cross =
        (sx - hx) * (_y(Lm.nose) - hy) - (sy - hy) * (_x(Lm.nose) - hx);
    return cross >= 0 ? magnitude : -magnitude;
  }

  /// Dirseğin omuz düşeyinden yatay kayması, gövdeye normalize.
  double get elbowUnderShoulderOffsetTorso =>
      (_x(_elbow) - _x(_shoulder)).abs() / torsoLength;

  /// Topuğun ayak parmağı hizasından yükselmesi, gövdeye normalize.
  double get heelRiseTorsoNorm {
    final int toe = _left ? Lm.leftFootIndex : Lm.rightFootIndex;
    return math.max(0, _y(toe) - _y(_heel)) / torsoLength;
  }

  /// Ayak bileği orta noktasının görüntü-y'si.
  double get ankleMidY => (_y(Lm.leftAnkle) + _y(Lm.rightAnkle)) / 2;

  /// ZEMİN TEMAS noktasının görüntü-y'si: ayağın en alçak parçası (parmak ucu
  /// veya topuk), ayak bileği DEĞİL.
  ///
  /// Ayak bileğiyle ölçmek plankta, şınavda, lungede ve parmak ucundaki her
  /// pozisyonda "ayak havada" der — çünkü o pozisyonlarda ayak bileği gerçekten
  /// yukarıdadır, yere değen parmak ucudur. Ölçümle bulundu (burpee zinciri
  /// plank fazında takılıyordu).
  double get footContactY => <double>[
        _y(Lm.leftFootIndex), _y(Lm.rightFootIndex),
        _y(Lm.leftHeel), _y(Lm.rightHeel),
      ].reduce(math.max);

  /// Kalçanın ayak hizasından yüksekliği, gövdeye normalize (ayakta ~büyük,
  /// çömelmede küçük, plankta ~0).
  double get hipHeightTorso {
    final double hy = (_y(Lm.leftHip) + _y(Lm.rightHip)) / 2;
    return (ankleMidY - hy) / torsoLength;
  }

  /// Yan plankta kalçanın hattan düşmesi (`+`) / yükselmesi (`−`).
  double get hipDropDeg => lineDeviationDeg;

  /// Config'deki metrik adından değer üretir — kural motoru bu haritayla konuşur.
  double? byName(String metric) => switch (metric) {
        'elbow_angle' => elbowAngle,
        'knee_angle' => kneeAngle,
        'hip_angle' => hipAngle,
        'shoulder_angle' => shoulderAngle,
        'elbow_angle_asymmetry' => elbowAngleAsymmetry,
        'torso_angle_from_vertical' => torsoAngleFromVertical,
        'line_deviation_deg' => lineDeviationDeg,
        'lumbar_flexion_proxy' => lumbarFlexionProxy,
        'lumbar_extension_proxy' => lumbarExtensionProxy,
        'neck_flexion_proxy' => neckFlexionProxy,
        'elbow_under_shoulder_offset_torso' => elbowUnderShoulderOffsetTorso,
        'heel_rise_torso_norm' => heelRiseTorsoNorm,
        'hip_drop_deg' => hipDropDeg,
        'hip_height_torso' => hipHeightTorso,
        'knee_angle_at_contact' => kneeAngle,
        _ => null,
      };

  /// Config'de geçen ama bu katmanın HENÜZ üretmediği metrikler.
  /// Bilinmeyen metrik sessizce 0 dönmez — kural değerlendirilmez, hüküm yok.
  static const Set<String> unimplemented = <String>{
    'rom_bottom_angle', 'rom_top_angle', // rep motorundan gelir (çevrim uç değeri)
    'hip_swing_amplitude_torso', 'shoulder_elevation_proxy',
    'cadence_spm', 'rep_duration_trend', 'limb_extension_sync_ms',
    'contralateral_alignment_deg', 'trunk_rotation_proxy', 'knee_travel_torso',
    'plantarflexion_deg', 'vertical_travel',
    'feet_off_ground', // zemin-göreli: MultiPhaseEngine'in GroundReference'ı üretir
  };
}
