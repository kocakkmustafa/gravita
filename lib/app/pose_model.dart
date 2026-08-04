/// Uygulamanın PİNLİ poz modeli beyanı (M-F-263 · JabLab J-072 uyarlaması).
///
/// **Neden sabit değil de kendi dosyası:** üç değer birbirine bağlı ve üçü
/// birlikte doğru olmak zorunda — asset yolu (hangi dosya yüklenecek),
/// [modelId] (her zarfa damgalanan kimlik) ve [sha256] (dosyanın gerçekten o
/// dosya olduğunun kanıtı). Biri kayarsa diğerleri onu örter.
///
/// ⚠️ [modelId] REFERANSLARI ÜRETEN MODELİN KİMLİĞİDİR. Gravita'nın hasat
/// fixture'ları ve `reference.push_up.json` bu modelin ürettiği açılardan
/// türedi; `partial_rom` eşiği (110°) ve kimlik kapısı (torso ≥60°, G-043)
/// o açıların üstünde kalibre edildi. Başka bir bundle ile koşmak, eşikleri
/// artık ait olmadıkları bir modele uygulamak olur — sessizce yanlış hüküm.
/// Bu yüzden kimlik ELDE TUTULUR ve çekirdek onu `provenance`ta görür.
///
/// ⚠️ `latest` YASAK (M-L-01'de ölçüldü): `full` varyantında
/// `/float16/latest/` ile `/float16/1/` FARKLI — **aynı boyut, farklı hash**.
/// Boyut değişmediği için fark gözden kaçar; sürüm segmenti bu yüzden pinli.
library;

final class PoseModelPin {
  const PoseModelPin._();

  /// Flutter asset yolu. Dosya git'te **DEĞİL** (aile kuralı: `.task`
  /// ikilileri izlenmez, `.gitignore`) — `tool/fetch_pose_model.sh` indirir
  /// ya da aile hattından kopyalar ve SHA-256'yı DOĞRULAR.
  static const String assetPath =
      'assets/models/pose_landmarker_full.v1.task';

  /// Zarfa damgalanan kimlik.
  static const String modelId = 'pose_landmarker_full/float16/1';

  /// Kanonik hash (varyant `full`, sürüm `1`) — fetch betiğiyle AYNI.
  static const String sha256 =
      '5134a3aad27a58b93da0088d431f366da362b44e3ccfbe3462b3827a839011b1';

  /// Pinli sürüm segmenti. `latest` buraya YAZILAMAZ.
  static const String versionSegment = '1';
}
