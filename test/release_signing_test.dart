/// RELEASE İMZASI SESSİZ-DÜŞÜŞ KAPISI (GRA-P0-003) — kaynak-metin nöbeti.
///
/// ## Neden bu dosya var
///
/// `android/app/build.gradle.kts` (G-192, 2026-08-12) iki parçalı bir kapı
/// taşıyor: ① `signingConfig = when { … }` seçimi (gerçek keystore VARSA
/// gerçek imza, `allowDebugSigning` bilerek verildiyse debug, aksi hâlde
/// `null`) ② ayrı bir `gradle.taskGraph.whenReady` bloğu — imza kimliği
/// yokken ve debug'a bilerek geçilmediğinde `GradleException` fırlatır.
///
/// Bu mantık Gradle Kotlin DSL'de yaşıyor; Dart testinden ÇALIŞTIRILAMAZ
/// (gerçek bir Gradle koşumu gerekir — pahalı, CI'da AYRI bir adım olarak
/// zaten var: `flutter build appbundle --release -PallowDebugSigning=true`,
/// bkz. `.github/workflows/checks.yml`). Bu dosya GRADLE'I ÇALIŞTIRMAZ;
/// kaynağın hâlâ kritik parçaları taşıdığını doğrular — biri sessizce
/// silinirse (ör. bir refactor sırasında) bu kapı KIRMIZI yanar; gerçek
/// koruma yalnız CI'ın gerçek `-release` koşumuyla TAM doğrulanır.
///
/// `tools/validate_release_signing.py` ile TAMAMLAYICI: Python kapısı
/// `run_all_gates.sh` içindeki içerik süitinde koşar, bu dosya `flutter
/// test` içinde. İkisi AYNI kaynağı, farklı koşum ortamlarında sınar.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _gradlePath = 'android/app/build.gradle.kts';

void main() {
  test('imza seçim mantığı VE gürültülü durdurucu kaynakta duruyor', () {
    final String src = File(_gradlePath).readAsStringSync();
    final Map<String, String> mustContain = <String, String>{
      'gerçek keystore kontrolü (seçim)': 'keyPropsFile.exists()',
      'else dalı null (sessiz debug düşüşü yok)': 'else -> null',
      'ayrı durdurucu blok': 'gradle.taskGraph.whenReady',
      'bilerek debug-imza opt-in bayrağı': 'allowDebugSigning',
      'sessiz düşüşü durduran gürültülü hata': 'throw GradleException(',
      'yalnız RELEASE görevlerine daraltma': 'name.contains("Release")',
    };
    final List<String> missing = <String>[
      for (final MapEntry<String, String> e in mustContain.entries)
        if (!src.contains(e.value)) '${e.key}: «${e.value}» bulunamadı',
    ];
    expect(missing, isEmpty,
        reason: 'RELEASE İMZASI GUARD\'I ZAYIFLADI:\n${missing.join("\n")}\n\n'
            'Bu, release artefaktın debug anahtarıyla SESSİZCE üretilip '
            'Play/App Store\'da reddedilmesi riskini geri getirir.');
  });

  test('SABOTAJ — durdurucu tamamen kaldırılsa nöbet gerçekten ateşliyor mu',
      () {
    final String real = File(_gradlePath).readAsStringSync();
    // whenReady bloğunun tamamını (dosyanın sonuna kadar) düş — Gradle
    // sözdiziminde en son bildirim olduğu için bu geçerli bir sabotajdır.
    final int idx = real.indexOf('gradle.taskGraph.whenReady');
    expect(idx, greaterThan(0),
        reason: 'Sabotaj kurulamadı — gerçek dosyada durdurucu blok YOK, bu '
            'ikiz hiçbir şey ölçmez.');
    final String sabotaged = real.substring(0, idx);
    expect(sabotaged.length, lessThan(real.length),
        reason: 'Sabotaj uygulanamadıysa bu ikiz hiçbir şey ölçmez.');
    expect(sabotaged.contains('throw GradleException('), isFalse,
        reason: 'Saptayıcı sentetik eksiği göremiyorsa gerçeğini de '
            'göremez.');
  });
}
