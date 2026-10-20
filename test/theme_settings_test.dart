import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_connection.dart';
import 'package:gravita/app/account_store_epoch.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/gravita_app.dart';
import 'package:gravita/app/profile_screen.dart';
import 'package:gravita/app/theme.dart';
import 'package:gravita/app/theme_preferences.dart';
import 'package:gravita/app/theme_settings_screen.dart';

import 'support/locale_asset_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await warmActualLocaleAssets();
    await ContentRepository.load(rootBundle);
  });

  Widget host(
    ThemePreferencesController controller, {
    Widget? home,
    Locale? locale,
  }) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => ThemePreferencesScope(
      controller: controller,
      child: MaterialApp(
        theme: GravitaTheme.light,
        darkTheme: GravitaTheme.dark,
        themeMode: controller.themeMode,
        locale: locale ?? const Locale('en'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: home ?? const ThemeSettingsScreen(),
      ),
    ),
  );

  testWidgets('preloaded dark mode is applied to the first Flutter frame', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final controller = ThemePreferencesController.ephemeral(
      mode: GravitaThemeMode.dark,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(GravitaApp(themePreferences: controller));
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await pumpActualLocaleReady(tester);
    expect(
      Theme.of(tester.element(find.byType(Navigator))).brightness,
      Brightness.dark,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'system follows platform changes and explicit mode ignores them',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final controller = ThemePreferencesController.ephemeral();
      addTearDown(controller.dispose);
      await tester.pumpWidget(host(controller));
      await pumpActualLocaleReady(tester);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(ThemeSettingsScreen))).brightness,
        Brightness.dark,
      );
      await tester.tap(find.byKey(ThemeSettingsScreen.lightKey));
      await tester.pumpAndSettle();
      expect(controller.mode, GravitaThemeMode.light);
      expect(
        Theme.of(tester.element(find.byType(ThemeSettingsScreen))).brightness,
        Brightness.light,
      );
    },
  );

  testWidgets(
    'settings show pending and sanitized failure with a working retry',
    (tester) async {
      final store = _WidgetStore();
      final controller = ThemePreferencesController(
        store: store,
        initial: const ThemePreferencesLoadResult(),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(host(controller));
      await pumpActualLocaleReady(tester);
      await tester.tap(find.byKey(ThemeSettingsScreen.darkKey));
      await tester.pump();
      expect(find.byKey(ThemeSettingsScreen.savingKey), findsOneWidget);
      expect(controller.mode, GravitaThemeMode.dark);
      store.pending
          .removeAt(0)
          .completeError(StateError('/private/sensitive/path'));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(ThemeSettingsScreen.failureKey), findsOneWidget);
      expect(find.textContaining('/private/sensitive/path'), findsNothing);
      await tester.ensureVisible(find.byKey(ThemeSettingsScreen.retryKey));
      await tester.tap(find.byKey(ThemeSettingsScreen.retryKey));
      await tester.pump();
      store.pending.removeAt(0).complete();
      await tester.pumpAndSettle();
      expect(find.byKey(ThemeSettingsScreen.failureKey), findsNothing);
      expect(find.byKey(ThemeSettingsScreen.savingKey), findsNothing);
      expect(store.calls, <GravitaThemeMode>[
        GravitaThemeMode.dark,
        GravitaThemeMode.dark,
      ]);
    },
  );

  testWidgets(
    'corrupt-load fallback is visible and contains no raw exception',
    (tester) async {
      final controller = ThemePreferencesController(
        store: _WidgetStore(),
        initial: const ThemePreferencesLoadResult(
          issue: ThemePreferencesLoadIssue.invalid,
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(host(controller));
      await pumpActualLocaleReady(tester);
      expect(find.byKey(ThemeSettingsScreen.loadIssueKey), findsOneWidget);
      expect(
        find.textContaining('original file has been kept'),
        findsOneWidget,
      );
      expect(controller.mode, GravitaThemeMode.system);
    },
  );

  testWidgets(
    'profile opens actual appearance settings and removes no-settings contradiction',
    (tester) async {
      late ContentRepository content;
      await tester.runAsync(
        () async => content = await ContentRepository.load(rootBundle),
      );
      final controller = ThemePreferencesController.ephemeral();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(controller, home: ProfileScreen(content: content)),
      );
      await pumpActualLocaleReady(tester);
      expect(find.byKey(ProfileScreen.appearanceKey), findsOneWidget);
      expect(find.text('Nothing to configure'), findsNothing);
      expect(
        find.text('There are no measurement preferences to change.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(ProfileScreen.appearanceKey));
      await tester.pumpAndSettle();
      expect(find.byType(ThemeSettingsScreen), findsOneWidget);
      await tester.tap(find.byKey(ThemeSettingsScreen.darkKey));
      await tester.pumpAndSettle();
      expect(controller.mode, GravitaThemeMode.dark);
    },
  );

  testWidgets('Turkish settings render at narrow width with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = ThemePreferencesController.ephemeral();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        controller,
        locale: const Locale('tr'),
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: ThemeSettingsScreen(),
        ),
      ),
    );
    await pumpActualLocaleReady(tester);
    await tester.pumpAndSettle();
    expect(find.text('Görünüm'), findsOneWidget);
    expect(find.text('Cihaz temasını kullan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'theme change keeps Navigator, active route, MaterialApp key and account epoch',
    (tester) async {
      const userId = '00000000-0000-4000-8000-000000000001';
      await tester.runAsync(() async {
        await AccountStoreEpochRegistry.resetForTest();
        await AccountStoreEpochRegistry.enableManagedAdmission();
      });
      final user = ValueNotifier<String?>(userId);
      final recovery = ValueNotifier<bool>(false);
      final controller = ThemePreferencesController.ephemeral();
      final account = AccountConnection(
        userId: user,
        passwordRecovery: recovery,
        pageBuilder: (_) => const Scaffold(),
        isIdentityAdmitted: () => true,
      );
      try {
        await tester.pumpWidget(
          GravitaApp(accountConnection: account, themePreferences: controller),
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
              builder: (_) => const ThemeSettingsScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await controller.setMode(GravitaThemeMode.dark);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).key,
          materialKey,
        );
        expect(
          tester.state<NavigatorState>(find.byType(Navigator)),
          same(navigator),
        );
        expect(find.byType(ThemeSettingsScreen), findsOneWidget);
        expect(AccountStoreEpochRegistry.capture(userId), same(epoch));
        expect(epoch.checkCurrent, returnsNormally);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        user.dispose();
        recovery.dispose();
        await tester.runAsync(AccountStoreEpochRegistry.resetForTest);
      }
    },
  );

  testWidgets(
    'reduced motion disables theme transition and dark status icons match surface',
    (tester) async {
      final controller = ThemePreferencesController.ephemeral(
        mode: GravitaThemeMode.dark,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: GravitaApp(themePreferences: controller),
        ),
      );
      expect(
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .themeAnimationDuration,
        Duration.zero,
      );
      await pumpActualLocaleReady(tester);
      final overlays = tester.widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(
        overlays.any(
          (overlay) =>
              overlay.value.statusBarIconBrightness == Brightness.light,
        ),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _WidgetStore implements ThemePreferencesStore {
  final calls = <GravitaThemeMode>[];
  final pending = <Completer<void>>[];

  @override
  Future<ThemePreferencesLoadResult> load() async =>
      const ThemePreferencesLoadResult();

  @override
  Future<void> save(GravitaThemeMode mode) {
    calls.add(mode);
    final completion = Completer<void>();
    pending.add(completion);
    return completion.future;
  }
}
