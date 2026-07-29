import 'dart:io';
import 'dart:math' as math;

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;
import 'package:test/test.dart';

/// Statik tutuş motoru — plank üzerinden.
///
/// Fixture'lar sentetik iskeletten üretilir ve kasıtlı hata **kontrollü
/// bozulmayla** gelir (M-C-03): kalça açısını katalogdaki `targetValue`a taşırız,
/// böylece fixture sınadığı toleransı gerçekten aşar (G-013).
void main() {
  MovementConfig load(String id) => MovementConfig.parse(
      File('../../content/catalog/w1/$id.json').readAsStringSync());

  const SyntheticPoseBuilder builder = SyntheticPoseBuilder();
  const FrameSize kSize = FrameSize(900, 900);

  /// Yüzüstü plank.
  ///
  /// SyntheticPose açıları MUTLAK yöndür (y aşağı). Omuzlar −x'te (π), bacaklar
  /// +x'te (0) — ikisi ters yöne bakmazsa vücut ikiye katlanır.
  /// [sagDeg] > 0: omuz ve ayak bileği yukarı kalkar, kalça hattın ALTINDA kalır.
  SyntheticPose plankPose(double sagDeg) {
    final double s = sagDeg * math.pi / 180;
    return SyntheticPose(
      trunkAngle: math.pi + s,
      leftUpperArm: math.pi / 2,
      rightUpperArm: math.pi / 2,
      leftForearm: math.pi / 2,
      rightForearm: math.pi / 2,
      leftThigh: -s,
      rightThigh: -s,
      leftShin: -s,
      rightShin: -s,
      rootY: 0.5,
    );
  }

  List<PoseFrame> hold(double sagDeg, int seconds, {int startUs = 0}) {
    final List<PoseFrame> out = <PoseFrame>[];
    for (int i = 0; i * 40000 <= seconds * 1000000; i++) {
      out.add(builder.build(plankPose(sagDeg), tUs: startUs + i * 40000));
    }
    return out;
  }

  group('HoldEngine — plank', () {
    test('config staticHold olarak yükleniyor', () {
      final MovementConfig c = load('plank');
      expect(c.engineType, EngineType.staticHold);
      expect(c.hold!.formBreaks, isNotEmpty);
      expect(c.hold!.entry, isNotEmpty);
    });

    test('temiz tutuşta süre işliyor, kırılma YOK', () {
      final HoldEngine e = HoldEngine(load('plank'));
      for (final PoseFrame f in hold(0, 10)) {
        e.addFrame(f, kSize);
      }
      expect(e.state, HoldState.holding);
      expect(e.breaks, isEmpty);
      expect(e.holdDurationUs / 1e6, greaterThan(8));
      expect(e.isValid, isTrue);
      expect(e.timeToFirstBreakUs, isNull);
    });

    test('kalça düştüğünde kırılma yakalanıyor ve tutuş bitiyor', () {
      final MovementConfig cfg = load('plank');
      final HoldEngine e = HoldEngine(cfg);
      // 6 sn temiz, sonra katalogdaki perturbasyon hedefine bozulma:
      // parametre 11° → ölçülen hat sapması 22° (katalogdaki targetValue).
      for (final PoseFrame f in hold(0, 6)) {
        e.addFrame(f, kSize);
      }
      final int t0 = 6 * 1000000 + 40000;
      for (final PoseFrame f in hold(11, 4, startUs: t0)) {
        e.addFrame(f, kSize);
      }
      expect(e.breaks, isNotEmpty);
      expect(e.breaks.first.id, 'hip_sag');
      expect(e.breaks.first.endedHold, isTrue,
          reason: 'plank config\'inde hip_sag warn_then_end');
      expect(e.state, HoldState.ended);
      // "Ne kadar TEMİZ dayandın" — asıl öğretici sayı bu.
      expect(e.timeToFirstBreakUs! / 1e6, closeTo(7.5, 1.5));
    });

    test('kırılma SÜRE şartını dolduruncaya kadar tetiklenmiyor', () {
      final HoldEngine e = HoldEngine(load('plank'));
      for (final PoseFrame f in hold(0, 6)) {
        e.addFrame(f, kSize);
      }
      // sustainedMs 1500 → 0.6 sn'lik anlık bozulma kırılma SAYILMAZ.
      int t = 6 * 1000000 + 40000;
      for (int i = 0; i < 15; i++, t += 40000) {
        e.addFrame(builder.build(plankPose(11), tUs: t), kSize);
      }
      expect(e.breaks, isEmpty,
          reason: 'anlık salınımı form kırılması saymak yanlış-pozitif üretir');
      expect(e.state, HoldState.holding);
    });

    test('tutuşa GİRİLMEDEN süre işlemiyor', () {
      final HoldEngine e = HoldEngine(load('plank'));
      // Giriş şartı line_deviation ≤10; parametre 15° → 30° sapma, hiç başlamamalı.
      for (final PoseFrame f in hold(15, 5)) {
        e.addFrame(f, kSize);
      }
      expect(e.state, HoldState.waiting);
      expect(e.holdDurationUs, 0);
      expect(e.isValid, isFalse);
    });
  });

  _w2();

  group('MovementMetrics', () {
    test('düz plankta hat sapması ~0, kalça düşünce POZİTİF', () {
      final MovementMetrics flat =
          MovementMetrics.of(builder.build(plankPose(0), tUs: 0).toIsotropic(kSize));
      final MovementMetrics sag =
          MovementMetrics.of(builder.build(plankPose(10), tUs: 0).toIsotropic(kSize));
      expect(flat.lineDeviationDeg.abs(), lessThan(3));
      expect(sag.lineDeviationDeg, greaterThan(5),
          reason: 'işaret sözleşmesi: + = kalça hattın altında (sag)');
    });

    test('bilinmeyen metrik null döner — sessizce 0 DEĞİL', () {
      final MovementMetrics m =
          MovementMetrics.of(builder.build(plankPose(0), tUs: 0).toIsotropic(kSize));
      expect(m.byName('cadence_spm'), isNull);
      expect(m.byName('line_deviation_deg'), isNotNull);
    });
  });
}

