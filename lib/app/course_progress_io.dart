import 'dart:io';

import 'account_store_epoch.dart';

final class _FileQueue {
  Future<void>? tail;
  int generation = 0;
  Future<T> enqueue<T>(Future<T> Function() operation) {
    final previous = tail;
    final result = previous == null
        ? Future<T>.sync(operation)
        : previous.then((_) => operation());
    late final Future<void> drain;
    void settled() {
      if (identical(tail, drain)) tail = null;
    }

    drain = result.then<void>(
      (_) => settled(),
      onError: (Object _, StackTrace __) => settled(),
    );
    tail = drain;
    return result;
  }
}

final Map<String, _FileQueue> _queues = <String, _FileQueue>{};
final Set<String> _deletedAccountDirectories = <String>{};
bool _deleted(File file) => _deletedAccountDirectories.any(
  (path) => normalizedAccountStorePath(file.path).startsWith('$path/'),
);

/// App-owned account files have one queue per absolute file. Deletion blocks
/// old and newly opened stores for the deleted identity before draining IO.
final class CourseProgressLease {
  CourseProgressLease(this.file, {AccountStoreEpoch? epoch})
    : epoch = AccountStoreEpochRegistry.forFile(file, captured: epoch),
      _queue = _queues.putIfAbsent(
        normalizedAccountStorePath(file.path),
        _FileQueue.new,
      ) {
    _generation = _queue.generation;
    checkCurrent();
  }
  final File file;
  final AccountStoreEpoch epoch;
  final _FileQueue _queue;
  late final int _generation;
  void checkCurrent() {
    epoch.checkCurrent();
    if (_deleted(file) || _generation != _queue.generation) {
      throw StateError('Local account identity was deleted');
    }
  }

  Future<T> mutate<T>(Future<T> Function() operation) => epoch.runHostIo(
    () => _queue.enqueue(() async {
      checkCurrent();
      final result = await operation();
      checkCurrent();
      return result;
    }),
  );
}

Future<void> invalidateCourseProgressDirectory(Directory directory) async {
  final path = normalizedAccountStorePath(directory.path);
  _deletedAccountDirectories.add(path);
  final List<Future<void>> drains = <Future<void>>[
    AccountStoreEpochRegistry.retireDirectory(directory),
  ];
  for (final entry in _queues.entries) {
    if (entry.key.startsWith('$path/')) {
      entry.value.generation++;
      final tail = entry.value.tail;
      if (tail != null) drains.add(tail);
    }
  }
  await Future.wait(drains);
}
