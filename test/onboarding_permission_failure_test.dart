import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/camera_release_policy.dart';
import 'package:gravita/app/onboarding_screen.dart';

import 'support/locale_asset_harness.dart'
    show warmActualLocaleAssets, pumpActualLocaleReady;

void main() {
  setUpAll(warmActualLocaleAssets);
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> showCameraStep(
    WidgetTester tester,
    Future<void> Function() complete, {
    bool permissionTest = true,
    String language = 'en',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: permissionTest
            ? OnboardingFlow.permissionTest(onComplete: complete)
            : OnboardingFlow(onComplete: complete),
      ),
    );
    await pumpActualLocaleReady(tester);
    await tester.tap(find.byKey(OnboardingFlow.valueContinueKey));
    await tester.pump();
    await tester.tap(find.byKey(OnboardingFlow.safetyConsentKey));
    await tester.pump();
  }

  for (final language in <String>['en', 'tr']) {
    testWidgets(
      '$language closed release completes without Allow or permission calls',
      (tester) async {
        var calls = 0;
        var completed = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (_) async {
              calls++;
              throw StateError(
                'Closed release must not ask for camera permission',
              );
            });
        expect(motionPaidCameraLaunchEnabled, isFalse);
        await showCameraStep(
          tester,
          () async => completed++,
          permissionTest: false,
          language: language,
        );
        expect(find.byKey(OnboardingFlow.cameraAllowKey), findsNothing);
        expect(find.byKey(OnboardingFlow.cameraDeniedKey), findsNothing);
        expect(
          // g_06cc3b14a4df: reviewed packaged TR copy, ahead of fallback text.
          find.text(
            language == 'tr' ? 'Kamera kullanılamıyor' : 'Camera unavailable',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            language == 'tr'
                ? 'Canlı kamera seansları bu sürümde kullanılamıyor.'
                : 'Live camera sessions are unavailable in this release.',
          ),
          findsOneWidget,
        );
        final next = find.byKey(OnboardingFlow.cameraContinueWithoutKey);
        expect(next, findsOneWidget);
        expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
        await tester.tap(next);
        await tester.pump();
        expect(completed, 1);
        expect(calls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'closed completion stays single-flight while persistence is pending',
    (tester) async {
      final gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      var completed = 0;
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            calls++;
            throw StateError('No permission request in a closed release');
          });
      await showCameraStep(tester, () async {
        completed++;
        await gate.future;
      }, permissionTest: false);
      final next = find.byKey(OnboardingFlow.cameraContinueWithoutKey);
      final action = tester.widget<FilledButton>(next).onPressed!;
      action();
      action();
      await tester.pump();
      expect(completed, 1);
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
      expect(calls, 0);
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(completed, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('isolated enabled permission grant completes once', (
    tester,
  ) async {
    var requests = 0;
    var completed = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'requestPermissions') {
            requests++;
            return <int, int>{
              for (final value in call.arguments as List<dynamic>)
                value as int: 1,
            };
          }
          return 1;
        });
    await showCameraStep(tester, () async => completed++);
    await tester.tap(find.byKey(OnboardingFlow.cameraAllowKey));
    await tester.pump();
    await tester.pump();
    expect(requests, 1);
    expect(completed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permission platform failure leaves continue without usable', (
    tester,
  ) async {
    var completed = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'synthetic-permission-unavailable');
        });
    await showCameraStep(tester, () async => completed++);
    await tester.tap(find.byKey(OnboardingFlow.cameraAllowKey));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(completed, 0, reason: 'a failed request cannot complete onboarding');
    final skip = find.byKey(OnboardingFlow.cameraContinueWithoutKey);
    final widget = tester.widget(skip);
    expect(
      widget is FilledButton
          ? widget.onPressed
          : (widget as TextButton).onPressed,
      isNotNull,
    );
    await tester.tap(skip);
    await tester.pump();
    expect(completed, 1);
  });

  testWidgets('duplicate permission callbacks issue one native request', (
    tester,
  ) async {
    final gate = Completer<void>();
    var requests = 0;
    var completed = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          requests++;
          await gate.future;
          return <int, int>{
            for (final value in call.arguments as List<dynamic>)
              value as int: 0,
          };
        });
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    await showCameraStep(tester, () async => completed++);
    final action = tester
        .widget<FilledButton>(find.byKey(OnboardingFlow.cameraAllowKey))
        .onPressed!;
    action();
    action();
    await tester.pump();
    expect(requests, 1);
    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(
      completed,
      0,
      reason: 'denial never pretends permission was granted',
    );
    await tester.tap(find.byKey(OnboardingFlow.cameraContinueWithoutKey));
    await tester.pump();
    expect(completed, 1);
  });
}
