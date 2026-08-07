import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/gravita_app.dart';
import 'package:gravita/app/theme.dart';

/// ⭐ GEZİLEBİLİRLİK KAPISI — *"bugün kullanıcı kaç ayrı ekrana GİDEBİLİYOR?"*
///
/// Bu sayı bir kez elle sayıldı (02:00) ve **bayatladı**. Bayat öncülle
/// verilen karar, bayat öncülle verilen her karar gibi yanlış çıkar — bu
/// yüzden sayı artık **kapıdan** geliyor: her koşuda yeniden ölçülür.
///
/// ## Sayma kuralı (aile geneli, karşılaştırılabilir olsun diye)
///
/// * **Sayılır:** açılıştan başlayarak, YALNIZ ekranda görünen kontrollere
///   basarak ulaşılan her ayrı ekran.
/// * **Sayılmaz:** kodda tanımlı ama hiçbir yerden ulaşılamayan ekran
///   (*repliğin varlığı ≠ tetiğinin varlığı*) · yalnız derin bağlantı ya da
///   test kancasıyla açılan.
///
/// ## Ekran envanteri ELLE TUTULMUYOR
///
/// Aday listesi `lib/app/*.dart` kaynağından türetilir: `Screen`/`Page`/`Tab`
/// ile biten her widget sınıfı. Elle tutulan bir liste, yeni bir ekran
/// eklendiği gün sessizce eksik kalır ve kapı *"hepsi ulaşılabilir"* derdi —
/// bu gecenin defalarca yakaladığı desen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Kaynaktan türetilen ekran adayları.
  Set<String> declaredScreens() {
    final RegExp cls = RegExp(
        r'^class\s+(\w+(?:Screen|Page|Tab))\s+extends\s+(?:Stateless|Stateful)Widget',
        multiLine: true);
    final Set<String> out = <String>{};
    for (final FileSystemEntity f in Directory('lib/app').listSync()) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final RegExpMatch m in cls.allMatches(f.readAsStringSync())) {
        out.add(m.group(1)!);
      }
    }
    return out;
  }

  /// O an ağaçta MONTE olan ekranlar — "görünür" değil, "monte".
  Set<String> mounted(WidgetTester tester, Set<String> candidates) => tester
      .allWidgets
      .map((Widget w) => w.runtimeType.toString())
      .where(candidates.contains)
      .toSet();

  /// ⚠️ `pumpAndSettle` BURADA KULLANILAMAZ ve bu ölçülmüş bir sınır:
  /// içerik gerçek asset bundle'dan geliyor, o da `runAsync` istiyor;
  /// ayrıca kalıcı bir animasyon varsa `pumpAndSettle` süresiz bekler.
  /// Sınırlı pump, "yerleşti mi" sorusunu cevaplamaz ama TAKILMAZ — ve
  /// gezilebilirlik ölçümü için yerleşme değil MONTE OLMA yeterli.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    // ⚠️ `takeException` framework'ün KENDİ kanalı — `FlutterError.onError`'ı
    // devralmak yerine bunu kullanmak gerekiyor, yoksa flutter_test kendi
    // assert'iyle düşüyor ("expect before restoring onError").
  }

  /// ⭐ SIRA ÖNEMLİ ve bu ölçülmüş: **içerik ÖNCE, boya SONRA.**
  ///
  /// `GravitaApp`i pump edip sonra `runAsync` çağırmak G-126'yı tetikliyor:
  /// ilk boyama google_fonts'un ağ isteğini başlatıyor, `runAsync`in
  /// gerçek-zaman penceresi de o isteğin REDDİNİ sahipsiz bir async hata
  /// olarak teste sızdırıyor — ne `takeException` ne `runZonedGuarded`
  /// yakalıyor (üçü de denendi ve ölçüldü).
  ///
  /// Panzehir bir bayrak değil, SIRA: içeriği boyamadan önce yükle, sonra
  /// yalnız saf pump kullan. Render probu da tam bu sırayla yeşil.
  ///
  /// ## Bunun KAPSAM BEDELİ — açıkça yazılıyor
  ///
  /// Ölçüm `GravitaShell`den başlıyor, `GravitaApp`ten değil. Yani içerik
  /// KAPISININ kendi ekranları (yükleniyor / `ContentFailureScreen`) bu
  /// sayının DIŞINDA. Onlar kullanıcının gördüğü ekranlar ama "gezilebilir"
  /// değil — kullanıcı onlara BASARAK gitmez, sistem onları gösterir.
  testWidgets('GEZİLEBİLİR EKRAN SAYIMI — kapıdan, gözden değil',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final Set<String> candidates = declaredScreens();
    final Set<String> reached = <String>{};

    late ContentRepository content;
    await tester.runAsync(
        () async => content = await ContentRepository.load(rootBundle));

    await tester.pumpWidget(MaterialApp(
        theme: GravitaTheme.light, home: GravitaShell(content: content)));
    await settle(tester);
    reached.addAll(mounted(tester, candidates));

    /// Ekranda GÖRÜNEN ve basılabilir olan her şey — tip listesi değil,
    /// `hitTestable` ile gerçekten dokunulabilir olanlar.
    List<Element> tappables() => <Element>[
          ...find.byType(InkWell, skipOffstage: true).hitTestable().evaluate(),
          ...find
              .byType(FloatingActionButton, skipOffstage: true)
              .hitTestable()
              .evaluate(),
          ...find
              .byType(NavigationDestination, skipOffstage: true)
              .evaluate(),
        ];

    // ---- Katman 1: sekmeler ----
    final int tabCount =
        find.byType(NavigationDestination, skipOffstage: false).evaluate().length;
    for (int i = 0; i < tabCount; i++) {
      final Finder dest =
          find.byType(NavigationDestination, skipOffstage: false).at(i);
      await tester.tap(dest, warnIfMissed: false);
      await settle(tester);
      reached.addAll(mounted(tester, candidates));

      // ---- Katman 2: o sekmedeki ilk basılabilir kontroller ----
      final int n = tappables().length;
      for (int k = 0; k < n && k < 8; k++) {
        final List<Element> live = tappables();
        if (k >= live.length) break;
        await tester.tap(find.byWidget(live[k].widget), warnIfMissed: false);
        await settle(tester);
        reached.addAll(mounted(tester, candidates));

        // ---- Katman 3: açılan ekrandaki kontroller ----
        final List<Element> deep = tappables();
        for (int d = 0; d < deep.length && d < 4; d++) {
          final List<Element> live2 = tappables();
          if (d >= live2.length) break;
          await tester.tap(find.byWidget(live2[d].widget),
              warnIfMissed: false);
          await settle(tester);
          reached.addAll(mounted(tester, candidates));
          // Geri dön; kök route'ta pop yoksa sessizce yut.
          final NavigatorState nav =
              tester.state(find.byType(Navigator).first);
          if (nav.canPop()) {
            nav.pop();
            await settle(tester);
          }
        }
        final NavigatorState nav = tester.state(find.byType(Navigator).first);
        if (nav.canPop()) {
          nav.pop();
          await settle(tester);
        }
      }
    }

    final List<String> unreachable = candidates.difference(reached).toList()
      ..sort();
    final List<String> reachedSorted = reached.toList()..sort();

    debugPrint('── GEZİLEBİLİRLİK ÖLÇÜMÜ ──');
    debugPrint('   GEZİLEBİLİR: ${reached.length} — ${reachedSorted.join(' · ')}');
    debugPrint('   ULAŞILAMIYOR AMA VAR: ${unreachable.length}'
        '${unreachable.isEmpty ? '' : ' — ${unreachable.join(' · ')}'}');

    // Kapı SAYIYI SABİTLEMİYOR — küçülmesini yasaklıyor. Sayı büyüdüğünde
    // sessizce geçer, küçüldüğünde bağırır: bir ekran ulaşılamaz hâle
    // gelirse (tetiği silinirse) bu satır öter.
    expect(reached.length, greaterThanOrEqualTo(6),
        reason: 'Gezilebilir ekran sayısı düştü — bir tetik silinmiş '
            'olabilir. Ulaşılamayanlar: ${unreachable.join(', ')}');

    // "Ulaşılamıyor ama var" listesi BOŞ OLMAK ZORUNDA DEĞİL; ama sessiz
    // kalamaz. Büyürse ötsün: yeni yazılan her ekran ya bağlanmalı ya da
    // burada bilerek listelenmeli.
    // Bugün TEK kalem bekleniyor: `ContentFailureScreen` — sistemin
    // gösterdiği hata hâli, kullanıcının BASARAK gitmediği bir ekran.
    // Sayı artarsa yeni bir ekran bağlanmadan yazılmış demektir.
    expect(unreachable.length, lessThanOrEqualTo(1),
        reason: 'Bağlanmamış ekran sayısı arttı: ${unreachable.join(', ')} — '
            'repliğin varlığı tetiğinin varlığı DEĞİLDİR.');
  });
}
