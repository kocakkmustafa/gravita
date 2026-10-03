import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_connection.dart';
import 'package:gravita/app/account_store_epoch.dart';
import 'package:gravita/app/gravita_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const first = '11111111-1111-4111-8111-111111111111';

  setUp(() async {
    await AccountStoreEpochRegistry.resetForTest();
    await AccountStoreEpochRegistry.enableManagedAdmission();
  });
  tearDown(AccountStoreEpochRegistry.resetForTest);

  testWidgets(
    'same UUID recovery retires admission and replaces active route',
    (tester) async {
      final user = ValueNotifier<String?>(first);
      final recovery = ValueNotifier<bool>(false);
      addTearDown(user.dispose);
      addTearDown(recovery.dispose);
      await tester.pumpWidget(
        GravitaApp(
          accountConnection: AccountConnection(
            userId: user,
            passwordRecovery: recovery,
            pageBuilder: (_) =>
                Scaffold(body: Text('RECOVERY_${recovery.value}')),
          ),
        ),
      );
      final oldEpoch = AccountStoreEpochRegistry.capture(first);
      final initialKey = tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .key;
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('OLD_ACTIVE_ROUTE')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('OLD_ACTIVE_ROUTE'), findsOneWidget);

      recovery.value = true;
      // Same UUID, before pump: retained account admission is already closed.
      expect(user.value, first);
      expect(oldEpoch.checkCurrent, throwsStateError);
      expect(oldEpoch.writeLease.isActive, isFalse);
      expect(() => AccountStoreEpochRegistry.capture(first), throwsStateError);
      await tester.pump();
      expect(find.text('OLD_ACTIVE_ROUTE'), findsNothing);
      expect(find.byType(GravitaRoot), findsNothing);
      expect(find.text('RECOVERY_true'), findsOneWidget);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).key,
        isNot(initialKey),
      );

      recovery.value = false;
      final freshEpoch = AccountStoreEpochRegistry.capture(first);
      expect(identical(oldEpoch, freshEpoch), isFalse);
      await tester.pump();
      expect(find.text('RECOVERY_true'), findsNothing);
      expect(find.byType(GravitaRoot), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(() => AccountStoreEpochRegistry.capture(first), throwsStateError);
    },
  );

  testWidgets('same UUID fresh sign-in retires the old epoch before pump', (
    tester,
  ) async {
    final user = ValueNotifier<String?>(first);
    final recovery = ValueNotifier<bool>(false);
    final owners = StreamController<void>.broadcast(sync: true);
    addTearDown(user.dispose);
    addTearDown(recovery.dispose);
    addTearDown(owners.close);
    await tester.pumpWidget(
      GravitaApp(
        accountConnection: AccountConnection(
          userId: user,
          passwordRecovery: recovery,
          ownerSessionChanges: owners.stream,
          pageBuilder: (_) => const SizedBox(),
        ),
      ),
    );
    final old = AccountStoreEpochRegistry.capture(first);
    final oldKey = tester.widget<MaterialApp>(find.byType(MaterialApp)).key;
    owners.add(null);
    expect(old.checkCurrent, throwsStateError);
    expect(identical(old, AccountStoreEpochRegistry.capture(first)), isFalse);
    await tester.pump();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).key,
      isNot(oldKey),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'held account erasure closes shell and fresh same UUID admission',
    (tester) async {
      final user = ValueNotifier<String?>(first);
      final recovery = ValueNotifier<bool>(false);
      final gate = Completer<void>();
      addTearDown(user.dispose);
      addTearDown(recovery.dispose);
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      await tester.pumpWidget(
        GravitaApp(
          accountConnection: AccountConnection(
            userId: user,
            passwordRecovery: recovery,
            pageBuilder: (_) => const Scaffold(body: Text('ACCOUNT_OPTIONS')),
          ),
        ),
      );
      final old = AccountStoreEpochRegistry.capture(first);
      final cleanup = AccountStoreEpochRegistry.beginConfirmedAccountErasure(
        first,
        () => gate.future,
      );
      expect(old.checkCurrent, throwsStateError);
      expect(() => AccountStoreEpochRegistry.capture(first), throwsStateError);
      await tester.pump();
      expect(find.byType(GravitaRoot), findsNothing);
      expect(find.textContaining('local cleanup completes'), findsOneWidget);
      recovery.value = true;
      recovery.value = false;
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(GravitaRoot), findsNothing);
      gate.complete();
      await cleanup;
      await tester.pump();
      expect(find.textContaining('local cleanup completes'), findsNothing);
      expect(find.textContaining('This account was deleted'), findsOneWidget);
      expect(find.byType(GravitaRoot), findsNothing);
      await tester.tap(find.text('Account options'));
      await tester.pumpAndSettle();
      expect(find.text('ACCOUNT_OPTIONS'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'guest owner error replaces IO while canonical guest stays admitted',
    (tester) async {
      final user = ValueNotifier<String?>(null);
      final recovery = ValueNotifier<bool>(false);
      final owners = StreamController<void>.broadcast(sync: true);
      addTearDown(user.dispose);
      addTearDown(recovery.dispose);
      addTearDown(owners.close);
      await tester.pumpWidget(
        GravitaApp(
          accountConnection: AccountConnection(
            userId: user,
            passwordRecovery: recovery,
            ownerSessionChanges: owners.stream,
            isIdentityAdmitted: () => true,
            pageBuilder: (_) => const SizedBox(),
          ),
        ),
      );
      final old = AccountStoreEpochRegistry.capture(null);
      final oldKey = tester.widget<MaterialApp>(find.byType(MaterialApp)).key;
      // Core keeps signedOut when its auth client has no current user.
      owners.addError(
        StateError('synthetic guest auth transport'),
        StackTrace.current,
      );
      expect(old.checkCurrent, throwsStateError);
      final fresh = AccountStoreEpochRegistry.capture(null);
      expect(identical(old, fresh), isFalse);
      expect(fresh.isActive, isTrue);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(GravitaRoot), findsOneWidget);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).key,
        isNot(oldKey),
      );
      await tester.runAsync(() => fresh.ready);
      fresh.checkCurrent();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('owner stream error retires IO while Core closes identity', (
    tester,
  ) async {
    final user = ValueNotifier<String?>(first);
    final recovery = ValueNotifier<bool>(false);
    final admitted = ValueNotifier<bool>(true);
    final owners = StreamController<void>.broadcast(sync: true);
    addTearDown(user.dispose);
    addTearDown(recovery.dispose);
    addTearDown(admitted.dispose);
    addTearDown(owners.close);
    await tester.pumpWidget(
      GravitaApp(
        accountConnection: AccountConnection(
          userId: user,
          passwordRecovery: recovery,
          ownerSessionChanges: owners.stream,
          identityAdmissionChanges: admitted,
          isIdentityAdmitted: () => admitted.value,
          pageBuilder: (_) => const SizedBox(),
        ),
      ),
    );
    final old = AccountStoreEpochRegistry.capture(first);
    // Real Core runtime closes its canonical phase before later observers.
    admitted.value = false;
    owners.addError(StateError('synthetic auth transport'), StackTrace.current);
    expect(old.checkCurrent, throwsStateError);
    expect(() => AccountStoreEpochRegistry.capture(first), throwsStateError);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(GravitaRoot), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('closed identity cannot reopen history when recovery clears', (
    tester,
  ) async {
    final user = ValueNotifier<String?>(first);
    final recovery = ValueNotifier<bool>(true);
    final admitted = ValueNotifier<bool>(true);
    addTearDown(user.dispose);
    addTearDown(recovery.dispose);
    addTearDown(admitted.dispose);
    await tester.pumpWidget(
      GravitaApp(
        accountConnection: AccountConnection(
          userId: user,
          passwordRecovery: recovery,
          identityAdmissionChanges: admitted,
          isIdentityAdmitted: () => admitted.value,
          pageBuilder: (_) => const Scaffold(body: Text('RECOVERY_VIEW')),
        ),
      ),
    );
    expect(find.text('RECOVERY_VIEW'), findsOneWidget);
    admitted.value = false;
    recovery.value = false;
    expect(() => AccountStoreEpochRegistry.capture(first), throwsStateError);
    await tester.pump();
    expect(find.byType(GravitaRoot), findsNothing);
    expect(find.text('RECOVERY_VIEW'), findsNothing);
    admitted.value = true;
    expect(AccountStoreEpochRegistry.capture(first), isNotNull);
    await tester.pump();
    expect(find.byType(GravitaRoot), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
