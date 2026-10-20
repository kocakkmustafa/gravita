import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/calisthenics_course_screen.dart';
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

  testWidgets('TAZE KULLANICI: açılış onboarding\'e VARIR — kabuk çizilmez', (
    WidgetTester tester,
  ) async {
    await bootGravitaRoot(
      tester,
      supportPath: tmp.path,
      restoreTo: defaultProvider,
    );

    expect(
      find.byType(OnboardingFlow),
      findsOneWidget,
      reason:
          'İlk açılışın TEK kapısı burası. Bu satır düşüyorsa '
          'onboarding kullanıcının yolundan koparılmış demektir — '
          'dosyaların VARLIĞI bunu göstermez (G-181 sabotaj ölçümü).',
    );
    expect(
      find.byType(GravitaShell),
      findsNothing,
      reason:
          'Onay alınmadan kabuk ÇİZİLMEZ; "önce göster sonra sor" '
          'güvenlik onayını süse çevirir.',
    );
  });

  testWidgets(
    'POZİTİF İKİZ — onboarding TAMAMLANMIŞSA kabuk gelir, akış TEKRARLAMAZ',
    (WidgetTester tester) async {
      // Bit'i ürünün KENDİ yazıcısıyla kur (şema anahtarını elle yazmak,
      // ailenin ölçülmüş enjeksiyon-hatası dersidir: gerçek yazıcıyı kullan).
      await realIo(
        tester,
        () => OnboardingStore.forFile(
          File('${tmp.path}/onboarding.json'),
        ).markComplete(),
      );
      await bootGravitaRoot(
        tester,
        supportPath: tmp.path,
        restoreTo: defaultProvider,
      );

      expect(find.byType(GravitaShell), findsOneWidget);
      expect(
        find.byType(OnboardingFlow),
        findsNothing,
        reason:
            'Bu ikiz olmadan üstteki iddia, onboarding\'i HER açılışta '
            'gösteren bir uygulamada da geçerdi — koşulsuz doğru bir kapı '
            'hiçbir şey ölçmez.',
      );
    },
  );

  group(
    'HAPPY PATH — G-218\'in belirsiz bıraktığı gözlem (2026-08-16, A1)',
    () {
      testWidgets('fresh guest can skip camera, persist onboarding and open '
          'the course without any permission calls', (tester) async {
        const channel = MethodChannel(
          'flutter.baseflow.com/permissions/methods',
        );
        final calls = <MethodCall>[];
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          throw StateError('The guest course path must not request permission');
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        await bootGravitaRoot(
          tester,
          supportPath: tmp.path,
          restoreTo: defaultProvider,
          size: const Size(390, 844),
        );
        await tester.tap(find.byKey(OnboardingFlow.valueContinueKey));
        await tester.pump();
        await tester.tap(find.byKey(OnboardingFlow.safetyConsentKey));
        await tester.pump();
        expect(find.byKey(OnboardingFlow.cameraDeniedKey), findsNothing);
        expect(find.byKey(OnboardingFlow.cameraAllowKey), findsNothing);
        final skip = find.byKey(OnboardingFlow.cameraContinueWithoutKey);
        expect(skip.hitTestable(), findsOneWidget);

        PathProviderPlatform.instance = FakeSupportDir(tmp.path);
        await tester.tap(skip);
        await settleUntil(
          tester,
          () => find.byType(GravitaShell).evaluate().isNotEmpty,
        );
        expect(find.byType(GravitaShell), findsOneWidget);
        expect(
          await realIo(
            tester,
            () => OnboardingStore.forFile(
              File('${tmp.path}/onboarding.json'),
            ).isComplete(),
          ),
          isTrue,
        );
        final courseEntry = find.byKey(const Key('calisthenics.entry')).first;
        await tester.ensureVisible(courseEntry);
        await tester.tap(courseEntry);
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CalisthenicsCourseScreen), findsOneWidget);
        expect(find.textContaining('Progress could not be read'), findsNothing);
        expect(calls, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      /// ⭐ G-218 (2026-08-14) bu akışı GERÇEK simülatörde yürütürken
      /// `flutter run` sona erdi; "akışın tamamlanıp tamamlanmadığı belirsiz"
      /// kaldı. O turda zorlanmadı (G-219'un kararı: belirsiz gözlemden sebep
      /// üretme) — B5 (font ağ reddi) kalkana kadar bekletildi. F2 (D1)
      /// indi, artık zorlanabilir: burada gerçek simülatör yerine gerçek
      /// widget ağacı + gerçek dosya G/Ç kullanılıyor (ürünün KENDİ kapısı,
      /// bkz. dosya başı doc), ama iddia AYRIŞTIRILMIŞ — Ostinato'nun `O-138`
      /// dersi: *"UI yürüyüşü ile motor gerçeği İKİ AYRI İDDİA."*
      ///
      /// Kapalı release'in gerçek root yolu izin istemeden tamamlanır.
      /// Koşullu granted/denied yolları ayrı permissionTest fixture'ındadır.
      testWidgets('kapalı kamera akışı izin istemeden tamamlanır, '
          'SONRAKİ açılış onboarding\'i atlar', (WidgetTester tester) async {
        const channel = MethodChannel(
          'flutter.baseflow.com/permissions/methods',
        );
        var permissionCalls = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async {
            permissionCalls++;
            throw StateError('Closed release must not call permission channel');
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        await bootGravitaRoot(
          tester,
          supportPath: tmp.path,
          restoreTo: defaultProvider,
        );
        expect(find.byType(OnboardingFlow), findsOneWidget);

        // ① UI-GÖZLEMLİ İDDİA: akışı gerçek kontrollerle yürü, O1 → O2 → O5.
        await tester.tap(find.byKey(OnboardingFlow.valueContinueKey));
        await tester.pump();
        await tester.tap(find.byKey(OnboardingFlow.safetyConsentKey));
        await tester.pump();
        expect(find.text(OnboardingStrings.cameraRationale), findsOneWidget);

        // ⭐ KENDİ BULGUM (A1 turu): `bootGravitaRoot` sahte sağlayıcıyı
        // yalnız İLK `pumpWidget` penceresinde açık tutuyor (harness'ın kendi
        // ② numaralı tuzağı — "sağlayıcı O AN açık olmalı, sonrasında değil").
        // Ama `OnboardingStore.open()` İKİ AYRI yerde çağrılıyor
        // (`gravita_app.dart:86` okuma-boot'ta · `:102` yazma-tamamlanmada) —
        // harness yalnız BİRİNCİYİ hesaba katıyordu. Bu tap ikinci çağrıyı
        // tetikliyor; sağlayıcı burada YENİDEN açılmazsa `getApplication
        // SupportDirectory()` GERÇEK platforma düşer (`flutter test`te
        // uygulaması yok → fırlatır), ürünün KENDİ fail-open tasarımı
        // (`_completeOnboarding`, `on Object` yutar) bunu SESSİZCE yutar ve
        // kabuk yine görünür — ama dosya HİÇ yazılmaz. İlk denemem TAM BUNA
        // düştü: kabuk göründü, `wrote` `false` çıktı — ürün kusuru değil,
        // testin kendi sağlayıcı penceresi kapalıydı.
        PathProviderPlatform.instance = FakeSupportDir(tmp.path);
        expect(find.byKey(OnboardingFlow.cameraAllowKey), findsNothing);
        await tester.tap(find.byKey(OnboardingFlow.cameraContinueWithoutKey));
        // onComplete() gerçek G/Ç ile yazıyor; zincir tek pump'la
        // bitmez. Sabit tur sayısı YETMİYOR (harness'ın kendi ③ numaralı
        // dersi — `bootGravitaRoot`un kendisi de bunun için SABİT değil
        // KOŞULLU döngü kullanıyor): burada da aynı desen — yükleyici/eski
        // ekran gidene kadar tur aç, uydurma bir sayıda durma.
        for (
          int round = 0;
          round < 8 && find.byType(OnboardingFlow).evaluate().isNotEmpty;
          round++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 150)),
          );
          await tester.pump(const Duration(milliseconds: 80));
        }
        PathProviderPlatform.instance = defaultProvider;

        expect(
          find.byType(GravitaShell),
          findsOneWidget,
          reason:
              'UI-GÖZLEMLİ İDDİA: akış tamamlandı, kabuk göründü. '
              'Kapalı sürümde izin veya ret dalı açılmadan tamamlanmalı.',
        );
        expect(find.byKey(OnboardingFlow.cameraDeniedKey), findsNothing);
        expect(permissionCalls, 0);

        // ② MOTOR-SONUCU İDDİASI — AYRI ölçülür: UI kabuğa geçti diye
        // dosyanın GERÇEKTEN yazıldığı çıkarılmaz.
        final bool wrote = await realIo(
          tester,
          () => File('${tmp.path}/onboarding.json').exists(),
        );
        expect(
          wrote,
          isTrue,
          reason: 'MOTOR-SONUCU İDDİASI: kalıcı bit gerçekten diske yazıldı.',
        );

        // ③ G-218'İN TAM SORUSU: bu kalıcılık bir SONRAKİ, TAMAMEN YENİ
        // widget ağacında yeniden okunuyor mu? Aynı StatefulWidget tipini
        // pump etmek state'i koruyabilir; önce açıkça unmount et. Bu bir
        // host remount kontrolüdür, native OS cold-start kabulü değildir.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await bootGravitaRoot(
          tester,
          supportPath: tmp.path,
          restoreTo: defaultProvider,
        );

        expect(
          find.byType(GravitaShell),
          findsOneWidget,
          reason:
              'G-218: SONRAKİ açılış onboarding\'i atlamalı — bu soru '
              'o gece flutter run çöktüğü için hiç ölçülememişti.',
        );
        expect(find.byType(OnboardingFlow), findsNothing);
      });
    },
  );

  group('DEPOLAMA ARIZASI — göster, ama kalıcılaştırma (G-183 / hüküm b)', () {
    // Kapalı sürümde doğrudan continue-without kullanılır; bu handler
    // mevcut olsa bile release yolu hiçbir permission isteği yapmamalı.
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
    testWidgets('okunamayan depoda onboarding GÖSTERİLİR — onay atlanmaz', (
      WidgetTester tester,
    ) async {
      await bootGravitaRoot(
        tester,
        supportPath: null,
        restoreTo: defaultProvider,
      );

      expect(
        find.byType(OnboardingFlow),
        findsOneWidget,
        reason: 'Arıza, güvenlik onayını askıya alamaz.',
      );
      expect(find.byType(GravitaShell), findsNothing);
    });

    /// Hükmün İKİNCİ yarısı — ve kapının iki yarısı birlikte tasarlanır.
    /// Okuma fail-closed olunca yazma da yutulmazsa, bozuk depolamalı bir
    /// cihazda kullanıcı onayı verir ve HİÇBİR YERE gidemezdi. Bu test tam
    /// o çıkmaz sokağı yasaklıyor.
    testWidgets('onay verilince kabuğa GEÇİLİR — yazma hatası KİLİTLEMEZ', (
      WidgetTester tester,
    ) async {
      await bootGravitaRoot(
        tester,
        supportPath: null,
        restoreTo: defaultProvider,
      );
      expect(find.byType(OnboardingFlow), findsOneWidget);

      // Akışı gerçek kontrollerle geç: O1 → O2 → O5.
      await tester.tap(find.byKey(OnboardingFlow.valueContinueKey));
      await tester.pump();
      await tester.tap(find.byKey(OnboardingFlow.safetyConsentKey));
      await tester.pump();
      expect(find.text(OnboardingStrings.cameraRationale), findsOneWidget);

      expect(find.byKey(OnboardingFlow.cameraAllowKey), findsNothing);
      expect(find.byKey(OnboardingFlow.cameraDeniedKey), findsNothing);
      await tester.tap(find.byKey(OnboardingFlow.cameraContinueWithoutKey));
      // `markComplete` GERÇEK G/Ç dener ve arızada FIRLATIR; ürün onu yutup
      // yine de kabuğa geçmeli. Gerçek-zaman turu o denemeye yer açıyor.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(
        find.byType(GravitaShell),
        findsOneWidget,
        reason:
            'Kalıcılık BAŞARISIZ olabilir; giriş engellenemez. Aksi '
            'hâlde bozuk depolamalı cihazda uygulama ÇIKMAZ SOKAK olurdu.',
      );
    });

    /// Ve "kalıcılaştırılmaz" gerçekten ÖLÇÜLÜYOR: arızalı depoda hiçbir
    /// dosya doğmaz, dolayısıyla bir sonraki açılış akışı TEKRAR sorar.
    /// Tekrar sorması KABUL EDİLMİŞ maliyettir (hüküm b), gizlenecek kusur
    /// değil — bu yüzden test onu iddia olarak DEĞİL, ölçüm olarak tutuyor.
    testWidgets('arızalı depoda BİT YAZILMAZ — sonraki açılış tekrar sorar', (
      WidgetTester tester,
    ) async {
      await bootGravitaRoot(
        tester,
        supportPath: null,
        restoreTo: defaultProvider,
      );
      await tester.tap(find.byKey(OnboardingFlow.valueContinueKey));
      await tester.pump();
      await tester.tap(find.byKey(OnboardingFlow.safetyConsentKey));
      await tester.pump();
      expect(find.byKey(OnboardingFlow.cameraAllowKey), findsNothing);
      await tester.tap(find.byKey(OnboardingFlow.cameraContinueWithoutKey));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();

      final bool wrote = await realIo(
        tester,
        () => File('${tmp.path}/onboarding.json').exists(),
      );
      expect(
        wrote,
        isFalse,
        reason: 'Arızalı depoya yazılamaz; "kalıcılaştırılmaz" yarısı.',
      );
    });
  });
}
