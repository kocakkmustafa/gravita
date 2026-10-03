import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_action_ticket.dart';
import 'package:gravita/app/account_data_directory.dart';
import 'package:gravita/app/account_session_store.dart';
import 'package:gravita/app/account_store_epoch.dart';
import 'package:gravita/app/course_progress_io.dart';
import 'package:motion_core/motion_core.dart';

import 'account_action_ticket_test.dart'
    show AccountHttpFixture, accountHttpResponse, ticketAlice, ticketBob;

const _sameToken = 'synthetic-A-old';

/// Ordinary async tests: real Core/Supabase clients cross synthetic HTTP, and
/// real host epochs/queues erase only temporary A files. No widget, camera,
/// native, audio, provider or physical acceptance is exercised here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('same-token successor during remote deletion keeps its Session while strict A receipt drains E and E+1', () async {
    final witness = await _SameTokenWitness.create();
    final releaseOld = Completer<void>();
    final oldStarted = Completer<void>();
    final fenced = Completer<void>();
    final confirmed = <String>[];
    final trace = <String>[];
    Future<void>? deletion;
    Future<void>? deletionExpected;
    Future<void>? oldRejected;
    Future<void>? freshHostRejected;
    Future<void>? freshJournalRejected;
    var eraseEntered = false;
    var freshWriterRan = false;
    try {
      final original = witness.http.client.auth.currentSession!;
      final oldEpoch = AccountStoreEpochRegistry.capture(ticketAlice);
      final ticket = AccountActionTicket.capture(witness.http.account)!;
      expect(ticket.epoch, same(oldEpoch));
      final bound = witness.bound(ticket);
      final reply = witness.http.delayDeletion();
      deletion = bound.deleteCommonAccount(
        afterRemoteDelete: (id) {
          confirmed.add(id);
          final cleanup =
              AccountStoreEpochRegistry.beginConfirmedAccountErasure(
                id,
                () async {
                  eraseEntered = true;
                  trace.add('erase-A');
                  await deleteAccountData(witness.root, id);
                },
              );
          fenced.complete();
          return cleanup;
        },
      );
      // Observe immediately with a failing matcher, retain the original
      // Future, and await that original directly after releasing the gates.
      deletionExpected = expectLater(deletion, completes);
      await _until(() => witness.http.deletions.length == 1);
      witness.expectCapturedRequest();

      final oldLease = CourseProgressLease(witness.aHostFile);
      oldRejected = expectLater(
        oldLease.mutate(() async {
          oldStarted.complete();
          await releaseOld.future;
          await witness.aHostFile.writeAsString('old A writer drained');
          trace.add('old-A-write');
        }),
        throwsStateError,
      );
      await _bounded(oldStarted.future, 'old A writer admission');

      witness.http.refreshToken = _sameToken;
      final response = await witness.http.client.auth.signInWithPassword(
        email: 'synthetic@example.invalid',
        password: 'Synthetic!Password123',
      );
      await _bounded(witness.signedIn.future, 'actual fresh signedIn event');
      final replacement = witness.http.client.auth.currentSession!;
      expect(response.session, same(replacement));
      expect(replacement, isNot(same(original)));
      expect(replacement.user.id, original.user.id);
      expect(replacement.accessToken, original.accessToken);
      expect(replacement.accessToken, _sameToken);
      expect(witness.ownerRotations, 1);
      expect(witness.authEvents, contains('signedIn'));
      expect(witness.authEvents, isNot(contains('tokenRefreshed')));
      final freshEpoch = AccountStoreEpochRegistry.capture(ticketAlice);
      expect(freshEpoch, isNot(same(oldEpoch)));
      expect(oldEpoch.checkCurrent, throwsStateError);
      expect(freshEpoch.isActive, isTrue);
      expect(freshEpoch.writeLease.isActive, isTrue);

      // E+1 work is admitted but cannot enter real IO before old E drains.
      // The strict UUID receipt must retire these new handles as well.
      final freshHost = CourseProgressLease(
        File('${witness.aDirectory.path}/fresh-program.json'),
      );
      freshHostRejected = expectLater(
        freshHost.mutate(() async {
          freshWriterRan = true;
          await freshHost.file.writeAsString('must not recreate A');
        }),
        throwsStateError,
      );
      final freshJournal = AccountSessionStore(witness.aJournal);
      freshJournalRejected = expectLater(
        freshJournal.append(_record('E+1 admitted before receipt')),
        throwsStateError,
      );
      expect(freshWriterRan, isFalse);
      expect(confirmed, isEmpty);

      reply.complete(
        accountHttpResponse({'deleted': true, 'userId': ticketAlice}),
      );
      await _bounded(fenced.future, 'strict A receipt fence');
      expect(confirmed, [ticketAlice]);
      expect(oldEpoch.checkCurrent, throwsStateError);
      expect(freshEpoch.checkCurrent, throwsStateError);
      expect(freshEpoch.writeLease.isActive, isFalse);
      expect(eraseEntered, isFalse);
      expect(await witness.aDirectory.exists(), isTrue);
      expect(
        () => AccountStoreEpochRegistry.activate(ticketAlice),
        throwsStateError,
      );

      releaseOld.complete();
      await _bounded(
        Future.wait([oldRejected, freshHostRejected, freshJournalRejected]),
        'ALL-A old and successor writer drain',
      );
      await _bounded(deletion, 'original captured deletion Future');
      await _bounded(deletionExpected, 'deletion completion expectation');
      expect(trace, ['old-A-write', 'erase-A']);
      expect(freshWriterRan, isFalse);
      expect(await witness.aDirectory.exists(), isFalse);
      await expectLater(freshJournal.recent(), throwsStateError);
      await witness.expectDisjointBytes();
      expect(
        witness.http.client.auth.currentSession,
        same(replacement),
        reason: 'an equal token must not authorize sign-out of a new Session',
      );
      witness.expectReplacementAuth();
      expect(witness.http.logoutCalls, 0);
      expect(witness.authEvents, isNot(contains('signedOut')));
      expect(witness.http.deletions, hasLength(1));
    } finally {
      if (!releaseOld.isCompleted) releaseOld.complete();
      witness.http.releasePending();
      try {
        await _bounded(
          Future.wait([
            if (oldRejected != null) oldRejected,
            if (freshHostRejected != null) freshHostRejected,
            if (freshJournalRejected != null) freshJournalRejected,
            if (deletionExpected != null) deletionExpected,
            if (deletion != null) deletion,
          ]),
          'first-case original operations cleanup',
        );
      } finally {
        await witness.dispose();
      }
    }
  });

  test('same-token successor during confirmed A cleanup keeps its Session while A admission stays fenced', () async {
    final witness = await _SameTokenWitness.create();
    final releaseCleanup = Completer<void>();
    final cleanupEntered = Completer<void>();
    final confirmed = <String>[];
    Future<void>? deletion;
    Future<void>? deletionExpected;
    try {
      final original = witness.http.client.auth.currentSession!;
      final epoch = AccountStoreEpochRegistry.capture(ticketAlice);
      final ticket = AccountActionTicket.capture(witness.http.account)!;
      final retainedJournal = AccountSessionStore(witness.aJournal);
      final reply = witness.http.delayDeletion();
      deletion = witness
          .bound(ticket)
          .deleteCommonAccount(
            afterRemoteDelete: (id) {
              confirmed.add(id);
              return AccountStoreEpochRegistry.beginConfirmedAccountErasure(
                id,
                () async {
                  cleanupEntered.complete();
                  await releaseCleanup.future;
                  await deleteAccountData(witness.root, id);
                },
              );
            },
          );
      deletionExpected = expectLater(deletion, completes);
      await _until(() => witness.http.deletions.length == 1);
      witness.expectCapturedRequest();
      reply.complete(
        accountHttpResponse({'deleted': true, 'userId': ticketAlice}),
      );
      await _bounded(cleanupEntered.future, 'confirmed A cleanup entry');
      expect(confirmed, [ticketAlice]);
      expect(epoch.checkCurrent, throwsStateError);
      expect(epoch.writeLease.isActive, isFalse);
      expect(
        AccountStoreEpochRegistry.isAccountErasurePending(ticketAlice),
        isTrue,
      );
      expect(await witness.aDirectory.exists(), isTrue);

      witness.http.refreshToken = _sameToken;
      final response = await witness.http.client.auth.signInWithPassword(
        email: 'synthetic@example.invalid',
        password: 'Synthetic!Password123',
      );
      await _bounded(witness.signedIn.future, 'actual signedIn during cleanup');
      final replacement = witness.http.client.auth.currentSession!;
      expect(response.session, same(replacement));
      expect(replacement, isNot(same(original)));
      expect(replacement.user.id, original.user.id);
      expect(replacement.accessToken, original.accessToken);
      expect(replacement.accessToken, _sameToken);
      expect(witness.ownerRotations, 1);
      expect(witness.blockedSignedIn, 1);
      expect(witness.authEvents, contains('signedIn'));
      expect(witness.authEvents, isNot(contains('tokenRefreshed')));
      expect(
        () => AccountStoreEpochRegistry.activate(ticketAlice),
        throwsStateError,
        reason: 'a fresh Auth Session cannot bypass confirmed UUID erasure',
      );
      expect(AccountActionTicket.capture(witness.http.account), isNull);
      await expectLater(
        retainedJournal.append(_record('late A write during erasure')),
        throwsStateError,
      );

      releaseCleanup.complete();
      await _bounded(deletion, 'original captured deletion after cleanup');
      await _bounded(deletionExpected, 'cleanup completion expectation');
      expect(await witness.aDirectory.exists(), isFalse);
      expect(
        AccountStoreEpochRegistry.isAccountErasurePending(ticketAlice),
        isFalse,
      );
      expect(
        AccountStoreEpochRegistry.isAccountErasureBlocked(ticketAlice),
        isTrue,
      );
      await witness.expectDisjointBytes();
      expect(
        witness.http.client.auth.currentSession,
        same(replacement),
        reason: 'cleanup completion belongs to the old Session object',
      );
      witness.expectReplacementAuth();
      expect(witness.http.logoutCalls, 0);
      expect(witness.authEvents, isNot(contains('signedOut')));
      expect(witness.http.deletions, hasLength(1));
    } finally {
      if (!releaseCleanup.isCompleted) releaseCleanup.complete();
      witness.http.releasePending();
      try {
        await _bounded(
          Future.wait([
            if (deletionExpected != null) deletionExpected,
            if (deletion != null) deletion,
          ]),
          'second-case original deletion cleanup',
        );
      } finally {
        await witness.dispose();
      }
    }
  });
}

