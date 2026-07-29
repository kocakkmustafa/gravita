import 'dart:io';
import 'dart:math' as math;

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;
import 'package:test/test.dart';

/// Perturbasyon üreteci — G-013'ün vaadinin kapanışı.
///
/// Zincir: config `targetValue` BEYAN eder → üreteç o hedefe ulaşan bozulmayı
/// ARAR ve ÖLÇER → tespit kuralı gerçekten ateşlenir. Üç halkadan biri kopsa
/// fixture "sınadığı toleransın içinde" kalır ve test hiçbir şeyi sınamadan
/// yeşil yanar (Choreia C-011).
void main() {
  MovementConfig load(String id) => MovementConfig.parse(
      File('../../content/catalog/w1/$id.json').readAsStringSync());

  const SyntheticPoseBuilder builder = SyntheticPoseBuilder();
  const FrameSize kSquare = FrameSize(900, 900);

  SyntheticPose plankPose() => SyntheticPose(
        trunkAngle: math.pi,
        leftUpperArm: math.pi / 2, rightUpperArm: math.pi / 2,
        leftForearm: math.pi / 2, rightForearm: math.pi / 2,
        leftThigh: 0, rightThigh: 0, leftShin: 0, rightShin: 0,
        rootY: 0.5,
      );

  List<PoseFrame> cleanHold(int n) => <PoseFrame>[
        for (int i = 0; i < n; i++)
          builder.build(plankPose(), tUs: i * 40000).toIsotropic(kSquare),
      ];

  group('Perturbation — hedefe ULAŞILDIĞI ölçülür', () {
    test('temiz plank hattı düz (taban ~0)', () {
      expect(MovementMetrics.of(cleanHold(1).first).lineDeviationDeg.abs(),
          lessThan(1));
    });

    test('kalça bozulması katalogdaki targetValue\'ya taşınıyor', () {
      final FormError hipSag = load('plank')
          .formErrors
          .firstWhere((FormError e) => e.id == 'hip_sag');
      expect(hipSag.perturbationTarget, 22);

      final ({List<PoseFrame> frames, double measured}) out =
          Perturbation.forError(cleanHold(60), hipSag, joint: 'hip');

      expect(out.measured, closeTo(22, 0.5),
          reason: 'üreteç hedefi varsaymaz, ÖLÇER');
      expect(hipSag.fires(out.measured), isTrue);
    });

    test('üretilen fixture HoldEngine\'de gerçekten kırılma tetikliyor', () {
      final MovementConfig plank = load('plank');
      final FormError hipSag =
          plank.formErrors.firstWhere((FormError e) => e.id == 'hip_sag');

      final HoldEngine e = HoldEngine(plank);
      // 6 sn temiz giriş, sonra bozulmuş kareler (zaman damgaları devam eder).
      for (final PoseFrame f in cleanHold(150)) {
        e.addFrame(f, kSquare);
      }
      expect(e.state, HoldState.holding);

      final List<PoseFrame> bad =
          Perturbation.forError(cleanHold(150), hipSag, joint: 'hip').frames;
      int t = 150 * 40000;
      for (final PoseFrame f in bad) {
        e.addFrame(
            PoseFrame(tUs: t, landmarks: f.landmarks, modelVersion: f.modelVersion),
            kSquare);
        t += 40000;
      }
      expect(e.breaks.map((HoldBreakEvent b) => b.id), contains('hip_sag'));
    });

    test('ULAŞILAMAYAN hedef sessizce geçmiyor — yüksek sesle patlıyor', () {
      // Fiziksel olarak erişilemez bir hedef: 179° hat sapması.
      expect(
          () => Perturbation.solveDelta(
              cleanHold(1).first, 'hip', 'line_deviation_deg', 179),
          throwsA(isA<StateError>()),
          reason: 'yaklaşık fixture üretmek C-011 tuzağının kendisidir');
    });

    test('tetiklemeyen fixture reddediliyor', () {
      final FormError weak = FormError(
        id: 'test_weak', label: 'x', priority: 'minor_form', cue: 'x',
        metric: 'line_deviation_deg', op: '>', threshold: 30,
        perturbationTarget: 10, // eşiğin ALTINDA hedef
      );
      expect(() => Perturbation.forError(cleanHold(5), weak, joint: 'hip'),
          throwsA(isA<StateError>()));
    });
  });

  group('Perturbation — distal zincir', () {
    test('döndürme pivotun PROKSİMAL tarafını bozmuyor', () {
      final PoseFrame clean = cleanHold(1).first;
      final PoseFrame bad = Perturbation.rotateDistal(clean, 'hip', 15);
      for (final int i in <int>[Lm.leftShoulder, Lm.rightShoulder, Lm.nose]) {
        expect(bad[i].x, closeTo(clean[i].x, 1e-12));
        expect(bad[i].y, closeTo(clean[i].y, 1e-12));
      }
      expect(bad[Lm.leftAnkle].y, isNot(closeTo(clean[Lm.leftAnkle].y, 1e-6)));
    });

    test('bozulmuş iskelet YAPISAL denetimden geçiyor (gerçekçi hata)', () {
      final PoseFrame bad =
          Perturbation.rotateDistal(cleanHold(1).first, 'hip', 11);
      expect(StructuralValidator().check(bad).plausible, isTrue,
          reason: 'form hatası anatomik olarak İMKÂNSIZ olmamalı — yoksa '
              'motor onu hata değil bozuk-veri sayar');
    });
  });
}
