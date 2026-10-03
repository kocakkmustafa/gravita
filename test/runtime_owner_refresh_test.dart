import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_store_epoch.dart';
import 'package:gravita/app/gravita_app.dart';
import 'package:gravita/app/motion_account_bootstrap.dart';
import 'package:motion_account/motion_account.dart';

import 'account_action_ticket_test.dart' show AccountHttpFixture, ticketAlice;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('production binding retains admitted owner during held ordinary refresh but retires new same UUID sign-in', (tester) async {
    Future<T?> real<T>(String stage, Future<T> Function() operation) =>
        tester.runAsync(() async {
          print('runtime-owner stage: $stage');
          return operation().timeout(const Duration(seconds: 5));
        });
    await real('registry startup', () async {
      await AccountStoreEpochRegistry.resetForTest();
      await AccountStoreEpochRegistry.enableManagedAdmission();
    });
    late AccountHttpFixture fixture;
    late MotionAccountRuntime runtime;
    late Completer<void> hold;
    Future<Object?>? refreshOutcome;
    try {
      await real('initial identity', () async {
        // Create SDK and subscription in the real async zone, where its queued
        // auth callbacks can run while a real HTTP proof response is held.
        hold = Completer<void>();
        fixture = AccountHttpFixture();
        runtime = MotionAccountRuntime.forTesting(
          client: fixture.client,
          app: MotionApp.gravita,
          onDeletedAccount: (_) async {},
        );
        await fixture.session(ticketAlice);
        await runtime.refreshIdentity();
        await Future<void>.delayed(Duration.zero);
      });
      expect(runtime.isCurrentSessionVerified, isTrue);
      final connection = bindGravitaMotionAccount(runtime, clearLocalData: (_) async {});
      await tester.pumpWidget(GravitaApp(accountConnection: connection));
      await tester.pump();
      final epoch = AccountStoreEpochRegistry.capture(ticketAlice);
      final key = tester.widget<MaterialApp>(find.byType(MaterialApp)).key;
      await real('held token refresh', () async {
        fixture.userReadHold = hold;
        fixture.userReadStarted = Completer<void>();
        // Actual GoTrue refresh replaces the SDK Session. Then drive the real
        // public Core verifier explicitly; no private proof/phase is changed.
        await fixture.client.auth.refreshSession();
        refreshOutcome = runtime.refreshIdentity().then<Object?>(
          (_) => null, onError: (Object error, StackTrace _) => error);
        await fixture.userReadStarted!.future.timeout(const Duration(seconds: 2),
          onTimeout: () => throw StateError('No held identity HTTP read: '
            '${fixture.requests.map((r) => '${r.method} ${r.url.path}').toList()}, '
            'phase=${runtime.phase.value}, proof=${runtime.isCurrentSessionVerified}'));
      });
      expect(runtime.isCurrentSessionVerified, isFalse);
      expect(connection.isCurrentIdentityVerified!(), isFalse);
      expect(connection.isIdentityAdmitted!(), isTrue);
      expect(epoch.checkCurrent, returnsNormally);
      expect(AccountStoreEpochRegistry.capture(ticketAlice), same(epoch));
      await tester.pump();
      expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).key, key);
      hold.complete();
      fixture.userReadHold = null;
      await real('refresh proof release', () async {
        expect(await refreshOutcome, isNull);
        await runtime.refreshIdentity();
      });
      await tester.pump();
      expect(runtime.isCurrentSessionVerified, isTrue);
      expect(AccountStoreEpochRegistry.capture(ticketAlice), same(epoch));
      await real('same UUID sign-in', () async {
        await runtime.account.signIn(email: 'synthetic@example.invalid', password: 'Synthetic!123');
        await runtime.refreshIdentity();
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      expect(epoch.checkCurrent, throwsStateError);
      expect(AccountStoreEpochRegistry.capture(ticketAlice), isNot(same(epoch)));
    } finally {
      if (!hold.isCompleted) hold.complete();
      await tester.pumpWidget(const SizedBox());
      await real('teardown', () async {
        runtime.dispose();
        if (refreshOutcome != null) await refreshOutcome;
        await fixture.dispose();
        await AccountStoreEpochRegistry.resetForTest();
      });
    }
  });
}
