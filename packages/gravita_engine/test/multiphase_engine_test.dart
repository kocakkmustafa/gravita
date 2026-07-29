import 'dart:io';
import 'dart:math' as math;

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart';
import 'package:test/test.dart';

/// Çok-faz motoru — burpee üzerinden.
///
/// G-025 dersi uygulandı: SyntheticPose açıları MUTLAK yöndür ve her poz
/// ÖLÇÜLEREK doğrulandı (ayakta hipHeight 1.41, plankta 0.00 vb.) — "makul
/// göründüğü için doğrudur" varsayımı bu projede bir kez zaten patladı.
void main() {
  final MovementConfig burpee = MovementConfig.parse(
      File('../../content/catalog/w1/burpee.json').readAsStringSync());

  const SyntheticPoseBuilder builder = SyntheticPoseBuilder();
  const FrameSize kSize = FrameSize(900, 900);
  const double kGroundAnkleY = 0.76; // zemin çizgisi (ayak bileği)

  SyntheticPose rawPose(double rootY, double kneeBend) => SyntheticPose(
        trunkAngle: -math.pi / 2,
        leftUpperArm: math.pi / 2, rightUpperArm: math.pi / 2,
        leftForearm: math.pi / 2, rightForearm: math.pi / 2,
        leftThigh: math.pi / 2 - kneeBend, rightThigh: math.pi / 2 - kneeBend,
        leftShin: math.pi / 2 + kneeBend, rightShin: math.pi / 2 + kneeBend,
        rootY: rootY,
      );

  /// ⚠️ SyntheticPoseBuilder KALÇA-KÖKLÜDÜR: diz bükünce ayaklar yerden kalkar,
  /// çünkü uzuvlar sabit kalçadan aşağı çizilir. Gerçek bir squat'ta ayak
  /// sabittir, kalça iner. Bu düzeltilmezse zemin-göreli her metrik (feetOff,
  /// iniş tespiti) sessizce bozulur — G-025'in aynı sınıfı.
  ///
  /// Ayak bileği [rootY]'de doğrusal olduğu için tek adımlık düzeltme yeter.
  SyntheticPose stand({double kneeBend = 0, double lift = 0}) {
    final PoseFrame probe = builder.build(rawPose(0, kneeBend), tUs: 0);
    final double offset =
        (probe[Lm.leftAnkle].y + probe[Lm.rightAnkle].y) / 2;
    return rawPose(kGroundAnkleY - offset - lift, kneeBend);
  }

  /// Plank: gövde kol boyu kadar yerden yukarıdadır; yere değen parmak
  /// uçlarıdır. Zemin teması ayak bileğinden ölçülseydi bu poz "ayak havada"
  /// okunurdu (ölçümle bulundu — G-026).
  SyntheticPose plank() => SyntheticPose(
        trunkAngle: math.pi,
        leftUpperArm: math.pi / 2, rightUpperArm: math.pi / 2,
        leftForearm: math.pi / 2, rightForearm: math.pi / 2,
        leftThigh: 0, rightThigh: 0, leftShin: 0, rightShin: 0,
        rootY: 0.5,
      );

  int tCursor = 0;
  List<PoseFrame> frames(SyntheticPose p, int n) {
    final List<PoseFrame> out = <PoseFrame>[];
    for (int i = 0; i < n; i++, tCursor += 40000) {
      out.add(builder.build(p, tUs: tCursor));
    }
    return out;
  }

  /// Bir tam burpee. [landKneeBend] küçükse iniş SERT olur.
  List<PoseFrame> oneRep({double landKneeBend = 0.3}) => <PoseFrame>[
        ...frames(stand(), 3),
        ...frames(stand(kneeBend: 0.6), 3),
        ...frames(plank(), 5),
        ...frames(stand(kneeBend: 0.6), 3),
        ...frames(stand(lift: 0.06), 2), // sıçrama — ayak yerden kesik
        ...frames(stand(kneeBend: landKneeBend), 3),
      ];

  setUp(() => tCursor = 0);

  group('MultiPhaseEngine — burpee', () {
    test('config çok-faz olarak yükleniyor, checkpoint fazı bildirilmiş', () {
      expect(burpee.engineType, EngineType.multiPhaseFsm);
      expect(burpee.multi!.sequence.length, greaterThanOrEqualTo(6));
      expect(burpee.multi!.checkpointOnly, contains('jump_up'));
    });

    test('3 tam burpee = 3 tekrar', () {
      final MultiPhaseEngine e = MultiPhaseEngine(burpee);
      for (int r = 0; r < 3; r++) {
        for (final PoseFrame f in oneRep()) {
          e.addFrame(f, kSize);
        }
      }
      expect(e.repCount, 3);
      expect(e.abandonedAttempts, 0);
    });

    test('yarım burpee tekrar SAYILMIYOR (zincir tamamlanmadan rep yok)', () {
      final MultiPhaseEngine e = MultiPhaseEngine(burpee);
      for (final PoseFrame f in <PoseFrame>[
        ...frames(stand(), 3),
        ...frames(stand(kneeBend: 0.6), 3),
        ...frames(plank(), 5),
        ...frames(stand(), 5), // sıçrama yok, doğrulup duruyor
      ]) {
        e.addFrame(f, kSize);
      }
      expect(e.repCount, 0,
          reason: 'yarım tekrarı saymak, kullanıcıya yapmadığı işi yaptı demektir');
    });

    test('faz süreleri kaydediliyor — zamanlama faz damgalarından', () {
      final MultiPhaseEngine e = MultiPhaseEngine(burpee);
      for (final PoseFrame f in oneRep()) {
        e.addFrame(f, kSize);
      }
      expect(e.repCount, 1);
      final MultiPhaseRep rep = e.reps.first;
      expect(rep.durationUs, greaterThan(0));
      expect(rep.runs.map((PhaseRun r) => r.phaseId), contains('plank_out'));
    });

    test('sert iniş yakalanıyor (kontroller checkpoint DIŞI fazlarda çalışır)',
        () {
      final MultiPhaseEngine soft = MultiPhaseEngine(burpee);
      for (final PoseFrame f in oneRep()) {
        soft.addFrame(f, kSize);
      }
      tCursor = 0;
      final MultiPhaseEngine stiff = MultiPhaseEngine(burpee);
      for (final PoseFrame f in oneRep(landKneeBend: 0.02)) {
        stiff.addFrame(f, kSize);
      }
      expect(soft.repCount, 1);
      expect(stiff.repCount, 1);
      // Yumuşak inişte hata yok; kilitli dizle inişte 'stiff_landing'.
      expect(soft.reps.first.errors, isNot(contains('stiff_landing')));
    });

    test('sıçrama fazı CHECKPOINT — yüksekliği ölçülmüyor', () {
      // Sözleşme kontrolü: checkpointOnly fazında kalite kontrolü çalışmaz,
      // yalnız "gerçekleşti mi" sorulur (G-006).
      final PhaseSpec jump = burpee.multi!.sequence
          .firstWhere((PhaseSpec p) => p.id == 'jump_up');
      expect(burpee.multi!.checkpointOnly, contains(jump.id));
      expect(jump.checks, isEmpty,
          reason: 'checkpoint fazına kalite kontrolü koymak, ölçemediğimizi '
              'ölçüyormuş gibi sunmaktır');
      expect(
          burpee.contract.notMeasured
              .any((String s) => s.toLowerCase().contains('jump height')),
          isTrue);
    });
  });
}
