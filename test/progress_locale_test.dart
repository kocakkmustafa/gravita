import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/content_failure.dart';
import 'package:gravita/app/content_failure_screen.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/progress_view.dart';
import 'package:gravita/app/theme.dart';
import 'package:gravita_engine/gravita_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentRepository content;
  setUp(() async => content = await ContentRepository.load(rootBundle));

  const reps = LessonSurface(
    id: 'push_foundations.reps_and_tempo',
    displayName: 'Reps that count',
    movementName: 'Push-Up',
    unitLabel: 'rep',
    gradedToday: false,
  );
  const hold = LessonSurface(
    id: 'synthetic.hold',
    displayName: 'Synthetic hold',
    movementName: 'Synthetic movement',
    unitLabel: 'second',
    gradedToday: false,
  );
  SessionRecord record({
    String lessonId = 'push_foundations.reps_and_tempo',
    String unit = 'rep',
    int units = 5,
    int unmeasured = 0,
    String? reason,
  }) => SessionRecord(
    lessonId: lessonId,
    completedAt: DateTime.utc(2026, 10, 16),
    workedSeconds: 95,
    unitsCompleted: units,
    plannedUnits: units + unmeasured,
    unitLabel: unit,
    lessonClass: 'measurementOnly',
    unmeasuredUnits: unmeasured,
    unmeasuredReason: reason,
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    String language = 'tr',
  }) async {
    tester.view.physicalSize = const Size(320, 8000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: GravitaTheme.light,
        locale: Locale(language),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('real four-lesson TR progress keeps named measurement locks', (
    tester,
  ) async {
    await pump(
      tester,
      ProgressView(
        summary: ProgressSummary.build(
          lessonSurfaces: content.lessonSurfaces,
          records: const [],
        ),
      ),
    );
    expect(find.text('Ölçülenler'), findsOneWidget);
    expect(find.text('Başlanmadı'), findsNWidgets(2));
    expect(find.text('Sayılan tekrarlar'), findsNWidgets(2));
    expect(find.text('Derinlik ve eğim kontrolü'), findsOneWidget);
    expect(find.text('Gövde çizgisi kontrolü'), findsOneWidget);
    expect(find.text('ŞINAV'), findsNWidgets(2));
    expect(find.textContaining('diz, kaval ve gövde'), findsOneWidget);
    expect(
      find.textContaining('dokuz eklem toleransının hiçbiri'),
      findsOneWidget,
    );
    expect(
      find.textContaining('canlı kamera oturumları kullanılamıyor'),
      findsWidgets,
    );
    expect(find.textContaining('stays open'), findsNothing);
    expect(find.text('LOCKED'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'TR partial history shows measured units and unmeasured work separately',
    (tester) async {
      await pump(
        tester,
        ProgressView(
          summary: ProgressSummary.build(
            lessonSurfaces: const [reps, hold],
            records: [
              record(unmeasured: 2, reason: 'framing'),
              record(lessonId: hold.id, unit: 'second', units: 45),
            ],
          ),
          historyStatus: const HistoryPartial(2),
        ),
      );
      expect(find.text('5 tekrar'), findsOneWidget);
      expect(find.text('45 saniye'), findsOneWidget);
      expect(find.text('1 dk 35 sn çalışma'), findsNWidgets(2));
      expect(find.textContaining('2 kayıtlı oturum okunamadı'), findsOneWidget);
      expect(
        find.textContaining('2 tekrar ölçülemedi (kadraj)'),
        findsOneWidget,
      );
      expect(find.textContaining('İlerlemen azalmaz.'), findsOneWidget);
      expect(find.text('1 oturum sayıldı, puanlanmadı.'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unknown unit and changed lesson source remain visible', (
    tester,
  ) async {
    const changed = LessonSurface(
      id: 'push_foundations.reps_and_tempo',
      displayName: 'Revised source title',
      movementName: 'Revised source movement',
      unitLabel: 'future_unit',
      gradedToday: false,
      lockedReason: 'Revised measurement contract',
    );
    await pump(
      tester,
      ProgressView(
        summary: ProgressSummary.build(
          lessonSurfaces: const [changed],
          records: [record(unit: 'future_unit')],
        ),
      ),
    );
    expect(find.text('Revised source title'), findsOneWidget);
    expect(find.text('REVISED SOURCE MOVEMENT'), findsOneWidget);
    expect(find.text('Revised measurement contract'), findsOneWidget);
    expect(find.text('5 future_unit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'TR unavailable history suppresses invented counts and preserves installation',
    (tester) async {
      await pump(
        tester,
        ProgressView(
          summary: ProgressSummary.build(
            lessonSurfaces: const [reps],
            records: [record()],
          ),
          historyStatus: const HistoryUnavailable('synthetic read failure'),
        ),
      );
      expect(
        find.textContaining('Yerel geçmişi korumak için uygulamayı yüklü tut.'),
        findsOneWidget,
      );
      expect(find.text('5 tekrar'), findsNothing);
      expect(find.text('Başlanmadı'), findsNothing);
      expect(find.textContaining('yeniden kur'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TR notes retain retroactive, locked-history and orphan boundaries',
    (tester) async {
      const gradedLater = LessonSurface(
        id: 'later.graded',
        displayName: 'Later grading',
        movementName: 'Synthetic',
        unitLabel: 'rep',
        gradedToday: true,
      );
      final locked = content.lessonSurfaces.firstWhere((l) => l.isLocked);
      await pump(
        tester,
        ProgressView(
          summary: ProgressSummary.build(
            lessonSurfaces: [gradedLater, locked],
            records: [
              record(
                lessonId: gradedLater.id,
                unmeasured: 2,
                reason: 'future_reason',
              ),
              record(lessonId: locked.id),
              record(lessonId: 'retired.lesson'),
            ],
          ),
        ),
      );
      expect(find.textContaining('geriye dönük puanlamayız'), findsOneWidget);
      expect(
        find.textContaining('Çalışmanı sakladık; ölçümü geri çektik.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('eşleşmeyen 1 derse ait geçmiş var.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('2 tekrar ölçülemedi (future_reason)'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'tr']) {
    testWidgets(
      '$language unavailable read hides locked, free and orphan totals too',
      (tester) async {
        final locked = content.lessonSurfaces.firstWhere((l) => l.isLocked);
        await pump(
          tester,
          ProgressView(
            summary: ProgressSummary.build(
              lessonSurfaces: [reps, locked],
              records: [
                record(),
                record(lessonId: locked.id, units: 9),
                record(lessonId: 'retired.lesson'),
              ],
            ),
            freeSessions: [record(units: 7)],
            historyStatus: const HistoryUnavailable(
              'read counts failed after recent()',
            ),
          ),
          language: language,
        );
        expect(find.byKey(ProgressView.lockedSectionKey), findsOneWidget);
        expect(find.byKey(ProgressView.historyFailureKey), findsOneWidget);
        expect(find.byKey(ProgressView.freeSectionKey), findsNothing);
        expect(find.byKey(ProgressView.notesSectionKey), findsNothing);
        expect(
          find.text(language == 'tr' ? '9 tekrar' : '9 reps'),
          findsNothing,
        );
        expect(
          find.text(language == 'tr' ? '1 oturum' : '1 session'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$language free sessions never add seconds to repetitions', (
      tester,
    ) async {
      await pump(
        tester,
        ProgressView(
          summary: ProgressSummary.build(
            lessonSurfaces: const [],
            records: const [],
          ),
          freeSessions: [
            record(units: 3),
            record(unit: 'second', units: 45),
            record(unit: 'future_unit', units: 2),
          ],
        ),
        language: language,
      );
      expect(
        find.text(
          language == 'tr'
              ? '3 oturum · 3 tekrar · 45 saniye · 2 future_unit sayıldı'
              : '3 sessions · 3 reps · 45 seconds · 2 future_unit counted',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('50 reps'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'TR read failure retries and exposes raw diagnostic without reinstall advice',
    (tester) async {
      var retries = 0;
      await pump(
        tester,
        ContentFailureScreen(
          failure: const ContentFailure(
            kind: ContentFailureKind.unreadable,
            detail: 'raw: missing asset',
          ),
          onRetry: () async {
            retries++;
          },
        ),
      );
      expect(find.text('Uygulama içeriğini okuyamadık'), findsOneWidget);
      expect(
        find.textContaining('Yerel geçmişi korumak için uygulamayı yüklü tut.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Yeniden dene'));
      expect(retries, 1);
      await tester.tap(find.text('Teknik ayrıntı'));
      await tester.pumpAndSettle();
      expect(find.text('raw: missing asset'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('TR integrity failure stays blocked without retry', (
    tester,
  ) async {
    await pump(
      tester,
      ContentFailureScreen(
        failure: const ContentFailure(
          kind: ContentFailureKind.integrity,
          detail: '',
        ),
        onRetry: () async {},
      ),
    );
    expect(find.text('İçeriği göstermeyi durdurduk'), findsOneWidget);
    expect(find.byKey(ContentFailureScreen.retryKey), findsNothing);
    await tester.tap(find.text('Teknik ayrıntı'));
    await tester.pumpAndSettle();
    expect(find.text('(ayrıntı bildirilmedi)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
