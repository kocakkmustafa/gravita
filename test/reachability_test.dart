import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/gravita_app.dart';
import 'package:gravita/app/theme.dart';

import 'support/reachability_contract.dart';

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

  /// ⚖️ Aday envanteri ORTAK EVDEN (`support/reachability_contract.dart`).
  /// Bu kapı kendi listesini TUTMAZ — iki kaynak tek olgu olmaz.
  /// 📌 **KANONİK SAYI BURADADIR**; soğuk açılış payı kapı-2'de kanıtlanır.

  /// O an ağaçta MONTE olan ekranlar — "görünür" değil, "monte".
  bool pushed(WidgetTester tester) {
    final Iterable<Element> navs = find.byType(Navigator).evaluate();
    if (navs.isEmpty) return false;
    return (tester.state(find.byType(Navigator).first) as NavigatorState)
        .canPop();
  }

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
  /// ⚖️ KATI okuma: itilen her AYRI ROTA. Sekmeler tek `Scaffold` içinde
  /// değişen gövdelerdir — rota değil, KABUK içi geçiş.
  ///
  /// > *Bir sayı, hangi kuralla çıktığı yazılmadan hatlar arasında
  /// > karşılaştırılamaz.* Bu yüzden kapı İKİSİNİ de basıyor.
  ///
  /// ⚠️ `NavigatorObserver` ile ölçmeyi DENEDİM ve düştü: rota nesnesi
  /// kendi içeriğini söylemiyor, hepsi `MaterialPageRoute<void>` görünüyor
  /// ve sayaç sessizce **1** derdi. Bu adsız-rota tuzağı bu gecenin
  /// "yüzeyi değil proxy'yi ölçme" desenidir. Onun yerine ROTA DERİNLİĞİ
  /// ölçülüyor: bir ekran ancak `canPop()` doğruyken monte olduysa
  /// AYRI ROTADIR.
  final Set<String> routeScreens = <String>{};

  /// Kabuk, itilen rotanın ALTINDA monte kalır — bu yüzden "derinlik>0'da
  /// monte" tek başına yetmiyor, kabukta da görülenler ÇIKARILMALI.
  /// (İlk ölçüm bu yüzden 8 dedi: dört sekme gövdesi rota sanılmıştı.)
  final Set<String> shellScreens = <String>{};

  testWidgets('GEZİLEBİLİR EKRAN SAYIMI — kapıdan, gözden değil',
      (WidgetTester tester) async {
    // ⚠️ 4000pt YÜKSEKLİK KASITLI ve bir MODELDİR: gerçek cihazda
    // kaydırarak ulaşılan her şey burada tek ekranda duruyor. Kaydırarak
    // ulaşılabilen bir ekran GEZİLEBİLİRDİR, o yüzden bu şişirme değil.
    //
    // Ölçüldü: `hitTestable` + merkez-görünür süzgeci eklendikten sonra
    // sayı DEĞİŞMEDİ (4/7) — yani bu yükseklikte hayalet dokunuş yok.
    // Süzgeç yine de duruyor: yükseklik bir gün gerçekçileşirse kapı
    // sessizce şişmesin.
    tester.view.physicalSize = const Size(375, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final Set<String> candidates = declaredScreens();
    final Set<String> reached = <String>{};

    late ContentRepository content;
    await tester.runAsync(
        () async => content = await ContentRepository.load(rootBundle));

    await tester.pumpWidget(MaterialApp(
        theme: GravitaTheme.light,
        home: GravitaShell(content: content)));
    await settle(tester);
    reached.addAll(mounted(tester, candidates));
    shellScreens.addAll(mounted(tester, candidates));

    /// Ekranda GÖRÜNEN ve basılabilir olan her şey — tip listesi değil,
    /// `hitTestable` ile gerçekten dokunulabilir olanlar.
    /// ⚠️ `hitTestable()` TEK BAŞINA YETMİYOR (Choreia aktarımı, ölçüldü):
    /// tembel `ListView` `cacheExtent` kadar **görünür alanın ALTINDA**
    /// widget kuruyor. `find` onları buluyor, `hitTestable` da geçiriyor
    /// (ağaçta ve hit-test edilebilirler), ama merkezleri ekranın DIŞINDA —
    /// `tap` boşluğa iner ve `warnIfMissed:false` bunu SESSİZCE yutar.
    ///
    /// > *Yürüyüş `find`de değil, gerçekten dokunulabilirlikte dursun.*
    ///
    /// Bu yüzden ek süzgeç: widget'ın merkezi görünür alanın İÇİNDE olmalı.
    bool onScreen(Element e) {
      final RenderObject? r = e.renderObject;
      if (r is! RenderBox || !r.hasSize) return false;
      final Offset c = r.localToGlobal(r.size.center(Offset.zero));
      final Size v = tester.view.physicalSize / tester.view.devicePixelRatio;
      return c.dx >= 0 && c.dy >= 0 && c.dx <= v.width && c.dy <= v.height;
    }

    List<Element> tappables() => <Element>[
          ...find.byType(InkWell, skipOffstage: true).hitTestable().evaluate(),
          ...find
              .byType(FloatingActionButton, skipOffstage: true)
              .hitTestable()
              .evaluate(),
          ...find
              .byType(NavigationDestination, skipOffstage: true)
              .evaluate(),
        ].where(onScreen).toList();

    // ---- Katman 1: sekmeler ----
    final int tabCount =
        find.byType(NavigationDestination, skipOffstage: false).evaluate().length;
    for (int i = 0; i < tabCount; i++) {
      final Finder dest =
          find.byType(NavigationDestination, skipOffstage: false).at(i);
      await tester.tap(dest, warnIfMissed: false);
      await settle(tester);
      reached.addAll(mounted(tester, candidates));
      shellScreens.addAll(mounted(tester, candidates));

      // ---- Katman 2: o sekmedeki ilk basılabilir kontroller ----
      final int n = tappables().length;
      for (int k = 0; k < n && k < 8; k++) {
        final List<Element> live = tappables();
        if (k >= live.length) break;
        await tester.tap(find.byWidget(live[k].widget), warnIfMissed: false);
        await settle(tester);
        reached.addAll(mounted(tester, candidates));
        if (pushed(tester)) routeScreens.addAll(mounted(tester, candidates));

        // ---- Katman 3: açılan ekrandaki kontroller ----
        final List<Element> deep = tappables();
        for (int d = 0; d < deep.length && d < 4; d++) {
          final List<Element> live2 = tappables();
          if (d >= live2.length) break;
          await tester.tap(find.byWidget(live2[d].widget),
              warnIfMissed: false);
          await settle(tester);
          reached.addAll(mounted(tester, candidates));
          if (pushed(tester)) routeScreens.addAll(mounted(tester, candidates));
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

    // ⚠️ Soğuk açılış payı BURADA "ulaşılamayan" DEĞİLDİR — ona kapı-2
    // yürüyerek varıyor. Düşülmezse bölme, kendi ürettiği bir yüzeyi
    // kayıp sanır (bölmenin ilk koşumunda ölçüldü: 1 → 2).
    final List<String> unreachable = candidates
        .difference(reached)
        .difference(kColdStartSurfaces)
        .toList()
      ..sort();
    final List<String> reachedSorted = reached.toList()..sort();

    final List<String> routes =
        routeScreens.difference(shellScreens).toList()..sort();

    debugPrint('── GEZİLEBİLİRLİK ÖLÇÜMÜ ──');
    debugPrint('   ⚖️ KATI (ayrı ROTA): ${routes.length + 1} — '
        'kabuk(1: 4 sekme) + ${routes.join(' · ')}');
    debugPrint('   ⚖️ GEVŞEK (ayrı YÜZEY): ${reached.length}');
    debugPrint('   yüzeyler: ${reachedSorted.join(' · ')}');
    debugPrint('   ULAŞILAMIYOR AMA VAR: ${unreachable.length}'
        '${unreachable.isEmpty ? '' : ' — ${unreachable.join(' · ')}'}');

    // Kapı SAYIYI SABİTLEMİYOR — küçülmesini yasaklıyor. Sayı büyüdüğünde
    // sessizce geçer, küçüldüğünde bağırır: bir ekran ulaşılamaz hâle
    // gelirse (tetiği silinirse) bu satır öter.
    // ⚠️ TABAN, ÖLÇÜLEN DEĞERE ÇEKİLDİ (G-187, 2026-08-12): `6` → **7**.
    // Eşik İCADI değil, bugün ölçülen sayının kendisi.
    //
    // ⚠️ VE GEREKÇESİ SABOTAJLA İNCELTİLDİ — ilk yazdığım gerekçe FAZLA
    // GENİŞTİ. "Bir ekran sessizce ulaşılamaz olabilirdi" demiştim; ölçtüm:
    // bir ekranın TETİĞİ koparıldığında `unreachable` 1→2 çıkıyor ve
    // aşağıdaki üçüncü iddia zaten ötüyor. Yani eski taban o vakayı
    // kaçırmıyordu.
    //
    // Bu tabanın gerçekten kapattığı boşluk BAŞKA ve daha sinsi: bir ekran
    // TAMAMEN SİLİNİRSE aday listesi de küçülür (envanter kaynaktan
    // türetiliyor), `unreachable` 1'de kalır ve `6 >= 6` sessizce geçerdi.
    // → *Bağlantısı kopan ekranı üçüncü iddia yakalar; YOK OLAN ekranı
    //   yalnız bu taban yakalar.* İki ayrı regresyon, iki ayrı nöbetçi.
    expect(reached.length, greaterThanOrEqualTo(7),
        reason: 'Gezilebilir ekran sayısı düştü — bir tetik silinmiş '
            'olabilir. Ulaşılamayanlar: ${unreachable.join(', ')}');

    // "Ulaşılamıyor ama var" listesi BOŞ OLMAK ZORUNDA DEĞİL; ama sessiz
    // kalamaz. Büyürse ötsün: yeni yazılan her ekran ya bağlanmalı ya da
    // burada bilerek listelenmeli.
    // Bugün TEK kalem bekleniyor: `ContentFailureScreen` — sistemin
    // gösterdiği hata hâli, kullanıcının BASARAK gitmediği bir ekran.
    // Sayı artarsa yeni bir ekran bağlanmadan yazılmış demektir.
    // KATI sayı da küçülemez: bir rota tetiği silinirse burası öter.
    expect(routes.length + 1, greaterThanOrEqualTo(4),
        reason: 'Ayrı rota sayısı düştü — bir push tetiği kaybolmuş '
            'olabilir. Ulaşılan rotalar: ${routes.join(', ')}');

    // ⚖️ DENKLEM — İKİ KAPI ARASINDA (aile kısıtı ①). Her kapı kendi
    // içinde tutarsa İKİSİ BİRDEN eksik olabilir; bu satır o boşluğu kapatır.
    final Set<String> hesap = <String>{
      ...reached, ...kColdStartSurfaces, ...kDeliberatelyUnreachable
    };
    expect(hesap, candidates,
        reason: 'BÖLME KAYIP ÜRETTİ: aday envanteri = kabuk yürüyüşü ⊎ '
            'soğuk açılış payı ⊎ kasıtlı-varılamayan denklemi tutmuyor. '
            'Fark: ${candidates.difference(hesap)} / ${hesap.difference(candidates)}');

    expect(unreachable.length, lessThanOrEqualTo(1),
        reason: 'Bağlanmamış ekran sayısı arttı: ${unreachable.join(', ')} — '
            'repliğin varlığı tetiğinin varlığı DEĞİLDİR.');
  });
}

