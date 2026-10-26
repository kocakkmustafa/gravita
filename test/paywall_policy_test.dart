import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_connection.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/calisthenics_course.dart';
import 'package:gravita/app/calisthenics_course_screen.dart';
import 'package:gravita/app/calisthenics_progress.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/paywall_policy.dart';
import 'package:gravita/app/theme.dart';

import 'support/launch_harness.dart' show settleUntil;
import 'support/locale_asset_harness.dart'
    show warmActualLocaleAssets, pumpActualLocaleReady;

/// Paywall "A" (user decision, 23 Oct 2026): module-aligned first third free,
/// the rest of each course behind the subscription gate, progress readable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(warmActualLocaleAssets);

  CalisthenicsCourse parse(String name) => CalisthenicsCourse.parse(
    File('content/courses/$name.v1.json').readAsStringSync(),
  );

  test('sales are open and the camera gate stays separate', () {
    expect(gravitaSubscriptionSalesAvailable, isTrue);
  });

  test('every Gravita course frees its module-aligned first third', () async {
    final content = await ContentRepository.load(rootBundle);
    final courses = <String, CalisthenicsCourse>{
      'calisthenics': content.calisthenicsCourse,
      'dbkb-written': parse('dbkb-written'),
      'dbkb-handling': parse('dbkb-handling'),
      'dbkb-transitions': parse('dbkb-transitions'),
      for (final area in ['barbell', 'rings', 'hands'])
        area: parse('$area-foundations'),
    };
    final free = {
      for (final e in courses.entries) e.key: freeLessonCount(e.value),
    };
    expect(free, <String, int>{
      'calisthenics': 21, // modules 1-3 of 10 (56 lessons)
      'dbkb-written': 6, // modules 1-2 of 4 (12)
      'dbkb-handling': 4, // single module: first ceil(11/3)
      'dbkb-transitions': 1, // single module: first ceil(2/3)
      'barbell': 4, // module 1 of 3 (12)
      'rings': 4,
      'hands': 4,
    });
    for (final e in courses.entries) {
      final course = e.value;
      final n = course.lessons.length;
      expect(free[e.key]! * 3, greaterThanOrEqualTo(n), reason: e.key);
      expect(free[e.key]!, lessThan(n), reason: '${e.key} keeps a paid part');
      for (final (i, lesson) in course.lessons.indexed) {
        expect(
          isFreeLesson(course, lesson),
          i < free[e.key]!,
          reason: lesson.id,
        );
        expect(isLockedLesson(course, lesson), i >= free[e.key]!);
      }
    }
    expect(free.values.fold<int>(0, (a, b) => a + b), 44);
  });

  test('a lesson outside the course is treated as paid', () {
    final written = parse('dbkb-written');
    final other = parse('barbell-foundations').lessons.first;
    expect(isFreeLesson(written, other), isFalse);
  });

  group('course screen gate', () {
    final course = parse('dbkb-written');
    late Directory temp;
    late List<String> guardCalls;
    setUp(() async {
      temp = await Directory.systemTemp.createTemp('gravita-paywall-');
      guardCalls = <String>[];
    });
    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    Widget host(String language, {bool? grant}) {
      final app = MaterialApp(
        theme: GravitaTheme.light,
        locale: Locale(language),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: CalisthenicsCourseScreen(
          course: course,
          storeLoader: (id) async =>
              calisthenicsProgressStoreFor(temp, id, courseId: course.id),
        ),
      );
      if (grant == null) return app;
      return AccountScope(
        connection: AccountConnection(
          userId: ValueNotifier<String?>(null),
          pageBuilder: (_) => const SizedBox.shrink(),
          requirePaidAccess: (context) async {
            guardCalls.add('called');
            return grant;
          },
        ),
        currentUserId: null,
        child: app,
      );
    }

    Future<void> show(WidgetTester tester, Widget widget) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(widget);
      await pumpActualLocaleReady(tester);
      await settleUntil(
        tester,
        () =>
            find
                .byKey(const Key('calisthenics.paywall.note'))
                .evaluate()
                .isNotEmpty &&
            find.text('0 / 12').evaluate().isNotEmpty,
        maxRounds: 40,
      );
    }

    Future<void> tapLesson(WidgetTester tester, String id) async {
      final tile = find.byKey(Key('calisthenics.lesson.$id'));
      await tester.scrollUntilVisible(
        tile,
        240,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('calisthenics.course.body')),
              matching: find.byType(Scrollable),
            )
            .first,
        maxScrolls: 60,
      );
      await tester.tap(tile);
      await settleUntil(
        tester,
        () => find.byType(CalisthenicsLessonScreen).evaluate().isNotEmpty,
        maxRounds: 20,
      );
    }

    for (final language in ['en', 'tr']) {
      testWidgets('$language preview note, locks and readable progress', (
        tester,
      ) async {
        await show(tester, host(language, grant: false));
        expect(
          find.text(
            language == 'en'
                ? 'Free preview: 6 of 12 lessons. The rest are included with a '
                      'Gravita or Motion+ subscription; your progress always stays readable.'
                : 'Ücretsiz önizleme: 12 dersten 6 ders. Diğerleri Gravita veya '
                      'Motion+ aboneliğine dahildir; ilerlemen her zaman okunur kalır.',
          ),
          findsOneWidget,
        );
        // Progress counts every lesson, paid ones included.
        expect(find.text('0 / 12'), findsOneWidget);
        for (final (i, lesson) in course.lessons.indexed) {
          // The course list is lazy: bring each row into view before
          // reading its lock state.
          final row = find.byKey(Key('calisthenics.lesson.${lesson.id}'));
          await tester.scrollUntilVisible(
            row,
            240,
            scrollable: find
                .descendant(
                  of: find.byKey(const Key('calisthenics.course.body')),
                  matching: find.byType(Scrollable),
                )
                .first,
            maxScrolls: 60,
          );
          final locked = find.byKey(Key('calisthenics.locked.${lesson.id}'));
          expect(
            locked,
            i < 6 ? findsNothing : findsOneWidget,
            reason: lesson.id,
          );
          // The lesson row and its state label stay visible either way.
          expect(row, findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a free lesson opens without asking for access', (
      tester,
    ) async {
      await show(tester, host('en', grant: false));
      await tapLesson(tester, course.lessons[5].id);
      expect(find.byType(CalisthenicsLessonScreen), findsOneWidget);
      expect(guardCalls, isEmpty);
    });

    testWidgets('a paid lesson stays closed when access is refused', (
      tester,
    ) async {
      await show(tester, host('en', grant: false));
      await tapLesson(tester, course.lessons[6].id);
      expect(guardCalls, hasLength(1));
      expect(find.byType(CalisthenicsLessonScreen), findsNothing);
    });

    testWidgets('a paid lesson opens once access is granted', (tester) async {
      await show(tester, host('en', grant: true));
      await tapLesson(tester, course.lessons[6].id);
      expect(guardCalls, hasLength(1));
      expect(find.byType(CalisthenicsLessonScreen), findsOneWidget);
    });

    testWidgets('without an account connection the paid part stays closed', (
      tester,
    ) async {
      await show(tester, host('en'));
      await tapLesson(tester, course.lessons[6].id);
      expect(find.byType(CalisthenicsLessonScreen), findsNothing);
      expect(find.text(PaywallStrings.unavailable), findsOneWidget);
    });
  });

  testWidgets('paywall copy resolves in all 14 locales', (tester) async {
    late Map<String, List<String>> resolved;
    resolved = <String, List<String>>{};
    for (final tag in supportedLocaleTags) {
      await tester.pumpWidget(
        MaterialApp(
          locale: localeForAppTag(tag),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          localeListResolutionCallback: resolveAppLocales,
          home: Builder(
            builder: (context) {
              resolved[tag] = <String>[
                localized(
                  context,
                  PaywallStrings.lockedLesson,
                  'Aboneliğe dahil',
                ),
                localized(
                  context,
                  PaywallStrings.coursePreview,
                  'x',
                  values: const <String, Object>{'count': 4, 'total': 12},
                ),
                localized(context, PaywallStrings.practiceNote, 'x'),
                localized(context, PaywallStrings.unavailable, 'x'),
              ];
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await pumpActualLocaleReady(tester);
      await tester.pump();
    }
    expect(resolved.keys.toSet(), supportedLocaleTags.toSet());
    final english = resolved['en']!;
    for (final tag in supportedLocaleTags.where((t) => t != 'en')) {
      for (final (i, text) in resolved[tag]!.indexed) {
        expect(text, isNot(english[i]), reason: '$tag #$i is translated');
        expect(text, isNot('x'), reason: '$tag #$i comes from the catalogue');
        expect(
          text,
          isNot(contains('{')),
          reason: '$tag #$i placeholders filled',
        );
      }
    }
  });
}
