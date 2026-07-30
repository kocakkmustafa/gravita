import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show ByteData, CachingAssetBundle, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/content_repository.dart';
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
        lessonClass: LessonClass.measurementOnly,
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
        lessonClass: LessonClass.measurementOnly,
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

  testWidgets('içerik yüklenmezse BOŞ ilerleme değil HATA gösterilir',
      (WidgetTester tester) async {
    // "Hiç çalışmadın" diyen boş bir ekran, yükleme hatasının en kötü
    // görünümüdür. Kabuk bunu ayırt ediyor mu?
    await tester.pumpWidget(MaterialApp(
      home: DefaultAssetBundle(
        bundle: _BrokenBundle(),
        child: const Scaffold(body: _ProbeScreen()),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load'), findsOneWidget);
    expect(find.text('No sessions yet.'), findsNothing);
  });
}

/// `ProgressScreen`in yükleme yolunu taklit eden en küçük prob: bozuk bundle
/// verildiğinde hata dalını gösterdiğini kanıtlar.
class _ProbeScreen extends StatelessWidget {
  const _ProbeScreen();

  @override
  Widget build(BuildContext context) => FutureBuilder<ContentRepository>(
        future: ContentRepository.load(DefaultAssetBundle.of(context)),
        builder: (BuildContext context,
            AsyncSnapshot<ContentRepository> snapshot) {
          if (snapshot.hasError) {
            return Text('Could not load: ${snapshot.error}');
          }
          return const Text('No sessions yet.');
        },
      );
}

class _BrokenBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw FlutterError('asset missing: $key');
}
