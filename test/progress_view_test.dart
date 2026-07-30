import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/progress_strings.dart';
import 'package:gravita/app/progress_view.dart';
import 'package:gravita_engine/gravita_engine.dart';

/// İlerleme yüzeyinin YAPI testleri (M-F-168 orta yol).
///
/// Her test bir metnin HANGİ BÖLÜMDE göründüğünü iddia ediyor, "bir yerde var
/// mı"yı değil: iki bölüm birleştirilse "bir yerde var" testi GEÇERDİ ve
/// kilitli dersin gerekçesi ölçüm satırlarının arasına karışmış olurdu.
///
/// ⚠️ Burada GÖRSEL bir şey kanıtlanmıyor — kanıtlanan şey YAPIdır. (Kabuğun
/// gerçekten koştuğu ayrıca simülatörde doğrulandı, G-100; ama "güzel görünüyor"
/// hiçbir testin iddiası değil. Görünüm tasarım turunun işi.)
///
/// Son iki test SİMÜLATÖR TURUNDAN SONRA eklendi: ekranda ders adı yerine
/// kimlik yazıyordu ve boş bir "Notes" başlığı duruyordu; 16 test yeşildi.
/// Kod düzeltmesi tek başına yetmez — nöbetçisi olmayan düzeltme geri gelir.
void main() {
  const LessonSurface reps = LessonSurface(
    id: 'push_foundations.reps_and_tempo',
    displayName: 'Reps that count',
    unitLabel: 'rep',
    gradedToday: false,
  );
  const LessonSurface plank = LessonSurface(
    id: 'hold_foundations.plank',
    displayName: 'Plank',
    unitLabel: 'second',
    gradedToday: false,
  );
  const LessonSurface formLocked = LessonSurface(
    id: 'push_foundations.form_check',
    displayName: 'Body-line check',
    unitLabel: 'rep',
    gradedToday: false,
    lockedReason: 'Nine joint tolerances still sit at our default floor.',
  );

  SessionRecord rec({
    required String lessonId,
    String unit = 'rep',
    int worked = 120,
    int done = 5,
    int unmeasured = 0,
    String? reason,
    LessonClass lessonClass = LessonClass.measurementOnly,
  }) =>
      SessionRecord(
        lessonId: lessonId,
        completedAt: DateTime.utc(2026, 7, 30),
        workedSeconds: worked,
        unitsCompleted: done,
        plannedUnits: 8,
        unitLabel: unit,
        lessonClass: lessonClass,
        unmeasuredUnits: unmeasured,
        unmeasuredReason: reason,
      );

  Future<void> pump(WidgetTester tester, ProgressSummary summary) async {
    // Yüksek yüzey: ListView tembel kurar, ekran dışı satır İNŞA EDİLMEZ ve
    // test "yok" der. Görünürlük testi yapmıyoruz, YAPI testi yapıyoruz.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ProgressView(summary: summary))));
  }

  Finder inSection(Key section, String text) => find.descendant(
      of: find.byKey(section), matching: find.text(text), matchRoot: false);

  testWidgets('ilk açılış: ölçüm bölümü BOŞ DEĞİL — başlanmamış ders görünüyor',
      (WidgetTester tester) async {
    await pump(
      tester,
      ProgressSummary.build(
        lessonSurfaces: const <LessonSurface>[reps],
        records: const <SessionRecord>[],
      ),
    );
    expect(inSection(ProgressView.measuredSectionKey, reps.displayName),
        findsOneWidget);
    expect(inSection(ProgressView.measuredSectionKey, ProgressStrings.notStarted),
        findsOneWidget);
  });

  testWidgets('kilitli dersin GEREKÇESİ kilit bölümünde, ölçüm bölümünde DEĞİL',
      (WidgetTester tester) async {
    await pump(
      tester,
      ProgressSummary.build(
        lessonSurfaces: const <LessonSurface>[reps, formLocked],
        records: <SessionRecord>[rec(lessonId: reps.id)],
      ),
    );
    // Kilitli ders yüzeyden DÜŞMEDİ...
    expect(inSection(ProgressView.lockedSectionKey, formLocked.displayName),
        findsOneWidget);
    // ...gerekçesi İÇERİKTEN aynen geldi...
    expect(inSection(ProgressView.lockedSectionKey, formLocked.lockedReason!),
        findsOneWidget);
    // ...ve ölçüm bölümüne KARIŞMADI.
    expect(inSection(ProgressView.measuredSectionKey, formLocked.displayName),
        findsNothing);
  });

  testWidgets('SAYI asla birimsiz çıkmıyor; plank SANİYE, şınav TEKRAR diyor',
      (WidgetTester tester) async {
    await pump(
      tester,
      ProgressSummary.build(
        lessonSurfaces: const <LessonSurface>[reps, plank],
        records: <SessionRecord>[
          rec(lessonId: reps.id, done: 5),
          rec(lessonId: plank.id, unit: 'second', done: 45, worked: 45),
        ],
      ),
    );
    // Delta 1'in ekranda GÖRÜNEN karşılığı: aynı ekran, iki farklı birim.
    expect(find.text('5 reps'), findsOneWidget);
    expect(find.text('45 seconds'), findsOneWidget);
    // Çıplak sayı yok — birim metnin İÇİNDE.
    expect(find.text('5'), findsNothing);
    expect(find.text('45'), findsNothing);
  });

  testWidgets('ölçülemeyen iş görünüyor ve "ilerleme düşmez" diyor',
      (WidgetTester tester) async {
    await pump(
      tester,
      ProgressSummary.build(
        lessonSurfaces: const <LessonSurface>[reps],
        records: <SessionRecord>[
          rec(lessonId: reps.id, done: 4, unmeasured: 2, reason: 'framing'),
        ],
      ),
    );
    final Finder note = inSection(
        ProgressView.measuredSectionKey,
        ProgressStrings.unmeasured(2, 'rep', const <String>['framing']));
    expect(note, findsOneWidget);
    expect(
      (tester.widget<Text>(note).data)!,
      allOf(contains('framing'), contains("progress doesn't drop")),
    );
  });

  testWidgets('retroaktif kredi reddi NOTLAR bölümünde ve sayıyı söylüyor',
      (WidgetTester tester) async {
    const LessonSurface promoted = LessonSurface(
      id: 'push_foundations.form_check',
      displayName: 'Body-line check',
      unitLabel: 'rep',
      gradedToday: true,
    );
    await pump(
      tester,
      ProgressSummary.build(
        lessonSurfaces: const <LessonSurface>[promoted],
        records: <SessionRecord>[
          rec(lessonId: promoted.id),
          rec(lessonId: promoted.id, lessonClass: LessonClass.scored),
        ],
      ),
    );
    expect(
        inSection(ProgressView.notesSectionKey,
            ProgressStrings.retroactiveWithheld(1)),
        findsOneWidget);
    // Satırın kendisi de "sayıldı, notlanmadı" diyor — not YOKLUĞU açık cümle.
    expect(
        inSection(ProgressView.measuredSectionKey,
            ProgressStrings.measurementOnly(1)),
        findsOneWidget);
  });

  testWidgets('kilit altındaki geçmiş GİZLENMİYOR — uyarı + sayılar görünüyor',
      (WidgetTester tester) async {
    await pump(
      tester,
      ProgressSummary.build(
        lessonSurfaces: const <LessonSurface>[formLocked],
        records: <SessionRecord>[rec(lessonId: formLocked.id, done: 7)],
      ),
    );
    expect(
        inSection(
            ProgressView.notesSectionKey, ProgressStrings.historyUnderLock),
        findsOneWidget);
    expect(inSection(ProgressView.lockedSectionKey, '7 reps'), findsOneWidget);
  });

  testWidgets('yetim kayıt NOTLAR bölümünde sayısıyla söyleniyor',
      (WidgetTester tester) async {
    await pump(
      tester,
      ProgressSummary.build(
        lessonSurfaces: const <LessonSurface>[reps],
        records: <SessionRecord>[
          rec(lessonId: reps.id),
          rec(lessonId: 'old_course.removed_lesson'),
        ],
      ),
    );
    expect(
        inSection(
            ProgressView.notesSectionKey, ProgressStrings.orphanRecords(1)),
        findsOneWidget);
  });

  testWidgets('yüzeyde SAYISAL HÜKÜM yok (skor/yüzde/derece değeri)',
      (WidgetTester tester) async {
    // `ProgressSummary`'nin anahtar-kümesi nöbeti VERİ tarafını tutuyor; bu
    // KABUK tarafını tutuyor: "Score: 82", "Form 91%", "Rating 4/5" sızarsa
    // test düşer.
    //
    // ⚠️ İlk hâli SÖZCÜK yasaklıyordu (`score`, `rating`, …) ve **kendi dürüst
    // altbaşlığımda ateşledi**: *"What we counted. Not a score."* Kapı, bir
    // hükmü İDDİA eden cümleyle onu İNKAR eden cümleyi ayırt edemiyordu — kaba
    // metin taramasının bilinen sınırının küçük ve somut bir örneği (aile
    // dersi: metin taramalı kapı "yazma deneniyor mu"yu ölçer, ANLAMI ölçmez).
    // Düzeltme: yasak sözcük değil, **hüküm-sözcüğü + SAYI** deseni. "Not a
    // score" geçer, "Score: 82" geçmez.
    await pump(
      tester,
      ProgressSummary.build(
        lessonSurfaces: const <LessonSurface>[reps, formLocked],
        records: <SessionRecord>[rec(lessonId: reps.id)],
      ),
    );
    final RegExp judgementValue = RegExp(
        r'\b(score|grade|rating|streak|level|band)\b[^.!?]{0,15}?\d|\d\s*%|\d\s*/\s*\d\s*(stars?|points?)',
        caseSensitive: false);
    for (final Text t in tester.widgetList<Text>(find.byType(Text))) {
      final String s = t.data ?? '';
      expect(judgementValue.hasMatch(s), isFalse,
          reason: 'Yüzeye SAYISAL HÜKÜM girdi: "$s". Gravita ölçtüğünü '
              'gösterir, not vermez (M-F-168).');
    }
  });

  testWidgets('kullanıcıya DERS KİMLİĞİ gösterilmiyor — ad gösteriliyor',
      (WidgetTester tester) async {
    // Simülatör turunun birinci bulgusu. Nöbet: hiçbir metin, noktalı
    // snake_case kimlik desenine UYMASIN. `lessonId` yalnız [Key]'de yaşar.
    await pump(
      tester,
      ProgressSummary.build(
        lessonSurfaces: const <LessonSurface>[reps, formLocked],
        records: <SessionRecord>[rec(lessonId: reps.id)],
      ),
    );
    final RegExp looksLikeId = RegExp(r'^[a-z0-9_]+\.[a-z0-9_]+$');
    for (final Text t in tester.widgetList<Text>(find.byType(Text))) {
      expect(looksLikeId.hasMatch(t.data ?? ''), isFalse,
          reason: 'Ekranda İÇ KİMLİK var: "${t.data}". Kullanıcı '
              'displayName görmeli.');
    }
    expect(find.text(reps.displayName), findsOneWidget);
  });

  testWidgets('söylenecek not yoksa BOŞ "Notes" başlığı çizilmiyor',
      (WidgetTester tester) async {
    // Simülatör turunun ikinci bulgusu: başlık bir SÖZ verir; altı boşsa
    // tutulmamış bir söz olur.
    await pump(
      tester,
      ProgressSummary.build(
        lessonSurfaces: const <LessonSurface>[reps],
        records: <SessionRecord>[rec(lessonId: reps.id)],
      ),
    );
    expect(find.byKey(ProgressView.notesSectionKey), findsNothing);
    expect(find.text(ProgressStrings.notesSection), findsNothing);
  });
}