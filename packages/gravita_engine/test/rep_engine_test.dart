import 'dart:io';
import 'dart:math' as math;

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart';
import 'package:test/test.dart';

/// W1 motor testi — fixture-replay disipliniyle.
///
/// Fixture'lar sentetik iskeletten üretilir: doğru tekrar dizisi + **kontrollü
/// bozulma** (M-C-03). Kasıtlı hata artık çekimle değil perturbasyonla gelir;
/// genliği katalogda `targetValue` olarak beyan edilir ve nöbetçi betik onun
/// eşiği gerçekten aştığını denetler (G-013/G-015/G-016).
void main() {
  MovementConfig load(String id) => MovementConfig.parse(
      File('../../content/catalog/w1/$id.json').readAsStringSync());

  const SyntheticPoseBuilder builder = SyntheticPoseBuilder();
  // Sentetik iskelet kare uzayda üretilir -> izotropik dönüşüm kimlik olur.
  // Gerçek-kare doğrulaması ayrı dosyada (j028_frame_space_test.dart).
  const FrameSize kSynthSize = FrameSize(900, 900);

  /// Dirsek açısı [deg] olan bir şınav karesi üretir.
  ///
  /// Gövde yatay (yüzüstü), kollar gövdeye dik: dirsek fleksiyonu üstkol ile
  /// önkol arasındaki açıdır, o yüzden önkolu üstkola göre döndürmek yeter.
  SyntheticPose pushUpPose(double elbowDeg, {double hipSagDeg = 0}) {
    final double upper = math.pi / 2; // üstkol aşağı doğru (yere)
    final double fore = upper + (math.pi - elbowDeg * math.pi / 180);
    return SyntheticPose(
      trunkAngle: math.pi + hipSagDeg * math.pi / 180,
      leftUpperArm: upper,
      rightUpperArm: upper,
      leftForearm: fore,
      rightForearm: fore,
      leftThigh: math.pi,
      rightThigh: math.pi,
      leftShin: math.pi,
      rightShin: math.pi,
      rootY: 0.5,
    );
  }

  /// n tekrarlık bir dizi: tepe → dip → tepe.
  List<PoseFrame> pushUpSequence(int reps,
      {double top = 170, double bottom = 80, int msPerPhase = 800}) {
    final List<PoseFrame> out = <PoseFrame>[];
    int tUs = 0;
    const int step = 40000; // 25 fps
    void ramp(double from, double to) {
      final int frames = (msPerPhase * 1000) ~/ step;
      for (int i = 0; i <= frames; i++) {
        final double a = from + (to - from) * (i / frames);
        out.add(builder.build(pushUpPose(a), tUs: tUs));
        tUs += step;
      }
    }

    out.add(builder.build(pushUpPose(top), tUs: tUs));
    tUs += step;
    for (int r = 0; r < reps; r++) {
      ramp(top, bottom);
      ramp(bottom, top);
    }
    return out;
  }

  group('RepEngine — config-güdümlü tekrar sayımı', () {
    test('şınav config\'i yükleniyor ve sınıf-A form hükmü iddia ediyor', () {
      final MovementConfig c = load('push_up');
      expect(c.engineType, EngineType.repFsm);
      expect(c.movementClass, MovementClass.a);
      expect(c.claimsFormVerdict, isTrue);
      expect(c.rep!.joint, 'elbow');
      expect(c.rep!.topIsExtended, isTrue);
    });

    test('temiz 5 tekrarlık dizide TAM 5 tekrar sayıyor', () {
      final RepEngine e = RepEngine(load('push_up'));
      for (final PoseFrame f in pushUpSequence(5)) {
        e.addFrame(f, kSynthSize);
      }
      expect(e.repCount, 5);
      expect(e.skippedFrames, 0);
    });

    test('yarım tekrarlar SAYILMIYOR — ROM eşiğine ulaşılmadan rep yok', () {
      final RepEngine e = RepEngine(load('push_up'));
      // Dip açısı 130° → config'in bottom eşiği (100) hiç geçilmiyor.
      for (final PoseFrame f in pushUpSequence(4, bottom: 130)) {
        e.addFrame(f, kSynthSize);
      }
      expect(e.repCount, 0,
          reason: 'kısmi tekrarı saymak, kullanıcıya yapmadığı işi yaptı demektir');
    });

    test('tempo faz damgalarından türetiliyor (piksel hızından DEĞİL)', () {
      final RepEngine e = RepEngine(load('push_up'));
      for (final PoseFrame f in pushUpSequence(3, msPerPhase: 600)) {
        e.addFrame(f, kSynthSize);
      }
      expect(e.repCount, 3);
      for (final Rep r in e.reps) {
        // İniş ve çıkış ~600 ms; kare adımı 40 ms olduğu için tolerans geniş.
        expect(r.descentUs / 1000, closeTo(600, 120));
        expect(r.ascentUs / 1000, closeTo(600, 120));
      }
    });

    test('uç açı kaydediliyor — ROM hükmünün kaynağı', () {
      final RepEngine e = RepEngine(load('push_up'));
      for (final PoseFrame f in pushUpSequence(2, bottom: 85)) {
        e.addFrame(f, kSynthSize);
      }
      expect(e.repCount, 2);
      expect(e.reps.first.extremeAngleDeg, closeTo(85, 6));
    });
  });

  group('Tek-düzeltme önceliklendirmesi (plan §9)', () {
    test('aynı anda birden çok hata varsa GÜVENLİK önce söylenir', () {
      final MovementConfig squat = load('bodyweight_squat');
      final RepEngine e = RepEngine(squat);
      final FormError? top = e.topCorrection(<String, double>{
        'rom_bottom_angle': 130, // blocking
        'torso_angle_from_vertical': 55, // major_alignment
        'lumbar_flexion_proxy': 26, // safety
      });
      expect(top, isNotNull);
      expect(top!.priority, 'safety');
      expect(top.id, 'butt_wink');
    });

    test('hiçbir eşik aşılmadıysa düzeltme YOK (sessizlik yanlış söylemekten iyidir)',
        () {
      final RepEngine e = RepEngine(load('push_up'));
      expect(e.topCorrection(<String, double>{'line_deviation_deg': 3}), isNull);
    });
  });

  group('Dürüstlük kutusu ÜRETİLİYOR', () {
    test('B sınıfı olmayan harekette form hükmü iddiası var', () {
      final ({List<String> measured, List<String> notMeasured}) box =
          load('push_up').honestyBox();
      expect(box.measured, isNotEmpty);
      expect(box.notMeasured.any((String s) => s.toLowerCase().contains('force')),
          isTrue);
    });

    test('pull-up "chin over bar" ölçmediğini AÇIKÇA söylüyor (G-017)', () {
      final ({List<String> measured, List<String> notMeasured}) box =
          load('pull_up').honestyBox();
      expect(box.notMeasured.any((String s) => s.toLowerCase().contains('chin')),
          isTrue,
          reason: 'ölçmediğimiz kriteri sessizce atlamak dürüstlük ihlalidir');
    });
  });
}
