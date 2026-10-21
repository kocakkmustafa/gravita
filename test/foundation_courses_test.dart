import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/account_store_epoch.dart';
import 'package:gravita/app/calisthenics_course.dart';
import 'package:gravita/app/calisthenics_course_screen.dart';
import 'package:gravita/app/calisthenics_progress.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:motion_content/motion_content.dart';
import 'package:gravita/app/motion_observation.dart';
import 'package:gravita/app/foundation_course_entry.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'support/launch_harness.dart';
import 'support/locale_asset_harness.dart';

class AlteredFoundationBundle extends CachingAssetBundle {
  AlteredFoundationBundle(this.path, {this.missing = false});
  final String path;
  final bool missing;
  @override
  Future<ByteData> load(String key) async {
    if (key == path && missing) throw StateError('Missing source asset');
    final bytes = await rootBundle.load(key);
    if (key != path) return bytes;
    final copy = Uint8List.fromList(Uint8List.sublistView(bytes));
    copy[copy.length - 1] = 32;
    return ByteData.sublistView(copy);
  }
}

/// Immutable legacy assets preserve the original1.0 HOLD contract after the
/// production course advances. Only these four assets use test fixtures.
class LegacyFoundationBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final name = key.split('/').last;
    if ((key.startsWith('content/courses/') &&
            const [
              'barbell-foundations.v1.json',
              'rings-foundations.v1.json',
              'hands-foundations.v1.json',
            ].contains(name)) ||
        key == 'content/motion_content/foundations.manifest.json') {
      return ByteData.sublistView(
        File('test/fixtures/foundations_v1/$name').readAsBytesSync(),
      );
    }
    return rootBundle.load(key);
  }
}

Future<void> reveal(WidgetTester t, Finder target) async {
  final scroll = find.byType(Scrollable).first;
  await t.scrollUntilVisible(target, 250, scrollable: scroll, maxScrolls: 200);
  for (var i = 0; target.hitTestable().evaluate().isEmpty && i < 100; i++) {
    final center = t.getCenter(target);
    await t.drag(scroll, Offset(0, center.dy > 450 ? -180 : 180));
    await t.pump();
  }
  expect(target.hitTestable(), findsOneWidget);
}

