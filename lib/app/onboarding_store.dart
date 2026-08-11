import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// İlk-açılış akışının TAMAMLANDI beyanı — kalıcı, tek bit.
///
/// **Neden ayrı dosya, `content_repository.dart`nın deseni:** kalıcılık
/// KABLOLAMASI (dosya yolu, `path_provider`) motor/ekran katmanından ayrı
/// tutulur — `docs/design/SESSION-STORE-DELTA.md` §0'ın aynı ilkesi:
/// "depo saf Dart, KABLOLAMA Flutter" (burada "saf Dart" katmanı yok çünkü
/// tek bir bool'un motor tarafında bir karşılığı yok — ama YİNE DE ekran
/// widget'larından ayrı: bir test akışın TAMAMINI pump etmeden bu bit'i
/// doğrudan sınayabilsin).
class OnboardingStore {
  const OnboardingStore._(this._file);

  final File _file;

  static Future<OnboardingStore> open() async {
    final Directory dir = await getApplicationSupportDirectory();
    return OnboardingStore._(File('${dir.path}/onboarding.json'));
  }

  /// Yalnız test/harness için — gerçek dizin yerine verilen dosyayı kullanır.
  static OnboardingStore forFile(File file) => OnboardingStore._(file);

  Future<bool> isComplete() async {
    if (!await _file.exists()) return false;
    try {
      final Map<String, dynamic> j =
          jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      return j['completed'] == true;
    } on Object {
      // Bozuk/okunamayan dosya "tamamlanmadı" sayılır — kullanıcıyı
      // sonsuza dek onboarding'e KİLİTLEMEZ, yalnız bir kez tekrar gösterir.
      return false;
    }
  }

  Future<void> markComplete() async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(<String, dynamic>{
      'completed': true,
      'completedAt': DateTime.now().toIso8601String(),
      'schemaVersion': 1,
    }));
  }
}
