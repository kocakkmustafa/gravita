import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodCall, MethodChannel, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/gravita_app.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Ürünün GERÇEK açılış yolunu (`GravitaRoot`) test altında koşturmanın
/// ortak kablolaması.
///
/// ## Neden ortak dosya
///
/// İki test dosyası aynı yolu pump ediyor (`onboarding_launch_path_test` →
/// akışın kendisi · `shell_end_to_end_test` → akış geçildikten SONRAKİ
/// kabuk). Kurulum kopyalansaydı G-079'un dersi tekrarlanırdı: *iki ev
/// tutarsızlaşır*. Burada TEK ev var.
///
/// ## Sahte olan NE (test-double sınırı)
///
/// Yalnız **uygulama destek dizini**. `OnboardingStore` gerçek, dosya
/// gerçek, JSON gerçek. Sahte bir "store" enjekte etmek, ürünün kuralını
/// değil taklidin kuralını ölçerdi.
class FakeSupportDir extends PathProviderPlatform {
  FakeSupportDir(this.path);

  /// `null` → `path_provider` `MissingPlatformDirectoryException` fırlatır.
  /// Depolama ARIZASININ testteki gerçek karşılığı budur: uydurma bir
  /// istisna atmak yerine plugin'in KENDİ arıza yolu kullanılıyor.
  final String? path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

/// `GravitaRoot`u gerçek açılış yolundan pump eder ve yerleşmesini bekler.
///
/// [supportPath] `null` ise depolama arızası simüle edilir.
/// [restoreTo] kurulumdan hemen sonra geri konacak sağlayıcı (genelde
/// `setUp`ta yakalanan varsayılan).
///
/// ## Üç ölçülmüş tuzak — sırası tesadüf değil
///
/// **① `pumpAndSettle` KULLANILAMAZ.** Gerçek asset okuması gerçek saate
/// bağlı, `testWidgets` gövdesi ise sahte saatli: yükleyici sonsuza döner.
///
/// **② Sahte `path_provider` bir YAN KAPI açıyor.** `google_fonts` yazı
/// tipi önbelleği için o plugin'i kullanır. Normal testte plugin yoktur, o
/// yüzden indirme yoluna hiç girilmez (ölçüldü: `library_surface_test`
/// koşumunda `gstatic` isabeti **0**). Sağlayıcı çalışır hâle gelince
/// `fonts.gstatic.com` isteği başlar, `flutter_test_config`in ölü istemcisi
/// reddeder ve red bir `runAsync` penceresinde **sahipsiz zone hatası**
/// olarak testi düşürür. `takeException` bunu YAKALAYAMAZ — yalnız
/// `FlutterError.onError` kanalını görür.
/// → Panzehir yakalamak değil **hiç doğurmamak**: yükleyici
/// (`CircularProgressIndicator`) yazı tipi İSTEMEZ, o ekrandayken tur açmak
/// serbesttir; **asıl ekran boyandıktan SONRA gerçek-zaman turu açılmaz.**
///
/// **③ Sabit tur sayısı YETMİYOR.** Onboarding bit'i okunurken dosya YOKSA
/// tek `exists()`, VARSA `exists`+`readAsString`+decode zinciri var; ikincisi
/// tek turda bitmiyor. Sayı UYDURMAK yerine **koşul** soruluyor: yükleyici
/// ekrandan gidene kadar tur aç.
Future<void> bootGravitaRoot(
  WidgetTester tester, {
  required String? supportPath,
  required PathProviderPlatform restoreTo,
  Size size = const Size(1200, 4000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // İçerik önbelleğini ÖNCEDEN ısıt: `rootBundle` bir `CachingAssetBundle`,
  // böylece `GravitaRoot` içindeki yükleme önbellekten döner. Bu ısıtma
  // olmadan içerik zinciri İLK testte bitiyor ama sonrakilerde bitmiyordu.
  await tester.runAsync(() => ContentRepository.load(rootBundle));

  // Mağazanın dizin sorusu `pumpWidget` sırasında sorulur; sağlayıcı O AN
  // açık olmalı, sonrasında değil.
  PathProviderPlatform.instance = FakeSupportDir(supportPath);
  await tester.pumpWidget(const MaterialApp(home: GravitaRoot()));
  PathProviderPlatform.instance = restoreTo;

  for (int round = 0;
      round < 8 &&
          find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      round++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 80));
  }
  for (int i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

/// `permission_handler`ın platform kanalını testte YANITLAR.
///
/// ⚠️ Ne yaptığı ve ne YAPMADIĞI: bu, cihaz davranışını taklit etmez —
/// kanalın testteki SESSİZLİĞİNİ giderir. Kanal yanıtsızken
/// `Permission.camera.request()` `MissingPluginException` fırlatır ve
/// ürünün KENDİ ret dalı (kullanıcı izni vermedi → "continue without")
/// hiç koşturulamaz. `run_all_gates.sh`ın "cihaz davranışı ölçülmez"
/// kapsam şerhi geçerliliğini korur: burada ölçülen şey cihazın kararı
/// değil, ürünün o karara verdiği YANIT.
///
/// [status] `PermissionStatus` sırasıdır: 0 denied · 1 granted ·
/// 2 restricted · 3 limited · 4 permanentlyDenied.
void mockPermissionChannel({required int status}) {
  const MethodChannel channel =
      MethodChannel('flutter.baseflow.com/permissions/methods');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
    switch (call.method) {
      case 'requestPermissions':
        // İstenen izinlerin ADINI VARSAYMIYORUZ: gelen anahtarlar aynen
        // yanıtlanıyor (camera'nın sayısal karşılığını elle yazmak,
        // paket sürümüne bağlı kırılgan bir bilgi olurdu).
        final List<dynamic> requested = call.arguments as List<dynamic>;
        return <int, int>{
          for (final dynamic p in requested) p as int: status,
        };
      case 'checkPermissionStatus':
        return status;
      default:
        return null;
    }
  });
}

/// Gerçek G/Ç'yi `testWidgets` gövdesinde koşturmanın TEK doğru yolu.
///
/// ⚠️ `testWidgets` gövdesi SAHTE saatlidir; `writeAsString` gibi gerçek
/// G/Ç doğrudan `await` edilirse test **sonsuza kadar asılı kalır** (ölçüldü:
/// koşum kesilene dek bekledi). FakeAsync tuzağının bu dosyadaki görünüşü.
Future<T> realIo<T>(WidgetTester tester, Future<T> Function() body) async {
  late T out;
  await tester.runAsync(() async => out = await body());
  return out;
}
