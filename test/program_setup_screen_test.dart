import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/program/program_model.dart';
import 'package:gravita/app/program/program_setup_screen.dart';
import 'package:gravita/app/program/program_store.dart';
import 'package:gravita/app/theme.dart';
import 'package:gravita/app/workout/workout_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/launch_harness.dart' show FakeSupportDir, realIo;

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
  /// baştan sona GERÇEK G/Ç. `pumpAndSettle` burada ÇALIŞMAZ — sahte saat
  /// gerçek G/Ç'yi bilmiyor (`launch_harness.dart`ın ① dersiyle AYNI tuzak,
  /// birebir ölçüldü: ilk yazımda `pumpAndSettle` hiçbir şey beklemeden
  /// döndü, `WorkoutScreen` 0 widget çıktı). Sabit tur sayısı yerine KOŞUL.
  Future<void> settleReal(WidgetTester tester, {int maxRounds = 10}) async {
    for (int round = 0;
        round < maxRounds &&
            (find.byType(WorkoutScreen).evaluate().isEmpty ||
                find.byType(CircularProgressIndicator).evaluate().isNotEmpty);
        round++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  testWidgets('kurulum → kaydet → WorkoutScreen\'e geçer, program GERÇEKTEN '
      'GÖRÜNÜR', (WidgetTester tester) async {
    PathProviderPlatform.instance = FakeSupportDir(tmp.path);

    late ContentRepository content;
    await tester.runAsync(
        () async => content = await ContentRepository.load(rootBundle));

    await tester.pumpWidget(host(ProgramSetupScreen(content: content)));
    await tester.pump();

    // Varsayılan: beginner + ekipmansız + 3 gün — hiçbir seçim değiştirmeden
    // "Build" basmak GEÇERLİ bir program üretmeli (beginner+bodyweight
    // program_builder_test.dart'ta ZATEN çökmediği doğrulanmış bir girdi).
    await tester.tap(find.byKey(ProgramSetupScreen.buildButtonKey));
    await settleReal(tester);

    // WorkoutScreen'e geçildi VE program (boş-durum DEĞİL) çizildi.
    expect(find.byType(WorkoutScreen), findsOneWidget);
    expect(find.byKey(WorkoutScreen.emptyKey, skipOffstage: false), findsNothing,
        reason: 'kurulum kaydedildi — boş-durum artık GÖRÜNMEMELİ');

    // Kaydedilen girdi GERÇEKTEN diskte — bağımsız bir ProgramStore
    // örneğiyle OKUNARAK doğrulanıyor (ekranın kendi belleğine güvenmiyoruz).
    // `realIo` ZORUNLU: doğrudan `await` FakeAsync gövdesinde sonsuza kadar
    // asılı kalır (launch_harness.dart'ın kendi belgelediği ölçüm).
    final ProgramInputs? saved =
        await realIo(tester, () async => (await ProgramStore.open()).read());
    expect(saved, isNotNull);
    expect(saved!.experience, ExperienceLevel.beginner);
    expect(saved.daysPerWeek, 3);
    expect(saved.availableEquipment, isEmpty);
  });

  testWidgets('ekipman/seviye/gün seçimi GERÇEKTEN kaydediliyor — sahte '
      'değil', (WidgetTester tester) async {
    PathProviderPlatform.instance = FakeSupportDir(tmp.path);

    late ContentRepository content;
    await tester.runAsync(
        () async => content = await ContentRepository.load(rootBundle));

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

    final ProgramInputs? saved =
        await realIo(tester, () async => (await ProgramStore.open()).read());
    expect(saved, isNotNull);
    expect(saved!.experience, ExperienceLevel.intermediate);
    expect(saved.daysPerWeek, 4);
    expect(saved.availableEquipment, isNotEmpty);
  });
}
