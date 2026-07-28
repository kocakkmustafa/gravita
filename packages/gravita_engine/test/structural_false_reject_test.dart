import 'dart:convert';
import 'dart:io';

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

  ({int rejected, int total}) measure({required double bilateralTolerance}) {
    int rejected = 0;
    for (final dynamic f in frames) {
      final Map<String, dynamic> m = f as Map<String, dynamic>;
      final StructuralValidator v =
          StructuralValidator(bilateralTolerance: bilateralTolerance);
      final BodyOrientation expected =
          m['bucket'] == 'inv' ? BodyOrientation.inverted : BodyOrientation.upright;
      if (!v.check(toFrame(m), expected: expected).plausible) rejected++;
    }
    return (rejected: rejected, total: frames.length);
  }

  test('varsayılan tolerans (0.35) doğru karelerin üçte birini reddediyor', () {
    final ({int rejected, int total}) r = measure(bilateralTolerance: 0.35);
    final double rate = r.rejected / r.total;
    // ignore: avoid_print
    print('varsayılan 0.35 → yanlış-red ${r.rejected}/${r.total} '
        '(${(rate * 100).round()}%)');
    expect(rate, greaterThan(0.20),
        reason: 'ölçülen taban ~%32; bu beklenti çekirdek düzelince kırılır');
  });

  test('tolerans gevşetilince yanlış-red düşüyor — sorun eşikte, mimaride değil',
      () {
    final double at35 = measure(bilateralTolerance: 0.35).rejected / frames.length;
    final double at60 = measure(bilateralTolerance: 0.60).rejected / frames.length;
    // ignore: avoid_print
    print('0.35 → ${(at35 * 100).round()}%   |   0.60 → ${(at60 * 100).round()}%');
    expect(at60, lessThan(at35));
  });

  test('#21 takası, gevşetilmiş toleransta bile yakalanmaya devam ediyor', () {
    // Toleransı gevşetmenin bedeli, gerçek hatayı kaçırmak OLMAMALI.
    final Map<String, dynamic> swap = (jsonDecode(
                File('test/fixtures/d1_axis_swap.json').readAsStringSync())
            as Map<String, dynamic>)['cases']
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
