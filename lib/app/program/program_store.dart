import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../account_data_directory.dart';

import 'program_model.dart';

/// Kullanıcının program girdilerinin + üretilmiş programın KALICILIĞI —
/// `onboarding_store.dart`ın AYNI deseni (G-127'nin kendi kuralı: "depo saf
/// Dart, KABLOLAMA Flutter").
///
/// ⚠️ Programın KENDİSİ (haftalar/günler/reçeteler) DEĞİL yalnız [ProgramInputs]
/// diskte durur — [WorkoutProgram] her açılışta [ProgramInputs] + GÜNCEL
/// katalogdan YENİDEN üretilir (`ProgramBuilder.build` deterministik). Bu,
/// bir içerik güncellemesi (ör. bir hareket `coming_soon`dan `live`e
/// terfi ettiğinde) kullanıcının GÖRDÜĞÜ programın da doğru güncellenmesini
/// SAĞLAR — dondurulmuş bir kopya bayatlardı.
class ProgramStore {
  const ProgramStore._(this._file);

  final File _file;

  static Future<ProgramStore> open({String? accountUserId}) async {
    final Directory dir = accountDataDirectory(
      await getApplicationSupportDirectory(), accountUserId);
    return ProgramStore._(File('${dir.path}/program_inputs.json'));
  }

  /// Yalnız test/harness için — gerçek dizin yerine verilen dosyayı kullanır.
  static ProgramStore forFile(File file) => ProgramStore._(file);

  /// Kayıtlı girdi — hiç seçilmemişse ya da dosya okunamıyorsa `null`.
  /// ⚠️ Bozuk/okunamayan dosya "hiç seçilmemiş" SAYILIR — kullanıcıyı
  /// sonsuza dek kurulum ekranına KİLİTLEMEZ (`OnboardingStore.isComplete`
  /// ile AYNI fail-open gerekçesi: burada da "kurulum GÖSTER" kullanıcıyı
  /// dışarıda bırakmaz, yalnız bir kez tekrar sorar).
  Future<ProgramInputs?> read() async {
    if (!await _file.exists()) return null;
    try {
      final Map<String, dynamic> j =
          jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      return ProgramInputs(
        availableEquipment:
            (j['availableEquipment'] as List<dynamic>).cast<String>().toSet(),
        daysPerWeek: j['daysPerWeek'] as int,
        experience: ExperienceLevel.values.byName(j['experience'] as String),
      );
    } on Object {
      return null;
    }
  }

  Future<void> write(ProgramInputs inputs) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'availableEquipment': inputs.availableEquipment.toList(),
      'daysPerWeek': inputs.daysPerWeek,
      'experience': inputs.experience.name,
    }));
  }

  /// Programı kaldırır (kullanıcı yeniden kurmak isterse). Dosya yoksa
  /// sessizce başarılı sayılır — "zaten yok" bir hata değildir.
  Future<void> clear() async {
    if (await _file.exists()) await _file.delete();
  }
}
