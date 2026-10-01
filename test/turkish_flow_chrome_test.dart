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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets(
    'Turkish program setup and movement header keep localized chrome',
    (tester) async {
      await tester.pumpWidget(
        host(const Locale('tr'), ProgramSetupScreen(content: content)),
      );
      expect(find.text('Programını oluştur'), findsOneWidget);
      expect(find.text('Başlangıç'), findsOneWidget);
      expect(find.text('HAFTALIK GÜN SAYISI'), findsOneWidget);
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
      expect(find.text('FORM SINIFI'), findsOneWidget);
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
    await tester.pump();
    await tester.tap(find.byKey(ProgramSetupScreen.buildButtonKey));
    await settleUntil(
      tester,
      () => find.byKey(WorkoutScreen.disclaimerKey).evaluate().isNotEmpty,
      maxRounds: 30,
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
