import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/gravita_app.dart';
import 'package:gravita/app/onboarding_screen.dart';
import 'package:gravita/app/onboarding_store.dart';
import 'package:gravita/app/onboarding_strings.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/launch_harness.dart';

/// ⭐ AÇILIŞ YOLU KAPISI — *"onboarding VAR"* ile *"kullanıcı ona VARIYOR"*
/// ayrı iki iddiadır ve bu dosya yazılana kadar yalnız birincisi sınanıyordu.
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
/// * `shell_end_to_end_test.dart` → `GravitaRoot`u pump ediyor ama o gün
///   fail-open dalıyla onboarding'i **atlıyordu**,
/// * `reachability_test.dart` → ölçümü `GravitaShell`den **başlatıyor**.
///
/// > *Repliğin varlığı, tetiğinin varlığı değildir* (M-F-503).
void main() {
  late Directory tmp;

  /// Varsayılan sağlayıcı ADIYLA değil DEĞERİYLE geri konuyor: somut sınıf
  /// paketin dışa açtığı yüzeyde yok ve sürümle değişebilir.
  late PathProviderPlatform defaultProvider;

  setUp(() async {
    defaultProvider = PathProviderPlatform.instance;
    tmp = await Directory.systemTemp.createTemp('onboarding_launch_path');
  });

  tearDown(() async {
    PathProviderPlatform.instance = defaultProvider;
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  testWidgets('TAZE KULLANICI: açılış onboarding\'e VARIR — kabuk çizilmez',
      (WidgetTester tester) async {
    await bootGravitaRoot(tester,
        supportPath: tmp.path, restoreTo: defaultProvider);

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
    await realIo(
        tester,
        () => OnboardingStore.forFile(File('${tmp.path}/onboarding.json'))
            .markComplete());
    await bootGravitaRoot(tester,
        supportPath: tmp.path, restoreTo: defaultProvider);

    expect(find.byType(GravitaShell), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing,
        reason: 'Bu ikiz olmadan üstteki iddia, onboarding\'i HER açılışta '
            'gösteren bir uygulamada da geçerdi — koşulsuz doğru bir kapı '
            'hiçbir şey ölçmez.');
  });

  group('DEPOLAMA ARIZASI — göster, ama kalıcılaştırma (G-183 / hüküm b)', () {
    // Kamera izni REDDEDİLDİ olarak yanıtlanıyor: akışın sonuna ürünün
    // kendi "continue without" dalından varılıyor (izin VERİLSEYDİ de aynı
    // `onComplete` çağrılırdı — ölçülen şey kalıcılık, izin değil).
    setUp(() => mockPermissionChannel(status: 0));

    /// ⚠️ BU TEST BİLEREK ÇEVRİLDİ, sessizce kaymadı.
    ///
    /// Önceki hâli *"⚠️ BUGÜNKÜ DAVRANIŞ (hüküm bekliyor): depolama
    /// ARIZASINDA onboarding ATLANIR"* diyordu ve bir ONAY değil bir
    /// GÖRÜNÜRLÜK aracıydı — davranış değişirse test bilerek çevrilsin,
    /// sessizce kaymasın diye. Koordinatör hükmü (b) geldi ve çevrildi.
    ///
    /// Gerekçe (G-181 ölçümü): `safetyDisclaimer` metni `lib/`de BAŞKA
    /// HİÇBİR YERDE geçmiyor → eski dalda kullanıcı güvenlik uyarısını ve
    /// açık onayı HİÇ görmüyordu. *Bir kuralı en çok ihtiyaç duyulan anda
    /// askıya alan tasarım, o kuralı taşımıyordur.*
    testWidgets('okunamayan depoda onboarding GÖSTERİLİR — onay atlanmaz',
        (WidgetTester tester) async {
      await bootGravitaRoot(tester,
          supportPath: null, restoreTo: defaultProvider);

      expect(find.byType(OnboardingFlow), findsOneWidget,
          reason: 'Arıza, güvenlik onayını askıya alamaz.');
      expect(find.byType(GravitaShell), findsNothing);
    });

    /// Hükmün İKİNCİ yarısı — ve kapının iki yarısı birlikte tasarlanır.
    /// Okuma fail-closed olunca yazma da yutulmazsa, bozuk depolamalı bir
    /// cihazda kullanıcı onayı verir ve HİÇBİR YERE gidemezdi. Bu test tam
    /// o çıkmaz sokağı yasaklıyor.
    testWidgets('onay verilince kabuğa GEÇİLİR — yazma hatası KİLİTLEMEZ',
        (WidgetTester tester) async {
      await bootGravitaRoot(tester,
          supportPath: null, restoreTo: defaultProvider);
      expect(find.byType(OnboardingFlow), findsOneWidget);

      // Akışı gerçek kontrollerle geç: O1 → O2 → O5.
      await tester.tap(find.byKey(OnboardingFlow.valueContinueKey));
      await tester.pump();
      await tester.tap(find.byKey(OnboardingFlow.safetyConsentKey));
      await tester.pump();
      expect(find.text(OnboardingStrings.cameraRationale), findsOneWidget);

      // O5: kullanıcı izni REDDEDİYOR → ürünün kendi "continue without"
      // dalı. `mockPermissionChannel` yalnız kanalın sessizliğini gideriyor.
      await tester.tap(find.byKey(OnboardingFlow.cameraAllowKey));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(OnboardingFlow.cameraDeniedKey), findsOneWidget,
          reason: 'Ret dalı çizilmeliydi; kanal yanıtı ürüne ulaşmamış.');
      await tester.tap(find.byKey(OnboardingFlow.cameraContinueWithoutKey));
      // `markComplete` GERÇEK G/Ç dener ve arızada FIRLATIR; ürün onu yutup
      // yine de kabuğa geçmeli. Gerçek-zaman turu o denemeye yer açıyor.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(find.byType(GravitaShell), findsOneWidget,
          reason: 'Kalıcılık BAŞARISIZ olabilir; giriş engellenemez. Aksi '
              'hâlde bozuk depolamalı cihazda uygulama ÇIKMAZ SOKAK olurdu.');
    });

    /// Ve "kalıcılaştırılmaz" gerçekten ÖLÇÜLÜYOR: arızalı depoda hiçbir
    /// dosya doğmaz, dolayısıyla bir sonraki açılış akışı TEKRAR sorar.
    /// Tekrar sorması KABUL EDİLMİŞ maliyettir (hüküm b), gizlenecek kusur
    /// değil — bu yüzden test onu iddia olarak DEĞİL, ölçüm olarak tutuyor.
    testWidgets('arızalı depoda BİT YAZILMAZ — sonraki açılış tekrar sorar',
        (WidgetTester tester) async {
      await bootGravitaRoot(tester,
          supportPath: null, restoreTo: defaultProvider);
      await tester.tap(find.byKey(OnboardingFlow.valueContinueKey));
      await tester.pump();
      await tester.tap(find.byKey(OnboardingFlow.safetyConsentKey));
      await tester.pump();
      await tester.tap(find.byKey(OnboardingFlow.cameraAllowKey));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(OnboardingFlow.cameraContinueWithoutKey));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();

      final bool wrote = await realIo(
          tester, () => File('${tmp.path}/onboarding.json').exists());
      expect(wrote, isFalse,
          reason: 'Arızalı depoya yazılamaz; "kalıcılaştırılmaz" yarısı.');
    });
  });
}
