import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/onboarding_screen.dart';
import 'package:gravita/app/onboarding_store.dart';
import 'package:gravita/app/onboarding_strings.dart';

/// İlk-açılış akışı — G-127 kapanışı (koordinatör sırası, 2026-08-12):
/// "lib/'de onboarding 0 dosya" gerçek yayın engeliydi.
///
/// ⚠️ KAPSAM DAR, bilerek: O1 (Value) · O2 (Safety consent) · O5 (Camera) —
/// `onboarding_strings.dart`'ın başındaki gerekçeyle O3/O4 (Profile/Pain)
/// atlandı. Kamera İZNİ TIKLAMASI da (gerçek `permission_handler` platform
/// kanalı gerektirir) sınanMIYOR — ailenin `LiveSessionScreen` için zaten
/// kabul ettiği "cihaz davranışı, sim'de yok" sınırının aynısı
/// (`run_all_gates.sh`'ın kapsam-dışı listesi).
void main() {
  group('OnboardingStore — kalıcılık, path_provider GEREKMEZ (File DI)', () {
    late Directory tmp;
    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('onboarding_store_test');
    });
    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('dosya YOKSA tamamlanmadı sayılır (ilk açılış)', () async {
      final OnboardingStore s = OnboardingStore.forFile(
        File('${tmp.path}/onboarding.json'),
      );
      expect(await s.isComplete(), isFalse);
    });

    test('markComplete SONRASI GERÇEKTEN kalıcı — yeni bir store aynı '
        'dosyayı okuyunca da tamamlandı görür', () async {
      final File f = File('${tmp.path}/onboarding.json');
      await OnboardingStore.forFile(f).markComplete();
      expect(await f.exists(), isTrue, reason: 'Dosyaya GERÇEKTEN yazıldı.');
      // Yeni bir örnek — process yeniden başlasa da AYNI kalır.
      expect(await OnboardingStore.forFile(f).isComplete(), isTrue);
    });

    test('BOZUK dosya tamamlanmadı sayılır — sonsuza dek kilitlemez', () async {
      final File f = File('${tmp.path}/onboarding.json')
        ..createSync(recursive: true);
      f.writeAsStringSync('{ bozuk json');
      expect(await OnboardingStore.forFile(f).isComplete(), isFalse);
    });

    /// H-20/21 (2026-08-16) — üçlü sabotajın ①'i (bozuk) üstteki test.
    /// Bu ikisi ②'yi (GEÇERLİ json + YANLIŞ tip) kapatır: `isComplete()`in
    /// `on Object` yakalayıcısı yalnız BOZUK sözdizimini değil, doğru
    /// sözdizimli ama beklenmeyen ŞEKİLLİ içeriği de görmelidir — bu iki
    /// yol farklı istisna sınıfları fırlatır (`FormatException` ↔ `TypeError`)
    /// ve dar bir `on FormatException` bu ikinciyi KAÇIRIRDI.
    test('GEÇERLİ json + YANLIŞ TİP (completed bir dize) — çökmeden '
        'tamamlanmadı sayılır', () async {
      final File f = File('${tmp.path}/onboarding.json')
        ..createSync(recursive: true);
      // `j['completed'] == true` bir EŞİTLİK, CAST değil — bu satır asla
      // fırlatmaz, yalnız `false` döner. Testin kanıtladığı budur: bu yolun
      // sessiz-yanlış değil sessiz-güvenli olduğu VARSAYIM değil ÖLÇÜM.
      f.writeAsStringSync(jsonEncode(<String, dynamic>{'completed': 'true'}));
      expect(await OnboardingStore.forFile(f).isComplete(), isFalse);
    });

    test('GEÇERLİ json ama tepe-seviye NESNE DEĞİL (dizi) — çökmeden '
        'tamamlanmadı sayılır', () async {
      final File f = File('${tmp.path}/onboarding.json')
        ..createSync(recursive: true);
      // `jsonDecode(...) as Map<String, dynamic>` burada TypeError fırlatır
      // (sözdizimi geçerli, biçim yanlış) — `on Object` bunu yakalamalı.
      f.writeAsStringSync(jsonEncode(<int>[1, 2, 3]));
      expect(await OnboardingStore.forFile(f).isComplete(), isFalse);
    });

    /// ③ (bilinmeyen şema sürümü) — bu depoda `schemaVersion` YAZILIR
    /// (`markComplete`) ama `isComplete()` hiç OKUMAZ. Pozitif ikiz: gelecek
    /// bir sürüm numarası akışı KIRMAMALI, çünkü okunan tek alan `completed`.
    test('BİLİNMEYEN şema sürümü + fazladan alanlar — completed hâlâ '
        'doğru okunur (ileriye dönük uyum)', () async {
      final File f = File('${tmp.path}/onboarding.json')
        ..createSync(recursive: true);
      f.writeAsStringSync(
        jsonEncode(<String, dynamic>{
          'completed': true,
          'schemaVersion': 999,
          'gelecekAlan': <String, dynamic>{'iceIce': 'baby'},
        }),
      );
      expect(
        await OnboardingStore.forFile(f).isComplete(),
        isTrue,
        reason:
            'isComplete() yalnız `completed` okur; bilinmeyen sürüm '
            'numarası ya da fazladan alan onu SAPTIRMAMALI.',
      );
    });

    test('markComplete alt dizinleri oluşturur (getApplicationSupport '
        'ilk açılışta yok olabilir)', () async {
      final File f = File('${tmp.path}/nested/does/not/exist/onboarding.json');
      await OnboardingStore.forFile(f).markComplete();
      expect(await f.exists(), isTrue);
      final Map<String, dynamic> j =
          jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      expect(j['completed'], isTrue);
    });
  });

  group('OnboardingFlow — O1 → O2 → O5, GERÇEK ekranlardan', () {
    testWidgets('O1: değer ekranı ne yaptığımızı VE yapmadığımızı gösterir', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: OnboardingFlow(onComplete: () async {})),
      );
      expect(find.text(OnboardingStrings.valueWhatWeDo), findsOneWidget);
      expect(find.text(OnboardingStrings.valueWhatWeDont), findsOneWidget);
      // İki adım ötesi henüz GÖRÜNMEMELİ.
      expect(find.text(OnboardingStrings.safetyDisclaimer), findsNothing);
    });

    testWidgets('O1 → O2: Continue basınca güvenlik onayına geçer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: OnboardingFlow(onComplete: () async {})),
      );
      await tester.tap(find.byKey(OnboardingFlow.valueContinueKey));
      await tester.pump();
      expect(find.text(OnboardingStrings.safetyDisclaimer), findsOneWidget);
      // safetyCopy.generalDisclaimer content/skill-graph/handstand.v1.json'dan
      // BİREBİR — elle yazılmadığının kanıtı: kaynakla AYNI dize.
      expect(
        OnboardingStrings.safetyDisclaimer,
        'Gravita is a movement-practice tool, not a medical service and '
        'not a substitute for an in-person coach. It cannot prevent a '
        'fall.',
      );
    });

    testWidgets(
      'O2 DISMISS EDİLEMEZ — sistem geri tuşu adımı atlamıyor (UI-BRIEF '
      'O2: "açık onay olmadan devam YOK")',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(home: OnboardingFlow(onComplete: () async {})),
        );
        await tester.tap(find.byKey(OnboardingFlow.valueContinueKey));
        await tester.pump();
        expect(find.text(OnboardingStrings.safetyDisclaimer), findsOneWidget);

        // `PopScope.canPop=false` — bu, sistem geri tuşunu/kaydırmasını
        // REDDEDEN gerçek Flutter mekanizmasıdır (framework'ün kendisi
        // uygular; burada test edilebilir olan onun DOĞRU KURULDUĞU).
        expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
      },
    );

    testWidgets('O2 → O5: onay basınca kamera adımına geçer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: OnboardingFlow(onComplete: () async {})),
      );
      await tester.tap(find.byKey(OnboardingFlow.valueContinueKey));
      await tester.pump();
      await tester.tap(find.byKey(OnboardingFlow.safetyConsentKey));
      await tester.pump();
      expect(find.text(OnboardingStrings.cameraRationale), findsOneWidget);
      // Aynı cümlenin ikinci yarısı `live_strings.dart`ın ret metniyle
      // BİREBİR — iki yerde iki farklı gerekçe olmasın diye.
      expect(
        OnboardingStrings.cameraRationale.contains(
          'nothing is recorded or uploaded',
        ),
        isTrue,
      );
    });
  });
}
