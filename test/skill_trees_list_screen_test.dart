import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/library_model.dart';
import 'package:gravita/app/skills/skill_trees_list_screen.dart';
import 'package:gravita/app/theme.dart';

/// [SkillTreesListScreen] — GRA-P1-001 gezilebilirlik düzeltmesi. Sentetik
/// [SkillTree] listesiyle çalışır (bkz. `skill_tree_screen_test.dart`ın aynı
/// gerekçesi: bu ekran de yalnız ZATEN paketli özeti kullanır).
void main() {
  Widget host(Widget child) =>
      MaterialApp(theme: GravitaTheme.light, home: child);

  const List<SkillTree> two = <SkillTree>[
    SkillTree(
      packId: 'gravita.handstand',
      displayName: 'Handstand',
      nodeCount: 15,
      thresholdsValidated: false,
      nodeIds: <String>[],
    ),
    SkillTree(
      packId: 'gravita.planche',
      displayName: 'Planche',
      nodeCount: 6,
      thresholdsValidated: false,
      nodeIds: <String>[],
    ),
  ];

  testWidgets('her ağaç bir satır — ad + adım sayısı', (WidgetTester tester) async {
    await tester.pumpWidget(host(const SkillTreesListScreen(trees: two)));
    await tester.pump();

    expect(find.text('Handstand'), findsOneWidget);
    expect(find.text('Planche'), findsOneWidget);
    expect(find.textContaining('15 steps'), findsOneWidget);
    expect(find.textContaining('6 steps'), findsOneWidget);
  });

  testWidgets('bir satıra dokununca DOĞRU ağacın ekranı açılıyor',
      (WidgetTester tester) async {
    await tester.pumpWidget(host(const SkillTreesListScreen(trees: two)));
    await tester.pump();

    await tester.tap(find.text('Planche'));
    await tester.pumpAndSettle();

    // Yeni ekranın AppBar'ı doğru ağacın adını taşıyor — ilk satıra değil,
    // DOKUNULANA gidildiğini kanıtlar.
    expect(find.text('Planche'), findsWidgets);
    expect(find.textContaining('6 STEPS, DRAFTED'), findsOneWidget);
  });

  testWidgets('boş liste — sessiz ekran DEĞİL, adıyla bir cümle',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        host(const SkillTreesListScreen(trees: <SkillTree>[])));
    await tester.pump();
    expect(find.byKey(SkillTreesListScreen.emptyKey), findsOneWidget);
  });

  testWidgets('taşma YOK — dar telefon genişliğinde', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(const SkillTreesListScreen(trees: two)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
