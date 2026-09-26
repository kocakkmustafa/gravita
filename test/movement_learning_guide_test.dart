import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/calisthenics_course_screen.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/movement_page.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _EphemeralSupport extends PathProviderPlatform {
  _EphemeralSupport(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory support;
  late PathProviderPlatform previous;
  setUp(() async {
    support = await Directory.systemTemp.createTemp('gravita-guide-test-');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _EphemeralSupport(support.path);
  });
  tearDown(() async {
    PathProviderPlatform.instance = previous;
    await support.delete(recursive: true);
  });

  for (final (movement, lesson, language) in [
    ('plank', 'cal-31', 'en'),
    ('wall_handstand', 'cal-46', 'tr'),
  ]) {
    testWidgets(
      '$movement guide opens its real lesson without camera promotion ($language)',
      (tester) async {
        late ContentRepository content;
        await tester.runAsync(() async {
          content = await ContentRepository.load(rootBundle);
        });
        var cameraStarts = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            home: MovementPage(
              movement: content.catalogue.byId(movement)!,
              content: content,
              onStartSession: (_) => cameraStarts++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(MovementPage.startSessionKey), findsNothing);
        final link = find.byKey(Key('movement.guide.$lesson'));
        await tester.scrollUntilVisible(link, 200);
        await tester.pumpAndSettle();
        // Lazy catalogue loading can enlarge the preceding honesty section.
        // Re-align after it settles and assert the control is actually tappable.
        await tester.ensureVisible(link);
        await tester.pumpAndSettle();
        expect(link.hitTestable(), findsOneWidget);
        await tester.tap(link);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pumpAndSettle();
        final screen = tester.widget<CalisthenicsLessonScreen>(
          find.byType(CalisthenicsLessonScreen),
        );
        expect(screen.lesson.id, lesson);
        expect(screen.lesson.learningOnly, movement == 'wall_handstand');
        expect(screen.lesson.prerequisites, isNotEmpty);
        expect(cameraStarts, 0);
        expect(content.foundationCoverage.configuredCameraIds, {
          'bodyweight_squat',
          'push_up',
        });
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
