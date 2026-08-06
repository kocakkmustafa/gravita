import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/gravita_app.dart';
import 'package:gravita/app/library_model.dart';
import 'package:gravita/app/library_screen.dart';
import 'package:gravita/app/library_strings.dart';
import 'package:gravita/app/movement_page.dart';
import 'package:gravita/app/theme.dart';
import 'package:gravita/app/why_not_here_screen.dart';

/// Kütüphane · Hareket sayfası · "Neden yok?" yüzey nöbetleri.
///
/// Hepsi GERÇEK içerikle koşuyor (`rootBundle`) — sahte fixture yok. Bu
/// bilinçli: bu ailenin ölçülmüş dersi *"gerçek metin fixture'dan uzundur"*,
/// ve taşma kusurlarının üçü de tam olarak fixture ile test edildiği için
/// kaçmıştı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// EN DAR cihaz. `flutter_test` varsayılanı ~800pt — gerçek telefonun iki
  /// katı; taşma kusurları orada GÖRÜNMEZ. 375×812 (iPhone SE/13 mini sınıfı)
  /// bu ailede üç ayrı gerçek kusuru yakalayan ölçü.
  void useNarrowPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// AYNI DAR GENİŞLİK, uzun yüzey. İkisi ayrı ölçü aleti:
  ///
  /// · **taşma** GENİŞLİĞE duyarlıdır → 375 kalmak zorunda
  /// · **"her madde çizildi mi"** ise MOUNT'a duyarlıdır ve `ListView`
  ///   ekran dışındaki çocuğu Offstage yapmaz, HİÇ MOUNT ETMEZ — yani
  ///   812pt'de alt yarısı element ağacında yoktur ve `find` onu bulamaz
  ///
  /// Bu yüzden içerik-bütünlüğü testleri 375×4000'de koşuyor. Genişliği
  /// büyütmek (ör. 1200) daha kolay olurdu ama taşmayı da GİZLERDİ — bu
  /// ailenin defterindeki tuzağın ta kendisi.
  void useNarrowTall(WidgetTester tester) {
    tester.view.physicalSize = const Size(375, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<ContentRepository> loadReal(WidgetTester tester) async {
    late ContentRepository c;
    await tester.runAsync(() async => c = await ContentRepository.load(rootBundle));
    return c;
  }

  Widget host(Widget child) =>
      MaterialApp(theme: GravitaTheme.light, home: child);

  group('kütüphane — kapsam GÖRÜNÜR', () {
    testWidgets('31 hareket, 9 aile; sayaç iki sayıyı da söylüyor',
        (WidgetTester tester) async {
      useNarrowPhone(tester);
      final ContentRepository c = await loadReal(tester);

      // Katalogla kütüphane aynı büyüklükte olmak ZORUNDA — terfi kapısının
      // (`promote_library.py --check`) yüzey tarafındaki ikizi.
      expect(c.catalogue.movements.length, 31);
      expect(c.catalogue.families.length, 9);
      expect(c.catalogue.liveCount, 1);

      await tester.pumpWidget(host(LibraryScreen(content: c)));
      await tester.pump();

      // Sayaç: toplam VE açık VE bekleyen. Yalnız toplamı göstermek 31'i
      // vitrin gibi sunardı; yalnız açığı göstermek kapsamı saklardı.
      expect(find.textContaining('31 movements'), findsOneWidget);
      expect(find.textContaining('1 open'), findsOneWidget);
      expect(find.textContaining('30 waiting'), findsOneWidget);
    });

    testWidgets('her aile bölümü ÇİZİLİYOR — hiçbiri sessizce düşmüyor',
        (WidgetTester tester) async {
      useNarrowPhone(tester);
      final ContentRepository c = await loadReal(tester);
      await tester.pumpWidget(host(LibraryScreen(content: c)));
      await tester.pump();

      // ⚠️ `skipOffstage: false` BURADA YETMEZ ve ilk yazışımda testi
      // düşürdü: `ListView` görünmeyen çocuğu Offstage yapmaz, HİÇ MOUNT
      // ETMEZ — element ağacında yoktur, bulunamaz. Yani "ekranda mı" ile
      // "üretildi mi" farklı iki soru ve kaydırmadan ikincisi sorulamıyor.
      // 9 ailenin 9'una GERÇEKTEN kaydırılıyor.
      for (final ({String family, String label, List<MovementEntry> movements}) f
          in c.catalogue.families) {
        await tester.scrollUntilVisible(
          find.byKey(Key('library.family.${f.family}')),
          280,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byKey(Key('library.family.${f.family}')), findsOneWidget,
            reason: '${f.family} ailesi kütüphaneden düştü');
      }
    });
  });

  group('⭐ KRİTİK KISIT — kapsam-dışı arama BOŞ DÖNMEZ (W0 §4)', () {
    testWidgets('"leg press" → boş sonuç DEĞİL, gerekçeli bölüm',
        (WidgetTester tester) async {
      useNarrowPhone(tester);
      final ContentRepository c = await loadReal(tester);
      await tester.pumpWidget(host(LibraryScreen(content: c)));
      await tester.pump();

      await tester.enterText(
          find.byKey(LibraryScreen.searchFieldKey), 'leg press');
      await tester.pump();

      expect(find.byKey(LibraryScreen.exclusionResultsKey, skipOffstage: false),
          findsOneWidget,
          reason: 'Kapsam-dışı terim kendi gerekçesine düşmeli.');
      expect(find.byKey(LibraryScreen.emptyResultKey, skipOffstage: false),
          findsNothing,
          reason: 'Boş sonuç, ürünü DAR gösterir — yasak olan tam bu.');
      // Gerekçe ekranda GERÇEKTEN yazıyor (bölümün varlığı yetmez).
      expect(
          find.textContaining('Machines already fix the path',
              skipOffstage: false),
          findsOneWidget);
    });

    testWidgets(
        'POZİTİF İKİZ: anlamsız sorgu GERÇEKTEN boş — kapsam-dışı bir '
        'her-şeyi-yakalayan değil', (WidgetTester tester) async {
      useNarrowPhone(tester);
      final ContentRepository c = await loadReal(tester);
      await tester.pumpWidget(host(LibraryScreen(content: c)));
      await tester.pump();

      await tester.enterText(
          find.byKey(LibraryScreen.searchFieldKey), 'zzzqqq');
      await tester.pump();

      // Bu ikiz olmadan üstteki test, "her sorguda tüm bölümleri göster"
      // diyen bir uygulamada da GEÇERDİ (vekil-ölçüm sınıfı hata).
      expect(find.byKey(LibraryScreen.emptyResultKey, skipOffstage: false),
          findsOneWidget);
      expect(find.byKey(LibraryScreen.exclusionResultsKey, skipOffstage: false),
          findsNothing);
      // Boşluk da BİR CÜMLEDİR — sessiz boş liste değil.
      expect(find.textContaining('Nothing in our catalogue matches',
          skipOffstage: false), findsOneWidget);
    });

    testWidgets('kapsam-İÇİ arama hareketi buluyor',
        (WidgetTester tester) async {
      useNarrowPhone(tester);
      final ContentRepository c = await loadReal(tester);
      await tester.pumpWidget(host(LibraryScreen(content: c)));
      await tester.pump();

      await tester.enterText(find.byKey(LibraryScreen.searchFieldKey), 'plank');
      await tester.pump();

      expect(find.byKey(LibraryScreen.movementResultsKey, skipOffstage: false),
          findsOneWidget);
      expect(find.text('Plank', skipOffstage: false), findsWidgets);
    });

    testWidgets('takma addan arama — "air squat" bodyweight squat\'ı buluyor',
        (WidgetTester tester) async {
      useNarrowPhone(tester);
      final ContentRepository c = await loadReal(tester);
      await tester.pumpWidget(host(LibraryScreen(content: c)));
      await tester.pump();

      await tester.enterText(
          find.byKey(LibraryScreen.searchFieldKey), 'air squat');
      await tester.pump();
      expect(find.text('Bodyweight Squat', skipOffstage: false), findsWidgets,
          reason: 'Takma adlar katalogdan geliyor; arama onları görmeli.');
    });
  });

  group('hareket sayfası — dürüstlük kutusu', () {
    testWidgets('KUYRUKTAKİ hareket: "ölçülen" BOŞ ama onurlu bir cümle var',
        (WidgetTester tester) async {
      useNarrowTall(tester);
      final ContentRepository c = await loadReal(tester);
      final MovementEntry plank = c.catalogue.byId('plank')!;
      expect(plank.honesty.measuresNothing, isTrue);

      await tester.pumpWidget(
          host(MovementPage(movement: plank, content: c)));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();

      expect(find.byKey(MovementPage.honestyKey, skipOffstage: false),
          findsOneWidget);
      // Boşluk bir HATA hâli gibi çizilmiyor: yerinde bir cümle var.
      expect(
          find.text(LibraryStrings.honestyMeasuresNothing, skipOffstage: false),
          findsOneWidget);
    });

    testWidgets('kutunun HER maddesi çiziliyor — kırpılmış beyan, beyan değil',
        (WidgetTester tester) async {
      useNarrowTall(tester);
      final ContentRepository c = await loadReal(tester);
      final MovementEntry plank = c.catalogue.byId('plank')!;

      await tester.pumpWidget(
          host(MovementPage(movement: plank, content: c)));
      await tester.pump();

      // 30/31 hareketin kutusu bugün 7+ madde taşıyor ve en uzunu bir
      // paragraf. Hepsinin AĞAÇTA olduğunu sınıyoruz: sabit yükseklikli bir
      // kart bunların bir kısmını sessizce yutardı.
      expect(plank.honesty.notMeasured.length, greaterThanOrEqualTo(5));
      for (final String item in plank.honesty.notMeasured) {
        expect(find.text(item, skipOffstage: false), findsOneWidget,
            reason: 'Dürüstlük maddesi ekranda YOK: "$item"');
      }
    });

    testWidgets('referans YOK hâli: sahte iskelet-avatar ÇİZİLMİYOR',
        (WidgetTester tester) async {
      useNarrowTall(tester);
      final ContentRepository c = await loadReal(tester);
      final MovementEntry plank = c.catalogue.byId('plank')!;

      await tester.pumpWidget(
          host(MovementPage(movement: plank, content: c)));
      await tester.pump();

      expect(find.byKey(MovementPage.howToKey, skipOffstage: false),
          findsOneWidget);
      expect(find.text(LibraryStrings.howToNoReference, skipOffstage: false),
          findsOneWidget);
      // Sayfada hiçbir görsel/figür yok — "uydurmadık" iddiasının nöbeti.
      expect(find.byType(Image, skipOffstage: false), findsNothing);
    });

    testWidgets(
        'güvenlik uyarısı KIRPILMIYOR — katalog metni birebir ekranda',
        (WidgetTester tester) async {
      useNarrowTall(tester);
      final ContentRepository c = await loadReal(tester);
      final MovementEntry squat = c.catalogue.byId('bodyweight_squat')!;
      expect(squat.safetyWarnings, isNotEmpty);

      await tester.pumpWidget(
          host(MovementPage(movement: squat, content: c)));
      await tester.pump();

      // ⚠️ 4000pt YETMEDİ: bu hareketin dürüstlük kutusu elle yazılmış ve
      // hasat sayıları taşıyor (en uzun sayfa), güvenlik bloku da altında.
      // Yüzeyi büyütmek yerine KAYDIRILIYOR — sorulan şey zaten "kullanıcı
      // bu uyarıya ERİŞEBİLİYOR mu"; sabit bir yükseklik uydurmak o soruyu
      // sormadan geçmek olurdu.
      for (final String w in squat.safetyWarnings) {
        await tester.scrollUntilVisible(find.text(w), 300,
            scrollable: find.byType(Scrollable).first);
        expect(find.text(w), findsOneWidget);
      }
    });

    testWidgets(
        'dersi OLMAYAN harekette "hiç seansın yok" DENMİYOR — kanıtlanamaz',
        (WidgetTester tester) async {
      useNarrowTall(tester);
      final ContentRepository c = await loadReal(tester);
      final MovementEntry plank = c.catalogue.byId('plank')!;
      expect(plank.lessonCount, 0);

      await tester.pumpWidget(
          host(MovementPage(movement: plank, content: c)));
      await tester.pump();

      expect(find.text(LibraryStrings.trendNoLesson, skipOffstage: false),
          findsOneWidget);
      expect(find.text(LibraryStrings.trendNoSessions, skipOffstage: false),
          findsNothing,
          reason: 'Yetim kayıt olabilir; "hiç seansın yok" kanıtlanamaz bir '
              'iddia. İçerikten kanıtlanabilir olan söylenir.');
    });

    testWidgets('EN DAR cihazda taşma YOK — 31 hareketin hepsinde',
        (WidgetTester tester) async {
      useNarrowPhone(tester);
      final ContentRepository c = await loadReal(tester);

      // Tek bir hareketi denemek yetmez: en uzun metin hangi harekette
      // olduğunu BİLMİYORUZ ve "gerçek metin fixture'dan uzundur" dersinin
      // tamamı bu. Flutter taşmada istisna atar; bu döngü onu 31 kez sorar.
      for (final MovementEntry m in c.catalogue.movements) {
        await tester.pumpWidget(host(MovementPage(movement: m, content: c)));
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: '${m.id} hareket sayfası 375pt genişlikte taştı');
      }
    });
  });

  group('"Neden yok?" sayfası', () {
    testWidgets('yedi bölümün hepsi ve gerekçeleri çiziliyor',
        (WidgetTester tester) async {
      useNarrowTall(tester);
      final ContentRepository c = await loadReal(tester);
      final ExclusionsPage page = c.catalogue.exclusions;
      expect(page.sections.length, 7);

      await tester.pumpWidget(host(WhyNotHereScreen(page: page)));
      await tester.pump();

      for (final ExclusionSection s in page.sections) {
        expect(find.byKey(WhyNotHereScreen.sectionKey(s.id), skipOffstage: false),
            findsOneWidget);
        expect(find.text(s.userReason, skipOffstage: false), findsOneWidget,
            reason: '${s.id} gerekçesi kırpıldı ya da çizilmedi');
      }
    });

    testWidgets('İÇ alanlar uygulamaya HİÇ girmiyor',
        (WidgetTester tester) async {
      // `internalRule_tr` (Türkçe iç kural) ve `reconsiderIf` (yol haritası
      // dili) kullanıcı metni DEĞİL. Üretim adımı beyaz listeyle çalışıyor;
      // bu test o beyaz listenin GERÇEKTEN uygulandığını asset üzerinden
      // sorguluyor — üretici betiğe güvenmiyor, çıktısını ölçüyor.
      late String shipped;
      await tester.runAsync(() async =>
          shipped = await rootBundle.loadString('content/exclusions.page.json'));
      expect(shipped.contains('internalRule_tr'), isFalse);
      expect(shipped.contains('reconsiderIf'), isFalse);
    });
  });

  group('kabuk', () {
    testWidgets('dört sekme ve nöbetli seans düğmesi',
        (WidgetTester tester) async {
      useNarrowPhone(tester);
      final ContentRepository c = await loadReal(tester);

      await tester.pumpWidget(host(GravitaShell(content: c)));
      await tester.pump();

      expect(find.byKey(GravitaShell.navBarKey), findsOneWidget);
      // ⚠️ `find.text('Today')` İKİ sonuç veriyordu: Home'un AppBar başlığı
      // ve sekme etiketi. Genel arama, "sekme var mı" sorusunun yerine
      // geçemez — arama NAV ÇUBUĞUNA daraltılıyor.
      for (final String label in <String>[
        LibraryStrings.tabToday,
        LibraryStrings.tabLibrary,
        LibraryStrings.tabProgress,
        LibraryStrings.tabProfile,
      ]) {
        expect(
            find.descendant(
                of: find.byKey(GravitaShell.navBarKey),
                matching: find.text(label)),
            findsOneWidget);
      }
      // Canlı yol VAR (push_up) → düğüm ÇİZİLİR. Yokluğu ayrı bir iddia ve
      // `liveConfig`in tanımıyla sınanıyor (aşağıdaki birim testi).
      expect(c.liveConfig, isNotNull);
      expect(find.byKey(GravitaShell.startSessionKey), findsOneWidget);
    });
  });

  group('dil nöbeti — VAAT dili yasak (M-F-186)', () {
    test('kullanıcıya giden hiçbir metinde açık vaat ifadesi YOK', () {
      // ⚠️ KAPSAM: yalnız TARTIŞMASIZ vaat kalıpları. "yet" sözcüğü bu turda
      // BİLEREK kapsam dışı ve koordinatöre soru olarak taşınıyor: aile
      // defteri onu yasaklılar arasında sayıyor, ama bu üründe kurucu/
      // koordinatör onayından geçmiş MEVCUT metin ("Squat coaching isn't open
      // yet") onu kullanıyor. İkisinden birini sessizce seçmek, kapıyı benim
      // kanaatimle doldurmak olurdu.
      const List<String> forbidden = <String>[
        'coming soon',
        'yakında',
        'stay tuned',
        'will be available',
        'in a future update',
        'we plan to',
      ];

      final Map<String, dynamic> lib = (jsonDecode(
              File('content/library.json').readAsStringSync()) as Map)
          .cast<String, dynamic>();
      final String userFacing = <String>[
        for (final Map<String, dynamic> m
            in (lib['movements'] as List<dynamic>).cast<Map<String, dynamic>>())
          jsonEncode(<String, dynamic>{
            'blurb': m['blurb'],
            'honesty': m['honesty'],
            'comingSoonInThisMovement': m['comingSoonInThisMovement'],
          }),
        File('content/exclusions.page.json').readAsStringSync(),
      ].join(' ').toLowerCase();

      for (final String phrase in forbidden) {
        expect(userFacing.contains(phrase), isFalse,
            reason: 'Kullanıcı metninde vaat ifadesi: "$phrase"');
      }
    });

    test('üretilmiş metinde DEFTER KODU sızıntısı YOK', () {
      // Gerçek bir kusurun nöbeti: ilk üretimde kullanıcı cümlesine "(G-043)"
      // yazılmıştı. Kod kimliği iç izlenebilirliğin işidir (`blockedBy`),
      // kullanıcı cümlesinin değil.
      final Map<String, dynamic> lib = (jsonDecode(
              File('content/library.json').readAsStringSync()) as Map)
          .cast<String, dynamic>();
      final RegExp code = RegExp(r'\b[GMJ]-\d{2,3}\b|\bADR-\d+\b');
      for (final Map<String, dynamic> m
          in (lib['movements'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        if (m['honestySource'] == 'curated') continue;
        final String blob = jsonEncode(<String, dynamic>{
          'blurb': m['blurb'],
          'honesty': m['honesty'],
          'comingSoonInThisMovement': m['comingSoonInThisMovement'],
        });
        expect(code.hasMatch(blob), isFalse,
            reason: '${m['id']}: üretilmiş metinde defter kodu var');
      }
    });
  });
}