SessionRecord _record(String lessonId) => SessionRecord(
  lessonId: lessonId,
  completedAt: DateTime.utc(2026, 10, 2),
  workedSeconds: 10,
  unitsCompleted: 1,
  plannedUnits: 1,
  unitLabel: 'rep',
  lessonClass: 'measurementOnly',
);

Future<T> _bounded<T>(Future<T> future, String stage) => future.timeout(
  const Duration(seconds: 5),
  onTimeout: () => throw TimeoutException(stage),
);

Future<void> _until(bool Function() predicate) async {
  final clock = Stopwatch()..start();
  while (!predicate()) {
    if (clock.elapsed >= const Duration(seconds: 5)) {
      throw TimeoutException('synthetic deletion request dispatch');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

final class _SameTokenWitness {
  _SameTokenWitness(this.root, this.http);

  final Directory root;
  final AccountHttpFixture http;
  StreamSubscription<dynamic>? _auth;
  final ownerDrains = <Future<void>>[];
  final authEvents = <String>[];
  Completer<void> signedIn = Completer<void>();
  int ownerRotations = 0;
  int blockedSignedIn = 0;
  late final List<int> _bBytes;
  late final List<int> _guestBytes;

  Directory get aDirectory => accountDataDirectory(root, ticketAlice);
  File get aJournal => File('${aDirectory.path}/free_sessions.jsonl');
  File get aHostFile => File('${aDirectory.path}/program.json');
  File get bFile =>
      File('${accountDataDirectory(root, ticketBob).path}/free_sessions.jsonl');
  File get guestFile => File('${root.path}/free_sessions.jsonl');

  static Future<_SameTokenWitness> create() async {
    await _bounded(AccountStoreEpochRegistry.resetForTest(), 'initial reset');
    final root = await Directory.systemTemp.createTemp(
      'gravita-same-token-successor-SYNTHETIC-',
    );
    final witness = _SameTokenWitness(root, AccountHttpFixture());
    try {
      await witness.bFile.parent.create(recursive: true);
      await witness.bFile.writeAsString('SYNTHETIC B BYTES PRESERVED\n');
      await witness.guestFile.writeAsString(
        'SYNTHETIC GUEST BYTES PRESERVED\n',
      );
      witness._bBytes = await witness.bFile.readAsBytes();
      witness._guestBytes = await witness.guestFile.readAsBytes();
      await AccountStoreEpochRegistry.enableManagedAdmission();
      await _bounded(
        AccountStoreEpochRegistry.activate(ticketAlice).ready,
        'initial A admission',
      );
      await AccountSessionStore(witness.aJournal).append(_record('A existing'));
      await witness.aHostFile.writeAsString('A existing host bytes');
      await witness.http.session(ticketAlice, token: _sameToken);
      // Bounded host owner-event seam matches bootstrap: only signedIn,
      // signedOut and recovery rotate resources; tokenRefreshed never does.
      witness._auth = witness.http.account.authChanges.listen((state) {
        final event = state.event.name;
        witness.authEvents.add(event);
        if (!const {
          'signedIn',
          'signedOut',
          'passwordRecovery',
        }.contains(event)) {
          return;
        }
        witness.ownerRotations++;
        witness.ownerDrains.add(AccountStoreEpochRegistry.retireAll());
        final userId = state.session?.user.id;
        if (AccountStoreEpochRegistry.isAccountErasureBlocked(userId)) {
          if (event == 'signedIn') witness.blockedSignedIn++;
        } else {
          AccountStoreEpochRegistry.activate(userId);
        }
        if (event == 'signedIn' && !witness.signedIn.isCompleted) {
          witness.signedIn.complete();
        }
      });
      await Future<void>.delayed(Duration.zero);
      witness.authEvents.clear();
      witness.ownerRotations = 0;
      witness.blockedSignedIn = 0;
      witness.signedIn = Completer<void>();
      return witness;
    } catch (_) {
      await witness._auth?.cancel();
      await witness.http.dispose();
      await AccountStoreEpochRegistry.resetForTest();
      await root.delete(recursive: true);
      rethrow;
    }
  }

  EpochBoundMotionAccountClient bound(AccountActionTicket ticket) =>
      EpochBoundMotionAccountClient(original: http.account, ticket: ticket);

  void expectCapturedRequest() {
    expect(
      http.deletions.single.headers['Authorization'],
      'Bearer $_sameToken',
    );
    expect(jsonDecode(http.deletions.single.body), {
      'confirmation': 'DELETE',
      'expectedUserId': ticketAlice,
    });
  }

  void expectReplacementAuth() {
    expect(http.client.auth.currentUser?.id, ticketAlice);
    expect(http.client.auth.currentSession?.accessToken, _sameToken);
  }

  Future<void> expectDisjointBytes() async {
    expect(await bFile.readAsBytes(), orderedEquals(_bBytes));
    expect(await guestFile.readAsBytes(), orderedEquals(_guestBytes));
  }

  Future<void> dispose() async {
    await _auth?.cancel();
    try {
      await http.dispose();
      await _bounded(Future.wait(ownerDrains), 'owner-event retirement drains');
    } finally {
      try {
        await _bounded(AccountStoreEpochRegistry.resetForTest(), 'final reset');
      } finally {
        await root.delete(recursive: true);
      }
    }
  }
}
