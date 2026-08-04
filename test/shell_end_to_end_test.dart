import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show ByteData, CachingAssetBundle, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/content_failure_screen.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/gravita_app.dart';
import 'package:gravita/app/progress_strings.dart';
import 'package:gravita/app/progress_view.dart';
import 'package:gravita_engine/gravita_engine.dart';

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

  testWidgets('gerçek içerik + gerçek depo + gerçek yüzey birlikte koşuyor',
      (WidgetTester tester) async {
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
      await store.append(SessionRecord(
        lessonId: 'push_foundations.reps_and_tempo',
        completedAt: DateTime.utc(2026, 7, 30, 9),
        workedSeconds: 95,
        unitsCompleted: 6,
        plannedUnits: 8,
        unitLabel: 'rep',
        lessonClass: 'measurementOnly',
        unmeasuredUnits: 1,
        unmeasuredReason: 'framing',
      ));
      await store.append(SessionRecord(
        lessonId: 'push_foundations.reps_and_tempo',
        completedAt: DateTime.utc(2026, 7, 30, 18),
        workedSeconds: 130,
        unitsCompleted: 9,
        plannedUnits: 8,
        unitLabel: 'rep',
        lessonClass: 'measurementOnly',
      ));
      expect(file.readAsLinesSync().length, 2,
          reason: 'Dosyaya GERÇEKTEN yazıldı.');

      // 3) GERÇEK özet.
      summary = ProgressSummary.build(
        lessonSurfaces: content.lessonSurfaces,
        records: await store.recent(),
      );
    });

    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ProgressView(summary: summary))));

    // Ölçümler toplandı: 6 + 9 tekrar, 95 + 130 saniye.
    expect(
        find.descendant(
            of: find.byKey(ProgressView.measuredSectionKey),
            matching: find.text('15 reps')),
        findsOneWidget);
    expect(find.text('3 min 45 s worked'), findsOneWidget);
    expect(find.text('2 sessions'), findsOneWidget);

    // Ölçülemeyen 1 tekrar SAKLANMADI ve gerekçesi göründü.
    expect(find.textContaining('framing'), findsOneWidget);

    // Kilitli form dersi düşmedi ve gerekçesi İÇERİKTEN geldi — bu metni ben
    // yazmadım, `library.json` yazdı.
    final LessonSurface locked = content.lessonSurfaces
        .firstWhere((LessonSurface s) => s.isLocked);
    expect(
        find.descendant(
            of: find.byKey(ProgressView.lockedSectionKey),
            matching: find.text(locked.lockedReason!)),
        findsOneWidget);

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
  testWidgets('GERÇEK JSONL: 1 sağlam + 3 bozuk satır → kayıp SAYILIYOR',
      (WidgetTester tester) async {
    late int unreadable;
    late List<SessionRecord> records;
    await tester.runAsync(() async {
      final File f = File('${tmp.path}/mixed.jsonl');
      final JsonlSessionStore store = JsonlSessionStore(f);
      await store.append(SessionRecord(
        lessonId: 'push_foundations.reps_and_tempo',
        completedAt: DateTime.utc(2026, 8, 4),
        workedSeconds: 60,
        unitsCompleted: 5,
        plannedUnits: 5,
        unitLabel: 'rep',
        lessonClass: 'measurementOnly',
      ));
      // Üç ayrı bozulma sınıfı — hepsi "çözülemedi" sayılmalı.
      await f.writeAsString(
        '{bu json değil\n'                       // sözdizimi bozuk
        '{"schemaVersion":999,"lessonId":"x"}\n' // bilinmeyen sürüm
        '{"schemaVersion":2}\n',                 // alanları eksik
        mode: FileMode.append,
      );
      records = await store.recent();
      unreadable = await store.unreadableRecords();
    });

    // Sağlam satır OKUNDU: kayıp, okunabileni götürmüyor.
    expect(records, hasLength(1));
    expect(records.single.unitsCompleted, 5);
    // Ve kayıp ADIYLA sayıldı.
    expect(unreadable, 3,
        reason: 'Bozuk satırlar sessizce atlanırsa yüzey eksik geçmişi TAM '
            'sayım gibi gösterir.');
  });

  testWidgets('POZİTİF İKİZ: GERÇEK JSONL tamamen sağlamsa kayıp SIFIR',
      (WidgetTester tester) async {
    // Bu ikiz olmadan üstteki test, sayaç HER ZAMAN 3 dönse de geçerdi.
    late int unreadable;
    await tester.runAsync(() async {
      final File f = File('${tmp.path}/clean.jsonl');
      final JsonlSessionStore store = JsonlSessionStore(f);
      await store.append(SessionRecord(
        lessonId: 'push_foundations.reps_and_tempo',
        completedAt: DateTime.utc(2026, 8, 4),
        workedSeconds: 60,
        unitsCompleted: 5,
        plannedUnits: 5,
        unitLabel: 'rep',
        lessonClass: 'measurementOnly',
      ));
      unreadable = await store.unreadableRecords();
    });
    expect(unreadable, 0);
  });

  testWidgets('dosya HİÇ yoksa kayıp 0 — ilk açılış "kayıp geçmiş" DEĞİL',
      (WidgetTester tester) async {
    late int unreadable;
    late List<SessionRecord> records;
    await tester.runAsync(() async {
      final JsonlSessionStore store =
          JsonlSessionStore(File('${tmp.path}/hicyok.jsonl'));
      records = await store.recent();
      unreadable = await store.unreadableRecords();
    });
    expect(records, isEmpty);
    expect(unreadable, 0,
        reason: 'İlk açılışta kayıp>0 dönseydi yüzey yeni kullanıcıya '
            '"geçmişinin bir kısmı okunamadı" derdi.');
  });

  testWidgets('GERÇEK ProgressScreen: bozuk bundle → tipli HATA ekranı',
      (WidgetTester tester) async {
    // ⚠️ Bu testin ilk hâli `_ProbeScreen` adında, yükleme yolunun KOPYASI olan
    // küçük bir widget kullanıyordu — yani ürünün kablolamasını değil kendi
    // taklidini sınıyordu. Aynı "iki ev tutarsızlaşır" riski (G-079). Artık
    // GERÇEK ekran pump ediliyor; mümkün oldu çünkü geçmiş hatası artık
    // ölümcül değil (Gravita deltası): `path_provider` testte yok, ama bu
    // içerik yolunu bloklamıyor.
    await tester.pumpWidget(MaterialApp(
      home: DefaultAssetBundle(
        bundle: _BrokenBundle(),
        child: const ProgressScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(ContentFailureScreen), findsOneWidget);
    expect(find.text(ProgressStrings.emptyHistory), findsNothing,
        reason: '"Hiç seans yok" ekranı, yükleme hatasının en kötü görünümü.');
    // Asset okunamadı → unreadable sınıfı → retry SUNULUR.
    expect(find.byKey(ContentFailureScreen.retryKey), findsOneWidget);
  });

  testWidgets('POZİTİF İKİZ: GERÇEK bundle ile hata ekranı HİÇ açılmıyor',
      (WidgetTester tester) async {
    // M-F-194. Üstteki iddia, `ContentFailureScreen` her koşulda çizilseydi de
    // geçerdi; bu ikiz onu kapatıyor. Ayrıca burada geçmiş GERÇEKTEN
    // okunamıyor (testte path_provider yok) ve yüzey bunu BEYAN ediyor —
    // "Not started" demiyor.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ProgressScreen()));
    // ⚠️ `pumpAndSettle()` BURADA KULLANILAMAZ ve ilk yazışımda timeout verdi:
    // GERÇEK asset okuması gerçek saate bağlı, `testWidgets` gövdesi ise sahte
    // saatli — yükleyici sonsuza kadar dönüyor. FakeAsync tuzağının ÜÇÜNCÜ
    // görünüşü (birincisi depo e2e testi, ikincisi buydu). Widget'ın ARKASINDA
    // gerçek G/Ç varsa: pump → runAsync ile gerçek işi bitir → pump.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(find.byType(ContentFailureScreen), findsNothing);
    expect(find.byKey(ProgressView.measuredSectionKey), findsOneWidget);
    expect(find.byKey(ProgressView.historyFailureKey), findsOneWidget,
        reason: 'path_provider testte yok → geçmiş okunamadı → BEYAN edilmeli.');
    expect(find.text(ProgressStrings.notStarted), findsNothing);
  });
}

class _BrokenBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw FlutterError('asset missing: $key');
}
