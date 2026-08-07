import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/live_session.dart';
import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_camera/motion_camera.dart';
import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;

/// CANLI YOL testi — kamera DONANIMI olmadan, ama TAKLİT olmadan.
///
/// Cihaz doğrulaması isimli bir release-gate (M-F-263); o güne kadar canlı
/// yolun doğruluğu YALNIZ burada kanıtlanabilir. Bu yüzden test sahte bir
/// "runner taklidi" kurmuyor: **gerçek** `LiveSessionRunner`, **gerçek**
/// `EnvelopeDriver`, **gerçek** `OrientationAwarePoseSource` ve **gerçek**
/// `RepEngine` üzerinden geçiyor. Sahte olan tek şey zarfların KAYNAĞI —
/// native kamera yerine sentetik iskelet.
///
/// ⚠️ Bu testin kanıtlamadığı şey ADIYLA durur: native katman (izin akışı,
/// MediaPipe çıkarımı, saat alanı, kare düşürme). Onlar cihaz-günü işi ve
/// buradaki hiçbir yeşil onlar hakkında bir şey SÖYLEMEZ.
void main() {
  final MovementConfig pushUp = MovementConfig.parse(
      File('packages/gravita_engine/../../content/catalog/w1/push_up.json')
          .readAsStringSync());

  const SyntheticPoseBuilder builder = SyntheticPoseBuilder();
  const FrameSize size = FrameSize(900, 900);

  SyntheticPose pushUpPose(double elbowDeg) {
    final double upper = math.pi / 2;
    final double fore = upper + (math.pi - elbowDeg * math.pi / 180);
    return SyntheticPose(
      trunkAngle: math.pi,
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

  /// Sentetik kareyi GERÇEK zarf tipine sarar — plugin'in ürettiğiyle aynı
  /// sınıf, aynı alanlar. `uprightOnly` plan: tek geçiş koştu.
  CameraFrameEnvelope envelope(PoseFrame frame, int tUs, {int dropped = 0}) =>
      CameraFrameEnvelope(
        tUs: tUs,
        size: size,
        modelVersion: 'pose_landmarker_full/float16/1',
        clockDomain: ClockDomain.monotonic,
        inferenceUs: 8000,
        dropped: dropped,
        passes: <BodyOrientation, PoseFrame?>{BodyOrientation.upright: frame},
      );

  /// Kişinin görünmediği kare: geçiş KOŞTU ama model kimseyi bulamadı.
  CameraFrameEnvelope emptyEnvelope(int tUs) => CameraFrameEnvelope(
        tUs: tUs,
        size: size,
        modelVersion: 'pose_landmarker_full/float16/1',
        clockDomain: ClockDomain.monotonic,
        inferenceUs: 5000,
        dropped: 0,
        passes: const <BodyOrientation, PoseFrame?>{
          BodyOrientation.upright: null
        },
      );

  List<PoseFrame> pushUpSequence(int reps, {double bottom = 80}) {
    final List<PoseFrame> out = <PoseFrame>[];
    int tUs = 0;
    void hold(double deg, int steps) {
      for (int i = 0; i < steps; i++) {
        out.add(builder.build(pushUpPose(deg), tUs: tUs));
        tUs += 40000;
      }
    }

    // ⚠️ İniş basamakları `bottom`a göre TÜRETİLİR, sabit yazılmaz. İlk
    // yazışımda basamaklar sabitti (150/120/100) ve sığ vaka için `bottom`u
    // 140 yapmak hiçbir şeyi değiştirmiyordu: ara basamak 100 zaten dip
    // eşiğini (katalogda 116°) geçiyordu. Yani "sığ" dizim aslında DERİN bir
    // tekrardı ve motor onu haklı olarak saydı — testin kendisi kırıktı.
    hold(170, 6);
    for (int r = 0; r < reps; r++) {
      final List<double> down = <double>[
        170 - (170 - bottom) * 0.33,
        170 - (170 - bottom) * 0.66,
        bottom,
      ];
      for (final double d in down) {
        hold(d, 3);
      }
      for (final double d in down.reversed) {
        hold(d, 3);
      }
      hold(170, 3);
    }
    return out;
  }

  group('canlı yol: zarf → sürücü → kaynak → motor', () {
    test('gerçek tekrar dizisi CANLI yoldan geçince SAYILIYOR', () {
      final LiveSessionRunner runner =
          LiveSessionRunner(config: pushUp, frameSize: size);
      int t = 0;
      for (final PoseFrame f in pushUpSequence(3)) {
        runner.consume(envelope(f, t));
        t += 40000;
      }
      expect(runner.reps.length, 3,
          reason: 'Canlı yol tekrarı düşürüyor ya da uyduruyor.');
      expect(runner.personVisible, isTrue);
      expect(runner.framesSeen, greaterThan(0));
    });

    test('POZİTİF İKİZ: sığ tekrarlar SAYILMIYOR (eşik canlı yolda da geçerli)',
        () {
      // Bu ikiz olmadan üstteki test, motor her diziye 3 dese de geçerdi.
      final LiveSessionRunner runner =
          LiveSessionRunner(config: pushUp, frameSize: size);
      int t = 0;
      for (final PoseFrame f in pushUpSequence(3, bottom: 140)) {
        runner.consume(envelope(f, t));
        t += 40000;
      }
      expect(runner.reps, isEmpty,
          reason: 'Sığ tekrarlar canlı yolda sayılıyorsa eşik kayboldu.');
    });

    test('kişi kadrajda YOKKEN çökmüyor ve tekrar UYDURMUYOR', () {
      final LiveSessionRunner runner =
          LiveSessionRunner(config: pushUp, frameSize: size);
      for (int i = 0; i < 20; i++) {
        runner.consume(emptyEnvelope(i * 40000));
      }
      expect(runner.reps, isEmpty);
      expect(runner.personVisible, isFalse,
          reason: '"Kimse yok" hâli kaybolursa yüzey sessiz kalır.');
      expect(runner.framesSeen, 20,
          reason: 'Görülmeyen kareler de SAYILIR — payda dürüst kalmalı.');
    });

    test('kişi kaybolup GERİ GELİNCE hâl geri dönüyor', () {
      // "personVisible" yapışkan olsaydı, kadraj dışına çıkan kullanıcı
      // yüzeyde hâlâ "görünüyor" diye kalırdı.
      final LiveSessionRunner runner =
          LiveSessionRunner(config: pushUp, frameSize: size);
      final List<PoseFrame> seq = pushUpSequence(1);
      int t = 0;
      runner.consume(envelope(seq.first, t));
      expect(runner.personVisible, isTrue);
      t += 40000;
      runner.consume(emptyEnvelope(t));
      expect(runner.personVisible, isFalse);
      t += 40000;
      runner.consume(envelope(seq.first, t));
      expect(runner.personVisible, isTrue);
    });

    test('düşen kareler zarfta TAŞINIYOR — "kamera modeli geçti" gizlenmiyor',
        () {
      // `dropped` native'in ölçtüğü gerçektir; runner onu yutmamalı.
      final CameraFrameEnvelope e =
          envelope(pushUpSequence(1).first, 0, dropped: 7);
      expect(e.dropped, 7);
    });
  });

  group('dürüst hâller TİPLİ', () {
    test('izin reddi ADIYLA taşınıyor, ham metin BİRİNCİL değil', () {
      const LiveState s = LiveFailed(CameraFailure.permissionDenied,
          detail: 'PlatformException(camera-permission-denied)');
      expect(s, isA<LiveFailed>());
      expect((s as LiveFailed).failure, CameraFailure.permissionDenied);
      expect(s.detail, isNotNull,
          reason: 'Ayrıntı GİZLENMEZ, ikincilleştirilir (G-102).');
    });

    test('tanınmayan arıza null failure ile taşınıyor — uydurulmuyor', () {
      const LiveFailed s = LiveFailed(null, detail: 'beklenmedik');
      expect(s.failure, isNull,
          reason: 'Tanınmayan kodu bilinen bir arızaya haritalamak yalan olur.');
    });

    test('"kimse yok" bir ARIZA DEĞİL — ayrı hâl', () {
      const LiveRunning r =
          LiveRunning(reps: <Rep>[], personVisible: false, framesSeen: 5);
      expect(r, isNot(isA<LiveFailed>()),
          reason: '"Geri çekil" ile "kamera bozuk" aynı şey değildir.');
      expect(r.repCount, 0);
    });
  });

  group('G-132 — biten seansın KAYDI (serbest kova)', () {
    final DateTime t0 = DateTime.utc(2026, 8, 7, 4, 0);
    final DateTime t1 = DateTime.utc(2026, 8, 7, 4, 3, 20);

    SessionRecord? build(LiveState state, {DateTime? end}) =>
        buildFreeSessionRecord(
          movementId: 'push_up',
          state: state,
          startedAt: t0,
          endedAt: end ?? t1,
        );

    test('kare YOKSA kayıt YOK — başlatılamamış deneme seans değildir', () {
      expect(
          build(const LiveRunning(
              reps: <Rep>[], personVisible: false, framesSeen: 0)),
          isNull);
      expect(build(const LiveIdle()), isNull);
      expect(build(const LiveStarting()), isNull);
      expect(build(const LiveFailed(null)), isNull);
    });

    test('kare VAR ama tekrar YOK → KAYDEDİLİR (gerçek bir sonuçtur)', () {
      // ⚠️ Bu, "beğenmediğimiz ölçümü saklamama" kuralının somut hâli:
      // kamera çalıştı ve hiç tam tekrar sayılmadı. Kaydı düşürmek, kötü
      // giden seansı geçmişten silmek olurdu.
      final SessionRecord? r = build(const LiveRunning(
          reps: <Rep>[], personVisible: true, framesSeen: 42));
      expect(r, isNotNull);
      expect(r!.unitsCompleted, 0);
      expect(r.workedSeconds, 200);
    });

    test('kayıt SERBEST kova anahtarı taşır — ders gibi görünmez', () {
      final SessionRecord? r = build(const LiveRunning(
          reps: <Rep>[], personVisible: true, framesSeen: 10));
      expect(r!.lessonId, 'movement:push_up');
      expect(r.lessonId.startsWith('movement:'), isTrue,
          reason: 'Kova karışsa bile kaydın KENDİSİ hareket olduğunu '
              'söylemeli; sessizce ders gibi görünmemeli (G-132).');
    });

    test('plan YOK → plannedUnits 0, ve bu "başarısız" DEMEK DEĞİL', () {
      final SessionRecord? r = build(const LiveRunning(
          reps: <Rep>[], personVisible: true, framesSeen: 10));
      expect(r!.plannedUnits, 0);
      // Sayılıyor, NOT VERİLMİYOR — bugünkü gerçek.
      expect(r.lessonClass, 'measurementOnly');
    });

    test('saat geri alınmışsa NEGATİF süre yazılmaz', () {
      final SessionRecord? r = build(
          const LiveRunning(reps: <Rep>[], personVisible: true, framesSeen: 5),
          end: t0.subtract(const Duration(minutes: 5)));
      expect(r!.workedSeconds, 0);
    });
  });
}
