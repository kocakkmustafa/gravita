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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'token refresh during admitted deletion preserves Auth but fences and drains the same A epoch',
    (tester) async {
      // Every real filesystem operation, Auth callback and drain originates
      // outside widget fake async. There is no provider/native request here.
      await tester.runAsync(() async {
        final witness = await _ErasureWitness.create();
        final releaseJournal = Completer<void>();
        final releaseHost = Completer<void>();
        final hostStarted = Completer<void>();
        final fenced = Completer<void>();
        final trace = <String>[];
        final cleanedIds = <String>[];
        Future<void>? journalRejected;
        Future<void>? hostRejected;
        Future<void>? deletionCompleted;
        var eraseEntered = false;
        var deletionDone = false;
        try {
          final epoch = AccountStoreEpochRegistry.capture(ticketAlice);
          final ticket = AccountActionTicket.capture(witness.http.account)!;
          expect(ticket.epoch, same(epoch));
          final bound = witness.bound(ticket);
          final reply = witness.http.delayDeletion();
          final deletion = bound.deleteCommonAccount(
            afterRemoteDelete: (confirmedId) {
              cleanedIds.add(confirmedId);
              final cleanup =
                  AccountStoreEpochRegistry.beginConfirmedAccountErasure(
                    confirmedId,
                    () async {
                      eraseEntered = true;
                      trace.add('erase');
                      await deleteAccountData(witness.root, confirmedId);
                    },
                  );
              fenced.complete();
              return cleanup;
            },
          );
          deletionCompleted = expectLater(
            deletion.then((_) => deletionDone = true),
            completes,
          );
          await _until(() => witness.http.deletions.length == 1);
          witness.expectPinnedRequest();

          final gatedJournal = _GatedExistsFile(
            witness.aJournal,
            releaseJournal.future,
          );
          final retainedJournal = AccountSessionStore(gatedJournal);
          journalRejected = expectLater(
            retainedJournal.append(_record('admitted-before-receipt')),
            throwsA(
              anyOf(isA<StateError>(), isA<SessionStoreRetiredException>()),
            ),
          );
          await gatedJournal.started.future;
          final hostLease = CourseProgressLease(witness.aHostFile);
          hostRejected = expectLater(
            hostLease.mutate(() async {
              hostStarted.complete();
              await releaseHost.future;
              await witness.aHostFile.writeAsString('admitted A host write');
              trace.add('host-write');
            }),
            throwsStateError,
          );
          await hostStarted.future;

          await witness.http.client.auth.refreshSession();
          await _until(() => witness.authEvents.contains('tokenRefreshed'));
          expect(witness.ownerRotations, 0);
          expect(AccountStoreEpochRegistry.capture(ticketAlice), same(epoch));
          expect(epoch.isActive, isTrue);
          expect(epoch.writeLease.isActive, isTrue);
          witness.expectAuth('synthetic-A-refreshed');

          reply.complete(
            accountHttpResponse({'deleted': true, 'userId': ticketAlice}),
          );
          await fenced.future;
          expect(cleanedIds, [ticketAlice]);
          expect(epoch.checkCurrent, throwsStateError);
          expect(epoch.writeLease.isActive, isFalse);
          expect(
            AccountStoreEpochRegistry.isAccountErasurePending(ticketAlice),
            isTrue,
          );
          expect(
            () => AccountStoreEpochRegistry.activate(ticketAlice),
            throwsStateError,
          );
          expect(AccountActionTicket.capture(witness.http.account), isNull);
          expect(
            eraseEntered,
            isFalse,
            reason: 'both admitted journal and host IO still hold A drain',
          );
          expect(deletionDone, isFalse);
          expect(await witness.aDirectory.exists(), isTrue);

          releaseJournal.complete();
          await journalRejected;
          expect(
            eraseEntered,
            isFalse,
            reason: 'journal completion cannot overtake the host writer',
          );
          expect(await witness.aDirectory.exists(), isTrue);
          releaseHost.complete();
          await hostRejected;
          await deletionCompleted;

          expect(trace, ['host-write', 'erase']);
          expect(await witness.aDirectory.exists(), isFalse);
          await expectLater(
            retainedJournal.append(_record('late-after-erasure')),
            throwsStateError,
          );
          expect(
            () => AccountStoreEpochRegistry.capture(ticketAlice),
            throwsStateError,
          );
          await witness.expectDisjointFilesPreserved();
          witness.expectAuth('synthetic-A-refreshed');
          expect(witness.http.logoutCalls, 0);
          expect(witness.http.deletions, hasLength(1));
          expect(witness.authEvents, isNot(contains('signedOut')));
        } finally {
          if (!releaseJournal.isCompleted) releaseJournal.complete();
          if (!releaseHost.isCompleted) releaseHost.complete();
          witness.http.releasePending();
          try {
            await Future.wait([
              if (journalRejected != null) journalRejected,
              if (hostRejected != null) hostRejected,
              if (deletionCompleted != null) deletionCompleted,
            ]);
          } finally {
            await witness.dispose();
          }
        }
      });
    },
  );

  testWidgets(
    'fresh same UUID session rejects stale initiation while confirmed A deletion drains both epochs and preserves replacement Auth',
    (tester) async {
      await tester.runAsync(() async {
        final witness = await _ErasureWitness.create();
        final releaseOld = Completer<void>();
        final oldStarted = Completer<void>();
        final fenced = Completer<void>();
        final trace = <String>[];
        Future<void>? oldRejected;
        Future<void>? freshHostRejected;
        Future<void>? freshJournalRejected;
        Future<void>? deletionCompleted;
        var freshWriterRan = false;
        var eraseEntered = false;
        try {
          final oldEpoch = AccountStoreEpochRegistry.capture(ticketAlice);
          final oldTicket = AccountActionTicket.capture(witness.http.account)!;
          final oldBound = witness.bound(oldTicket);
          final reply = witness.http.delayDeletion();
          final deletion = oldBound.deleteCommonAccount(
            afterRemoteDelete: (confirmedId) {
              expect(confirmedId, ticketAlice);
              final cleanup =
                  AccountStoreEpochRegistry.beginConfirmedAccountErasure(
                    confirmedId,
                    () async {
                      eraseEntered = true;
                      trace.add('erase');
                      await deleteAccountData(witness.root, confirmedId);
                    },
                  );
              fenced.complete();
              return cleanup;
            },
          );
          deletionCompleted = expectLater(deletion, completes);
          await _until(() => witness.http.deletions.length == 1);
          witness.expectPinnedRequest();
          final oldLease = CourseProgressLease(witness.aHostFile);
          oldRejected = expectLater(
            oldLease.mutate(() async {
              oldStarted.complete();
              await releaseOld.future;
              await witness.aHostFile.writeAsString('old A write drained');
              trace.add('old-write');
            }),
            throwsStateError,
          );
          await oldStarted.future;

          witness.http.refreshToken = 'synthetic-A-replacement';
          await witness.http.account.signIn(
            email: 'synthetic@example.invalid',
            password: 'Synthetic!Password123',
          );
          await _until(() => witness.ownerRotations == 1);
          expect(witness.authEvents, contains('signedIn'));
          final freshEpoch = AccountStoreEpochRegistry.capture(ticketAlice);
          expect(freshEpoch, isNot(same(oldEpoch)));
          expect(oldEpoch.checkCurrent, throwsStateError);
          expect(oldEpoch.writeLease.isActive, isFalse);
          expect(freshEpoch.isActive, isTrue);
          final freshTicket = AccountActionTicket.capture(
            witness.http.account,
          )!;
          expect(freshTicket.epoch, same(freshEpoch));
          await expectLater(oldBound.deleteCommonAccount(), throwsStateError);
          expect(
            witness.http.deletions,
            hasLength(1),
            reason: 'stale pre-dialog ticket must not dispatch another RPC',
          );

          // Fresh work is admitted to E+1, but cannot enter filesystem IO until
          // E's started writer drains. The UUID receipt must retire both.
          final freshLease = CourseProgressLease(
            File('${witness.aDirectory.path}/fresh-program.json'),
          );
          freshHostRejected = expectLater(
            freshLease.mutate(() async {
              freshWriterRan = true;
              await freshLease.file.writeAsString('must not recreate A');
            }),
            throwsStateError,
          );
          final freshJournal = AccountSessionStore(witness.aJournal);
          freshJournalRejected = expectLater(
            freshJournal.append(_record('fresh-admitted-before-receipt')),
            throwsStateError,
          );
          expect(freshWriterRan, isFalse);
          witness.expectAuth('synthetic-A-replacement');

          reply.complete(
            accountHttpResponse({'deleted': true, 'userId': ticketAlice}),
          );
          await fenced.future;
          expect(oldEpoch.checkCurrent, throwsStateError);
          expect(freshEpoch.checkCurrent, throwsStateError);
          expect(freshEpoch.writeLease.isActive, isFalse);
          expect(eraseEntered, isFalse);
          expect(await witness.aDirectory.exists(), isTrue);
          expect(
            () => AccountStoreEpochRegistry.activate(ticketAlice),
            throwsStateError,
          );
          await expectLater(
            witness.bound(freshTicket).deleteCommonAccount(),
            throwsStateError,
          );
          expect(witness.http.deletions, hasLength(1));

          releaseOld.complete();
          await Future.wait([
            oldRejected,
            freshHostRejected,
            freshJournalRejected,
            deletionCompleted,
          ]);
          expect(trace, ['old-write', 'erase']);
          expect(freshWriterRan, isFalse);
          expect(await witness.aDirectory.exists(), isFalse);
          await expectLater(freshJournal.recent(), throwsStateError);
          expect(
            AccountStoreEpochRegistry.isAccountErasureBlocked(ticketAlice),
            isTrue,
          );
          await witness.expectDisjointFilesPreserved();
          witness.expectAuth('synthetic-A-replacement');
          expect(witness.http.logoutCalls, 0);
          expect(witness.authEvents, isNot(contains('signedOut')));
        } finally {
          if (!releaseOld.isCompleted) releaseOld.complete();
          witness.http.releasePending();
          try {
            await Future.wait([
              if (oldRejected != null) oldRejected,
              if (freshHostRejected != null) freshHostRejected,
              if (freshJournalRejected != null) freshJournalRejected,
              if (deletionCompleted != null) deletionCompleted,
            ]);
          } finally {
            await witness.dispose();
          }
        }
      });
    },
  );
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

