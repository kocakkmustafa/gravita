import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/calisthenics_course_screen.dart';
import 'package:gravita/app/calisthenics_progress.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/home_screen.dart';
import 'package:gravita/app/library_screen.dart';
import 'package:gravita/app/library_strings.dart';
import 'package:gravita/app/localization/locale_delegate.dart';
import 'package:gravita/app/program/program_builder.dart';
import 'package:gravita/app/program/program_model.dart';
import 'package:gravita/app/program/program_schedule_store.dart';
import 'package:gravita/app/program/program_setup_screen.dart';
import 'package:gravita/app/program/program_signature.dart';
import 'package:gravita/app/program/program_store.dart';
import 'package:gravita/app/theme.dart';
import 'package:gravita/app/workout/workout_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/locale_asset_harness.dart' show warmActualLocaleAssets;
import 'support/launch_harness.dart' show FakeSupportDir, realIo, settleUntil;

// Authored for the coordinator's SDK lane; authoring is not a test result.
// The matrix uses production screens, packaged course/catalogue dictionaries
// and real stores in a new temporary directory. Only the support-directory
// platform seam is replaced. It checks selected visible regions and actions,
// rather than claiming every page, native glyph or screen-reader acceptance.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentRepository content;
  late ProgramBuilder builder;
  late PathProviderPlatform originalProvider;
  late Directory support;

  final now = DateTime.utc(2040, 5, 10, 12);
  const inputs = ProgramInputs(
    availableEquipment: <String>{},
    daysPerWeek: 3,
    experience: ExperienceLevel.beginner,
  );
  const layouts = <({String name, Size size, double scale})>[
    (name: 'phone', size: Size(320, 900), scale: 2),
    (name: 'wide', size: Size(1024, 768), scale: 1),
  ];

  setUpAll(() async {
    await warmActualLocaleAssets();
    content = await ContentRepository.load(rootBundle);
    builder = ProgramBuilder(
      config: await ContentRepository.loadProgramConfig(rootBundle),
      catalog: await content.programCatalogEntries(),
    );
  });

  setUp(() async {
    LocaleCatalogRegistry.clearForTesting();
    originalProvider = PathProviderPlatform.instance;
    support = await Directory.systemTemp.createTemp('gravita-locale-surface-');
    PathProviderPlatform.instance = FakeSupportDir(support.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalProvider;
    LocaleCatalogRegistry.clearForTesting();
    if (await support.exists()) await support.delete(recursive: true);
  });

  File inputFile() => File('${support.path}/program_inputs.json');
  File scheduleFile() => File('${support.path}/program_schedule.json');

  Future<void> withPrepared(
    WidgetTester tester,
    ({String name, Size size, double scale}) layout,
    Future<void> Function() body,
  ) async {
    tester.view.physicalSize = layout.size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    try {
      await body();
    } finally {
      // Unmount timers/observers before the framework's end-of-test checks.
      // Dispose our handle even if the body or unmount/pump fails.
      try {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      } finally {
        semantics.dispose();
      }
    }
  }

  Widget host(
    String tag,
    ({String name, Size size, double scale}) layout,
    Widget page,
  ) => MaterialApp(
    theme: GravitaTheme.light,
    locale: localeForAppTag(tag),
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    localeListResolutionCallback: resolveAppLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(layout.scale)),
      child: child!,
    ),
    home: page,
  );

  Future<void> show(
    WidgetTester tester,
    String tag,
    ({String name, Size size, double scale}) layout,
    Widget page,
    bool Function() ready,
  ) async {
    await tester.pumpWidget(host(tag, layout, page));
    await settleUntil(tester, ready, maxRounds: 40);
    expect(ready(), isTrue, reason: '$tag ${layout.name}: screen settled');
    await tester.pump();
  }

  void expectLocale(WidgetTester tester, Finder page, String tag) {
    final context = tester.element(page);
    expect(Localizations.localeOf(context).toLanguageTag(), tag);
    expect(
      Localizations.of<GravitaLocalizations>(
        context,
        GravitaLocalizations,
      )?.localeTag,
      tag,
      reason: 'The packaged Gravita dictionary must have loaded.',
    );
    expect(
      Directionality.of(context),
      tag == 'ar' ? TextDirection.rtl : TextDirection.ltr,
    );
  }

  void expectPaintedWithoutError(WidgetTester tester, String stage) {
    expect(tester.takeException(), isNull, reason: stage);
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final value = text.data ?? text.textSpan?.toPlainText() ?? '';
      expect(
        RegExp(r'\{[A-Za-z_][A-Za-z0-9_]*\}').hasMatch(value),
        isFalse,
        reason: '$stage: unresolved display placeholder: $value',
      );
    }
  }

  Future<void> reveal(WidgetTester tester, Finder target, String stage) async {
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
    expect(scrollable, findsOneWidget, reason: stage);
    if (target.evaluate().isEmpty) {
      // A previous reveal can evict a lazy target above the viewport.
      // Share the existing 100-scroll budget between return and search.
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
        reason: stage,
      );
      if (target.evaluate().isEmpty) {
        expect(usedScrolls, lessThan(100), reason: '$stage search budget');
        await tester.scrollUntilVisible(
          target,
          240,
          scrollable: scrollable,
          maxScrolls: 100 - usedScrolls,
        );
      }
    }
    // Center the target and render that scroll before reading hit geometry.
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
    await tester.pump();
    expect(target, findsOneWidget, reason: stage);
    expectPaintedWithoutError(tester, stage);
  }

  void expectTapSemantics(WidgetTester tester, Finder target) {
    final data = tester.getSemantics(target).getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.label.trim(), isNotEmpty);
  }

  Future<void> seedProgram(WidgetTester tester) => realIo(tester, () async {
    final program = builder.build(inputs);
    await ProgramStore.forFile(inputFile()).write(inputs);
    await ProgramScheduleStore.forFile(scheduleFile()).write(
      ProgramSchedule(
        dates: scheduleProgram(
          program: program,
          startDate: now,
          daysPerWeek: inputs.daysPerWeek,
        ),
        rpeByDayIndex: const <int, int>{},
        programSignature: programSignature(inputs, program),
      ),
    );
  });

  Future<({List<int> inputs, List<int> schedule})> programBytes(
    WidgetTester tester,
  ) => realIo(
    tester,
    () async => (
      inputs: await inputFile().readAsBytes(),
      schedule: await scheduleFile().readAsBytes(),
    ),
  );

  for (final tag in supportedLocaleTags) {
    for (final layout in layouts) {
      final label =
          '$tag ${layout.name} ${layout.size.width}px/${layout.scale}x';

      testWidgets('$label home discovery and program action', (tester) async {
        await withPrepared(tester, layout, () async {
          await show(
            tester,
            tag,
            layout,
            HomeScreen(content: content, onBrowseLibrary: () {}),
            () => find.byType(HomeScreen).evaluate().isNotEmpty,
          );
          expectLocale(tester, find.byType(HomeScreen), tag);
          expectPaintedWithoutError(tester, '$label home initial');
          await reveal(
            tester,
            find.byKey(HomeScreen.noPlanKey),
            '$label home practice selection',
          );
          final setup = find.byKey(HomeScreen.programSetupLinkKey);
          await reveal(tester, setup, '$label home setup action');
          expectTapSemantics(tester, setup);
        });
      });

      testWidgets('$label library searches its actual localized name', (
        tester,
      ) async {
        await withPrepared(tester, layout, () async {
          await show(
            tester,
            tag,
            layout,
            LibraryScreen(content: content),
            () => find.byType(LibraryScreen).evaluate().isNotEmpty,
          );
          expectLocale(tester, find.byType(LibraryScreen), tag);
          expectPaintedWithoutError(tester, '$label library initial');
          final search = find.byKey(LibraryScreen.searchFieldKey);
          await reveal(tester, search, '$label library search');
          final movement = content.catalogue.byId('bodyweight_squat')!;
          final name = catalogName(
            tester.element(search),
            movement.id,
            movement.displayName,
          );
          await tester.enterText(search, name);
          await tester.pump();
          await reveal(
            tester,
            find.byKey(LibraryScreen.movementResultsKey),
            '$label localized movement results',
          );
          expect(find.text(name), findsWidgets);
          expect(find.byKey(LibraryScreen.emptyResultKey), findsNothing);
          await reveal(tester, search, '$label library return to search');
          final clear = find.widgetWithIcon(IconButton, Icons.close);
          expect(clear, findsOneWidget);
          expect(tester.widget<IconButton>(clear).tooltip, isNotEmpty);
          expect(clear.hitTestable(), findsOneWidget);
          await tester.tap(clear);
          await tester.pump();
          expect(tester.widget<TextField>(search).controller!.text, isEmpty);
          expectPaintedWithoutError(tester, '$label search cleared');
        });
      });

      testWidgets('$label setup day controls and build action', (tester) async {
        await withPrepared(tester, layout, () async {
          await show(
            tester,
            tag,
            layout,
            ProgramSetupScreen(content: content),
            () => find.byType(ProgramSetupScreen).evaluate().isNotEmpty,
          );
          expectLocale(tester, find.byType(ProgramSetupScreen), tag);
          expectPaintedWithoutError(tester, '$label setup initial');
          final days = find.byKey(ProgramSetupScreen.daysPerWeekKey);
          await reveal(tester, days, '$label setup day controls');
          final add = find.widgetWithIcon(IconButton, Icons.add_circle_outline);
          final remove = find.widgetWithIcon(
            IconButton,
            Icons.remove_circle_outline,
          );
          expect(tester.widget<IconButton>(add).tooltip, isNotEmpty);
          expect(tester.widget<IconButton>(remove).tooltip, isNotEmpty);
          await tester.tap(add);
          await tester.pump();
          expect(
            find.descendant(
              of: days,
              matching: find.text(formatLocaleNumber(4, tag)),
            ),
            findsOneWidget,
          );
          await tester.tap(remove);
          await tester.pump();
          expect(
            find.descendant(
              of: days,
              matching: find.text(formatLocaleNumber(3, tag)),
            ),
            findsOneWidget,
          );
          final build = find.byKey(ProgramSetupScreen.buildButtonKey);
          await reveal(tester, build, '$label setup build action');
          expectTapSemantics(tester, build);
          expect(tester.widget<FilledButton>(build).onPressed, isNotNull);
          expect(await realIo(tester, () => inputFile().exists()), isFalse);
          expect(await realIo(tester, () => scheduleFile().exists()), isFalse);
        });
      });

      testWidgets('$label empty workout remains readable and actionable', (
        tester,
      ) async {
        await withPrepared(tester, layout, () async {
          await show(
            tester,
            tag,
            layout,
            WorkoutScreen.withClock(content: content, now: () => now),
            () => find.byKey(WorkoutScreen.emptyKey).evaluate().isNotEmpty,
          );
          expectLocale(tester, find.byType(WorkoutScreen), tag);
          expect(find.byKey(WorkoutScreen.unavailableKey), findsNothing);
          expectPaintedWithoutError(tester, '$label empty workout');
          final actionText = resolveLocalized(
            tag,
            LibraryStrings.programNoInputsAction,
            turkish: 'Programını oluştur',
          );
          final action = find.text(actionText);
          await reveal(tester, action, '$label empty workout setup action');
          expectTapSemantics(tester, action);
          expect(await realIo(tester, () => inputFile().exists()), isFalse);
          expect(await realIo(tester, () => scheduleFile().exists()), isFalse);
        });
      });

      testWidgets('$label ready workout and local RPE choice fit', (
        tester,
      ) async {
        await withPrepared(tester, layout, () async {
          await seedProgram(tester);
          final before = await programBytes(tester);
          await show(
            tester,
            tag,
            layout,
            WorkoutScreen.withClock(content: content, now: () => now),
            () => find.byKey(WorkoutScreen.disclaimerKey).evaluate().isNotEmpty,
          );
          expectLocale(tester, find.byType(WorkoutScreen), tag);
          expect(find.byKey(WorkoutScreen.unavailableKey), findsNothing);
          expectPaintedWithoutError(tester, '$label workout overview');
          final day = builder.build(inputs).days.first;
          final suffix = '${day.weekNumber}.${day.dayNumber}';
          final mark = find.byKey(ValueKey<String>('workout.markDone.$suffix'));
          await reveal(tester, mark, '$label workout mark done');
          expectTapSemantics(tester, mark);
          await tester.tap(mark);
          await tester.pump();
          final save = find.byKey(ValueKey<String>('workout.saveRpe.$suffix'));
          await reveal(tester, save, '$label RPE save action');
          expectTapSemantics(tester, save);
          expect(find.byType(ChoiceChip), findsNWidgets(10));
          final highest = find.widgetWithText(
            ChoiceChip,
            formatLocaleNumber(10, tag),
          );
          await reveal(tester, highest, '$label RPE highest real hit target');
          expect(highest.hitTestable(), findsOneWidget);
          expect(tester.widget<ChoiceChip>(highest).onSelected, isNotNull);
          await tester.tap(highest);
          await tester.pump();
          expect(tester.widget<ChoiceChip>(highest).selected, isTrue);
          expectPaintedWithoutError(tester, '$label RPE selected');
          final after = await programBytes(tester);
          expect(after.inputs, before.inputs);
          expect(
            after.schedule,
            before.schedule,
            reason:
                'Viewing and choosing an unsaved RPE must not rewrite history.',
          );
        });
      });

      testWidgets('$label protected workout preserves corrupt files', (
        tester,
      ) async {
        await withPrepared(tester, layout, () async {
          await realIo(tester, () async {
            await inputFile().writeAsString('{invalid-input');
            await scheduleFile().writeAsString('{preserved-history');
          });
          final before = await programBytes(tester);
          await show(
            tester,
            tag,
            layout,
            WorkoutScreen.withClock(content: content, now: () => now),
            () =>
                find.byKey(WorkoutScreen.unavailableKey).evaluate().isNotEmpty,
          );
          expectLocale(tester, find.byType(WorkoutScreen), tag);
          expect(find.byKey(WorkoutScreen.emptyKey), findsNothing);
          expect(find.byKey(WorkoutScreen.disclaimerKey), findsNothing);
          expectPaintedWithoutError(tester, '$label protected workout');
          final retry = find.byKey(WorkoutScreen.retryKey);
          await reveal(tester, retry, '$label protected workout retry');
          expectTapSemantics(tester, retry);
          expect(tester.widget<OutlinedButton>(retry).onPressed, isNotNull);
          final after = await programBytes(tester);
          expect(after.inputs, before.inputs);
          expect(after.schedule, before.schedule);
        });
      });

      testWidgets('$label real health lesson reader and self-report controls', (
        tester,
      ) async {
        await withPrepared(tester, layout, () async {
          final course = content.calisthenicsCourse;
          final lesson = course.lessons.singleWhere(
            (value) => value.id == 'cal-02',
          );
          final store = CalisthenicsProgressStore(
            File('${support.path}/reader-progress.json'),
            courseId: course.id,
          );
          await show(
            tester,
            tag,
            layout,
            CalisthenicsLessonScreen(
              course: course,
              lesson: lesson,
              storeLoader: (_) async => store,
              now: () => now,
            ),
            () => find
                .byKey(const Key('calisthenics.lesson.body'))
                .evaluate()
                .isNotEmpty,
          );
          expectLocale(tester, find.byType(CalisthenicsLessonScreen), tag);
          expect(find.text(lesson.title.inLanguage(tag)), findsOneWidget);
          // markSeen starts in the widget zone. Advance both clocks until its
          // actual Seen state is painted before awaiting a queued real read.
          final seen = find.byKey(const Key('calisthenics.state'));
          final seenText = resolveLocalized(tag, 'Seen', turkish: 'Görüldü');
          debugPrint('surface-lesson WAIT Seen writer: $label');
          await reveal(tester, seen, '$label health lesson writer readiness');
          bool seenReady() =>
              seen.evaluate().length == 1 &&
              tester.widget<Text>(seen).data == seenText;
          await settleUntil(tester, seenReady, maxRounds: 40);
          expect(
            seenReady(),
            isTrue,
            reason: '$label actual markSeen writer must settle before read',
          );
          debugPrint('surface-lesson READY Seen writer: $label');
          // Keep the real serialized read and all journal/UI safety oracles.
          debugPrint('surface-lesson START journal read: $label');
          final journal = await realIo(tester, store.load);
          debugPrint('surface-lesson END journal read: $label');
          await tester.pump();
          expect(
            journal.forLesson(lesson, course.version)?.state,
            CalisthenicsLessonState.seen,
          );
          // The title/objective can push the lazy state label off-screen.
          // Preserve the actual Seen UI oracle after IO and a real reveal.
          await reveal(tester, seen, '$label health lesson seen state');
          expect(tester.widget<Text>(seen).data, seenText);
          expect(find.text(seenText), findsOneWidget);
          expectPaintedWithoutError(tester, '$label health lesson initial');
          await reveal(
            tester,
            find.byKey(const Key('calisthenics.practiceOptions')),
            '$label health lesson practice boundary',
          );
          final confirm = find.byKey(const Key('calisthenics.confirm'));
          await reveal(tester, confirm, '$label health lesson self-check');
          final check = tester.widget<CheckboxListTile>(confirm);
          expect(check.value, isFalse);
          expect(check.onChanged, isNotNull);
          final complete = find.byKey(const Key('calisthenics.complete'));
          await reveal(
            tester,
            complete,
            '$label health lesson completion guard',
          );
          expect(
            tester.widget<FilledButton>(complete).onPressed,
            isNull,
            reason:
                'Reading/seen must not count as a practice or completion report.',
          );
          expectPaintedWithoutError(tester, '$label health lesson controls');
        });
      });
    }
  }

  testWidgets('narrow Arabic workout hides old owner data during a reload', (
    tester,
  ) async {
    const accountA = '11111111-1111-4111-8111-111111111111';
    const accountB = '22222222-2222-4222-8222-222222222222';
    const tag = 'ar';
    const layout = (name: 'phone', size: Size(320, 900), scale: 2.0);
    await withPrepared(tester, layout, () async {
      await realIo(tester, () async {
        final program = builder.build(inputs);
        await (await ProgramStore.open(accountUserId: accountA)).write(inputs);
        await (await ProgramScheduleStore.open(accountUserId: accountA)).write(
          ProgramSchedule(
            dates: scheduleProgram(
              program: program,
              startDate: now,
              daysPerWeek: inputs.daysPerWeek,
            ),
            rpeByDayIndex: const <int, int>{},
            programSignature: programSignature(inputs, program),
          ),
        );
      });
      final oldInput = File(
        '${support.path}/accounts/$accountA/program_inputs.json',
      );
      final oldSchedule = File(
        '${support.path}/accounts/$accountA/program_schedule.json',
      );
      final before = await realIo(
        tester,
        () async => (
          inputs: await oldInput.readAsBytes(),
          schedule: await oldSchedule.readAsBytes(),
        ),
      );
      await show(
        tester,
        tag,
        layout,
        WorkoutScreen.withClock(
          content: content,
          accountUserId: accountA,
          now: () => now,
        ),
        () => find.byKey(WorkoutScreen.disclaimerKey).evaluate().isNotEmpty,
      );
      final previousState = tester.state(find.byType(WorkoutScreen));
      await tester.pumpWidget(
        host(
          tag,
          layout,
          WorkoutScreen.withClock(
            content: content,
            accountUserId: accountB,
            now: () => now,
          ),
        ),
      );
      expect(
        identical(tester.state(find.byType(WorkoutScreen)), previousState),
        isTrue,
      );
      expect(
        find.byKey(WorkoutScreen.disclaimerKey),
        findsNothing,
        reason: 'A pending read must not retain the previous owner snapshot.',
      );
      await settleUntil(
        tester,
        () => find.byKey(WorkoutScreen.emptyKey).evaluate().isNotEmpty,
        maxRounds: 40,
      );
      expect(find.byKey(WorkoutScreen.emptyKey), findsOneWidget);
      expectLocale(tester, find.byType(WorkoutScreen), tag);
      expectPaintedWithoutError(tester, 'Arabic account switch');
      final after = await realIo(
        tester,
        () async => (
          inputs: await oldInput.readAsBytes(),
          schedule: await oldSchedule.readAsBytes(),
        ),
      );
      expect(after.inputs, before.inputs);
      expect(after.schedule, before.schedule);
      expect(
        await realIo(
          tester,
          () => File(
            '${support.path}/accounts/$accountB/program_inputs.json',
          ).exists(),
        ),
        isFalse,
      );
    });
  });
}
