import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/program/program_builder.dart';
import 'package:gravita/app/program/program_model.dart';
import 'package:gravita/app/program/program_schedule_store.dart';
import 'package:gravita/app/program/program_signature.dart';
import 'package:gravita/app/program/program_setup_screen.dart';
import 'package:gravita/app/program/program_store.dart';
import 'package:gravita/app/theme.dart';
import 'package:gravita/app/workout/workout_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/launch_harness.dart' show FakeSupportDir, realIo, settleUntil;
import 'support/locale_asset_harness.dart'
    show warmActualLocaleAssets, pumpActualLocaleReady;

/// [ProgramSetupScreen] — GRA-P1-003. `FakeSupportDir`/`realIo` `test/
/// support/launch_harness.dart`tan — İKİNCİ bir sahte sağlayıcı/G-Ç
/// sarmalayıcı YAZILMADI (G-079 dersi: iki ev tutarsızlaşır).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(warmActualLocaleAssets);

  late PathProviderPlatform defaultProvider;
  late Directory tmp;

  setUp(() async {
    defaultProvider = PathProviderPlatform.instance;
    tmp = await Directory.systemTemp.createTemp('gra_program_setup');
  });

  tearDown(() async {
    PathProviderPlatform.instance = defaultProvider;
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Widget host(Widget child) => MaterialApp(
    theme: GravitaTheme.light,
    locale: const Locale('en'),
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    localeListResolutionCallback: resolveAppLocales,
    home: child,
  );

  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    final scrollable = find.byElementPredicate((element) {
      final widget = element.widget;
      if (widget is! Scrollable ||
          axisDirectionToAxis(widget.axisDirection) != Axis.vertical) {
        return false;
      }
      final route = ModalRoute.of(element);
      if (route?.isCurrent != true) return false;
      var hasOuterVerticalViewport = false;
      element.visitAncestorElements((ancestor) {
        final outer = ancestor.widget;
        if (outer is Scrollable &&
            axisDirectionToAxis(outer.axisDirection) == Axis.vertical &&
            identical(ModalRoute.of(ancestor), route)) {
          hasOuterVerticalViewport = true;
          return false;
        }
        return true;
      });
      return !hasOuterVerticalViewport;
    }, description: 'active setup route outer vertical Scrollable');
    expect(scrollable, findsOneWidget);
    if (target.evaluate().isEmpty) {
      final state = tester.state<ScrollableState>(scrollable);
      var usedScrolls = 0;
      while (state.position.pixels > state.position.minScrollExtent + 1 &&
          usedScrolls < 100) {
        await tester.drag(scrollable, const Offset(0, 600));
        await tester.pump();
        usedScrolls++;
      }
      expect(
        state.position.pixels,
        lessThanOrEqualTo(state.position.minScrollExtent + 1),
      );
      if (target.evaluate().isEmpty) {
        expect(usedScrolls, lessThan(100));
        await tester.scrollUntilVisible(
          target,
          240,
          scrollable: scrollable,
          maxScrolls: 100 - usedScrolls,
        );
      }
    }
    expect(target, findsOneWidget);
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
    await tester.pump();
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target.hitTestable());
  }

  /// Kurulum → yazma → geçiş → `WorkoutScreen`in KENDİ yükleyicisi zinciri
  /// baştan sona GERÇEK G/Ç — `settleUntil` (`support/launch_harness.dart`)
  /// bu YÜZDEN gerekiyor: `pumpAndSettle` ilk yazımda hiçbir şey beklemeden
  /// döndü, `WorkoutScreen` 0 widget çıktı (sahte saat gerçek G/Ç'yi bilmiyor).
  Future<void> settleReal(WidgetTester tester) => settleUntil(
    tester,
    () =>
        find.byType(WorkoutScreen).evaluate().isNotEmpty &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty,
    maxRounds: 40,
  );

  Future<void> expectBoundSchedule(
    WidgetTester tester,
    ContentRepository content,
    ProgramInputs inputs,
  ) async {
    await realIo(tester, () async {
      final config = await ContentRepository.loadProgramConfig(rootBundle);
      final entries = await content.programCatalogEntries();
      final program = ProgramBuilder(
        config: config,
        catalog: entries,
      ).build(inputs);
      final schedule = await (await ProgramScheduleStore.open()).read();
      expect(schedule, isNotNull);
      expect(schedule!.programSignature, programSignature(inputs, program));
      expect(schedule.dates, hasLength(program.days.length));
      expect(schedule.rpeByDayIndex, isEmpty);
    });
    expect(find.byKey(WorkoutScreen.disclaimerKey), findsOneWidget);
    expect(find.byKey(WorkoutScreen.unavailableKey), findsNothing);
  }

  testWidgets('kurulum → kaydet → WorkoutScreen\'e geçer, program GERÇEKTEN '
      'GÖRÜNÜR', (WidgetTester tester) async {
    PathProviderPlatform.instance = FakeSupportDir(tmp.path);

    late ContentRepository content;
    await tester.runAsync(
      () async => content = await ContentRepository.load(rootBundle),
    );
    await realIo(tester, () async {
      await ContentRepository.loadProgramConfig(rootBundle);
      await content.programCatalogEntries();
    });

    await tester.pumpWidget(host(ProgramSetupScreen(content: content)));
    await pumpActualLocaleReady(tester);

    // Varsayılan: beginner + ekipmansız + 3 gün — hiçbir seçim değiştirmeden
    // "Build" basmak GEÇERLİ bir program üretmeli (beginner+bodyweight
    // program_builder_test.dart'ta ZATEN çökmediği doğrulanmış bir girdi).
    await tapVisible(tester, find.byKey(ProgramSetupScreen.buildButtonKey));
    await settleReal(tester);

    // WorkoutScreen'e geçildi VE program (boş-durum DEĞİL) çizildi.
    expect(find.byType(WorkoutScreen), findsOneWidget);
    expect(
      find.byKey(WorkoutScreen.emptyKey, skipOffstage: false),
      findsNothing,
      reason: 'kurulum kaydedildi — boş-durum artık GÖRÜNMEMELİ',
    );

    // Kaydedilen girdi GERÇEKTEN diskte — bağımsız bir ProgramStore
    // örneğiyle OKUNARAK doğrulanıyor (ekranın kendi belleğine güvenmiyoruz).
    // `realIo` ZORUNLU: doğrudan `await` FakeAsync gövdesinde sonsuza kadar
    // asılı kalır (launch_harness.dart'ın kendi belgelediği ölçüm).
    final ProgramInputs? saved = await realIo(
      tester,
      () async => (await ProgramStore.open()).read(),
    );
    expect(saved, isNotNull);
    expect(saved!.experience, ExperienceLevel.beginner);
    expect(saved.daysPerWeek, 3);
    expect(saved.availableEquipment, isEmpty);
    await expectBoundSchedule(tester, content, saved);
  });

  testWidgets('ekipman/seviye/gün seçimi GERÇEKTEN kaydediliyor — sahte '
      'değil', (WidgetTester tester) async {
    PathProviderPlatform.instance = FakeSupportDir(tmp.path);

    late ContentRepository content;
    await tester.runAsync(
      () async => content = await ContentRepository.load(rootBundle),
    );
    await realIo(tester, () async {
      await ContentRepository.loadProgramConfig(rootBundle);
      await content.programCatalogEntries();
    });

    await tester.pumpWidget(host(ProgramSetupScreen(content: content)));
    await pumpActualLocaleReady(tester);

    await tapVisible(tester, find.text('Intermediate'));
    await tester.pump();
    // Select the first catalogue equipment by identity, not lazy widget index.
    final equipmentOptions = <String>{
      for (final movement in content.catalogue.movements) ...movement.equipment,
    }.toList()..sort();
    expect(equipmentOptions, isNotEmpty);
    final selectedEquipment = equipmentOptions.first;
    final equipmentLabel = equipmentDisplayName(
      tester.element(find.byType(ProgramSetupScreen)),
      selectedEquipment,
    );
    await tapVisible(
      tester,
      find.descendant(
        of: find.byKey(ProgramSetupScreen.equipmentKey),
        matching: find.widgetWithText(FilterChip, equipmentLabel),
      ),
    );
    await tester.pump();
    await tapVisible(tester, find.byIcon(Icons.add_circle_outline));
    await tester.pump();

    await tapVisible(tester, find.byKey(ProgramSetupScreen.buildButtonKey));
    await settleReal(tester);

    final ProgramInputs? saved = await realIo(
      tester,
      () async => (await ProgramStore.open()).read(),
    );
    expect(saved, isNotNull);
    expect(saved!.experience, ExperienceLevel.intermediate);
    expect(saved.daysPerWeek, 4);
    expect(saved.availableEquipment, isNotEmpty);
    expect(saved.availableEquipment, contains(selectedEquipment));
    await expectBoundSchedule(tester, content, saved);
  });
}
