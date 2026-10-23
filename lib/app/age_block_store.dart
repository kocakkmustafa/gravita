import 'dart:async';
import 'dart:io';

/// Device-local, durable "under the minimum age" block for the shared Motion
/// account page (Core `MotionAccountPage(ageBlocked, onAgeBlocked)`).
///
/// Once the Core age gate reports an under-13 declaration, sign-up stays
/// closed on this device across restarts. A failed read starts unblocked:
/// the server still refuses an under-13 declaration, so this flag only keeps
/// the local form from being offered again. Guest use of the app is not
/// age-gated; only common-account creation is.
///
/// The file sits in the support root, outside `accounts/<uuid>`, so it is
/// neither listed as an account nor removed by confirmed account erasure.
class AgeBlockStore {
  AgeBlockStore({required Future<Directory> Function() directory})
    : _directory = directory;

  static const String fileName = 'motion_age_blocked';

  final Future<Directory> Function() _directory;
  bool _blocked = false;

  bool get blocked => _blocked;

  Future<File> _file() async =>
      File('${(await _directory()).path}${Platform.pathSeparator}$fileName');

  /// Bounded read before the first frame; any failure leaves it unblocked.
  Future<void> load({Duration timeout = const Duration(seconds: 2)}) async {
    try {
      _blocked = await (await _file()).exists().timeout(timeout);
    } on Object {
      _blocked = false;
    }
  }

  /// Marks this device blocked in memory at once, then persists it.
  Future<void> markBlocked() async {
    _blocked = true;
    try {
      final File file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString('1', flush: true);
    } on Object {
      // The in-memory block still holds for this run.
    }
  }
}
