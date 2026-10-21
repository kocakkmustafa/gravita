import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_store_epoch.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/calisthenics_course.dart';
import 'package:gravita/app/calisthenics_course_screen.dart';
import 'package:gravita/app/calisthenics_progress.dart';
import 'package:gravita/app/localization/locale_delegate.dart';
import 'support/locale_asset_harness.dart';

const _areas = ['barbell', 'rings', 'hands'];
const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';

CalisthenicsCourse _course(String area, {bool legacy = false}) =>
    CalisthenicsCourse.parse(
      File(
        legacy
            ? 'test/fixtures/foundations_v1/$area-foundations.v1.json'
            : 'content/courses/$area-foundations.v1.json',
      ).readAsStringSync(),
    );

Future<void> _reveal(WidgetTester t, Finder target) async {
  final scrollable = find
      .descendant(
        of: find.byKey(const Key('calisthenics.lesson.body')),
        matching: find.byType(Scrollable),
      )
      .first;
  expect(scrollable, findsOneWidget);
  // A previous target may be below a lazily disposed target. Start an absent
  // target's bounded scan from the top; ensureVisible handles mounted targets.
  if (target.evaluate().isEmpty) {
    final position = t.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.minScrollExtent);
    await t.pump();
  }
  await t.scrollUntilVisible(
    target,
    320,
    scrollable: scrollable,
    maxScrolls: 220,
  );
  await t.ensureVisible(target);
  await t.pump();
  expect(target.hitTestable(), findsOneWidget);
}

