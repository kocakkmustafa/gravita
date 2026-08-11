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

  // ⚠️ 2026-08-12 (G-176 sonrası, koordinatör hükmü): squat'ın terfisi
  // `validate_catalog`/`validate_library`in TEMİZ demesi + `RepEngine`
  // seviyesinde 30 gerçek klibin geçmesiyle kanıtlanmıştı — ama o kanıtın
  // HİÇBİRİ `LiveSessionRunner`den (zarf → sürücü → yön-farkında kaynak →
  // motor) geçmedi. "Katalog+kütüphane doğru" ile "kullanıcı bu hareketi
  // açıp bir seans yapabiliyor" AYRI cümleler — bu grup ikincisini ölçüyor.
  // GERÇEK, diskteki kataloğu okuyor: `status: derived` artık gerçek, ayrı
  // bir kopya çevirmeye GEREK yok (bkz. window_correlation_test.dart'ın
  // kendi kopyası — orada hâlâ gerekli, çünkü o mekanizmayı M-F-122'nin dış
  // kapısından İZOLE sınıyor; burada tam tersi: izolasyon DEĞİL, gerçek yol).
  final MovementConfig squat = MovementConfig.parse(File(
          'packages/gravita_engine/../../content/catalog/w1/bodyweight_squat.json')
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

  // Diz VE kalça BİRLİKTE bükülen bir squat karesi — `window_correlation_
  // test.dart`daki `coordinatedSquatPose` ile AYNI mekanizma (uyluk açısı
  // diz açısıyla orantılı değişir, gerçek harekette olduğu gibi). Burada
  // TEKRAR yazıldı çünkü iki dosya farklı amaçlarla farklı katmanları
  // sınıyor (motor izolasyonu vs. tam zarf yolu) ve ortak bir yardımcı
  // paylaşmak iki testi birbirine BAĞLARDI — biri kırılınca öteki neden
  // kırıldığını anlamazdı.
  SyntheticPose squatPose(double kneeDeg) {
    final double thighT = (175 - kneeDeg) / (175 - 95);
    final double thigh = math.pi / 2 - thighT * (math.pi / 6);
    final double shin = thigh - (math.pi - kneeDeg * math.pi / 180);
    return SyntheticPose(
      trunkAngle: -math.pi / 2,
      leftThigh: thigh,
      rightThigh: thigh,
      leftShin: shin,
      rightShin: shin,
      rootY: 0.45,
    );
  }

  List<PoseFrame> squatSequence(int reps,
      {double top = 175, double bottom = 95}) {
    final List<PoseFrame> out = <PoseFrame>[];
    int tUs = 0;
    const int step = 40000;
    void ramp(double from, double to, int msPerPhase) {
      final int frames = (msPerPhase * 1000) ~/ step;
      for (int i = 0; i <= frames; i++) {
        out.add(builder.build(
            squatPose(from + (to - from) * (i / frames)), tUs: tUs));
        tUs += step;
      }
    }

    out.add(builder.build(squatPose(top), tUs: tUs));
    tUs += step;
    for (int r = 0; r < reps; r++) {
      ramp(top, bottom, 800);
      ramp(bottom, top, 800);
    }
    return out;
  }

  group('canlı yol — bodyweight_squat GERÇEK üretim config\'iyle (G-176 sonrası ②)',
      () {
    test('gerçek tekrar dizisi CANLI yoldan geçince SAYILIYOR (squat)', () {
      // `harvestIdentityAttested` YOK — LiveSessionRunner hiç geçirmiyor,
      // yani bu tam olarak kullanıcının alacağı yol: M-F-122 dış kapısı VE
      // pencere-korelasyonu İKİSİ de gerçekten çalışıyor olmalı.
      final LiveSessionRunner runner =
          LiveSessionRunner(config: squat, frameSize: size);
      int t = 0;
      for (final PoseFrame f in squatSequence(3)) {
        runner.consume(envelope(f, t));
        t += 40000;
      }
      expect(runner.reps.length, 3,
          reason: 'squat GERÇEK üretim yolunda (harvestIdentityAttested '
              'YOK) canlı zarftan tekrar üretemiyor — terfi katalog/kütüphane '
              'seviyesinde doğru olsa da kullanıcı bir seans YAPAMAZ.');
      expect(runner.personVisible, isTrue);
    });

    test('biten squat seansı G-132 serbest kovasına yazılıyor', () {
      final LiveSessionRunner runner =
          LiveSessionRunner(config: squat, frameSize: size);
      int t = 0;
      for (final PoseFrame f in squatSequence(2)) {
        runner.consume(envelope(f, t));
        t += 40000;
      }
      final SessionRecord? r = buildFreeSessionRecord(
        movementId: 'bodyweight_squat',
        state: LiveRunning(
          reps: runner.reps,
          personVisible: runner.personVisible,
          framesSeen: runner.framesSeen,
        ),
        startedAt: DateTime.utc(2026, 8, 12, 4, 0),
        endedAt: DateTime.utc(2026, 8, 12, 4, 2),
      );
      expect(r, isNotNull);
      expect(r!.unitsCompleted, runner.reps.length,
          reason: 'canlı yoldan sayılan squat tekrarı kayda TAŞINMIYOR.');
      expect(r.lessonId, 'movement:bodyweight_squat');
    });
  });

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

    test('⭐ SIFIR-OLMAYAN tekrar sayısı KAYDA TAŞINIYOR', () {
      // ⚠️ Bu test bir KAPSAM BOŞLUĞUNU kapatıyor ve boşluk tam da aktarılan
      // sınıftı (J-156): *"olan bir şeyi kaybetmek"* — ve kaybın sonucu
      // sessiz değil, **`0` diye konuşuyor.**
      //
      // Ölçüldü: bu grubun ALTI vakasının altısı da `reps: <Rep>[]`
      // kullanıyordu, yani `unitsCompleted` YALNIZ 0 olarak sınanmıştı.
      // Biri `unitsCompleted: 0` diye SABİTLESE hepsi geçerdi — JabLab'ın
      // `eventCount: 0`ının birebir aynısı.
      //
      // *"Ölçmediğimiz sayıyı göstermeyiz"* diyen bir ürün, ölçtüğü sayıyı
      // atıp yerine yanlışını gösteremez.
      const Rep rep = Rep(
        index: 0,
        startUs: 0,
        endUs: 2000000,
        descentUs: 900000,
        ascentUs: 1100000,
        extremeAngleDeg: 92,
        startedAtOpenEnd: true,
        identityGapShare: 0,
      );
      final SessionRecord? r = build(LiveRunning(
        reps: List<Rep>.filled(7, rep),
        personVisible: true,
        framesSeen: 300,
      ));
      expect(r, isNotNull);
      expect(r!.unitsCompleted, 7,
          reason: 'Sayılan tekrarlar kayda TAŞINMIYOR — kullanıcı 7 tekrar '
              'yapıp geçmişinde başka bir sayı görür.');
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
