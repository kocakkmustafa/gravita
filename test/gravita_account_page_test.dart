import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_action_ticket.dart';
import 'package:gravita/app/account_data_directory.dart';
import 'package:gravita/app/account_store_epoch.dart';
import 'package:gravita/app/gravita_account_page.dart';
import 'package:motion_account/motion_account.dart';

import 'account_action_ticket_test.dart'
    show AccountHttpFixture, accountHttpResponse, ticketAlice, ticketBob;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AccountHttpFixture fixture;
  late Directory support;
  setUp(() async {
    await AccountStoreEpochRegistry.resetForTest();
    await AccountStoreEpochRegistry.enableManagedAdmission();
    AccountStoreEpochRegistry.activate(ticketAlice);
    fixture = AccountHttpFixture();
    support = Directory.systemTemp.createTempSync('gravita-account-SYNTHETIC-');
    await fixture.session(ticketAlice);
  });
  tearDown(() async {
    await fixture.dispose();
    await AccountStoreEpochRegistry.resetForTest();
    support.deleteSync(recursive: true);
  });

  Future<void> show(
    WidgetTester tester, {
    Future<void> Function(String)? clear,
    ValueNotifier<bool>? recovery,
    ValueNotifier<bool>? admission,
    Future<void> Function()? retry,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: GravitaAccountPage(
          client: fixture.account,
          clearLocalData: clear ?? (_) async {},
          passwordRecovery: recovery,
          identityAdmissionChanges: admission,
          isIdentityAdmitted: admission == null ? null : () => admission.value,
          onRetryIdentity: retry,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> dialog(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Delete Motion account'));
    await tester.tap(find.text('Delete Motion account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Delete account'), findsOneWidget);
  }

  testWidgets(
    'held deletion dialog rejects same UUID replacement token before RPC',
    (tester) async {
      final cleaned = <String>[];
      try {
        await show(tester, clear: (id) async => cleaned.add(id));
        await dialog(tester);
        await tester.runAsync(
          () => fixture.session(ticketAlice, token: 'synthetic-A-new'),
        );
        await tester.pump();
        await tester.tap(find.text('Delete account'));
        await _finishDialog(tester);
        await _turn(tester);
        expect(
          fixture.deletions,
          isEmpty,
          reason: 'dialog pinned the previous token before it was shown',
        );
        expect(cleaned, isEmpty);
        expect(
          fixture.client.auth.currentSession?.accessToken,
          'synthetic-A-new',
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.releasePending();
        await _turn(tester);
        expect(tester.takeException(), isNull);
      }
    },
  );

  for (final replacementId in [ticketBob, ticketAlice]) {
    for (final holdCleanup in [false, true]) {
      testWidgets(
        'confirmed A cleanup keeps captured UUID and replacement ${replacementId == ticketAlice ? 'same UUID' : 'B'} session while ${holdCleanup ? 'cleanup' : 'remote response'} is held',
        (tester) async {
          final response = fixture.delayDeletion();
          final cleanup = Completer<void>();
          final oldCleaned = <String>[];
          final newCleaned = <String>[];
          final aFile = File(
            '${accountDataDirectory(support, ticketAlice).path}/free_sessions.jsonl',
          );
          final bFile = File(
            '${accountDataDirectory(support, ticketBob).path}/free_sessions.jsonl',
          );
          final guestFile = File('${support.path}/free_sessions.jsonl');
          for (final file in [aFile, bFile, guestFile]) {
            file.parent.createSync(recursive: true);
            file.writeAsStringSync('SYNTHETIC PRESERVED ${file.path}\n');
          }
          final bBytes = bFile.readAsBytesSync();
          final guestBytes = guestFile.readAsBytesSync();
          var eraseEntered = false;
          Future<void>? retainedErasure;
          try {
            await show(
              tester,
              clear: (id) async {
                oldCleaned.add(id);
                // Actual filesystem IO must originate outside widget fake
                // async, so awaiting this exact retained Future can drain it.
                final erasure = Zone.root.run(
                  () => AccountStoreEpochRegistry.beginConfirmedAccountErasure(
                    id,
                    () async {
                      eraseEntered = true;
                      await cleanup.future;
                      await deleteAccountData(support, id);
                    },
                  ),
                );
                retainedErasure = erasure;
                await erasure;
              },
            );
            await dialog(tester);
            await tester.tap(find.text('Delete account'));
            await _finishDialog(tester);
            await _until(
              tester,
              () => fixture.deletions.length == 1,
              'A request admitted',
            );
            expect(
              fixture.deletions.single.headers['Authorization'],
              'Bearer synthetic-A-old',
            );
            if (holdCleanup) {
              response.complete(
                accountHttpResponse({'deleted': true, 'userId': ticketAlice}),
              );
              await _until(
                tester,
                () => eraseEntered,
                'captured A cleanup entered',
              );
            }
            await tester.runAsync(
              () => fixture.session(
                replacementId,
                token: 'synthetic-replacement',
              ),
            );
            if (holdCleanup && replacementId == ticketAlice) {
              expect(
                () => AccountStoreEpochRegistry.activate(ticketAlice),
                throwsStateError,
              );
            } else {
              AccountStoreEpochRegistry.activate(replacementId);
            }
            await show(tester, clear: (id) async => newCleaned.add(id));
            if (!holdCleanup) {
              response.complete(
                accountHttpResponse({'deleted': true, 'userId': ticketAlice}),
              );
              await _until(
                tester,
                () => eraseEntered,
                'captured A cleanup after replacement',
              );
            }
            expect(oldCleaned, [ticketAlice]);
            expect(newCleaned, isEmpty);
            expect(
              AccountStoreEpochRegistry.isAccountErasureBlocked(ticketAlice),
              isTrue,
            );
            expect(
              () => AccountStoreEpochRegistry.capture(ticketAlice),
              throwsStateError,
            );
            expect(
              () => AccountStoreEpochRegistry.activate(ticketAlice),
              throwsStateError,
            );
            expect(aFile.existsSync(), isTrue);
            cleanup.complete();
            await tester.runAsync(
              () => retainedErasure!.timeout(const Duration(seconds: 3)),
            );
            await _turn(tester);
            expect(
              accountDataDirectory(support, ticketAlice).existsSync(),
              isFalse,
            );
            expect(bFile.readAsBytesSync(), bBytes);
            expect(guestFile.readAsBytesSync(), guestBytes);
            if (replacementId == ticketBob) {
              expect(
                AccountStoreEpochRegistry.capture(ticketBob).isActive,
                isTrue,
              );
            }
            expect(fixture.client.auth.currentUser?.id, replacementId);
            expect(
              fixture.client.auth.currentSession?.accessToken,
              'synthetic-replacement',
            );
            expect(fixture.logoutCalls, 0);
            expect(fixture.deletions, hasLength(1));
          } finally {
            if (!response.isCompleted) {
              response.complete(
                accountHttpResponse({'deleted': true, 'userId': ticketAlice}),
              );
            }
            if (!cleanup.isCompleted) cleanup.complete();
            await tester.pumpWidget(const SizedBox.shrink());
            await _turn(tester);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }

  testWidgets(
    'normal tokenRefreshed renews only account page ticket and preserves storage epoch',
    (tester) async {
      try {
        await show(tester);
        final before = tester.widget<MotionAccountPage>(
          find.byType(MotionAccountPage),
        );
        final epoch =
            (before.account as EpochBoundMotionAccountClient).ticket!.epoch;
        await tester.runAsync(() => fixture.client.auth.refreshSession());
        await _until(
          tester,
          () =>
              tester
                  .widget<MotionAccountPage>(find.byType(MotionAccountPage))
                  .key !=
              before.key,
          'refreshed page key',
        );
        final after = tester.widget<MotionAccountPage>(
          find.byType(MotionAccountPage),
        );
        final ticket = (after.account as EpochBoundMotionAccountClient).ticket!;
        expect(identical(ticket.epoch, epoch), isTrue);
        expect(epoch.isActive, isTrue);
        expect(
          identical(AccountStoreEpochRegistry.capture(ticketAlice), epoch),
          isTrue,
        );
        expect(
          fixture.client.auth.currentSession?.accessToken,
          'synthetic-A-refreshed',
        );
        expect(fixture.deletions, isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _turn(tester);
        await _drainMembershipRead(tester);
      }
    },
  );

  testWidgets(
    'fresh wrapper ticket can confirm strict UUID deletion and captured cleanup',
    (tester) async {
      final cleaned = <String>[];
      try {
        await show(tester, clear: (id) async => cleaned.add(id));
        await dialog(tester);
        await tester.tap(find.text('Delete account'));
        await _finishDialog(tester);
        await _until(
          tester,
          () => cleaned.length == 1 && fixture.client.auth.currentUser == null,
          'strict deletion completed',
        );
        expect(cleaned, [ticketAlice]);
        expect(fixture.deletions, hasLength(1));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _turn(tester);
      }
    },
  );

  testWidgets(
    'held dialog with retired epoch never dispatches into a fresh same-token owner',
    (tester) async {
      try {
        await show(tester);
        await dialog(tester);
        final old =
            tester
                    .widget<MotionAccountPage>(find.byType(MotionAccountPage))
                    .account
                as EpochBoundMotionAccountClient;
        await AccountStoreEpochRegistry.retireAll();
        AccountStoreEpochRegistry.activate(ticketAlice);
        expect(old.ticket!.epoch.isActive, isFalse);
        await tester.pump();
        await tester.tap(find.text('Delete account'));
        await _finishDialog(tester);
        await _turn(tester);
        expect(fixture.deletions, isEmpty);
        expect(
          fixture.client.auth.currentSession?.accessToken,
          'synthetic-A-old',
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _turn(tester);
      }
    },
  );

  testWidgets(
    'canonical recovery listenable shows password UI and closes deletion admission',
    (tester) async {
      final recovery = ValueNotifier(true);
      final admission = ValueNotifier(true);
      var retries = 0;
      try {
        await show(
          tester,
          recovery: recovery,
          admission: admission,
          retry: () async => retries++,
        );
        expect(find.text('Save password'), findsOneWidget);
        expect(find.text('Delete Motion account'), findsNothing);
        final recovering = tester.widget<MotionAccountPage>(
          find.byType(MotionAccountPage),
        );
        expect(
          (recovering.account as EpochBoundMotionAccountClient).ticket,
          isNull,
        );
        recovery.value = false;
        await tester.pump();
        expect(find.text('Save password'), findsNothing);
        expect(find.text('Delete Motion account'), findsOneWidget);
        // Sales are on (production default), so Core labels the retry
        // "Refresh account and membership".
        await tester.ensureVisible(find.text('Refresh account and membership'));
        await tester.tap(find.text('Refresh account and membership'));
        await _until(tester, () => retries == 1, 'forwarded identity retry');
        admission.value = false;
        await tester.pump();
        final closed = tester.widget<MotionAccountPage>(
          find.byType(MotionAccountPage),
        );
        expect(
          (closed.account as EpochBoundMotionAccountClient).ticket,
          isNull,
        );
        await dialog(tester);
        await tester.tap(find.text('Delete account'));
        await _finishDialog(tester);
        await _turn(tester);
        expect(fixture.deletions, isEmpty);
        expect(find.text('Sign out'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        recovery.dispose();
        admission.dispose();
        await _turn(tester);
        await _drainMembershipRead(tester);
        expect(tester.takeException(), isNull);
      }
    },
  );
}

Future<void> _turn(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 5)),
  );
  await tester.pump();
}

/// Remounting the page (token refresh, recovery) starts a new membership read
/// with sales on; the client's 10 s read deadline outlives the fake-async test.
/// Core R1: a late timeout of a disposed page is swallowed, so pass it.
Future<void> _drainMembershipRead(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 11));

Future<void> _finishDialog(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
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
