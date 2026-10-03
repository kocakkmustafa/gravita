import 'dart:io';

import 'package:motion_core/motion_core.dart';

import 'course_progress_io.dart';
import 'account_store_epoch.dart';

/// The pinned journal schema stays in Core; account lifetime stays in Gravita.
/// Multiple app handles share the same file queue and deletion fence.
final class AccountSessionStore implements SessionStore {
  AccountSessionStore(File file, {AccountStoreEpoch? epoch})
    : _lease = CourseProgressLease(file, epoch: epoch) {
    _journal = JsonlSessionStore(file, writeLease: _lease.epoch.writeLease);
  }

  late final JsonlSessionStore _journal;
  final CourseProgressLease _lease;

  @override
  Future<void> append(SessionRecord record) =>
      _lease.mutate(() => _journal.append(record));

  @override
  Future<List<SessionRecord>> recent({int? limit}) =>
      _lease.mutate(() => _journal.recent(limit: limit));

  @override
  Future<int> workedSecondsFor(String lessonId) =>
      _lease.mutate(() => _journal.workedSecondsFor(lessonId));

  @override
  Future<int> unreadableRecords() => _lease.mutate(_journal.unreadableRecords);
}
