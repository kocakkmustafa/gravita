import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ⭐ H-44 — **"ders bağlamlı bir başlatma yolu HENÜZ YOK" cümlesi ÖLÇÜLEBİLİR
/// bir kapıya mı bağlı, yoksa yalnız DÜZYAZIYA mı?**
///
/// `content_repository.dart:189-190` ve `free_bucket_integrity_test.dart`
/// (G-211) AYNI olguyu anlatıyor: `LiveSessionScreen`e bugün **tek giriş**
/// var ve o giriş HAREKET düzeyinde (`gravita_app.dart`), DERS bağlamlı
/// değil — bu yüzden her seans serbest kovaya yazılıyor, dallanma yok. İki
/// dosya da bunu ŞİMDİYE KADAR yalnız düzyazıyla anlatıyordu; bu test o
/// olguyu ölçüyor (koordinatör H-44: yokluk beyanlarını mümkünse gerçek bir
/// teste bağla).
///
/// Bir kurs sayfası inşa edilip `LiveSessionScreen`e İKİNCİ bir çağrı yeri
/// eklendiği gün bu test KIRMIZI yanar — o an `content_repository.dart`daki
/// "serbest/ders" yönlendirme kararı YENİDEN yazılmalı, tek-giriş varsayımı
/// artık geçerli değil.
void main() {
  test('LiveSessionScreen tam olarak TEK yerden inşa ediliyor — HAREKET '
      'düzeyinde (gravita_app.dart)', () {
    final List<File> dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();
    expect(dartFiles, isNotEmpty, reason: 'VAKUM: lib/ altında .dart yok.');

    final RegExp ctor = RegExp(r'LiveSessionScreen\(');
    final List<String> siteler = <String>[];
    for (final File f in dartFiles) {
      // Sınıfın KENDİ tanım dosyası hariç — `const LiveSessionScreen({` bir
      // ÇAĞRI değil yapıcı BİLDİRİMİ, aynı dizgiyle eşleşir ama farklı şey.
      if (f.path.endsWith('live_session_screen.dart')) continue;
      final List<String> lines = f.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String trimmed = lines[i].trim();
        if (trimmed.startsWith('///') || trimmed.startsWith('//')) continue;
        if (ctor.hasMatch(lines[i])) siteler.add('${f.path}:${i + 1}');
      }
    }

    expect(siteler, <String>['lib/app/gravita_app.dart:216'],
        reason: 'LiveSessionScreen inşa yerleri değişti ⇒ '
            'content_repository.dart:189-190 ve free_bucket_integrity_test.'
            'dart\'ın (G-211) "tek giriş, ders bağlamı yok" iddiası artık '
            'YANLIŞ olabilir (H-44) — o yorumlar ve serbest/ders '
            'yönlendirme kararı elden geçirilmeli. Bulunan: $siteler');
  });
}
