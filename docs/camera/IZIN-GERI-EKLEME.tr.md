# Kamera izni: kapalı sürümde kaldırıldı, açılınca geri eklenir

Bilet: GRA-P1-02 · Tarih: 2026-11-15

- Kamera koçluğu bayrağı kapalıdır (`lib/app/camera_release_policy.dart`, `motionCameraCoachingAvailable`, Core'dan gelir). Bu sürümde Android manifestinde `android.permission.CAMERA` yoktur; `test/android_camera_permission_test.dart` yokluğunu doğrular.
- Kamera özelliği açılırken: `android/app/src/main/AndroidManifest.xml` içine `<uses-permission android:name="android.permission.CAMERA" />` geri eklenir ve `test/android_camera_permission_test.dart` bu karara göre güncellenir (testi sessizce silme).
- iOS: `ios/Runner/Info.plist` içindeki `NSCameraUsageDescription` bu biletle değiştirilmedi; metin kameranın bu sürümde kapalı olduğunu söyler.
- Kamera açılması ayrıca izin metni, gizlilik ve mağaza metni kararı gerektirir (kurucu kararı).
