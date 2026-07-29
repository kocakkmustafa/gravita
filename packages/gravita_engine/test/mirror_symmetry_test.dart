import 'dart:math' as math;

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart';
import 'package:test/test.dart';

/// M-F-145: `mirrorAgnostic` BÜYÜKLÜKTEN türer, işaret-iptalinden DEĞİL.
///
/// Bu testin varlık sebebi G-078 Bulgu B: eski `meanLeftRightDiffDeg` alanı
/// konsensüs üzerinde `|ortalama|` hesaplıyordu ve `|E[X]| ≤ E[|X|]` olduğu
/// için take'ler arasında işaretler birbirini yediğinde küçük bir sayı
/// üretiyordu. push_up'ta ölçüldü: take düzeyi 14,74° iken o alan 5,16°
/// diyordu ve bayrak yanlışlıkla `true` oluyordu. Bu test o kusuru
/// SENTETİK olarak yeniden üretir — kapı ateşlenmemişse kapı değildir
/// (G-037/G-052).
void main() {
  const List<JointSpec> specs = <JointSpec>[
    JointSpec(id: 'left_knee', kind: AngleKind.flexion, a: Lm.leftHip, b: Lm.leftKnee, c: Lm.leftAnkle),
    JointSpec(
        id: 'right_knee',
        kind: AngleKind.flexion,
        a: Lm.rightHip,
        b: Lm.rightKnee,
        c: Lm.rightAnkle),
  ];

  /// Sol-sağ farkı [diffDeg] olan tek karelik bir take üretir.
  List<JointAngleVector> take(double diffDeg) => <JointAngleVector>[
        JointAngleVector(
          tUs: 0,
          specs: specs,
          values: <double>[
            90 * math.pi / 180,
            (90 - diffDeg) * math.pi / 180,
          ],
        ),
      ];

  test('işaretler BİRBİRİNİ YERSE bayrak yine de FALSE kalır (M-F-145)', () {
    // İki take: biri +20°, öteki −20°. İşaretli ortalama ~0 → ESKİ metrik
    // "0° fark, ayna-agnostik" derdi. Büyüklük ortalaması 20° → doğru cevap.
    final MirrorSymmetry m =
        MirrorSymmetry.fromTakes(<List<JointAngleVector>>[take(20), take(-20)]);

    expect(m.takeMeanAbsLRDiffDeg, closeTo(20, 0.01),
        reason: 'BÜYÜKLÜK sorusu: fark 20°, iptal olması onu küçültmez');
    expect(m.signedCircularMeanDeg.abs(), lessThan(0.01),
        reason: 'işaretli ortalama ~0 — eski metriğin tuzağı tam buydu');
    expect(m.signConsistencyRatio, closeTo(0, 0.001),
        reason: 'işaret tutarlılığı 0: fark rastgele yöne bakıyor');
    expect(m.mirrorAgnostic, isFalse,
        reason: 'bayrak BÜYÜKLÜKTEN türer — işaret-iptali "simetri" DEĞİLDİR');
  });

  test('gerçekten küçük fark bayrağı TRUE yapar (kapı körlük değil)', () {
    final MirrorSymmetry m =
        MirrorSymmetry.fromTakes(<List<JointAngleVector>>[take(2), take(-3)]);
    expect(m.takeMeanAbsLRDiffDeg, lessThan(MirrorSymmetry.agnosticThresholdDeg));
    expect(m.mirrorAgnostic, isTrue,
        reason: 'küçük GERÇEK fark ayna-agnostikliği hak eder; aksi hâlde '
            'kapı değil körlük olurdu');
  });

  test('tutarlı işaret = sistematik tek-yanlılık, oran 1e yakın', () {
    final MirrorSymmetry m =
        MirrorSymmetry.fromTakes(<List<JointAngleVector>>[take(20), take(20)]);
    expect(m.signConsistencyRatio, closeTo(1, 0.001),
        reason: 'hep aynı tarafa bakan fark = sistematik, iptal olmaz');
    expect(m.mirrorAgnostic, isFalse);
  });
}
