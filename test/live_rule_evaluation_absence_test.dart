import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ⭐ H-44 — **"kurallar canlıda çalışmıyor" cümlesi ÖLÇÜLEBİLİR bir kapıya mı
/// bağlı, yoksa yalnız DÜZYAZIYA mı?**
///
/// `library_strings.dart`taki `formErrorsBody`/`formErrorsBodyLive` (G-212) ve
/// `onboarding_strings.dart`taki karşılığı, hepsi AYNI olguyu anlatıyordu:
/// `RepEngine.correctionFor` / `.topCorrection` / `.repMetrics` üründe hiç
/// çağrılmıyor — tek çağıran `packages/gravita_engine/tool/replay_gate.dart`
/// (KAYITLI görüntü üzerinde koşan çevrimdışı kapı).
///
/// Bu olgu ÜÇ dosyada DÜZYAZI olarak tekrarlanıyordu ama hiçbiri onu
/// ÖLÇMÜYORDU — biri motoru canlı bir yerden çağırsa, üç yorum da SESSİZCE
/// yalan söylemeye başlardı, hiçbir test kırmızı yanmazdı. Bu dosya o boşluğu
/// kapatıyor (koordinatör H-44: yokluk beyanlarını mümkünse gerçek bir teste
/// bağla).
void main() {
  final RegExp callPattern =
      RegExp(r'\.(correctionFor|topCorrection|repMetrics)\(');

  test('motor kaynağı bu üç ismi HÂLÂ TAŞIYOR — yoksa aşağıdaki yokluk sahte '
      'olur', () {
    // VAKUM KORUMASI: API yeniden adlandırılırsa aşağıdaki "hiç çağrılmıyor"
    // testi hiçbir şey aramadığı için trivially yeşil kalır. Önce isimlerin
    // hâlâ var olduğunu doğrula, yoksa "temiz" sonucu anlamsızdır.
    final String src = File('packages/gravita_engine/lib/src/rep_engine.dart')
        .readAsStringSync();
    for (final String name in <String>[
      'correctionFor',
      'topCorrection',
      'repMetrics',
    ]) {
      expect(src.contains('$name('), isTrue,
          reason: '$name artık rep_engine.dart\'ta yok ⇒ bu kapı adı değişmiş '
              'bir API\'yi "hiç çağrılmıyor" sanıp yanlışlıkla yeşil kalıyor '
              'olabilir. library_strings.dart/onboarding_strings.dart\'taki '
              'yokluk cümlelerini elle kontrol et.');
    }
  });

  test('lib/ altında HİÇBİR dosya canlı kural-değerlendirme API\'sini '
      'çağırmıyor', () {
    final List<File> dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();
    expect(dartFiles, isNotEmpty, reason: 'VAKUM: lib/ altında .dart yok.');

    final List<String> ihlaller = <String>[];
    for (final File f in dartFiles) {
      final List<String> lines = f.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String trimmed = lines[i].trim();
        // Yorum satırları hariç — üç kaynak dosya da bu API'yi DÜZYAZIYLA
        // anıyor (bu dosyanın kendisi de dahil, yukarıdaki doc-comment).
        if (trimmed.startsWith('///') || trimmed.startsWith('//')) continue;
        if (callPattern.hasMatch(lines[i])) {
          ihlaller.add('${f.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(ihlaller, isEmpty,
        reason: 'lib/ içinde canlı kural-değerlendirme API\'si çağrıldı ⇒ '
            'library_strings.dart (formErrorsBody/formErrorsBodyLive) ve '
            'onboarding_strings.dart artık YALAN söylüyor (H-44) — o metinler '
            'GÜNCELLENMELİ. Bulunan çağrılar:\n${ihlaller.join('\n')}');
  });
}
