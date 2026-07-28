import 'dart:convert';
import 'dart:io';

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart';
import 'package:test/test.dart';

/// G-018 — yapısal denetimin YANLIŞ-RED oranı, gerçek veri üzerinde.
///
/// D1 kapısının elenmiş setindeki 66 karenin hepsi DOĞRU çıkarımdır: ürün
/// bunları analiz edebilmelidir. Yapısal denetim bunları reddediyorsa kullanıcı
/// "analiz edemedim" duvarına çarpar — yani aşırı-katı bir denetim, kaçıran bir
/// denetim kadar ürünü bozar. Bu, D1 dersinin simetrik yüzüdür.
///
/// Bu bir **karakterizasyon testi**: ölçülen oranı sabitler, kötüleşirse kırılır.
void main() {
  final Map<String, dynamic> fx = jsonDecode(
    File('test/fixtures/d1_correct_frames.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final List<dynamic> frames = fx['frames'] as List<dynamic>;

  PoseFrame toFrame(Map<String, dynamic> f) => PoseFrame(
        tUs: 0,
        landmarks: (f['landmarks'] as List<dynamic>)
            .map((dynamic l) => PoseLandmark(
                  (l as List<dynamic>)[0] as double,
                  l[1] as double,
                  l[2] as double,
                  l[3] as double,
                ))
            .toList(),
      );

  FrameSize sizeOf(Map<String, dynamic> f) {
    final Map<String, dynamic> s = f['frameSize'] as Map<String, dynamic>;
    return FrameSize(s['width'] as int, s['height'] as int);
  }

  ({int rejected, int total}) measure(
      {double? bilateralTolerance, bool isotropic = true}) {
    int rejected = 0;
    for (final dynamic f in frames) {
      final Map<String, dynamic> m = f as Map<String, dynamic>;
      final StructuralValidator v = bilateralTolerance == null
          ? StructuralValidator()
          : StructuralValidator(bilateralTolerance: bilateralTolerance);
      final BodyOrientation expected =
          m['bucket'] == 'inv' ? BodyOrientation.inverted : BodyOrientation.upright;
      final PoseFrame frame = isotropic
          ? toIsotropic(toFrame(m), sizeOf(m))
          : toFrame(m);
      if (!v.check(frame, expected: expected).plausible) rejected++;
    }
    return (rejected: rejected, total: frames.length);
  }

  test('G-018 KAPANIŞI — çekirdek v0.2.1 varsayılanı kabul edilebilir bandta', () {
    final ({int rejected, int total}) r = measure();
    final double rate = r.rejected / r.total;
    // ignore: avoid_print
    print('v0.2.1 varsayılanı (bilateralTolerance 0.55) → yanlış-red '
        '${r.rejected}/${r.total} (${(rate * 100).round()}%)');
    expect(rate, lessThan(0.10),
        reason: 'v0.1.0 varsayılanı (0.35) %32 reddediyordu — ürünü '
            '"analiz edemedim" duvarına kilitliyordu');
  });

  test('J-028 düzeltmesi yanlış-redlerin bir kısmını AYRICA açıklıyor', () {
    // Aynı tolerans, iki uzay: fark tamamen en-boy çarpıklığından gelir.
    final double raw035 =
        measure(bilateralTolerance: 0.35, isotropic: false).rejected / frames.length;
    final double iso035 =
        measure(bilateralTolerance: 0.35, isotropic: true).rejected / frames.length;
    // ignore: avoid_print
    print('0.35 toleransında — HAM uzay ${(raw035 * 100).round()}% · '
        'İZOTROPİK ${(iso035 * 100).round()}%');
    expect(iso035, lessThan(raw035),
        reason: 'G-018 ölçümümün bir kısmı perspektif değil J-028 çarpıklığıydı');
  });

  test('#21 takası, gevşetilmiş toleransta bile yakalanmaya devam ediyor', () {
    // Toleransı gevşetmenin bedeli, gerçek hatayı kaçırmak OLMAMALI.
    final Map<String, dynamic> root = jsonDecode(
            File('test/fixtures/d1_axis_swap.json').readAsStringSync())
        as Map<String, dynamic>;
    final Map<String, dynamic> swap = (root['cases'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((Map<String, dynamic> c) => c['id'] == 'd1_axis_swap_021');
    final PoseFrame wrong = PoseFrame(
      tUs: 0,
      landmarks: ((swap['wrong'] as Map<String, dynamic>)['landmarks']
              as List<dynamic>)
          .map((dynamic l) => PoseLandmark((l as List<dynamic>)[0] as double,
              l[1] as double, l[2] as double, l[3] as double))
          .toList(),
    );
    final StructuralCheck check = StructuralValidator(bilateralTolerance: 0.60)
        .check(wrong, expected: BodyOrientation.inverted);
    expect(check.plausible, isFalse,
        reason: 'eksen denetimi toleranstan bağımsız çalışıyor: ${check.detail}');
  });
}
