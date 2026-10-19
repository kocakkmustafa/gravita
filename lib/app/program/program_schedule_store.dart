import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../account_data_directory.dart';
import '../course_progress_io.dart';
import '../account_store_epoch.dart';
import 'program_schedule_io.dart';

export 'program_schedule_io.dart'
    show ProgramSchedule, ProgramScheduleException, ProgramScheduleFailure;

/// Flutter path/account wiring. All file operations and read-modify-write
/// transactions delegate to the pure Dart production pipeline, under the same
/// existing per-file queue and account epoch lease.
final class ProgramScheduleStore {
  ProgramScheduleStore._(File file, {AccountStoreEpoch? epoch})
    : _file = file,
      _lease = CourseProgressLease(file, epoch: epoch) {
    _io = ProgramScheduleIo(
      file,
      serialize: _lease.mutate,
      checkCurrent: _lease.checkCurrent,
    );
  }

  final File _file;
  final CourseProgressLease _lease;
  late final ProgramScheduleIo _io;

  static Future<ProgramScheduleStore> open({String? accountUserId}) async {
    final epoch = AccountStoreEpochRegistry.capture(accountUserId);
    final Directory dir = accountDataDirectory(
      await getApplicationSupportDirectory(),
      accountUserId,
    );
    epoch.checkCurrent();
    return ProgramScheduleStore._(
      File('${dir.path}/program_schedule.json'),
      epoch: epoch,
    );
  }

  /// Yalnız test/harness için — gerçek dizin yerine verilen dosyayı kullanır.
  static ProgramScheduleStore forFile(File file) =>
      ProgramScheduleStore._(file);

  /// Only an absent file is null. Corrupt/unavailable data throws and remains
  /// unchanged; a legacy null signature is returned without any migration.
  Future<ProgramSchedule?> read() => _io.read();

  Future<void> write(ProgramSchedule schedule) => _io.write(schedule);

  Future<ProgramSchedule> createIfMissing(ProgramSchedule Function() factory) =>
      _io.createIfMissing(factory);

  Future<ProgramSchedule> update({
    required String expectedSignature,
    required ProgramSchedule Function(ProgramSchedule current) transform,
  }) => _io.update(expectedSignature: expectedSignature, transform: transform);

  /// Takvimi kaldırır (ör. kullanıcı programı yeniden kurarsa). Dosya yoksa
  /// sessizce başarılı sayılır — `ProgramStore.clear` ile AYNI gerekçe.
  Future<void> clear() => _lease.mutate(() async {
    if (await _file.exists()) {
      _lease.checkCurrent();
      await _file.delete();
    }
  });
}
