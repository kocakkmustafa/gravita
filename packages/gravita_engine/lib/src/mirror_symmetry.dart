import 'dart:math' as math;

import 'package:motion_core/motion_core.dart';

/// Taraf-simetri ölçüsü — İKİ AYRI SORU, iki ayrı alan (M-F-145).
///
/// **Neden bu dosya var (G-078 Bulgu B):** referans artefaktlarına yazdığım
/// eski `meanLeftRightDiffDeg` alanı konsensüs açıları üzerinde `|ortalama|`
/// hesaplıyordu. `|E[X]| ≤ E[|X|]` olduğu için o sayı İKİ SORUYU
/// karıştırıyordu:
///   1. **Büyüklük:** sol ve sağ ne kadar farklı okunuyor?
///   2. **İşaret tutarlılığı:** fark take'ler arasında AYNI yöne mi bakıyor
///      (sistematik tek-yanlılık) yoksa rastgele mi (iptal olur)?
///
/// Ölçüldü: push_up take-düzeyi 19,25° iken konsensüs `|ortalama|` yalnız
/// 5,16° (3,73× iptal — işaretler rastgele); squat 33,13° vs 32,26° (1,03×,
/// işaret tutarlı). Yani eski sayı push_up'ı "ayna-agnostik" gösteriyordu
/// ama ölçtüğü şey simetri DEĞİL, işaret-iptaliydi.
///
/// ⚠️ Bu hesap İKİ tüketici tarafından kullanılıyor (push_up ve squat
/// referans araçları). Tek evde durmasının sebebi bu gece iki kez avlanan
/// **kopya-sürüklenmesi** sınıfı (G-065/G-066): aynı formülün iki kopyası
/// zamanla ayrışır ve ayrışma SESSİZ olur.
class MirrorSymmetry {
  const MirrorSymmetry({
    required this.takeMeanAbsLRDiffDeg,
    required this.signedCircularMeanDeg,
    required this.signConsistencyRatio,
    required this.pairSamples,
  });

  /// **BÜYÜKLÜK sorusu:** take-düzeyi ortalama `|sol − sağ|` (dairesel).
  /// `mirrorAgnostic` bayrağı YALNIZ bundan türer — "teknik tarafı ayırt
  /// etmiyor" iddiası KÜÇÜK FARK ister, işaret-iptali değil (M-F-145).
  final double takeMeanAbsLRDiffDeg;

  /// İşaretli farkın dairesel ortalaması (denetlenebilirlik için açıkta).
  final double signedCircularMeanDeg;

  /// **İŞARET TUTARLILIĞI sorusu:** `|işaretli ortalama| / ortalama|fark|`
  /// ∈ [0,1]. 1'e yakın = fark hep AYNI tarafa bakıyor (sistematik
  /// tek-yanlılık); 0'a yakın = işaretler birbirini yiyor (rastgele).
  /// Eski `|ortalama|` metriği tam olarak bu ikisinin ÇARPIMIydı.
  final double signConsistencyRatio;

  /// Kaç (kare × eklem-çifti) örneği kullanıldı.
  final int pairSamples;

  /// Eşik dayanağı METRİK-AYRIMI ÖNCESİ döneme ait (M-F-145 hüküm 3).
  /// Şu an sınırda vaka YOK (ölçülen değerler 19,25° ve 32+°, ikisi de
  /// eşikten uzak), bu yüzden yeniden türetilmedi. **Bir referans bu eşiğe
  /// YAKLAŞIRSA önce eşiğin temeli yeniden türetilmelidir** — icat-eşik
  /// yasağının bu alandaki karşılığı.
  static const double agnosticThresholdDeg = 7.0;

  bool get mirrorAgnostic => takeMeanAbsLRDiffDeg < agnosticThresholdDeg;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'takeMeanAbsLRDiffDeg':
            double.parse(takeMeanAbsLRDiffDeg.toStringAsFixed(2)),
        'signedCircularMeanDeg':
            double.parse(signedCircularMeanDeg.toStringAsFixed(2)),
        'signConsistencyRatio':
            double.parse(signConsistencyRatio.toStringAsFixed(3)),
        'pairSamples': pairSamples,
        'mirrorAgnostic': mirrorAgnostic,
        'thresholdDeg': agnosticThresholdDeg,
      };

  /// Kanonik yolla hazırlanmış take'lerden ölçer.
  ///
  /// Girdi `ReferenceCli.prepareTake`in ürettiği açı vektörleridir — yani
  /// izotropik dönüşüm, güven kapısı ve açı çıkarımı referansın kullandığı
  /// KOD YOLUNUN AYNISI.
  static MirrorSymmetry fromTakes(Iterable<List<JointAngleVector>> takes) {
    double absSum = 0, sinSum = 0, cosSum = 0;
    int n = 0;
    for (final List<JointAngleVector> frames in takes) {
      for (final JointAngleVector v in frames) {
        for (final JointSpec s in v.specs) {
          if (!s.id.startsWith('left_')) continue;
          final double? a = v.byId(s.id);
          final double? b = v.byId(s.id.replaceFirst('left_', 'right_'));
          if (a == null || b == null) continue;
          // Dairesel fark — doğrusal çıkarma 359,7° sahte farkı üretir
          // (G-051, bu gece bir kez sahte alarm verdirdi).
          final double d = math.atan2(math.sin(a - b), math.cos(a - b));
          absSum += d.abs();
          sinSum += math.sin(d);
          cosSum += math.cos(d);
          n++;
        }
      }
    }
    if (n == 0) {
      return const MirrorSymmetry(
        takeMeanAbsLRDiffDeg: double.nan,
        signedCircularMeanDeg: double.nan,
        signConsistencyRatio: double.nan,
        pairSamples: 0,
      );
    }
    const double toDeg = 180 / math.pi;
    final double meanAbs = (absSum / n) * toDeg;
    final double signedMean = math.atan2(sinSum / n, cosSum / n) * toDeg;
    return MirrorSymmetry(
      takeMeanAbsLRDiffDeg: meanAbs,
      signedCircularMeanDeg: signedMean,
      signConsistencyRatio: meanAbs.abs() < 1e-9
          ? double.nan
          : signedMean.abs() / meanAbs,
      pairSamples: n,
    );
  }
}
