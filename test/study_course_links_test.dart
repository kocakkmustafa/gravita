import 'dart:io';
import 'package:flutter/services.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/study_review.dart';
import 'package:gravita/app/calisthenics_course_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'support/launch_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> tapVisible(WidgetTester t, String key) async {
  final target = find.byKey(Key(key));
  if (target.hitTestable().evaluate().isEmpty) {
    await t.scrollUntilVisible(
      target,
      300,
      maxScrolls: 100,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await t.ensureVisible(target);
  await t.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await t.tap(target.hitTestable());
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> mount(WidgetTester t, Widget home, String language) async {
  t.view.physicalSize = const Size(320, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      supportedLocales: const [Locale('en'), Locale('tr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
        child: child!,
      ),
      home: home,
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  for (final language in ['en', 'tr']) {
    testWidgets(
      '$language recall opens only actual bodyweight/DBKB courses at 320px/2x',
      (t) async {
        final temp = Directory.systemTemp.createTempSync(
          'gravita-course-links-',
        );
        final original = PathProviderPlatform.instance;
        PathProviderPlatform.instance = FakeSupportDir(temp.path);
        addTearDown(() async {
          await t.pumpWidget(const SizedBox.shrink());
          await t.pumpAndSettle();
          PathProviderPlatform.instance = original;
          temp.deleteSync(recursive: true);
        });
        final content = (await t.runAsync(
          () => ContentRepository.load(rootBundle),
        ))!;
        await mount(
          t,
          Scaffold(body: StudyReviewEntry(content: content)),
          language,
        );
        await tapVisible(t, 'study-review-entry');
        for (final entry in {
          'bodyweight': content.calisthenicsCourse,
          'dbkb': content.dbkbCourse,
          ...content.foundationCourses,
        }.entries) {
          await tapVisible(t, 'study-course-${entry.key}');
          expect(
            t
                .widget<CalisthenicsCourseScreen>(
                  find.byType(CalisthenicsCourseScreen),
                )
                .course
                .id,
            entry.value.id,
          );
          await t.tap(find.byType(BackButton));
          await t.pumpAndSettle();
        }
        expect(t.takeException(), isNull);
      },
    );
  }
}
