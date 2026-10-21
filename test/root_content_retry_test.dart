import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/content_failure_screen.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/gravita_app.dart';
import 'package:gravita/app/onboarding_screen.dart';
import 'package:gravita/app/theme.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/launch_harness.dart' show FakeSupportDir, settleUntil;
import 'support/locale_asset_harness.dart'
    show warmActualLocaleAssets, pumpActualLocaleReady;

class _RecoverableLibraryBundle extends CachingAssetBundle {
  bool libraryReadable = false;
  int libraryReads = 0;

  @override
  Future<ByteData> load(String key) => rootBundle.load(key);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == 'content/library.json') {
      libraryReads++;
      if (!libraryReadable) throw FlutterError('Temporary fixture asset read');
    }
    return rootBundle.loadString(key, cache: cache);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PathProviderPlatform originalProvider;
  late Directory support;

  setUpAll(() async {
    await warmActualLocaleAssets();
    await ContentRepository.load(rootBundle);
  });
  setUp(() async {
    originalProvider = PathProviderPlatform.instance;
    support = await Directory.systemTemp.createTemp('gravita-root-retry-');
    PathProviderPlatform.instance = FakeSupportDir(support.path);
  });
  tearDown(() async {
    PathProviderPlatform.instance = originalProvider;
    if (await support.exists()) await support.delete(recursive: true);
  });

  testWidgets('real root retry rebuilds after failure and keeps onboarding', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bundle = _RecoverableLibraryBundle();
    try {
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: bundle,
          child: MaterialApp(
            theme: GravitaTheme.light,
            locale: const Locale('en'),
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            localeListResolutionCallback: resolveAppLocales,
            home: const GravitaRoot(),
          ),
        ),
      );
      await pumpActualLocaleReady(tester);
      final retry = find.byKey(ContentFailureScreen.retryKey);
      await settleUntil(
        tester,
        () => retry.evaluate().isNotEmpty,
        maxRounds: 40,
      );
      expect(find.byType(ContentFailureScreen), findsOneWidget);
      expect(bundle.libraryReads, 1);
      expect(find.byType(GravitaShell), findsNothing);

      // A still unreadable asset must stay blocked after a real retry.
      expect(retry.hitTestable(), findsOneWidget);
      await tester.tap(retry);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await settleUntil(
        tester,
        () => bundle.libraryReads == 2 && retry.evaluate().isNotEmpty,
        maxRounds: 40,
      );
      expect(bundle.libraryReads, 2);
      expect(find.byType(ContentFailureScreen), findsOneWidget);
      expect(find.byType(OnboardingFlow), findsNothing);
      expect(find.byType(GravitaShell), findsNothing);

      // Repair only the fixture; the actual root must reload and rebuild.
      bundle.libraryReadable = true;
      expect(retry.hitTestable(), findsOneWidget);
      await tester.tap(retry);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await settleUntil(
        tester,
        () => find.byType(OnboardingFlow).evaluate().isNotEmpty,
        maxRounds: 40,
      );
      expect(bundle.libraryReads, 3);
      expect(find.byType(GravitaRoot), findsOneWidget);
      expect(find.byType(OnboardingFlow), findsOneWidget);
      expect(find.byType(ContentFailureScreen), findsNothing);
      expect(find.byType(GravitaShell), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
