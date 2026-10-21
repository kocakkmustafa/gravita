import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show LogicalKeyboardKey, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_connection.dart';
import 'package:gravita/app/account_store_epoch.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/calisthenics_knowledge_diagrams.dart';
import 'package:gravita/app/content_failure.dart';
import 'package:gravita/app/content_failure_screen.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/gravita_app.dart';
import 'package:gravita/app/language_preferences.dart';
import 'package:gravita/app/library_screen.dart';
import 'package:gravita/app/live_session_screen.dart';
import 'package:gravita/app/localization/locale_delegate.dart';
import 'package:gravita/app/motion_account_bootstrap.dart';
import 'package:gravita/app/onboarding_screen.dart';
import 'package:gravita/app/progress_view.dart';
import 'package:gravita/app/program/program_setup_screen.dart';
import 'package:gravita/app/surface_widgets.dart';
import 'package:gravita/app/theme.dart';
import 'package:gravita/app/theme_preferences.dart';
import 'package:gravita/app/workout/workout_screen.dart';
import 'package:gravita_engine/gravita_engine.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/launch_harness.dart' show FakeSupportDir, settleUntil;
import 'support/locale_asset_harness.dart'
    show pumpActualLocaleReady, warmActualLocaleAssets;

// Authored for the coordinator's SDK lane. These are selected real Flutter
// surfaces; they do not establish native camera, glyph or visual acceptance.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Real asset decoding must finish outside testWidgets' FakeAsync zone.
  // A later runAsync cannot rescue a cached Future created in that zone.
  setUpAll(warmActualLocaleAssets);

  Widget host(
    ThemeMode mode,
    Widget child, {
    Locale locale = const Locale('en'),
    double scale = 1,
  }) => MaterialApp(
    theme: GravitaTheme.light,
    darkTheme: GravitaTheme.dark,
    themeMode: mode,
    themeAnimationDuration: Duration.zero,
    locale: locale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    builder: (context, page) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: page!,
    ),
    home: child,
  );

  void viewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  Future<void> show(
    WidgetTester tester,
    ThemeMode mode,
    Widget child, {
    Locale locale = const Locale('en'),
    double scale = 1,
    required Finder ready,
  }) async {
    await tester.pumpWidget(host(mode, child, locale: locale, scale: scale));
    await pumpActualLocaleReady(tester);
    await settleUntil(tester, () => ready.evaluate().isNotEmpty, maxRounds: 40);
    expect(ready, findsWidgets);
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  // Read actual painted CTA pixels in memory; no golden/file is generated.
  Future<List<int>> paintedRect(
    WidgetTester tester,
    Finder boundaryFinder,
    Finder target,
  ) async {
    final rect = tester
        .getRect(target)
        .shift(-tester.getTopLeft(boundaryFinder));
    final boundary = tester.renderObject<RenderRepaintBoundary>(boundaryFinder);
    final pixels = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final left = rect.left.ceil().clamp(0, image.width).toInt();
        final right = rect.right.floor().clamp(0, image.width).toInt();
        final top = rect.top.ceil().clamp(0, image.height).toInt();
        final bottom = rect.bottom.floor().clamp(0, image.height).toInt();
        final result = <int>[];
        for (var y = top; y < bottom; y++) {
          final offset = (y * image.width + left) * 4;
          result.addAll(data.buffer.asUint8List(offset, (right - left) * 4));
        }
        return result;
      } finally {
        image.dispose();
      }
    });
    return pixels!;
  }

  bool containsPaintedColor(List<int> pixels, Color color) {
    final argb = color.toARGB32();
    for (var i = 0; i + 3 < pixels.length; i += 4) {
      if (pixels[i] == ((argb >> 16) & 0xff) &&
          pixels[i + 1] == ((argb >> 8) & 0xff) &&
          pixels[i + 2] == (argb & 0xff) &&
          pixels[i + 3] == ((argb >> 24) & 0xff)) {
        return true;
      }
    }
    return false;
  }

  void compactPlatform(WidgetTester tester) {
    viewport(tester, const Size(320, 180));
    tester.view.padding = const FakeViewPadding(
      left: 12,
      top: 16,
      right: 12,
      bottom: 20,
    );
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  testWidgets('default shared text follows an in-place theme change', (
    tester,
  ) async {
    viewport(tester, const Size(320, 900));
    const page = Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            ReasonList(items: <String>['default reason']),
            ReasonList(
              items: <String>['explicit reason'],
              color: Colors.purple,
              bulletColor: Colors.purple,
            ),
            NoteCard(title: 'sealed title', text: 'sealed note', sealed: true),
          ],
        ),
      ),
    );
    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      await show(tester, mode, page, ready: find.text('default reason'));
      final palette = GravitaColors.of(
        tester.element(find.byType(ReasonList).first),
      );
      expect(
        tester.widget<Text>(find.text('default reason')).style?.color,
        palette.ink,
      );
      expect(
        tester.widget<Text>(find.text('explicit reason')).style?.color,
        Colors.purple,
      );
      expect(
        tester.widget<Text>(find.text('sealed title')).style?.color,
        palette.honestyText,
      );
      expect(
        tester.widget<Text>(find.text('sealed note')).style?.color,
        palette.honestyText,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('library search keeps query and focus when the theme changes', (
    tester,
  ) async {
    viewport(tester, const Size(375, 900));
    late ContentRepository content;
    await tester.runAsync(() async {
      content = await ContentRepository.load(rootBundle);
    });
    final page = LibraryScreen(content: content);
    await show(
      tester,
      ThemeMode.light,
      page,
      ready: find.byType(LibraryScreen),
    );
    final field = find.byKey(LibraryScreen.searchFieldKey);
    final choices = find
        .descendant(
          of: find.byType(LibraryScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      field,
      240,
      scrollable: choices,
      maxScrolls: 20,
    );
    await tester.pump();
    expect(field.hitTestable(), findsOneWidget);
    await tester.enterText(field, 'push');
    await tester.pump();
    final inputBefore = tester.widget<EditableText>(find.byType(EditableText));
    expect(inputBefore.focusNode.hasFocus, isTrue);
    await show(tester, ThemeMode.dark, page, ready: field);
    final inputAfter = tester.widget<EditableText>(find.byType(EditableText));
    final palette = GravitaColors.of(tester.element(field));
    expect(inputAfter.controller, same(inputBefore.controller));
    expect(inputAfter.controller.text, 'push');
    expect(inputAfter.focusNode.hasFocus, isTrue);
    expect(inputAfter.style.color, palette.ink);
    expect(
      tester.widget<TextField>(field).decoration?.fillColor,
      palette.cardTop,
    );
    expect(find.byKey(LibraryScreen.movementResultsKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('knowledge diagrams request repaint after a theme change', (
    tester,
  ) async {
    viewport(tester, const Size(375, 1000));
    const page = Scaffold(
      body: SingleChildScrollView(
        child: CalisthenicsKnowledgeDiagrams(lessonId: 'cal-47'),
      ),
    );
    await show(
      tester,
      ThemeMode.light,
      page,
      ready: find.byType(CalisthenicsKnowledgeDiagrams),
    );
    Finder drawings() => find.descendant(
      of: find.byType(CalisthenicsKnowledgeDiagrams),
      matching: find.byType(CustomPaint),
    );
    final lightPainter = tester.widget<CustomPaint>(drawings().first).painter!;
    await show(tester, ThemeMode.dark, page, ready: drawings());
    final darkPainter = tester.widget<CustomPaint>(drawings().first).painter!;
    expect(darkPainter.shouldRepaint(lightPainter), isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    for (final kind in ContentFailureKind.values) {
      testWidgets('$mode $kind: readable error and reachable details in RTL', (
        tester,
      ) async {
        viewport(tester, const Size(320, 900));
        await show(
          tester,
          mode,
          ContentFailureScreen(
            failure: ContentFailure(kind: kind, detail: 'local diagnostic'),
            onRetry: () async {},
          ),
          locale: const Locale('ar'),
          scale: 1.8,
          ready: find.byKey(ContentFailureScreen.headlineKey),
        );
        final headline = find.byKey(ContentFailureScreen.headlineKey);
        final palette = GravitaColors.of(tester.element(headline));
        expect(Directionality.of(tester.element(headline)), TextDirection.rtl);
        expect(tester.widget<Text>(headline).style?.color, palette.ink);
        if (kind == ContentFailureKind.unreadable) {
          final retry = find.byKey(ContentFailureScreen.retryKey);
          await tester.scrollUntilVisible(
            retry,
            240,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 20,
          );
          await tester.pump();
          expect(retry.hitTestable(), findsOneWidget);
        }
        expect(
          find.byKey(ContentFailureScreen.retryKey),
          kind == ContentFailureKind.unreadable ? findsOneWidget : findsNothing,
        );
        await tester.scrollUntilVisible(
          find.byType(ExpansionTile),
          240,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(ContentFailureScreen.detailKey),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        final detail = tester.widget<SelectableText>(
          find.byKey(ContentFailureScreen.detailKey),
        );
        expect(detail.data, 'local diagnostic');
        expect(detail.style?.color, palette.textSecondary);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('$mode onboarding footer survives compact RTL and large text', (
      tester,
    ) async {
      viewport(tester, const Size(568, 320));
      var completed = 0;
      await show(
        tester,
        mode,
        OnboardingFlow(
          onComplete: () async {
            completed++;
          },
        ),
        locale: const Locale('ar'),
        scale: 2,
        ready: find.byKey(OnboardingFlow.valueContinueKey),
      );
      expect(
        find.byKey(OnboardingFlow.valueContinueKey).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(OnboardingFlow.valueContinueKey));
      await tester.pump();
      expect(
        find.byKey(OnboardingFlow.safetyConsentKey).hitTestable(),
        findsOneWidget,
      );
      expect(completed, 0);
      expect(tester.takeException(), isNull);
    });

    for (final status in <HistoryStatus>[
      const HistoryOk(),
      const HistoryPartial(2),
      const HistoryUnavailable('synthetic read failure'),
    ]) {
      testWidgets(
        '$mode ${status.runtimeType}: progress retains its boundary',
        (tester) async {
          viewport(tester, const Size(320, 1800));
          final summary = ProgressSummary.build(
            lessonSurfaces: const <LessonSurface>[
              LessonSurface(
                id: 'push_foundations.reps_and_tempo',
                displayName: 'Reps that count',
                movementName: 'Push-Up',
                unitLabel: 'rep',
                gradedToday: false,
              ),
              LessonSurface(
                id: 'push_foundations.form_check',
                displayName: 'Body-line check',
                movementName: 'Push-Up',
                unitLabel: 'rep',
                gradedToday: false,
                lockedReason:
                    'A long unvalidated boundary remains visible. '
                    'A long unvalidated boundary remains visible.',
              ),
            ],
            records: const <SessionRecord>[],
          );
          await show(
            tester,
            mode,
            Scaffold(
              body: ProgressView(summary: summary, historyStatus: status),
            ),
            locale: const Locale('ar'),
            scale: 1.8,
            ready: find.byType(ProgressView),
          );
          final expected = status is HistoryUnavailable
              ? ProgressView.historyFailureKey
              : status is HistoryPartial
              ? ProgressView.historyPartialKey
              : ProgressView.measuredSectionKey;
          await tester.scrollUntilVisible(find.byKey(expected), 200);
          expect(find.byKey(expected), findsOneWidget);
          await tester.scrollUntilVisible(
            find.byKey(ProgressView.lockedSectionKey),
            240,
          );
          expect(find.byKey(ProgressView.lockedSectionKey), findsOneWidget);
          final palette = GravitaColors.of(
            tester.element(find.byType(ProgressView)),
          );
          final sealedText = tester.widgetList<Text>(
            find.descendant(
              of: find.byKey(ProgressView.lockedSectionKey),
              matching: find.byType(Text),
            ),
          );
          expect(
            sealedText.any((text) => text.style?.color == palette.honestyText),
            isTrue,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('$mode fitting live sheet has no artificial scroll extent', (
      tester,
    ) async {
      viewport(tester, const Size(640, 1200));
      final config = MovementConfig.parse(
        File('content/catalog/w1/push_up.json').readAsStringSync(),
      );
      final button = find.byKey(LiveSessionScreen.startButtonKey);
      await show(
        tester,
        mode,
        LiveSessionScreen(config: config),
        ready: button,
      );
      final scroll = find.descendant(
        of: find.byType(LiveSessionScreen),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scroll).position;
      expect(position.maxScrollExtent, closeTo(0, 0.01));
      final bounds = tester.getRect(scroll);
      final action = tester.getRect(button);
      expect(bounds.contains(action.topLeft), isTrue);
      expect(
        bounds.contains(action.bottomRight - const Offset(0.1, 0.1)),
        isTrue,
      );
      expect(button.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$mode long RTL live sheet still scrolls to the full CTA', (
      tester,
    ) async {
      viewport(tester, const Size(320, 320));
      final config = MovementConfig.parse(
        File('content/catalog/w1/push_up.json').readAsStringSync(),
      );
      final button = find.byKey(LiveSessionScreen.startButtonKey);
      await show(
        tester,
        mode,
        LiveSessionScreen(config: config),
        locale: const Locale('ar'),
        scale: 2,
        ready: button,
      );
      final scroll = find.descendant(
        of: find.byType(LiveSessionScreen),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scroll).position;
      expect(position.maxScrollExtent, greaterThan(0));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      final bounds = tester.getRect(scroll);
      final action = tester.getRect(button);
      expect(bounds.contains(action.topLeft), isTrue);
      expect(
        bounds.contains(action.bottomRight - const Offset(0.1, 0.1)),
        isTrue,
      );
      expect(button.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$mode program CTA paints keyboard focus and hover over its ink',
      (tester) async {
        viewport(tester, const Size(320, 900));
        await AccountStoreEpochRegistry.resetForTest();
        final original = PathProviderPlatform.instance;
        late Directory directory;
        late ContentRepository content;
        await tester.runAsync(() async {
          directory = await Directory.systemTemp.createTemp('gravita_surface_');
          content = await ContentRepository.load(rootBundle);
        });
        PathProviderPlatform.instance = FakeSupportDir(directory.path);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          PathProviderPlatform.instance = original;
          await AccountStoreEpochRegistry.resetForTest();
          await tester.runAsync(() => directory.delete(recursive: true));
        });
        const boundaryKey = Key('surface.workout.paint');
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: host(
              mode,
              WorkoutScreen(content: content),
              locale: const Locale('ar'),
              scale: 2,
            ),
          ),
        );
        await pumpActualLocaleReady(tester);
        await settleUntil(
          tester,
          () => find.byKey(WorkoutScreen.emptyKey).evaluate().isNotEmpty,
          maxRounds: 40,
        );
        expect(find.byKey(WorkoutScreen.unavailableKey), findsNothing);
        final cta = find.descendant(
          of: find.byType(WorkoutScreen),
          matching: find.byType(InkWell),
        );
        expect(cta, findsOneWidget);
        await tester.ensureVisible(cta);
        await tester.pumpAndSettle();
        final boundary = find.byKey(boundaryKey);
        final idle = await paintedRect(tester, boundary, cta);
        expect(idle, isNotEmpty);
        final palette = GravitaColors.of(tester.element(cta));
        expect(
          containsPaintedColor(idle, palette.accent),
          isTrue,
          reason: 'The captured CTA must contain its actual accent paint.',
        );
        final ink = find.descendant(of: cta, matching: find.byType(Ink));
        final node = Focus.of(tester.element(ink));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        // The first frame starts a newly scheduled ink ticker at elapsed zero;
        // advance the existing fade interval only after that starting frame.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(node.hasFocus, isTrue);
        expect(
          FocusManager.instance.highlightMode,
          FocusHighlightMode.traditional,
        );
        debugPrint(
          'surface-cta $mode: focus=${node.hasFocus} '
          'highlight=${FocusManager.instance.highlightMode}',
        );
        final focused = await paintedRect(tester, boundary, cta);
        expect(focused, isNot(orderedEquals(idle)));
        node.unfocus();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(node.hasFocus, isFalse);
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: const Offset(1, 1));
        await mouse.moveTo(tester.getCenter(cta));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        final hovered = await paintedRect(tester, boundary, cta);
        expect(hovered, isNot(orderedEquals(idle)));
        await mouse.moveTo(const Offset(1, 1));
        node.requestFocus();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(ProgramSetupScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$mode startup failure scrolls safely with compact RTL text', (
      tester,
    ) async {
      compactPlatform(tester);
      await tester.runAsync(
        () => const GravitaLocalizationsDelegate().load(const Locale('ar')),
      );
      final appearance = ThemePreferencesController.ephemeral(
        mode: mode == ThemeMode.dark
            ? GravitaThemeMode.dark
            : GravitaThemeMode.light,
      );
      final language = LanguagePreferencesController.ephemeral(
        selectedTag: 'ar',
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        appearance.dispose();
        language.dispose();
      });
      final expected = resolveLocalized(
        'ar',
        'Sign-in is unavailable in this build. Please try an updated version.',
        turkish:
            'Bu sürümde giriş kullanılamıyor. Lütfen güncel bir sürüm deneyin.',
      );
      await tester.pumpWidget(
        AccountStartupFailure(
          themePreferences: appearance,
          languagePreferences: language,
        ),
      );
      await pumpActualLocaleReady(tester);
      await settleUntil(
        tester,
        () => find.text(expected).evaluate().isNotEmpty,
      );
      final text = find.text(expected);
      expect(Directionality.of(tester.element(text)), TextDirection.rtl);
      expect(MediaQuery.textScalerOf(tester.element(text)).scale(10), 30);
      final scroll = find.byType(Scrollable);
      final position = tester.state<ScrollableState>(scroll).position;
      final bounds = tester.getRect(scroll);
      expect(bounds.left, greaterThanOrEqualTo(12));
      expect(bounds.top, greaterThanOrEqualTo(16));
      expect(bounds.right, lessThanOrEqualTo(308));
      expect(bounds.bottom, lessThanOrEqualTo(160));
      expect(position.maxScrollExtent, greaterThan(0));
      await tester.drag(scroll, Offset(0, -position.maxScrollExtent - 100));
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(position.maxScrollExtent, 1));
      expect(tester.getBottomRight(text).dy, lessThanOrEqualTo(bounds.bottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$mode closed account states scroll and retain account access', (
      tester,
    ) async {
      compactPlatform(tester);
      await tester.runAsync(
        () => const GravitaLocalizationsDelegate().load(const Locale('ar')),
      );
      await AccountStoreEpochRegistry.resetForTest();
      await AccountStoreEpochRegistry.enableManagedAdmission();
      const id = '11111111-1111-4111-8111-111111111111';
      final user = ValueNotifier<String?>(id);
      final recovery = ValueNotifier<bool>(false);
      final appearance = ThemePreferencesController.ephemeral(
        mode: mode == ThemeMode.dark
            ? GravitaThemeMode.dark
            : GravitaThemeMode.light,
      );
      final language = LanguagePreferencesController.ephemeral(
        selectedTag: 'ar',
      );
      final gate = Completer<void>();
      final syntheticCleanupFailure = StateError('synthetic cleanup failure');
      final cleanup = AccountStoreEpochRegistry.beginConfirmedAccountErasure(
        id,
        () => gate.future,
      );
      var cleanupSettled = false;
      Object? cleanupError;
      StackTrace? cleanupStackTrace;
      final settled = cleanup.then<void>(
        (_) {
          cleanupSettled = true;
        },
        onError: (Object error, StackTrace stackTrace) {
          cleanupError = error;
          cleanupStackTrace = stackTrace;
          cleanupSettled = true;
        },
      );
      addTearDown(() async {
        var teardownBridgeSettled = false;
        // Attach before pumping: a late listener on the completed fake-zone
        // Future still needs that zone's microtasks to be flushed. The bridge
        // itself belongs to this teardown's zone, like binding.runTest's bridge.
        final teardownBridge = settled.then<void>((_) {
          teardownBridgeSettled = true;
        });
        debugPrint('surface-cleanup $mode: unmount');
        await tester.pumpWidget(const SizedBox.shrink());
        if (!gate.isCompleted) gate.complete();
        var turns = 0;
        while (!teardownBridgeSettled && turns < 16) {
          await tester.pump();
          turns++;
        }
        debugPrint(
          'surface-cleanup $mode: drain=$cleanupSettled '
          'bridge=$teardownBridgeSettled turns=$turns',
        );
        expect(
          cleanupSettled,
          isTrue,
          reason: 'Synthetic erasure did not settle after $turns fake pumps.',
        );
        expect(
          teardownBridgeSettled,
          isTrue,
          reason: 'Synthetic erasure bridge did not settle after $turns pumps.',
        );
        await teardownBridge;
        expect(
          cleanupError,
          isNull,
          reason: 'Unexpected synthetic cleanup error: $cleanupStackTrace',
        );
        debugPrint('surface-cleanup $mode: registry reset start');
        await AccountStoreEpochRegistry.resetForTest();
        debugPrint('surface-cleanup $mode: registry reset');
        user.dispose();
        recovery.dispose();
        appearance.dispose();
        language.dispose();
      });
      await tester.pumpWidget(
        GravitaApp(
          themePreferences: appearance,
          languagePreferences: language,
          accountConnection: AccountConnection(
            userId: user,
            passwordRecovery: recovery,
            pageBuilder: (_) =>
                const Scaffold(body: Text('surface-account-options')),
          ),
        ),
      );
      await pumpActualLocaleReady(tester);
      final options = find.widgetWithText(
        TextButton,
        resolveLocalized('ar', 'Account options', turkish: 'Hesap seçenekleri'),
      );
      Future<void> checkBoundary(String english, String turkish) async {
        final expected = resolveLocalized('ar', english, turkish: turkish);
        await settleUntil(
          tester,
          () => find.text(expected).evaluate().isNotEmpty,
        );
        expect(find.byType(GravitaRoot), findsNothing);
        expect(() => AccountStoreEpochRegistry.capture(id), throwsStateError);
        final text = find.text(expected);
        expect(Directionality.of(tester.element(text)), TextDirection.rtl);
        expect(MediaQuery.textScalerOf(tester.element(text)).scale(10), 30);
        final scroll = find.byType(Scrollable);
        final position = tester.state<ScrollableState>(scroll).position;
        expect(position.maxScrollExtent, greaterThan(0));
        await tester.ensureVisible(options);
        await tester.pumpAndSettle();
        final bounds = tester.getRect(scroll);
        final action = tester.getRect(options);
        debugPrint(
          'surface-boundary $mode: bounds=$bounds action=$action '
          'offset=${position.pixels} extent=${position.maxScrollExtent}',
        );
        expect(bounds.left, greaterThanOrEqualTo(12));
        expect(bounds.top, greaterThanOrEqualTo(16));
        expect(bounds.right, lessThanOrEqualTo(308));
        expect(bounds.bottom, lessThanOrEqualTo(160));
        expect(bounds.contains(action.topLeft), isTrue);
        expect(
          bounds.contains(action.bottomRight - const Offset(0.1, 0.1)),
          isTrue,
        );
        expect(options.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      await checkBoundary(
        'Account history is unavailable while local cleanup completes.',
        'Yerel temizlik tamamlanana kadar hesap geçmişi kullanılamıyor.',
      );
      gate.completeError(syntheticCleanupFailure);
      await settled;
      expect(cleanupError, same(syntheticCleanupFailure));
      expect(cleanupStackTrace, isNotNull);
      // Only this explicitly checked, injected failure is consumed. Any other
      // cleanup error remains recorded for the teardown's isNull assertion.
      cleanupError = null;
      cleanupStackTrace = null;
      await tester.pump();
      await checkBoundary(
        'Local cleanup could not finish. Account history remains unavailable.',
        'Yerel temizlik tamamlanamadı. Hesap geçmişi kapalı tutuluyor.',
      );
      await AccountStoreEpochRegistry.beginConfirmedAccountErasure(
        id,
        () async {},
      );
      await tester.pump();
      await checkBoundary(
        'This account was deleted. Its local history is unavailable.',
        'Bu hesap silindi. Yerel hesap geçmişi kullanılamıyor.',
      );
      await tester.tap(options);
      await tester.pumpAndSettle();
      expect(find.text('surface-account-options'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$mode live idle keeps the camera dark and adapts the sheet', (
      tester,
    ) async {
      viewport(tester, const Size(320, 900));
      final config = MovementConfig.parse(
        File('content/catalog/w1/push_up.json').readAsStringSync(),
      );
      await show(
        tester,
        mode,
        LiveSessionScreen(config: config),
        scale: 1.8,
        ready: find.byKey(LiveSessionScreen.startButtonKey),
      );
      final screen = find.byType(LiveSessionScreen);
      final palette = GravitaColors.of(tester.element(screen));
      final scaffold = tester.widget<Scaffold>(
        find.descendant(of: screen, matching: find.byType(Scaffold)),
      );
      expect(scaffold.backgroundColor, GravitaColors.sessionStage);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.foregroundColor, GravitaColors.sessionInkOnDark);
      final sheetDecorations = tester
          .widgetList<Container>(
            find.descendant(of: screen, matching: find.byType(Container)),
          )
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>();
      expect(
        sheetDecorations.any((box) => box.color == palette.surfaceTop),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
