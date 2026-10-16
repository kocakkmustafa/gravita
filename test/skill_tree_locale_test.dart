import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/library_model.dart';
import 'package:gravita/app/library_screen.dart';
import 'package:gravita/app/skills/skill_tree_screen.dart';
import 'package:gravita/app/skills/skill_trees_list_screen.dart';
import 'package:gravita/app/surface_widgets.dart';
import 'package:gravita/app/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentRepository content;
  setUp(() async => content = await ContentRepository.load(rootBundle));

  Widget host(Widget child, {String language = 'tr'}) => MaterialApp(
    theme: GravitaTheme.light,
    locale: Locale(language),
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
      child: child!,
    ),
    home: child,
  );

  void narrow(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets(
    'Turkish list opens the selected draft with its boundary at 320px/2x',
    (tester) async {
      narrow(tester);
      await tester.pumpWidget(
        host(SkillTreesListScreen(trees: content.catalogue.skillTrees.trees)),
      );
      expect(find.text('Beceri ağaçları'), findsOneWidget);
      expect(find.text('Amut'), findsOneWidget);
      expect(find.text('Handstand'), findsNothing);
      expect(find.text('15 adım'), findsOneWidget);
      expect(find.text('6 adım'), findsOneWidget);
      await tester.tap(find.text('Planche'));
      await tester.pumpAndSettle();
      expect(find.text('6 ADIM, TASLAK'), findsOneWidget);
      expect(
        find.textContaining('fiziksel uygulamayı onaylamaz'),
        findsOneWidget,
      );
      expect(find.textContaining('not showing you'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'English draft summary never invites practice from unvalidated gates',
    (tester) async {
      narrow(tester);
      await tester.pumpWidget(
        host(
          SkillTreeScreen(tree: content.catalogue.skillTrees.trees.first),
          language: 'en',
        ),
      );
      expect(
        find.textContaining('does not approve physical practice'),
        findsOneWidget,
      );
      expect(find.textContaining('you can practise them today'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Turkish empty list explains the absence', (tester) async {
    narrow(tester);
    await tester.pumpWidget(host(const SkillTreesListScreen(trees: [])));
    expect(
      find.text('Şu anda taslak ilerleme ağacı bulunmuyor.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Turkish synthetic reviewed status retains the missing-view boundary',
    (tester) async {
      narrow(tester);
      const tree = SkillTree(
        packId: 'synthetic',
        displayName: 'Sentetik',
        nodeCount: 1,
        thresholdsValidated: true,
        nodeIds: ['synthetic'],
      );
      await tester.pumpWidget(host(const SkillTreeScreen(tree: tree)));
      expect(
        find.textContaining('Adım adım görünüm oluşturulmamıştır.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('hareket bilimi incelemesinden geçmiştir'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Turkish library explains the real draft count and review boundary',
    (tester) async {
      narrow(tester);
      await tester.pumpWidget(host(LibraryScreen(content: content)));
      await tester.scrollUntilVisible(
        find.byKey(LibraryScreen.skillTreesKey),
        350,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 100,
      );
      expect(find.textContaining('2 taslak ilerleme ağacı'), findsOneWidget);
      expect(find.textContaining('(Amut ve Planche)'), findsOneWidget);
      expect(
        find.textContaining('fiziksel uygulamayı onaylamaz'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'tr']) {
    testWidgets(
      '$language movement status remains readable and tappable at 320px/2x',
      (tester) async {
        narrow(tester);
        final selected = [
          content.catalogue.byId('push_up')!,
          content.catalogue.byId('wall_handstand')!,
        ];
        final tapped = <String>[];
        await tester.pumpWidget(
          host(
            Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  for (final movement in selected)
                    MovementCard(
                      key: Key('narrow.${movement.id}'),
                      movement: movement,
                      onTap: () => tapped.add(movement.id),
                    ),
                ],
              ),
            ),
            language: language,
          ),
        );
        expect(tester.takeException(), isNull);
        for (final movement in selected) {
          final target = find.byKey(Key('narrow.${movement.id}'));
          await tester.ensureVisible(target);
          await tester.tap(target);
          await tester.pump();
        }
        expect(tapped, selected.map((movement) => movement.id).toList());
        expect(tester.takeException(), isNull);
      },
    );
  }
}
