import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/library_model.dart';
import 'package:gravita/app/live_session_screen.dart';
import 'package:gravita/app/skills/skill_tree_screen.dart';
import 'package:gravita/app/skills/skill_trees_list_screen.dart';
import 'package:gravita/app/surface_widgets.dart';
import 'package:gravita/app/why_not_here_screen.dart';
import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_camera/motion_camera.dart';

// Synthetic catalogues exercise source lookup before named value formatting.
// No actual camera start, account, provider, physical or translation acceptance.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(LocaleCatalogRegistry.clearForTesting);
  tearDown(LocaleCatalogRegistry.clearForTesting);

  LocaleCatalog catalog(String tag, Map<String, String> messages) =>
      LocaleCatalog.parse(
        jsonEncode(<String, Object>{
          'schemaVersion': 1,
          'localeTag': tag,
          'messages': messages,
        }),
      );

  void register(
    String tag,
    Map<String, String> english,
    Map<String, String> translated,
  ) {
    LocaleCatalogRegistry.register(
      catalog('en', english),
      catalog(tag, translated),
    );
  }

  Widget host(Widget child, {String language = 'de'}) => MaterialApp(
    locale: Locale(language),
    supportedLocales: appSupportedLocales,
    // Do not load/replace the deliberately tiny synthetic registry with assets.
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  const draftBody =
      'We are not showing you the individual steps of {tree}: their '
      'unlock criteria have not been through a movement-science review, and '
      'we do not want to draw a gate whose number we picked ourselves. The '
      'related movement pages in the library show their learning guides and '
      'camera availability separately; this summary does not approve physical '
      'practice.';

  testWidgets(
    'skill counts resolve a stable key before number and name values',
    (tester) async {
      tall(tester);
      register(
        'de',
        <String, String>{
          'g_7b859bb9f07b': '{count} steps',
          'g_ac22c50eb509': '{count} step',
          'g_3cc1c7cca3fe': '{count} steps, drafted',
          'g_ff5bfdb5b1a5': draftBody,
        },
        <String, String>{
          'g_7b859bb9f07b': '{count} TESTSCHRITTE',
          'g_ac22c50eb509': '{count} TESTSCHRITT',
          'g_3cc1c7cca3fe': '{count} TESTENTWURF',
          'g_ff5bfdb5b1a5': 'TEST: {tree}. No physical approval.',
        },
      );
      const tree = SkillTree(
        packId: 'synthetic',
        displayName: 'Source {count} name',
        nodeCount: 1234,
        thresholdsValidated: false,
        nodeIds: ['synthetic'],
      );
      const single = SkillTree(
        packId: 'synthetic.single',
        displayName: 'Single source',
        nodeCount: 1,
        thresholdsValidated: false,
        nodeIds: ['single'],
      );
      await tester.pumpWidget(
        host(const SkillTreesListScreen(trees: [tree, single])),
      );
      await tester.pumpAndSettle();
      expect(find.text('1.234 TESTSCHRITTE'), findsOneWidget);
      expect(find.text('1 TESTSCHRITT'), findsOneWidget);
      await tester.tap(find.text('Source {count} name'));
      await tester.pumpAndSettle();
      expect(find.byType(SkillTreeScreen), findsOneWidget);
      expect(find.text('1.234 TESTENTWURF'), findsOneWidget);
      expect(
        find.text('TEST: Source {count} name. No physical approval.'),
        findsOneWidget,
        reason:
            'Inserted braces are data and must not be expanded recursively.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'movement blocker count uses the catalogue template at new counts',
    (tester) async {
      tall(tester);
      register(
        'de',
        <String, String>{'g_d0e2e4b25574': '{count} measurements missing'},
        <String, String>{'g_d0e2e4b25574': '{count} TESTLÜCKEN'},
      );
      final source = await tester.runAsync(
        () => rootBundle.loadString('content/library.json'),
      );
      final library = jsonDecode(source!) as Map<String, dynamic>;
      final raw = (library['movements'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((m) => m['status'] != 'live');
      final synthetic = Map<String, dynamic>.of(raw)
        ..['blockedBy'] = List<String>.generate(1234, (i) => 'synthetic_$i');
      final movement = MovementEntry.fromJson(synthetic);
      expect(movement.isLive, isFalse);
      await tester.pumpWidget(
        host(
          Scaffold(
            body: MovementCard(movement: movement, onTap: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1.234 TESTLÜCKEN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final tag in ['de', 'ar']) {
    testWidgets(
      '$tag class badge resolves before casing and keeps class as data',
      (tester) async {
        tall(tester);
        register(
          tag,
          <String, String>{'g_da5a6736faa6': 'Class {class}'},
          <String, String>{
            'g_da5a6736faa6': tag == 'ar'
                ? 'اختبار {class}'
                : 'Testklasse {class}',
          },
        );
        const page = ExclusionsPage(
          title: 'Synthetic source',
          intro: 'Source scope',
          sections: [
            ExclusionSection(
              id: 'synthetic',
              title: 'Source section',
              examples: [],
              userReason: 'Source reason',
              searchTerms: [],
              limitClass: null,
              movementClass: 'B',
            ),
          ],
        );
        await tester.pumpWidget(
          host(const WhyNotHereScreen(page: page), language: tag),
        );
        await tester.pumpAndSettle();
        final label = find.text(
          tag == 'ar' ? 'اختبار \u2068B\u2069' : 'TESTKLASSE B',
        );
        expect(label, findsOneWidget);
        expect(
          Directionality.of(tester.element(label)),
          tag == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('tempo values retain explicit precision and translated token order', () {
    register(
      'de',
      <String, String>{'g_69c6f6f7658f': '{down}s down · {up}s up (median)'},
      <String, String>{'g_69c6f6f7658f': '{up}s TEST-AUF · {down}s TEST-AB'},
    );
    expect(
      resolveLocalized(
        'de',
        '{down}s down · {up}s up (median)',
        values: <String, Object>{
          'down': const LocaleNumber(1.24, fractionDigits: 1),
          'up': const LocaleNumber(0.76, fractionDigits: 1),
        },
      ),
      '0,8s TEST-AUF · 1,2s TEST-AB',
    );
  });

  testWidgets(
    'a revised gate source does not inherit a reviewed movement claim',
    (tester) async {
      tall(tester);
      final source = await tester.runAsync(
        () => rootBundle.loadString('content/catalog/w1/bodyweight_squat.json'),
      );
      final original = jsonDecode(source!) as Map<String, dynamic>;
      await tester.pumpWidget(
        host(
          LiveSessionScreen(
            config: MovementConfig.fromJson(original),
            controller: MotionCameraController(),
          ),
          language: 'tr',
        ),
      );
      await tester.pump();
      expect(
        find.textContaining('Tekrarı yalnızca kalça ve diz birlikte'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      final revised = jsonDecode(source) as Map<String, dynamic>;
      (revised['measurementContract'] as Map<String, dynamic>)['gateNote'] =
          'Revised source contract; no additional measurement claim.';
      await tester.pumpWidget(
        host(
          LiveSessionScreen(
            config: MovementConfig.fromJson(revised),
            controller: MotionCameraController(),
          ),
          language: 'tr',
        ),
      );
      await tester.pump();
      expect(
        find.text('Revised source contract; no additional measurement claim.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Tekrarı yalnızca kalça ve diz birlikte'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
