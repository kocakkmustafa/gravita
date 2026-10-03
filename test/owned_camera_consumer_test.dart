import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/camera_release_latch.dart';
import 'package:gravita/app/live_session_screen.dart';
import 'package:gravita/app/pose_model.dart';
import 'package:gravita_engine/gravita_engine.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'owned_camera_protocol_fixture.dart';
import 'account_action_ticket_test.dart' show AccountHttpFixture, ticketAlice;
import 'package:motion_account/motion_account.dart';
import 'package:gravita/app/account_connection.dart';
import 'package:gravita/app/motion_account_bootstrap.dart';
import 'package:gravita/app/account_store_epoch.dart';

/// The app consumes final, real Core leases through actual mocked channels.
/// Synthetic native/model responses establish ownership behavior only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory support;
  late PathProviderPlatform originalSupport;
  late OwnedSupportDirectory model;
  late OwnedPermissionFixture permission;
  late OwnedCameraProtocolFixture native;
  late MovementConfig movement;

  setUp(() {
    CameraReleaseLatch.resetForTest();
    originalSupport = PathProviderPlatform.instance;
    support = Directory.systemTemp.createTempSync(
      'gravita-two-owner-SYNTHETIC-',
    );
    File(
      '${support.path}/${PoseModelPin.assetPath.split('/').last}',
    ).writeAsStringSync('SYNTHETIC SENTINEL; NOT A MEDIAPIPE MODEL');
    model = OwnedSupportDirectory(support.path);
    PathProviderPlatform.instance = model;
    movement = MovementConfig.parse(
      File('content/catalog/w1/push_up.json').readAsStringSync(),
    );
    permission = OwnedPermissionFixture()..install();
    native = OwnedCameraProtocolFixture()..install();
  });

  tearDown(() {
    native.uninstall();
    permission.uninstall();
    PathProviderPlatform.instance = originalSupport;
    CameraReleaseLatch.resetForTest();
    support.deleteSync(recursive: true);
  });

  Future<void> show(WidgetTester tester, {bool a = true, bool b = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: Stack(
          children: [
            if (a)
              Offstage(
                key: const ValueKey('route-A'),
                offstage: b,
                child: LiveSessionScreen(
                  key: const ValueKey('A'),
                  config: movement,
                  controller: native.controller,
                  onSessionEnd: (_) async {},
                ),
              ),
            if (b)
              Offstage(
                key: const ValueKey('route-B'),
                offstage: false,
                child: LiveSessionScreen(
                  key: const ValueKey('B'),
                  config: movement,
                  controller: native.controller,
                  onSessionEnd: (_) async {},
                ),
              ),
          ],
        ),
      ),
    );
    await tester.pump();
  }

  Finder inside(String id, Finder child) => find.descendant(
    of: find.byKey(ValueKey(id), skipOffstage: false),
    matching: child,
    skipOffstage: false,
  );
  Finder button(String id, Key key) =>
      inside(id, find.byKey(key, skipOffstage: false));
  Finder frames(String id, int count) =>
      inside(id, find.text('$count frames', skipOffstage: false));
  VoidCallback callback(WidgetTester tester, String id, Key key) =>
      tester.widget<FilledButton>(button(id, key)).onPressed!;

  Future<void> startA(WidgetTester tester) async {
    await show(tester);
    callback(tester, 'A', LiveSessionScreen.startButtonKey)();
    await _until(tester, () => native.rawListens == 1, 'A native subscription');
    await native.emit(1);
    await _until(
      tester,
      () => frames('A', 1).evaluate().isNotEmpty,
      'A first frame',
    );
  }

  void consumer(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        permission.releasePending();
        model.releasePending();
        native.releasePending();
        await _until(
          tester,
          () => !CameraReleaseLatch.isHolding,
          'bounded consumer cleanup',
        );
        expect(native.usedLegacy, isFalse);
        expect(tester.takeException(), isNull);
      }
    });
  }

  for (final scenario in ['completed capture', 'pending native create', 'active capture']) {
    consumer('real Session held refresh fences $scenario admission', (tester) async {
      late AccountHttpFixture fixture;
      late MotionAccountRuntime runtime;
      late Completer<void> hold;
      Future<Object?>? outcome;
      await tester.runAsync(() async {
        await AccountStoreEpochRegistry.resetForTest();
        await AccountStoreEpochRegistry.enableManagedAdmission();
        hold = Completer<void>();
        fixture = AccountHttpFixture();
        runtime = MotionAccountRuntime.forTesting(client: fixture.client,
          app: MotionApp.gravita, onDeletedAccount: (_) async {});
        await fixture.session(ticketAlice);
        await runtime.refreshIdentity();
        await Future<void>.delayed(Duration.zero);
      });
      try {
        expect(runtime.isCurrentSessionVerified, isTrue, reason: 'real initial Session proof');
        final connection = bindGravitaMotionAccount(runtime, clearLocalData: (_) async {});
        expect(connection.isIdentityAdmitted!(), isTrue);
        expect(connection.isCurrentIdentityVerified!(), isTrue);
        // This screen harness has no GravitaApp host. Mirror its admitted
        // store activation only after actual Core proof has succeeded.
        AccountStoreEpochRegistry.activate(ticketAlice);
        await tester.pumpWidget(MaterialApp(home: AccountScope(
          connection: connection, currentUserId: ticketAlice,
          child: LiveSessionScreen(key: const ValueKey('A'), config: movement,
            controller: native.controller, onSessionEnd: (_) async {}))));
        await tester.pump();
        expect(runtime.isCurrentSessionVerified, isTrue, reason: 'proof before Start');
        expect(AccountStoreEpochRegistry.capture(ticketAlice).checkCurrent, returnsNormally);
        final delayed = scenario == 'pending native create' ? native.delayNextStart() : null;
        callback(tester, 'A', LiveSessionScreen.startButtonKey)();
        await _until(tester, () => native.startCalls == 1, 'first native admission');
        if (delayed == null) {
          await _until(tester, () => native.rawListens == 1, 'live subscription');
        }
        if (scenario == 'completed capture') {
          callback(tester, 'A', LiveSessionScreen.stopButtonKey)();
          await _until(tester, () => !CameraReleaseLatch.isHolding && native.stopCalls > 0,
            'completed capture ACK');
          await _until(tester, () => button('A', LiveSessionScreen.goAgainKey).evaluate().isNotEmpty, 'finished capture UI');
          callback(tester, 'A', LiveSessionScreen.goAgainKey)();
          await tester.pump();
        }
        await tester.runAsync(() async {
          fixture.userReadHold = hold;
          fixture.userReadStarted = Completer<void>();
          await fixture.client.auth.refreshSession();
          outcome = runtime.refreshIdentity().then<Object?>(
            (_) => null, onError: (Object error, StackTrace _) => error);
          await fixture.userReadStarted!.future.timeout(const Duration(seconds: 5));
        });
        expect(runtime.isCurrentSessionVerified, isFalse);
        await tester.pump();
        if (scenario == 'completed capture') {
          final start = tester.widget<FilledButton>(button('A', LiveSessionScreen.startButtonKey)).onPressed;
          start?.call();
          await tester.pump();
          expect(native.startCalls, 1, reason: 'ACKed old lease grants no fresh Session proof');
        } else if (delayed != null) {
          native.releasePending();
          await _until(tester, () => !CameraReleaseLatch.isHolding, 'stale create owned close');
          expect(native.rawListens, 0, reason: 'late native creation cannot publish a stream');
          expect(native.stopCalls, greaterThan(0));
        } else {
          expect(native.stopCalls, 0, reason: 'ordinary refresh retains live owner');
          await native.emit(1);
          await _until(tester, () => frames('A', 1).evaluate().isNotEmpty, 'retained live frame');
        }
      } finally {
        hold.complete();
        fixture.userReadHold = null;
        await tester.runAsync(() async { if (outcome != null) await outcome; });
        await tester.pumpWidget(const SizedBox.shrink());
        native.releasePending();
        await _until(tester, () => !CameraReleaseLatch.isHolding, 'runtime camera teardown');
        await tester.runAsync(() async {
          runtime.dispose();
          await fixture.dispose();
          await AccountStoreEpochRegistry.resetForTest();
        });
      }
    });
  }

  consumer('B busy rejection and owned close leave live A frames intact', (
    tester,
  ) async {
    await startA(tester);
    final a = native.owner!;
    callback(tester, 'B', LiveSessionScreen.startButtonKey)();
    await _until(
      tester,
      () =>
          native.startCalls == 2 &&
          native.readbackCalls == 1 &&
          !CameraReleaseLatch.isHolding,
      'B rejected owner closed',
    );
    expect(native.owner, a);
    expect(native.rawListens, 1);
    expect(native.rawCancels, 0);
    expect(
      inside('B', find.byKey(LiveSessionScreen.failureKey)).evaluate(),
      hasLength(1),
    );
    final bStop = native.controlCalls.singleWhere(
      (call) => call.method == 'stopOwned',
    );
    expect(OwnedCameraProtocolFixture.args(bStop)['ownerId'], isNot(a));
    await native.emit(2);
    await _until(
      tester,
      () => frames('A', 2).evaluate().isNotEmpty,
      'A survives B failure',
    );
  });

  consumer('retiring pending rejected B never sends global Stop or cancels A', (
    tester,
  ) async {
    await startA(tester);
    final a = native.owner!;
    final rejected = Completer<Object?>();
    native.nextBusyStart = rejected;
    callback(tester, 'B', LiveSessionScreen.startButtonKey)();
    await _until(
      tester,
      () => native.startCalls == 2,
      'B pending busy response',
    );
    await show(tester, b: false);
    await _until(
      tester,
      () => native.stopCalls == 1,
      'retired B owned Stop dispatched',
    );
    expect(CameraReleaseLatch.isHolding, isTrue);
    expect(native.owner, a);
    expect(native.rawCancels, 0);
    await native.emit(2);
    await _until(
      tester,
      () => frames('A', 2).evaluate().isNotEmpty,
      'A while B close waits',
    );
    rejected.completeError(PlatformException(code: 'already-running'));
    await _until(
      tester,
      () => !CameraReleaseLatch.isHolding,
      'B settled and read back closed',
    );
    expect(CameraReleaseLatch.requiresRecovery, isFalse);
    expect(native.owner, a);
    expect(native.rawListens, 1);
    await native.emit(3);
    await _until(
      tester,
      () => frames('A', 3).evaluate().isNotEmpty,
      'A after B close',
    );
  });

  consumer(
    'denied B then successful B cannot be torn down by late A Stop or disposal',
    (tester) async {
      await startA(tester);
      final a = native.owner!;
      final oldStop = callback(tester, 'A', LiveSessionScreen.stopButtonKey);
      permission.status = 0;
      callback(tester, 'B', LiveSessionScreen.startButtonKey)();
      await _until(
        tester,
        () =>
            inside(
              'B',
              find.byKey(LiveSessionScreen.failureKey),
            ).evaluate().isNotEmpty &&
            !CameraReleaseLatch.isHolding,
        'B denied before native work',
      );
      expect(native.owner, a);
      expect(native.startCalls, 1);
      expect(native.stopCalls, 0);
      await native.emit(2);
      await _until(
        tester,
        () => frames('A', 2).evaluate().isNotEmpty,
        'A after denied B',
      );
      oldStop();
      await _until(
        tester,
        () => native.readbackCalls == 1 && !CameraReleaseLatch.isHolding,
        'A native drain and fresh readback',
      );
      permission.status = 1;
      callback(tester, 'B', LiveSessionScreen.startButtonKey)();
      await _until(
        tester,
        () => native.rawListens == 2,
        'B successor subscription',
      );
      final b = native.owner!;
      expect(b, isNot(a));
      final calls = native.controlCalls.length;
      final cancels = native.rawCancels;
      oldStop();
      await show(tester, a: false);
      await _turn(tester);
      expect(native.owner, b);
      expect(native.controlCalls.length, calls);
      expect(native.rawCancels, cancels);
      await native.emit(3, ownerId: a);
      await tester.pump();
      expect(frames('B', 0), findsOneWidget);
      await native.emit(4);
      await _until(
        tester,
        () => frames('B', 1).evaluate().isNotEmpty,
        'B survives late A teardown',
      );
    },
  );

  consumer(
    'paused old app subscription cannot block native close or cancel live B',
    (tester) async {
      final old = native.controller.createCaptureLease();
      var started = false;
      final starting = old
          .start(
            modelPath: '/SYNTHETIC.task',
            modelId: 'synthetic; no-native-inference',
          )
          .then((_) => started = true);
      await _until(tester, () => started, 'old owned start');
      await starting;
      final oldSub = old.frames().listen((_) {});
      await _until(
        tester,
        () => native.rawListens == 1,
        'old private raw listen',
      );
      oldSub.pause();
      var closed = false;
      final closing = old.close().then((_) => closed = true);
      await _until(
        tester,
        () => closed,
        'owned close independent of paused app bus',
      );
      await closing;
      expect(native.rawCancels, 1);
      expect(native.readbackCalls, 1);
      await show(tester, a: false);
      callback(tester, 'B', LiveSessionScreen.startButtonKey)();
      await _until(tester, () => native.rawListens == 2, 'B new raw listen');
      final b = native.owner!;
      final calls = native.controlCalls.length;
      var cancelled = false;
      final cancelling = oldSub.cancel().then((_) => cancelled = true);
      await _until(tester, () => cancelled, 'old app cancellation');
      await cancelling;
      await old.close();
      await _turn(tester);
      expect(native.owner, b);
      expect(native.rawCancels, 1);
      expect(native.controlCalls.length, calls);
      expect(native.frameCalls.map((call) => call.method), [
        'listen',
        'cancel',
        'listen',
      ]);
      await native.emit(1);
      await _until(
        tester,
        () => frames('B', 1).evaluate().isNotEmpty,
        'B receives frame after old app cancel',
      );
    },
  );

  consumer(
    'retained native cancel reply blocks close readback and replacement B until ACK',
    (tester) async {
      await startA(tester);
      final a = native.owner!;
      final cancelReply = native.delayNextRawCancel();
      callback(tester, 'A', LiveSessionScreen.stopButtonKey)();
      await _until(
        tester,
        () =>
            native.rawCancels == 1 &&
            native.protocolTrace.contains('reply-stopOwned'),
        'owned Stop ACK and retained native cancel request',
      );
      expect(native.rawCancelReplies, 0);
      expect(
        native.readbackCalls,
        0,
        reason: 'native cancel dispatch is not its ACK',
      );
      expect(
        CameraReleaseLatch.isHolding,
        isTrue,
        reason:
            'lease.close must retain the native MethodChannel cancel Future',
      );

      callback(tester, 'B', LiveSessionScreen.startButtonKey)();
      await _until(
        tester,
        () => permission.requests == 2,
        'B permission may settle while A native cancellation remains pending',
      );
      await _turn(tester);
      expect(native.startCalls, 1);
      expect(native.rawListens, 1);
      expect(native.readbackCalls, 0);
      expect(CameraReleaseLatch.isHolding, isTrue);
      expect(native.rawCancelReplies, 0);

      cancelReply.complete();
      await _until(
        tester,
        () =>
            native.rawCancelReplies == 1 &&
            native.readbackCalls == 1 &&
            native.startCalls == 2 &&
            native.rawListens == 2 &&
            !CameraReleaseLatch.isHolding,
        'actual native cancel ACK then fresh readback admits B',
      );
      final b = native.owner!;
      expect(b, isNot(a));
      expect(
        native.protocolTrace.indexOf('reply-frame-cancel'),
        lessThan(native.protocolTrace.indexOf('dispatch-readback')),
      );
      expect(
        native.protocolTrace.indexOf('dispatch-readback'),
        lessThan(native.protocolTrace.lastIndexOf('dispatch-startOwned')),
      );
      expect(native.frameCalls.map((call) => call.method), [
        'listen',
        'cancel',
        'listen',
      ]);
      await native.emit(2, ownerId: a);
      await tester.pump();
      expect(frames('B', 0), findsOneWidget);
      await native.emit(3);
      await _until(
        tester,
        () => frames('B', 1).evaluate().isNotEmpty,
        'B frames continue after acknowledged A cancel',
      );
    },
  );

  consumer(
    'old native plugin is fail closed with owned-protocol failure and no legacy fallback',
    (tester) async {
      native.protocolAvailable = false;
      await show(tester, a: false);
      callback(tester, 'B', LiveSessionScreen.startButtonKey)();
      await _until(
        tester,
        () =>
            inside(
              'B',
              find.byKey(LiveSessionScreen.failureKey),
            ).evaluate().isNotEmpty &&
            !CameraReleaseLatch.isHolding,
        'unsupported owned protocol rejected',
      );
      expect(native.rawListens, 0);
      expect(native.usedLegacy, isFalse);
      expect(CameraReleaseLatch.requiresRecovery, isTrue);
      expect(
        tester
            .widget<FilledButton>(button('B', LiveSessionScreen.startButtonKey))
            .onPressed,
        isNull,
      );
    },
  );
}

Future<void> _turn(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 5)),
  );
  await tester.pump();
}

Future<void> _until(
  WidgetTester tester,
  bool Function() condition,
  String reason,
) async {
  await tester.pump();
  for (int turn = 0; turn < 40 && !condition(); turn++) {
    await _turn(tester);
  }
  expect(condition(), isTrue, reason: '$reason (40 bounded event turns)');
}