Future<void> _until(bool Function() predicate) async {
  final clock = Stopwatch()..start();
  const limit = Duration(seconds: 5);
  while (!predicate()) {
    if (clock.elapsed >= limit) {
      throw TimeoutException('Synthetic async boundary did not settle', limit);
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

/// Real HTTP-bound Core/Supabase clients and actual files. Only the owner-event
/// host seam is driven here: it follows bootstrap's signedIn/signedOut/recovery
/// policy and intentionally excludes tokenRefreshed. No app route/media/camera
/// is mounted, so these tests make no combined resource-lifecycle claim.
final class _ErasureWitness {
  _ErasureWitness(this.root, this.http);

  final Directory root;
  final AccountHttpFixture http;
  late final StreamSubscription<dynamic> _auth;
  final authEvents = <String>[];
  int ownerRotations = 0;
  late final List<int> _bBytes;
  late final List<int> _guestBytes;

  Directory get aDirectory => accountDataDirectory(root, ticketAlice);
  File get aJournal => File('${aDirectory.path}/free_sessions.jsonl');
  File get aHostFile => File('${aDirectory.path}/program.json');
  File get bFile =>
      File('${accountDataDirectory(root, ticketBob).path}/free_sessions.jsonl');
  File get guestFile => File('${root.path}/free_sessions.jsonl');

  static Future<_ErasureWitness> create() async {
    await AccountStoreEpochRegistry.resetForTest();
    final root = await Directory.systemTemp.createTemp(
      'gravita-confirmed-erasure-refresh-',
    );
    final witness = _ErasureWitness(root, AccountHttpFixture());
    await witness.bFile.parent.create(recursive: true);
    await witness.bFile.writeAsString('SYNTHETIC B FILE PRESERVED\n');
    await witness.guestFile.writeAsString('SYNTHETIC GUEST FILE PRESERVED\n');
    witness._bBytes = await witness.bFile.readAsBytes();
    witness._guestBytes = await witness.guestFile.readAsBytes();
    await AccountStoreEpochRegistry.enableManagedAdmission();
    await AccountStoreEpochRegistry.activate(ticketAlice).ready;
    await AccountSessionStore(witness.aJournal).append(_record('A existing'));
    await witness.aHostFile.writeAsString('A existing host bytes');
    await witness.http.session(ticketAlice);
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
      unawaited(AccountStoreEpochRegistry.retireAll());
      final userId = state.session?.user.id;
      if (!AccountStoreEpochRegistry.isAccountErasureBlocked(userId)) {
        AccountStoreEpochRegistry.activate(userId);
      }
    });
    await Future<void>.delayed(Duration.zero);
    witness.authEvents.clear();
    witness.ownerRotations = 0;
    return witness;
  }

  EpochBoundMotionAccountClient bound(AccountActionTicket ticket) =>
      EpochBoundMotionAccountClient(original: http.account, ticket: ticket);

  void expectPinnedRequest() {
    expect(
      http.deletions.single.headers['Authorization'],
      'Bearer synthetic-A-old',
    );
    expect(jsonDecode(http.deletions.single.body), {
      'confirmation': 'DELETE',
      'expectedUserId': ticketAlice,
    });
  }

  void expectAuth(String token) {
    expect(http.client.auth.currentUser?.id, ticketAlice);
    expect(http.client.auth.currentSession?.accessToken, token);
  }

  Future<void> expectDisjointFilesPreserved() async {
    expect(await bFile.readAsBytes(), orderedEquals(_bBytes));
    expect(await guestFile.readAsBytes(), orderedEquals(_guestBytes));
  }

  Future<void> dispose() async {
    await _auth.cancel();
    await http.dispose();
    await AccountStoreEpochRegistry.resetForTest();
    await root.delete(recursive: true);
  }
}

final class _GatedExistsFile implements File {
  _GatedExistsFile(this.delegate, this.release);
  final File delegate;
  final Future<void> release;
  final started = Completer<void>();

  @override
  File get absolute => delegate.absolute;
  @override
  String get path => delegate.path;
  @override
  Directory get parent => delegate.parent;
  @override
  Future<bool> exists() async {
    started.complete();
    await release;
    return delegate.exists();
  }

  @override
  Future<String> readAsString({Encoding encoding = utf8}) =>
      delegate.readAsString(encoding: encoding);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
