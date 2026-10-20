import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_store_epoch.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/gravita_account_page.dart';
import 'package:gravita/app/gravita_app.dart';
import 'package:gravita/app/gravita_motion_host.dart';
import 'package:gravita/app/language_preferences.dart';
import 'package:gravita/app/localization/locale_delegate.dart';
import 'package:gravita/app/motion_account_bootstrap.dart';
import 'package:gravita/app/onboarding_screen.dart';
import 'package:gravita/app/theme.dart';
import 'package:gravita/app/theme_preferences.dart';
import 'package:motion_account/motion_account.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'account_action_ticket_test.dart' show AccountHttpFixture, ticketAlice;
import 'support/launch_harness.dart' show FakeSupportDir, settleUntil;
import 'support/locale_asset_harness.dart';

const _closedChildKey = Key('motion.host.must-remain-unadmitted');
const _retainedRouteKey = Key('motion.host.retained-route');

/// runAsync reports callback errors through Flutter's test error channel. The
/// completion assertion also prevents a failed callback from looking successful
/// merely because runAsync returned null. No exception is consumed here.
Future<void> _realStage(
  WidgetTester tester,
  String stage,
  Future<void> Function() operation,
) async {
  var completed = false;
  await tester.runAsync<void>(() async {
    print('motion-host stage START: $stage');
    await operation().timeout(const Duration(seconds: 5));
    completed = true;
    print('motion-host stage END: $stage');
  });
  expect(completed, isTrue, reason: 'Real async stage unfinished: $stage');
}

/// Only synthetic HTTP and an optional held /user response are test doubles.
/// All SDK objects, callbacks, completers and their drains start in runAsync.
class _AccountHarness {
  AccountHttpFixture? _fixture;
  MotionAccountRuntime? _runtime;
  Completer<void>? _hold;
  Future<Object?>? _proofOutcome;

  AccountHttpFixture get fixture => _fixture!;
  MotionAccountRuntime get runtime => _runtime!;

