import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/calisthenics_course.dart';
import 'package:gravita/app/calisthenics_course_screen.dart';
import 'package:gravita/app/calisthenics_knowledge_diagrams.dart';
import 'package:gravita/app/calisthenics_progress.dart';
import 'package:gravita/app/theme.dart';
import 'support/locale_asset_harness.dart' show warmActualLocaleAssets, pumpActualLocaleReady;

void main() {
  setUpAll(warmActualLocaleAssets);
  test(
    'diagram lessons are existing reading tasks, not physical assignments',
    () {
      final course = CalisthenicsCourse.parse(
        File('content/courses/calisthenics.v1.json').readAsStringSync(),
      );
      for (final id in ['cal-46', 'cal-47', 'cal-48', 'cal-49']) {
        expect(
          course.lessons.singleWhere((l) => l.id == id).learningOnly,
          isTrue,
        );
        expect(CalisthenicsKnowledgeDiagrams.supports(id), isTrue);
      }
      expect(CalisthenicsKnowledgeDiagrams.supports('cal-01'), isFalse);
      expect(CalisthenicsKnowledgeDiagrams.supports('unknown'), isFalse);
    },
  );

  for (final language in ['en', 'tr']) {
    for (final id in ['cal-46', 'cal-47', 'cal-48', 'cal-49']) {
      testWidgets(
        'actual $id at 320px/200percent $language does not award practice or completion',
        (tester) async {
          tester.view.physicalSize = const Size(320, 812);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final root = Directory.systemTemp.createTempSync(
            'gravita-diagram-view-',
          );
          addTearDown(() => root.deleteSync(recursive: true));
          final store = CalisthenicsProgressStore(
            File('${root.path}/progress.json'),
          );
          final course = CalisthenicsCourse.parse(
            File('content/courses/calisthenics.v1.json').readAsStringSync(),
          );
          final lesson = course.lessons.singleWhere((l) => l.id == id);
          await tester.pumpWidget(
            MaterialApp(
              theme: GravitaTheme.light,
              locale: Locale(language),
              supportedLocales: appSupportedLocales,
              localizationsDelegates: appLocalizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: CalisthenicsLessonScreen(
                course: course,
                lesson: lesson,
                storeLoader: (_) async => store,
              ),
            ),
          );
          await pumpActualLocaleReady(tester);
          await tester.pump();
          // Observe a real serialized read behind the UI's markSeen writer.
          // Its predecessor may finish in the widget zone while disk IO and
          // this retained read finish in the root zone; both must be drained.
          final read = Zone.root.run(store.load);
          var readSettled = false;
          unawaited(
            read.then<void>(
              (_) => readSettled = true,
              onError: (Object _, StackTrace __) => readSettled = true,
            ),
          );
          for (var turn = 0; turn < 100 && !readSettled; turn++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.idle();
          }
          expect(
            readSettled,
            isTrue,
            reason: 'bounded actual progress IO drain',
          );
          final progress = await tester.runAsync(
            () => read.timeout(const Duration(seconds: 2)),
          );
          await tester.pump();
          await tester.scrollUntilVisible(
            find.byKey(Key('calisthenics-diagrams-$id')),
            300,
            scrollable: find
                .descendant(
                  of: find.byKey(const Key('calisthenics.lesson.body')),
                  matching: find.byType(Scrollable),
                )
                .first,
            maxScrolls: 80,
          );
          await tester.pump();
          expect(find.byType(CalisthenicsKnowledgeDiagrams), findsOneWidget);
          expect(
            find.textContaining(
              language == 'tr' ? 'Şekli taklit etme.' : 'Do not copy the pose.',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          final record = progress!.forLesson(lesson, course.version)!;
          expect(record.state, CalisthenicsLessonState.seen);
          expect(record.practiceCount, 0);
          expect(record.lastPractisedAt, isNull);
          expect(record.completedAt, isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
