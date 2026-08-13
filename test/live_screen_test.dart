import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/library_model.dart';
import 'package:gravita/app/live_session.dart';
import 'package:gravita/app/live_strings.dart';
import 'package:gravita_engine/gravita_engine.dart';
import 'package:gravita/app/live_session_screen.dart';
import 'package:motion_camera/motion_camera.dart';

import 'support/launch_harness.dart';

/// Canlı seans YÜZEYİ — her hâlin ekranda ne dediği.
///
/// ⚠️ Bu süit kamerayı SÜRMÜYOR: `LiveSessionScreen` native kanal açıyor ve
/// widget testinde o kanal yok. Sınanan şey **hâl → metin** eşlemesi, yani
/// `LiveStrings` sözleşmesi ve hâllerin ayrılığı. Ekranın kendi kablolaması
/// simülatörde görüldü (G-120 ekran kanıtları), canlı zincir ise
/// `live_session_test.dart`te gerçek motorla koşuyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Katalogdan İSİMLE yükler — başlık ölçümü iki ayrı hareketi yan yana
  /// koymak zorunda (G-205 ikizi), tek bir sabit fixture yetmiyor.
  MovementConfig loadNamed(String id) => MovementConfig.parse(
      File('packages/gravita_engine/../../content/catalog/w1/$id.json')
          .readAsStringSync());

  MovementConfig load() => loadNamed('push_up');

  group('hâl → metin sözleşmesi', () {
    test('her tanınan arıza AYRI başlık ve gövde alıyor', () {
      final Set<String> titles = <String>{};
      final Set<String> bodies = <String>{};
      for (final CameraFailure f in CameraFailure.values) {
        titles.add(LiveStrings.failureTitle(f));
        bodies.add(LiveStrings.failureBody(f));
      }
      expect(titles.length, CameraFailure.values.length,
          reason: 'İki arıza aynı cümleyi paylaşıyorsa biri diğerinin '
              'arkasına saklanır.');
      expect(bodies.length, CameraFailure.values.length);
    });

    test('tanınmayan arıza da ADLANDIRILIYOR — boş bırakılmıyor', () {
      expect(LiveStrings.failureTitle(null), isNotEmpty);
      expect(LiveStrings.failureBody(null), isNotEmpty);
      expect(LiveStrings.failureTitle(null).toLowerCase(),
          contains("don't recognise"),
          reason: 'Bilinmeyeni bilinen bir arıza gibi sunmak yalan olur.');
    });

    test('izin metni gizliliği SÖYLÜYOR — kamera istemek açıklama ister', () {
      final String body =
          LiveStrings.failureBody(CameraFailure.permissionDenied).toLowerCase();
      expect(body, contains('never leaves'),
          reason: 'Kamera izni isterken verinin nereye gittiğini söylemeyen '
              'metin, izni hak etmiyor.');
    });

    test('sayım metni SKOR DEĞİL diyor', () {
      expect(LiveStrings.countingNote.toLowerCase(), contains('not scored'));
      expect(LiveStrings.reps(1), '1 rep');
      expect(LiveStrings.reps(3), '3 reps');
    });

    test('tekrar yokken "0" YAZILMIYOR — ne beklendiği söyleniyor', () {
      // "0 reps" teknik olarak doğru ama kullanıcıya bir HÜKÜM gibi okunur.
      expect(LiveStrings.noRepsYet.toLowerCase(), isNot(contains('0 ')));
      expect(LiveStrings.noRepsYet, isNotEmpty);
    });

    test('YEDEK kapı cümlesi doğrulanmayanı ATTIĞINI söylüyor', () {
      expect(LiveStrings.gateNoteFallback.toLowerCase(),
          contains('rather than guessed'),
          reason: 'Kapının varlığı değil, DAVRANIŞI beyan edilir.');
    });

    /// ⭐ G-205 — yedek cümle HİÇBİR harekete özel kapı İDDİA ETMEZ.
    ///
    /// Yedeğin tek işi yalan söylememek. İçine bir hareketin kimlik kapısı
    /// sızarsa (gövde yataylığı, kalça-diz eş-hareketi…) yedek sessizce
    /// "yanlış harekete doğru cümle" üreten şeye döner — düzeltilen kusurun
    /// ta kendisi.
    test('yedek cümle hareketE ÖZEL bir kapı iddia ETMİYOR', () {
      final String f = LiveStrings.gateNoteFallback.toLowerCase();
      for (final String kapiSizintisi in <String>[
        'torso',
        'horizontal',
        'hip',
        'knee',
        'elbow',
      ]) {
        expect(f, isNot(contains(kapiSizintisi)),
            reason: 'Yedek cümle "$kapiSizintisi" içeriyor ⇒ artık genel '
                'değil, BİR hareketin kapısı. Yanlış seansta yalan olur.');
      }
    });
  });

  /// ⭐ G-207 — SEANS BİTİNCE ÖLÇÜLEN EKRANDA KALIR.
  ///
  /// ## Kapattığı kusur
  ///
  /// `_stop()` kaydı yazıp doğrudan `LiveIdle`a dönüyordu: kullanıcı setini
  /// bitirdiği ANDA ekran *"henüz başlamadın"* hâline düşüyor, az önce
  /// kazandığı sayılar siliniyordu. Kayıt sağlamdı (G-132); kaybolan
  /// **tamamlanma anıydı** — "bitmiş ürün" tanımının 4. maddesi.
  ///
  /// ## Neden SAF testler — ve neden bu bir taviz DEĞİL
  ///
  /// Karar `buildFinishedState`te, `buildFreeSessionRecord`ın yanında ve aynı
  /// gerekçeyle: *"ne gösterilir, ne zaman HİÇ gösterilmez"* bir ÜRÜN
  /// kararıdır. Ekranın içinde bıraksaydım yalnız sahte kamera + izin kanalı
  /// + model yolu harness'ıyla sınanabilirdi; burada doğrudan sınanıyor.
  /// Bu, o dosyanın kendi kurduğu emsalin uygulanmasıdır, kestirme değil.
  group('seans BİTİNCE sonuç kalır (G-207)', () {
    const LiveRunning kosan = LiveRunning(
      reps: <Rep>[],
      personVisible: true,
      framesSeen: 12,
    );
    final DateTime t0 = DateTime(2026, 8, 14, 1);

    test('koşan seans BİTİŞ hâline geçer — LiveIdle DEĞİL', () {
      final LiveState s = buildFinishedState(
          state: kosan, startedAt: t0, endedAt: t0.add(const Duration(seconds: 42)));

      expect(s, isA<LiveFinished>(),
          reason: 'Kusurun ta kendisi buydu: bitişte LiveIdle\'a dönmek.');
      expect((s as LiveFinished).elapsed, const Duration(seconds: 42));
      expect(s.framesSeen, 12);
    });

    /// POZİTİF İKİZ: her durdurma bir özet DEĞİLDİR. Koşmayan bir hâlden
    /// durdurma sıfırlarla dolu bir "özet" üretseydi, ürün hiç yapılmamış bir
    /// seansı yapılmış gibi gösterirdi.
    test('koşMAYAN hâlden durdurma özet ÜRETMEZ', () {
      for (final LiveState girdi in <LiveState>[
        const LiveIdle(),
        const LiveStarting(),
        const LiveFailed(CameraFailure.permissionDenied),
      ]) {
        expect(buildFinishedState(state: girdi, startedAt: t0, endedAt: t0),
            isA<LiveIdle>(),
            reason: '${girdi.runtimeType} özetlenecek bir ölçüm taşımıyor.');
      }
    });

    test('saat geri alınmışsa EKSİ süre gösterilmez', () {
      final LiveState s = buildFinishedState(
          state: kosan, startedAt: t0, endedAt: t0.subtract(const Duration(minutes: 5)));

      expect((s as LiveFinished).elapsed, Duration.zero,
          reason: 'Eksi bir "çalışma" yazmaktansa 0 dürüst.');
    });

    /// "Kamera hiç kare vermedi" ile "izledik ama tam tekrar çıkmadı" AYRI
    /// sonuçlardır: biri ölçüm YOKLUĞU, öteki gerçek bir ölçüm. Yüzey ikisini
    /// ayrı cümlelerle anlatır; metinler eşitlenirse ayrım sessizce ölür.
    test('iki "hiçbir şey" hâli AYNI cümleyle anlatılmıyor', () {
      expect(LiveStrings.finishedNoFrames,
          isNot(equals(LiveStrings.finishedNoReps)));
      expect(LiveStrings.finishedNoFramesNote,
          isNot(equals(LiveStrings.finishedNoRepsNote)));
    });

    test('kare yoksa sawFrames false — seans SAYILMAZ', () {
      const LiveFinished bos = LiveFinished(
          reps: <Rep>[], framesSeen: 0, elapsed: Duration(seconds: 3));
      expect(bos.sawFrames, isFalse);
      expect(bos.tempo, isNull, reason: 'Tekrar yokken tempo UYDURULMAZ.');
    });

    /// Tempo ORTANCA — ortalama DEĞİL. Tek bir uzun duraklama ortalamayı
    /// sürükler ve kullanıcıya hiç yapmadığı bir tempoyu geri okur.
    /// Bu fikstürde ortalama 3000ms, ortanca 1000ms: iki cevap AYRIŞIYOR,
    /// yani test hangisinin uygulandığını gerçekten ayırt ediyor.
    test('tempo ORTANCA veriyor, ortalama değil', () {
      final LiveFinished f = LiveFinished(
        reps: <Rep>[
          _rep(0, descentUs: 1000000, ascentUs: 1000000),
          _rep(1, descentUs: 1000000, ascentUs: 1000000),
          _rep(2, descentUs: 7000000, ascentUs: 7000000),
        ],
        framesSeen: 90,
        elapsed: const Duration(seconds: 30),
      );

      expect(f.tempo!.descent, const Duration(seconds: 1));
      expect(f.tempo!.ascent, const Duration(seconds: 1));
    });
  });

  /// ⭐ G-210 — YÜZEYE ÇIKAN BİR ÖLÇÜM, İÇERİKTE "GÖSTERİLMİYOR" DİYE KALAMAZ.
  ///
  /// ## Bu kapının doğuş hikâyesi — kendi kusurum
  ///
  /// `G-207` seans özetine **tempo** ekledi. `content/library.json`da ise
  /// squat'ın `comingSoonInThisMovement[0]`'ı şunu diyordu:
  /// *"…**no screen in this app shows it to you**, so we do not count it as
  /// something you get."*
  /// Sabahleyin DOĞRU olan bu cümleyi **kendi iyileştirmem YALANA çevirdi** ve
  /// üç süitin hiçbiri kırmızı yanmadı.
  ///
  /// > ***BİR ÜRÜNÜ İYİLEŞTİRMEK, ONUN HAKKINDAKİ DOĞRU BİR CÜMLEYİ
  /// > YANLIŞLAYABİLİR — VE BU, KUSURUN EN SESSİZ TÜRÜDÜR: kimse bir şeyi
  /// > bozmamıştır, yalnız beyan geride kalmıştır.***
  ///
  /// Kusuru bulan şey bir kapı değildi: uygulamayı açıp `push_up` sayfasını
  /// **okumaktı**. Kapı şimdi var, ki bir dahakine okumaya kalmasın.
  ///
  /// ## Neden YALNIZ ulaşılabilir hareket
  ///
  /// `push_up`ın aynı cümlesi **bugün hâlâ DOĞRU** — o hareketin seansı
  /// başlatılamıyor (`startable_reach_test`), dolayısıyla tempoyu ona
  /// gösteren bir ekran gerçekten yok. Cümleyi orada da değiştirmek,
  /// düzeltmek değil **yeni bir yanlış beyan üretmek** olurdu.
  /// ⇒ Kapı `liveConfig`in döndürdüğü harekete bağlanıyor: `push_up`
  /// başlatılabilir olduğu gün otomatik olarak onu da kapsar.
  group('içerik, gösterilen bir ölçümü "gösterilmiyor" diye ANLATMIYOR (G-210)',
      () {
    testWidgets('ulaşılabilir hareket tempoyu "hiçbir ekran göstermiyor" DEMİYOR',
        (WidgetTester tester) async {
      late ContentRepository repo;
      await tester
          .runAsync(() async => repo = await ContentRepository.load(rootBundle));

      final MovementConfig? giris = repo.liveConfig;
      expect(giris, isNotNull, reason: 'VAKUM: canlı giriş yoksa kapı boştur.');

      final MovementEntry hareket = repo.catalogue.movements
          .firstWhere((MovementEntry m) => m.catalogId == giris!.id);

      // Seans özeti tempoyu ÇİZİYOR — bu testin dayanağı budur.
      final LiveFinished ornek = LiveFinished(
        reps: <Rep>[_rep(0, descentUs: 900000, ascentUs: 800000)],
        framesSeen: 40,
        elapsed: const Duration(seconds: 20),
      );
      expect(ornek.tempo, isNotNull,
          reason: 'Tempo artık ölçülüp gösteriliyor; aşağıdaki beyan buna '
              'dayanıyor. Tempo yüzeyden kalkarsa bu kapı da yeniden '
              'gerekçelendirilmeli.');

      for (final String cumle in hareket.comingSoon) {
        final String c = cumle.toLowerCase();
        if (!c.contains('tempo')) continue;
        expect(c, isNot(contains('no screen in this app shows it')),
            reason: 'İçerik tempoyu "hiçbir ekran göstermiyor" diye anlatıyor, '
                'ama seans özeti onu ÇİZİYOR. Beyan geride kalmış: $cumle');
      }
    });
  });

  group('hâller birbirinin yerine geçmiyor', () {
    test('"kimse yok" LiveRunning içinde, LiveFailed DEĞİL', () {
      const LiveState s =
          LiveRunning(reps: <Rep>[], personVisible: false, framesSeen: 3);
      expect(s, isA<LiveRunning>());
      expect(s, isNot(isA<LiveFailed>()));
    });

    test('POZİTİF İKİZ: gerçek arıza LiveFailed, LiveRunning DEĞİL', () {
      const LiveState s = LiveFailed(CameraFailure.noSuchCamera);
      expect(s, isA<LiveFailed>());
      expect(s, isNot(isA<LiveRunning>()));
    });
  });

  group('canlı giriş: ölü buton yok', () {
    testWidgets('kimlik ön koşulu DERIVED olan hareket canlı yola uygun',
        (WidgetTester tester) async {
      // FAB'ın çizilme koşulu bu; koşul kayarsa buton ölü butona dönerdi.
      expect(load().preconditionDerived, isTrue);
    });

  });

  /// ⭐ G-205 — SEANS BAŞLIĞI İÇERİKTEN GELİR, SABİTTEN DEĞİL.
  ///
  /// ## Kapattığı kusur
  ///
  /// `live_strings.dart`ta `title = 'Push-ups'` SABİTİ vardı. Canlı seansa tek
  /// giriş `ContentRepository.liveConfig` ve o **İLK** uygun hareketi döndürür;
  /// `library.json` sırası `[0] bodyweight_squat` ⇒ açılan seans **squat**.
  /// Yani ürünün tek ulaşılabilir seansı, YAPILMAYAN hareketin adını taşıyordu
  /// — üstelik o ad `push_up`, yani BAŞLATILAMAYAN hareketin adı.
  ///
  /// ## Neden eski test bunu göremedi — bu süitin varlık sebebi
  ///
  /// Eski kapı `Text(LiveStrings.title)` pump edip aynı metni arıyordu:
  /// **koşulsuz doğru**. Başlık `'Banana'` olsa da geçerdi, çünkü beklenti
  /// ölçtüğü şeyden türetiliyordu.
  /// > ***KOŞULSUZ DOĞRU BİR KAPI HİÇBİR ŞEY ÖLÇMEZ*** (bu hattın 2.11 kuralı).
  ///
  /// ## Ayırt ediciliği KURGUSAL — mutasyona ihtiyaç duymuyor
  ///
  /// Aynı ekran İKİ ayrı config'le pump ediliyor ve İKİ AYRI başlık bekleniyor.
  /// Herhangi bir SABİT başlık iki beklentiyi aynı anda karşılayamaz ⇒ eski
  /// kusur bu süit altında tanım gereği kırmızıdır. Sabotaj kurmaya gerek yok:
  /// ayırt edicilik testin şeklinde, bir mutasyonun keşfinde değil.
  group('seans başlığı İÇERİKTEN gelir (G-205)', () {
    /// ⚠️ VAKUM KORUMASI: iki hareket AYNI ada sahip olsaydı aşağıdaki iki
    /// beklenti bir sabitle de karşılanabilirdi ve süit sessizce ayırt
    /// ediciliğini kaybederdi. Payda önce kanıtlanır.
    test('iki hareketin adı GERÇEKTEN farklı — yoksa ikiz ayırt edici değil',
        () {
      expect(loadNamed('bodyweight_squat').name,
          isNot(equals(loadNamed('push_up').name)),
          reason: 'Adlar eşitse sabit bir başlık her iki testi de geçer.');
    });

    for (final String id in <String>['bodyweight_squat', 'push_up']) {
      testWidgets('$id seansının başlığı o hareketin ADI',
          (WidgetTester tester) async {
        final MovementConfig config = loadNamed(id);
        await tester.pumpWidget(MaterialApp(
            home: LiveSessionScreen(config: config, controller: _NoCamera())));

        expect(find.text(config.name), findsOneWidget,
            reason: 'Başlık config.name olmalı; sabit bir başlık burada düşer.');
      });
    }

    /// Ürünün GERÇEK girişinin bugün hangi hareketi açtığını sabitler.
    /// `library.json` sırası değişirse bu satır kırmızı yanar ve başlık
    /// iddiası YENİDEN gözden geçirilir — sessizce kaymaz.
    testWidgets('bugünkü tek giriş SQUAT açıyor — başlık iddiasının dayanağı',
        (WidgetTester tester) async {
      late ContentRepository repo;
      await tester
          .runAsync(() async => repo = await ContentRepository.load(rootBundle));
      final MovementConfig? giris = repo.liveConfig;

      expect(giris, isNotNull, reason: 'Canlı giriş yoksa başlık sorusu boştur.');
      expect(giris!.id, 'bodyweight_squat',
          reason: 'Giriş kaydıysa (sıra değişimi) başlık ölçümü yeniden '
              'gerekçelendirilmeli.');
    });
  });

  /// ⭐ G-205 — KAPI CÜMLESİ DE İÇERİKTEN. Başlıktan DAHA AĞIR bir kusurdu.
  ///
  /// Sabit `gateNote`, seansı açan hareket ne olursa olsun *"we can see your
  /// torso is actually horizontal"* diyordu. O **şınavın** kapısı
  /// (`torso_angle_from_vertical >= 60`); squat'ınki **kalça-diz eş-hareketi**
  /// (`windowPrecondition`, Pearson >= 0,2). Ürünün tek ulaşılabilir seansı
  /// squat olduğu için kullanıcı **ölçülmeyen bir şeyin ölçüldüğünü** okuyordu.
  ///
  /// > ***YANLIŞ ETİKET BİR ADLANDIRMA HATASIDIR; YANLIŞ ÖLÇÜM İDDİASI BİR
  /// > DÜRÜSTLÜK HATASIDIR — İKİSİ AYNI KEFEYE KONMAZ.***
  ///
  /// Bu kusuru statik okuma DEĞİL, **uygulamayı çalıştırmak** buldu: başlık
  /// düzeltilip simülatörde yürünürken kapı cümlesi ekranda okundu.
  group('kapı cümlesi İÇERİKTEN gelir (G-205)', () {
    /// Ayırt edici ikiz: iki hareketin kapı cümlesi FARKLI olmak ZORUNDA.
    /// Herhangi bir sabit cümle bu beklentiyi karşılayamaz.
    test('iki canlı hareketin kapı cümlesi FARKLI', () {
      final String? squat = loadNamed('bodyweight_squat').contract.gateNote;
      final String? sinav = loadNamed('push_up').contract.gateNote;

      expect(squat, isNotNull);
      expect(sinav, isNotNull);
      expect(squat, isNot(equals(sinav)),
          reason: 'Eşitlerse en az biri yanlış hareketin kapısını anlatıyor.');
    });

    /// Her cümle KENDİ `engine.precondition`ını anlatmalı — "farklı olsunlar"
    /// yetmez, DOĞRU olanı anlatmaları gerekir. Cümleler yer değiştirseydi
    /// üstteki test yine yeşil kalırdı; bu test kalmaz.
    test('her cümle KENDİ kapısını anlatıyor — yer değiştirmeye karşı', () {
      final String squat =
          loadNamed('bodyweight_squat').contract.gateNote!.toLowerCase();
      final String sinav = loadNamed('push_up').contract.gateNote!.toLowerCase();

      expect(squat, contains('hip'));
      expect(squat, contains('knee'));
      expect(squat, isNot(contains('horizontal')),
          reason: 'Squat kapısı gövde yataylığı DEĞİL — o şınavınki.');

      expect(sinav, contains('horizontal'));
      expect(sinav, isNot(contains('hip and knee')),
          reason: 'Şınav kapısı kalça-diz eş-hareketi DEĞİL — o squat\'ınki.');
    });

    /// ⛔ YEDEK, CANLI BİR HAREKETİ SESSİZCE ÖRTEMEZ.
    ///
    /// Yedek cümle yalan söylemez ama bilgi de vermez. Canlı bir hareket
    /// yedeğe düşerse kullanıcı o hareketin kapısını HİÇ öğrenemez ve bu
    /// kimsenin gözüne batmaz — tam olarak `A3`ün "sessiz yüzey" sınıfı.
    testWidgets('canlı BEYAN EDİLEN her hareketin KENDİ cümlesi var',
        (WidgetTester tester) async {
      late ContentRepository repo;
      await tester
          .runAsync(() async => repo = await ContentRepository.load(rootBundle));

      final List<String> yedegeDusenler = <String>[];
      final List<String> canlilar = <String>[];
      for (final MovementEntry m in repo.catalogue.movements) {
        if (!m.isLive) continue;
        canlilar.add(m.id);
        if (repo.loadedCatalog(m.catalogId)?.contract.gateNote == null) {
          yedegeDusenler.add(m.id);
        }
      }

      // VAKUM: canlı hareket yoksa aşağıdaki beklenti tanım gereği geçerdi.
      expect(canlilar, isNotEmpty,
          reason: 'VAKUM: canlı hareket yok; kapı cümlesi ölçümü anlamsız.');
      expect(yedegeDusenler, isEmpty,
          reason: 'Bu hareketler canlı BEYAN EDİLİYOR ama kendi kapı '
              'cümleleri YOK ⇒ kullanıcı genel yedeği görür ve o hareketin '
              'neyle korunduğunu HİÇ öğrenmez: $yedegeDusenler');
    });

    /// Ekran gerçekten config'in cümlesini çiziyor mu — sözleşme değil YÜZEY.
    testWidgets('ekran config\'in kapı cümlesini ÇİZİYOR',
        (WidgetTester tester) async {
      final MovementConfig squat = loadNamed('bodyweight_squat');
      await tester.pumpWidget(MaterialApp(
          home: LiveSessionScreen(config: squat, controller: _NoCamera())));

      expect(find.text(squat.contract.gateNote!), findsOneWidget);
      expect(find.text(LiveStrings.gateNoteFallback), findsNothing,
          reason: 'Özel cümlesi olan hareket yedeğe DÜŞMEMELİ.');
    });
  });

  /// ⭐ KALICI RET — G-185. Koordinatörün aile taraması bende `permanentlyDenied`
  /// için SIFIR isabet bulmuştu ve ölçüm onu doğruladı: kusur eksiklik değil
  /// **ayrımsızlıktı** — üç hâl de `!isGranted` kovasına düşüyordu.
  ///
  /// Bu grup ekranı GERÇEKTEN pump ediyor ve izin kanalını yanıtlıyor;
  /// sınanan şey "hangi hâl doğdu" değil **kullanıcının ekranda ne
  /// görebildiği ve neye basabildiği**.
  group('kamera izni KALICI reddedildiğinde ölü döngü YOK', () {
    Future<void> pumpScreen(WidgetTester tester, {required int status}) async {
      mockPermissionChannel(status: status);
      await tester.pumpWidget(MaterialApp(
          home: LiveSessionScreen(config: load(), controller: _NoCamera())));
      await tester.tap(find.byKey(LiveSessionScreen.startButtonKey));
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    testWidgets('kalıcı ret: Settings eylemi ÇİZİLİR, Start çizilmez',
        (WidgetTester tester) async {
      await pumpScreen(tester, status: 4); // permanentlyDenied

      expect(find.byKey(LiveSessionScreen.openSettingsKey), findsOneWidget,
          reason: 'İşe yarayan TEK eylem bu; yoksa metin Settings diyor ama '
              'oraya götüren hiçbir kontrol olmuyor.');
      expect(find.byKey(LiveSessionScreen.startButtonKey), findsNothing,
          reason: 'Basılabilir ama ASLA başarılı olamayacak bir düğme, ölü '
              'butondan farksızdır.');
      expect(find.text(LiveStrings.permissionBlockedTitle), findsOneWidget);
    });

    testWidgets('KISITLI cihaz (MDM/ebeveyn) da aynı yere düşer',
        (WidgetTester tester) async {
      // `isRestricted` sezgiyle bulunamaz: diyalog HİÇ çıkmaz, yani
      // "ikinci ret = kalıcı" sezgisi bu vakayı İLKECE göremez.
      await pumpScreen(tester, status: 2); // restricted

      expect(find.byKey(LiveSessionScreen.openSettingsKey), findsOneWidget);
      expect(find.byKey(LiveSessionScreen.startButtonKey), findsNothing);
    });

    testWidgets(
        'POZİTİF İKİZ — GEÇİCİ rette Start KALIR, Settings çizilmez',
        (WidgetTester tester) async {
      // Bu ikiz olmadan üstteki iki test, Start düğmesini HER arızada gizleyen
      // bir uygulamada da geçerdi. Geçici rette tekrar denemek ANLAMLI:
      // sistem diyaloğu bir daha çıkar.
      await pumpScreen(tester, status: 0); // denied

      expect(find.byKey(LiveSessionScreen.startButtonKey), findsOneWidget);
      expect(find.byKey(LiveSessionScreen.openSettingsKey), findsNothing);
      expect(find.text(LiveStrings.permissionBlockedTitle), findsNothing);
    });

    testWidgets('ham durum ADIYLA gösteriliyor — sabit "denied" değil',
        (WidgetTester tester) async {
      // Eski kod `detail`e SABİT 'permission_handler: denied' yazıyordu:
      // gerçek durum `permanentlyDenied` olsa bile "denied" diyordu.
      await pumpScreen(tester, status: 4);
      expect(find.textContaining('permanentlyDenied'), findsOneWidget);
    });
  });
}

/// Kamera AÇILMADAN önce izin kapısına takılıyoruz; bu denetleyicinin hiçbir
/// üyesi çağrılmamalı. Çağrılırsa test ADIYLA düşsün — sessiz bir sahte,
/// izin kapısının atlandığını gizlerdi.
/// Tempo ölçümü için tekrar fikstürü — yalnız süre alanları anlamlı.
Rep _rep(int index, {required int descentUs, required int ascentUs}) => Rep(
      index: index,
      startUs: 0,
      endUs: descentUs + ascentUs,
      descentUs: descentUs,
      ascentUs: ascentUs,
      extremeAngleDeg: 95,
      startedAtOpenEnd: true,
      identityGapShare: 0,
    );

class _NoCamera implements MotionCameraController {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('İzin kapısı geçilmemeliydi: ${invocation.memberName}');
}
