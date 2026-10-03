import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_data_directory.dart';
import 'package:gravita/app/calisthenics_progress.dart';
import 'package:gravita/app/course_progress_io.dart';

void main() {
  const account = '11111111-1111-4111-8111-111111111111';
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('gravita-in-flight-account-');
  });
  tearDown(() async => root.delete(recursive: true));

  Future<void> waitForRevocation(CourseProgressLease lease) async {
    for (var turn = 0; turn < 100; turn++) {
      try {
        lease.checkCurrent();
      } on StateError {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('deletion must revoke the active lease before waiting for its IO');
  }

  test(
    'deletion drains a started writer and rejects its stale result',
    () async {
      final directory = accountDataDirectory(root, account);
      await directory.create(recursive: true);
      final file = File('${directory.path}/pending.json');
      final lease = CourseProgressLease(file);
      final started = Completer<void>();
      final release = Completer<void>();
      final operation = lease.mutate(() async {
        started.complete();
        await release.future;
        await file.writeAsString('finished before deletion');
        return 'retired identity';
      });
      final rejected = expectLater(operation, throwsStateError);
      await started.future;
      var deleted = false;
      final deletion = deleteAccountData(
        root,
        account,
      ).then((_) => deleted = true);
      try {
        await waitForRevocation(lease);
        expect(deleted, isFalse);
        expect(await directory.exists(), isTrue);
      } finally {
        release.complete();
        await rejected;
        await deletion;
      }
      expect(deleted, isTrue);
      expect(await directory.exists(), isFalse);
    },
  );

  test('deletion rechecks ancestry after an active operation drains', () async {
    final directory = accountDataDirectory(root, account);
    await directory.create(recursive: true);
    final lease = CourseProgressLease(File('${directory.path}/pending.json'));
    final started = Completer<void>();
    final release = Completer<void>();
    final operation = lease.mutate(() async {
      started.complete();
      await release.future;
      return 'retired read';
    });
    final rejected = expectLater(operation, throwsStateError);
    await started.future;
    final outside = await Directory.systemTemp.createTemp('gravita-target-');
    addTearDown(() => outside.delete(recursive: true));
    final target = await Directory('${outside.path}/$account').create();
    final sentinel = await File(
      '${target.path}/keep.txt',
    ).writeAsString('keep');
    final deletion = expectLater(
      deleteAccountData(root, account),
      throwsA(isA<FileSystemException>()),
    );
    try {
      await waitForRevocation(lease);
      await Directory('${root.path}/accounts').rename('${root.path}/retained');
      await Link('${root.path}/accounts').create(outside.path);
    } finally {
      release.complete();
      await rejected;
      await deletion;
    }
    expect(await sentinel.readAsString(), 'keep');
  });

  test('a pending missing-file course read rejects account deletion', () async {
    final directory = accountDataDirectory(root, account);
    final file = _DelayedMissingFile(File('${directory.path}/course.json'));
    final store = CalisthenicsProgressStore(file);
    final read = store.load();
    final rejected = expectLater(read, throwsStateError);
    await file.started.future;
    var deleted = false;
    final deletion = deleteAccountData(
      root,
      account,
    ).then((_) => deleted = true);
    try {
      await Future<void>.delayed(Duration.zero);
      expect(
        deleted,
        isFalse,
        reason: 'the admitted course read is still pending',
      );
    } finally {
      file.result.complete(false);
      await rejected;
      await deletion;
    }
    expect(deleted, isTrue);
  });
}

final class _DelayedMissingFile implements File {
  _DelayedMissingFile(this.delegate);
  final File delegate;
  final started = Completer<void>();
  final result = Completer<bool>();

  @override
  File get absolute => delegate.absolute;
  @override
  String get path => delegate.path;
  @override
  Future<bool> exists() {
    started.complete();
    return result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
