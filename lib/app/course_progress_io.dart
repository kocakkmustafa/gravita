import 'dart:io';

final class _FileQueue {
  Future<void> tail = Future<void>.value();
  int generation = 0;
  Future<T> enqueue<T>(Future<T> Function() operation) {
    final result = tail.then((_) => operation());
    tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}

final Map<String, _FileQueue> _queues = <String, _FileQueue>{};
final Set<String> _deletedAccountDirectories = <String>{};
bool _deleted(File file) => _deletedAccountDirectories.any(
  (path) => file.absolute.path.startsWith('$path/'),
);

/// App-local course writes have one queue per absolute file. Deletion blocks
/// old and newly opened stores for the deleted identity before draining IO.
final class CourseProgressLease {
  CourseProgressLease(this.file)
    : _queue = _queues.putIfAbsent(file.absolute.path, _FileQueue.new) {
    _generation = _queue.generation;
    checkCurrent();
  }
  final File file;
  final _FileQueue _queue;
  late final int _generation;
  void checkCurrent() {
    if (_deleted(file) || _generation != _queue.generation) {
      throw StateError('Course progress identity was deleted');
    }
  }

  Future<T> mutate<T>(Future<T> Function() operation) => _queue.enqueue(() {
    checkCurrent();
    return operation();
  });
}

Future<void> invalidateCourseProgressDirectory(Directory directory) async {
  final path = directory.absolute.path;
  _deletedAccountDirectories.add(path);
  final List<Future<void>> drains = <Future<void>>[];
  for (final entry in _queues.entries) {
    if (entry.key.startsWith('$path/')) {
      entry.value.generation++;
      drains.add(entry.value.tail);
    }
  }
  await Future.wait(drains);
}
