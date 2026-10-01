import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/camera_release_policy.dart';
import 'package:gravita/app/calisthenics_course_screen.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/gravita_app.dart';
import 'package:gravita/app/home_screen.dart';
import 'package:gravita/app/library_screen.dart';
import 'package:gravita/app/live_session_screen.dart';
import 'package:gravita/app/movement_page.dart';
import 'package:gravita/app/theme.dart';
import 'package:gravita/app/why_not_here_screen.dart';
import 'package:motion_account/motion_account.dart'
    show motionPaidFeaturesAvailable;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ContentRepository> loadReal(WidgetTester tester) async {
    late ContentRepository content;
    await tester.runAsync(() async {
      content = await ContentRepository.load(rootBundle);
    });
    return content;
  }

  Widget host(Widget child, String language) => MaterialApp(
    locale: Locale(language),
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    theme: GravitaTheme.light,
    home: child,
  );

  void useNarrowTall(WidgetTester tester) {
    tester.view.physicalSize = const Size(375, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  for (final language in ['en', 'tr']) {
    final tr = language == 'tr';
    testWidgets(
      '$language Today states camera closure and disables shell launch',
      (tester) async {
        useNarrowTall(tester);
        final content = await loadReal(tester);
        expect(motionPaidCameraLaunchEnabled, isFalse);
        expect(motionPaidCameraLaunchEnabled, motionPaidFeaturesAvailable);
        expect(content.catalogue.liveCount, 2);
        expect(content.startableConfigFor('push_up'), isNotNull);
        expect(content.calisthenicsCourse.lessons, hasLength(56));
        await tester.pumpWidget(host(GravitaShell(content: content), language));
        await tester.pump();
        final section = find.byKey(HomeScreen.openNowKey);
        expect(
          find.descendant(
            of: section,
            matching: find.text(
              tr ? 'ÖLÇÜM KATALOĞU' : 'MEASUREMENT CATALOGUE',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            tr
                ? 'Canlı kamera seansları bu sürümde kullanılamıyor.'
                : 'Live camera sessions are unavailable in this release.',
          ),
          findsWidgets,
        );
        expect(find.text(tr ? 'ŞU ANDA AÇIK' : 'OPEN RIGHT NOW'), findsNothing);
        final launch = find.byKey(GravitaShell.startSessionKey);
        expect(tester.widget<FloatingActionButton>(launch).onPressed, isNull);
        expect(
          find.text(tr ? 'Kamera kapalı' : 'Camera unavailable'),
          findsOneWidget,
        );
        await tester.tap(launch);
        await tester.pump();
        expect(find.byType(LiveSessionScreen), findsNothing);
        expect(find.byKey(const Key('calisthenics.entry')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$language Library distinguishes catalogue from live access', (
      tester,
    ) async {
      useNarrowTall(tester);
      final content = await loadReal(tester);
      await tester.pumpWidget(host(LibraryScreen(content: content), language));
      await tester.pump();
      expect(
        find.textContaining(
          tr ? '2 yapılandırılmış ölçüm' : '2 configured measurements',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          tr ? '29 ölçüm kanıtı bekliyor' : '29 pending measurement evidence',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('library.cameraUnavailable')),
        findsOneWidget,
      );
      expect(find.text(tr ? 'AÇIK' : 'OPEN'), findsNothing);
      expect(find.text(tr ? 'KAMERA KAPALI' : 'CAMERA CLOSED'), findsWidgets);
      await tester.tap(find.byKey(const Key('calisthenics.entry')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.byType(CalisthenicsCourseScreen),
        findsOneWidget,
        reason:
            'Guest teaching access must remain available with camera closed.',
      );
      expect(find.byType(LiveSessionScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$language configured movement camera callback cannot run', (
      tester,
    ) async {
      useNarrowTall(tester);
      final content = await loadReal(tester);
      var starts = 0;
      for (final id in ['bodyweight_squat', 'push_up']) {
        final movement = content.catalogue.byId(id)!;
        await tester.pumpWidget(
          host(
            MovementPage(
              key: ValueKey(id),
              content: content,
              movement: movement,
              onStartSession: (_) => starts++,
            ),
            language,
          ),
        );
        await tester.pump();
        final button = find.byKey(MovementPage.startSessionKey);
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        expect(
          find.text(tr ? 'Kamera kapalı' : 'Camera unavailable'),
          findsOneWidget,
        );
        expect(
          find.text(tr ? 'KAMERA KAPALI' : 'CAMERA CLOSED'),
          findsOneWidget,
        );
        await tester.tap(button);
        await tester.pump();
        expect(starts, 0);
        expect(find.byType(LiveSessionScreen), findsNothing);
        expect(find.byKey(MovementPage.learningGuideKey), findsOneWidget);
        expect(
          find.textContaining(
            tr
                ? 'tekrarlarını saymaz veya zamanlamaz'
                : 'does not count or time your repetitions',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            tr
                ? 'Bu sürüm formunu ölçmez veya puanlamaz'
                : 'This release does not measure or grade your form',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            tr
                ? 'Bu hareket ölçüm kataloğunda yer alır.'
                : 'This movement is in the measurement catalogue.',
          ),
          findsOneWidget,
        );
        for (final claim in [
          movement.blurb,
          ...movement.honesty.measured,
          movement.honesty.scoring!,
        ]) {
          expect(find.text(claim), findsNothing);
        }
        for (final activeClaim
            in tr
                ? [
                    'Tekrarlarını sayar',
                    'Doğrulanan şınav tekrarlarını sayar',
                    'temponu ölçeriz',
                    'temposunun ortancasını gösteririz',
                  ]
                : [
                    'We count your reps',
                    'We count verified push-up reps',
                    'show median down/up tempo',
                  ]) {
          expect(find.textContaining(activeClaim), findsNothing);
        }
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(
        host(WhyNotHereScreen(page: content.catalogue.exclusions), language),
      );
      await tester.pump();
      expect(
        find.textContaining(
          tr
              ? 'Telefon kamerası kuvveti veya maksimum kuvveti ölçmez.'
              : 'A phone camera does not measure force or maximum strength.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          tr
              ? 'Açık hareketlerde tekrarları sayıp'
              : 'On the movements that are open we',
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
