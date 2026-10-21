import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_connection.dart';
import 'package:gravita/app/account_data_directory.dart';
import 'package:gravita/app/account_store_epoch.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/calisthenics_course.dart';
import 'package:gravita/app/calisthenics_course_screen.dart';
import 'package:gravita/app/calisthenics_progress.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/movement_page.dart';
import 'package:gravita/app/program/program_builder.dart';
import 'package:gravita/app/program/program_model.dart';
import 'package:gravita/app/program/program_safety_notice.dart';
import 'package:gravita/app/program/program_schedule_store.dart';
import 'package:gravita/app/program/program_setup_screen.dart';
import 'package:gravita/app/program/program_signature.dart';
import 'package:gravita/app/program/program_store.dart';
import 'package:gravita/app/surface_widgets.dart';
import 'package:gravita/app/theme.dart';
import 'package:gravita/app/workout/workout_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/launch_harness.dart' show FakeSupportDir, settleUntil;
import 'support/locale_asset_harness.dart'
    show warmActualLocaleAssets, pumpActualLocaleReady;

// Candidate only: requires V1-MINIMAL-SAFETY-CANDIDATE plus the five real
// messages in all 14 packaged locale assets. No injected dictionary/store,
// private state access, production algorithm clone or weakened old oracle.
// Byte equality below is stronger than merely comparing file hashes.
const _guidanceId = 'g_d4fe4334d919';
const _swingId = 'g_967c950f4582';
const _reportId = 'g_e8ad76dfbee0';
const _requirementId = 'g_a660fcae9dfa';
const _guideId = 'g_2f860bb1e4c0';
const _criticalEnglish = <String, String>{
  _guidanceId:
      'Experience is self-reported; it does not establish readiness. The scheduled sets, repetitions and hold times are examples, not deadlines. Use only a familiar variation that you can enter and finish under control. You may use the lesson’s smaller dose, stop sooner and rest longer. A later week does not require an increase. End the task for pain, dizziness, unusual breathlessness or loss of control; do not retest symptoms with an easier version.',
  _swingId:
      'This sample plan may include a kettlebell swing. Its full setup and finish are not taught here. If unfamiliar, skip the swing; for a new generated plan, leave kettlebell unselected until you have learned it separately. Kettlebell deadlift or handling reading is not swing instruction.',
  _reportId:
      'I have already learned the kettlebell swing, including its setup and controlled finish. This is my own report, not an assessment by Gravita.',
  _requirementId:
      'Your plan includes a kettlebell swing. Before saving, confirm that you have learned its setup and controlled finish, or remove kettlebell from this generated plan and use the learning guides separately.',
  _guideId: 'Movement details and learning options',
};