  Future<void> open({bool pending = false, bool verified = false}) async {
    await AccountStoreEpochRegistry.resetForTest();
    await AccountStoreEpochRegistry.enableManagedAdmission();
    final fixture = _fixture = AccountHttpFixture();
    if (pending || verified) await fixture.session(ticketAlice);
    if (pending) {
      fixture.userReadHold = _hold = Completer<void>();
      fixture.userReadStarted = Completer<void>();
    }
    final runtime = _runtime = MotionAccountRuntime.forTesting(
      client: fixture.client,
      app: MotionApp.gravita,
      onDeletedAccount: (_) async {},
      // Keep the genuine pending branch throughout 42 UI vectors. This test
      // override does not validate or change production's 10-second timeout.
      identityVerificationTimeout: pending
          ? const Duration(minutes: 2)
          : const Duration(seconds: 10),
    );
    if (pending) {
      // Attach observation immediately, but never await the held response.
      _proofOutcome = runtime.refreshIdentity().then<Object?>(
        (_) => null,
        onError: (Object error, StackTrace _) => error,
      );
      await fixture.userReadStarted!.future.timeout(const Duration(seconds: 2));
    } else {
      await runtime.refreshIdentity();
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> close() async {
    final hold = _hold;
    if (hold != null && !hold.isCompleted) hold.complete();
    _fixture?.userReadHold = null;
    try {
      final proof = _proofOutcome;
      if (proof != null) {
        expect(
          await proof.timeout(const Duration(seconds: 2)),
          isNull,
          reason: 'The observed public identity proof must drain successfully',
        );
      }
    } finally {
      _runtime?.dispose();
      // Drain callbacks already queued by released HTTP and stream cancellation.
      await Future<void>.delayed(Duration.zero);
      try {
        await _fixture?.dispose();
      } finally {
        await AccountStoreEpochRegistry.resetForTest();
      }
    }
  }
}

void _prepareView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void _expectPendingGate(
  WidgetTester tester, {
  required Locale locale,
  required Brightness brightness,
}) {
  final expected = MotionAccountLocalizations(locale);
  final status = find.text(expected.text(MotionAccountString.checkingAccount));
  expect(status, findsOneWidget, reason: 'Visible gate copy for $locale');
  final context = tester.element(status);
  final resource = Localizations.of<MotionAccountLocalizations>(
    context,
    MotionAccountLocalizations,
  );
  expect(resource, isNotNull, reason: 'Core delegate must actually load');
  expect(resource!.locale, locale);
  expect(Localizations.localeOf(context), locale);
  expect(Theme.of(context).brightness, brightness);
  expect(
    Directionality.of(context),
    locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
  );
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  expect(find.byKey(_closedChildKey, skipOffstage: false), findsNothing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Start genuine asset futures outside any widget FakeAsync zone.
    await warmActualLocaleAssets().timeout(const Duration(seconds: 10));
    await ContentRepository.load(
      rootBundle,
    ).timeout(const Duration(seconds: 10));
  });

  testWidgets(
    'production host cold pending gate renders 14 locales and light dark system vectors',
    (tester) async {
      _prepareView(tester);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final harness = _AccountHarness();
      var vectors = 0;
      try {
        await _realStage(
          tester,
          'cold pending identity',
          () => harness.open(pending: true),
        );
        expect(harness.runtime.phase.value, MotionIdentityPhase.verifying);
        expect(harness.runtime.isCurrentSessionVerified, isFalse);
        expect(appSupportedLocales, hasLength(14));
        for (final locale in appSupportedLocales) {
          for (final mode in GravitaThemeMode.values) {
            final language = LanguagePreferencesController.ephemeral(
              selectedTag: locale.toLanguageTag(),
            );
            final theme = ThemePreferencesController.ephemeral(mode: mode);
            try {
              print(
                'motion-host cold vector: ${locale.toLanguageTag()}/${mode.name}',
              );
              await tester.pumpWidget(
                GravitaMotionHost(
                  runtime: harness.runtime,
                  themePreferences: theme,
                  languagePreferences: language,
                  child: const SizedBox(key: _closedChildKey),
                ),
              );
              // This is the first pumped frame of a freshly mounted host, with
              // loaded preferences. No second frame may hide an English/light
              // first frame. Asset warmup is not a disk preference-load test.
              _expectPendingGate(
                tester,
                locale: locale,
                brightness: mode == GravitaThemeMode.light
                    ? Brightness.light
                    : Brightness.dark,
              );
              expect(harness.runtime.isCurrentSessionVerified, isFalse);
              vectors++;
            } finally {
              try {
                await tester.pumpWidget(const SizedBox());
              } finally {
                theme.dispose();
                language.dispose();
              }
            }
          }
        }
        expect(vectors, 42, reason: '42 vectors within this single test body');
        expect(harness.fixture.deletions, isEmpty);
        expect(harness.fixture.logoutCalls, 0);
      } finally {
        try {
          await tester.pumpWidget(const SizedBox());
        } finally {
          await _realStage(tester, 'cold pending teardown', harness.close);
        }
      }
    },
  );

  testWidgets(
    'production host follows live OS preferences and retains explicit Arabic',
    (tester) async {
      _prepareView(tester);
      tester.platformDispatcher.localesTestValue = const <Locale>[
        Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: 'TW',
        ),
        Locale('fr'),
      ];
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final harness = _AccountHarness();
      final language = LanguagePreferencesController.ephemeral();
      final theme = ThemePreferencesController.ephemeral();
      try {
        await _realStage(
          tester,
          'OS pending identity',
          () => harness.open(pending: true),
        );
        final requestCount = harness.fixture.requests.length;
        await tester.pumpWidget(
          GravitaMotionHost(
            runtime: harness.runtime,
            themePreferences: theme,
            languagePreferences: language,
            child: const SizedBox(key: _closedChildKey),
          ),
        );
        _expectPendingGate(
          tester,
          locale: const Locale('fr'),
          brightness: Brightness.light,
        );
        tester.platformDispatcher.localesTestValue = const <Locale>[
          Locale('zz'),
        ];
        await tester.pump();
        _expectPendingGate(
          tester,
          locale: const Locale('en'),
          brightness: Brightness.light,
        );
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        _expectPendingGate(
          tester,
          locale: const Locale('en'),
          brightness: Brightness.dark,
        );
        await language.setSelectedTag('ar');
        await tester.pump();
        _expectPendingGate(
          tester,
          locale: const Locale('ar'),
          brightness: Brightness.dark,
        );
        tester.platformDispatcher.localesTestValue = const <Locale>[
          Locale('ja'),
        ];
        tester.platformDispatcher.platformBrightnessTestValue =
            Brightness.light;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        _expectPendingGate(
          tester,
          locale: const Locale('ar'),
          brightness: Brightness.light,
        );
        expect(language.selectedTag, 'ar');
        expect(theme.mode, GravitaThemeMode.system);
        expect(harness.runtime.isCurrentSessionVerified, isFalse);
        expect(harness.fixture.requests, hasLength(requestCount));
        expect(harness.fixture.deletions, isEmpty);
        expect(harness.fixture.logoutCalls, 0);
      } finally {
        try {
          await tester.pumpWidget(const SizedBox());
        } finally {
          theme.dispose();
          language.dispose();
          await _realStage(tester, 'OS pending teardown', harness.close);
        }
      }
    },
  );

