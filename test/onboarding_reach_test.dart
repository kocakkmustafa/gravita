import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/onboarding_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/launch_harness.dart';
import 'support/reachability_contract.dart';

/// ⚖️ KAPI-2 — SOĞUK AÇILIŞ payı ((c) hükmü, 2026-08-12).
///
/// 📌 **KANONİK GEZİLEBİLİRLİK SAYISI BURADA DEĞİL.** Kapı-1
/// (`reachability_test.dart`) tutar; bu kapı yalnız **soğuk açılışta
/// yürünen yüzeyleri** kanıtlar ve kapı-1 onu denklemde kullanır.
///
/// ## Ölçüm neden ikiye bölündü
///
/// Kapı-1 `GravitaShell`den başlıyor ve boyamadan sonra **hiç gerçek-zaman
/// turu açmıyor**. Soğuk açılıştan yürümek o turu **zorunlu** kılıyor
/// (`_completeOnboarding` → `getApplicationSupportDirectory` +
/// `parent.create` + `writeAsString` = en az üç adım), ve o tur ölçülmüş
/// `google_fonts` tuzağını tetikliyor (`fonts.gstatic.com` reddi → `runAsync`
/// penceresinde sahipsiz zone hatası; `takeException` yakalayamaz).
///
/// Üç panzehir ölçüldü: **testte font paketlemek** ürünü değiştirir ve başka
/// bir kapıyı kırmızıya düşürür · **tamamlamayı kalıcılıktan ayırmak** üretim
/// davranışını değiştirir (*bir ölçümü mümkün kılmak için ürünün davranışını
/// değiştirmek, ölçülen şeyi değiştirmektir*) · **bölmek** üretime dokunmaz.
/// Seçilen: bölmek. **Kabul edilmiş bedel: okuma yeri dağılıyor.**
void main() {
  testWidgets('SOĞUK AÇILIŞ: yürüyerek varılan yüzeyler kanıtlanıyor', (
    WidgetTester tester,
  ) async {
    final Directory tmp = Directory.systemTemp.createTempSync('cold_reach');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final PathProviderPlatform def = PathProviderPlatform.instance;
    addTearDown(() => PathProviderPlatform.instance = def);
    mockPermissionChannel(status: 0);

    await bootGravitaRoot(tester, supportPath: tmp.path, restoreTo: def);

    final Set<String> candidates = declaredScreens();
    final Set<String> reached = tester.allWidgets
        .map((Widget w) => w.runtimeType.toString())
        .where(candidates.contains)
        .toSet();

    // ⚠️ Aday envanteri ORTAK EVDEN geliyor; bu kapı kendi listesini
    // TUTMUYOR — iki kaynak tek olgu olmaz.
    expect(
      reached,
      kColdStartSurfaces,
      reason:
          'Soğuk açılışta varılan yüzey kümesi sözleşmedeki payla '
          'AYNI olmalı. Ayrışıyorsa denklemin bu yarısı bozuktur ve '
          'kapı-1 eksik bir bölmeyle hesaplar.',
    );

    // Ve yürüyüş GERÇEKTEN yürüyor: onboarding kullanıcı gibi geçilebiliyor.
    await tester.tap(find.byKey(OnboardingFlow.valueContinueKey));
    await tester.pump();
    await tester.tap(find.byKey(OnboardingFlow.safetyConsentKey));
    await tester.pump();
    expect(
      find.byType(OnboardingFlow),
      findsOneWidget,
      reason:
          'İki adım basılabildi; akış yürünebilir. (Kabuğa GEÇİŞ '
          'kapı-1\'in konusu — burada ölçülmez, çünkü o geçiş gerçek-zaman '
          'turu ister ve tuzağı tetikler.)',
    );
  });

  /// POZİTİF İKİZ — sözleşmenin payı **ölçülmüş** mü, yoksa yazılmış mı?
  test('sözleşme payı BOŞ DEĞİL ve envanterin ALT KÜMESİ', () {
    expect(
      kColdStartSurfaces,
      isNotEmpty,
      reason: 'Boş bir pay, üstteki testi koşulsuz doğru yapardı.',
    );
    expect(
      declaredScreens().containsAll(kColdStartSurfaces),
      isTrue,
      reason:
          'Soğuk açılış payı envanterde YOKSA denklem tutmaz — '
          'desen o yüzeyi hiç aday yapmıyor demektir.',
    );
  });
}