/// W2 — ters yönelimli tutuş (chest-to-wall handstand).
///
/// D1'in ürüne dönüştüğü yer: `expectedOrientation: inverted` bir MOTOR TİPİ
/// değil, HoldEngine'in aynı kodla çalıştırdığı bir yönelim niteliği. Motor
/// yapısal denetime beklentiyi geçirir; geçirmezse model kol↔bacak etiketlerini
/// yüksek güvenle takas edebilir (D1'de ölçüldü).
void _w2() {
  test('wall_handstand ters yönelim BEYAN ediyor ve yapısal denetim şart', () {
    final MovementConfig c = MovementConfig.parse(
        File('../../content/catalog/w2/wall_handstand.json').readAsStringSync());
    expect(c.engineType, EngineType.staticHold,
        reason: 'ters-duruş bir zaman yapısı değil, yönelim niteliği');
    expect(c.isInverted, isTrue);
    expect(c.hold, isNotNull, reason: 'tutuş motoru aynı kodla çalışmalı');
    expect(c.hold!.formBreaks.map((FormBreak b) => b.id),
        containsAll(<String>['banana_back', 'bent_elbows']));
  });

  test('floor_press sınıf B — form hükmü İDDİA ETMİYOR', () {
    final MovementConfig c = MovementConfig.parse(
        File('../../content/catalog/w2/floor_press.json').readAsStringSync());
    expect(c.movementClass, MovementClass.b);
    expect(c.claimsFormVerdict, isFalse);
    final ({List<String> measured, List<String> notMeasured}) box = c.honestyBox();
    expect(box.notMeasured.any((String s) => s.toLowerCase().contains('form verdict')),
        isTrue, reason: 'B sınıfında "form hükmü yok" kullanıcıya AÇIKÇA söylenir');
    expect(box.measured.any((String s) => s.toLowerCase().contains('form')), isFalse);
  });
}
