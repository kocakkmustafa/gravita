import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/movement_page.dart';
import 'package:gravita/app/program/program_setup_screen.dart';
import 'package:gravita/app/surface_widgets.dart';
import 'package:gravita/app/workout/workout_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/launch_harness.dart' show FakeSupportDir, settleUntil;
import 'support/locale_asset_harness.dart'
    show warmActualLocaleAssets, pumpActualLocaleReady;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(warmActualLocaleAssets);

  late ContentRepository content;
  setUpAll(() async {
    content = await ContentRepository.load(rootBundle);
  });

  Widget host(Locale locale, Widget child) => MaterialApp(
    locale: locale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    home: child,
  );

  // ProgramSetupScreen is a lazy list: reveal targets below the first view.
  Future<void> reveal(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        240,
        scrollable: find
            .byWidgetPredicate(
              (w) =>
                  w is Scrollable &&
                  axisDirectionToAxis(w.axisDirection) == Axis.vertical,
            )
            .first,
        maxScrolls: 100,
      );
    }
  }

  testWidgets(
    'Turkish program setup and movement header keep localized chrome',
    (tester) async {
      await tester.pumpWidget(
        host(const Locale('tr'), ProgramSetupScreen(content: content)),
      );
      await pumpActualLocaleReady(tester);
      expect(find.text('Programını oluştur'), findsOneWidget);
      expect(find.text('Başlangıç'), findsOneWidget);
      await reveal(tester, find.text('HAFTALIK GÜN SAYISI'));
      expect(find.text('HAFTALIK GÜN SAYISI'), findsOneWidget);
      await reveal(tester, find.text('Dambıl'));
      expect(find.text('Dambıl'), findsOneWidget);
      expect(find.text('Set up your program'), findsNothing);

      final movement = content.catalogue.movements.firstWhere(
        (entry) => entry.id == 'farmer_carry',
      );
      await tester.pumpWidget(
        host(
          const Locale('tr'),
          MovementPage(movement: movement, content: content),
        ),
      );
      await pumpActualLocaleReady(tester);
      // The reviewed TR catalog (g_3ebf6dd5eef8) names this badge; the
      // app_locale switch value is only a fallback.
      expect(find.text('FORM REHBERLİĞİ'), findsOneWidget);
      expect(
        find.text(
          'Sınıf A — kameranın ihtiyaç duyduğu her şey yandan görünür.',
        ),
        findsOneWidget,
      );
      expect(find.text('FORM COACHING'), findsNothing);
    },
  );

  testWidgets('English copy and session unit labels remain accurate', (
    tester,
  ) async {
    late String english;
    late String turkish;
    await tester.pumpWidget(
      host(
        const Locale('en'),
        Builder(
          builder: (context) {
            english = movementTrendSummary(context, 2, 12, 'rep');
            return const SizedBox();
          },
        ),
      ),
    );
    await pumpActualLocaleReady(tester);
    await tester.pump();
    await tester.pumpWidget(
      host(
        const Locale('tr'),
        Builder(
          builder: (context) {
            turkish = movementTrendSummary(context, 2, 12, 'rep');
            return const SizedBox();
          },
        ),
      ),
    );
    await pumpActualLocaleReady(tester);
    await tester.pump();
    expect(english, '2 sessions · 12 reps');
    expect(turkish, '2 oturum · 12 tekrar');
  });

  testWidgets('Turkish program overview keeps the plan and safety copy clear', (
    tester,
  ) async {
    final originalProvider = PathProviderPlatform.instance;
    final Directory temp = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('gra_tr_workout'),
    ))!;
    addTearDown(() async {
      PathProviderPlatform.instance = originalProvider;
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    PathProviderPlatform.instance = FakeSupportDir(temp.path);
    await tester.pumpWidget(
      host(const Locale('tr'), ProgramSetupScreen(content: content)),
    );
    await pumpActualLocaleReady(tester);
    await tester.pump();
    await reveal(tester, find.byKey(ProgramSetupScreen.buildButtonKey));
    await tester.ensureVisible(find.byKey(ProgramSetupScreen.buildButtonKey));
    await tester.pump();
    await tester.tap(find.byKey(ProgramSetupScreen.buildButtonKey));
    await settleUntil(
      tester,
      () => find.byKey(WorkoutScreen.disclaimerKey).evaluate().isNotEmpty,
      maxRounds: 40,
    );
    expect(find.text('Sekiz haftalık programın'), findsOneWidget);
    expect(find.byKey(WorkoutScreen.disclaimerKey), findsOneWidget);
    final disclaimer = tester.widget<NoteCard>(
      find.byKey(WorkoutScreen.disclaimerKey),
    );
    expect(
      disclaimer.text,
      contains('İlerleme düzeni hareket bilimi incelemesinden'),
    );
    expect(find.text('1. HAFTA'), findsOneWidget);
    expect(find.text('Your 8-week program'), findsNothing);
  });
}
