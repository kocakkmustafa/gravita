import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/library_model.dart';
import 'package:gravita/app/library_strings.dart';
import 'package:gravita/app/skills/skill_tree_screen.dart';
import 'package:gravita/app/theme.dart';

/// [SkillTreeScreen] — GRA-P1-001. Yalnız ZATEN paketli [SkillTree] özetini
/// gösterir; `content/skill-graph/*.json`ın kendisi bundle'da OLMADIĞI için
/// (bkz. `pubspec.yaml` + dosya başı yorumu) bu ekran o dosyaları hiç okumaz
/// — testler de SENTETİK [SkillTree] örnekleriyle çalışır, gerçek asset
/// yüklemesi gerekmez.
void main() {
  Widget host(Widget child) =>
      MaterialApp(theme: GravitaTheme.light, home: child);

  const SkillTree draft = SkillTree(
    packId: 'gravita.handstand',
    displayName: 'Handstand',
    nodeCount: 15,
    thresholdsValidated: false,
    nodeIds: <String>['wrist_prep'],
  );

  group('taslak ağaç (bugünkü GERÇEK durum — iki paket de draft)', () {
    testWidgets('başlıkta ağaç adı, gövdede adım sayısı VE taslak gerekçesi',
        (WidgetTester tester) async {
      await tester.pumpWidget(host(const SkillTreeScreen(tree: draft)));
      await tester.pump();

      expect(find.text('Handstand'), findsWidgets);
      // Ekran mono-eyebrow desenini izler (`SurfaceSection.title` deseninin
      // aynısı): metin `.toUpperCase()` ile çizilir. İlk yazışımım küçük
      // harfle aradı ve "0 bulundu" verdi — ekran kusuru değil, testin
      // gerçek büyük/küçük harf durumunu ölçmemesi.
      expect(find.textContaining('15 STEPS, DRAFTED'), findsOneWidget);
      expect(find.byKey(SkillTreeScreen.statusKey), findsOneWidget);
      expect(
          find.textContaining('not showing you the individual steps',
              skipOffstage: false),
          findsOneWidget);
    });

    testWidgets('doğrulanmış-durumu cümlesi ÇİZİLMİYOR — sayfa kendiyle '
        'çelişmiyor', (WidgetTester tester) async {
      // ⚠️ İLK YAZIŞIMIM `textContaining('been through a movement-science '
      // 'review')` diyordu ve YANLIŞ KIRMIZI verdi — draft cümlesi de TAM O
      // ALT DİZGEYİ taşıyor ("have NOT been through a movement-science
      // review"). Alt dizge iki hâli AYIRT ETMİYORDU (vekil-ölçüm hatası,
      // bu ailenin defalarca adlandırdığı sınıf). Düzeltme: TAM metin
      // eşleşmesi — `skillTreeScreenValidatedBody` yalnız validated dalda
      // çizilen SABİT bir cümle, alt dizge değil.
      await tester.pumpWidget(host(const SkillTreeScreen(tree: draft)));
      await tester.pump();
      expect(
          find.text(LibraryStrings.skillTreeScreenValidatedBody,
              skipOffstage: false),
          findsNothing,
          reason: 'draft ağaç "doğrulandı" cümlesini GÖSTERMEMELİ');
    });
  });

  group('POZİTİF İKİZ — doğrulanmış dal GERÇEKTEN çiziliyor mu', () {
    // ⚠️ Bugün hiçbir GERÇEK pakette `thresholdsValidated:true` yok — bu dal
    // sentetik veri olmadan HİÇ ÖLÇÜLMEZ ve ölü kod olarak kalabilir. Bu
    // test, `tools/build_skill_tree_index.py`nin bir gün bu bayrağı `true`
    // yazdığı an ekranın DOĞRU cümleye geçtiğini kanıtlıyor.
    const SkillTree validated = SkillTree(
      packId: 'gravita.synthetic',
      displayName: 'Synthetic Progression',
      nodeCount: 3,
      thresholdsValidated: true,
      nodeIds: <String>['a', 'b', 'c'],
    );

    testWidgets('validated ağaç → doğrulanmış-durum cümlesi, taslak DEĞİL',
        (WidgetTester tester) async {
      await tester.pumpWidget(host(const SkillTreeScreen(tree: validated)));
      await tester.pump();

      expect(
          find.text(LibraryStrings.skillTreeScreenValidatedBody,
              skipOffstage: false),
          findsOneWidget);
      expect(
          find.textContaining('not showing you the individual steps',
              skipOffstage: false),
          findsNothing,
          reason: 'validated ağaç taslak cümlesini GÖSTERMEMELİ');
    });
  });

  testWidgets('taşma YOK — dar telefon genişliğinde, en uzun gövde metniyle',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // En uzun gerçekçi ad — kırpılma/taşma burada yakalanır.
    const SkillTree longName = SkillTree(
      packId: 'gravita.planche',
      displayName: 'Planche Progression With A Rather Long Display Name',
      nodeCount: 6,
      thresholdsValidated: false,
      nodeIds: <String>[],
    );
    await tester.pumpWidget(host(const SkillTreeScreen(tree: longName)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
