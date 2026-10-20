import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../account_data_directory.dart';
import '../course_progress_io.dart';
import '../account_store_epoch.dart';

import 'program_inputs_io.dart';
import 'program_model.dart';

/// Kullanıcının program girdilerinin + üretilmiş programın KALICILIĞI —
/// `onboarding_store.dart`ın AYNI deseni (G-127'nin kendi kuralı: "depo saf
/// Dart, KABLOLAMA Flutter").
///
/// ⚠️ Programın KENDİSİ (haftalar/günler/reçeteler) DEĞİL yalnız [ProgramInputs]
/// diskte durur — [WorkoutProgram] her açılışta [ProgramInputs] + GÜNCEL
/// katalogdan YENİDEN üretilir (`ProgramBuilder.build` deterministik).
/// Takvimdeki reçete bağı bu sonucu doğrular. Katalog/reçete değiştiğinde
/// eski tarih ve RPE yeni programa otomatik bağlanmaz; Workout korumalı
/// bekleme gösterir. Bu depo geçmiş programların göçünü uygulamaz.
class ProgramStore {
  ProgramStore._(File file, {AccountStoreEpoch? epoch})
    : _file = file,
      _lease = CourseProgressLease(file, epoch: epoch) {
    _io = ProgramInputsIo(
      file,
      serialize: _lease.mutate,
      checkCurrent: _lease.checkCurrent,
    );
  }

  final File _file;
  final CourseProgressLease _lease;
  late final ProgramInputsIo _io;

  static Future<ProgramStore> open({String? accountUserId}) async {
    final epoch = AccountStoreEpochRegistry.capture(accountUserId);
    final Directory dir = accountDataDirectory(
      await getApplicationSupportDirectory(),
      accountUserId,
    );
    epoch.checkCurrent();
    return ProgramStore._(
      File('${dir.path}/program_inputs.json'),
      epoch: epoch,
    );
  }

  /// Yalnız test/harness için — gerçek dizin yerine verilen dosyayı kullanır.
  static ProgramStore forFile(File file) => ProgramStore._(file);

  /// Only an absent file is null. Invalid/unavailable inputs must not be
  /// mistaken for a fresh setup and written over by the caller.
  Future<ProgramInputs?> read() => _io.read();

  Future<void> write(ProgramInputs inputs) => _io.write(inputs);

  /// Programı kaldırır (kullanıcı yeniden kurmak isterse). Dosya yoksa
  /// sessizce başarılı sayılır — "zaten yok" bir hata değildir.
  Future<void> clear() => _lease.mutate(() async {
    if (await _file.exists()) await _file.delete();
  });
}
