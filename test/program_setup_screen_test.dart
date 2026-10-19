import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
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

/// [ProgramSetupScreen] — GRA-P1-003. `FakeSupportDir`/`realIo` `test/
/// support/launch_harness.dart`tan — İKİNCİ bir sahte sağlayıcı/G-Ç
/// sarmalayıcı YAZILMADI (G-079 dersi: iki ev tutarsızlaşır).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  Widget host(Widget child) =>
      MaterialApp(theme: GravitaTheme.light, home: child);

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
    await tester.pump();

    // Varsayılan: beginner + ekipmansız + 3 gün — hiçbir seçim değiştirmeden
    // "Build" basmak GEÇERLİ bir program üretmeli (beginner+bodyweight
    // program_builder_test.dart'ta ZATEN çökmediği doğrulanmış bir girdi).
    await tester.tap(find.byKey(ProgramSetupScreen.buildButtonKey));
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
    await tester.pump();

    await tester.tap(find.text('Intermediate'));
    await tester.pump();
    // Katalogdan türetilen ilk ekipman çipine dokun.
    await tester.tap(find.byType(FilterChip).first);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();

    await tester.tap(find.byKey(ProgramSetupScreen.buildButtonKey));
    await settleReal(tester);

    final ProgramInputs? saved = await realIo(
      tester,
      () async => (await ProgramStore.open()).read(),
    );
    expect(saved, isNotNull);
    expect(saved!.experience, ExperienceLevel.intermediate);
    expect(saved.daysPerWeek, 4);
    expect(saved.availableEquipment, isNotEmpty);
    await expectBoundSchedule(tester, content, saved);
  });
}