Future<void> _waitReaderUntil(
  WidgetTester t,
  bool Function() ready, {
  required String stage,
}) async {
  // Preserve the former 10x150ms real budget without limiting serial file IO
  // to ten pump boundaries. Stopwatch is real time even inside FakeAsync.
  final watch = Stopwatch()..start();
  var turns = 0;
  while (!ready() && watch.elapsedMilliseconds < 1500 && turns < 4096) {
    await t.runAsync<void>(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await t.pump(const Duration(milliseconds: 80));
    turns++;
  }
  final reached = ready();
  debugPrint(
    'reader-wait $stage: ready=$reached turns=$turns '
    'wallMs=${watch.elapsedMilliseconds}',
  );
  expect(
    reached,
    isTrue,
    reason: 'Reader readiness was false at the 1500ms deadline: $stage',
  );
}

Future<T> _driveReaderIo<T>(
  WidgetTester t,
  Future<T> Function() operation, {
  required String stage,
}) async {
  var completed = false;
  late T result;
  Object? failure;
  StackTrace? failureStack;
  debugPrint('reader-io START: $stage');
  // Start and observe in the fake zone. A real-zone await of a queue's fake
  // predecessor prevents runAsync from returning so that fake pumps can resume.
  final observed = operation().then<void>(
    (value) {
      result = value;
      completed = true;
    },
    onError: (Object error, StackTrace stack) {
      failure = error;
      failureStack = stack;
      completed = true;
    },
  );
  await _waitReaderUntil(t, () => completed, stage: stage);
  expect(
    completed,
    isTrue,
    reason: 'Reader IO did not complete within the bounded turns: $stage',
  );
  await observed;
  final error = failure;
  if (error != null) Error.throwWithStackTrace(error, failureStack!);
  debugPrint('reader-io END: $stage');
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(warmActualLocaleAssets);

  for (final area in _areas) {
    final course = _course(area);
    final legacy = _course(area, legacy: true);
    final physical = course.lessons.firstWhere(
      (lesson) => !lesson.learningOnly,
    );

    test(
      '$area 1.1 original sequence opens beginner options and fails closed',
      () {
        expect(course.version, '1.1.0');
        expect(course.isFoundationCourse, isTrue);
        expect(course.reviewRequired, isFalse);
        expect(course.lessons, hasLength(12));
        expect(
          course.lessons.where((lesson) => !lesson.learningOnly),
          hasLength(8),
        );
        expect(course.lessons.where(course.practiceHeld), isEmpty);
        expect(legacy.version, '1.0.0');
        expect(legacy.lessons.where(legacy.practiceHeld), hasLength(8));
        for (final lesson in course.lessons) {
          expect(lesson.steps.length, inInclusiveRange(3, 5));
          expect(lesson.practice.en.trim(), isNotEmpty);
          expect(lesson.stop.en.trim(), isNotEmpty);
          expect(lesson.progression, isNotNull);
          expect(lesson.regression, isNotNull);
          expect(lesson.rest, isNotNull);
        }
        final raw = File(
          'content/courses/$area-foundations.v1.json',
        ).readAsStringSync();
        for (final mutate in <void Function(Map<String, dynamic>)>[
          (v) => v['reviewStatus'] = 'expert_approved',
          (v) => v['version'] = '1.2.0',
          (v) =>
              v['modules'][0]['lessons'][2].remove('candidatePracticeAccess'),
          (v) => v['modules'][0]['lessons'][2]['candidatePracticeAccess'] =
              'unrestricted',
          (v) => v['modules'][0]['lessons'][2]['candidatePracticeAccess'] =
              'learning_only',
        ]) {
          final changed = jsonDecode(raw) as Map<String, dynamic>;
          mutate(changed);
          expect(
            () => CalisthenicsCourse.parse(jsonEncode(changed)),
            throwsFormatException,
          );
        }
      },
    );

    test(
      '$area revision store preserves1.0 bytes and requires two self reports',
      () async {
        final root = Directory.systemTemp.createTempSync('gravita-revision-');
        try {
          final old = calisthenicsProgressStoreFor(
            root,
            null,
            courseId: course.id,
          );
          await old.markPractised(legacy, legacy.lessons.first);
          await old.markCompleted(
            legacy,
            legacy.lessons.first,
            selfChecksConfirmed: true,
          );
          final oldBytes = old.file.readAsBytesSync();
          final current = calisthenicsProgressStoreFor(
            root,
            null,
            courseId: course.id,
            courseVersion: course.version,
          );
          expect(current.file.path, isNot(old.file.path));
          expect(current.file.existsSync(), isFalse);
          await expectLater(old.markSeen(course, physical), throwsStateError);
          expect(old.file.readAsBytesSync(), oldBytes);
          await current.markSeen(course, physical);
          await current.markPractised(course, physical);
          await expectLater(
            current.markCompleted(course, physical, selfChecksConfirmed: true),
            throwsStateError,
          );
          expect(
            () => current.markCompleted(
              course,
              physical,
              selfChecksConfirmed: false,
            ),
            throwsStateError,
          );
          await current.markPractised(course, physical);
          await current.markCompleted(
            course,
            physical,
            selfChecksConfirmed: true,
          );
          final reopened = calisthenicsProgressStoreFor(
            root,
            null,
            courseId: course.id,
            courseVersion: course.version,
          );
          final result = await reopened.load();
          expect(result.forLesson(physical, course.version)?.practiceCount, 2);
          expect(
            result.forLesson(physical, course.version)?.state,
            CalisthenicsLessonState.selfReportedComplete,
          );
          expect(result.completedCount(course), 1);
          expect(old.file.readAsBytesSync(), oldBytes);
          expect((await old.load()).completedCount(legacy), 1);
          expect(
            (await calisthenicsProgressStoreFor(
              root,
              _ownerA,
              courseId: course.id,
              courseVersion: course.version,
            ).load()).records,
            isEmpty,
          );
          final another = _course(
            _areas.firstWhere((candidate) => candidate != area),
          );
          expect(
            (await calisthenicsProgressStoreFor(
              root,
              null,
              courseId: another.id,
              courseVersion: another.version,
            ).load()).records,
            isEmpty,
          );
          expect(
            () => calisthenicsProgressStoreFor(
              root,
              null,
              courseId: course.id,
              courseVersion: '1.2.0',
            ),
            throwsArgumentError,
          );
        } finally {
          await AccountStoreEpochRegistry.resetForTest();
          root.deleteSync(recursive: true);
        }
      },
    );

    test(
      '$area corrupt revision and retired owner cannot rewrite history',
      () async {
        final root = Directory.systemTemp.createTempSync(
          'gravita-revision-owner-',
        );
        try {
          await AccountStoreEpochRegistry.enableManagedAdmission();
          final epoch = AccountStoreEpochRegistry.activate(_ownerA);
          final store = calisthenicsProgressStoreFor(
            root,
            _ownerA,
            epoch: epoch,
            courseId: course.id,
            courseVersion: course.version,
          );
          await store.markSeen(course, physical);
          final beforeRetire = store.file.readAsBytesSync();
          await epoch.retireAndDrain();
          await expectLater(
            store.markPractised(course, physical),
            throwsStateError,
          );
          expect(store.file.readAsBytesSync(), beforeRetire);
          AccountStoreEpochRegistry.activate(_ownerB);
          final other = calisthenicsProgressStoreFor(
            root,
            _ownerB,
            courseId: course.id,
            courseVersion: course.version,
          );
          expect((await other.load()).records, isEmpty);
          AccountStoreEpochRegistry.activate(_ownerA);
          final fresh = calisthenicsProgressStoreFor(
            root,
            _ownerA,
            courseId: course.id,
            courseVersion: course.version,
          );
          final changed =
              jsonDecode(fresh.file.readAsStringSync()) as Map<String, dynamic>;
          changed['lessons'][physical.id]['contentVersion'] = '1.0.0';
          fresh.file.writeAsStringSync(jsonEncode(changed));
          final corruptedBytes = fresh.file.readAsBytesSync();
          await expectLater(fresh.load(), throwsFormatException);
          await expectLater(
            fresh.markPractised(course, physical),
            throwsFormatException,
          );
          expect(fresh.file.readAsBytesSync(), corruptedBytes);
          expect(File('${fresh.file.path}.tmp').existsSync(), isFalse);
        } finally {
          await AccountStoreEpochRegistry.resetForTest();
          root.deleteSync(recursive: true);
        }
      },
    );

    for (final dark in [false, true]) {
      final lang = dark ? 'tr' : 'en';
      testWidgets(
        '${area}1.1 $lang ${dark ? 'dark' : 'light'}320px2x two visits and completion',
        (t) async {
          final root = Directory.systemTemp.createTempSync(
            'gravita-release-reader-',
          );
          t.view.physicalSize = const Size(320, 900);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final store = calisthenicsProgressStoreFor(
            root,
            null,
            courseId: course.id,
            courseVersion: course.version,
          );
          try {
            for (var visit = 0; visit < 2; visit++) {
              await t.pumpWidget(
                MaterialApp(
                  key: ValueKey('$area-$visit'),
                  locale: Locale(lang),
                  supportedLocales: appSupportedLocales,
                  localizationsDelegates: appLocalizationsDelegates,
                  theme: ThemeData(
                    brightness: dark ? Brightness.dark : Brightness.light,
                  ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(2)),
                    child: child!,
                  ),
                  home: CalisthenicsLessonScreen(
                    course: course,
                    lesson: physical,
                    storeLoader: (_) async => store,
                  ),
                ),
              );
              await pumpActualLocaleReady(t);
              final count = find.byKey(const Key('calisthenics.practiceCount'));
              await _reveal(t, count);
              await _waitReaderUntil(
                t,
                () =>
                    count.evaluate().isNotEmpty &&
                    t.widget<Text>(count).data!.endsWith('$visit'),
                stage: '$area $lang visit $visit initial count',
              );
              expect(t.widget<Text>(count).data!.endsWith('$visit'), isTrue);
              final prepared = find.byKey(const Key('calisthenics.prepared'));
              await _reveal(t, prepared);
              expect(t.widget<CheckboxListTile>(prepared).value, isFalse);
              await t.tap(prepared.hitTestable());
              await t.pump();
              final practice = find.byKey(const Key('calisthenics.practised'));
              await _reveal(t, practice);
              await _waitReaderUntil(
                t,
                () => t.widget<OutlinedButton>(practice).onPressed != null,
                stage: '$area $lang visit $visit practice admission',
              );
              expect(t.widget<OutlinedButton>(practice).onPressed, isNotNull);
              await t.tap(practice.hitTestable());
              await _waitReaderUntil(
                t,
                () => t.widget<Text>(count).data!.endsWith('${visit + 1}'),
                stage: '$area $lang visit $visit practice report saved',
              );
              expect(
                t.widget<Text>(count).data!.endsWith('${visit + 1}'),
                isTrue,
              );
              expect(
                t.widget<OutlinedButton>(practice).onPressed,
                isNull,
                reason: 'Only one report per reader visit',
              );
              final confirmation = find.byKey(
                const Key('calisthenics.confirm'),
              );
              await _reveal(t, confirmation);
              await t.tap(confirmation.hitTestable());
              await t.pump();
              final complete = find.byKey(const Key('calisthenics.complete'));
              await _reveal(t, complete);
              expect(
                t.widget<FilledButton>(complete).onPressed,
                visit == 0 ? isNull : isNotNull,
              );
              if (visit == 1) {
                await t.tap(complete.hitTestable());
                await t.pump();
                await _waitReaderUntil(
                  t,
                  () =>
                      t.widget<CheckboxListTile>(confirmation).onChanged !=
                      null,
                  stage: '$area $lang completion saved',
                );
                expect(
                  t.widget<CheckboxListTile>(confirmation).onChanged,
                  isNotNull,
                );
              }
              expect(t.takeException(), isNull);
              await t.pumpWidget(const SizedBox.shrink());
              await t.pump();
            }
            final saved = await _driveReaderIo(
              t,
              store.load,
              stage: '$area $lang saved two-visit history',
            );
            expect(saved.forLesson(physical, course.version)?.practiceCount, 2);
            expect(
              saved.forLesson(physical, course.version)?.state,
              CalisthenicsLessonState.selfReportedComplete,
            );
          } finally {
            await t.pumpWidget(const SizedBox.shrink());
            await t.pump();
            await _driveReaderIo(
              t,
              AccountStoreEpochRegistry.resetForTest,
              stage: '$area $lang reader registry reset',
            );
            root.deleteSync(recursive: true);
          }
        },
      );
    }
  }

  testWidgets('1.1 actual lesson resources cover14 locales and RTL', (t) async {
    final course = CalisthenicsCourse.parse(
      File('content/courses/calisthenics.v1.json').readAsStringSync(),
    );
    final lesson = course.lessons.singleWhere((item) => item.id == 'cal-52');
    final root = Directory.systemTemp.createTempSync(
      'gravita-release-locales-',
    );
    final store = calisthenicsProgressStoreFor(
      root,
      null,
      courseId: course.id,
      courseVersion: course.version,
    );
    try {
      for (final locale in appSupportedLocales) {
        await t.pumpWidget(
          MaterialApp(
            key: ValueKey(locale.toLanguageTag()),
            locale: locale,
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            home: CalisthenicsLessonScreen(
              course: course,
              lesson: lesson,
              storeLoader: (_) async => store,
            ),
          ),
        );
        await pumpActualLocaleReady(t);
        final context = t.element(find.byType(CalisthenicsLessonScreen));
        expect(
          Localizations.of<GravitaLocalizations>(
            context,
            GravitaLocalizations,
          )?.localeTag,
          canonicalLocaleTag(locale.toLanguageTag()),
        );
        expect(
          Directionality.of(context),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(find.byType(CalisthenicsLessonScreen), findsOneWidget);
        final corrected = localized(
          context,
          "If fatigue increases without symptoms, choose recovery or plan an easier option for a later session. If symptoms appear or increase, end the current task; do not retest symptoms with an easier version. Persistent or concerning symptoms need appropriate individual assessment before resuming. A course checklist is not a training deadline.",
          "Belirti olmadan yorgunluk artarsa toparlanmayı seç veya sonraki bir seans için daha kolay seçeneği planla. Belirti ortaya çıkar ya da artarsa mevcut görevi bitir; belirtileri daha kolay biçimle yeniden sınama. Süren veya kaygı veren belirtilerde yeniden başlamadan önce uygun bireysel değerlendirme gerekir. Kurs listesi antrenman son tarihi değildir.",
        );
        expect(
          localized(context, lesson.steps[2].en, lesson.steps[2].tr),
          corrected,
          reason:
              'Reviewed cal52 display correction must be present under the canonical sourceID in every locale',
        );
        if (const ['en', 'tr', 'ar'].contains(locale.languageCode)) {
          final line = localized(
            context,
            '{number}. {label}',
            '{number}. {label}',
            values: <String, Object>{'number': 3, 'label': corrected},
          );
          await _reveal(t, find.text(line));
          expect(find.text(line).hitTestable(), findsOneWidget);
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
        // Alternate real IO turns and fake callbacks before the next lifetime;
        // never await the fake-zone file queue inside a real-only runAsync.
        await _driveReaderIo(
          t,
          store.load,
          stage: 'cal52 ${locale.toLanguageTag()} reader history drain',
        );
      }
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
      await _driveReaderIo(
        t,
        AccountStoreEpochRegistry.resetForTest,
        stage: 'cal52 reader registry reset',
      );
      root.deleteSync(recursive: true);
    }
  });
}