Future<void> drainLegacyRegistry(WidgetTester t, String stage) async {
  var completed = false;
  Object? failure;
  StackTrace? failureStack;
  debugPrint('legacy-drain START: $stage');
  // Pending work was admitted by widgets in the fake zone. Awaiting its
  // drain inside one real-zone runAsync prevents those callbacks from pumping.
  final observed = AccountStoreEpochRegistry.resetForTest().then<void>(
    (_) => completed = true,
    onError: (Object error, StackTrace stack) {
      failure = error;
      failureStack = stack;
      completed = true;
    },
  );
  final watch = Stopwatch()..start();
  var turns = 0;
  while (!completed && watch.elapsedMilliseconds < 1500 && turns < 4096) {
    await t.runAsync<void>(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await t.pump(const Duration(milliseconds: 80));
    turns++;
  }
  debugPrint(
    'legacy-drain $stage: completed=$completed turns=$turns '
    'wallMs=${watch.elapsedMilliseconds}',
  );
  expect(
    completed,
    isTrue,
    reason: 'Legacy registry drain missed the 1500ms deadline: $stage',
  );
  await observed;
  final error = failure;
  if (error != null) Error.throwWithStackTrace(error, failureStack!);
  debugPrint('legacy-drain END: $stage');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentRepository legacyContent;
  setUpAll(() async {
    await warmActualLocaleAssets();
    legacyContent = await ContentRepository.load(LegacyFoundationBundle());
  });
  for (final area in ['barbell', 'rings', 'hands']) {
    final raw = File(
      'test/fixtures/foundations_v1/$area-foundations.v1.json',
    ).readAsStringSync();
    final course = CalisthenicsCourse.parse(raw);
    test('$area legacy1.0 distinct sequence with draft physical gate', () {
      expect(course.lessons, hasLength(12));
      expect(course.lessons.where((l) => course.practiceHeld(l)), hasLength(8));
      for (final lesson in course.lessons) {
        expect(lesson.progression, isNotNull);
        expect(lesson.regression, isNotNull);
        expect(lesson.rest, isNotNull);
        expect(lesson.movementTaskId, 'gravita:${lesson.id}');
      }
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (v) => v['reviewStatus'] = 'accepted',
        (v) => v['equipment'] = {'en': '', 'tr': ''},
        (v) => v['modules'][0]['lessons'][2]['practiceType'] = 'learning_only',
        (v) => v['modules'][0]['lessons'][0]['id'] = 'cal-01',
        (v) => v['modules'][0]['lessons'][0].remove('rest'),
        (v) => v['modules'][0]['lessons'][1]['prerequisites'] = ['unknown'],
        (v) => v['catalogueGuides'] = [
          {
            'movementId': 'push_up',
            'kind': 'practice',
            'lessonIds': ['$area-03'],
          },
        ],
      ]) {
        final changed = jsonDecode(raw) as Map<String, dynamic>;
        mutate(changed);
        expect(
          () => CalisthenicsCourse.parse(jsonEncode(changed)),
          throwsA(anything),
        );
      }
    });
    test(
      '$area real file reopen, account/course isolation and held write rejection',
      () async {
        final dir = Directory.systemTemp.createTempSync('gravita-foundations-');
        try {
          final store = calisthenicsProgressStoreFor(
            dir,
            null,
            courseId: course.id,
          );
          final physical = course.lessons[2];
          await store.markSeen(course, physical);
          await expectLater(
            store.markPractised(course, physical),
            throwsStateError,
          );
          await expectLater(
            store.markCompleted(course, physical, selfChecksConfirmed: true),
            throwsStateError,
          );
          final read = course.lessons.first;
          await store.markPractised(course, read);
          await store.markCompleted(course, read, selfChecksConfirmed: true);
          final reopened = calisthenicsProgressStoreFor(
            dir,
            null,
            courseId: course.id,
          );
          expect((await reopened.load()).completedCount(course), 1);
          expect(
            (await reopened.load()).forLesson(physical, course.version)!.state,
            CalisthenicsLessonState.seen,
          );
          expect(
            (await calisthenicsProgressStoreFor(
              dir,
              '11111111-1111-4111-8111-111111111111',
              courseId: course.id,
            ).load()).records,
            isEmpty,
          );
          expect(
            (await calisthenicsProgressStoreFor(dir, null).load()).records,
            isEmpty,
          );
        } finally {
          dir.deleteSync(recursive: true);
        }
      },
    );
    for (final lang in ['tr', 'en']) {
      testWidgets(
        '$area legacy1.0 $lang 320px/2x entry → lesson → held controls → back',
        (t) async {
          final dir = Directory.systemTemp.createTempSync(
            'gravita-foundation-ui-',
          );
          final oldProvider = PathProviderPlatform.instance;
          PathProviderPlatform.instance = FakeSupportDir(dir.path);
          addTearDown(() {
            PathProviderPlatform.instance = oldProvider;
          });
          t.view.physicalSize = const Size(320, 900);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final content = legacyContent;
          debugPrint('legacy-stage $area $lang: mount and locale');
          await t.pumpWidget(
            MaterialApp(
              locale: Locale(lang),
              supportedLocales: appSupportedLocales,
              localizationsDelegates: appLocalizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: ListView(
                  children: [FoundationCourseEntry(content: content)],
                ),
              ),
            ),
          );
          await pumpActualLocaleReady(t);
          await t.pumpAndSettle();
          final entry = find.byKey(Key('foundation.entry.$area'));
          await reveal(t, entry);
          debugPrint('legacy-stage $area $lang: enter course');
          await t.tap(entry.hitTestable());
          await t.pumpAndSettle();
          await settleUntil(
            t,
            () => find
                .byKey(Key('calisthenics.lesson.${course.lessons[2].id}'))
                .evaluate()
                .isNotEmpty,
          );
          expect(find.byType(CalisthenicsCourseScreen), findsOneWidget);
          final lesson = find.byKey(
            Key('calisthenics.lesson.${course.lessons[2].id}'),
          );
          await reveal(t, lesson);
          debugPrint('legacy-stage $area $lang: enter held lesson');
          await t.tap(lesson.hitTestable());
          await t.pumpAndSettle();
          await settleUntil(
            t,
            () => find
                .byKey(const Key('calisthenics.practised'))
                .evaluate()
                .isNotEmpty,
          );
          expect(find.byType(CalisthenicsLessonScreen), findsOneWidget);
          final heading = find.text(
            lang == 'tr'
                ? 'Fiziksel pratik inceleme bekliyor'
                : 'Physical practice awaiting review',
          );
          await reveal(t, heading);
          expect(heading, findsOneWidget);
          final practiced = find.byKey(const Key('calisthenics.practised'));
          await reveal(t, practiced);
          expect(t.widget<OutlinedButton>(practiced).onPressed, isNull);
          expect(
            t
                .widget<FilledButton>(
                  find.byKey(const Key('calisthenics.complete')),
                )
                .onPressed,
            isNull,
          );
          expect(t.takeException(), isNull);
          debugPrint('legacy-stage $area $lang: back to course');
          await t.tap(find.byType(BackButton));
          await t.pumpAndSettle();
          expect(find.byType(CalisthenicsCourseScreen), findsOneWidget);
          debugPrint('legacy-stage $area $lang: unmount');
          await t.pumpWidget(const SizedBox.shrink());
          await t.pumpAndSettle();
          await drainLegacyRegistry(t, '$area $lang registry reset');
          dir.deleteSync(recursive: true);
        },
      );
    }
  }
  test(
    'verified offline composition keeps all five areas and pending capabilities',
    () async {
      final content = await ContentRepository.load(rootBundle);
      for (final area in ['bodyweight', 'dbkb', 'barbell', 'rings', 'hands']) {
        expect(content.courseForArea(area), isNotNull);
      }
      expect(content.calisthenicsCourse.lessons, hasLength(56));
      expect(content.dbkbCourse.lessons, hasLength(12));
      expect(content.dbkbHandlingCourse.lessons, hasLength(11));
      expect(content.dbkbTransitionsCourse.lessons, hasLength(2));
      for (final task in content.observationManifest.tasks.keys) {
        expect(
          content.observationManifest.readinessFor(task),
          ObservationStatus.calibrationRequired,
        );
      }
      for (final path in [
        'content/courses/barbell-foundations.v1.json',
        'content/courses/rings-foundations.v1.json',
        'content/courses/hands-foundations.v1.json',
        'content/models/gravita-observation.v1.json',
      ]) {
        for (final missing in [true, false]) {
          await expectLater(
            ContentRepository.load(
              AlteredFoundationBundle(path, missing: missing),
            ),
            throwsA(isA<ContentException>()),
          );
        }
      }
    },
  );
}
