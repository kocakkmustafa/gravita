import 'package:motion_core/motion_core.dart';

/// Karenin piksel boyutu — açı/mesafe matematiği için ZORUNLU.
///
/// **J-028 (aile kuralı M-F-30).** MediaPipe'ın normalize landmark'ları
/// `x = piksel_x / genişlik` ve `y = piksel_y / yükseklik` biçimindedir: iki
/// eksen AYRI bölenlerle ölçeklenir. Kare kare değilse bu uzay **anizotropiktir**
/// — yataydaki 0.1 ile dikeydeki 0.1 farklı fiziksel uzunluklardır. Bu uzayda
/// hesaplanan her açı ve her mesafe en-boy oranı kadar bozulur.
///
/// Gravita verisinde ölçüldü (D1'in 64 gerçek karesi, en-boy 0.47-1.79):
/// dirsek açısında medyan **4,8°**, p90 **13,3°**, maks **23,1°** sapma;
/// ölçümlerin **%42'si >5°**, **%21'i >10°** kayıyor. Form eşiklerimiz 12-45°
/// bandında olduğu için bu, hükümleri doğrudan çevirir.
///
/// Sentetik testler bu hatayı YAKALAYAMAZ: sentetik iskelet tek bir uzayda
/// üretilir, dolayısıyla üretim ve ölçüm aynı çarpıklığı paylaşır ve fark
/// görünmez. Bu yüzden motor, gerçek-kare regresyon testi taşımak zorundadır.
final class FrameSize {
  const FrameSize(this.width, this.height)
      : assert(width > 0 && height > 0, 'kare boyutu pozitif olmalı');

  final int width;
  final int height;

  double get aspect => width / height;
  bool get isSquare => width == height;

  /// x ekseninin izotropik ölçeği (uzun kenara göre).
  double get scaleX => width / (width > height ? width : height);

  /// y ekseninin izotropik ölçeği.
  double get scaleY => height / (width > height ? width : height);

  @override
  String toString() => '${width}x$height';
}

/// Kareyi izotropik uzaya taşır: bir birim x ile bir birim y aynı fiziksel
/// uzunluğu temsil eder.
///
/// Değerler [0,1] aralığında kalır (uzun kenar 1'e ölçeklenir), böylece
/// çekirdeğin gövde-uzunluğuna normalize eden matematiği aynen çalışır —
/// yalnız artık doğru bir uzayda çalışır.
///
/// ⚠️ Varsayılan YOK. "Kare boyutu verilmezse kare varsay" gibi bir kolaylık,
/// hatayı sessizce geri getirir; çağıran boyutu vermek ZORUNDADIR.
PoseFrame toIsotropic(PoseFrame frame, FrameSize size) {
  if (size.isSquare) return frame;
  final double sx = size.scaleX;
  final double sy = size.scaleY;
  return PoseFrame(
    tUs: frame.tUs,
    modelVersion: frame.modelVersion,
    landmarks: <PoseLandmark>[
      for (final PoseLandmark l in frame.landmarks)
        PoseLandmark(l.x * sx, l.y * sy, l.z * sx, l.visibility),
    ],
  );
}
