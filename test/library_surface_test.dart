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
        expect(m.honesty.measured.length, 1,
            reason: '${m.id}: canlı ekran bugün YALNIZ rep sayacı çiziyor '
                '(live_session_screen `repCountKey`). Yeni bir `measured` '
                'iddiası eklendiyse onu GÖSTEREN yüzey de eklenmiş olmalı; '
                'yoksa iddia kabukta karşılıksızdır (O-040 sınıfı).');
        expect(m.honesty.measured.single.startsWith('Rep count'), isTrue);
      }
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

    test('rozet ETİKETİ gerekçeli — "Coming soon" sınıfı etiket YOK', () {
      // Koordinatör hükmü ③: `status: coming_soon` bir VERİ MODELİ kodudur
      // ve serbesttir; ama o durumun GÖRÜNEN etiketi vaat olamaz. Rozet
      // "MEASURING" diyor ve kartın alt satırı gerekçeyi sayıyor
      // ("3 measurements missing") — durum, söz değil.
      expect(LibraryStrings.queuedBadge.toLowerCase().contains('soon'), isFalse);
      expect(LibraryStrings.queuedBadge.toLowerCase().contains('yakında'), isFalse);
      expect(LibraryStrings.blockerCount(3), contains('missing'));
    });

    testWidgets('HAM katalog anahtarı yüzeye sızmıyor (alt çizgi yok)',
        (WidgetTester tester) async {
      // Gerçek bir kusurun nöbeti: simülatörde kütüphane kartı ve hareket
      // sayfası **"Parallel_bars"** yazıyordu — ham `equipment` anahtarı.
      // 78 test yeşilken kaçtı çünkü hepsi metnin VARLIĞINI sınıyordu.
      // Bu nöbet DESENE yazılıyor: 31 hareketin HEPSİ, tek tek değil.
      final ContentRepository c = await loadReal(tester);
      for (final MovementEntry m in c.catalogue.movements) {
        expect(LibraryStrings.metaLine(m).contains('_'), isFalse,
            reason: '${m.id}: ham anahtar yüzeyde — '
                '"${LibraryStrings.metaLine(m)}"');
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