  testWidgets(
    'production host presentation changes preserve admitted app state navigator session and owner epoch',
    (tester) async {
      _prepareView(tester);
      final harness = _AccountHarness();
      final language = LanguagePreferencesController.ephemeral(
        selectedTag: 'en',
      );
      final theme = ThemePreferencesController.ephemeral(
        mode: GravitaThemeMode.light,
      );
      final originalProvider = PathProviderPlatform.instance;
      Directory? supportDirectory;
      try {
        await _realStage(
          tester,
          'admitted identity and isolated storage',
          () async {
            supportDirectory = await Directory.systemTemp.createTemp(
              'gravita-motion-host-',
            );
            PathProviderPlatform.instance = FakeSupportDir(
              supportDirectory!.path,
            );
            await harness.open(verified: true);
          },
        );
        expect(harness.runtime.isCurrentSessionVerified, isTrue);
        final cleanupCalls = <String>[];
        final connection = bindGravitaMotionAccount(
          harness.runtime,
          clearLocalData: (id) async => cleanupCalls.add(id),
        );
        final child = GravitaApp(
          key: const ValueKey('motion-host-real-app'),
          accountConnection: connection,
          themePreferences: theme,
          languagePreferences: language,
        );
        await tester.pumpWidget(
          GravitaMotionHost(
            runtime: harness.runtime,
            themePreferences: theme,
            languagePreferences: language,
            child: child,
          ),
        );
        await pumpActualLocaleReady(tester);
        print('motion-host stage START: real onboarding read');
        await settleUntil(
          tester,
          () => find.byType(OnboardingFlow).evaluate().length == 1,
        );
        expect(find.byType(OnboardingFlow), findsOneWidget);
        print('motion-host stage END: real onboarding read');
        final appFinder = find.byType(GravitaApp, skipOffstage: false);
        final rootFinder = find.byType(GravitaRoot, skipOffstage: false);
        final appState = tester.state(appFinder);
        final rootState = tester.state(rootFinder);
        final materialKey = tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .key;
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        final epoch = AccountStoreEpochRegistry.capture(ticketAlice);
        final session = harness.fixture.client.auth.currentSession;
        final requestCount = harness.fixture.requests.length;
        expect(connection.isIdentityAdmitted!(), isTrue);
        expect(connection.isCurrentIdentityVerified!(), isTrue);
        final retainedRoute = MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: Text('Retained route', key: _retainedRouteKey),
          ),
        );
        var routeDidPop = false;
        var routeDisposed = false;
        unawaited(
          retainedRoute.completed.then<void>((_) => routeDisposed = true),
        );
        unawaited(
          navigator
              .push<void>(retainedRoute)
              .then<void>((_) => routeDidPop = true),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(_retainedRouteKey), findsOneWidget);

        await language.setSelectedTag('ar');
        await theme.setMode(GravitaThemeMode.dark);
        await pumpActualLocaleReady(tester);
        await tester.pump(const Duration(milliseconds: 300));
        final routeContext = tester.element(find.byKey(_retainedRouteKey));
        expect(Localizations.localeOf(routeContext), const Locale('ar'));
        expect(Theme.of(routeContext).brightness, Brightness.dark);
        expect(Directionality.of(routeContext), TextDirection.rtl);
        expect(tester.state(appFinder), same(appState));
        expect(tester.state(rootFinder), same(rootState));
        expect(
          tester.state<NavigatorState>(find.byType(Navigator)),
          same(navigator),
        );
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).key,
          materialKey,
        );
        expect(
          tester
              .widget<MotionIdentityGate>(find.byType(MotionIdentityGate))
              .runtime,
          same(harness.runtime),
        );
        expect(
          tester
              .widget<GravitaMotionHost>(find.byType(GravitaMotionHost))
              .child,
          same(child),
        );
        expect(harness.fixture.client.auth.currentSession, same(session));
        expect(harness.runtime.userId.value, ticketAlice);
        expect(harness.runtime.isCurrentSessionVerified, isTrue);
        expect(connection.isIdentityAdmitted!(), isTrue);
        expect(connection.isCurrentIdentityVerified!(), isTrue);
        expect(AccountStoreEpochRegistry.capture(ticketAlice), same(epoch));
        expect(epoch.checkCurrent, returnsNormally);
        expect(harness.fixture.requests, hasLength(requestCount));
        expect(harness.fixture.deletions, isEmpty);
        expect(harness.fixture.logoutCalls, 0);
        expect(cleanupCalls, isEmpty);
        expect(retainedRoute.isCurrent, isTrue);
        expect(retainedRoute.navigator, same(navigator));
        navigator.pop();
        await tester.pump();
        await tester.pump(retainedRoute.reverseTransitionDuration);
        // Flutter's interpolation completes strictly after its duration. Let
        // the actual route finish and dispose on a bounded later fake frame.
        for (var frame = 0; frame < 3 && !routeDisposed; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(routeDidPop, isTrue);
        expect(
          routeDisposed,
          isTrue,
          reason: 'The retained route must complete and dispose after pop',
        );
        expect(find.byKey(_retainedRouteKey), findsNothing);
        expect(
          find.byKey(_retainedRouteKey, skipOffstage: false),
          findsNothing,
        );
        expect(find.byType(OnboardingFlow), findsOneWidget);
        expect(tester.state(rootFinder), same(rootState));
      } finally {
        try {
          try {
            await tester.pumpWidget(const SizedBox());
          } finally {
            theme.dispose();
            language.dispose();
            await _realStage(tester, 'admitted teardown', harness.close);
          }
        } finally {
          PathProviderPlatform.instance = originalProvider;
          await _realStage(tester, 'isolated storage removal', () async {
            final directory = supportDirectory;
            if (directory != null && await directory.exists()) {
              await directory.delete(recursive: true);
            }
          });
        }
      }
    },
  );

  testWidgets(
    'actual Gravita account page inherits all 14 Core delegates and dark theme',
    (tester) async {
      _prepareView(tester);
      final harness = _AccountHarness();
      var vectors = 0;
      try {
        await _realStage(tester, 'guest account identity', harness.open);
        expect(harness.runtime.phase.value, MotionIdentityPhase.signedOut);
        final requestCount = harness.fixture.requests.length;
        final cleanupCalls = <String>[];
        final connection = bindGravitaMotionAccount(
          harness.runtime,
          clearLocalData: (id) async => cleanupCalls.add(id),
        );
        for (final locale in appSupportedLocales) {
          final language = LanguagePreferencesController.ephemeral(
            selectedTag: locale.toLanguageTag(),
          );
          final theme = ThemePreferencesController.ephemeral(
            mode: GravitaThemeMode.dark,
          );
          try {
            print('motion-host account vector: ${locale.toLanguageTag()}/dark');
            await tester.pumpWidget(
              GravitaMotionHost(
                runtime: harness.runtime,
                themePreferences: theme,
                languagePreferences: language,
                // The account route uses the production delegates/resolver and
                // themes. Full app navigation is exercised by the preceding
                // test; this boundary isolates the real account page itself.
                child: MaterialApp(
                  locale: language.locale,
                  localeListResolutionCallback: resolveAppLocales,
                  supportedLocales: appSupportedLocales,
                  localizationsDelegates: appLocalizationsDelegates,
                  theme: GravitaTheme.light,
                  darkTheme: GravitaTheme.dark,
                  themeMode: theme.themeMode,
                  home: Builder(builder: connection.pageBuilder),
                ),
              ),
            );
            await pumpActualLocaleReady(tester);
            expect(find.byType(GravitaAccountPage), findsOneWidget);
            expect(find.byType(MotionAccountPage), findsOneWidget);
            final context = tester.element(find.byType(MotionAccountPage));
            final coreResource = Localizations.of<MotionAccountLocalizations>(
              context,
              MotionAccountLocalizations,
            );
            final appResource = Localizations.of<GravitaLocalizations>(
              context,
              GravitaLocalizations,
            );
            final expected = MotionAccountLocalizations(locale);
            expect(coreResource, isNotNull);
            expect(coreResource!.locale, locale);
            expect(appResource?.localeTag, locale.toLanguageTag());
            expect(Localizations.localeOf(context), locale);
            expect(Theme.of(context).brightness, Brightness.dark);
            expect(
              Directionality.of(context),
              locale.languageCode == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
            );
            expect(
              find.text(expected.text(MotionAccountString.accountTitle)),
              findsOneWidget,
            );
            expect(
              find.text(expected.text(MotionAccountString.signIn)),
              findsWidgets,
            );
            final labels = tester
                .widgetList<TextField>(find.byType(TextField))
                .map((field) => field.decoration?.labelText)
                .toList();
            expect(
              labels,
              containsAll(<String>[
                expected.text(MotionAccountString.email),
                expected.text(MotionAccountString.password),
              ]),
            );
            expect(harness.fixture.client.auth.currentSession, isNull);
            vectors++;
          } finally {
            try {
              await tester.pumpWidget(const SizedBox());
            } finally {
              theme.dispose();
              language.dispose();
            }
          }
        }
        expect(vectors, 14, reason: '14 vectors within this single test body');
        expect(harness.fixture.requests, hasLength(requestCount));
        expect(harness.fixture.deletions, isEmpty);
        expect(harness.fixture.logoutCalls, 0);
        expect(cleanupCalls, isEmpty);
      } finally {
        try {
          await tester.pumpWidget(const SizedBox());
        } finally {
          await _realStage(tester, 'guest account teardown', harness.close);
        }
      }
    },
  );
}
