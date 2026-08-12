import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/gravita_app.dart';
import 'package:gravita/app/onboarding_screen.dart';
import 'package:gravita/app/onboarding_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// ⭐ AÇILIŞ YOLU KAPISI — *"onboarding VAR"* ile *"kullanıcı ona VARIYOR"*
/// ayrı iki iddiadır ve bugüne kadar yalnız birincisi sınanıyordu.
///
/// ## Bu dosya neden var — SABOTAJLA ölçüldü, iddia edilmedi (G-181)
///
/// `gravita_app.dart`taki `return OnboardingFlow(...)` satırı
/// `GravitaShell`e çevrildi ve **app süiti 161/161 YEŞİL kaldı.** Yani
/// onboarding kullanıcının yolundan sessizce koparılabiliyordu ve hiçbir
/// kapı ötmüyordu. Üç testin üçü de yolu ıskalıyordu:
///
/// * `onboarding_test.dart` → `OnboardingFlow`u **doğrudan** pump ediyor
///   (widget'ı sınıyor, ona GİDEN yolu değil),
/// * `shell_end_to_end_test.dart` → `GravitaRoot`u pump ediyor ama testte
///   `path_provider` olmadığı için **fail-open dalıyla onboarding'i
///   ATLIYOR** (o testin konusu kabuk, bu yüzden doğru davranıyor),
/// * `reachability_test.dart` → ölçümü `GravitaShell`den **başlatıyor**.
///
/// > *Repliğin varlığı, tetiğinin varlığı değildir* (M-F-503).
///
/// ## Sahte olan NE, gerçek olan NE (test-double sınırı açıkça)
///
/// Sahte olan yalnız **dizin**: `PathProviderPlatform` geçici bir klasör
/// gösteriyor. `OnboardingStore` GERÇEK — ürünün kendi `open()` çağrısı,
/// gerçek dosya okuma/yazma, gerçek JSON. Sahte bir "store" enjekte etseydik
/// test, ürünün kuralını değil kendi taklidinin kuralını ölçerdi.
class _TempSupportDir extends PathProviderPlatform {
  _TempSupportDir(this._path);

  /// `null` → `path_provider` `MissingPlatformDirectoryException` fırlatır;
  /// depolama ARIZASININ testteki gerçek karşılığı budur (uydurma bir
  /// `Exception` atmak yerine plugin'in KENDİ arıza yolunu kullanıyoruz).
  final String? _path;

  @override
  Future<String?> getApplicationSupportPath() async => _path;
}

