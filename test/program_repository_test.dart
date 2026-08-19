import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/program/program_builder.dart';
import 'package:gravita/app/program/program_model.dart';

/// `ContentRepository`ın GRA-P1-003 kablolaması — `loadProgramConfig` +
/// `programCatalogEntries()` — GERÇEK bundle'a karşı. `program_builder_test.
/// dart`taki "gerçek katalog" testleri elle inşa edilmiş [ProgramCatalogEntry]
/// kullanıyordu; bu dosya o inşa ADIMININ (kablolamanın) kendisini sınıyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('foundation.v1.json bundle\'dan GERÇEKTEN okunuyor',
      (WidgetTester tester) async {
    late ProgramConfig config;
    await tester.runAsync(
        () async => config = await ContentRepository.loadProgramConfig(rootBundle));
    expect(config.totalWeeks, 8);
    expect(config.deloadWeeks, <int>{4, 8});
  });

  testWidgets(
      'programCatalogEntries() 31 hareketin HEPSİNİ döner, isHold katalogla '
      'TUTARLI', (WidgetTester tester) async {
    late ContentRepository content;
    late List<ProgramCatalogEntry> entries;
    await tester.runAsync(() async {
      content = await ContentRepository.load(rootBundle);
      entries = await content.programCatalogEntries();
    });

    expect(entries.length, content.catalogue.movements.length);

    // Bilinen bir hold hareketi + bilinen bir rep hareketi — katalog
    // dosyasının `engine.type`ıyla GERÇEKTEN eşleşiyor mu.
    final ProgramCatalogEntry plank =
        entries.firstWhere((ProgramCatalogEntry e) => e.id == 'plank');
    expect(plank.isHold, isTrue, reason: 'plank staticHold olmalı');
    final ProgramCatalogEntry squat = entries
        .firstWhere((ProgramCatalogEntry e) => e.id == 'bodyweight_squat');
    expect(squat.isHold, isFalse, reason: 'squat repFsm olmalı');
    expect(squat.isLive, isTrue);
  });

  testWidgets(
      'UÇTAN UCA: gerçek bundle → ProgramBuilder → çökmeden program üretiyor',
      (WidgetTester tester) async {
    late ContentRepository content;
    late ProgramConfig config;
    late List<ProgramCatalogEntry> entries;
    await tester.runAsync(() async {
      content = await ContentRepository.load(rootBundle);
      config = await ContentRepository.loadProgramConfig(rootBundle);
      entries = await content.programCatalogEntries();
    });

    final ProgramBuilder builder = ProgramBuilder(config: config, catalog: entries);
    final WorkoutProgram program = builder.build(const ProgramInputs(
      availableEquipment: <String>{},
      daysPerWeek: 3,
      experience: ExperienceLevel.beginner,
    ));
    expect(program.totalSessions, config.totalWeeks * 3);
    for (final ProgramDay d in program.days) {
      expect(d.exercises, isNotEmpty);
    }
  });
}
