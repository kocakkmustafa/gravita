import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/onboarding_screen.dart';

void main() {
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> showCameraStep(
    WidgetTester tester,
    Future<void> Function() complete,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: OnboardingFlow(onComplete: complete)),
    );
    await tester.tap(find.byKey(OnboardingFlow.valueContinueKey));
    await tester.pump();
    await tester.tap(find.byKey(OnboardingFlow.safetyConsentKey));
    await tester.pump();
  }

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
