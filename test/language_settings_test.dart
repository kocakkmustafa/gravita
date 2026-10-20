import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_connection.dart';
import 'package:gravita/app/account_store_epoch.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/gravita_app.dart';
import 'package:gravita/app/language_preferences.dart';
import 'package:gravita/app/language_settings_screen.dart';
import 'package:gravita/app/profile_screen.dart';
import 'package:gravita/app/theme.dart';
import 'package:gravita/app/theme_preferences.dart';

import 'support/locale_asset_harness.dart';

// Controller and widget contracts are source-only until the authorized Flutter
// runner executes this file. The codec/IO harness is a separate pure Dart file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await warmActualLocaleAssets();
    await ContentRepository.load(rootBundle);
  });

  Widget host(
    LanguagePreferencesController controller, {
    Widget? home,
    Locale? localeOverride,
    bool reduceMotion = false,
    double textScale = 1,
  }) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => LanguagePreferencesScope(
      controller: controller,
      child: MaterialApp(
        theme: GravitaTheme.light,
        darkTheme: GravitaTheme.dark,
        locale: localeOverride ?? controller.locale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        localeListResolutionCallback: resolveAppLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: home ?? const LanguageSettingsScreen(),
      ),
    ),
  );

  test('all preloaded exact tags and system are available synchronously', () {
    for (final tag in <String?>[null, ...supportedLocaleTags]) {
      final controller = LanguagePreferencesController(
        store: _ControlledStore(),
        initial: LanguagePreferencesLoadResult(selectedTag: tag),
      );
      expect(controller.selectedTag, tag);
      expect(controller.locale, tag == null ? null : localeForAppTag(tag));
      expect(controller.saving, isFalse);
      controller.dispose();
    }
  });

  test(
    'unknown injected initial value falls back and invalid mutation does no IO',
    () async {
      final store = _ControlledStore();
      final controller = LanguagePreferencesController(
        store: store,
        initial: const LanguagePreferencesLoadResult(selectedTag: 'en-US'),
      );
      addTearDown(controller.dispose);
      expect(controller.locale, isNull);
      expect(controller.loadIssue, LanguagePreferencesLoadIssue.invalid);
      await expectLater(
        controller.setSelectedTag('zh-Hant'),
        throwsArgumentError,
      );
      expect(controller.selectedTag, isNull);
      expect(store.calls, isEmpty);
      expect(
        () => LanguagePreferencesController.ephemeral(selectedTag: 'pt'),
        throwsArgumentError,
      );
    },
  );

  test(
    'selection applies immediately and stale write failure cannot replace latest success',
    () async {
      final store = _ControlledStore();
      final controller = LanguagePreferencesController(
        store: store,
        initial: const LanguagePreferencesLoadResult(),
      );
      addTearDown(controller.dispose);
      final first = controller.setSelectedTag('tr');
      final last = controller.setSelectedTag('ja');
      expect(controller.selectedTag, 'ja');
      expect(controller.locale, localeForAppTag('ja'));
      expect(controller.saving, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(store.calls, <String?>['tr']);
      store.pending
          .removeAt(0)
          .completeError(StateError('synthetic older failure'));
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(controller.saveFailed, isFalse);
      expect(store.calls, <String?>['tr', 'ja']);
      store.pending.removeAt(0).complete();
      await last;
      expect(controller.saving, isFalse);
      expect(controller.saveFailed, isFalse);
      expect(controller.selectedTag, 'ja');
    },
  );

  test(
    'failed write remains visible and retry saves the current selection',
    () async {
      final store = _ControlledStore();
      final controller = LanguagePreferencesController(
        store: store,
        initial: const LanguagePreferencesLoadResult(),
      );
      addTearDown(controller.dispose);
      final first = controller.setSelectedTag('zh-Hans');
      await Future<void>.delayed(Duration.zero);
      store.pending.removeAt(0).completeError(StateError('synthetic failure'));
      await first;
      expect(controller.saveFailed, isTrue);
      expect(controller.locale, localeForAppTag('zh-Hans'));
      final retry = controller.retrySave();
      await Future<void>.delayed(Duration.zero);
      store.pending.removeAt(0).complete();
      await retry;
      expect(store.calls, <String?>['zh-Hans', 'zh-Hans']);
      expect(controller.saveFailed, isFalse);
    },
  );

  test(
    'system can recover an unchanged fallback choice and disposal allows IO to settle',
    () async {
      final store = _ControlledStore();
      final controller = LanguagePreferencesController(
        store: store,
        initial: const LanguagePreferencesLoadResult(
          issue: LanguagePreferencesLoadIssue.invalid,
        ),
      );
      final write = controller.setSelectedTag(null);
      await Future<void>.delayed(Duration.zero);
      expect(store.calls, <String?>[null]);
      controller.dispose();
      store.pending.removeAt(0).complete();
      await write;
      expect(controller.loadIssue, isNull);
      expect(controller.saving, isFalse);
    },
  );

  testWidgets('system and all 14 exact autonyms are present', (tester) async {
    final controller = LanguagePreferencesController.ephemeral();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));
    await pumpActualLocaleReady(tester);
    await tester.pumpAndSettle();
    expect(languageAutonyms.keys.toSet(), supportedLocaleTags.toSet());
    expect(languageAutonyms, hasLength(14));
    expect(find.byKey(LanguageSettingsScreen.systemKey), findsOneWidget);
    for (final entry in languageAutonyms.entries) {
      expect(
        find.byKey(LanguageSettingsScreen.languageKey(entry.key)),
        findsOneWidget,
      );
      expect(find.text(entry.value), findsOneWidget);
    }
    await tester.ensureVisible(
      find.byKey(LanguageSettingsScreen.languageKey('tr')),
    );
    await tester.tap(find.byKey(LanguageSettingsScreen.languageKey('tr')));
    await pumpActualLocaleReady(tester);
    await tester.pumpAndSettle();
    expect(controller.selectedTag, 'tr');
    expect(find.text('Dil'), findsOneWidget);
    expect(find.text('Cihaz dilini kullan'), findsOneWidget);
  });

  testWidgets(
    'startup load is bounded and late readonly result cannot change the controller',
    (tester) async {
      final store = _DelayedLoadStore();
      LanguagePreferencesController? controller;
      final loading = loadDeviceLanguagePreferences(store: store).then((value) {
        controller = value;
      });
      await tester.pump();
      expect(controller, isNull);
      await tester.pump(const Duration(seconds: 3));
      expect(controller, isNotNull);
      await loading;
      expect(controller!.selectedTag, isNull);
      expect(controller!.loadIssue, LanguagePreferencesLoadIssue.unavailable);
      store.pending.complete(
        const LanguagePreferencesLoadResult(selectedTag: 'ar'),
      );
      await tester.pump();
      expect(controller!.selectedTag, isNull);
      expect(controller!.locale, isNull);
      expect(controller!.loadIssue, LanguagePreferencesLoadIssue.unavailable);
      expect(store.saves, isEmpty);
      controller!.dispose();
    },
  );

  testWidgets(
    'system follows platform locale while explicit selection stays fixed',
    (tester) async {
      tester.platformDispatcher.localesTestValue = const <Locale>[Locale('tr')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final controller = LanguagePreferencesController.ephemeral();
      addTearDown(controller.dispose);
      await tester.pumpWidget(host(controller));
      await pumpActualLocaleReady(tester);
      await tester.pumpAndSettle();
      expect(
        Localizations.localeOf(
          tester.element(find.byType(LanguageSettingsScreen)),
        ),
        localeForAppTag('tr'),
      );
      tester.platformDispatcher.localesTestValue = const <Locale>[Locale('de')];
      await pumpActualLocaleReady(tester);
      await tester.pumpAndSettle();
      expect(
        Localizations.localeOf(
          tester.element(find.byType(LanguageSettingsScreen)),
        ),
        localeForAppTag('de'),
      );
      await controller.setSelectedTag('ar');
      await pumpActualLocaleReady(tester);
      await tester.pumpAndSettle();
      tester.platformDispatcher.localesTestValue = const <Locale>[Locale('ja')];
      await pumpActualLocaleReady(tester);
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(LanguageSettingsScreen));
      expect(Localizations.localeOf(context), localeForAppTag('ar'));
      expect(Directionality.of(context), TextDirection.rtl);
      await controller.setSelectedTag(null);
      await pumpActualLocaleReady(tester);
      await tester.pumpAndSettle();
      expect(
        Localizations.localeOf(
          tester.element(find.byType(LanguageSettingsScreen)),
        ),
        localeForAppTag('ja'),
      );
    },
  );

  testWidgets('pending, sanitized failure and working retry are visible', (
    tester,
  ) async {
    final store = _ControlledStore();
    final controller = LanguagePreferencesController(
      store: store,
      initial: const LanguagePreferencesLoadResult(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(controller, localeOverride: const Locale('en')),
    );
    await pumpActualLocaleReady(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(LanguageSettingsScreen.languageKey('en')),
    );
    // ensureVisible can jump without laying out the new hit-test geometry.
    await tester.pump();
    expect(
      find.byKey(LanguageSettingsScreen.languageKey('en')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(LanguageSettingsScreen.languageKey('en')));
    await tester.pump();
    expect(controller.saving, isTrue);
    expect(store.calls, <String?>['en']);
    expect(store.pending, hasLength(1));
    expect(find.byKey(LanguageSettingsScreen.savingKey), findsOneWidget);
    expect(controller.selectedTag, 'en');
    store.pending
        .removeAt(0)
        .completeError(StateError('/private/sensitive/language.json'));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(LanguageSettingsScreen.failureKey), findsOneWidget);
    expect(find.textContaining('/private/sensitive'), findsNothing);
    await tester.ensureVisible(find.byKey(LanguageSettingsScreen.retryKey));
    await tester.pump();
    expect(
      find.byKey(LanguageSettingsScreen.retryKey).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(LanguageSettingsScreen.retryKey));
    await tester.pump();
    store.pending.removeAt(0).complete();
    await tester.pumpAndSettle();
    expect(find.byKey(LanguageSettingsScreen.failureKey), findsNothing);
    expect(find.byKey(LanguageSettingsScreen.savingKey), findsNothing);
    expect(store.calls, <String?>['en', 'en']);
  });

  testWidgets('invalid and unavailable load fallback are visible', (
    tester,
  ) async {
    for (final issue in LanguagePreferencesLoadIssue.values) {
      final controller = LanguagePreferencesController(
        store: _ControlledStore(),
        initial: LanguagePreferencesLoadResult(issue: issue),
      );
      await tester.pumpWidget(
        host(controller, localeOverride: const Locale('en')),
      );
      await pumpActualLocaleReady(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(LanguageSettingsScreen.loadIssueKey), findsOneWidget);
      expect(controller.selectedTag, isNull);
      if (issue == LanguagePreferencesLoadIssue.invalid) {
        expect(
          find.textContaining('original file has been kept'),
          findsOneWidget,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('profile opens the actual language screen', (tester) async {
    late ContentRepository content;
    await tester.runAsync(
      () async => content = await ContentRepository.load(rootBundle),
    );
    final controller = LanguagePreferencesController.ephemeral(
      selectedTag: 'en',
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(controller, home: ProfileScreen(content: content)),
    );
    await pumpActualLocaleReady(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Language'));
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    expect(find.byType(LanguageSettingsScreen), findsOneWidget);
  });

  testWidgets(
    'saved locale is on the first app frame and switching keeps navigation/account epoch',
    (tester) async {
      const userId = '00000000-0000-4000-8000-000000000001';
      await tester.runAsync(() async {
        await AccountStoreEpochRegistry.resetForTest();
        await AccountStoreEpochRegistry.enableManagedAdmission();
      });
      final user = ValueNotifier<String?>(userId);
      final recovery = ValueNotifier<bool>(false);
      final controller = LanguagePreferencesController.ephemeral(
        selectedTag: 'tr',
      );
      final appearance = ThemePreferencesController.ephemeral();
      final account = AccountConnection(
        userId: user,
        passwordRecovery: recovery,
        pageBuilder: (_) => const Scaffold(),
        isIdentityAdmitted: () => true,
      );
      try {
        await tester.pumpWidget(
          GravitaApp(
            accountConnection: account,
            themePreferences: appearance,
            languagePreferences: controller,
          ),
        );
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
          localeForAppTag('tr'),
        );
        await pumpActualLocaleReady(tester);
        final materialKey = tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .key;
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        final epoch = AccountStoreEpochRegistry.capture(userId);
        unawaited(
          navigator.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const LanguageSettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await controller.setSelectedTag('ar');
        await pumpActualLocaleReady(tester);
        await tester.pumpAndSettle();
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).key,
          materialKey,
        );
        expect(
          tester.state<NavigatorState>(find.byType(Navigator)),
          same(navigator),
        );
        expect(find.byType(LanguageSettingsScreen), findsOneWidget);
        expect(
          Directionality.of(
            tester.element(find.byType(LanguageSettingsScreen)),
          ),
          TextDirection.rtl,
        );
        expect(AccountStoreEpochRegistry.capture(userId), same(epoch));
        expect(epoch.checkCurrent, returnsNormally);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        appearance.dispose();
        user.dispose();
        recovery.dispose();
        await tester.runAsync(AccountStoreEpochRegistry.resetForTest);
      }
    },
  );

  testWidgets('Arabic and CJK autonyms fit narrow large-text settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = LanguagePreferencesController.ephemeral(
      selectedTag: 'ar',
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(controller, textScale: 1.8, reduceMotion: true),
    );
    await pumpActualLocaleReady(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(LanguageSettingsScreen.languageKey('zh-Hans')),
    );
    await tester.pumpAndSettle();
    expect(find.text('简体中文'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pending language shows a static indicator under reduced motion',
    (tester) async {
      final store = _ControlledStore();
      final controller = LanguagePreferencesController(
        store: store,
        initial: const LanguagePreferencesLoadResult(),
      );
      addTearDown(controller.dispose);
      final write = controller.setSelectedTag('en');
      await tester.pumpWidget(
        host(
          controller,
          localeOverride: const Locale('en'),
          reduceMotion: true,
        ),
      );
      await pumpActualLocaleReady(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(LanguageSettingsScreen.savingKey), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
      store.pending.removeAt(0).complete();
      await write;
      await tester.pumpAndSettle();
    },
  );
}

class _ControlledStore implements LanguagePreferencesStore {
  final calls = <String?>[];
  final pending = <Completer<void>>[];
  @override
  Future<LanguagePreferencesLoadResult> load() async =>
      const LanguagePreferencesLoadResult();
  @override
  Future<void> save(String? selectedTag) {
    calls.add(selectedTag);
    final completion = Completer<void>();
    pending.add(completion);
    return completion.future;
  }
}

class _DelayedLoadStore implements LanguagePreferencesStore {
  final pending = Completer<LanguagePreferencesLoadResult>();
  final saves = <String?>[];
  @override
  Future<LanguagePreferencesLoadResult> load() => pending.future;
  @override
  Future<void> save(String? selectedTag) async => saves.add(selectedTag);
}
