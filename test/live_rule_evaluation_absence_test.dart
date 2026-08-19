import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ⭐ H-44 — **"kurallar canlıda nereden çağrılıyor" cümlesi ÖLÇÜLEBİLİR bir
/// kapıya mı bağlı, yoksa yalnız DÜZYAZIYA mı?**
///
/// ⚠️ **KAPSAM DEĞİŞTİ (G-275, GRA-P1-004 Step 1/2).** Bu dosya EVVELCE
/// "lib/ altında HİÇBİR çağrı yok" derdi — `library_strings.dart`taki
/// `formErrorsBody`/`formErrorsBodyLive` (G-212) ve `onboarding_strings.
/// dart`taki karşılığı hepsi AYNI olguyu anlatıyordu: `RepEngine.
/// correctionFor` / `.topCorrection` / `.repMetrics` üründe hiç
/// çağrılmıyordu, tek çağıran `packages/gravita_engine/tool/replay_gate.dart`
/// (çevrimdışı kapı). `LiveFeedbackController` (`feedback_controller.dart`)
/// artık `LiveSessionRunner.consume()`dan (`live_session.dart`) ÇAĞRILIYOR —
/// blanket-yokluk iddiası artık YANLIŞ olurdu. Panzehir
/// `single_session_entry_point_test.dart`ın (H-44'ün AYNI ailesi) deseni:
/// yokluk yerine BİLİNEN, SINIRLI çağrı-yeri kümesini PİNLE — küme
/// DEĞİŞİRSE (büyür ya da küçülürse) kapı öter, sessizce geçmez.
///
/// Bu olgu birden çok dosyada DÜZYAZI olarak tekrarlanıyordu ama hiçbiri onu
/// ÖLÇMÜYORDU — biri motoru YENİ bir yerden çağırsa, o yorumlar SESSİZCE
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

  test(
      'lib/ altında bu API\'yi çağıran yerler TAM OLARAK BİLİNEN ikiliyle '
      'sınırlı — GRA-P1-004 Step 1/2', () {
    final List<File> dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();
    expect(dartFiles, isNotEmpty, reason: 'VAKUM: lib/ altında .dart yok.');

    final List<String> siteler = <String>[];
    for (final File f in dartFiles) {
      final List<String> lines = f.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String trimmed = lines[i].trim();
        // Yorum satırları hariç — birden çok dosya bu API'yi DÜZYAZIYLA anıyor
        // (bu dosyanın kendisi + `feedback_controller.dart`ın kendi belgesi).
        if (trimmed.startsWith('///') || trimmed.startsWith('//')) continue;
        if (callPattern.hasMatch(lines[i])) siteler.add('${f.path}:${i + 1}');
      }
    }
    siteler.sort();

    expect(
      siteler,
      <String>[
        'lib/app/live_session.dart:191',
        'lib/app/workout/feedback_controller.dart:62',
      ],
      reason: 'Çağrı-yeri kümesi DEĞİŞTİ ⇒ ÜÇ şeyden biri olabilir: (1) YENİ '
          'bir çağrı eklendi ve `library_strings.dart`taki '
          '`formErrorsBody`/`formErrorsBodyLive` (G-212/G-275) +'
          '`onboarding_strings.dart`ın `valueWhatWeDo`su artık YALAN olabilir '
          '(H-44) — elle kontrol et; (2) bilinen bir çağrı SİLİNDİ — '
          '`LiveFeedbackController`ın kablosu koptu, `live_session_test.dart`'
          '"GRA-P1-004 Step 1/2" grubu da kırmızı yanmalıydı; (3) satır '
          'numaraları kaydı — dosya düzenlendi, yalnız bu listeyi güncelle. '
          'Bulunan: $siteler');
  });
}
