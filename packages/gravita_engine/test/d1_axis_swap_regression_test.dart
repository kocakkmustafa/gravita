import 'dart:convert';
import 'dart:io';

import 'package:motion_core/motion_core.dart';
import 'package:test/test.dart';

/// G-002 / G-003 doğrulaması — motion_core **v0.1.0**'a karşı.
///
/// Bu dosya API'nin var olduğunu değil, **D1 kapısında ölçülen gerçek hatanın**
/// motora ulaşıp ulaşmadığını sınar. Fixture, Wikimedia Commons görüntülerinden
/// çıkarılmış GERÇEK landmark'lardır: MediaPipe üç karede ters vücudu dik sanıp
/// kol↔bacak zincirlerini takas etti — bunu yüksek güvenle yaparak.
///
/// Testler ÖLÇÜLEN davranışı sabitler (temenni edilen davranışı değil). Çekirdek
/// iyileştiğinde bu beklentiler kırılır ve bilinçli olarak güncellenir — sessizce
/// "zaten geçiyordu" durumuna düşmez.
void main() {
  final Map<String, dynamic> fx = jsonDecode(
    File('test/fixtures/d1_axis_swap.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final List<dynamic> cases = fx['cases'] as List<dynamic>;

  PoseFrame frameOf(Map<String, dynamic> pass, String modelVersion) => PoseFrame(
        tUs: 0,
        modelVersion: modelVersion,
        landmarks: (pass['landmarks'] as List<dynamic>)
            .map((dynamic l) => PoseLandmark(
                  (l as List<dynamic>)[0] as double,
                  l[1] as double,
                  l[2] as double,
                  l[3] as double,
                ))
            .toList(),
      );

  Map<String, dynamic> caseById(String id) => cases
      .cast<Map<String, dynamic>>()
      .firstWhere((Map<String, dynamic> c) => c['id'] == id);

  group('D1 — kanıt: güven kapısı yetmez, yapısal denetim gerekir', () {
    // #21 BELİRLEYİCİ VAKA: güven kapısı geçiriyor, yapısal denetim yakalıyor.
    // Tek bir yüksek-güvenli takasın kapıdan geçmesi, kapının tek başına
    // yetersiz olduğunu KANITLAMAYA yeter.
    final Map<String, dynamic> c21 = caseById('d1_axis_swap_021');
    final String mv = c21['modelVersion'] as String;

    test('#21 güven kapısı takası GEÇİRİYOR (vis_crit 0.93)', () {
      final FrameQuality q = ConfidenceGate.forVariant(PoseModelVariant.full)
          .evaluate(frameOf(c21['wrong'] as Map<String, dynamic>, mv));
      expect(q.judgeable, isTrue,
          reason: 'kapı bunu reddetseydi "güven ≠ doğruluk" bulgusu çürürdü');
    });

    test('#21 yapısal denetim takası REDDEDİYOR', () {
      final StructuralCheck check = StructuralValidator().check(
          frameOf(c21['wrong'] as Map<String, dynamic>, mv),
          expected: BodyOrientation.inverted);
      expect(check.plausible, isFalse, reason: check.detail);
    });

    test('#53 yapısal denetim takası REDDEDİYOR', () {
      final Map<String, dynamic> c = caseById('d1_axis_swap_053');
      final StructuralCheck check = StructuralValidator().check(
          frameOf(c['wrong'] as Map<String, dynamic>, c['modelVersion'] as String),
          expected: BodyOrientation.inverted);
      expect(check.plausible, isFalse, reason: check.detail);
    });
  });

  group('D1 — v0.1.0 boşlukları (ölçülmüş; çekirdek geri bildirimi)', () {
    test('G-019: gövde neredeyse YATAY olduğunda eksen testi çekimser kalıyor '
        've takas yakalanmıyor (#9)', () {
      final Map<String, dynamic> c = caseById('d1_axis_swap_009');
      final PoseFrame wrong =
          frameOf(c['wrong'] as Map<String, dynamic>, c['modelVersion'] as String);
      // Yanlış etiketli karede baş ile kalça neredeyse aynı yükseklikte
      // (ölçüm: nose.y 0.435 vs hip.y 0.440) -> eksen okuması bilgi taşımıyor.
      final StructuralCheck check =
          StructuralValidator().check(wrong, expected: BodyOrientation.inverted);
      expect(check.plausible, isTrue,
          reason: 'v0.1.0 bu vakayı KAÇIRIYOR — düzeltilirse bu beklenti '
              'kırılır ve G-019 kapatılır');
    });
  });
}
