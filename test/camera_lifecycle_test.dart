import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_action_ticket.dart';
import 'package:gravita/app/account_connection.dart';
import 'package:gravita/app/account_store_epoch.dart';
import 'package:gravita/app/camera_release_latch.dart';
import 'package:gravita/app/live_session_screen.dart';
import 'package:gravita/app/live_strings.dart';
import 'package:gravita/app/pose_model.dart';
import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_camera/motion_camera.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'account_action_ticket_test.dart'
    show AccountHttpFixture, accountHttpResponse, ticketAlice;
import 'owned_camera_protocol_fixture.dart';

/// Actual host + final Core leases + real mocked channel dispatch. The model
/// sentinel and native responses are synthetic, not physical/native acceptance.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory support;
  late PathProviderPlatform originalSupport;
  late OwnedSupportDirectory model;
  late OwnedPermissionFixture permission;
  late OwnedCameraProtocolFixture native;
  late MovementConfig movement;

  setUp(() async {
    await AccountStoreEpochRegistry.resetForTest();
    CameraReleaseLatch.resetForTest();
    originalSupport = PathProviderPlatform.instance;
    support = Directory.systemTemp.createTempSync('gravita-owned-SYNTHETIC-');
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

  tearDown(() async {
    native.uninstall();
    permission.uninstall();
    PathProviderPlatform.instance = originalSupport;
    CameraReleaseLatch.resetForTest();
    await AccountStoreEpochRegistry.resetForTest();
    support.deleteSync(recursive: true);
  });

  Future<void> show(
    WidgetTester tester, {
    String id = 'first',
    String? userId,
    AccountConnection? connection,
    Future<void> Function(SessionRecord)? sink,
    bool useRealStore = false,
  }) async {
    final screen = LiveSessionScreen(
      key: ValueKey(id),
      config: movement,
      controller: native.controller,
      accountUserId: userId,
      onSessionEnd: useRealStore ? null : sink ?? (_) async {},
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: connection == null
            ? screen
            : AccountScope(
                connection: connection,
                currentUserId: connection.userId.value,
                child: screen,
              ),
      ),
    );
    await tester.pump();
  }

  Future<void> running(
    WidgetTester tester, {
    AccountConnection? connection,
    String? userId,
    Future<void> Function(SessionRecord)? sink,
    bool useRealStore = false,
  }) async {
    await show(
      tester,
      connection: connection,
      userId: userId,
      sink: sink,
      useRealStore: useRealStore,
    );
    await tester.tap(find.byKey(LiveSessionScreen.startButtonKey));
    await untilOwned(
      tester,
      () =>
          native.rawListens == 1 &&
          find.byKey(LiveSessionScreen.stopButtonKey).evaluate().isNotEmpty,
      'running owned screen',
    );
  }

  bool startEnabled(WidgetTester tester) {
    final found = find.byKey(LiveSessionScreen.startButtonKey);
    return found.evaluate().isNotEmpty &&
        tester.widget<FilledButton>(found).onPressed != null;
  }

  void lifecycle(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        permission.releasePending();
        model.releasePending();
        native.releasePending();
        await untilOwned(
          tester,
          () => !CameraReleaseLatch.isHolding,
          'bounded owned close cleanup',
        );
        expect(native.usedLegacy, isFalse);
        expect(tester.takeException(), isNull);
      }
    });
  }

  lifecycle('pending owned start closes before the replacement starts', (
    tester,
  ) async {
    native.delayNextStart();
    await show(tester);
    await tester.tap(find.byKey(LiveSessionScreen.startButtonKey));
    await untilOwned(
      tester,
      () => native.startCalls == 1,
      'pending native start',
    );
    final oldOwner = native.owner;
    final stop = native.delayNextStop();
    await show(tester, id: 'successor');
    await tester.tap(find.byKey(LiveSessionScreen.startButtonKey));
    await untilOwned(
      tester,
      () => permission.requests == 2,
      'successor permission',
    );
    expect(native.startCalls, 1);
    expect(CameraReleaseLatch.isHolding, isTrue);
    stop.complete();
    await untilOwned(
      tester,
      () => native.startCalls == 2 && native.rawListens == 1,
      'owned ACK/readback admits replacement',
    );
    expect(native.owner, isNot(oldOwner));
    expect(native.readbackCalls, 1);
  });

  lifecycle('inactive then resumed never adopts the retired pending start', (
    tester,
  ) async {
    native.delayNextStart();
    await show(tester);
    await tester.tap(find.byKey(LiveSessionScreen.startButtonKey));
    await untilOwned(tester, () => native.startCalls == 1, 'pending start');
    final stop = native.delayNextStop();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    stop.complete();
    await untilOwned(
      tester,
      () => !CameraReleaseLatch.isHolding && startEnabled(tester),
      'explicit retry',
    );
    expect(native.rawListens, 0);
    await tester.tap(find.byKey(LiveSessionScreen.startButtonKey));
    await untilOwned(
      tester,
      () => native.startCalls == 2 && native.rawListens == 1,
      'fresh lease',
    );
  });

  lifecycle('permission reply before resume cannot revive the retired lease', (
    tester,
  ) async {
    final reply = Completer<int>();
    permission.nextReply = reply;
    await show(tester);
    await tester.tap(find.byKey(LiveSessionScreen.startButtonKey));
    await untilOwned(
      tester,
      () => permission.requests == 1,
      'delayed permission',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    reply.complete(1);
    await untilOwned(
      tester,
      () => find.byKey(LiveSessionScreen.startButtonKey).evaluate().isNotEmpty,
      'inactive Idle',
    );
    expect(startEnabled(tester), isFalse);
    expect(native.controlCalls, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await untilOwned(tester, () => startEnabled(tester), 'resume redraw');
    expect(native.controlCalls, isEmpty);
    await tester.tap(find.byKey(LiveSessionScreen.startButtonKey));
    await untilOwned(
      tester,
      () => native.rawListens == 1,
      'explicit new attempt',
    );
  });

  for (final delayedModel in [false, true]) {
    lifecycle(
      'dispose fences delayed ${delayedModel ? 'model' : 'permission'} before native start',
      (tester) async {
        if (delayedModel) {
          model.nextReply = Completer<String?>();
        } else {
          permission.nextReply = Completer<int>();
        }
        await show(tester);
        await tester.tap(find.byKey(LiveSessionScreen.startButtonKey));
        await untilOwned(
          tester,
          () => delayedModel ? model.requests == 1 : permission.requests == 1,
          'pre-native await',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        permission.releasePending();
        model.releasePending();
        await tickOwned(tester);
        expect(native.controlCalls, isEmpty);
        expect(native.frameCalls, isEmpty);
      },
    );
  }

  lifecycle('manual stop and immediate reopen await fresh readback', (
    tester,
  ) async {
    await running(tester);
    final readback = native.delayNextReadback();
    await tester.tap(find.byKey(LiveSessionScreen.stopButtonKey));
    await untilOwned(
      tester,
      () => native.readbackCalls == 1,
      'fresh close readback pending',
    );
    await show(tester, id: 'successor');
    await tester.tap(find.byKey(LiveSessionScreen.startButtonKey));
    await untilOwned(
      tester,
      () => permission.requests == 2,
      'successor permission',
    );
    expect(
      native.startCalls,
      1,
      reason: 'Stop ACK alone does not release the barrier',
    );
    readback.complete();
    await untilOwned(
      tester,
      () => native.startCalls == 2 && native.rawListens == 2,
      'readback then B',
    );
  });

  lifecycle(
    'private raw cancellation joins owned close before successor listen',
    (tester) async {
      await running(tester);
      final cancel = native.delayNextRawCancel();
      await tester.tap(find.byKey(LiveSessionScreen.stopButtonKey));
      await untilOwned(
        tester,
        () => native.rawCancels == 1 && native.stopCalls == 1,
        'raw cancel and owned Stop dispatched',
      );
      await show(tester, id: 'successor');
      await tester.tap(find.byKey(LiveSessionScreen.startButtonKey));
      await untilOwned(
        tester,
        () => permission.requests == 2,
        'successor requests',
      );
      expect(native.startCalls, 1);
      cancel.complete();
      await untilOwned(
        tester,
        () => native.startCalls == 2 && native.rawListens == 2,
        'raw native drain completed',
      );
    },
  );

  lifecycle(
    'frame transport error quarantines capture after Stop and rejects old-owner frames',
    (tester) async {
      await running(tester);
      final oldOwner = native.owner!;
      await native.emit(1);
      await untilOwned(
        tester,
        () => find.text('1 frames').evaluate().isNotEmpty,
        'first frame',
      );
      final stop = native.delayNextStop();
      await native.emitError();
      await untilOwned(
        tester,
        () =>
            native.stopCalls == 1 &&
            find.byKey(LiveSessionScreen.failureKey).evaluate().isNotEmpty,
        'frame error starts owned close',
      );
      expect(find.byKey(LiveSessionScreen.failureKey), findsOneWidget);
      stop.complete();
      await untilOwned(
        tester,
        () => !CameraReleaseLatch.isHolding && native.rawCancels == 1,
        'owned close settles with transport quarantine',
      );
      expect(startEnabled(tester), isFalse);
      expect(CameraReleaseLatch.requiresRecovery, isTrue);
      expect(native.readbackCalls, 0);
      await native.emit(2, ownerId: oldOwner);
      await tester.pump();
      expect(find.byKey(LiveSessionScreen.failureKey), findsOneWidget);
      expect(find.text('2 frames'), findsNothing);
      final controlCalls = native.controlCalls.length;
      await show(tester, id: 'fresh-route');
      expect(startEnabled(tester), isFalse);
      await tester.tap(find.byKey(LiveSessionScreen.startButtonKey));
      await tester.pump();
      await native.emit(3, ownerId: oldOwner);
      await tester.pump();
      expect(native.controlCalls.length, controlCalls);
      expect(native.startCalls, 1);
      expect(native.rawListens, 1);
      expect(find.byKey(LiveSessionScreen.failureKey), findsOneWidget);
    },
  );

  for (final failedStop in [false, true]) {
    lifecycle(
      '${failedStop ? 'failed Stop' : 'wrong nonce'} quarantines capture without global recovery or replacement controller',
      (tester) async {
        await running(tester);
        if (failedStop) {
          native.failNextStop();
        } else {
          native.wrongReadbackNonce = true;
        }
        await tester.tap(find.byKey(LiveSessionScreen.stopButtonKey));
        await untilOwned(
          tester,
          () =>
              !CameraReleaseLatch.isHolding &&
              find
                  .text(LiveStrings.failureTitle(CameraFailure.closeUncertain))
                  .evaluate()
                  .isNotEmpty,
          'uncertain owned close',
        );
        expect(startEnabled(tester), isFalse);
        expect(CameraReleaseLatch.requiresRecovery, isTrue);
        final calls = native.controlCalls.length;
        await show(tester, id: 'fresh-route');
        expect(startEnabled(tester), isFalse);
        await tester.tap(find.byKey(LiveSessionScreen.startButtonKey));
        await tester.pump();
        expect(native.controlCalls.length, calls);
        expect(native.startCalls, 1);
        expect(native.stopCalls, 1);
      },
    );
  }

  lifecycle(
    'duplicate button callbacks before rebuild admit only one owned lease start',
    (tester) async {
      await show(tester);
      final callback = tester
          .widget<FilledButton>(find.byKey(LiveSessionScreen.startButtonKey))
          .onPressed!;
      callback();
      callback();
      await untilOwned(
        tester,
        () => native.rawListens == 1,
        'single admitted attempt',
      );
      expect(permission.requests, 1);
      expect(native.startCalls, 1);
    },
  );

  for (final background in [false, true]) {
    lifecycle(
      'measured session persists once after ${background ? 'background' : 'manual'} close plus disposal',
      (tester) async {
        final records = <SessionRecord>[];
        final persistence = Completer<void>();
        try {
          await running(
            tester,
            sink: (record) async {
              records.add(record);
              await persistence.future;
            },
          );
          await native.emit(1);
          await untilOwned(
            tester,
            () => find.text('1 frames').evaluate().isNotEmpty,
            'measured frame',
          );
          final readback = native.delayNextReadback();
          if (background) {
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.inactive,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.paused,
            );
          } else {
            final callback = tester
                .widget<FilledButton>(
                  find.byKey(LiveSessionScreen.stopButtonKey),
                )
                .onPressed!;
            callback();
            callback();
          }
          await untilOwned(
            tester,
            () => native.readbackCalls == 1,
            'owned close readback',
          );
          await tester.pumpWidget(const SizedBox.shrink());
          expect(records, isEmpty);
          readback.complete();
          await untilOwned(
            tester,
            () => records.length == 1,
            'one frozen record',
          );
          expect(records.single.lessonId, 'movement:push_up');
          expect(records.single.unitsCompleted, 0);
          expect(native.stopCalls, 1);
          persistence.complete();
          await tickOwned(tester);
          expect(records, hasLength(1));
        } finally {
          if (!persistence.isCompleted) persistence.complete();
        }
      },
    );
  }

  for (final realStore in [false, true]) {
    lifecycle(
      'manual snapshot awaiting close cannot acquire fresh same-UUID ${realStore ? 'store' : 'sink'} after recovery',
      (tester) async {
        const userId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
        await AccountStoreEpochRegistry.enableManagedAdmission();
        final oldEpoch = AccountStoreEpochRegistry.activate(userId);
        final records = <SessionRecord>[];
        await running(
          tester,
          userId: userId,
          sink: (record) async => records.add(record),
          useRealStore: realStore,
        );
        await native.emit(1);
        await untilOwned(
          tester,
          () => find.text('1 frames').evaluate().isNotEmpty,
          'old measured session',
        );
        final readback = native.delayNextReadback();
        await tester.tap(find.byKey(LiveSessionScreen.stopButtonKey));
        await untilOwned(
          tester,
          () => native.readbackCalls == 1,
          'old manual close waiting',
        );
        // Shell disposal can detach the live account listener before recovery.
        // The captured epoch must still reject the late persistence callback.
        await tester.pumpWidget(const SizedBox.shrink());
        await AccountStoreEpochRegistry.retireAll();
        expect(oldEpoch.isActive, isFalse);
        final fresh = AccountStoreEpochRegistry.activate(userId);
        await fresh.ready;
        final newJournal = File(
          '${support.path}/accounts/$userId/free_sessions.jsonl',
        );
        newJournal.parent.createSync(recursive: true);
        const freshBytes = 'SYNTHETIC NEW ACCOUNT LIFETIME SENTINEL\n';
        newJournal.writeAsStringSync(freshBytes);
        readback.complete();
        await untilOwned(
          tester,
          () => !CameraReleaseLatch.isHolding,
          'old owner closed',
        );
        await tickOwned(tester);
        expect(records, isEmpty);
        expect(newJournal.readAsStringSync(), freshBytes);
        expect(fresh.isActive, isTrue);
        expect(
          File('${support.path}/free_sessions.jsonl').existsSync(),
          isFalse,
        );
      },
    );
  }

  lifecycle('completed manual summary survives inactive paused and resumed', (
    tester,
  ) async {
    final records = <SessionRecord>[];
    await running(tester, sink: (record) async => records.add(record));
    await native.emit(1);
    await untilOwned(
      tester,
      () => find.text('1 frames').evaluate().isNotEmpty,
      'measured frame',
    );
    await tester.tap(find.byKey(LiveSessionScreen.stopButtonKey));
    await untilOwned(
      tester,
      () =>
          find.byKey(LiveSessionScreen.finishedKey).evaluate().isNotEmpty &&
          !CameraReleaseLatch.isHolding,
      'completed manual summary',
    );
    final calls = native.controlCalls.length;
    final frameCalls = native.frameCalls.length;
    expect(records, hasLength(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(LiveSessionScreen.finishedKey), findsOneWidget);
    expect(find.byKey(LiveSessionScreen.finishedRepCountKey), findsOneWidget);
    expect(native.controlCalls.length, calls);
    expect(native.frameCalls.length, frameCalls);
    expect(records, hasLength(1));
  });

  lifecycle('ordinary disposal releases without recording a completed set', (
    tester,
  ) async {
    final records = <SessionRecord>[];
    await running(tester, sink: (record) async => records.add(record));
    await native.emit(1);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await untilOwned(
      tester,
      () => !CameraReleaseLatch.isHolding,
      'disposal owned close',
    );
    expect(records, isEmpty);
  });

  lifecycle('Settings grant and resumed restore explicit owned Start', (
    tester,
  ) async {
    permission.status = 4;
    await show(tester);
    await tester.tap(find.byKey(LiveSessionScreen.startButtonKey));
    await untilOwned(
      tester,
      () => find.byKey(LiveSessionScreen.openSettingsKey).evaluate().isNotEmpty,
      'permanent denial',
    );
    expect(native.controlCalls, isEmpty);
    await tester.tap(find.byKey(LiveSessionScreen.openSettingsKey));
    await untilOwned(
      tester,
      () => permission.settingsOpens == 1,
      'Settings opened',
    );
    permission.status = 1;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await untilOwned(tester, () => startEnabled(tester), 'grant refresh');
    expect(native.controlCalls, isEmpty);
    await tester.tap(find.byKey(LiveSessionScreen.startButtonKey));
    await untilOwned(
      tester,
      () => native.rawListens == 1,
      'explicit owned capture',
    );
  });

  lifecycle('same UUID fresh sign-in retires active capture before pump', (
    tester,
  ) async {
    final user = ValueNotifier<String?>('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    final owners = StreamController<void>.broadcast(sync: true);
    final records = <SessionRecord>[];
    final connection = AccountConnection(
      userId: user,
      ownerSessionChanges: owners.stream,
      pageBuilder: (_) => const SizedBox(),
    );
    await running(
      tester,
      connection: connection,
      userId: user.value,
      sink: (record) async => records.add(record),
    );
    await native.emit(1);
    await tester.pump();
    final stop = native.delayNextStop();
    owners.add(null);
    expect(CameraReleaseLatch.isHolding, isTrue);
    await untilOwned(
      tester,
      () => native.stopCalls == 1,
      'new sameUUID session retired old native owner',
    );
    stop.complete();
    await untilOwned(
      tester,
      () => !CameraReleaseLatch.isHolding,
      'old native owner drained',
    );
    expect(startEnabled(tester), isFalse);
    expect(records, isEmpty);
    await tester.pumpWidget(const SizedBox());
    user.dispose();
    await owners.close();
  });

  lifecycle('held account erasure retires active capture before pump', (
    tester,
  ) async {
    const uuid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    await AccountStoreEpochRegistry.enableManagedAdmission();
    AccountStoreEpochRegistry.activate(uuid);
    final user = ValueNotifier<String?>(uuid);
    final records = <SessionRecord>[];
    final cleanupGate = Completer<void>();
    addTearDown(() {
      if (!cleanupGate.isCompleted) cleanupGate.complete();
    });
    await running(
      tester,
      connection: AccountConnection(
        userId: user,
        pageBuilder: (_) => const SizedBox(),
      ),
      userId: uuid,
      sink: (record) async => records.add(record),
    );
    final stop = native.delayNextStop();
    final cleanup = AccountStoreEpochRegistry.beginConfirmedAccountErasure(
      uuid,
      () => cleanupGate.future,
    );
    try {
      // No UI pump or sign-out: remote success alone must fence the old camera.
      expect(CameraReleaseLatch.isHolding, isTrue);
      await untilOwned(
        tester,
        () => native.stopCalls == 1,
        'erasure retires native owner',
      );
      stop.complete();
      await untilOwned(
        tester,
        () => !CameraReleaseLatch.isHolding,
        'erasure close readback',
      );
      expect(startEnabled(tester), isFalse);
      expect(records, isEmpty);
    } finally {
      if (!cleanupGate.isCompleted) cleanupGate.complete();
      await cleanup;
      user.dispose();
    }
  });

  lifecycle(
    'confirmed A deletion after normal token refresh retires its camera before pump and preserves refreshed auth',
    (tester) async {
      final account = (await tester.runAsync(() async {
        final fixture = AccountHttpFixture();
        await fixture.session(ticketAlice, token: 'synthetic-A-token1');
        return fixture;
      }))!;
      await AccountStoreEpochRegistry.enableManagedAdmission();
      final epoch = AccountStoreEpochRegistry.activate(ticketAlice);
      final ticket = AccountActionTicket.capture(account.account)!;
      expect(identical(ticket.epoch, epoch), isTrue);
      final deleting = EpochBoundMotionAccountClient(
        original: account.account,
        ticket: ticket,
      );
      final user = ValueNotifier<String?>(ticketAlice);
      final authEvents = <String>[];
      final authSubscription = account.account.authChanges.listen((state) {
        authEvents.add(state.event.name);
        user.value = state.session?.user.id;
      });
      final connection = AccountConnection(
        userId: user,
        ownerSessionChanges: account.account.authChanges
            .where(
              (state) => const {
                'signedIn',
                'signedOut',
                'passwordRecovery',
              }.contains(state.event.name),
            )
            .map<void>((_) {}),
        pageBuilder: (_) => const SizedBox.shrink(),
      );
      final records = <SessionRecord>[];
      final response = Zone.root.run(account.delayDeletion);
      final hostIoGate = Zone.root.run(Completer<void>.new);
      final cleanupGate = Zone.root.run(Completer<void>.new);
      final receiptBoundary = Zone.root.run(Completer<void>.new);
      final confirmed = <String>[];
      var cleanupStarted = false;
      var retiredAtReceipt = false;
      var holdingAtReceipt = false;
      var ioFinished = false;
      Object? ioError;
      Object? deletionError;
      Future<void>? deletion;
      Future<void>? erasure;
      Future<void>? oldIo;
      Future<void> waitReal(Future<void> work, String stage) => work.timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw TimeoutException(stage),
      );
      try {
        await running(
          tester,
          connection: connection,
          userId: ticketAlice,
          sink: (record) async => records.add(record),
        );
        final owner = native.owner!;
        await native.emit(1);
        await tester.pump();
        expect(find.text('1 frames'), findsOneWidget);
        final lateStop = tester
            .widget<FilledButton>(find.byKey(LiveSessionScreen.stopButtonKey))
            .onPressed!;

        // Retain admitted A IO in the real async zone. Confirmed erasure must
        // retire E immediately, but wait for E's old IO before cleanup starts.
        oldIo = Zone.root.run(
          () => epoch
              .runHostIo<void>(() => hostIoGate.future)
              .then<void>(
                (_) => ioFinished = true,
                onError: (Object error, StackTrace _) {
                  ioError = error;
                  ioFinished = true;
                },
              ),
        );
        deletion = Zone.root.run(
          () => deleting.deleteCommonAccount(
            afterRemoteDelete: (id) {
              confirmed.add(id);
              erasure = AccountStoreEpochRegistry.beginConfirmedAccountErasure(
                id,
                () async {
                  cleanupStarted = true;
                  await cleanupGate.future;
                },
              );
              retiredAtReceipt = !epoch.isActive;
              holdingAtReceipt = CameraReleaseLatch.isHolding;
              // Let actual MethodChannel handlers dispatch without a UI
              // pump. This boundary precedes native close acknowledgments.
              unawaited(
                Future<void>.delayed(
                  Duration.zero,
                ).then<void>((_) => receiptBoundary.complete()),
              );
              return erasure!;
            },
          ),
        );
        Zone.root.run(() {
          unawaited(
            deletion!.then<void>(
              (_) {},
              onError: (Object error, StackTrace _) {
                deletionError = error;
              },
            ),
          );
        });
        await untilOwned(
          tester,
          () => account.deletions.length == 1,
          'captured A deletion dispatched and HTTP reply held',
        );
        expect(
          account.deletions.single.headers['Authorization'],
          'Bearer synthetic-A-token1',
        );
        expect(jsonDecode(account.deletions.single.body), {
          'confirmation': 'DELETE',
          'expectedUserId': ticketAlice,
        });

        account.refreshToken = 'synthetic-A-token2';
        await tester.runAsync(() => account.client.auth.refreshSession());
        await untilOwned(
          tester,
          () => authEvents.contains('tokenRefreshed'),
          'actual normal token refresh delivered',
        );
        expect(
          account.client.auth.currentSession?.accessToken,
          'synthetic-A-token2',
        );
        expect(
          identical(AccountStoreEpochRegistry.capture(ticketAlice), epoch),
          isTrue,
        );
        expect(epoch.isActive, isTrue);
        expect(epoch.writeLease.isActive, isTrue);
        expect(native.owner, owner);
        expect(native.stopCalls, 0);
        expect(native.rawCancels, 0);
        expect(confirmed, isEmpty);
        await native.emit(2);
        await untilOwned(
          tester,
          () => find.text('2 frames').evaluate().isNotEmpty,
          'same camera continues frames after normal token refresh',
        );
        expect(find.text('2 frames'), findsOneWidget);

        final stopReply = native.delayNextStop();
        final cancelReply = native.delayNextRawCancel();
        await tester.runAsync(() async {
          response.complete(
            accountHttpResponse({'deleted': true, 'userId': ticketAlice}),
          );
          await waitReal(receiptBoundary.future, 'confirmed receipt boundary');
        });
        // The raw stream was created in the widget fake zone. Drain its
        // cancellation microtasks without scheduling or drawing a UI frame.
        await tester.idle();
        // There has been no UI pump since the exact A server receipt. Its
        // synchronous UUID fence has already retired the camera and E.
        expect(confirmed, [ticketAlice]);
        expect(retiredAtReceipt, isTrue);
        expect(holdingAtReceipt, isTrue);
        expect(native.stopCalls, 1);
        expect(native.rawCancels, 1);
        expect(native.rawCancelReplies, 0);
        expect(find.text('2 frames'), findsOneWidget);
        expect(
          AccountStoreEpochRegistry.isAccountErasureBlocked(ticketAlice),
          isTrue,
        );
        expect(epoch.isActive, isFalse);
        expect(epoch.writeLease.isActive, isFalse);
        expect(epoch.checkCurrent, throwsStateError);
        expect(cleanupStarted, isFalse);
        expect(ioFinished, isFalse);
        expect(records, isEmpty);

        await native.emit(3, ownerId: owner);
        lateStop();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(find.text('3 frames'), findsNothing);
        expect(find.byKey(LiveSessionScreen.finishedKey), findsNothing);
        expect(startEnabled(tester), isFalse);
        expect(records, isEmpty);
        stopReply.complete();
        cancelReply.complete();
        await untilOwned(
          tester,
          () => !CameraReleaseLatch.isHolding,
          'confirmed owner Stop cancel ACK and readback drained',
        );
        expect(native.readbackCalls, 1);
        expect(cleanupStarted, isFalse);

        hostIoGate.complete();
        await tester.runAsync(() async {
          await waitReal(oldIo!, 'old admitted A IO');
          await waitReal(epoch.retireAndDrain(), 'A epoch drain');
        });
        expect(ioError, isA<StateError>());
        expect(ioFinished, isTrue);
        expect(cleanupStarted, isTrue);
        cleanupGate.complete();
        await tester.runAsync(
          () => waitReal(deletion!, 'captured A deletion completion'),
        );
        expect(deletionError, isNull);
        expect(
          AccountStoreEpochRegistry.isAccountErasurePending(ticketAlice),
          isFalse,
        );
        expect(account.client.auth.currentUser?.id, ticketAlice);
        expect(
          account.client.auth.currentSession?.accessToken,
          'synthetic-A-token2',
        );
        expect(account.logoutCalls, 0);
        expect(authEvents.where((event) => event == 'signedOut'), isEmpty);
        expect(records, isEmpty);
      } finally {
        if (!response.isCompleted) {
          response.complete(
            accountHttpResponse({'deleted': true, 'userId': ticketAlice}),
          );
        }
        if (!hostIoGate.isCompleted) hostIoGate.complete();
        if (!cleanupGate.isCompleted) cleanupGate.complete();
        native.releasePending();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          if (oldIo != null) await waitReal(oldIo, 'cleanup old A IO');
          if (deletion != null) await waitReal(deletion, 'cleanup A deletion');
          await authSubscription.cancel();
          await account.dispose();
        });
        user.dispose();
      }
    },
  );

  for (final event in ['recovery', 'identity', 'user', 'owner error']) {
    lifecycle(
      '$event signal synchronously retires active capture before shell pump without recording',
      (tester) async {
        final user = ValueNotifier<String?>(
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        );
        final recovery = ValueNotifier(false);
        final identity = ValueNotifier(true);
        final owners = StreamController<void>.broadcast(sync: true);
        final records = <SessionRecord>[];
        final connection = AccountConnection(
          userId: user,
          passwordRecovery: recovery,
          ownerSessionChanges: owners.stream,
          identityAdmissionChanges: identity,
          isIdentityAdmitted: () => identity.value,
          pageBuilder: (_) => const SizedBox.shrink(),
        );
        await running(
          tester,
          connection: connection,
          userId: user.value,
          sink: (record) async => records.add(record),
        );
        await native.emit(1);
        await tester.pump();
        final stop = native.delayNextStop();
        if (event == 'owner error') {
          owners.addError(
            StateError('synthetic auth transport'),
            StackTrace.current,
          );
        }
        if (event == 'recovery') recovery.value = true;
        if (event == 'identity') identity.value = false;
        if (event == 'user') {
          user.value = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
        }
        // No pump: the runtime boundary itself has synchronously retired lease.
        expect(CameraReleaseLatch.isHolding, isTrue);
        await untilOwned(
          tester,
          () => native.stopCalls == 1,
          'owned Stop was dispatched at signal boundary',
        );
        stop.complete();
        await untilOwned(
          tester,
          () => !CameraReleaseLatch.isHolding,
          'signal close readback',
        );
        expect(startEnabled(tester), isFalse);
        expect(records, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        user.dispose();
        recovery.dispose();
        identity.dispose();
        await owners.close();
      },
    );
  }
}

Future<void> tickOwned(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 5)),
  );
  await tester.pump();
}

Future<void> untilOwned(
  WidgetTester tester,
  bool Function() condition,
  String reason,
) async {
  await tester.pump();
  for (int turn = 0; turn < 40 && !condition(); turn++) {
    await tickOwned(tester);
  }
  expect(condition(), isTrue, reason: '$reason (40 bounded event turns)');
}
