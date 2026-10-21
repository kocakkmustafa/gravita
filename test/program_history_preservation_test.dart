import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/course_progress_io.dart';
import 'package:gravita/app/library_strings.dart';
import 'package:gravita/app/program/program_builder.dart';
import 'package:gravita/app/program/program_model.dart';
import 'package:gravita/app/program/program_inputs_io.dart';
import 'package:gravita/app/program/program_schedule_store.dart';
import 'package:gravita/app/program/program_setup_screen.dart';
import 'package:gravita/app/program/program_signature.dart';
import 'package:gravita/app/program/program_store.dart';
import 'package:gravita/app/theme.dart';
import 'package:gravita/app/workout/workout_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/locale_asset_harness.dart'
    show warmActualLocaleAssets, pumpActualLocaleReady;
import 'support/launch_harness.dart' show FakeSupportDir, realIo, settleUntil;

// A02/A03/A08 regresyonları: gerçek widget/store, yalnız yeni sentetik dizin.
// OS process death, fiziksel disk, hesap veya provider kabulü değildir.
void main() {
  setUpAll(warmActualLocaleAssets);
  TestWidgetsFlutterBinding.ensureInitialized();
  late PathProviderPlatform originalProvider;
  late Directory temp;
  late ContentRepository content;
  late ProgramBuilder builder;

  const initial = ProgramInputs(
    availableEquipment: <String>{},
    daysPerWeek: 3,
    experience: ExperienceLevel.beginner,
  );

  setUp(() async {
    originalProvider = PathProviderPlatform.instance;
    temp = await Directory.systemTemp.createTemp(
      'gravita-history-preservation-',
    );
    PathProviderPlatform.instance = FakeSupportDir(temp.path);
    // Lazy program Future'larını widget fake zone'una bırakma.
    content = await ContentRepository.load(rootBundle);
    final config = await ContentRepository.loadProgramConfig(rootBundle);
    final entries = await content.programCatalogEntries();
    builder = ProgramBuilder(config: config, catalog: entries);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalProvider;
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  File inputFile() => File('${temp.path}/program_inputs.json');
  File scheduleFile() => File('${temp.path}/program_schedule.json');

  Widget host(Widget child) => MaterialApp(
    theme: GravitaTheme.light,
    locale: const Locale('en'),
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    home: child,
  );

  void prepareView(WidgetTester tester) {
    // İçerik/state gözlemi; minimum telefon veya performans fixture'ı değildir.
    tester.view.physicalSize = const Size(1400, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  Future<void> seed(
    WidgetTester tester, {
    bool legacy = false,
    int missingDates = 0,
    Map<int, int> rpe = const <int, int>{0: 7},
  }) => realIo(tester, () async {
    final program = builder.build(initial);
    final now = DateTime.now();
    final dates = scheduleProgram(
      program: program,
      startDate: DateTime(now.year, now.month, now.day + 2),
      daysPerWeek: initial.daysPerWeek,
    );
    await ProgramStore.forFile(inputFile()).write(initial);
    await ProgramScheduleStore.forFile(scheduleFile()).write(
      ProgramSchedule(
        dates: dates.take(dates.length - missingDates).toList(),
        rpeByDayIndex: rpe,
        programSignature: legacy ? null : programSignature(initial, program),
      ),
    );
  });

  Future<({List<int>? inputs, List<int>? schedule})> bytes(
    WidgetTester tester,
  ) => realIo(
    tester,
    () async => (
      inputs: await inputFile().exists()
          ? await inputFile().readAsBytes()
          : null,
      schedule: await scheduleFile().exists()
          ? await scheduleFile().readAsBytes()
          : null,
    ),
  );

  Future<void> expectBytes(
    WidgetTester tester,
    ({List<int>? inputs, List<int>? schedule}) before,
  ) async {
    final after = await bytes(tester);
    expect(
      after.inputs,
      before.inputs,
      reason: 'Mevcut girdiler byte olarak korunmalı.',
    );
    expect(
      after.schedule,
      before.schedule,
      reason: 'Mevcut tarih/RPE ve eksik dosya durumu korunmalı.',
    );
  }

  Future<void> showWorkout(
    WidgetTester tester, {
    DateTime Function()? now,
  }) async {
    await tester.pumpWidget(
      host(
        now == null
            ? WorkoutScreen(content: content)
            : WorkoutScreen.withClock(content: content, now: now),
      ),
    );
    await pumpActualLocaleReady(tester);
    await settleUntil(
      tester,
      () =>
          find.byKey(WorkoutScreen.unavailableKey).evaluate().isNotEmpty ||
          find.byKey(WorkoutScreen.disclaimerKey).evaluate().isNotEmpty ||
          find.byKey(WorkoutScreen.emptyKey).evaluate().isNotEmpty,
      maxRounds: 40,
    );
    expect(tester.takeException(), isNull);
  }

  void expectUnavailable() {
    expect(find.byKey(WorkoutScreen.unavailableKey), findsOneWidget);
    expect(find.byKey(WorkoutScreen.emptyKey), findsNothing);
    expect(find.byKey(WorkoutScreen.disclaimerKey), findsNothing);
    expect(
      find.text(LibraryStrings.programNoInputsAction),
      findsNothing,
      reason: 'Korunan geçmiş için yeni setup CTA sunulmamalı.',
    );
  }

  Future<void> submitSetup(WidgetTester tester) async {
    final button = find.byKey(ProgramSetupScreen.buildButtonKey);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  Future<void> expectSetupRejected(WidgetTester tester) async {
    final button = find.byKey(ProgramSetupScreen.buildButtonKey);
    await settleUntil(
      tester,
      () =>
          find.byType(SnackBar).evaluate().isNotEmpty &&
          button.evaluate().isNotEmpty &&
          tester.widget<FilledButton>(button).onPressed != null,
      maxRounds: 40,
    );
    expect(find.byType(ProgramSetupScreen), findsOneWidget);
    expect(find.byType(WorkoutScreen), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('could not be saved'), findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  }

  Future<void> rejectDefaultSetup(WidgetTester tester) async {
    await tester.pumpWidget(host(ProgramSetupScreen(content: content)));
    await pumpActualLocaleReady(tester);
    await tester.pump();
    await submitSetup(tester);
    await expectSetupRejected(tester);
  }

  String recipes(WorkoutProgram program) => program.days
      .map(
        (day) => day.exercises
            .map(
              (e) =>
                  '${e.movementId}/${e.sets}/${e.targetReps}/'
                  '${e.targetHoldSeconds}/${e.restSeconds}',
            )
            .join(','),
      )
      .join('|');

  Future<void> seedOnDate(WidgetTester tester, DateTime date) async {
    await seed(tester, rpe: const <int, int>{});
    await realIo(tester, () async {
      final store = ProgramScheduleStore.forFile(scheduleFile());
      final saved = (await store.read())!;
      await store.write(
        saved.withDates(
          scheduleProgram(
            program: builder.build(initial),
            startDate: date,
            daysPerWeek: initial.daysPerWeek,
          ),
        ),
      );
    });
  }

  testWidgets('retry rereads repaired fixture without creating a plan', (
    tester,
  ) async {
    prepareView(tester);
    await seed(tester);
    final original = await bytes(tester);
    final expectedSchedule = await realIo(
      tester,
      () => ProgramScheduleStore.forFile(scheduleFile()).read(),
    );
    expect(expectedSchedule, isNotNull);
    expect(expectedSchedule!.rpeByDayIndex, <int, int>{0: 7});
    const broken = '{"dates":';
    await realIo(tester, () => scheduleFile().writeAsString(broken));
    await showWorkout(tester);
    expectUnavailable();
    await tester.tap(find.byKey(WorkoutScreen.retryKey));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await settleUntil(
      tester,
      () =>
          tester
              .widget<OutlinedButton>(find.byKey(WorkoutScreen.retryKey))
              .onPressed !=
          null,
    );
    expectUnavailable();
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(WorkoutScreen.retryKey))
          .onPressed,
      isNotNull,
    );
    expect(await realIo(tester, () => scheduleFile().readAsString()), broken);
    // The fixture is repaired explicitly by the test, never by Workout.
    await realIo(tester, () => scheduleFile().writeAsBytes(original.schedule!));
    await expectBytes(tester, original);
    await tester.tap(find.byKey(WorkoutScreen.retryKey));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await settleUntil(
      tester,
      () => find.byKey(WorkoutScreen.disclaimerKey).evaluate().isNotEmpty,
    );
    // settleUntil is bounded and does not itself assert its final condition.
    expect(find.byKey(WorkoutScreen.disclaimerKey), findsOneWidget);
    expect(find.byKey(WorkoutScreen.unavailableKey), findsNothing);
    expect(find.byKey(WorkoutScreen.emptyKey), findsNothing);
    expect(tester.takeException(), isNull);
    expect(
      Localizations.localeOf(tester.element(find.byType(WorkoutScreen))),
      const Locale('en'),
    );
    // Read the actual store after the reload completed, before searching UI.
    // A lost or rebound RPE must fail even if another card has similar text.
    final reloaded = await realIo(
      tester,
      () => ProgramScheduleStore.forFile(scheduleFile()).read(),
    );
    expect(reloaded, isNotNull);
    expect(reloaded!.rpeByDayIndex, <int, int>{0: 7});
    expect(reloaded.programSignature, expectedSchedule.programSignature);
    expect(reloaded.dates, expectedSchedule.dates);
    await expectBytes(tester, original);

    // A lazy ListView's disclaimer does not prove a day card was mounted.
    // Find the first persisted date by its public label, never widget index.
    final firstDate = find.text(
      'Scheduled: ${formatLocaleDate(expectedSchedule.dates[0], 'en')}',
    );
    final scrollable = find.descendant(
      of: find.byType(WorkoutScreen),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
      ),
    );
    expect(scrollable, findsOneWidget);
    if (firstDate.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        firstDate,
        240,
        scrollable: scrollable,
        maxScrolls: 100,
      );
    }
    expect(firstDate, findsOneWidget);
    final firstDayCard = find.ancestor(
      of: firstDate,
      matching: find.byType(GravitaCard),
    );
    expect(firstDayCard, findsOneWidget);
    final firstDayDone = find.descendant(
      of: firstDayCard,
      matching: find.text('Done · RPE 7'),
    );
    expect(
      firstDayDone,
      findsOneWidget,
      reason:
          'The persisted first day must show its RPE; mounted pill labels: '
          '${tester.widgetList<GravitaPill>(find.descendant(of: firstDayCard, matching: find.byType(GravitaPill))).map((pill) => pill.label).toList()}',
    );
    await Scrollable.ensureVisible(
      tester.element(firstDayDone),
      alignment: 0.5,
    );
    await tester.pump();
    expect(find.text('Done · RPE 7'), findsOneWidget);
    expect(firstDayDone.hitTestable(), findsOneWidget);
    await expectBytes(tester, original);
  });

  testWidgets('midnight refreshes day classification without rewriting dates', (
    tester,
  ) async {
    prepareView(tester);
    var clock = DateTime.utc(2026, 10, 20, 23, 59, 59);
    await seedOnDate(tester, DateTime.utc(2026, 10, 20));
    final before = await bytes(tester);
    await showWorkout(tester, now: () => clock);
    const done = ValueKey<String>('workout.markDone.1.1');
    const reschedule = ValueKey<String>('workout.reschedule.1.1');
    expect(find.byKey(done), findsOneWidget);
    clock = DateTime.utc(2026, 10, 21, 0, 0, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(reschedule), findsOneWidget);
    expect(find.byKey(done), findsNothing);
    await expectBytes(tester, before);
  });

  testWidgets('resume refreshes only the view date', (tester) async {
    prepareView(tester);
    var clock = DateTime(2026, 10, 20, 9);
    await seedOnDate(tester, DateTime(2026, 10, 20));
    final before = await bytes(tester);
    await showWorkout(tester, now: () => clock);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    clock = DateTime(2026, 10, 21, 9);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('workout.reschedule.1.1')),
      findsOneWidget,
    );
    await expectBytes(tester, before);
  });

  testWidgets('midnight preserves an unsaved RPE choice', (tester) async {
    prepareView(tester);
    var clock = DateTime.utc(2026, 10, 20, 23, 59, 59);
    await seedOnDate(tester, DateTime.utc(2026, 10, 20));
    final before = await bytes(tester);
    await showWorkout(tester, now: () => clock);
    await tester.tap(
      find.byKey(const ValueKey<String>('workout.markDone.1.1')),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, '7'));
    clock = DateTime.utc(2026, 10, 21, 0, 0, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(
      find.byKey(const ValueKey<String>('workout.saveRpe.1.1')),
      findsOneWidget,
    );
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '7')).selected,
      isTrue,
    );
    await expectBytes(tester, before);
  });

  testWidgets('iki dosya da yoksa Workout salt okunur boş durumu gösterir', (
    tester,
  ) async {
    prepareView(tester);
    final before = await bytes(tester);
    expect(before.inputs, isNull);
    expect(before.schedule, isNull);
    await showWorkout(tester);
    expect(find.byKey(WorkoutScreen.emptyKey), findsOneWidget);
    expect(find.byKey(WorkoutScreen.unavailableKey), findsNothing);
    expect(find.text(LibraryStrings.programNoInputsAction), findsOneWidget);
    await expectBytes(tester, before);
  });

  for (final corruption in <String>['truncatedJSON', 'badRPEtype', 'badDate']) {
    testWidgets(
      'Workout $corruption geçmişini değiştirmeden unavailable gösterir',
      (tester) async {
        prepareView(tester);
        await seed(tester);
        await realIo(tester, () async {
          final original = await scheduleFile().readAsString();
          if (corruption == 'truncatedJSON') {
            await scheduleFile().writeAsString(
              original.substring(0, original.length - 1),
            );
          } else {
            final payload = jsonDecode(original) as Map<String, dynamic>;
            if (corruption == 'badRPEtype') {
              payload['rpeByDayIndex'] = <String, Object>{'0': '7'};
            } else {
              final dates = payload['dates'] as List<dynamic>;
              dates[0] = 'not-a-date';
            }
            await scheduleFile().writeAsString(jsonEncode(payload));
          }
        });
        final before = await bytes(tester);
        await showWorkout(tester);
        expectUnavailable();
        await expectBytes(tester, before);
        await tester.pumpWidget(const SizedBox.shrink());
        await showWorkout(tester);
        expectUnavailable();
        await expectBytes(tester, before);
        if (corruption == 'badRPEtype') {
          await rejectDefaultSetup(tester);
          await expectBytes(tester, before);
        }
      },
    );
  }

  testWidgets('legacy imzasız geçmiş Workout ve Setup tarafından korunur', (
    tester,
  ) async {
    prepareView(tester);
    await seed(tester, legacy: true);
    final before = await bytes(tester);
    await showWorkout(tester);
    expectUnavailable();
    await expectBytes(tester, before);
    await rejectDefaultSetup(tester);
    await expectBytes(tester, before);
  });

  for (final remaining in <String>['inputsOnly', 'scheduleOnly']) {
    testWidgets('$remaining kısmi geçmişi Workout ve Setup tamamlayıp ezmez', (
      tester,
    ) async {
      prepareView(tester);
      await seed(tester);
      await realIo(tester, () async {
        if (remaining == 'inputsOnly') {
          await scheduleFile().delete();
        } else {
          await inputFile().delete();
        }
      });
      final before = await bytes(tester);
      await showWorkout(tester);
      expectUnavailable();
      await expectBytes(tester, before);
      await rejectDefaultSetup(tester);
      await expectBytes(tester, before);
    });
  }

  testWidgets('imza aynı olsa da farklı gün sayısı geçmişi ezilmez', (
    tester,
  ) async {
    prepareView(tester);
    await seed(tester, missingDates: 1);
    final before = await bytes(tester);
    await showWorkout(tester);
    expectUnavailable();
    await rejectDefaultSetup(tester);
    await expectBytes(tester, before);
  });

  for (final inputFault in <String>['truncatedJSON', 'unknownSchema']) {
    testWidgets('ProgramInputs $inputFault yeni setup sayılmaz ve korunur', (
      tester,
    ) async {
      prepareView(tester);
      await seed(tester);
      await realIo(tester, () async {
        if (inputFault == 'truncatedJSON') {
          await inputFile().writeAsString('{"daysPerWeek":');
        } else {
          final payload =
              jsonDecode(await inputFile().readAsString())
                  as Map<String, dynamic>;
          payload['schemaVersion'] = 2;
          await inputFile().writeAsString(jsonEncode(payload));
        }
        await expectLater(
          ProgramStore.forFile(inputFile()).read(),
          throwsA(isA<ProgramInputsException>()),
        );
      });
      final before = await bytes(tester);
      await showWorkout(tester);
      expectUnavailable();
      await rejectDefaultSetup(tester);
      await expectBytes(tester, before);
    });
  }

  testWidgets('aynı bağlı Setup tarih RPE ve input byte yazmadan gezinir', (
    tester,
  ) async {
    prepareView(tester);
    await seed(tester);
    // Yeniden canonical JSON yazımı da byte karşılaştırmasında görülsün.
    await realIo(tester, () async {
      for (final file in <File>[inputFile(), scheduleFile()]) {
        final payload = jsonDecode(await file.readAsString());
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(payload),
        );
      }
    });
    final before = await bytes(tester);
    await tester.pumpWidget(host(ProgramSetupScreen(content: content)));
    await pumpActualLocaleReady(tester);
    await tester.pump();
    await submitSetup(tester);
    await settleUntil(
      tester,
      () => find.byKey(WorkoutScreen.disclaimerKey).evaluate().isNotEmpty,
      maxRounds: 40,
    );
    expect(find.byType(WorkoutScreen), findsOneWidget);
    expect(find.byKey(WorkoutScreen.disclaimerKey), findsOneWidget);
    expect(find.byKey(WorkoutScreen.unavailableKey), findsNothing);
    expect(find.text('Done · RPE 7'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await expectBytes(tester, before);
    await tester.pumpWidget(const SizedBox.shrink());
    await showWorkout(tester);
    expect(find.text('Done · RPE 7'), findsOneWidget);
    await expectBytes(tester, before);
  });

  final changes = <String, ProgramInputs>{
    'experience': const ProgramInputs(
      availableEquipment: <String>{},
      daysPerWeek: 3,
      experience: ExperienceLevel.intermediate,
    ),
    'equipment': const ProgramInputs(
      availableEquipment: <String>{'dumbbells'},
      daysPerWeek: 3,
      experience: ExperienceLevel.beginner,
    ),
    'frequency': const ProgramInputs(
      availableEquipment: <String>{},
      daysPerWeek: 4,
      experience: ExperienceLevel.beginner,
    ),
  };
  for (final change in changes.entries) {
    testWidgets(
      'Setup ${change.key} değişimini reddeder eski RPEyi yeni plana bağlamaz',
      (tester) async {
        prepareView(tester);
        await seed(tester);
        final before = await bytes(tester);
        final oldProgram = builder.build(initial);
        final changedProgram = builder.build(change.value);
        expect(
          programSignature(change.value, changedProgram),
          isNot(programSignature(initial, oldProgram)),
        );
        if (change.key != 'frequency') {
          expect(changedProgram.days.length, oldProgram.days.length);
          expect(
            recipes(changedProgram),
            isNot(recipes(oldProgram)),
            reason: 'Aynı-N fixture gerçek reçete farkını içermeli.',
          );
        }
        await tester.pumpWidget(host(ProgramSetupScreen(content: content)));
        await pumpActualLocaleReady(tester);
        await tester.pump();
        if (change.key == 'experience') {
          await tester.tap(find.text('Intermediate'));
        } else if (change.key == 'equipment') {
          await tester.tap(find.widgetWithText(FilterChip, 'dumbbells'));
        } else {
          await tester.tap(find.byIcon(Icons.add_circle_outline));
        }
        await tester.pump();
        await submitSetup(tester);
        await expectSetupRejected(tester);
        await expectBytes(tester, before);
        await tester.pumpWidget(const SizedBox.shrink());
        await showWorkout(tester);
        expect(find.byKey(WorkoutScreen.disclaimerKey), findsOneWidget);
        expect(
          find.text('Done · RPE 7'),
          findsOneWidget,
          reason: 'RPE eski, değişmemiş reçetenin geçmişi olarak kalmalı.',
        );
        await expectBytes(tester, before);
      },
    );
  }

  testWidgets(
    'farklı reçete girdisi ile eski aynı-N takvim salt okunur bloklanır',
    (tester) async {
      prepareView(tester);
      await seed(tester);
      final changed = changes['experience']!;
      expect(
        builder.build(changed).days.length,
        builder.build(initial).days.length,
      );
      await realIo(
        tester,
        () => ProgramStore.forFile(inputFile()).write(changed),
      );
      final before = await bytes(tester);
      await showWorkout(tester);
      expectUnavailable();
      await expectBytes(tester, before);
    },
  );

  Future<void> chooseAndSave(WidgetTester tester, int day, int rpe) async {
    final mark = find.byKey(ValueKey<String>('workout.markDone.1.$day'));
    await tester.ensureVisible(mark);
    await tester.tap(mark);
    await tester.pump();
    // İlk günün bekleyen picker'ı açıksa son eşleşme ikinci gününküdür.
    final chip = find.widgetWithText(ChoiceChip, '$rpe').last;
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pump();
    final save = find.byKey(ValueKey<String>('workout.saveRpe.1.$day'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
  }

  testWidgets(
    'RPE kaydı başarısızsa picker seçim ve hata kalır retry başarılı olur',
    (tester) async {
      prepareView(tester);
      await seed(tester, rpe: const <int, int>{});
      final original = await bytes(tester);
      await showWorkout(tester);
      expect(find.byKey(WorkoutScreen.disclaimerKey), findsOneWidget);
      const corrupt = '{"dates":';
      // UI yüklendikten sonraki dosya bozulması, gerçek update/read hata dalı.
      // Fiziksel disk/write failure deneyi değildir.
      await realIo(tester, () => scheduleFile().writeAsString(corrupt));
      await chooseAndSave(tester, 1, 7);
      final save = find.byKey(const ValueKey<String>('workout.saveRpe.1.1'));
      await settleUntil(
        tester,
        () =>
            find.byType(SnackBar).evaluate().isNotEmpty &&
            save.evaluate().isNotEmpty &&
            tester.widget<FilledButton>(save).onPressed != null,
        maxRounds: 40,
      );
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining('save could not be confirmed'),
        findsOneWidget,
      );
      expect(save, findsOneWidget);
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '7'))
            .selected,
        isTrue,
      );
      expect(find.text('Done · RPE 7'), findsNothing);
      expect(
        await realIo(tester, () => scheduleFile().readAsString()),
        corrupt,
      );
      final afterFailure = await bytes(tester);
      expect(afterFailure.inputs, original.inputs);

      await realIo(
        tester,
        () => scheduleFile().writeAsBytes(original.schedule!),
      );
      await tester.tap(save);
      await settleUntil(
        tester,
        () => find.text('Done · RPE 7').evaluate().isNotEmpty,
        maxRounds: 40,
      );
      expect(find.text('Done · RPE 7'), findsOneWidget);
      expect(save, findsNothing);
      final stored = await realIo(
        tester,
        () => ProgramScheduleStore.forFile(scheduleFile()).read(),
      );
      expect(stored!.rpeByDayIndex, <int, int>{0: 7});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('iki gün bekleyen RPE kaydı busy kalır güncel dosyada birleşir', (
    tester,
  ) async {
    prepareView(tester);
    await seed(tester, rpe: const <int, int>{});
    await showWorkout(tester);
    expect(find.byKey(WorkoutScreen.disclaimerKey), findsOneWidget);

    final entered = Completer<void>();
    final release = Completer<void>();
    var settled = false;
    Object? gateError;
    await tester.runAsync(() async {
      final gate = CourseProgressLease(scheduleFile()).mutate(() async {
        entered.complete();
        await release.future;
      });
      unawaited(
        gate.then<void>(
          (_) {
            settled = true;
          },
          onError: (Object error, StackTrace stack) {
            gateError = error;
            settled = true;
          },
        ),
      );
    });
    try {
      await settleUntil(tester, () => entered.isCompleted, maxRounds: 40);
      expect(entered.isCompleted, isTrue);
      await chooseAndSave(tester, 1, 7);
      final firstSave = find.byKey(
        const ValueKey<String>('workout.saveRpe.1.1'),
      );
      expect(firstSave, findsOneWidget);
      expect(tester.widget<FilledButton>(firstSave).onPressed, isNull);
      await chooseAndSave(tester, 2, 6);
      final secondSave = find.byKey(
        const ValueKey<String>('workout.saveRpe.1.2'),
      );
      expect(secondSave, findsOneWidget);
      expect(tester.widget<FilledButton>(secondSave).onPressed, isNull);
      final pending = await realIo(tester, () => scheduleFile().readAsString());
      expect(
        (jsonDecode(pending) as Map<String, dynamic>)['rpeByDayIndex'],
        isEmpty,
      );
      expect(find.text('Done · RPE 7'), findsNothing);
      expect(find.text('Done · RPE 6'), findsNothing);
    } finally {
      if (!release.isCompleted) release.complete();
      // Gate'i runAsync içinde bekleme: kuyruk fake-zone pump isteyebilir.
      await settleUntil(tester, () => settled, maxRounds: 40);
      expect(settled, isTrue);
      expect(gateError, isNull);
    }
    await settleUntil(
      tester,
      () =>
          find.text('Done · RPE 7').evaluate().isNotEmpty &&
          find.text('Done · RPE 6').evaluate().isNotEmpty,
      maxRounds: 40,
    );
    final stored = await realIo(
      tester,
      () => ProgramScheduleStore.forFile(scheduleFile()).read(),
    );
    expect(stored!.rpeByDayIndex, <int, int>{0: 7, 1: 6});
    expect(find.text('Done · RPE 7'), findsOneWidget);
    expect(find.text('Done · RPE 6'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await showWorkout(tester);
    expect(find.text('Done · RPE 7'), findsOneWidget);
    expect(find.text('Done · RPE 6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