typedef _Bytes = ({List<int>? inputs, List<int>? schedule});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentRepository content;
  late ProgramConfig config;
  late List<ProgramCatalogEntry> entries;
  late ProgramBuilder builder;
  late Map<String, Map<String, String>> dictionaries;
  late PathProviderPlatform originalProvider;
  late Directory root;
  late Directory support;
  final fixedNow = DateTime.utc(2040, 5, 10, 12);
  final setupStart = DateTime(2040, 5, 10);
  const first = '11111111-1111-4111-8111-111111111111';
  const second = '22222222-2222-4222-8222-222222222222';
  const beginner = ProgramInputs(
    availableEquipment: <String>{},
    daysPerWeek: 3,
    experience: ExperienceLevel.beginner,
  );
  const swingInputs = ProgramInputs(
    availableEquipment: <String>{'kettlebell'},
    daysPerWeek: 3,
    experience: ExperienceLevel.intermediate,
  );

  setUpAll(() async {
    // Real delegates and large rootBundle futures must start outside FakeAsync.
    await warmActualLocaleAssets();
    content = await ContentRepository.load(rootBundle);
    config = await ContentRepository.loadProgramConfig(rootBundle);
    entries = await content.programCatalogEntries();
    builder = ProgramBuilder(config: config, catalog: entries);
    for (final movement in content.catalogue.movements) {
      await content.catalogFor(movement.id);
    }
    dictionaries = <String, Map<String, String>>{};
    for (final locale in appSupportedLocales) {
      final tag = canonicalLocaleTag(locale.toLanguageTag());
      final raw =
          jsonDecode(await rootBundle.loadString('content/locales/$tag.json'))
              as Map<String, dynamic>;
      expect(raw['localeTag'], tag);
      dictionaries[tag] = (raw['messages'] as Map).cast<String, String>();
    }
  });

  setUp(() async {
    await AccountStoreEpochRegistry.resetForTest();
    originalProvider = PathProviderPlatform.instance;
    root = await Directory.systemTemp.createTemp('gravita-program-safety-');
    support = root;
    PathProviderPlatform.instance = FakeSupportDir(support.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalProvider;
    await AccountStoreEpochRegistry.resetForTest();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<T> io<T>(WidgetTester tester, Future<T> Function() operation) async {
    late T result;
    var completed = false;
    Object? failure;
    StackTrace? failureStack;
    // runAsync reports uncaught errors to the framework and returns null.
    // Capture inside its real zone, then rethrow in the calling test so that
    // an assertion keeps its original identity/stack instead of a late result.
    await tester.runAsync<void>(() async {
      try {
        result = await operation().timeout(const Duration(seconds: 8));
      } on Object catch (error, stack) {
        failure = error;
        failureStack = stack;
      } finally {
        completed = true;
      }
    });
    expect(completed, isTrue, reason: 'Program fixture IO did not complete');
    final error = failure;
    if (error != null) Error.throwWithStackTrace(error, failureStack!);
    return result;
  }

  Future<void> waitFor(
    WidgetTester tester,
    bool Function() ready,
    String reason,
  ) async {
    await settleUntil(tester, ready, maxRounds: 40);
    expect(ready(), isTrue, reason: reason);
    expect(tester.takeException(), isNull, reason: reason);
  }

  Future<void> drainAfterWidget(WidgetTester tester) async {
    var completed = false;
    Object? failure;
    StackTrace? failureStack;
    debugPrint('program-cleanup START: registry drain');
    // A failed assertion can leave the widget's admitted file work in the fake
    // zone. Drain it before the global real-zone teardown awaits the registry.
    final observed = AccountStoreEpochRegistry.resetForTest().then<void>(
      (_) => completed = true,
      onError: (Object error, StackTrace stack) {
        failure = error;
        failureStack = stack;
        completed = true;
      },
    );
    final watch = Stopwatch()..start();
    var turns = 0;
    while (!completed && watch.elapsedMilliseconds < 1500 && turns < 4096) {
      await tester.runAsync<void>(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
      );
      await tester.pump(const Duration(milliseconds: 80));
      turns++;
    }
    debugPrint(
      'program-cleanup registry drain: completed=$completed turns=$turns '
      'wallMs=${watch.elapsedMilliseconds}',
    );
    expect(
      completed,
      isTrue,
      reason: 'Program registry drain missed the 1500ms deadline',
    );
    await observed;
    final error = failure;
    if (error != null) Error.throwWithStackTrace(error, failureStack!);
    debugPrint('program-cleanup END: registry drain');
  }

  void prepare(WidgetTester tester, {Size size = const Size(900, 1200)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await drainAfterWidget(tester);
    });
  }

  Widget host(
    Widget page, {
    Locale locale = const Locale('en'),
    ThemeMode mode = ThemeMode.light,
    double scale = 1,
    String? owner,
    AccountConnection? connection,
  }) => AccountScope(
    connection: connection,
    currentUserId: owner,
    child: MaterialApp(
      key: UniqueKey(),
      theme: GravitaTheme.light,
      darkTheme: GravitaTheme.dark,
      themeMode: mode,
      themeAnimationDuration: Duration.zero,
      locale: locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      localeListResolutionCallback: resolveAppLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: page,
    ),
  );

  Future<void> showSetup(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    ThemeMode mode = ThemeMode.light,
    double scale = 1,
    String? owner,
    DateTime? scheduleStart,
  }) async {
    await tester.pumpWidget(
      host(
        ProgramSetupScreen.withClock(
          content: content,
          accountUserId: owner,
          now: () => scheduleStart ?? setupStart,
        ),
        locale: locale,
        mode: mode,
        scale: scale,
        owner: owner,
      ),
    );
    await pumpActualLocaleReady(tester);
    expect(find.byType(ProgramSetupScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  Future<void> showWorkout(
    WidgetTester tester, {
    String? owner,
    AccountConnection? connection,
    bool blocked = false,
  }) async {
    await tester.pumpWidget(
      host(
        WorkoutScreen.withClock(
          content: content,
          accountUserId: owner,
          now: () => fixedNow,
        ),
        owner: owner,
        connection: connection,
      ),
    );
    await pumpActualLocaleReady(tester);
    final ready = find.byKey(
      blocked ? WorkoutScreen.unavailableKey : WorkoutScreen.disclaimerKey,
    );
    await waitFor(tester, () => ready.evaluate().isNotEmpty, 'Workout load');
    expect(ready, findsOneWidget);
    expect(find.byKey(WorkoutScreen.emptyKey), findsNothing);
    expect(
      find.byKey(
        blocked ? WorkoutScreen.disclaimerKey : WorkoutScreen.unavailableKey,
      ),
      findsNothing,
    );
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    // A pushed route can retain the previous ListView during its transition.
    // Select the active route's outer vertical viewport, not a retained route
    // or the nested scrollable belonging to SelectableText.
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
    }, description: 'active route outer vertical Scrollable');
    await waitFor(tester, () {
      final elements = scrollable.evaluate().toList();
      if (elements.length != 1) return false;
      final route = ModalRoute.of(elements.single)!;
      return (route.animation == null ||
              route.animation!.status == AnimationStatus.completed) &&
          (route.secondaryAnimation == null ||
              route.secondaryAnimation!.status == AnimationStatus.dismissed);
    }, 'Active route viewport and transition must be ready');
    expect(scrollable, findsOneWidget);
    expect(scrollable.hitTestable(), findsOneWidget);
    if (target.evaluate().isEmpty) {
      // A ListView may have evicted a target above the current viewport.
      // Return by real drag gestures, then search downward with a finite budget.
      final state = tester.state<ScrollableState>(scrollable);
      var drags = 0;
      while (state.position.pixels > state.position.minScrollExtent + 1 &&
          drags < 300) {
        await tester.drag(scrollable, const Offset(0, 600));
        await tester.pump();
        drags++;
      }
      expect(
        state.position.pixels,
        lessThanOrEqualTo(state.position.minScrollExtent + 1),
      );
      await tester.scrollUntilVisible(
        target,
        240,
        scrollable: scrollable,
        maxScrolls: 300,
      );
    }
    await tester.ensureVisible(target);
    await tester.pump();
    expect(target, findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    await reveal(tester, target);
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target);
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  Finder reportTile() => find.byKey(ProgramSetupScreen.swingFamiliarityKey);
  Finder reportBox() =>
      find.descendant(of: reportTile(), matching: find.byType(Checkbox));

  Future<void> chooseExperience(WidgetTester tester, ExperienceLevel value) =>
      tapVisible(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is RadioListTile<ExperienceLevel> && widget.value == value,
        ),
      );

  Future<void> chooseEquipment(WidgetTester tester, String equipment) {
    // Use the actual catalogue-derived chip order; do not translate its label
    // in the test or invoke onSelected instead of the real hit target.
    final options = <String>{
      for (final movement in content.catalogue.movements) ...movement.equipment,
    }.toList()..sort();
    final index = options.indexOf(equipment);
    expect(index, greaterThanOrEqualTo(0));
    return tapVisible(
      tester,
      find
          .descendant(
            of: find.byKey(ProgramSetupScreen.equipmentKey),
            matching: find.byType(FilterChip),
          )
          .at(index),
    );
  }

  Future<void> configure(WidgetTester tester, ProgramInputs inputs) async {
    if (inputs.experience != ExperienceLevel.beginner) {
      await chooseExperience(tester, inputs.experience);
    }
    for (final equipment in inputs.availableEquipment) {
      await chooseEquipment(tester, equipment);
    }
    for (var day = 3; day < inputs.daysPerWeek; day++) {
      await tapVisible(tester, find.byIcon(Icons.add_circle_outline));
    }
    for (var day = 3; day > inputs.daysPerWeek; day--) {
      await tapVisible(tester, find.byIcon(Icons.remove_circle_outline));
    }
  }

  Future<void> submit(WidgetTester tester) async {
    final button = find.byKey(ProgramSetupScreen.buildButtonKey);
    await reveal(tester, button);
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tapVisible(tester, button);
  }

  Future<void> expectBlockedSwing(WidgetTester tester) async {
    final requirement = find.byKey(ProgramSetupScreen.swingRequirementKey);
    final build = find.byKey(ProgramSetupScreen.buildButtonKey);
    await waitFor(
      tester,
      () => requirement.evaluate().isNotEmpty,
      'Actual selected swing requires a correctable report',
    );
    await reveal(tester, build);
    // The previous inline warning remains visible during a second submit.
    // Once the button is mounted, also wait for that submit's async work to
    // release saving; warning presence alone does not establish readiness.
    debugPrint('program-blocked-state WAIT: saving released');
    await waitFor(
      tester,
      () =>
          build.evaluate().isNotEmpty &&
          tester.widget<FilledButton>(build).onPressed != null,
      'Blocked swing must release saving and remain correctable',
    );
    debugPrint('program-blocked-state END: saving released');
    expect(tester.widget<FilledButton>(build).onPressed, isNotNull);
    await reveal(tester, requirement);
    expect(find.byType(ProgramSetupScreen), findsOneWidget);
    expect(find.byType(WorkoutScreen), findsNothing);
    expect(
      find.byType(SnackBar),
      findsNothing,
      reason: 'A swallowed storage error is not the inline swing decision.',
    );
    expect(
      tester.widget<Text>(requirement).data,
      _criticalEnglish[_requirementId],
    );
    expect(
      find.ancestor(
        of: requirement,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
      ),
      findsOneWidget,
    );
    await reveal(tester, reportBox());
    expect(tester.widget<CheckboxListTile>(reportTile()).value, isFalse);
    expect(tester.widget<CheckboxListTile>(reportTile()).onChanged, isNotNull);
  }

  Future<void> expectWorkout(WidgetTester tester) async {
    await waitFor(
      tester,
      () =>
          find.byType(WorkoutScreen).evaluate().isNotEmpty &&
          find.byKey(WorkoutScreen.disclaimerKey).evaluate().isNotEmpty &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty,
      'Saved program must actually render, not just navigate',
    );
    expect(find.byKey(WorkoutScreen.unavailableKey), findsNothing);
    expect(find.byKey(WorkoutScreen.emptyKey), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  }

  File inputFile([String? owner]) =>
      File('${accountDataDirectory(support, owner).path}/program_inputs.json');
  File scheduleFile([String? owner]) => File(
    '${accountDataDirectory(support, owner).path}/program_schedule.json',
  );

  Future<_Bytes> bytes(WidgetTester tester, [String? owner]) => io(
    tester,
    () async => (
      inputs: await inputFile(owner).exists()
          ? await inputFile(owner).readAsBytes()
          : null,
      schedule: await scheduleFile(owner).exists()
          ? await scheduleFile(owner).readAsBytes()
          : null,
    ),
  );

  Future<void> expectBytes(
    WidgetTester tester,
    _Bytes before, [
    String? owner,
  ]) async {
    final after = await bytes(tester, owner);
    expect(
      after.inputs,
      before.inputs,
      reason: 'Input bytes, including formatting, must be preserved.',
    );
    expect(
      after.schedule,
      before.schedule,
      reason:
          'Signature, dates, indices, RPE and formatting must be preserved.',
    );
  }

  Future<void> expectNoWrites(WidgetTester tester) async {
    final current = await bytes(tester);
    expect(current.inputs, isNull);
    expect(current.schedule, isNull);
    final files = await io(
      tester,
      () => support
          .list(recursive: true, followLinks: false)
          .where((entity) => entity is File)
          .map((entity) => entity.path)
          .toList(),
    );
    expect(
      files,
      isEmpty,
      reason: 'No temporary or partial program write either.',
    );
  }

  Set<String> selected(WorkoutProgram program) => <String>{
    for (final day in program.days)
      for (final exercise in day.exercises) exercise.movementId,
  };

  Future<ProgramSchedule> seed(
    WidgetTester tester,
    ProgramInputs inputs, {
    String? owner,
  }) => io(tester, () async {
    final program = builder.build(inputs);
    final saved = ProgramSchedule(
      dates: scheduleProgram(
        program: program,
        startDate: DateTime.utc(2040, 5, 10),
        daysPerWeek: inputs.daysPerWeek,
      ),
      rpeByDayIndex: <int, int>{1: 7, 10: 4, program.days.length - 1: 9},
      programSignature: programSignature(inputs, program),
    );
    await (await ProgramStore.open(accountUserId: owner)).write(inputs);
    await (await ProgramScheduleStore.open(accountUserId: owner)).write(saved);
    // Noncanonical whitespace makes even a decode/re-encode observable.
    for (final file in [inputFile(owner), scheduleFile(owner)]) {
      final raw = jsonDecode(await file.readAsString());
      await file.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(raw)}\n',
      );
    }
    return saved;
  });

  Future<void> checkSaved(WidgetTester tester, ProgramInputs expected) =>
      io(tester, () async {
        final saved = await (await ProgramStore.open()).read();
        expect(saved, isNotNull);
        expect(saved!.experience, expected.experience);
        expect(saved.availableEquipment, expected.availableEquipment);
        expect(saved.daysPerWeek, expected.daysPerWeek);
        final raw = jsonDecode(await inputFile().readAsString()) as Map;
        expect(raw.keys.toSet(), <String>{
          'schemaVersion',
          'availableEquipment',
          'daysPerWeek',
          'experience',
        });
        expect(raw['schemaVersion'], 1);
        final program = builder.build(saved);
        final schedule = await (await ProgramScheduleStore.open()).read();
        expect(schedule, isNotNull);
        expect(schedule!.programSignature, programSignature(expected, program));
        expect(schedule.rpeByDayIndex, isEmpty);
        expect(schedule.dates, hasLength(program.days.length));
        final start = schedule.dates.first;
        expect(start, DateTime(start.year, start.month, start.day));
        expect(start, setupStart);
        expect(
          schedule.dates,
          scheduleProgram(
            program: program,
            startDate: start,
            daysPerWeek: expected.daysPerWeek,
          ),
        );
      });

  Future<void> expectNotice(
    WidgetTester tester,
    String tag, {
    required bool swing,
  }) async {
    await reveal(tester, find.byKey(ProgramSafetyNotice.guidanceKey));
    expect(
      tester.widget<NoteCard>(find.byKey(ProgramSafetyNotice.guidanceKey)).text,
      dictionaries[tag]![_guidanceId],
    );
    final boundary = find.byKey(ProgramSafetyNotice.swingKey);
    if (swing) {
      await reveal(tester, boundary);
      expect(
        tester.widget<NoteCard>(boundary).text,
        dictionaries[tag]![_swingId],
      );
    } else {
      expect(boundary, findsNothing);
    }
  }

  Future<void> rejectSetup(WidgetTester tester) async {
    final build = find.byKey(ProgramSetupScreen.buildButtonKey);
    await waitFor(
      tester,
      () =>
          find.byType(SnackBar).evaluate().isNotEmpty &&
          build.evaluate().isNotEmpty &&
          tester.widget<FilledButton>(build).onPressed != null,
      'Protected history must reject setup and release saving state',
    );
    expect(find.byType(WorkoutScreen), findsNothing);
    expect(find.textContaining('could not be saved'), findsOneWidget);
    expect(find.byType(ProgramSetupScreen), findsOneWidget);
  }

  testWidgets('P00 fixture IO preserves the original error and stack', (
    tester,
  ) async {
    final sentinel = StateError('program-io-regression-sentinel');
    final origin = StackTrace.fromString('program-io-regression-origin');
    Object? caught;
    StackTrace? caughtStack;
    try {
      await io<void>(tester, () => Future<void>.error(sentinel, origin));
    } on Object catch (error, stack) {
      caught = error;
      caughtStack = stack;
    }
    expect(caught, same(sentinel));
    expect(caughtStack.toString(), origin.toString());
    expect(tester.takeException(), isNull);
  });

  testWidgets('P00 injected setup clock preserves non-midnight timestamp', (
    tester,
  ) async {
    prepare(tester);
    final start = DateTime(2040, 5, 10, 12, 34, 56, 789, 123);
    await showSetup(tester, scheduleStart: start);
    await submit(tester);
    await expectWorkout(tester);
    final saved = await io(
      tester,
      () async => (await ProgramScheduleStore.open()).read(),
    );
    expect(saved, isNotNull);
    expect(saved!.dates.first, start);
    expect(saved.dates.first.isUtc, isFalse);
    expect(tester.takeException(), isNull);
  });

  test('P01 actual catalogue excludes advanced/elite at both v1 levels', () {
    final allEquipment = <String>{
      for (final entry in entries) ...entry.equipment,
    };
    final advanced = entries
        .where((entry) => entry.level == 'advanced' || entry.level == 'elite')
        .map((e) => e.id)
        .toSet();
    expect(
      advanced,
      containsAll(<String>{'toes_to_bar', 'wall_handstand', 'tuck_planche'}),
      reason:
          'The exclusion test must not pass because its adversaries vanished.',
    );
    for (final level in ExperienceLevel.values) {
      for (var days = 2; days <= 6; days++) {
        final inputs = ProgramInputs(
          availableEquipment: allEquipment,
          daysPerWeek: days,
          experience: level,
        );
        final program = builder.build(inputs);
        expect(program.days, hasLength(8 * days));
        expect(selected(program), isNotEmpty);
        expect(selected(program).intersection(advanced), isEmpty);
        for (final id in selected(program)) {
          final entry = entries.singleWhere((entry) => entry.id == id);
          expect(level.acceptedCatalogLevels, contains(entry.level));
        }
      }
    }
  });

  testWidgets('P02 actual swing without own report writes neither file', (
    tester,
  ) async {
    prepare(tester);
    expect(selected(builder.build(swingInputs)), contains('kb_swing'));
    await showSetup(tester);
    await configure(tester, swingInputs);
    await reveal(tester, reportBox());
    expect(tester.widget<CheckboxListTile>(reportTile()).value, isFalse);
    await submit(tester);
    await expectBlockedSwing(tester);
    await expectNoWrites(tester);
    // A second real click must also be usable, not a stuck _saving branch.
    await submit(tester);
    await expectBlockedSwing(tester);
    await expectNoWrites(tester);
    await reveal(tester, reportBox());
    expect(reportBox().hitTestable(), findsOneWidget);
  });

  testWidgets('P03 explicit report saves v1 and resets on changed inputs', (
    tester,
  ) async {
    prepare(tester);
    await showSetup(tester);
    await configure(tester, swingInputs);
    await reveal(tester, reportBox());
    expect(
      tester
          .widget<Text>(
            find
                .descendant(of: reportTile(), matching: find.byType(Text))
                .first,
          )
          .data,
      _criticalEnglish[_reportId],
    );
    await tapVisible(tester, reportBox());
    expect(tester.widget<CheckboxListTile>(reportTile()).value, isTrue);
    await chooseExperience(tester, ExperienceLevel.beginner);
    await chooseExperience(tester, ExperienceLevel.intermediate);
    await reveal(tester, reportBox());
    expect(tester.widget<CheckboxListTile>(reportTile()).value, isFalse);
    await tapVisible(tester, reportBox());
    await chooseEquipment(tester, 'kettlebell');
    await chooseEquipment(tester, 'kettlebell');
    await reveal(tester, reportBox());
    expect(tester.widget<CheckboxListTile>(reportTile()).value, isFalse);
    await submit(tester);
    await expectBlockedSwing(tester);
    await expectNoWrites(tester);
    await tapVisible(tester, reportBox());
    await submit(tester);
    await expectWorkout(tester);
    await checkSaved(tester, swingInputs);
    await expectNotice(tester, 'en', swing: true);
    final before = await bytes(tester);
    // The report is transient even when an identical plan already exists.
    await showSetup(tester);
    await configure(tester, swingInputs);
    await reveal(tester, reportBox());
    expect(tester.widget<CheckboxListTile>(reportTile()).value, isFalse);
    await submit(tester);
    await expectBlockedSwing(tester);
    await expectBytes(tester, before);
    await tapVisible(tester, reportBox());
    await submit(tester);
    await expectWorkout(tester);
    await expectBytes(tester, before);
  });

  testWidgets('P04 no-swing results save despite coarse KB preview', (
    tester,
  ) async {
    prepare(tester);
    final allEquipment = <String>{
      for (final entry in entries) ...entry.equipment,
    };
    final cases = <ProgramInputs>[
      const ProgramInputs(
        availableEquipment: <String>{'kettlebell'},
        daysPerWeek: 3,
        experience: ExperienceLevel.beginner,
      ),
      const ProgramInputs(
        availableEquipment: <String>{},
        daysPerWeek: 3,
        experience: ExperienceLevel.intermediate,
      ),
      const ProgramInputs(
        availableEquipment: <String>{'dumbbells', 'kettlebell'},
        daysPerWeek: 3,
        experience: ExperienceLevel.intermediate,
      ),
      ProgramInputs(
        availableEquipment: allEquipment,
        daysPerWeek: 3,
        experience: ExperienceLevel.intermediate,
      ),
    ];
    for (var index = 0; index < cases.length; index++) {
      final inputs = cases[index];
      support = await io(
        tester,
        () => Directory('${root.path}/P04-$index').create(),
      );
      PathProviderPlatform.instance = FakeSupportDir(support.path);
      expect(
        selected(builder.build(inputs)),
        isNot(contains('kb_swing')),
        reason:
            'This is an actual no-swing control, not a coarse preview claim.',
      );
      await showSetup(tester);
      await configure(tester, inputs);
      if (index < 2) {
        expect(reportTile(), findsNothing);
        await expectNotice(tester, 'en', swing: false);
      } else {
        await reveal(tester, reportBox());
        expect(tester.widget<CheckboxListTile>(reportTile()).value, isFalse);
        await expectNotice(tester, 'en', swing: true);
      }
      await submit(tester);
      await expectWorkout(tester);
      await checkSaved(tester, inputs);
      await expectNotice(tester, 'en', swing: false);
    }
  });

  testWidgets('P05 exact signed and malformed histories are preserved', (
    tester,
  ) async {
    prepare(tester);
    // Literal byte-for-byte v1 binding oracle, independent of the builder.
    const signatureInputs = ProgramInputs(
      availableEquipment: <String>{},
      daysPerWeek: 3,
      experience: ExperienceLevel.beginner,
    );
    const signatureProgram = WorkoutProgram(
      programId: 'foundation.v1',
      days: [
        ProgramDay(
          weekNumber: 1,
          dayNumber: 1,
          isDeload: false,
          exercises: [
            PrescribedExercise(
              movementId: 'push_up',
              sets: 3,
              isHold: false,
              targetReps: 8,
              restSeconds: 75,
              isLiveMeasured: true,
            ),
          ],
        ),
      ],
    );
    expect(
      programSignature(signatureInputs, signatureProgram),
      '{"bindingVersion":1,"calendarPolicy":"civil-week-v1","equipment":[],"daysPerWeek":3,"experience":"beginner","programId":"foundation.v1","days":[{"week":1,"day":1,"deload":false,"exercises":[{"movementId":"push_up","sets":3,"hold":false,"reps":8,"seconds":null,"restSeconds":75,"live":true}]}]}',
    );
    final original = await seed(tester, beginner);
    final before = await bytes(tester);
    await showWorkout(tester);
    await tapVisible(
      tester,
      find
          .byKey(
            const ValueKey<String>('workout.movementGuide.bodyweight_squat'),
          )
          .first,
    );
    await waitFor(
      tester,
      () => find.byType(MovementPage).evaluate().isNotEmpty,
      'Movement details opened',
    );
    expect(
      tester.widget<MovementPage>(find.byType(MovementPage)).movement.id,
      'bodyweight_squat',
    );
    await expectBytes(tester, before);
    await showSetup(tester);
    await tapVisible(tester, find.byIcon(Icons.add_circle_outline));
    await submit(tester);
    await rejectSetup(tester);
    await expectBytes(tester, before);
    final reread = await io(
      tester,
      () async => (await ProgramScheduleStore.open()).read(),
    );
    expect(reread!.dates, original.dates);
    expect(reread.rpeByDayIndex, <int, int>{1: 7, 10: 4, 23: 9});
    expect(reread.programSignature, original.programSignature);

    for (final fault in <String>[
      'missingInputs',
      'missingSchedule',
      'corruptInputs',
      'corruptSchedule',
      'unknownInputs',
      'unknownSchedule',
      'unsigned',
    ]) {
      support = await io(
        tester,
        () => Directory('${root.path}/P05-$fault').create(),
      );
      PathProviderPlatform.instance = FakeSupportDir(support.path);
      await seed(tester, beginner);
      await io(tester, () async {
        if (fault == 'missingInputs') {
          await inputFile().delete();
        } else if (fault == 'missingSchedule') {
          await scheduleFile().delete();
        } else if (fault.startsWith('corrupt')) {
          await (fault.endsWith('Inputs') ? inputFile() : scheduleFile())
              .writeAsString('{"incomplete":');
        } else {
          final file = fault.endsWith('Inputs') ? inputFile() : scheduleFile();
          final raw =
              jsonDecode(await file.readAsString()) as Map<String, dynamic>;
          if (fault == 'unsigned') {
            raw.remove('programSignature');
          } else {
            raw['schemaVersion'] = 2;
          }
          await file.writeAsString(
            const JsonEncoder.withIndent('  ').convert(raw),
          );
        }
      });
      final protected = await bytes(tester);
      await showWorkout(tester, blocked: true);
      await expectBytes(tester, protected);
      await showSetup(tester);
      await submit(tester);
      await rejectSetup(tester);
      await expectBytes(tester, protected);
    }
  });

  testWidgets('P06 saved v1 swing remains readable with explicit skip notice', (
    tester,
  ) async {
    prepare(tester);
    expect(selected(builder.build(swingInputs)), contains('kb_swing'));
    final original = await seed(tester, swingInputs);
    final before = await bytes(tester);
    await showWorkout(tester);
    await expectNotice(tester, 'en', swing: true);
    expect(
      _criticalEnglish[_swingId],
      contains('If unfamiliar, skip the swing'),
    );
    expect(_criticalEnglish[_swingId], contains('not taught here'));
    expect(
      _criticalEnglish[_swingId],
      contains(
        'Kettlebell deadlift or handling reading is not swing instruction.',
      ),
    );
    await reveal(tester, find.byKey(ProgramSafetyNotice.swingKey));
    expect(reportTile(), findsNothing);
    await tapVisible(
      tester,
      find
          .byKey(const ValueKey<String>('workout.movementGuide.kb_swing'))
          .first,
    );
    await waitFor(
      tester,
      () => find.byType(MovementPage).evaluate().isNotEmpty,
      'Existing swing details remain readable',
    );
    final page = tester.widget<MovementPage>(find.byType(MovementPage));
    expect(page.movement.id, 'kb_swing');
    expect(page.onStartSession, isNull);
    expect(find.byKey(MovementPage.startSessionKey), findsNothing);
    expect(
      find.byKey(MovementPage.learningGuideKey),
      findsNothing,
      reason: 'A deadlift/handling pathway is not swing instruction.',
    );
    await expectBytes(tester, before);
    final saved = await io(
      tester,
      () async => (await ProgramScheduleStore.open()).read(),
    );
    expect(saved!.programSignature, original.programSignature);
    expect(saved.dates, original.dates);
    expect(saved.rpeByDayIndex, original.rpeByDayIndex);
  });

  testWidgets('P07 actual guide route retains owner/epoch fences on switch', (
    tester,
  ) async {
    bool settledCurrentRoute(Element element) {
      final route = ModalRoute.of(element);
      return route?.isCurrent == true &&
          (route!.animation == null ||
              route.animation!.status == AnimationStatus.completed) &&
          (route.secondaryAnimation == null ||
              route.secondaryAnimation!.status == AnimationStatus.dismissed);
    }

    Finder currentPage(Type type) => find.byElementPredicate(
      (element) =>
          element.widget.runtimeType == type &&
          ModalRoute.of(element)?.isCurrent == true,
      description: 'current $type route page',
    );

    Future<void> backFromTo({required Type from, required Type to}) async {
      final source = currentPage(from);
      await waitFor(tester, () {
        final elements = source.evaluate().toList();
        return elements.length == 1 && settledCurrentRoute(elements.single);
      }, '$from must be the settled current route before Back');
      expect(source, findsOneWidget);
      final sourceElement = source.evaluate().single;
      final sourceRoute = ModalRoute.of(sourceElement)!;
      final appBar = find.descendant(of: source, matching: find.byType(AppBar));
      expect(appBar, findsOneWidget);
      final back = find.descendant(
        of: appBar,
        matching: find.byType(BackButton),
      );
      expect(back, findsOneWidget);
      expect(
        find.descendant(
          of: back,
          matching: find.byTooltip(
            MaterialLocalizations.of(sourceElement).backButtonTooltip,
          ),
        ),
        findsOneWidget,
      );
      expect(back.hitTestable(), findsOneWidget);
      // Use the actual public AppBar action. Neither a global tooltip match
      // nor a direct Navigator.pop establishes which route's control was used.
      await tester.tap(back);
      await tester.pump();
      final destination = currentPage(to);
      final retiredSource = find.byType(from, skipOffstage: false);
      await waitFor(tester, () {
        final elements = destination.evaluate().toList();
        return elements.length == 1 &&
            settledCurrentRoute(elements.single) &&
            retiredSource.evaluate().isEmpty &&
            !sourceRoute.isActive;
      }, '$from must retire and $to must become the settled current route');
      expect(retiredSource, findsNothing);
      expect(sourceRoute.isActive, isFalse);
      expect(destination, findsOneWidget);
    }

    prepare(tester);
    await io(tester, () async {
      await AccountStoreEpochRegistry.enableManagedAdmission();
      await AccountStoreEpochRegistry.activate(first).ready;
    });
    await seed(tester, beginner, owner: first);
    await io(tester, () => AccountStoreEpochRegistry.activate(second).ready);
    await seed(tester, beginner, owner: second);
    await io(tester, () => AccountStoreEpochRegistry.activate(first).ready);
    final beforeA = await bytes(tester, first);
    final beforeB = await bytes(tester, second);
    final staleInputs = await io(
      tester,
      () => ProgramStore.open(accountUserId: first),
    );
    final staleSchedule = await io(
      tester,
      () => ProgramScheduleStore.open(accountUserId: first),
    );
    final staleCourse = await io(
      tester,
      () =>
          ContentRepository.openCalisthenicsProgressStore(accountUserId: first),
    );
    final owner = ValueNotifier<String?>(first);
    final sessions = StreamController<void>.broadcast(sync: true);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await sessions.close();
      owner.dispose();
    });
    final connection = AccountConnection(
      userId: owner,
      ownerSessionChanges: sessions.stream,
      pageBuilder: (_) => const SizedBox.shrink(),
    );
    await showWorkout(tester, owner: first, connection: connection);
    final retainedWorkoutRoute = ModalRoute.of(
      find.byType(WorkoutScreen).evaluate().single,
    );
    await tapVisible(
      tester,
      find
          .byKey(
            const ValueKey<String>('workout.movementGuide.bodyweight_squat'),
          )
          .first,
    );
    await waitFor(
      tester,
      () => find.byType(MovementPage).evaluate().isNotEmpty,
      'Workout day opens actual MovementPage',
    );
    final page = tester.widget<MovementPage>(find.byType(MovementPage));
    expect(page.accountUserId, first);
    expect(page.content, same(content));
    expect(page.movement.id, 'bodyweight_squat');
    expect(page.onStartSession, isNull);
    expect(find.byKey(MovementPage.startSessionKey), findsNothing);
    expect(
      content.calisthenicsCourse.guideFor('bodyweight_squat')!.kind,
      MovementGuideKind.practice,
    );
    expect(
      content.calisthenicsCourse.guideFor('hanging_leg_raise')!.kind,
      MovementGuideKind.preparation,
    );
    expect(
      content.calisthenicsCourse.guideFor('wall_handstand')!.kind,
      MovementGuideKind.readingOnly,
    );
    await tapVisible(tester, find.byKey(const Key('movement.guide.cal-08')));
    await waitFor(
      tester,
      () => find.byType(CalisthenicsLessonScreen).evaluate().isNotEmpty,
      'Movement guide opens actual course route',
    );
    final lessonScreen = tester.widget<CalisthenicsLessonScreen>(
      find.byType(CalisthenicsLessonScreen),
    );
    expect(lessonScreen.lesson.id, 'cal-08');
    expect(lessonScreen.lesson.learningOnly, isFalse);
    expect(
      lessonScreen.storeLoader,
      isNull,
      reason: 'Do not replace the real account store with a test loader.',
    );
    final confirm = find.byKey(const Key('calisthenics.confirm'));
    await reveal(tester, confirm);
    await waitFor(
      tester,
      () => tester.widget<CheckboxListTile>(confirm).onChanged != null,
      'A course store loaded under the actual inherited owner',
    );
    final aProgress = await io(tester, staleCourse.load);
    expect(
      aProgress
          .forLesson(lessonScreen.lesson, lessonScreen.course.version)!
          .state,
      CalisthenicsLessonState.seen,
    );
    await tapVisible(tester, find.byKey(const Key('calisthenics.prepared')));
    final aFilesBefore = await io(tester, () async {
      final result = <String, List<int>>{};
      await for (final entity in accountDataDirectory(
        support,
        first,
      ).list(recursive: true)) {
        if (entity is File) result[entity.path] = await entity.readAsBytes();
      }
      return result;
    });
    expect(aFilesBefore, isNotEmpty);
    await io(tester, () => AccountStoreEpochRegistry.activate(second).ready);
    owner.value = second;
    sessions.add(null);
    await tester.pump();
    await reveal(tester, confirm);
    await waitFor(
      tester,
      () => tester.widget<CheckboxListTile>(confirm).onChanged != null,
      'B course reload finishes without retaining A preparation/report',
    );
    expect(tester.widget<CheckboxListTile>(confirm).value, isFalse);
    await reveal(tester, find.byKey(const Key('calisthenics.prepared')));
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('calisthenics.prepared')),
          )
          .value,
      isFalse,
    );
    await io(tester, () async {
      expect(() => AccountStoreEpochRegistry.capture(first), throwsStateError);
      final bCourse = await ContentRepository.openCalisthenicsProgressStore(
        accountUserId: second,
      );
      final bProgress = await bCourse.load();
      expect(
        bProgress
            .forLesson(lessonScreen.lesson, lessonScreen.course.version)!
            .state,
        CalisthenicsLessonState.seen,
      );
      expect(
        bProgress
            .forLesson(lessonScreen.lesson, lessonScreen.course.version)!
            .practiceCount,
        0,
      );
      await expectLater(
        staleCourse.markPractised(lessonScreen.course, lessonScreen.lesson),
        throwsStateError,
      );
      await expectLater(staleInputs.write(beginner), throwsStateError);
      await expectLater(
        staleSchedule.update(
          expectedSignature: programSignature(
            beginner,
            builder.build(beginner),
          ),
          transform: (current) => current.withRpe(0, 10),
        ),
        throwsStateError,
      );
      for (final entry in aFilesBefore.entries) {
        expect(await File(entry.key).readAsBytes(), entry.value);
      }
    });
    await expectBytes(tester, beforeA, first);
    await expectBytes(tester, beforeB, second);
    // A fresh session with the SAME UUID must retire the old store handles
    // and reset the guide's transient preparation, not just compare strings.
    await tapVisible(tester, find.byKey(const Key('calisthenics.prepared')));
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('calisthenics.prepared')),
          )
          .value,
      isTrue,
    );
    await io(tester, () async {
      final oldEpoch = AccountStoreEpochRegistry.capture(second);
      final oldB = await ProgramScheduleStore.open(accountUserId: second);
      final fresh = AccountStoreEpochRegistry.activate(second);
      await fresh.ready;
      expect(fresh, isNot(same(oldEpoch)));
      expect(oldEpoch.checkCurrent, throwsStateError);
      await expectLater(
        oldB.update(
          expectedSignature: programSignature(
            beginner,
            builder.build(beginner),
          ),
          transform: (current) => current.withRpe(0, 10),
        ),
        throwsStateError,
      );
    });
    sessions.add(null);
    await tester.pump();
    await reveal(tester, confirm);
    await waitFor(
      tester,
      () => tester.widget<CheckboxListTile>(confirm).onChanged != null,
      'Same-UUID fresh owner reload completes',
    );
    await reveal(tester, find.byKey(const Key('calisthenics.prepared')));
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('calisthenics.prepared')),
          )
          .value,
      isFalse,
    );
    await expectBytes(tester, beforeA, first);
    await expectBytes(tester, beforeB, second);
    // Keep the obsolete A workout route alive deliberately: an actual RPE
    // action must fail rather than opening B's store under the new scope.
    await backFromTo(from: CalisthenicsLessonScreen, to: MovementPage);
    await backFromTo(from: MovementPage, to: WorkoutScreen);
    expect(
      ModalRoute.of(currentPage(WorkoutScreen).evaluate().single),
      same(retainedWorkoutRoute),
    );
    expect(
      tester.widget<WorkoutScreen>(currentPage(WorkoutScreen)).accountUserId,
      first,
    );
    await tapVisible(
      tester,
      find.byKey(const ValueKey<String>('workout.markDone.1.1')),
    );
    await tapVisible(tester, find.widgetWithText(ChoiceChip, '7'));
    await tapVisible(
      tester,
      find.byKey(const ValueKey<String>('workout.saveRpe.1.1')),
    );
    await waitFor(
      tester,
      () => find.byType(SnackBar).evaluate().isNotEmpty,
      'Stale captured A cannot write successor account',
    );
    expect(find.textContaining('save could not be confirmed'), findsOneWidget);
    await expectBytes(tester, beforeA, first);
    await expectBytes(tester, beforeB, second);
  });

  testWidgets('P08 fixed v1 numbers coexist with honest voluntary-dose copy', (
    tester,
  ) async {
    prepare(tester);
    final inputs = ProgramInputs(
      availableEquipment: <String>{
        for (final entry in entries) ...entry.equipment,
      },
      daysPerWeek: 6,
      experience: ExperienceLevel.intermediate,
    );
    final program = builder.build(inputs);
    const reps = <int>[8, 9, 10, 8, 11, 12, 12, 8];
    const holds = <int>[20, 25, 30, 20, 35, 40, 45, 20];
    const sets = <int>[3, 3, 3, 2, 3, 3, 3, 2];
    for (var week = 1; week <= 8; week++) {
      final days = program.days.where((day) => day.weekNumber == week).toList();
      expect(days, hasLength(6));
      final exercises = days.expand((day) => day.exercises).toList();
      expect(exercises.where((e) => e.isHold), isNotEmpty);
      expect(exercises.where((e) => !e.isHold), isNotEmpty);
      for (final day in days) {
        expect(day.isDeload, week == 4 || week == 8);
        for (final exercise in day.exercises) {
          expect(exercise.sets, sets[week - 1]);
          expect(
            exercise.isHold ? exercise.targetHoldSeconds : exercise.targetReps,
            exercise.isHold ? holds[week - 1] : reps[week - 1],
          );
          expect(exercise.restSeconds, exercise.isHold ? 60 : 75);
        }
      }
    }
    await seed(tester, inputs);
    final before = await bytes(tester);
    await showWorkout(tester);
    await expectNotice(tester, 'en', swing: false);
    final copy = tester
        .widget<NoteCard>(find.byKey(ProgramSafetyNotice.guidanceKey))
        .text;
    for (final phrase in <String>[
      'self-reported; it does not establish readiness',
      'examples, not deadlines',
      'smaller dose, stop sooner and rest longer',
      'A later week does not require an increase',
      'End the task for pain, dizziness, unusual breathlessness or loss of control',
      'do not retest symptoms with an easier version',
    ]) {
      expect(copy, contains(phrase));
    }
    expect(copy, isNot(contains('unsafe progression')));
    for (final week in <int>[1, 4, 6, 8]) {
      final header = find.text(
        week == 4 || week == 8 ? 'WEEK $week — DELOAD' : 'WEEK $week',
      );
      await reveal(tester, header);
    }
    await expectBytes(tester, before);
  });

  // Keep P09 selectable as a group, while each locale has the normal
  // runner timeout and exactly four unchanged light/dark x 2x/3x vectors.
  for (final locale in appSupportedLocales) {
    final tag = canonicalLocaleTag(locale.toLanguageTag());
    testWidgets('P09 $tag real resources at 320/light-dark/2x3x are reachable', (
      tester,
    ) async {
      prepare(tester, size: const Size(320, 900));
      final semantics = tester.ensureSemantics();
      try {
        expect(dictionaries.keys.toSet(), <String>{
          'tr',
          'en',
          'es-419',
          'pt-BR',
          'de',
          'fr',
          'ja',
          'ar',
          'it',
          'ko',
          'id',
          'pl',
          'hi',
          'zh-Hans',
        });
        for (final entry in _criticalEnglish.entries) {
          expect(
            dictionaries['en']![entry.key],
            entry.value,
            reason: 'The canonical source must actually be packaged.',
          );
        }
        expect(appSupportedLocales, hasLength(14));
        var index = 0;
        for (final entry in _criticalEnglish.entries) {
          final translated = dictionaries[tag]![entry.key];
          expect(translated, isNotNull, reason: '$tag missing ${entry.key}');
          expect(translated!.trim(), isNotEmpty);
          if (tag != 'en') {
            expect(
              translated,
              isNot(entry.value),
              reason: '$tag must not pass by copying English.',
            );
          }
        }
        final firstDay = builder
            .build(swingInputs)
            .days
            .singleWhere((day) => day.weekNumber == 1 && day.dayNumber == 1);
        expect(
          firstDay.exercises.where(
            (exercise) => exercise.movementId == 'bodyweight_squat',
          ),
          hasLength(1),
        );
        expect(content.catalogue.byId('bodyweight_squat'), isNotNull);
        for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
          for (final scale in <double>[2, 3]) {
            support = await io(
              tester,
              () => Directory('${root.path}/P09-${index++}').create(),
            );
            PathProviderPlatform.instance = FakeSupportDir(support.path);
            await showSetup(tester, locale: locale, mode: mode, scale: scale);
            final context = tester.element(find.byType(ProgramSetupScreen));
            expect(Localizations.localeOf(context), locale);
            expect(
              Directionality.of(context),
              tag == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            );
            expect(
              Theme.of(context).brightness,
              mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
            );
            expect(MediaQuery.textScalerOf(context).scale(10), scale * 10);
            expect(MediaQuery.of(context).disableAnimations, isTrue);
            await configure(tester, swingInputs);
            await expectNotice(tester, tag, swing: true);
            await submit(tester);
            final requirement = find.byKey(
              ProgramSetupScreen.swingRequirementKey,
            );
            final build = find.byKey(ProgramSetupScreen.buildButtonKey);
            await waitFor(
              tester,
              () => requirement.evaluate().isNotEmpty,
              '$tag $mode $scale inline requirement',
            );
            await reveal(tester, build);
            expect(tester.widget<FilledButton>(build).onPressed, isNotNull);
            await reveal(tester, requirement);
            expect(
              tester.widget<Text>(requirement).data,
              dictionaries[tag]![_requirementId],
            );
            expect(
              find.ancestor(
                of: requirement,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Semantics &&
                      widget.properties.liveRegion == true,
                ),
              ),
              findsOneWidget,
            );
            await expectNoWrites(tester);
            await reveal(tester, reportBox());
            final reportSemantics = tester
                .getSemantics(reportTile())
                .getSemanticsData();
            expect(
              reportSemantics.label,
              contains(dictionaries[tag]![_reportId]!),
            );
            expect(reportSemantics.hasAction(SemanticsAction.tap), isTrue);
            expect(
              tester.widget<CheckboxListTile>(reportTile()).value,
              isFalse,
            );
            // The tile owns keyboard activation; Flutter excludes its visual
            // Checkbox child from focus traversal. Keep using actual Tab/Space.
            await tabTo(tester, reportTile());
            await tester.sendKeyEvent(LogicalKeyboardKey.space);
            await tester.pump();
            expect(tester.widget<CheckboxListTile>(reportTile()).value, isTrue);
            await reveal(tester, build);
            expect(build.hitTestable(), findsOneWidget);
            final buildSemantics = tester
                .getSemantics(build)
                .getSemanticsData();
            expect(buildSemantics.label.trim(), isNotEmpty);
            expect(buildSemantics.hasAction(SemanticsAction.tap), isTrue);
            await tabTo(tester, build);
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pump();
            await expectWorkout(tester);
            await checkSaved(tester, swingInputs);
            await expectNotice(tester, tag, swing: true);
            // Week cards are lazy and repeat movement keys across days. Keep
            // both queries empty-safe until reveal mounts the actual first day.
            final firstDayCard = find.ancestor(
              of: find.byKey(const ValueKey<String>('workout.markDone.1.1')),
              matching: find.byType(GravitaCard),
            );
            final guide = find.descendant(
              of: firstDayCard,
              matching: find.byKey(
                const ValueKey<String>(
                  'workout.movementGuide.bodyweight_squat',
                ),
              ),
            );
            await reveal(tester, guide);
            expect(firstDayCard, findsOneWidget);
            expect(guide, findsOneWidget);
            expect(tester.widget<TextButton>(guide).onPressed, isNotNull);
            expect(guide.hitTestable(), findsOneWidget);
            final guideSemantics = tester
                .getSemantics(guide)
                .getSemanticsData();
            expect(
              guideSemantics.label,
              contains(dictionaries[tag]![_guideId]!),
            );
            expect(guideSemantics.hasAction(SemanticsAction.tap), isTrue);
            await tabTo(tester, guide);
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pump();
            await waitFor(
              tester,
              () => find.byType(MovementPage).evaluate().isNotEmpty,
              '$tag $mode $scale keyboard learning navigation',
            );
            expect(
              tester
                  .widget<MovementPage>(find.byType(MovementPage))
                  .movement
                  .id,
              'bodyweight_squat',
            );
            expect(find.byKey(MovementPage.startSessionKey), findsNothing);
            expect(
              tester.takeException(),
              isNull,
              reason:
                  '$tag $mode $scale must not clip with a framework overflow.',
            );
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          }
        }
        expect(index, 4);
        expect(
          index * appSupportedLocales.length,
          56,
          reason:
              'All 14 P09 locale registrations retain four layout vectors each.',
        );
      } finally {
        semantics.dispose();
      }
    });
  }
}

Future<void> tabTo(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget, reason: 'Keyboard target must be mounted.');
  bool inside() {
    final targets = target.evaluate().toList();
    if (targets.length != 1) return false;
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    final targetElement = targets.single;
    var found = identical(focusContext, targetElement);
    focusContext.visitAncestorElements((ancestor) {
      if (identical(ancestor, targetElement)) found = true;
      return !found;
    });
    return found;
  }

  for (var turn = 0; turn < 100 && !inside(); turn++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  expect(
    target,
    findsOneWidget,
    reason: 'Keyboard target must remain mounted.',
  );
  expect(
    inside(),
    isTrue,
    reason: 'Real keyboard traversal must reach $target.',
  );
}
