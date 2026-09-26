import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/onboarding_screen.dart';
import 'package:gravita/app/library_model.dart';
import 'package:gravita/app/surface_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> library;
  setUpAll(() async {
    library =
        jsonDecode(await rootBundle.loadString('content/library.json'))
            as Map<String, dynamic>;
  });

  testWidgets('Turkish onboarding keeps the safety consent gate', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: OnboardingFlow(onComplete: () async {}),
      ),
    );
    expect(find.text('Gravita nedir, ne değildir?'), findsOneWidget);
    await tester.tap(find.byKey(OnboardingFlow.valueContinueKey));
    await tester.pump();
    expect(find.text('Başlamadan önce'), findsOneWidget);
    expect(find.text('Anladım ve kabul ediyorum'), findsOneWidget);
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
  });

  testWidgets('every movement and course has a Turkish display label', (
    tester,
  ) async {
    late List<String> missing;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: Builder(
          builder: (context) {
            final ids = <String>[
              for (final movement
                  in library['movements'] as List<dynamic>) ...<String>[
                (movement as Map<String, dynamic>)['id'] as String,
                for (final course in movement['courses'] as List<dynamic>)
                  (course as Map<String, dynamic>)['id'] as String,
              ],
            ];
            missing = ids
                .where(
                  (id) =>
                      catalogName(context, id, 'UNTRANSLATED') ==
                      'UNTRANSLATED',
                )
                .toList();
            return const SizedBox();
          },
        ),
      ),
    );
    expect(missing, isEmpty);
  });

  testWidgets('Turkish movement card shows catalog name and camera closure', (
    tester,
  ) async {
    final movement = MovementEntry.fromJson(
      (library['movements'] as List<dynamic>).first as Map<String, dynamic>,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: Scaffold(
          body: MovementCard(movement: movement, onTap: () {}),
        ),
      ),
    );
    expect(find.text('Vücut ağırlığıyla squat'), findsOneWidget);
    expect(find.text('Bacak · Başlangıç · Ekipmansız'), findsOneWidget);
    expect(movement.isLive, isTrue);
    expect(find.text('KAMERA KAPALI'), findsOneWidget);
    expect(find.text('AÇIK'), findsNothing);
  });
}
