import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_data_directory.dart';
import 'package:gravita/app/account_session_store.dart';
import 'package:gravita/app/account_store_epoch.dart';
import 'package:gravita/app/course_progress_io.dart';
import 'package:motion_core/motion_core.dart';

void main() {
  const first = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const second = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  late Directory root;

  setUp(() async {
    await AccountStoreEpochRegistry.resetForTest();
    root = await Directory.systemTemp.createTemp('gravita-erasure-fence-');
  });
  tearDown(() async {
    await AccountStoreEpochRegistry.resetForTest();
    await root.delete(recursive: true);
  });

  SessionRecord record(String lesson) => SessionRecord(
    lessonId: lesson,
    completedAt: DateTime.utc(2026, 10, 2),
    workedSeconds: 10,
    unitsCompleted: 1,
    plannedUnits: 1,
    unitLabel: 'rep',
    lessonClass: 'measurementOnly',
  );

  test('fence closes same UUID before held support-directory lookup', () async {
    await AccountStoreEpochRegistry.enableManagedAdmission();
    final old = AccountStoreEpochRegistry.activate(first);
    final heldDirectory = Completer<void>();
    final entered = Completer<void>();
    final cleanup = AccountStoreEpochRegistry.beginConfirmedAccountErasure(
      first,
      () async {
        entered.complete();
        await heldDirectory.future;
        await deleteAccountData(root, first);
      },
    );
    try {
      expect(() => AccountStoreEpochRegistry.activate(first), throwsStateError);
      expect(AccountStoreEpochRegistry.isAccountErasureBlocked(first), isTrue);
      expect(old.checkCurrent, throwsStateError);
      expect(old.writeLease.isActive, isFalse);
      expect(() => AccountStoreEpochRegistry.capture(first), throwsStateError);
      await entered.future;
    } finally {
      heldDirectory.complete();
      await cleanup;
    }
    expect(AccountStoreEpochRegistry.isAccountErasureBlocked(first), isTrue);
    expect(() => AccountStoreEpochRegistry.activate(first), throwsStateError);
  });

  test(
    'overlapping callbacks share exactly one erase Future and action',
    () async {
      await AccountStoreEpochRegistry.enableManagedAdmission();
      AccountStoreEpochRegistry.activate(first);
      final release = Completer<void>();
      var calls = 0;
      Future<void> erase() async {
        calls++;
        await release.future;
      }

      final one = AccountStoreEpochRegistry.beginConfirmedAccountErasure(
        first,
        erase,
      );
      final two = AccountStoreEpochRegistry.beginConfirmedAccountErasure(
        first.toUpperCase(),
        erase,
      );
      try {
        expect(two, same(one));
        await Future<void>.delayed(Duration.zero);
        expect(calls, 1);
      } finally {
        release.complete();
        await Future.wait([one, two]);
      }
      await AccountStoreEpochRegistry.beginConfirmedAccountErasure(
        first,
        erase,
      );
      expect(
        calls,
        1,
        reason: 'confirmed completed erasure stays fenced and idempotent',
      );
    },
  );

  test('A cleanup leaves active B and guest files unchanged', () async {
    final guestFile = File('${root.path}/free_sessions.jsonl');
    final aFile = File(
      '${accountDataDirectory(root, first).path}/free_sessions.jsonl',
    );
    final bFile = File(
      '${accountDataDirectory(root, second).path}/free_sessions.jsonl',
    );
    await AccountSessionStore(guestFile).append(record('guest'));
    await AccountSessionStore(aFile).append(record('A'));
    await AccountSessionStore(bFile).append(record('B'));
    final guestBytes = await guestFile.readAsString();
    await AccountStoreEpochRegistry.enableManagedAdmission();
    final bEpoch = AccountStoreEpochRegistry.activate(second);
    final bStore = AccountSessionStore(bFile);
    final release = Completer<void>();
    final entered = Completer<void>();
    final cleanup = AccountStoreEpochRegistry.beginConfirmedAccountErasure(
      first,
      () async {
        entered.complete();
        await release.future;
        await deleteAccountData(root, first);
      },
    );
    try {
      await entered.future;
      expect(AccountStoreEpochRegistry.capture(second), same(bEpoch));
      expect(
        AccountStoreEpochRegistry.isAccountErasureBlocked(second),
        isFalse,
      );
      expect(AccountStoreEpochRegistry.isAccountErasureBlocked(null), isFalse);
      await bStore.append(record('B while A pending'));
      expect((await bStore.recent()).map((entry) => entry.lessonId).toSet(), {
        'B',
        'B while A pending',
      });
      expect(await guestFile.readAsString(), guestBytes);
    } finally {
      release.complete();
      await cleanup;
    }
    expect(await aFile.exists(), isFalse);
    expect(bEpoch.isActive, isTrue);
    expect((await bStore.recent()).length, 2);
    expect(await guestFile.readAsString(), guestBytes);
  });

  test(
    'all known A file epochs retire and admitted writes drain before erase',
    () async {
      final secondRoot = await Directory.systemTemp.createTemp(
        'gravita-erasure-other-root-',
      );
      addTearDown(() => secondRoot.delete(recursive: true));
      final file = File(
        '${accountDataDirectory(root, first).path}/pending.json',
      );
      await file.parent.create(recursive: true);
      final firstLease = CourseProgressLease(file);
      final otherLease = CourseProgressLease(
        File('${accountDataDirectory(secondRoot, first).path}/pending.json'),
      );
      final guestLease = CourseProgressLease(File('${root.path}/guest.json'));
      final bLease = CourseProgressLease(
        File('${accountDataDirectory(root, second).path}/pending.json'),
      );
      final started = Completer<void>();
      final release = Completer<void>();
      final write = firstLease.mutate(() async {
        started.complete();
        await release.future;
        await file.writeAsString('old admitted write');
      });
      final rejected = expectLater(write, throwsStateError);
      await started.future;
      var eraseCalls = 0;
      final cleanup = AccountStoreEpochRegistry.beginConfirmedAccountErasure(
        first,
        () async {
          eraseCalls++;
          await deleteAccountData(root, first);
        },
      );
      try {
        expect(firstLease.checkCurrent, throwsStateError);
        expect(otherLease.checkCurrent, throwsStateError);
        guestLease.checkCurrent();
        bLease.checkCurrent();
        await Future<void>.delayed(Duration.zero);
        expect(
          eraseCalls,
          0,
          reason: 'erase cannot overtake admitted account IO',
        );
      } finally {
        release.complete();
        await rejected;
        await cleanup;
      }
      expect(eraseCalls, 1);
      expect(await file.exists(), isFalse);
      expect(
        () => CourseProgressLease(
          File('${accountDataDirectory(secondRoot, first).path}/new.json'),
        ),
        throwsStateError,
      );
      guestLease.checkCurrent();
      bLease.checkCurrent();
    },
  );

  test(
    'failed cleanup remains blocked and one explicit retry is coalesced',
    () async {
      await AccountStoreEpochRegistry.enableManagedAdmission();
      AccountStoreEpochRegistry.activate(first);
      final failure = StateError('synthetic erase failed');
      await expectLater(
        AccountStoreEpochRegistry.beginConfirmedAccountErasure(first, () async {
          throw failure;
        }),
        throwsStateError,
      );
      expect(AccountStoreEpochRegistry.isAccountErasureBlocked(first), isTrue);
      expect(AccountStoreEpochRegistry.erasureError(first), same(failure));
      expect(AccountStoreEpochRegistry.erasureError(second), isNull);
      expect(AccountStoreEpochRegistry.erasureError(null), isNull);
      expect(() => AccountStoreEpochRegistry.activate(first), throwsStateError);
      final release = Completer<void>();
      var retryCalls = 0;
      Future<void> retry() async {
        retryCalls++;
        await release.future;
        await deleteAccountData(root, first);
      }

      final one = AccountStoreEpochRegistry.beginConfirmedAccountErasure(
        first,
        retry,
      );
      final two = AccountStoreEpochRegistry.beginConfirmedAccountErasure(
        first,
        retry,
      );
      try {
        expect(AccountStoreEpochRegistry.erasureError(first), isNull);
        expect(two, same(one));
        await Future<void>.delayed(Duration.zero);
        expect(retryCalls, 1);
        expect(
          () => AccountStoreEpochRegistry.capture(first),
          throwsStateError,
        );
      } finally {
        release.complete();
        await Future.wait([one, two]);
      }
      expect(AccountStoreEpochRegistry.isAccountErasureBlocked(first), isTrue);
      expect(AccountStoreEpochRegistry.erasureError(first), isNull);
      AccountStoreEpochRegistry.activate(second);
      expect(AccountStoreEpochRegistry.capture(second).isActive, isTrue);
    },
  );

  test(
    'admission notifier fires for erasure changes only and reset clears fence',
    () async {
      var notifications = 0;
      void listener() {
        notifications++;
      }

      AccountStoreEpochRegistry.admissionChanges.addListener(listener);
      addTearDown(
        () =>
            AccountStoreEpochRegistry.admissionChanges.removeListener(listener),
      );
      await AccountStoreEpochRegistry.enableManagedAdmission();
      AccountStoreEpochRegistry.activate(first);
      await AccountStoreEpochRegistry.retireAll();
      AccountStoreEpochRegistry.activate(first);
      expect(notifications, 0);
      final release = Completer<void>();
      final pending = AccountStoreEpochRegistry.beginConfirmedAccountErasure(
        first,
        () => release.future,
      );
      try {
        expect(notifications, 1);
        AccountStoreEpochRegistry.beginConfirmedAccountErasure(
          first,
          () async {},
        );
        expect(
          notifications,
          1,
          reason: 'joining the same erase does not notify again',
        );
      } finally {
        release.complete();
        await pending;
      }
      expect(notifications, 2);
      await AccountStoreEpochRegistry.beginConfirmedAccountErasure(
        first,
        () async {},
      );
      expect(notifications, 2);
      await AccountStoreEpochRegistry.resetForTest();
      expect(notifications, 3);
      expect(AccountStoreEpochRegistry.isAccountErasureBlocked(first), isFalse);
      final reopened = AccountStoreEpochRegistry.capture(first);
      expect(reopened.isActive, isTrue);
    },
  );

  test('invalid captured UUID never enters erase callback', () async {
    var called = false;
    expect(
      () => AccountStoreEpochRegistry.beginConfirmedAccountErasure(
        '../other',
        () async {
          called = true;
        },
      ),
      throwsArgumentError,
    );
    expect(called, isFalse);
  });
}
