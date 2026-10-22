import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/account_connection.dart';
import 'package:gravita/app/gravita_account_page.dart';

import 'account_action_ticket_test.dart' show AccountHttpFixture;
import 'package:gravita/app/gravita_app.dart';
import 'package:gravita/app/language_preferences.dart';
import 'package:gravita/app/theme_preferences.dart';
import 'package:gravita/app/theme.dart';
import 'package:gravita/app/surface_widgets.dart';
import 'package:gravita/app/movement_page.dart';
import 'package:gravita/app/calisthenics_course_screen.dart';

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
  late AccountHttpFixture accountFixture;
  setUp(() => accountFixture = AccountHttpFixture());
  tearDown(() => accountFixture.dispose());

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

  testWidgets('GEZİLEBİLİR EKRAN SAYIMI — kapıdan, gözden değil', (
    WidgetTester tester,
  ) async {
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

    // ⚖️ (e) ELLE KÜME — **kaynak değil, türetimin POZİTİF KONTROLÜ** (G-198).
    //
    // Bu satır türetime *"bildiğimizi kapsıyor musun?"* diye sorar. Türetim
    // bozulursa — desen daraltılırsa, `_XState` sınıfı bir eleme yazılırsa,
    // dizin taraması bir dosyayı ıskalarsa — kapı BURADA öter, sayı sessizce
    // küçülmeden önce.
    //
    // ⚠️ ŞERH 1: [kKnownFloor] bir **ALT SINIRDIR, tam envanter DEĞİLDİR.**
    // ⚠️ ŞERH 2: oraya ekleme yapmak envanter güncellemesi DEĞİL,
    //    **kontrolün TABANINI yükseltmektir.**
    //
    // > *Bir elle liste, KAYNAK olarak yanlıştır ama KONTROL olarak doğrudur.*
    expect(
      candidates.containsAll(kKnownFloor),
      isTrue,
      reason:
          'TÜRETİM BİLİNEN TABANI KAPSAMIYOR — eksik: '
          '${kKnownFloor.difference(candidates)}. Elle küme kaynak değil '
          'kontroldür: türetim onu yutuyorsa bozuk olan TÜRETİMDİR, taban '
          'değil. (Tabanı küçülterek geçirme — desen neden kaçırdı, ONU ölç.)',
    );

    // ⚖️ (a) İKİNCİ TÜRETİM KANALI — *iki bağımsız türetimin uzlaşması* (G-198).
    //
    // AD kanalı sınıf **bildirimine** bakar, YAPI kanalı **montaj noktasına**.
    // Ayrışırlarsa kapı öter: yapıda monte edilen ama ad deseninin kaçırdığı
    // bir sınıf, envanterde **hayalet** demektir.
    //
    // ⚠️ Yön TEK TARAFLI ve bu bilerek: `montaj ⊆ ad`. Tersi (ad ∖ montaj)
    // ölçüldü ve **boş değil** — `ContentFailureScreen` (sistem gösterir) ·
    // `OnboardingFlow` (kök, montaj noktası yok) · `LibraryScreen` ·
    // `ProfileScreen` · `ProgressTab` (sekme gövdeleri kabuğun İÇİNDE).
    // Çift yönlü eşitlik istemek **gerçek hedefleri hayalet ilan ederdi.**
    final Set<String> byMount = mountedScreens();
    debugPrint('── (a) İKİ KANAL ──');
    debugPrint('   AD: ${candidates.length} · YAPI(montaj): ${byMount.length}');
    debugPrint('   YAPI ∖ AD: ${byMount.difference(candidates)}');

    // Vakum koruması (Choreia M-F-580): kanal hiç aday bulamazsa denetim
    // vakumda demektir — sessiz geçiş yerine kırmızı.
    expect(
      byMount,
      isNotEmpty,
      reason:
          'YAPI kanalı hiç montaj noktası bulamadı — denetim VAKUMDA. '
          'Desen ağacın biçimiyle ayrışmış olabilir.',
    );

    expect(
      byMount.difference(candidates),
      isEmpty,
      reason:
          'İKİ TÜRETİM AYRIŞTI — yapıda monte edilen bir ekranı AD '
          'deseni kaçırıyor: ${byMount.difference(candidates)}. Envanter '
          'eksik demektir (Gravita M-F-575 sınıfı: desenin kapsamı, onu '
          'yazanın adlandırma alışkanlığı kadardır).',
    );

    final Set<String> reached = <String>{};

    late ContentRepository content;
    await tester.runAsync(
      () async => content = await ContentRepository.load(rootBundle),
    );

    // ⚖️ (b) TANIK — `NavigatorObserver`, ve **OLAYI** sayıyor, adı DEĞİL.
    //
    // Bu dosyanın eski yorumu *"NavigatorObserver DENENDİ ve düştü"* diyordu:
    // doğruydu ama **kapsamı dardı** — düşen şey rotayı ADIYLA saymaktı
    // (`route.settings.name` bu uygulamada boş, hepsi `MaterialPageRoute<void>`
    // görünüyor). M-F-582 tam bu vakayı hükme bağlamış: *adı değil OLAYI say.*
    // Ad zaten monte-olan enstantaneden geliyor; tanıktan istenen tek şey
    // **kök varışın gerçekten olduğu**.
    final _RouteWitness witness = _RouteWitness();
    final accountUser = ValueNotifier<String?>(null);
    addTearDown(accountUser.dispose);
    // GravitaApp always provides these scopes (ephemeral controllers when
    // none are injected); without them Profile hides its Appearance and
    // Language entries and the walk cannot reach those settings screens.
    final themePreferences = ThemePreferencesController.ephemeral();
    final languagePreferences = LanguagePreferencesController.ephemeral();
    addTearDown(themePreferences.dispose);
    addTearDown(languagePreferences.dispose);
    await tester.pumpWidget(
      ThemePreferencesScope(
        controller: themePreferences,
        child: LanguagePreferencesScope(
          controller: languagePreferences,
          child: AccountScope(
            connection: AccountConnection(
              userId: accountUser,
              pageBuilder: (_) =>
                  GravitaAccountPage(client: accountFixture.account),
            ),
            currentUserId: null,
            child: MaterialApp(
              theme: GravitaTheme.light,
              navigatorObservers: <NavigatorObserver>[witness],
              home: GravitaShell(content: content),
            ),
          ),
        ),
      ),
    );
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
      ...find.byType(NavigationDestination, skipOffstage: true).evaluate(),
    ].where(onScreen).toList();

    // ---- Katman 1: sekmeler ----
    final int tabCount = find
        .byType(NavigationDestination, skipOffstage: false)
        .evaluate()
        .length;
    for (int i = 0; i < tabCount; i++) {
      final Finder dest = find
          .byType(NavigationDestination, skipOffstage: false)
          .at(i);
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
          // ⚠️ İTME SAYACI ÖNCEDEN yakalanıyor — G-272 ölçümü: bu satır
          // olmadan aşağıki pop KOŞULSUZDU ve yalnız "1+ derindeyim"i
          // soruyordu, "BU dokunuş beni DAHA derine itti mi"yi değil. Bir
          // ekranın İLK basılabilir kontrolü GEZİNMEYEN bir şeyse (ör.
          // `RadioListTile` — yerinde değişir, itmez) koşulsuz pop onu HEMEN
          // dışarı atıyordu; sonraki `d` turu `live2`yi YENİDEN sorguladığında
          // artık AYNI ekranda değil, kök sekmenin KENDİ kontrollerini
          // buluyordu — dizin aynı kalırken ekran habersizce değişiyordu.
          // Ölçülen sonuç: `ProgramSetupScreen`e (İKİ `RadioListTile`'ı olan
          // İLK ekran) bu yoldan dalınca üçüncü katman rastgele ana ekrana
          // sıçrıyor, `skillTrees`/`queue` kartlarının kendi sırası hiç
          // gelmiyordu — ekranın kusuru değil, yürüyüşün "pop" ile
          // "gezinmeyen dokunuş"u AYIRT EDEMEMESİ.
          final int pushesBefore = witness.pushes;
          await tester.tap(find.byWidget(live2[d].widget), warnIfMissed: false);
          await settle(tester);
          reached.addAll(mounted(tester, candidates));
          if (pushed(tester)) routeScreens.addAll(mounted(tester, candidates));
          // Geri dön — YALNIZ bu tur GERÇEKTEN bir şey ittiyse. İtmediyse
          // hâlâ AYNI ekrandayız; pop etmek erken dışarı atardı.
          if (witness.pushes > pushesBefore) {
            final NavigatorState nav = tester.state(
              find.byType(Navigator).first,
            );
            if (nav.canPop()) {
              nav.pop();
              await settle(tester);
            }
          }
        }
        final NavigatorState nav = tester.state(find.byType(Navigator).first);
        if (nav.canPop()) {
          nav.pop();
          await settle(tester);
        }
      }
    }

    // Course entry cards can displace later Home controls beyond the generic
    // first-eight sweep. Prove those routes with actual scroll/tap navigation,
    // without changing the inventory or its intentionally unreachable set.
    await tester.tap(find.byType(NavigationDestination).at(0));
    await settle(tester);
    for (final homeKey in [
      'home.programSetupLink',
      'home.program',
      'home.skillTrees',
    ]) {
      final target = homeKey == 'home.programSetupLink'
          ? find.byKey(Key(homeKey))
          : find
                .descendant(
                  of: find.byKey(Key(homeKey)),
                  matching: find.byType(InkWell),
                )
                .first;
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 100,
      );
      await tester.ensureVisible(target);
      await settle(tester);
      await tester.tap(target);
      await settle(tester);
      reached.addAll(mounted(tester, candidates));
      if (pushed(tester)) routeScreens.addAll(mounted(tester, candidates));
      if (homeKey == 'home.skillTrees') {
        final tree = find.byType(InkWell).hitTestable().first;
        await tester.tap(tree);
        await settle(tester);
        reached.addAll(mounted(tester, candidates));
        if (pushed(tester)) routeScreens.addAll(mounted(tester, candidates));
      }
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      while (nav.canPop()) {
        nav.pop();
        await settle(tester);
      }
    }

    // The handling entry displaces Library movement cards beyond the bounded
    // generic sweep. Exercise their real visible route without changing coverage.
    await tester.tap(find.byType(NavigationDestination).at(1));
    await settle(tester);
    // Course links now precede recall controls. Exercise recall explicitly
    // through visible UI instead of relying on the bounded first-four sweep.
    final reviewEntry = find.byKey(const Key('study-review-entry'));
    await tester.scrollUntilVisible(
      reviewEntry,
      -250,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 150,
    );
    await tester.ensureVisible(reviewEntry);
    await tester.tap(reviewEntry);
    await settle(tester);
    final recall = find.byKey(const Key('study-lesson-bodyweight.1'));
    await tester.scrollUntilVisible(
      recall,
      250,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 150,
    );
    await tester.ensureVisible(recall);
    await tester.tap(recall);
    await settle(tester);
    reached.addAll(mounted(tester, candidates));
    if (pushed(tester)) routeScreens.addAll(mounted(tester, candidates));
    final recallNav = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    recallNav.pop();
    await settle(tester);
    recallNav.pop();
    await settle(tester);
    // New transition entry reuses existing screen classes; preserve inventory.
    final transitionEntry = find.byKey(const Key('dbkb.transitions.entry'));
    await tester.scrollUntilVisible(
      transitionEntry,
      200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 150,
    );
    await tester.ensureVisible(transitionEntry);
    await tester.tap(transitionEntry);
    await settle(tester);
    expect(find.byType(CalisthenicsCourseScreen), findsOneWidget);
    reached.addAll(mounted(tester, candidates));
    if (pushed(tester)) routeScreens.addAll(mounted(tester, candidates));
    for (final lesson in content.dbkbTransitionsCourse.lessons) {
      final tile = find.byKey(Key('calisthenics.lesson.${lesson.id}'));
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 150,
      );
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await settle(tester);
      expect(find.byType(CalisthenicsLessonScreen), findsOneWidget);
      reached.addAll(mounted(tester, candidates));
      if (pushed(tester)) routeScreens.addAll(mounted(tester, candidates));
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      for (var flush = 0; flush < 8; flush++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await settle(tester);
      }
    }
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    for (var flush = 0; flush < 8; flush++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await settle(tester);
    }
    final movementCard = find.byType(MovementCard).first;
    await tester.scrollUntilVisible(
      movementCard,
      200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 100,
    );
    // Flush the actual lazy catalogue read in the real IO zone before route entry.
    final selectedMovement = tester.widget<MovementCard>(movementCard).movement;
    await tester.runAsync(() => content.catalogFor(selectedMovement.id));
    final movementTap = find
        .descendant(of: movementCard, matching: find.byType(InkWell))
        .first;
    await tester.ensureVisible(movementTap);
    await settle(tester);
    await tester.tap(movementTap);
    await settle(tester);
    expect(find.byType(MovementPage), findsOneWidget);
    reached.addAll(mounted(tester, candidates));
    if (pushed(tester)) routeScreens.addAll(mounted(tester, candidates));
    final movementNavigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    for (var exits = 0; movementNavigator.canPop() && exits < 5; exits++) {
      movementNavigator.pop();
      // Existing pages may have real filesystem futures; fake-time settling
      // alone can leave their progress indicators animating indefinitely.
      for (var flush = 0; flush < 8; flush++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await settle(tester);
      }
    }
    expect(movementNavigator.canPop(), isFalse);
    expect(find.byType(MovementPage), findsNothing);

    // ⚠️ Soğuk açılış payı BURADA "ulaşılamayan" DEĞİLDİR — ona kapı-2
    // yürüyerek varıyor. Düşülmezse bölme, kendi ürettiği bir yüzeyi
    // kayıp sanır (bölmenin ilk koşumunda ölçüldü: 1 → 2).
    final List<String> unreachable =
        candidates.difference(reached).difference(kColdStartSurfaces).toList()
          ..sort();
    final List<String> reachedSorted = reached.toList()..sort();

    final List<String> routes = routeScreens.difference(shellScreens).toList()
      ..sort();

    // ⚖️ (b) KÖK VARIŞ artık SABİT DEĞİL, GÖZLENEN OLAY. Eskiden KATI'ya
    // çıplak bir `+1` ekleniyordu; şimdi tanığın `previous == null` olan
    // `didPush`ından geliyor ve `kRootArrivals`e çapalı.
    final int katiCount = witness.rootPushes + routes.length;

    // Walk the actual Core-backed account route from its visible Profile
    // control; the general InkWell traversal cannot discover OutlinedButton.
    await tester.tap(find.byType(NavigationDestination).at(3));
    await settle(tester);
    final accountButton = find.widgetWithText(OutlinedButton, 'Account');
    expect(accountButton, findsOneWidget);
    await tester.tap(accountButton);
    await settle(tester);
    expect(find.byType(GravitaAccountPage), findsOneWidget);
    reached.addAll(mounted(tester, candidates));
    routeScreens.addAll(mounted(tester, candidates));
    (tester.state(find.byType(Navigator).first) as NavigatorState).pop();
    await settle(tester);

    debugPrint('── GEZİLEBİLİRLİK ÖLÇÜMÜ ──');
    debugPrint(
      '   ⚖️ KATI (ayrı ROTA): $katiCount — '
      'kök varış ${witness.rootPushes} (${kRootArrivals.join(', ')}: 4 sekme)'
      ' + ${routes.join(' · ')}',
    );
    debugPrint(
      '   tanık: didPush kök ${witness.rootPushes} · '
      'itilen ${witness.pushes}',
    );
    debugPrint('   ⚖️ GEVŞEK (ayrı YÜZEY): ${reached.length}');
    debugPrint('   yüzeyler: ${reachedSorted.join(' · ')}');
    debugPrint(
      '   ULAŞILAMIYOR AMA VAR: ${unreachable.length}'
      '${unreachable.isEmpty ? '' : ' — ${unreachable.join(' · ')}'}',
    );

    // ⚖️ (c) DIŞLAMA SEBEBİ — her koşumda KAYNAKTAN türetilir, düzyazıdan değil.
    // Sebep çürürse kapı öter: *yanlış bir sebep, sebepsizlikten daha kötüdür
    // — denetimi doğrulanmış gösterir.*
    final Map<String, String> reasons = derivedExclusionReasons();
    reasons.forEach((String k, String v) => debugPrint('   ⚖️ dışlama $k: $v'));

    expect(
      reasons.values.where((String r) => r.startsWith('⛔')),
      isEmpty,
      reason:
          'DIŞLAMA SEBEBİ ÇÜRÜDÜ: $reasons — kalem ya bağlanmalı ya '
          'silinmeli; dışlama kovasında yanlış sebeple durmamalı.',
    );

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
    expect(
      reached.length,
      greaterThanOrEqualTo(7),
      reason:
          'Gezilebilir ekran sayısı düştü — bir tetik silinmiş '
          'olabilir. Ulaşılamayanlar: ${unreachable.join(', ')}',
    );

    // "Ulaşılamıyor ama var" listesi BOŞ OLMAK ZORUNDA DEĞİL; ama sessiz
    // kalamaz. Büyürse ötsün: yeni yazılan her ekran ya bağlanmalı ya da
    // burada bilerek listelenmeli.
    // Sistem hatası ve kapalı yayın kamerası kaybolmadan ayrı dışlanır.
    // `ContentFailureScreen` — sistemin
    // gösterdiği hata hâli, kullanıcının BASARAK gitmediği bir ekran.
    // Sayı artarsa yeni bir ekran bağlanmadan yazılmış demektir.
    // KATI sayı da küçülemez: bir rota tetiği silinirse burası öter.
    // ⚖️ (b-i) TANIK BAĞLI MI — Ostinato'nun bedeli (M-F-582): tanığı
    // TANIMLIYDI ama BAĞLI DEĞİLDİ ve sessizce 0 sayıyordu. Bu satır o vakayı
    // kırmızıya çevirir: gözlemci `navigatorObservers`e takılmazsa kök varış
    // 0 kalır ve kapı öter.
    //
    // ⚖️ (b-ii) BEYANSIZ KÖK VARIŞ = KIRMIZI. *Üçüncü bir kök varış beyan
    // değil BULGUDUR* — sessizce KATI'ya eklenmez.
    expect(
      witness.rootPushes,
      kRootArrivals.length,
      reason:
          'KÖK VARIŞ BEYANLA AYRIŞTI — beyan ${kRootArrivals.length} '
          '(${kRootArrivals.join(', ')}), gözlenen ${witness.rootPushes}. '
          '0 ise tanık BAĞLI DEĞİL (navigatorObservers); fazlaysa beyansız '
          'bir kök varış doğmuş demektir.',
    );

    // ⚖️ (b-iii) İKİ TARAF AYRI KAYNAKTAN: `routes` monte-olma + `canPop`
    // derinliğinden, `pushes` tanığın OLAY sayacından geliyor. Rota olarak
    // sayılan her yüzeyin arkasında en az bir push OLAYI olmak zorunda —
    // aksi hâlde derinlik ölçümü olmayan bir rotayı rota sanıyor demektir.
    expect(
      witness.pushes,
      greaterThanOrEqualTo(routes.length),
      reason:
          'ROTA SAYISI PUSH OLAYINDAN FAZLA: ${routes.length} rota '
          'sayıldı ama yalnız ${witness.pushes} push olayı gözlendi — '
          'derinlik ölçümü rota olmayan bir şeyi rota sayıyor olabilir.',
    );

    expect(
      katiCount,
      greaterThanOrEqualTo(4),
      reason:
          'Ayrı rota sayısı düştü — bir push tetiği kaybolmuş '
          'olabilir. Ulaşılan rotalar: ${routes.join(', ')}',
    );

    // ⚖️ DENKLEM — İKİ KAPI ARASINDA (aile kısıtı ①). Her kapı kendi
    // içinde tutarsa İKİSİ BİRDEN eksik olabilir; bu satır o boşluğu kapatır.
    final Set<String> hesap = <String>{
      ...reached,
      ...kColdStartSurfaces,
      ...kDeliberatelyUnreachable,
    };
    expect(
      hesap,
      candidates,
      reason:
          'BÖLME KAYIP ÜRETTİ: aday envanteri = kabuk yürüyüşü ⊎ '
          'soğuk açılış payı ⊎ kasıtlı-varılamayan denklemi tutmuyor. '
          'Fark: ${candidates.difference(hesap)} / ${hesap.difference(candidates)}',
    );

    expect(
      unreachable.toSet(),
      kDeliberatelyUnreachable,
      reason:
          'Bağlanmamış ekran sayısı arttı: ${unreachable.join(', ')} — '
          'repliğin varlığı tetiğinin varlığı DEĞİLDİR.',
    );
  });
}

/// Rota **OLAY** tanığı — ad tutmaz, çünkü bu uygulamada rota adı **boş**
/// (ölçüldü: hepsi `MaterialPageRoute<void>`, `settings.name == null`).
///
/// > *Adı bekleyen bir tanık burada sessizce BOŞ kalırdı* (M-F-582).
///
/// Bu yüzden tanık iki **olay** sayar ve adlandırmayı monte-olan enstantaneye
/// bırakır: kök varış (`previous == null`) ve itilen rota.
class _RouteWitness extends NavigatorObserver {
  int rootPushes = 0;
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previous) {
    if (previous == null) {
      rootPushes++;
    } else {
      pushes++;
    }
  }
}
