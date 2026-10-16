import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show ByteData, CachingAssetBundle, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/content_failure_screen.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/gravita_app.dart';
import 'package:gravita/app/onboarding_store.dart';
import 'package:gravita/app/progress_strings.dart';
import 'package:gravita/app/progress_view.dart';
import 'package:gravita_engine/gravita_engine.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/launch_harness.dart';

/// Kabuk UÇTAN UCA — sahte hiçbir şey yok.
///
/// GERÇEK `library.json` + GERÇEK katalog (asset bundle'dan) → GERÇEK
/// `JsonlSessionStore` (geçici dosya) → GERÇEK `ProgressView`. Diğer testler
/// katmanları ayrı ayrı tutuyor; bu test **zincirin kendisini** koşuyor.
///
/// Neden gerekli: gecenin en pahalı dersi "testler yeşil ≠ kod koşuyor" oldu
/// (rig sondasında `reports` başlatması düşmüştü ve sözleşme testleri
/// orkestrasyonu hiç koşmadığı için sessiz kaldı). Kabukta aynı boşluğun adresi
/// burası: içerik yükleme + kalıcılık + yüzey ancak BİRLİKTE koştuğunda
/// kanıtlanır.
///
/// `path_provider` BİLEREK çağrılmıyor: depo kurucusu bir `File` alıyor, o yüzden
/// zincir platform kanalı olmadan koşabiliyor. Terfi-arayüzünün 1. şartının
/// (`File` alan kurucu) somut bedeli/faydası tam olarak bu testtir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late File file;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('gravita_shell');
    file = File('${tmp.path}/sessions.jsonl');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  testWidgets('gerçek içerik + gerçek depo + gerçek yüzey birlikte koşuyor', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // ⚠️ GERÇEK G/Ç `tester.runAsync` İÇİNDE koşmak ZORUNDA. `testWidgets`
    // gövdesi SAHTE saatli (FakeAsync) bir bölgede çalışır: dosya okuma ve
    // asset kanalı gibi işletim sistemine bağlı future'lar sahte saat
    // ilerletilmediği için ASLA tamamlanmaz — ilk yazışımda test hata vermedi,
    // **10 dakika ASILDI**. Arıza yönü öğretici: sahte-async bir bölgede
    // "gerçek" iş yapmak, kırmızı test değil ÖLÜ test üretir.
    late ContentRepository content;
    late ProgressSummary summary;
    await tester.runAsync(() async {
      // 1) GERÇEK içerik — asset bundle'dan, `wave` alanından kurulan adresle.
      content = await ContentRepository.load(rootBundle);
      expect(content.lessonSurfaces, isNotEmpty);
      // Birim KATALOGDAN geldi (push_up repFsm), elle yazılmadı.
      expect(content.lessonSurfaces.first.unitLabel, 'rep');

      // 2) GERÇEK depo — append-only JSONL, gerçek dosya.
      final JsonlSessionStore store = JsonlSessionStore(file);
      await store.append(
        SessionRecord(
          lessonId: 'push_foundations.reps_and_tempo',
          completedAt: DateTime.utc(2026, 7, 30, 9),
          workedSeconds: 95,
          unitsCompleted: 6,
          plannedUnits: 8,
          unitLabel: 'rep',
          lessonClass: 'measurementOnly',
          unmeasuredUnits: 1,
          unmeasuredReason: 'framing',
        ),
      );
      await store.append(
        SessionRecord(
          lessonId: 'push_foundations.reps_and_tempo',
          completedAt: DateTime.utc(2026, 7, 30, 18),
          workedSeconds: 130,
          unitsCompleted: 9,
          plannedUnits: 8,
          unitLabel: 'rep',
          lessonClass: 'measurementOnly',
        ),
      );
      expect(
        file.readAsLinesSync().length,
        2,
        reason: 'Dosyaya GERÇEKTEN yazıldı.',
      );

      // 3) GERÇEK özet.
      summary = ProgressSummary.build(
        lessonSurfaces: content.lessonSurfaces,
        records: await store.recent(),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProgressView(summary: summary)),
      ),
    );

    // Ölçümler toplandı: 6 + 9 tekrar, 95 + 130 saniye.
    expect(
      find.descendant(
        of: find.byKey(ProgressView.measuredSectionKey),
        matching: find.text('15 reps'),
      ),
      findsOneWidget,
    );
    expect(find.text('3 min 45 s worked'), findsOneWidget);
    expect(find.text('2 sessions'), findsOneWidget);

    // Ölçülemeyen 1 tekrar SAKLANMADI ve gerekçesi göründü.
    expect(find.textContaining('framing'), findsOneWidget);

    // The complete source measurement explanation survives. Historical
    // availability is qualified by this release's closed camera policy.
    final LessonSurface locked = content.lessonSurfaces.firstWhere(
      (LessonSurface s) => s.isLocked,
    );
    expect(
      find.descendant(
        of: find.byKey(ProgressView.lockedSectionKey),
        matching: find.textContaining(
          locked.lockedReason!.split('Rep counting').first,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Rep counting is unaffected and stays open.'),
      findsNothing,
    );
    expect(
      find.textContaining(
        'live camera sessions are unavailable in this release.',
      ),
      findsNWidgets(2),
    );

    // Bugün hiçbir ders not vermiyor → retroaktif kredi notu YOK. Bu bir
    // ölçüm: form notu açıldığı gün bu satır düşer ve kural gerçek geçmişle
    // sınanır (bayat-yokluk nöbeti, M-F-165).
    expect(summary.withheldRetroactiveCredit, 0);
  });

  // --- ÇEKİRDEK 0.10.0: kayıp-satır sayımı GERÇEK dosyayla ---
  //
  // Widget testleri `HistoryPartial`ı ELLE kuruyor; bu test onu KİMSE
  // kurmadan, gerçek bozuk satırlardan doğurtuyor. İkisi farklı şeyi
  // kanıtlar: orada yüzeyin davranışı, burada çekirdeğin sayımının
  // gerçekten çalıştığı ve kabuğun onu doğru okuduğu.
  testWidgets('GERÇEK JSONL: 1 sağlam + 3 bozuk satır → kayıp SAYILIYOR', (
    WidgetTester tester,
  ) async {
    late int unreadable;
    late List<SessionRecord> records;
    await tester.runAsync(() async {
      final File f = File('${tmp.path}/mixed.jsonl');
      final JsonlSessionStore store = JsonlSessionStore(f);
      await store.append(
        SessionRecord(
          lessonId: 'push_foundations.reps_and_tempo',
          completedAt: DateTime.utc(2026, 8, 4),
          workedSeconds: 60,
          unitsCompleted: 5,
          plannedUnits: 5,
          unitLabel: 'rep',
          lessonClass: 'measurementOnly',
        ),
      );
      // Üç ayrı bozulma sınıfı — hepsi "çözülemedi" sayılmalı.
      await f.writeAsString(
        '{bu json değil\n' // sözdizimi bozuk
        '{"schemaVersion":999,"lessonId":"x"}\n' // bilinmeyen sürüm
        '{"schemaVersion":2}\n', // alanları eksik
        mode: FileMode.append,
      );
      records = await store.recent();
      unreadable = await store.unreadableRecords();
    });

    // Sağlam satır OKUNDU: kayıp, okunabileni götürmüyor.
    expect(records, hasLength(1));
    expect(records.single.unitsCompleted, 5);
    // Ve kayıp ADIYLA sayıldı.
    expect(
      unreadable,
      3,
      reason:
          'Bozuk satırlar sessizce atlanırsa yüzey eksik geçmişi TAM '
          'sayım gibi gösterir.',
    );
  });

  testWidgets('POZİTİF İKİZ: GERÇEK JSONL tamamen sağlamsa kayıp SIFIR', (
    WidgetTester tester,
  ) async {
    // Bu ikiz olmadan üstteki test, sayaç HER ZAMAN 3 dönse de geçerdi.
    late int unreadable;
    await tester.runAsync(() async {
      final File f = File('${tmp.path}/clean.jsonl');
      final JsonlSessionStore store = JsonlSessionStore(f);
      await store.append(
        SessionRecord(
          lessonId: 'push_foundations.reps_and_tempo',
          completedAt: DateTime.utc(2026, 8, 4),
          workedSeconds: 60,
          unitsCompleted: 5,
          plannedUnits: 5,
          unitLabel: 'rep',
          lessonClass: 'measurementOnly',
        ),
      );
      unreadable = await store.unreadableRecords();
    });
    expect(unreadable, 0);
  });

  testWidgets('dosya HİÇ yoksa kayıp 0 — ilk açılış "kayıp geçmiş" DEĞİL', (
    WidgetTester tester,
  ) async {
    late int unreadable;
    late List<SessionRecord> records;
    await tester.runAsync(() async {
      final JsonlSessionStore store = JsonlSessionStore(
        File('${tmp.path}/hicyok.jsonl'),
      );
      records = await store.recent();
      unreadable = await store.unreadableRecords();
    });
    expect(records, isEmpty);
    expect(
      unreadable,
      0,
      reason:
          'İlk açılışta kayıp>0 dönseydi yüzey yeni kullanıcıya '
          '"geçmişinin bir kısmı okunamadı" derdi.',
    );
  });

  testWidgets('GERÇEK içerik kapısı: bozuk bundle → tipli HATA ekranı', (
    WidgetTester tester,
  ) async {
    // ⚠️ Bu testin ilk hâli `_ProbeScreen` adında, yükleme yolunun KOPYASI olan
    // küçük bir widget kullanıyordu — yani ürünün kablolamasını değil kendi
    // taklidini sınıyordu. Aynı "iki ev tutarsızlaşır" riski (G-079). Artık
    // GERÇEK kapı pump ediliyor; mümkün oldu çünkü geçmiş hatası artık
    // ölümcül değil (Gravita deltası): `path_provider` testte yok, ama bu
    // içerik yolunu bloklamıyor.
    //
    // 2026-08-06: dört-sekmeli kabukla birlikte içerik yükleme `ProgressScreen`
    // içinden `GravitaRoot`a taşındı. Test de ürünün YENİ kapısını pump ediyor
    // — eski adı korumak için kabuk-dışı bir yol bırakmak, tam olarak yukarıda
    // sökülen "test-özel ikinci ev"i geri getirirdi.
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: _BrokenBundle(),
          child: const GravitaRoot(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ContentFailureScreen), findsOneWidget);
    expect(
      find.text(ProgressStrings.emptyHistory),
      findsNothing,
      reason: '"Hiç seans yok" ekranı, yükleme hatasının en kötü görünümü.',
    );
    // Asset okunamadı → unreadable sınıfı → retry SUNULUR.
    expect(find.byKey(ContentFailureScreen.retryKey), findsOneWidget);
  });

  testWidgets('POZİTİF İKİZ: GERÇEK bundle ile hata ekranı HİÇ açılmıyor', (
    WidgetTester tester,
  ) async {
    // M-F-194. Üstteki iddia, `ContentFailureScreen` her koşulda çizilseydi de
    // geçerdi; bu ikiz onu kapatıyor. Ayrıca burada geçmiş GERÇEKTEN
    // okunamıyor (testte path_provider yok) ve yüzey bunu BEYAN ediyor —
    // "Not started" demiyor.
    //
    // ⚠️ 2026-08-12 (G-183 / hüküm b) — BU TESTİN KURULUMU DEĞİŞTİ ve sebebi
    // bir ÜRÜN kararıdır, test hilesi değil: eskiden kabuğa `GravitaRoot`un
    // FAIL-OPEN dalıyla varılıyordu (testte `path_provider` yok → onboarding
    // "tamamlanmış" sayılıyordu). O dal artık fail-CLOSED: arızada onboarding
    // GÖSTERİLİYOR. Yani bu test kabuğa ancak onboarding'i GERÇEKTEN
    // tamamlayarak varabilir. Bit ürünün KENDİ yazıcısıyla, gerçek bir
    // dizine kuruluyor.
    //
    // > Bir testin bir yüzeye nasıl ULAŞTIĞI da o testin iddiasının parçasıdır;
    // > ulaşma yolu ürün kararıyla değişince kurulum da değişir.
    // ⚠️ `createTempSync` / `deleteSync` — ve bu ölçüldü, tercih değil:
    // `testWidgets` içinde kaydedilen `addTearDown` geri çağrıları da SAHTE
    // saatli bölgede koşar. İlk yazışımda temizlik `await tmp.delete(...)`
    // idi ve test **asıldı** (süit 25 sn yerine 10 dk sürüp tek kırmızı
    // verdi). Bu dosyanın kendi `tearDown`unun neden `deleteSync` olduğunun
    // da cevabı bu. FakeAsync tuzağının DÖRDÜNCÜ görünüşü.
    final Directory tmp = Directory.systemTemp.createTempSync(
      'shell_e2e_onboarding',
    );
    addTearDown(() => tmp.deleteSync(recursive: true));
    final PathProviderPlatform defaultProvider = PathProviderPlatform.instance;
    addTearDown(() => PathProviderPlatform.instance = defaultProvider);
    await realIo(
      tester,
      () => OnboardingStore.forFile(
        File('${tmp.path}/onboarding.json'),
      ).markComplete(),
    );

    // Kurulumun geri kalanı (FakeAsync/yazı-tipi tuzakları dâhil) ortak
    // harness'ta; burada KOPYALANMIYOR — G-079: iki ev tutarsızlaşır.
    await bootGravitaRoot(
      tester,
      supportPath: tmp.path,
      restoreTo: defaultProvider,
    );

    expect(find.byType(ContentFailureScreen), findsNothing);
    expect(
      find.byType(GravitaShell),
      findsOneWidget,
      reason: 'Onboarding tamamlanmış bir cihazda açılış kabuğa VARIR.',
    );

    // İlerleme sekmesine GEÇ. `IndexedStack` dört sekmeyi de inşa ettiği için
    // "widget ağacında var mı" sorusu bu kabukta ZAYIF bir sorudur — sekmeye
    // gerçekten gidilebildiğini sınamak gerekiyor.
    //
    // ⭐ A7③ (F2, 2026-08-16) düzeltmesi — bu testin ASLINDA ÖLÇTÜĞÜ şey
    // değişti, KENDİ bulgum: `supportPath: tmp.path` burada HER ZAMAN
    // GEÇERLİ bir dizindi (`null` değil) — eski yorum *"path_provider
    // testte yok"* YANLIŞTI. Gerçek sebep `bootGravitaRoot`un kendi
    // zamanlama boşluğuydu (`launch_harness.dart`daki ④ numaralı tuzak):
    // sağlayıcı `pumpWidget`in HEMEN ardından kapanıyordu, eager `IndexedStack`
    // sekmesi ONDAN SONRA kuruluyordu. Harness düzeltildi (sağlayıcı artık
    // yerleşme BİTENE kadar açık) — bu test artık GERÇEKTEN çalışan bir
    // depoya varıyor. Aşağıdaki ikinci pencere (tap sırasında) `Onboarding
    // Store.open()`ın İKİNCİ çağrısı sınıfının (A1/G-229) burada da
    // geçerli olması için.
    PathProviderPlatform.instance = FakeSupportDir(tmp.path);
    await tester.tap(find.text('Progress'));
    await tester.pump();
    for (
      int round = 0;
      round < 20 && find.byType(AppBar).evaluate().isEmpty;
      round++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump(const Duration(milliseconds: 80));
    }
    PathProviderPlatform.instance = defaultProvider;

    expect(find.byKey(ProgressView.measuredSectionKey), findsOneWidget);
    expect(
      find.byKey(ProgressView.historyFailureKey),
      findsNothing,
      reason:
          'Depo GERÇEKTEN çalışıyor (harness düzeltildi) — arıza '
          'BEYANI artık YANLIŞ olurdu.',
    );
    expect(
      find.byKey(ProgressView.historyPartialKey),
      findsNothing,
      reason: 'Hiçbir satır bozuk değil — kısmi BEYANI da yanlış olurdu.',
    );
    // Ölçüldü, varsayılmadı: `open` boş DEĞİL (canlı hareketlerin dersleri
    // var), o yüzden `ProgressStrings.emptyHistory` DEĞİL — her canlı ders
    // kendi satırında `notStarted` gösteriyor (`_measuredRow`, per-ders hâl).
    // İlk denemem `emptyHistory` bekliyordu ve YANLIŞTI; okuyup düzelttim.
    expect(
      find.text(ProgressStrings.notStarted),
      findsWidgets,
      reason:
          'Depo SAĞLAM ama BOŞ: canlı derslerin HER BİRİ "başlanmadı" '
          'demeli — "geçmiş okunamadı" (historyFailureKey) ile "henüz '
          'başlanmadı" FARKLI cümlelerdir, karıştırılmamalı.',
    );
  });

  /// ⭐ A7③ (F2, 2026-08-16) — G-211'in KENDİSİ, kabuktan render edilerek.
  ///
  /// `content_repository.dart:203-210`in kendi notu: G-211'in hükmü
  /// (`readHistoryStatus`, İKİ kovadan da sayar) *"yalnız kabuğu render
  /// ederek sınanabiliyordu ve o yol bugün B5 yüzünden testte KAPALIYDI"* —
  /// F2 B5'i kapattı. Üstteki testin ölçtüğü `HistoryUnavailable`
  /// (path_provider'ın KENDİSİ yok) bu turun sorusu DEĞİL — G-211'in asıl
  /// vakası SERBEST kovanın bozulması, ders kovası SAĞLAMKEN
  /// (`HistoryPartial`). Bu SINIF hiçbir yerde GERÇEK dosyalarla + GERÇEK
  /// render edilmiş kabukla birlikte sınanmamıştı: `free_bucket_
  /// integrity_test.dart` saf `ContentRepository.readHistoryStatus`ı
  /// çağırıyor (kabuk yok), üstteki son iki test `HistoryPartial`ı
  /// (kendi yorumunun dediği gibi) hiç KURMUYOR bile — yalnız `store.
  /// unreadableRecords()`u doğrudan sınıyor, ProgressView'a hiç pump
  /// etmiyor. Kabuğun `_ProgressTabState._load()`ı bu iki kovayı GERÇEKTEN
  /// doğru okuyup `historyPartialKey`i doğru sayıyla çizdiğini kanıtlayan
  /// TEK yer burası.
  testWidgets(
    'GERÇEK kabuk + GERÇEK serbest-kova bozulması → historyPartialKey '
    'DOĞRU sayıyla çiziliyor (G-211, render edilerek)',
    (WidgetTester tester) async {
      final Directory tmp = Directory.systemTemp.createTempSync(
        'shell_e2e_partial',
      );
      addTearDown(() => tmp.deleteSync(recursive: true));
      final PathProviderPlatform defaultProvider =
          PathProviderPlatform.instance;
      addTearDown(() => PathProviderPlatform.instance = defaultProvider);

      await realIo(tester, () async {
        await OnboardingStore.forFile(
          File('${tmp.path}/onboarding.json'),
        ).markComplete();
        // DERS kovası SAĞLAM — G-211'in ayırt ettiği vaka tam bu: yalnız
        // ders kovasına bakan bir denetim burada asla ötmezdi.
        final JsonlSessionStore lessons = JsonlSessionStore(
          File('${tmp.path}/sessions.jsonl'),
        );
        await lessons.append(
          SessionRecord(
            lessonId: 'push_foundations.reps_and_tempo',
            completedAt: DateTime.utc(2026, 8, 10),
            workedSeconds: 60,
            unitsCompleted: 5,
            plannedUnits: 5,
            unitLabel: 'rep',
            lessonClass: 'measurementOnly',
          ),
        );
        // SERBEST kova BOZUK — iki ayrı bozulma sınıfı, ders kovasına hiç
        // dokunulmadı.
        await File('${tmp.path}/free_sessions.jsonl').writeAsString(
          '{bu json değil\n'
          '{"schemaVersion":999,"lessonId":"x"}\n',
        );
      });

      await bootGravitaRoot(
        tester,
        supportPath: tmp.path,
        restoreTo: defaultProvider,
      );
      expect(find.byType(GravitaShell), findsOneWidget);

      // ⭐ Kendi bulgum (A1'de bulunan sınıfın ÜÇÜNCÜ örneği, G-229): kabuk
      // sekmesine geçmek `_ProgressTabState._load()`ı tetikler, o da
      // `ContentRepository.open{Session,FreeSession}Store()` üzerinden
      // path_provider'ı YENİDEN sorar — `bootGravitaRoot` sağlayıcıyı yalnız
      // KENDİ `pumpWidget` penceresinde açık tutuyor. Yeniden açılmazsa bu
      // çağrı gerçek platforma düşer, fırlatır, `readHistoryStatus`ın kendi
      // `on Object catch` yakalayıcısı bunu `HistoryUnavailable`e çevirir —
      // görünüşte "hata ekranı" ama ölçülen şey ürünün DEĞİL testin
      // penceresi. `OnboardingStore.open()`ın iki-çağrı deseni burada da
      // tekrarlandı: bir yardımcının "sağlayıcıyı açık tut" penceresi,
      // ürünün onu KAÇ KEZ sorduğu kadar geniş olmalı.
      // Sabit KÜÇÜK tur sayısı YETMİYOR — ve bu ölçüldü, tahmin edilmedi.
      // `_load()`in zinciri TEK bir gerçek G/Ç değil, SIRALI birden fazlası
      // (destek dizini → ders dosyası → serbest dosya → `readHistoryStatus`ın
      // KENDİ ikinci okuması, sayım için). Tek bir uzun `runAsync` gecikmesi
      // (3 sn TEK blokta denendi) zinciri İLERLETMEDİ — ama `pump()` ARAYA
      // giren, HER biri kısa, ÇOK sayıda `runAsync` turu ilerletti (20×200ms
      // denendi, çalıştı). Fark: her `runAsync` çağrısı test çerçevesine
      // gerçek olay döngüsüyle KISA bir kesişim penceresi açıyor; SIRALI
      // await'ler bu yüzden SIRAYLA, tek turda değil, ilerliyor.
      // > Gerçek G/Ç'yi beklemek "yeterince uzun BEKLEMEK" değil, "yeterince
      // > SIK kesişmek"tir.
      PathProviderPlatform.instance = FakeSupportDir(tmp.path);
      await tester.tap(find.text('Progress'));
      await tester.pump();
      for (
        int round = 0;
        round < 20 && find.byType(AppBar).evaluate().isEmpty;
        round++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump(const Duration(milliseconds: 80));
      }
      PathProviderPlatform.instance = defaultProvider;

      expect(
        find.byKey(ProgressView.historyFailureKey),
        findsNothing,
        reason:
            'Depo ARIZALI değil, İKİ satırı OKUNAMADI — farklı hâl, '
            'karıştırılırsa kullanıcı yanlış mesaj görür.',
      );
      expect(
        find.byKey(ProgressView.historyPartialKey),
        findsOneWidget,
        reason:
            'Kabuk G-211 hükmünü GERÇEKTEN çağırmıyor olabilirdi — bu '
            'satır olmadan pure-Dart testleri hep yeşil kalır, kablolama '
            'kopuk olsa bile.',
      );
      expect(
        find.textContaining('2'),
        findsWidgets,
        reason:
            'Kayıp sayısı (2) ekranda GÖRÜNMELİ, yalnız durumun adı '
            'değil.',
      );
      // Sağlam kayıt OKUNDU: kayıp, okunabileni götürmüyor.
      expect(find.byKey(ProgressView.measuredSectionKey), findsOneWidget);
    },
  );
}

class _BrokenBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw FlutterError('asset missing: $key');
}
