import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;
import 'package:test/test.dart';

/// `WindowCorrelationCondition` — motor mekanizması İZOLE sınanıyor.
///
/// ⚠️ İzolasyon NEDEN gerekli: `harvestIdentityAttested:true` HEM M-F-122'nin
/// dış kapısını (`_refused`) HEM pencere-korelasyonunu atlıyor (ikisi de
/// "kimlik zaten başka yoldan doğrulandı" anlamına geliyor) — yani o bayrakla
/// pencere-koşulunu asla TEK BAŞINA göremezsin. Squat'ın GERÇEK kataloğu da
/// `status: pending` (bilerek — DEFTER G-131, kanal-havuzlu eşiğin pencere-
/// başına aynı ölçüt olmadığı açık kalan bir karar). Bu yüzden bu dosya
/// kataloğun BİR KOPYASINI `status: derived`e çevirerek pencere-koşulunu
/// M-F-122'nin dış kapısından BAĞIMSIZ sınıyor — üretim yolu DEĞİL, mekanizma
/// testi (K8'in `validate_library.py`deki `lookup_pending` mutasyon deseninin
/// Dart karşılığı).
void main() {
  final String rawJson =
      File('../../content/catalog/w1/bodyweight_squat.json').readAsStringSync();
  final Map<String, dynamic> j =
      jsonDecode(rawJson) as Map<String, dynamic>;
  (j['engine'] as Map<String, dynamic>)['precondition']['status'] = 'derived';
  final MovementConfig config =
      MovementConfig.fromJson(j);

  test('kurulum: squat gerçekten bir windowPrecondition taşıyor', () {
    expect(config.windowPrecondition, isNotNull);
    expect(config.windowPrecondition!.minPearson, 0.2);
  });

  const SyntheticPoseBuilder builder = SyntheticPoseBuilder();
  const FrameSize kSynthSize = FrameSize(900, 900);

  /// Diz VE kalça BİRLİKTE bükülen bir squat karesi — gerçek harekette
  /// olduğu gibi uyluk açısı da diz açısıyla orantılı değişir.
  SyntheticPose coordinatedSquatPose(double kneeDeg) {
    final double thighT = (175 - kneeDeg) / (175 - 95); // 0..1
    final double thigh = math.pi / 2 - thighT * (math.pi / 6); // kalça geriye kayar
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

  /// Diz büküldüğü HÂLDE uyluk SABİT kalan bir kare — hip-knee korelasyonu
  /// TANIMSIZ olmalı (uyluk hiç değişmiyor → varyans 0).
  SyntheticPose uncoordinatedSquatPose(double kneeDeg) {
    const double thigh = math.pi / 2; // SABİT — gerçek squat'ta olmaz
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

  List<PoseFrame> sequence(SyntheticPose Function(double) poseAt,
      {double top = 175, double bottom = 95, int msPerPhase = 800}) {
    final List<PoseFrame> out = <PoseFrame>[];
    int tUs = 0;
    const int step = 40000;
    void ramp(double from, double to) {
      final int frames = (msPerPhase * 1000) ~/ step;
      for (int i = 0; i <= frames; i++) {
        out.add(builder.build(
            poseAt(from + (to - from) * (i / frames)), tUs: tUs));
        tUs += step;
      }
    }

    out.add(builder.build(poseAt(top), tUs: tUs));
    tUs += step;
    ramp(top, bottom);
    ramp(bottom, top);
    return out;
  }

  test('POZİTİF — kalça-diz BİRLİKTE hareket ederse tekrar SAYILIR', () {
    final RepEngine e = RepEngine(config);
    for (final PoseFrame f in sequence(coordinatedSquatPose)) {
      e.addFrame(f, kSynthSize);
    }
    expect(e.repCount, 1,
        reason: 'gerçekçi (kalça+diz birlikte) hareket reddedilmemeli');
    expect(e.repsRejectedByWindowCorrelation, 0);
  });

  test('NEGATİF — diz büker ama kalça SABİT kalırsa tekrar REDDEDİLİR', () {
    final RepEngine e = RepEngine(config);
    for (final PoseFrame f in sequence(uncoordinatedSquatPose)) {
      e.addFrame(f, kSynthSize);
    }
    expect(e.repCount, 0,
        reason: 'kalça hiç değişmiyorsa korelasyon TANIMSIZ (varyans 0) — '
            'kabul edilirse pencere-koşulu hiçbir şeyi elemiyor demektir');
    expect(e.repsRejectedByWindowCorrelation, 1);
  });

  test('windowPrecondition YOKSA hiçbir hareket etkilenmez (push_up)', () {
    final MovementConfig pushUp = MovementConfig.parse(
        File('../../content/catalog/w1/push_up.json').readAsStringSync());
    expect(pushUp.windowPrecondition, isNull,
        reason: 'bu testin ÖN-KOŞULU: push_up pencere-koşulu taşımıyor');
  });
}
