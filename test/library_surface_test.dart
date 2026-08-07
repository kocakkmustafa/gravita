import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/gravita_app.dart';
import 'package:gravita/app/home_screen.dart';
import 'package:gravita/app/library_model.dart';
import 'package:gravita/app/library_screen.dart';
import 'package:gravita/app/library_strings.dart';
import 'package:gravita/app/progress_strings.dart';
import 'package:gravita/app/progress_view.dart';
import 'package:gravita_engine/gravita_engine.dart';
import 'package:gravita/app/movement_page.dart';
import 'package:gravita/app/profile_screen.dart';
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

      // ⚠️ SAYI DEĞİL KURAL ölçülüyor — ve bu bir DÜZELTMENİN ürünü.
      //
      // Eski hâli `movements.length == 31`, `families.length == 9`,
      // `liveCount == 1` diyordu. Üçü de ürün DOĞRU ilerlediğinde kırmızıya
      // dönerdi: 32. hareket katalogdan geldiğinde, yeni bir aile açıldığında
      // ve — en kötüsü — **bir hareket terfi kazandığında.** Yani gecenin
      // asıl hedefi gerçekleştiği an test "kusur" diye bağıracaktı, ve bir
      // süre sonra kırmızı "yine o test" diye okunacaktı.
      //
      // Kural: kütüphane katalogla AYNI büyüklükte (terfi kapısının yüzey
      // ikizi) · aile listesi veriden türer · canlı/bekleyen ayrımı
      // BLOKER durumundan türer, sabit bir sayıdan değil.
      final int catalogued = _catalogFileCount();
      expect(c.catalogue.movements.length, catalogued);
      expect(c.catalogue.families.length,
          c.catalogue.movements.map((MovementEntry m) => m.family).toSet().length);
      expect(c.catalogue.liveCount,
          c.catalogue.movements.where((MovementEntry m) => m.isLive).length);

      await tester.pumpWidget(host(LibraryScreen(content: c)));
      await tester.pump();

      // Sayaç metni de VERİDEN kuruluyor: üç sayının da GÖSTERİLDİĞİ kural,
      // hangi sayı olduğu değil. Yalnız toplamı göstermek kataloğu vitrin
      // gibi sunardı; yalnız açığı göstermek kapsamı saklardı.
      final int live = c.catalogue.liveCount;
      final int waiting = c.catalogue.movements.length - live;
      expect(find.textContaining('$catalogued movements'), findsOneWidget);
      expect(find.textContaining('$live open'), findsOneWidget);
      expect(find.textContaining('$waiting waiting'), findsOneWidget);
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
      //
      // ⚠️ İKİ liste birden geziliyor: kutu artık KUYRUK ile KALICI sınırı
      // ayrı başlıklarda çiziyor. Yalnız birini gezen test, ötekinin
      // sessizce düşmesini göremezdi — kapsamın yarısını kaybetmek,
      // kapının kendisini kaybetmekle aynı sınıf.
      final List<String> allItems = <String>[
        ...plank.honesty.waitingOnMeasurement,
        ...plank.honesty.notMeasured,
      ];
      expect(plank.honesty.waitingOnMeasurement, isNotEmpty);
      expect(plank.honesty.notMeasured, isNotEmpty);
      expect(allItems.length, greaterThanOrEqualTo(5));
      for (final String item in allItems) {
        expect(find.text(item, skipOffstage: false), findsOneWidget,
            reason: 'Dürüstlük maddesi ekranda YOK: "$item"');
      }
    });

    testWidgets('"referans yok" cümlesi KOŞULLU — sayfa kendiyle çelişmiyor',
        (WidgetTester tester) async {
      // ⚠️ Ölçüt (koordinatör aktarımı): *sevk edilmiş bir dürüstlük cümlesini
      // yanlışa çevirecek en MAKUL değişiklik neyse, kapı onu tutmalı.*
      //
      // Burada o değişiklik ZATEN OLMUŞTU: cümle *"hiç kayıtlı eğitmen
      // referansımız yok"* diyor ve KOŞULSUZ çiziliyordu; `push_up`ın
      // referansı hasat edildi (5 eğitmen, 36 çekim) ve cümle yerinde kaldı.
      // Aynı sayfanın dürüstlük kutusu *"ATTESTED"* diyordu — **iki blok
      // birbiriyle çelişiyordu.** Kimse yalan söylemeye karar vermedi;
      // hasat yapıldı ve sevk edilmiş bir cümle sessizce yanlış oldu.
      useNarrowTall(tester);
      final ContentRepository c = await loadReal(tester);

      for (final MovementEntry m in c.catalogue.movements) {
        await tester.pumpWidget(host(MovementPage(movement: m, content: c)));
        await tester.pump();
        if (m.referenceSources > 0) {
          expect(find.text(LibraryStrings.howToNoReference, skipOffstage: false),
              findsNothing,
              reason: '${m.id}: ${m.referenceSources} eğitmen hasat edilmiş '
                  'ama sayfa "hiç referans yok" diyor.');
          expect(
              find.text(
                  LibraryStrings.howToReferenceNotDrawable(m.referenceSources),
                  skipOffstage: false),
              findsOneWidget);
        } else {
          expect(find.text(LibraryStrings.howToNoReference, skipOffstage: false),
              findsOneWidget);
        }
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
      // ⚠️ Bu nöbet VAKUM-DOĞRU'ydu ve bir aktarım (Flutter tuzağı #5)
      // gösterdi. Eski hâli yalnız `Image` arıyordu — ama bir iskelet-avatar
      // **en makul olarak `CustomPaint` ile çizilir**, `Image` ile değil.
      // Yani nöbet, engellemeye çalıştığı şeyin EN OLASI biçimini hiç
      // görmüyordu ve `findsNothing` her zaman geçiyordu.
      //
      // > Sıfır bekleyen bir kapı, bozuk aracı asla göstermez.
      //
      // Şimdi üç tipin üçü de sorgulanıyor ve AŞAĞIDA pozitif ikizi var:
      // bulucunun gerçekten çalıştığı kanıtlanmadan `findsNothing` bir şey
      // ifade etmiyor.
      // ⚠️ İKİ AYRI ÖLÇÜ, çünkü tek tip yetmiyor.
      //
      // (a) GÖRSEL tipleri: bir demo/foto `Image` ya da `RawImage` olurdu.
      //     Bunlar sayfada YOK ve pozitif ikizle bulucunun çalıştığı
      //     kanıtlanıyor.
      // (b) ⚠️ `CustomPaint` tip olarak SORULAMIYOR: Flutter'ın kendi
      //     bileşenleri (kaydırma çubuğu, geri düğmesi dalgası) onu
      //     kullanıyor ve sayfada zaten BİR tane var. Onu yasaklamak
      //     bu gecenin dördüncü "fazla geniş kapı"sı olurdu.
      //     Asıl garanti KAYNAK düzeyinde ve daha güçlü: uygulamada
      //     HİÇBİR `CustomPainter` YOK — yani hiçbir şey çizilmiyor,
      //     sahte bir iskelet çizilemez de.
      for (final Type figure in <Type>[Image, RawImage]) {
        expect(find.byType(figure, skipOffstage: false), findsNothing,
            reason: 'Sayfada $figure var — uydurulmuş bir figür olabilir.');
      }
      final bool paints = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .any((File f) => f.readAsStringSync().contains('CustomPainter'));
      expect(paints, isFalse,
          reason: 'Uygulamada bir `CustomPainter` belirdi — sahte iskelet '
              'avatarı çizilebilir hâle geldi. Referans dizisi gerçekten '
              'geldiyse bu meşru; o zaman bu nöbeti gerekçesiyle güncelle.');
    });

    testWidgets('POZİTİF İKİZ: figür bulucusu GERÇEKTEN çalışıyor',
        (WidgetTester tester) async {
      // ⚠️ Üstteki testin tamamı `findsNothing` — yani bulucu BOZUK olsa da
      // geçerdi. Bu ikiz onu kapatıyor: aynı bulucu, figür VARKEN onu
      // bulmalı. Bu kanıt olmadan "sahte avatar yok" bir ölçüm değil,
      // bir temenni.
      useNarrowPhone(tester);
      await tester.pumpWidget(host(Scaffold(
        body: Column(children: <Widget>[
          const RawImage(width: 4, height: 4),
          Image.memory(Uint8List.fromList(_tinyPng), width: 4, height: 4),
        ]),
      )));
      await tester.pump();
      for (final Type figure in <Type>[Image, RawImage]) {
        expect(find.byType(figure, skipOffstage: false), findsWidgets,
            reason: '$figure bulucusu figür VARKEN de bulamıyor — '
                'üstteki `findsNothing` vakum-doğru demektir.');
      }
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
      // Özne KURALLA seçiliyor: "dersi olmayan herhangi bir hareket".
      // `plank` sabitlenseydi, plank terfi ettiği gün test yanlış şeyi
      // ölçmeye başlardı — G-129'un (fixture konumla seçilirse kayar)
      // aynı sınıfı.
      final MovementEntry plank = c.catalogue.movements
          .firstWhere((MovementEntry m) => m.lessonCount == 0);

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

    testWidgets('taşma YOK — 375pt\'te, HER hareketin TÜM sayfasında',
        (WidgetTester tester) async {
      final ContentRepository c = await loadReal(tester);

      // ⚠️ İKİ YÜKSEKLİKTE koşuyor ve bu bir DÜZELTMENİN ürünü (J-118).
      //
      // Eski hâli yalnız 375×812'de pump ediyordu ve **sayfanın yalnız ilk
      // ekranını ölçüyordu**: `ListView` görünmeyen çocuğu MOUNT ETMEZ, yani
      // LAYOUT DA ETMEZ — alt yarıdaki bir taşma hiç oluşmuyordu, test de
      // onu göremiyordu. G-124'ün ("skipOffstage yetmez") taşma tarafındaki
      // ikizi; aynı kökten ikinci kez ısırdı.
      //
      // 4000pt'lik geçiş her bloğu GERÇEKTEN 375pt genişlikte layout'a sokar
      // — dürüstlük kutusu, kuyruk, form kuralları, güvenlik, trend dahil.
      // 812pt'lik geçiş gerçek cihaz yüksekliğini korur (yükseklik-kısıtlı
      // bir kusur varsa orada doğar).
      for (final Size surface in <Size>[
        const Size(375, 4000),
        const Size(375, 812),
      ]) {
        tester.view.physicalSize = surface;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // İçerik büyüdükçe kapsam KENDİLİĞİNDEN büyür: liste `library.json`
        // canlı okunuyor, sabit bir fixture yok. 32. hareket eklendiği gün
        // bu döngü onu da ölçer, elle güncellenecek bir sayı yoktur.
        for (final MovementEntry m in c.catalogue.movements) {
          await tester.pumpWidget(host(MovementPage(movement: m, content: c)));
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: '${m.id} hareket sayfası ${surface.width.toInt()}×'
                  '${surface.height.toInt()}\'te taştı');
        }
      }
    });

    testWidgets('taşma YOK — 375pt\'te, BEŞ yüzeyin HEPSİNDE',
        (WidgetTester tester) async {
      // ⚠️ Bu test, JabLab\'ın dersinin bende DOĞRULANMASIDIR:
      // *"bir kusur sınıfını teşhis etmek, onu aynı commit\'te üretmene engel
      // değil."* G-139\'da taşma süpürmesinin sayfanın yalnız ilk ekranını
      // ölçtüğünü buldum ve düzelttim — ama düzeltmeyi **tek ekrana**
      // uyguladım. Library · Home · Profile · "Neden yok?" hiç 375pt\'te
      // ölçülmemişti. Sınıfı teşhis edip örneği düzeltmişim; tam da uyarılan
      // desen.
      //
      // Kapı 110pt\'e daraltılarak SINANDI: "Home 110×4000\'te taştı" diye
      // öttü, yani beş yüzey gerçekten pump ediliyor ve arıza adıyla geliyor.
      final ContentRepository c = await loadReal(tester);
      final ExclusionsPage page = c.catalogue.exclusions;

      for (final Size surface in <Size>[
        const Size(375, 4000),
        const Size(375, 812),
      ]) {
        tester.view.physicalSize = surface;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final Map<String, Widget> surfaces = <String, Widget>{
          'Home': HomeScreen(content: c, onBrowseLibrary: () {}),
          'Library': LibraryScreen(content: c),
          'Profile': ProfileScreen(content: c),
          'WhyNotHere': WhyNotHereScreen(page: page),
          // Vurgulu hâl AYRI layout (mühürlü kart + farklı tipografi).
          'WhyNotHere(odakli)': WhyNotHereScreen(
              page: page, focusSectionId: page.sections.first.id),
        };

        for (final MapEntry<String, Widget> e in surfaces.entries) {
          await tester.pumpWidget(host(e.value));
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: '${e.key} ${surface.width.toInt()}×'
                  '${surface.height.toInt()}\'te taştı');
        }

        // Library\'nin ARAMA hâli — EN UZUN kapsam-dışı gerekçesiyle.
        // Gezinme hâlinden tamamen farklı bir layout ve en uzun prose orada.
        await tester.pumpWidget(host(LibraryScreen(content: c)));
        await tester.pump();
        final ExclusionSection longest = page.sections.reduce(
            (ExclusionSection a, ExclusionSection b) =>
                a.userReason.length >= b.userReason.length ? a : b);
        await tester.enterText(find.byKey(LibraryScreen.searchFieldKey),
            longest.examples.isEmpty ? longest.title : longest.examples.first);
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: 'Library ARAMA hâli ${surface.width.toInt()}pt\'te taştı '
                '(en uzun gerekçe: ${longest.id})');
      }
    });

    testWidgets('taşma süpürmesi SESSİZCE küçülemez', (WidgetTester tester) async {
      // ⚠️ Üstteki süpürme "hepsi" diyor; bu test "hepsi"nin KAÇ olduğunu
      // katalogla karşılaştırıyor. Kütüphane bir gün yanlışlıkla daralırsa
      // süpürme de daralır ve **yeşil kalır** — kapsamın sessizce küçülmesi,
      // bu defterin defalarca avladığı desen (G-129: kapı büyümeyle sahte
      // oldu; bu onun küçülme yönü).
      final ContentRepository c = await loadReal(tester);
      final int catalogued = _catalogFileCount();
      expect(c.catalogue.movements.length, catalogued,
          reason: 'Taşma süpürmesinin kapsamı katalogdan AYRIŞTI — '
              'kütüphanede $catalogued yerine ${c.catalogue.movements.length} '
              'hareket var.');
    });

    testWidgets(
        '⭐ SESSİZLİK NÖBETİ: her kullanıcı metni GERÇEKTEN çiziliyor',
        (WidgetTester tester) async {
      // ⚠️ Bu test, negatif ikizin ÜÇÜNCÜ yönü (JabLab aktarımı).
      //
      // Normal ikiz: *"düzeltme kaldırılırsa kırılır mı?"*
      // Ters ikiz:   *"kapı fazla genişlerse kırılır mı?"* (G-146)
      // Üçüncüsü:    ***"korunan cümle SİLİNİRSE kırılır mı?"***
      //
      // > Bir dürüstlük kapısı, korumaya çalıştığı cümlenin SİLİNMESİNİ de
      // > geçerli sayarsa, dürüstlüğü değil **SESSİZLİĞİ** korur.
      //
      // Ölçüldü: `comingSoonInThisMovement` hiçbir testte *ekranda çiziliyor
      // mu* diye SORULMUYORDU — iki referans da JSON içeriğine bakıyordu.
      // Yani hareket sayfasının "What is missing" bloğu TAMAMEN SİLİNSE
      // 117 testin hepsi yeşil kalırdı. Kuyruk metni ürünün en çok
      // konuştuğu yer (30/31 hareket) ve hiç korunmuyordu.
      //
      // Nöbet DESENE yazılıyor: hareketin TAŞIDIĞI her kullanıcı metni
      // ekranda BULUNMAK zorunda — tek tek alan saymak yerine.
      // ⚠️ 4000pt YETMEDİ ve nöbet bunu İLK KOŞUMDA gösterdi: `push_up`ın
      // güvenlik uyarısı "içerikte var, ekranda yok" diye öttü. Ölçtüm —
      // GERÇEK kusur değil, MOUNT sınırı: o sayfa 2134 karakter taşıyor ve
      // güvenlik bloğu en altta. Yani nöbetin kendisi doğru çalıştı, ölçü
      // aleti kısaydı.
      //
      // Ders (G-125'in üçüncü tekrarı): "ekranda yok" iddiası ancak yüzey
      // HER ŞEYİ mount edecek kadar uzunken kurulabilir. Genişlik 375
      // KALIYOR (taşma ona duyarlı), yükseklik içeriğe göre.
      tester.view.physicalSize = const Size(375, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final ContentRepository c = await loadReal(tester);

      for (final MovementEntry m in c.catalogue.movements) {
        await tester.pumpWidget(host(MovementPage(movement: m, content: c)));
        await tester.pump();

        final List<String> mustAppear = <String>[
          ...m.honesty.measured,
          ...m.honesty.waitingOnMeasurement,
          ...m.honesty.notMeasured,
          ...m.comingSoon,
          ...m.safetyWarnings,
          if (m.honesty.scoring != null) m.honesty.scoring!,
          m.blurb,
        ];
        for (final String text in mustAppear) {
          expect(find.text(text, skipOffstage: false), findsOneWidget,
              reason: '${m.id}: içerikte VAR, ekranda YOK — "$text". '
                  'Kapı bir sessizliği koruyor.');
        }
      }
    });

    testWidgets('EN UZUN dürüstlük kutusu da 375pt\'te taşmıyor',
        (WidgetTester tester) async {
      // Koordinatörün ② maddesi: sabit fixture yerine `library.json`daki EN
      // UZUN metinden beslen. Süpürme zaten HEPSİNİ ölçüyor (bu daha güçlü),
      // ama en uzunu AYRICA adlandırmak iki şey kazandırıyor: ölçümün neye
      // dayandığı görünür olur, ve en uzun metin küçülürse (yani içerik
      // sessizce kırpılırsa) burada fark edilir.
      final ContentRepository c = await loadReal(tester);
      final MovementEntry longest = c.catalogue.movements.reduce(
          (MovementEntry a, MovementEntry b) =>
              _honestyLength(a) >= _honestyLength(b) ? a : b);

      // Bugünkü en uzun `push_up` (curated, hasat sayılarıyla). Kimliği
      // SABİTLENMİYOR — terfi ettikçe başka bir hareket öne geçebilir ve
      // test onu ölçmeye devam etmeli.
      expect(_honestyLength(longest), greaterThan(1000),
          reason: 'En uzun dürüstlük kutusu 1000 karakterin altına düştü — '
              'içerik kırpılmış olabilir.');

      tester.view.physicalSize = const Size(375, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(MovementPage(movement: longest, content: c)));
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: '${longest.id}: en uzun dürüstlük kutusu 375pt\'te taştı');
      // Kutunun her maddesi GERÇEKTEN çizilmiş olmalı — taşmama, kırpılarak
      // da sağlanabilir ve o "geçti" en kötü geçiştir.
      for (final String item in longest.honesty.notMeasured) {
        expect(find.text(item, skipOffstage: false), findsOneWidget,
            reason: '${longest.id}: madde çizilmedi — "$item"');
      }
    });
  });

  group('"Neden yok?" sayfası', () {
    testWidgets('yedi bölümün hepsi ve gerekçeleri çiziliyor',
        (WidgetTester tester) async {
      useNarrowTall(tester);
      final ContentRepository c = await loadReal(tester);
      final ExclusionsPage page = c.catalogue.exclusions;
      // Sayı KAYNAKTAN: `exclusions.json`a bir bölüm eklendiğinde test
      // kırılmaz, yeni bölümü ÖLÇER.
      final Map<String, dynamic> src = (jsonDecode(File(
                  'content/catalog/exclusions.json')
              .readAsStringSync()) as Map)
          .cast<String, dynamic>();
      expect(page.sections.length, (src['sections'] as List<dynamic>).length);

      await tester.pumpWidget(host(WhyNotHereScreen(page: page)));
      await tester.pump();

      for (final ExclusionSection s in page.sections) {
        expect(find.byKey(WhyNotHereScreen.sectionKey(s.id), skipOffstage: false),
            findsOneWidget);
        // ⭐ SINIF cümlesi de EKRANDA (J-153): sınıf olmadan yedi kalem tek
        // çerçevede okunuyor ve `authority` olanlar *"teknoloji çözer"* diye
        // anlaşılıyor. Ölçüldü: 7 kalemin 3'ü authority — yani çoğunluk
        // değil ama azınlık da değil, ve hepsi yanlış okunuyordu.
        expect(
            find.text(LibraryStrings.limitClassLine(s.limitClass),
                skipOffstage: false),
            findsWidgets,
            reason: '${s.id}: sınır SINIFI ekranda yok — "kamera göremiyor" '
                'örtük bir vaat taşır, "bu bir çizgi" taşımaz.');
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

  _reachability();

  group('dil nöbeti — VAAT dili yasak (M-F-186)', () {
    test('kullanıcıya giden hiçbir metinde VAAT ifadesi YOK — "yet" DAHİL', () {
      // ⚠️ Bu kapı GENİŞLETİLDİ (koordinatör hükmü 2026-08-07). Önceki hâli
      // "yet"i BİLEREK kapsam dışı bırakıyordu çünkü aile defteri onu
      // yasaklarken bu üründe onaydan geçmiş mevcut metin kullanıyordu ve
      // ikisinden birini kendi kanaatimle seçmek istemedim. Koordinatör
      // hükmü geldi: **"yet" yasaklı.** Ölçülen: 103 örnek (87 üretilmiş +
      // 3 curated + 13 Dart string).
      //
      // KAPSAM da genişledi ve asıl düzeltme bu: eski kapı yalnız
      // `library.json`ın hareket bloklarına + exclusions'a bakıyordu. Yani
      // ders `lockedReason`'ı, `progress_strings`, `live_strings` ve
      // `library_strings` HİÇ TARANMIYORDU — kapı vardı ama yarısı kördü.
      // Ölçüldü: "yet"in bir örneği tam da o kör noktada (`lockedReason`)
      // duruyordu. Kapının kapsamı, kapının varlığı kadar önemli.
      const List<String> forbidden = <String>[
        'coming soon',
        'yakında',
        'stay tuned',
        'will be available',
        'in a future update',
        'we plan to',
      ];

      // TÜM `library.json` (dersler + kilit gerekçeleri dahil) + kapsam-dışı
      // sayfası + kullanıcı metni taşıyan HER Dart dosyası.
      final StringBuffer buf = StringBuffer()
        ..write(File('content/library.json').readAsStringSync())
        ..write(File('content/exclusions.page.json').readAsStringSync());
      for (final String path in <String>[
        'lib/app/library_strings.dart',
        'lib/app/progress_strings.dart',
        'lib/app/live_strings.dart',
      ]) {
        // Yorum satırları HARİÇ: bu dosyaların doküman yorumları kuralın
        // KENDİSİNİ tarif ediyor ve içinde "yet" geçiyor. Kuralı anlatan
        // cümleyi ihlal saymak, kapıyı kendi belgesine düşman eder.
        buf.write(File(path)
            .readAsLinesSync()
            .where((String l) =>
                !l.trimLeft().startsWith('///') && !l.trimLeft().startsWith('//'))
            .join('\n'));
      }
      final String userFacing = buf.toString().toLowerCase();

      for (final String phrase in forbidden) {
        expect(userFacing.contains(phrase), isFalse,
            reason: 'Kullanıcı metninde vaat ifadesi: "$phrase"');
      }

      // "yet" SÖZCÜK SINIRIYLA aranır: `yet` içeren meşru sözcükler
      // (ör. bir marka adı) yanlış alarm vermesin.
      final RegExp yet = RegExp(r'\byet\b');
      final Iterable<Match> hits = yet.allMatches(userFacing);
      expect(hits, isEmpty,
          reason: '"yet" VAAT dilidir (M-F-186): '
              '${hits.take(3).map((Match m) => userFacing.substring(
                  (m.start - 60).clamp(0, userFacing.length),
                  (m.end + 20).clamp(0, userFacing.length))).join(" ||| ")}');
    });

    testWidgets(
        '⭐ O-040 AKTARIMI: `measured` iddiasının kabukta CANLI YOLU var mı',
        (WidgetTester tester) async {
      // Koordinatörün Ostinato'dan aktardığı soru: `honesty.measured`
      // dürüstlük kutusunun ÜST YARISIDIR ve oradaki yanlış en pahalısıdır.
      // Motorun bir şeyi FIXTURE üzerinde ölçmesi, kullanıcının o ölçümü
      // ALDIĞI anlamına gelmiyor.
      //
      // Ölçüldü (2026-08-07): push_up 4 iddia taşıyordu; kabukta canlı yolu
      // olan **1** tanesiydi. `Rep` nesnesi `descentUs`/`ascentUs` (tempo) ve
      // `extremeAngleDeg` (ROM) taşıyor ama canlı ekran YALNIZ `reps.length`
      // çiziyor; `partial_rom` için canlı bir cue yolu HİÇ yok. Üçü kuyruğa
      // taşındı.
      //
      // Bu test o düzeltmeyi SABİTLİYOR: canlı ekranın sayısal yüzeyi rep
      // sayacından ibaret olduğu sürece, `measured` de tek iddiadan ibaret
      // kalmalı. Biri büyürse öteki de büyümek zorunda — ve büyümezse bu
      // kapı öter.
      final ContentRepository c = await loadReal(tester);
      for (final MovementEntry m in c.catalogue.movements) {
        if (m.honesty.measured.isEmpty) continue;
        expect(m.isLive, isTrue,
            reason: '${m.id}: canlı DEĞİL ama `measured` iddiası taşıyor — '
                'girilemeyen bir hareket ölçüm veremez');
        // ⚠️ SAYI DEĞİL KAYIT DEFTERİ. Eski hâli `measured.length == 1`
        // diyordu ve bu, tempo/ROM yüzeye çıkarıldığı gün — yani kusur
        // DÜZELTİLDİĞİ gün — kırmızıya dönerdi.
        //
        // Kural: her `measured` iddiası, kabukta onu GÖSTEREN bir yüzeye
        // izlenebilmeli. Yeni iddia eklemek serbest; iddiayı yüzeysiz
        // eklemek değil.
        for (final String claim in m.honesty.measured) {
          final String? surface = _surfaceForClaim(claim);
          expect(surface, isNotNull,
              reason: '${m.id}: "$claim" iddiasının kabukta GÖSTEREN yüzeyi '
                  'yok (O-040 sınıfı). Ya iddiayı kuyruğa taşı, ya da onu '
                  'çizen yüzeyi ekleyip `_surfacedClaims`e kaydet.');
          expect(
              File('lib/app/live_session_screen.dart')
                  .readAsStringSync()
                  .contains(surface!),
              isTrue,
              reason: '${m.id}: "$claim" için kayıtlı yüzey anahtarı '
                  '`$surface` canlı ekranda YOK — kayıt defteri bayatlamış.');
        }
      }
    });

    testWidgets(
        '⭐ J-113: `measured` iddiası TESPİT/PUANLAMA ayrımını taşıyor',
        (WidgetTester tester) async {
      // JabLab'ın bulgusu: "ölçülenler" başlığı İKİ AYRI iddiayı topluyor —
      // "tespit edip koçluyoruz" ile "puanlıyoruz" — ve kullanıcı ikincisini
      // okuyor. M-F-287'nin TERS yönü: bir SINIRI değil bir YETENEĞİ
      // olduğundan geniş yazmak; hata kullanıcının ALEYHİNE.
      //
      // Gravita'da ölçüldü: 30/31 hareket ipucu veren 71 kural taşıyor
      // (tespit + koçluk), bugün gerçekten puanlayan ders 0, scoreDisplay
      // 31/31 `band`. Sınıf VAR ve BASKIN — eksik olan ADIYDI.
      useNarrowTall(tester);
      final ContentRepository c = await loadReal(tester);

      for (final MovementEntry m in c.catalogue.movements) {
        if (m.honesty.measured.isEmpty) {
          // Ölçülen yoksa ayrım da olmamalı: olmayan bir şeyi nitelemek.
          expect(m.honesty.scoring, isNull, reason: m.id);
          continue;
        }
        expect(m.honesty.scoring, isNotNull,
            reason: '${m.id}: `measured` iddiası var ama TESPİT/PUANLAMA '
                'ayrımı YOK — okuyucu "puanlanıyor" diye okur (J-113).');
        // ⚠️ İFADEYE değil KAVRAMA bağlanıyor. İlk yazışımda `'not a score'`
        // tam metnini arıyordum ve üreteç "None of this is a score" yazınca
        // düştü — nöbetin kendisi bir yeniden-yazıma karşı kırılgandı.
        // Az önce `movement:<id>` iddiasında düzelttiğim hatanın aynısı:
        // sözleşme, cümlenin harfleri değil TAŞIDIĞI ayrım.
        expect(m.honesty.scoring!.toLowerCase(), contains('score'),
            reason: '${m.id}: ayrım cümlesi puanlamadan hiç söz etmiyor');
      }

      // Ayrım EKRANDA da çiziliyor — içerikte olması yetmez.
      final MovementEntry live =
          c.catalogue.movements.firstWhere((MovementEntry m) => m.isLive);
      await tester.pumpWidget(host(MovementPage(movement: live, content: c)));
      await tester.pump();
      expect(find.byKey(MovementPage.scoringKey, skipOffstage: false),
          findsOneWidget);
      expect(find.text(live.honesty.scoring!, skipOffstage: false),
          findsOneWidget);
    });

    test('canlı seans AYRI KOVAYA yazılıyor — ders trendine karışmıyor', () {
      // ⚠️ Bu nöbet TERS ÇEVRİLDİ ve çevrilme sebebi kayda değer. Önceki hâli
      // bir KUSURU sabitliyordu ("kabukta hiç `.append(` yok") ve ikinci yönü
      // şunu diyordu: *kabuk yazmaya başlarsa bu test öter, çünkü içerikteki
      // "seansın atılıyor" beyanı BAYAT olur.* Koordinatör G-132 hükmünü
      // verdi, yazma yolu eklendi, ve test **tam da tasarlandığı gibi öttü**.
      // Beyan içerikten kaldırıldı, nöbet yeni gerçeği tutuyor.
      //
      // Hüküm (G-132): seans başlatıldığı DERSİN kaydına yazılır — çünkü
      // farklı `focus`lu dersleri tek trendde toplamak, "tek genel skor yok"
      // yasağının ZAMAN eksenindeki hâlidir. Dar-kapsam şartı ölçüldü ve
      // DEVREDE: bugün `LiveSessionScreen`e tek giriş kabuktaki seans düğmesi
      // ve o giriş HAREKET düzeyinde — ders bağlamlı başlatma yolu YOK.
      // O yüzden her seans serbesttir ve AYRI DOSYAYA yazılır.
      final List<File> dart = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .toList();

      // ① Yazma yolu VAR.
      expect(dart.any((File f) => f.readAsStringSync().contains('.append(')),
          isTrue,
          reason: 'Seans yazma yolu kayboldu — tekrarlar yine atılıyor olur.');

      // ② Yazma SERBEST kovaya gidiyor, ders kovasına DEĞİL. Bu, hükmün
      //    "karışmaz" şartının mekanik hâli: karışma unutulmadığı için değil,
      //    yazan taraf öteki dosyayı hiç açmadığı için imkânsız.
      final String live =
          File('lib/app/live_session_screen.dart').readAsStringSync();
      expect(live.contains('openFreeSessionStore'), isTrue);
      expect(live.contains('openSessionStore()'), isFalse,
          reason: 'Canlı ekran DERS kovasına yazıyor — serbest seans ders '
              'trendine karışır ve 7-bileşen ayrımı zaman ekseninde çöker.');

      // ③ Anahtar ön eki: kova karışsa bile kaydın kendisi hareket olduğunu
      //    SÖYLÜYOR (`movement:<id>`), sessizce ders gibi görünmüyor.
      //
      // ⚠️ Bu iddia önce `content_repository.dart` içinde METİN olarak
      // aranıyordu ve tanımı `live_session.dart`a taşıyınca DÜŞTÜ — nöbet
      // doğru öttü ama yanlış şeyi ölçüyordu: bir sabitin hangi DOSYADA
      // yazıldığı sözleşme değil, ÜRETTİĞİ DEĞER sözleşme. Artık davranış
      // sınanıyor, konum değil.
      expect(ContentRepository.freeSessionKey('push_up'), 'movement:push_up');

      // ④ İçerikteki "atılıyor" beyanı KALDIRILMIŞ olmalı — kusur kapandıysa
      //    beyanı durmak, kapanmadığında durmaması kadar yanlış.
      final Map<String, dynamic> lib = (jsonDecode(
              File('content/library.json').readAsStringSync()) as Map)
          .cast<String, dynamic>();
      final Map<String, dynamic> pushUp = (lib['movements'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((Map<String, dynamic> m) => m['id'] == 'push_up');
      expect(
          (pushUp['comingSoonInThisMovement'] as List<dynamic>)
              .cast<String>()
              .any((String s) => s.contains('discarded')),
          isFalse,
          reason: 'Seans artık kaydediliyor; "atılıyor" beyanı BAYAT.');
    });

    testWidgets('KUYRUK ile KALICI sınır AYRI başlıklarda çiziliyor',
        (WidgetTester tester) async {
      // JabLab aktarımı: M-F-287 sınırın SINIFINI yazmayı söylüyordu; bu,
      // sınıfın hangi KUYRUĞA gittiğini de yazıyor.
      //   · ölçülmemiş → bir gün kapanır (ölçüm kapatır)
      //   · kamera göremez → ASLA kapanmaz
      // Tek listede toplandıklarında kullanıcı ürünü yanlış anlıyordu:
      // kalıcı sınır "yakında" sanılıyor, kuyruk da umutsuz görünüyordu.
      useNarrowTall(tester);
      final ContentRepository c = await loadReal(tester);
      // ⚠️ TEK hareket değil HEPSİ — ve bu bir düzeltmenin ürünü. Kapı
      // `firstWhere` ile ilk bloklu hareketi alıyordu; `bodyweight_squat`
      // **curated** olduğu için yapısal ayrımı HİÇ ALMAMIŞTI ve kapı onu
      // hiç görmedi. Muafiyet (prose'dan muaf) sessizce bir YAPISAL
      // iyileştirmeyi de dışarıda bırakmıştı — G-134'ün tam tekrarı.
      for (final MovementEntry m
          in c.catalogue.movements.where((MovementEntry x) => !x.isLive)) {
        expect(m.honesty.waitingOnMeasurement, isNotEmpty,
            reason: '${m.id}: kuyruk/kalıcı ayrımı YOK — kullanıcı '
                '"henüz ölçmedik" ile "kamera asla göremez" farkını '
                'göremiyor.');
        expect(m.honesty.notMeasured, isNotEmpty, reason: m.id);
        expect(
            m.honesty.waitingOnMeasurement
                .toSet()
                .intersection(m.honesty.notMeasured.toSet()),
            isEmpty,
            reason: '${m.id}: aynı madde hem kuyrukta hem kalıcı sınırda.');
      }

      final MovementEntry m = c.catalogue.movements
          .firstWhere((MovementEntry x) => !x.isLive);

      expect(m.honesty.waitingOnMeasurement, isNotEmpty);
      expect(m.honesty.notMeasured, isNotEmpty);
      // İKİ küme AYRIK olmalı — aynı cümle iki kuyruğa birden giremez.
      expect(
          m.honesty.waitingOnMeasurement
              .toSet()
              .intersection(m.honesty.notMeasured.toSet()),
          isEmpty,
          reason: '${m.id}: aynı madde hem kuyrukta hem kalıcı sınırda.');

      await tester.pumpWidget(host(MovementPage(movement: m, content: c)));
      await tester.pump();
      // İKİ başlık da EKRANDA — veride ayrılıp yüzeyde birleşirse ayrım yok.
      expect(find.text(LibraryStrings.honestyWaitingLabel.toUpperCase(),
          skipOffstage: false), findsOneWidget);
      expect(find.text(LibraryStrings.honestyNotMeasuredLabel.toUpperCase(),
          skipOffstage: false), findsOneWidget);
    });

    test('her bloklu hareket KUYRUĞUNU beyan ediyor — ve kuyruk TÜRETİMLİ', () {
      // ⭐ Koordinatörün sorusunun kapı hâli: *"kod bekleyenler bu gece
      // açılabilir, ölçüm bekleyenler açılamaz."* Ölçüldü: bugün 30/30
      // hareket ÖLÇÜM kuyruğunda, yani kod yazarak açılabilecek hareket YOK.
      //
      // Bu test o durumu SABİTLEMİYOR — tersine, DEĞİŞTİĞİ gün görünür
      // olmasını sağlıyor: yalnız kod bekleyen bir hareket doğarsa,
      // `--queues` onu yeşil satırda listeler ve bu test kuyruk beyanının
      // türetimli kaldığını doğrular.
      const Map<String, String> queueOf = <String, String>{
        'engine.precondition.status!=derived': 'measurement',
        'replayFixture:missing': 'measurement',
        'provenance.sources:empty': 'measurement',
      };
      final Map<String, dynamic> lib = (jsonDecode(
              File('content/library.json').readAsStringSync()) as Map)
          .cast<String, dynamic>();

      for (final Map<String, dynamic> m
          in (lib['movements'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        final List<String> blockers =
            ((m['blockedBy'] as List<dynamic>?) ?? const <dynamic>[])
                .cast<String>();
        if (blockers.isEmpty) {
          expect(m['blockedByQueue'], isNull,
              reason: '${m['id']}: engeli yok ama kuyruk beyanı var');
          continue;
        }
        // Kuyruk ELLE yazılamaz: bloker anahtarlarından TÜREMELİ.
        final Set<String> expected =
            blockers.map((String b) => queueOf[b]!).toSet();
        expect(
            ((m['blockedByQueue'] as List<dynamic>?) ?? const <dynamic>[])
                .cast<String>()
                .toSet(),
            expected,
            reason: '${m['id']}: kuyruk beyanı blokerlerinden türemiyor — '
                'elle yazılmış ya da bayatlamış.');
      }
    });

    test('KOD kuyruğu ÖLÇÜM kuyruğu gibi sunulmuyor', () {
      // Ölçüldü: `floor_press`in HİÇ kural seti yok. Üretilmiş cümle
      // "0 kural hiç koşturulmadı" diyordu — teknik olarak doğru ama YANLIŞ
      // KUYRUĞU gösteriyor: orada eksik olan ÖLÇÜM değil KOD. Yanlış kuyruk,
      // kapanmayacak bir şeyi kovalatır ya da kapanacak bir şeyi bekletir.
      final Map<String, dynamic> lib = (jsonDecode(
              File('content/library.json').readAsStringSync()) as Map)
          .cast<String, dynamic>();
      final Map<String, dynamic> fp = (lib['movements'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((Map<String, dynamic> m) => m['id'] == 'floor_press');
      final String queue =
          ((fp['honesty'] as Map)['waitingOnMeasurement'] as List<dynamic>)
              .join(' ');
      expect(queue.contains('No error rules have been written'), isTrue,
          reason: 'Kuralsız hareket, kural-koşturulmamış gibi sunuluyor.');
      expect(queue.contains('have never been run against real footage'), isFalse,
          reason: 'KOD boşluğu ÖLÇÜM boşluğu gibi anlatılıyor.');
    });

    testWidgets('J-124: Progress SERBEST seansı görüyor — "Not started" DEMİYOR',
        (WidgetTester tester) async {
      // ⚠️ Yayın envanterinin en ağır satırı. Ölçüldü: seanslar SERBEST kovaya
      // yazılıyordu (`free_sessions.jsonl`) ama Progress yalnız DERS kovasını
      // okuyordu. Yani kullanıcı gerçek bir seans yapıp Progress'e geldiğinde
      // ekran ona **"Not started"** diyordu — eksik bilgi değil, YANLIŞ bilgi.
      //
      // Bu, koordinatörün sevk ettiği J-124 sınıfı: *üretici yok ama beyan
      // onu ANLATIYOR* — burada üretici VARDI, beyan onu okumuyordu.
      useNarrowTall(tester);
      final ContentRepository c = await loadReal(tester);
      final SessionRecord free = SessionRecord(
        lessonId: ContentRepository.freeSessionKey('push_up'),
        completedAt: DateTime.utc(2026, 8, 7, 5),
        workedSeconds: 180,
        unitsCompleted: 12,
        plannedUnits: 0,
        unitLabel: 'rep',
        lessonClass: 'measurementOnly',
      );

      await tester.pumpWidget(host(Scaffold(
        body: ProgressView(
          summary: ProgressSummary.build(
            lessonSurfaces: c.lessonSurfaces,
            records: const <SessionRecord>[],
          ),
          freeSessions: <SessionRecord>[free],
        ),
      )));
      await tester.pump();

      expect(find.byKey(ProgressView.freeSectionKey, skipOffstage: false),
          findsOneWidget,
          reason: 'Gerçek seans yapılmış ama Progress onu GÖRMÜYOR.');
      expect(find.textContaining('12 reps', skipOffstage: false),
          findsOneWidget);
      // ⚠️ SESSİZLİK NÖBETİ: açıklayıcı cümle de EKRANDA olmalı. Nöbetin
      // eski hâli yalnız bölümün VARLIĞINI ve sayıyı sınıyordu — o cümle
      // (*"ayrı tutuluyor, hiçbir derse SAYILMIYOR"*) silinse kapı yeşil
      // kalırdı. Ve o cümle, G-132 hükmünün kullanıcıya ANLATILDIĞI tek yer:
      // sayı olmadan da bölüm görünür, ama ayrımın SEBEBİ kaybolur.
      expect(find.text(ProgressStrings.freeSubtitle, skipOffstage: false),
          findsOneWidget,
          reason: 'Serbest seans bölümünün GEREKÇESİ ekranda yok — bölüm '
              'görünüyor ama neden ayrı tutulduğu söylenmiyor.');

      // ⚠️ KARIŞMIYOR: serbest seans ders satırına GİRMEZ. `summary` boş
      // kayıtla kuruldu, yani ders satırları hâlâ "Not started" — ve bu
      // DOĞRU, çünkü o derse ait bir seans gerçekten yok. Yanlış olan,
      // serbest seansın HİÇ görünmemesiydi.
      expect(find.byKey(ProgressView.measuredSectionKey, skipOffstage: false),
          findsOneWidget);
    });

    testWidgets('POZİTİF İKİZ: serbest seans YOKKEN bölüm ÇİZİLMEZ',
        (WidgetTester tester) async {
      // Bölüm koşulsuz çizilseydi üstteki test yine geçerdi; bu ikiz onu
      // kapatıyor. Boş bir "Sessions outside a lesson" başlığı, altı boşken
      // tutulmayan bir söz olurdu (aynı gerekçe `notes` bölümünde de var).
      useNarrowTall(tester);
      final ContentRepository c = await loadReal(tester);
      await tester.pumpWidget(host(Scaffold(
        body: ProgressView(
          summary: ProgressSummary.build(
            lessonSurfaces: c.lessonSurfaces,
            records: const <SessionRecord>[],
          ),
        ),
      )));
      await tester.pump();
      expect(find.byKey(ProgressView.freeSectionKey, skipOffstage: false),
          findsNothing);
    });

    test('rozet ETİKETİ gerekçeli — "Coming soon" sınıfı etiket YOK', () {
      // Koordinatör hükmü ③: `status: coming_soon` bir VERİ MODELİ kodudur
      // ve serbesttir; ama o durumun GÖRÜNEN etiketi vaat olamaz. Rozet
      // "MEASURING" diyor ve kartın alt satırı gerekçeyi sayıyor
      // ("3 measurements missing") — durum, söz değil.
      expect(LibraryStrings.queuedBadge.toLowerCase().contains('soon'), isFalse);
      expect(LibraryStrings.queuedBadge.toLowerCase().contains('yakında'), isFalse);
      // ⚠️ `MEASURING` de yasak — "uygulama seni ölçüyor" diye okunuyordu,
      // oysa ölçülmemiş olan ÜRÜNÜN kendisi. Doğru sonuç, yanlış gerekçe.
      expect(LibraryStrings.queuedBadge.toLowerCase().contains('measuring'),
          isFalse,
          reason: 'Rozet, ölçümü KULLANICIYA atfediyor (J-124 sınıfı).');
      expect(LibraryStrings.blockerCount(3), contains('missing'));
    });

    testWidgets('HAM katalog anahtarı yüzeye sızmıyor (alt çizgi yok)',
        (WidgetTester tester) async {
      // Gerçek bir kusurun nöbeti: simülatörde kütüphane kartı ve hareket
      // sayfası **"Parallel_bars"** yazıyordu — ham `equipment` anahtarı.
      // 78 test yeşilken kaçtı çünkü hepsi metnin VARLIĞINI sınıyordu.
      // Bu nöbet DESENE yazılıyor: 31 hareketin HEPSİ, tek tek değil.
      // ⚠️ KAPSAM GENİŞLETİLDİ — BİÇİM ekseni (J-155 aktarımı).
      //
      // Eski hâli yalnız `metaLine`a bakıyordu ve `Parallel_bars`ı orada
      // yakalamıştı. Ama aynı kusur **başka bir biçimde** başka bir yerde
      // yaşıyordu: hareket sayfası *'This movement is node "hollow_body"…'*
      // diyerek HAM DÜĞÜM KİMLİĞİNİ çiziyordu. Nöbet oraya hiç bakmadı.
      //
      // > Bir kusuru bulduğun BİÇİMDE düzeltmek, onu bulduğun YERDE
      // > düzeltmek değildir.
      //
      // Artık sayfanın ÇİZDİĞİ metnin tamamı taranıyor — tek bir alan değil.
      // Kapsam kusurunun dört ekseni: dizin · katman · yüzey · **biçim**.
      final ContentRepository c = await loadReal(tester);
      useNarrowTall(tester);
      final RegExp rawKey = RegExp(r'\b[a-z]+_[a-z_]+\b');
      for (final MovementEntry m in c.catalogue.movements) {
        await tester.pumpWidget(host(MovementPage(movement: m, content: c)));
        await tester.pump();
        for (final Element e in find.byType(Text, skipOffstage: false)
            .evaluate()) {
          final String? t = (e.widget as Text).data;
          if (t == null) continue;
          final RegExpMatch? hit = rawKey.firstMatch(t);
          expect(hit, isNull,
              reason: '${m.id}: HAM ANAHTAR yüzeyde — "${hit?.group(0)}" '
                  '(cümle: "${t.length > 90 ? '${t.substring(0, 90)}…' : t}")');
        }
      }
    });

    test('HİÇBİR kullanıcı metninde DEFTER KODU yok — curated DAHİL', () {
      // Gerçek bir kusurun nöbeti: ilk üretimde kullanıcı cümlesine "(G-043)"
      // yazılmıştı. Kod kimliği iç izlenebilirliğin işidir (`blockedBy`),
      // kullanıcı cümlesinin değil.
      final Map<String, dynamic> lib = (jsonDecode(
              File('content/library.json').readAsStringSync()) as Map)
          .cast<String, dynamic>();
      // ⚠️ MUAFİYET DARALTILDI (JabLab aktarımı, 2026-08-07). Bu kapı
      // `honestySource: curated` girdileri ATLIYORDU ve tam orada bir kör
      // nokta üretiyordu: ölçüldü, curated prose'ta **8 defter kodu**
      // (ADR-003 · G-007 · G-014 · G-043 · G-050 · M-F-46) kullanıcı
      // yüzeyinde duruyordu ve kapı hiç ötmüyordu.
      //
      // Aynı kör nokta O-040 kusurunu da saklamıştı: push_up'ın 3 yanlış
      // `measured` iddiası TAMAMEN muaf alanların içindeydi ve onu hiçbir
      // kapı değil, koordinatörün insan sorusu buldu.
      //
      // Doğru sınır: muafiyet yalnız **DRIFT**e (prose ≠ yeniden üretilen
      // prose) uygulanır — her girdiye uygulanan DEĞİŞMEZLERE asla.
      // `_` ile başlayan alanlar (`_why_unlocked`) iç gerekçe kaydıdır ve
      // yüzeye hiç okunmaz; onlar hariç.
      final RegExp code = RegExp(r'\b[GMJ]-\d{2,3}\b|\bADR-\d+\b');
      for (final Map<String, dynamic> m
          in (lib['movements'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        final String blob = jsonEncode(<String, dynamic>{
          'blurb': m['blurb'],
          'honesty': m['honesty'],
          'comingSoonInThisMovement': m['comingSoonInThisMovement'],
          // Kilit gerekçesi KULLANICIYA gider — ilerleme ekranı onu aynen
          // çiziyor. Eski kapı buraya hiç bakmıyordu.
          'lockedReason': <String>[
            for (final dynamic c in (m['courses'] as List<dynamic>? ??
                const <dynamic>[]))
              for (final dynamic l in ((c as Map)['lessons'] as List<dynamic>? ??
                  const <dynamic>[]))
                if ((l as Map)['lockedReason'] != null)
                  l['lockedReason'] as String,
          ],
        });
        expect(code.hasMatch(blob), isFalse,
            reason: '${m['id']}: kullanıcı metninde defter kodu var '
                '(curated olması muafiyet DEĞİL — muafiyet yalnız drift için)');
      }
    });
  });
}

/// Bir hareketin dürüstlük kutusunun toplam karakter uzunluğu.
int _honestyLength(MovementEntry m) =>
    m.honesty.measured.join().length +
    m.honesty.notMeasured.join().length +
    (m.honesty.scoring?.length ?? 0);

/// `honesty.measured` iddiası ↔ onu ÇİZEN yüzey anahtarı.
///
/// ⭐ O-040'ın kalıcı hâli. Ölçüldü (`ae8a14d`): push_up 4 iddia ediyordu,
/// kabukta yolu olan 1'di — tempo ve ROM `Rep` nesnesinde VARDI ama hiçbir
/// ekran çizmiyordu. Üçü kuyruğa taşındı.
///
/// Bu defter o düzeltmeyi KURAL hâline getiriyor: bir iddia buraya kayıtlı
/// DEĞİLSE kapı öter, kayıtlıysa anahtarın canlı ekranda GERÇEKTEN var
/// olduğu ayrıca doğrulanır. Yani defterin kendisi de bayatlayamaz.
///
/// Tempo/ROM yüzeye çıktığı gün buraya bir satır eklenir ve iddia
/// `measured`a geri taşınabilir — kapı ürünün ilerlemesini ENGELLEMEZ,
/// yalnız iddianın yüzeysiz kalmasını engeller.
const Map<String, String> _surfacedClaims = <String, String>{
  'Rep count': 'repCountKey',
};

String? _surfaceForClaim(String claim) {
  for (final MapEntry<String, String> e in _surfacedClaims.entries) {
    if (claim.startsWith(e.key)) return e.value;
  }
  return null;
}

/// Katalogdaki hareket dosyası sayısı — dalga-bağımsız.
///
/// Testler bu sayıyı ELLE YAZMAZ: kütüphane ↔ katalog eşitliği bir KURAL,
/// `31` bir olgudur. Kural ürün büyürken doğru kalır, olgu kalmaz.
int _catalogFileCount() => Directory('content/catalog')
    .listSync()
    .whereType<Directory>()
    .expand((Directory d) => d.listSync())
    .whereType<File>()
    .where((File f) => f.path.endsWith('.json'))
    .length;

/// ⚠️ JabLab aktarımı: *"erişilemez bir sayfayı sabitleyen test, kapsam
/// sayarken kapsama benzer ama kullanıcıya ulaşan hiçbir şeyi ölçmez."*
///
/// Bu, bu hattın `c3cb694` bulgusunun GENEL hâli — 79 test yeşilken
/// simülatörde iki gerçek kusur vardı. **Test sayısı bir kapsam ölçüsü
/// değildir**, ve büyüme turlarında yanlış güven üretir: 28 hareket terfi
/// ederken test sayısı artacak, ama artan sayı kullanıcıya ULAŞAN yüzeyi
/// ölçmüyor olabilir.
///
/// Bu kapı ayrımı mekanikleştiriyor: her ekran ÜRETİM kodundan inşa
/// edilmeli. Yalnız testlerden çağrılan bir ekran, kapsam sayısını şişirir
/// ve kullanıcıya hiçbir şey vermez.
void _reachability() {
  test('her ekran ÜRETİM kodundan inşa ediliyor — test-only yüzey YOK', () {
    const List<String> screens = <String>[
      'HomeScreen', 'LibraryScreen', 'ProgressTab', 'ProfileScreen',
      'MovementPage', 'WhyNotHereScreen', 'LiveSessionScreen',
      'ContentFailureScreen',
    ];
    final List<File> prod = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();

    for (final String screen in screens) {
      // ⚠️ Kural bir DÜZELTMENİN ürünü. İlk hâli *"sınıfı tanımlayan
      // dosyayı komple atla"* diyordu ve `ProgressTab`te YANLIŞ ALARM
      // verdi: o sınıf `gravita_app.dart` içinde hem tanımlanıyor HEM
      // inşa ediliyor — yani kapı, doğru çalışan bir şeyi kırmızıya
      // döndürdü. Ters-ikiz dersinin (G-146) kendi kapımdaki hâli:
      // fazla geniş bir kural doğru şeyi öldürür.
      //
      // Doğrusu dosyayı değil KULLANIMI ayırmak: `X({` bir kurucu
      // TANIMIDIR, `X(` + argüman bir ÇAĞRIDIR.
      final RegExp call = RegExp('$screen\\s*\\((?!\\s*\\{)');
      final bool built = prod.any((File f) => call.hasMatch(
          f.readAsStringSync().replaceAll('class $screen extends', '')));
      expect(built, isTrue,
          reason: '$screen yalnız testlerden çağrılıyor — kullanıcı ona '
              'ULAŞAMIYOR. Onu sabitleyen testler kapsam sayıyor ama '
              'kullanıcıya ulaşan hiçbir şeyi ölçmüyor.');
    }
  });
}

/// 1×1 saydam PNG — `Image` tipini ağaca sokmak için en küçük geçerli veri.
const List<int> _tinyPng = <int>[
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
  0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137,
  0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1,
  13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
];