void main() {
  late Directory tmp;

  /// Varsayılan sağlayıcı ADIYLA değil DEĞERİYLE geri konuyor: somut sınıf
  /// (`MethodChannelPathProvider`) paketin dışa açtığı yüzeyde yok ve
  /// sürümle değişebilir. Sakla-geri koy, bu testin diğer dosyalara
  /// sızmamasının en dar yolu.
  late PathProviderPlatform defaultProvider;

  setUp(() async {
    defaultProvider = PathProviderPlatform.instance;
    tmp = await Directory.systemTemp.createTemp('onboarding_launch_path');
  });

  tearDown(() async {
    PathProviderPlatform.instance = defaultProvider;
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// `GravitaRoot`un ARKASINDA iki AYRI gerçek G/Ç zinciri var (içerik
  /// asset'i + onboarding dosyası) ve her biri KENDİ turunu ister. Tek
  /// `runAsync` yalnız birincisini bitirir — bu G-127'de bir regresyon
  /// olarak ölçülmüştü.
  ///
  /// ⚠️ `pumpAndSettle` KULLANILAMAZ: gerçek asset okuması gerçek saate
  /// bağlı, `testWidgets` gövdesi ise sahte saatli — yükleyici sonsuza
  /// kadar döner.
  ///
  /// ⭐ SAHTE SAĞLAYICI YALNIZ BİR AN AÇIK KALIR — ve bu, testi üç kez
  /// düşürdükten sonra ÖLÇÜLEREK bulundu.
  ///
  /// `google_fonts` yazı tipi önbelleği için `path_provider` kullanıyor.
  /// Depodaki diğer widget testleri indirme yoluna HİÇ girmiyor
  /// (`library_surface_test.dart` koşumunda `gstatic` isabeti **0**), çünkü
  /// testte plugin yok. Bu dosya sağlayıcıyı çalışır hâle getirince o yan
  /// kapı açılıyor: `google_fonts` `fonts.gstatic.com`a uzanıyor,
  /// `flutter_test_config`in ölü istemcisi reddediyor ve red, `runAsync`
  /// penceresi içinde **sahipsiz bir zone hatası** olarak testi anında
  /// düşürüyor. `takeException` bunu YAKALAYAMAZ (yalnız
  /// `FlutterError.onError` kanalını görür) — `reachability_test.dart`ta
  /// yazılı olan ders, burada tekrar ölçüldü.
  ///
  /// Çözüm hatayı yakalamak değil, **hiç doğurmamak**: `OnboardingStore`
  /// dizini `pumpWidget` sırasında (`didChangeDependencies`) SORAR, yani
  /// sağlayıcı o an okunur ve çağrı uçuşa geçer. `google_fonts` ise dizini
  /// çok sonra, ilk BUILD'de sorar. Aradaki bu boşlukta varsayılanı geri
  /// koymak mağazayı bozmadan indirme yolunu kapatıyor.
  Future<void> bootRoot(WidgetTester tester, String? supportPath) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // ① İçerik önbelleğini ÖNCEDEN ısıt. `rootBundle` bir `CachingAssetBundle`
    //    olduğu için `GravitaRoot` içindeki `ContentRepository.load` bundan
    //    sonra önbellekten döner. Bu ısıtma olmadan içerik zinciri İLK testte
    //    tek turda bitiyor ama sonrakilerde bitmiyordu (ölçüldü: `TANI`
    //    satırında `icerikYuklendi=0`, ekranda yükleyici kalıyordu).
    await tester.runAsync(() => ContentRepository.load(rootBundle));

    // ② Mağazanın sorusu `pumpWidget` sırasında sorulur; sağlayıcı o an açık.
    PathProviderPlatform.instance = _TempSupportDir(supportPath);
    await tester.pumpWidget(const MaterialApp(home: GravitaRoot()));
    PathProviderPlatform.instance = defaultProvider;

    // ③ YÜKLEYİCİ EKRANDAYKEN tur aç — ve tam o ekran kaybolunca DUR.
    //
    //    Kilit gözlem: yükleyici `CircularProgressIndicator`dür, yazı tipi
    //    İSTEMEZ. Yani yükleyici çizilirken kare basmak güvenli; asıl ekran
    //    (onboarding ya da kabuk) çizildiği an `google_fonts` isteği başlar
    //    ve BUNDAN SONRA açılan her gerçek-zaman turu o isteğin reddini
    //    testin üstüne düşürür (ölçüldü: turlar arasına kare koyan sürüm
    //    `gstatic` hatasıyla düştü).
    //
    //    Sabit tur sayısı YETMİYOR ve sebebi ölçüldü: dosya YOKSA zincir tek
    //    `exists()`, VARSA `exists`+`readAsString`+decode — ikincisi bir
    //    turda bitmiyor. Sayı UYDURMAK yerine koşul soruluyor.
    for (int round = 0;
        round < 8 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
        round++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump(const Duration(milliseconds: 80));
    }

    // ④ Kalan boyama YALNIZ saf pump ile.
    for (int i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  testWidgets(
      'TAZE KULLANICI: açılış onboarding\'e VARIR — kabuk hiç çizilmez',
      (WidgetTester tester) async {
    await bootRoot(tester, tmp.path);

    expect(find.byType(OnboardingFlow), findsOneWidget,
        reason: 'İlk açılışın TEK kapısı burası. Bu satır düşüyorsa '
            'onboarding kullanıcının yolundan koparılmış demektir — '
            'dosyaların VARLIĞI bunu göstermez (G-181 sabotaj ölçümü).');
    expect(find.byType(GravitaShell), findsNothing,
        reason: 'Onay alınmadan kabuk ÇİZİLMEZ; "önce göster sonra sor" '
            'güvenlik onayını süse çevirir.');
  });

  testWidgets(
      'POZİTİF İKİZ — onboarding TAMAMLANMIŞSA kabuk gelir, akış TEKRARLAMAZ',
      (WidgetTester tester) async {
    // Bit'i ürünün KENDİ yazıcısıyla kur (şema anahtarını elle yazmak,
    // ailenin ölçülmüş enjeksiyon-hatası dersidir: gerçek yazıcıyı kullan).
    //
    // ⚠️ `runAsync` ZORUNLU ve bu da ölçüldü: `testWidgets` gövdesi SAHTE
    // saatlidir, `writeAsString` ise GERÇEK G/Ç — doğrudan `await` edilirse
    // test sonsuza kadar asılı kalır (koşum kesilene dek bekledi). Aynı
    // FakeAsync tuzağının bu dosyadaki görünüşü.
    await tester.runAsync(() =>
        OnboardingStore.forFile(File('${tmp.path}/onboarding.json'))
            .markComplete());
    await bootRoot(tester, tmp.path);

    expect(find.byType(GravitaShell), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing,
        reason: 'Bu ikiz olmadan üstteki iddia, onboarding\'i HER açılışta '
            'gösteren bir uygulamada da geçerdi — koşulsuz doğru bir kapı '
            'hiçbir şey ölçmez.');
  });

  testWidgets(
      '⚠️ BUGÜNKÜ DAVRANIŞ (hüküm bekliyor): depolama ARIZASINDA onboarding '
      'ATLANIR — güvenlik onayı gösterilmez', (WidgetTester tester) async {
    // Bu test bir ONAY DEĞİL, bir GÖRÜNÜRLÜK aracı. `GravitaRoot`un
    // `.catchError((_) => true)` dalı bilinçli bir seçimdi (G-127: "depolama
    // arızası gerçek kullanıcıyı uygulamaya HİÇ SOKMAMALI") ama bedeli
    // ölçüldü ve adı kondu (G-181): O2'nin gösterdiği `safetyDisclaimer`
    // metni `lib/`de BAŞKA HİÇBİR yerde geçmiyor → bu dalda kullanıcı
    // güvenlik uyarısını ve açık onayı HİÇ görmez. Ürünün kendi sert kuralı
    // ise "güvenlik kırpılmaz … + açık onay" diyor.
    //
    // Karar koordinatörde (G-181 ④). Davranış değişirse bu test BİLEREK
    // çevrilecek — sessizce kaymayacak. Kapının işi, seçimi görünür tutmak.
    await bootRoot(tester, null);

    expect(find.byType(GravitaShell), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing);
  });
}
