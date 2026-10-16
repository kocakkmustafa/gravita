import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/calisthenics_course_screen.dart';
import 'package:gravita/app/calisthenics_progress.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/gravita_app.dart';
import 'package:gravita/app/library_screen.dart';
import 'package:gravita/app/progress_view.dart';
import 'package:gravita/app/study_review.dart';
import 'package:gravita/app/theme.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/launch_harness.dart';

void main() {
  late ContentRepository content;
  late Directory temp;
  late PathProviderPlatform original;
  setUp(() async {
    content = await ContentRepository.load(rootBundle);
    temp = await Directory.systemTemp.createTemp('gravita-reading-links-');
    original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = FakeSupportDir(temp.path);
  });
  tearDown(() async {
    PathProviderPlatform.instance = original;
    await temp.delete(recursive: true);
  });

  for (final language in ['en', 'tr']) {
    testWidgets(
      '$language progress tab loads real empty history in the selected locale',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: GravitaTheme.light,
            locale: Locale(language),
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            home: ProgressTab(content: content),
          ),
        );
        await settleUntil(
          tester,
          () => find.byType(ProgressView).evaluate().isNotEmpty,
          maxRounds: 40,
        );
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text(language == 'tr' ? 'Ölçülenler' : 'Measured'),
          ),
          findsOneWidget,
        );
        expect(
          find.text(language == 'tr' ? 'Başlanmadı' : 'Not started'),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$language library recall reaches five existing reading-only lessons',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
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
            home: LibraryScreen(content: content),
          ),
        );
        await tester.tap(find.byKey(const Key('study-review-entry')));
        await tester.pumpAndSettle();
        expect(find.byType(StudyReviewPage), findsOneWidget);
        for (final id in ['cal-22', 'cal-48', 'cal-49', 'cal-46', 'cal-47']) {
          final target = find.byKey(Key('study-related-$id'));
          await tester.scrollUntilVisible(
            target,
            300,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 100,
          );
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          expect(target.hitTestable(), findsOneWidget);
          await tester.tap(target);
          await tester.pumpAndSettle();
          final page = tester.widget<CalisthenicsLessonScreen>(
            find.byType(CalisthenicsLessonScreen),
          );
          expect(page.lesson.id, id);
          expect(page.lesson.learningOnly, isTrue);
          await tester.scrollUntilVisible(
            find.byKey(const Key('calisthenics.state')),
            200,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 30,
          );
          await tester.pumpAndSettle();
          await settleUntil(
            tester,
            () => find
                .text(language == 'tr' ? 'Görüldü' : 'Seen')
                .evaluate()
                .isNotEmpty,
            // Existing-file read + atomic write crosses more host-I/O turns
            // than a first open. Wait on the state, never a fixed sleep.
            maxRounds: 40,
          );
          expect(
            find.text(language == 'tr' ? 'Görüldü' : 'Seen'),
            findsOneWidget,
            reason:
                '$id state=${tester.widget<Text>(find.byKey(const Key('calisthenics.state'))).data}; '
                'storage notice=${find.textContaining(language == 'tr' ? 'İlerleme okunamadı' : 'Progress could not').evaluate().length}',
          );
          await tester.scrollUntilVisible(
            find.text(language == 'tr' ? 'Öğrenme görevi' : 'Learning task'),
            200,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 30,
          );
          expect(find.byKey(const Key('calisthenics.prepared')), findsNothing);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
        }
        final saved = await tester.runAsync(
          () => calisthenicsProgressStoreFor(temp, null).load(),
        );
        for (final lesson in content.calisthenicsCourse.lessons.where(
          (l) =>
              ['cal-22', 'cal-46', 'cal-47', 'cal-48', 'cal-49'].contains(l.id),
        )) {
          final record = saved!.forLesson(
            lesson,
            content.calisthenicsCourse.version,
          )!;
          expect(record.state, CalisthenicsLessonState.seen);
          expect(record.practiceCount, 0);
          expect(record.completedAt, isNull);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
