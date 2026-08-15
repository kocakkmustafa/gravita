import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/content_failure.dart';
import 'package:gravita/app/content_repository.dart';
// ⚠️ `motion_core` da `History*` adlarını taşıyor (çekirdeğin OKUMA durumu).
// Bu testin konusu ÜRÜNÜN yüzey hükmü, o yüzden çekirdeğinkiler gizleniyor —
// iki ailenin adları karışırsa test hangi katmanı ölçtüğünü kaybeder.
import 'package:motion_core/motion_core.dart'
    hide HistoryOk, HistoryPartial, HistoryStatus, HistoryUnavailable;

/// ⭐ G-211 — **SERBEST KOVANIN BÜTÜNLÜĞÜ DE SORULUYOR MU?**
///
/// ## Kapattığı kusur
///
/// Geçmişin kayıp-satır sayısı **yalnız DERS kovasından** (`sessions.jsonl`)
/// okunuyordu. Serbest kova (`free_sessions.jsonl`) `recent()` ile okunuyor
/// ama **bütünlüğü hiç sorulmuyordu.**
///
/// Oysa bu üründe *"bugün her seans serbest seanstır"* — ders bağlamlı bir
/// başlatma yolu HENÜZ YOK (`content_repository.dart`). ⇒ Denetim, bugün
/// **her zaman BOŞ olan** dosyayı bekliyordu; kullanıcının bütün verisini
/// tutan dosya ise **denetimsizdi.** Bozulan bir satır sessizce düşer, yüzey
/// toplamı yine kendinden emin gösterirdi.
///
/// > ***BİR BÜTÜNLÜK DENETİMİ YANLIŞ DOSYAYA BAKIYORSA, DENETİM DEĞİL
/// > TESELLİDİR.***
///
/// ## Neden bu testler SAF — ve bu bir taviz DEĞİL
///
/// İlk denemem gerçek kabuğu render edip Progress sekmesine yürümekti.
/// **`B5` çarptı:** `google_fonts` testte `fonts.gstatic.com`a gidiyor,
/// düşüyor, kabuk hiç çizilmiyor. O karar kurucuda ve etrafından
/// DOLANMADIM — bunun yerine hüküm `ContentRepository.readHistoryStatus`a
/// taşındı ve burada **gerçek dosyalarla** sınanıyor.
/// Bu, `buildFreeSessionRecord` ve `buildFinishedState`in kurduğu emsalin
/// üçüncü uygulaması: ürün kararı ekranın içinde saklanmaz.
///
/// ⛔ **Bu testlerin KANITLAMADIĞI şey — adıyla:** kabuğun bu hükmü gerçekten
/// ÇAĞIRDIĞI. Onu ancak render eden bir test kanıtlar ve o yol `B5` açılana
/// kadar kapalı. Bugün çağrının doğruluğu **tek satırlık ve gözle
/// okunabilir** durumda (`gravita_app.dart`), ama bu bir ölçüm değildir ve
/// öyle sayılmıyor.
void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('g211'));
  tearDown(() => tmp.deleteSync(recursive: true));

  SessionStore store(String ad, String icerik) {
    final File f = File('${tmp.path}/$ad');
    f.writeAsStringSync(icerik);
    return JsonlSessionStore(f);
  }

  /// Üç ayrı bozulma sınıfı — üçü de "çözülemedi" sayılmalı.
  const String bozukUcSatir = '{bu json değil\n'
      '{"schemaVersion":999,"lessonId":"x"}\n'
      '{"schemaVersion":2}\n';

  test('SERBEST kovadaki bozulma kayıp SAYILIYOR — ders kovası tertemizken',
      () async {
    // Kusur tam olarak burada saklanıyordu: sağlam dosyaya bakıp
    // "her şey yolunda" demek.
    final HistoryStatus s = await ContentRepository.readHistoryStatus(
      lessons: store('sessions.jsonl', ''),
      free: store('free_sessions.jsonl', bozukUcSatir),
    );

    expect(s, isA<HistoryPartial>(),
        reason: 'Bu üründe her seans serbest seans — kayıp TAM O KOVADA olur. '
            'Yalnız ders kovasına bakan bir denetim hiçbir zaman ötmez.');
    expect((s as HistoryPartial).unreadableRecords, 3);
  });

  test('DERS kovasındaki bozulma da sayılıyor — eski davranış KAYBOLMADI',
      () async {
    // ⚠️ Düzeltme "ders kovasını bırak, serbeste geç" DEĞİL. İkisi de sayılır;
    // bu test eski yarının düşmediğini kanıtlıyor.
    final HistoryStatus s = await ContentRepository.readHistoryStatus(
      lessons: store('sessions.jsonl', bozukUcSatir),
      free: store('free_sessions.jsonl', ''),
    );

    expect((s as HistoryPartial).unreadableRecords, 3);
  });

  test('İKİ kovada da bozulma varsa kayıplar TOPLANIR', () async {
    final HistoryStatus s = await ContentRepository.readHistoryStatus(
      lessons: store('sessions.jsonl', bozukUcSatir),
      free: store('free_sessions.jsonl', '{yine bozuk\n'),
    );

    expect((s as HistoryPartial).unreadableRecords, 4,
        reason: 'Kullanıcının TEK bir geçmişi var; iki dosya bizim iç '
            'ayrımımız. Yalnız birini raporlamak kaybı küçük gösterirdi.');
  });

  /// ⭐ POZİTİF İKİZ — bu olmadan üstteki üç test, hüküm HER ZAMAN
  /// `HistoryPartial` dönse de geçerdi. *"0 kusur" en kolay sahtelenen sayıdır.*
  test('POZİTİF İKİZ: iki kova da sağlamsa kayıp beyanı YOK', () async {
    final HistoryStatus s = await ContentRepository.readHistoryStatus(
      lessons: store('sessions.jsonl', ''),
      free: store('free_sessions.jsonl', ''),
    );

    expect(s, isA<HistoryOk>(),
        reason: 'Sağlam iki kovada uyarı çıkarsa, üsttekiler kusuru değil '
            'sabit bir uyarıyı ölçüyor olurdu.');
  });

  /// Dosyalar HİÇ yokken: ilk açılış "kayıp geçmiş" DEĞİLDİR.
  test('dosya hiç yoksa kayıp 0 — yeni kullanıcıya "geçmişin eksik" denmez',
      () async {
    final HistoryStatus s = await ContentRepository.readHistoryStatus(
      lessons: JsonlSessionStore(File('${tmp.path}/yok1.jsonl')),
      free: JsonlSessionStore(File('${tmp.path}/yok2.jsonl')),
    );

    expect(s, isA<HistoryOk>());
  });

  /// H-20/21 (2026-08-16) — SATIR-İÇİ bozulma üsttekilerde tam korumalı,
  /// ama `JsonlSessionStore._readAll()` (pinli `motion_core`) İKİ DOSYA-
  /// GENELİ hatayı KENDİSİ yakalamaz — bilerek: kendi paketinin testi
  /// (`session_store_test.dart`) bunun `FileSystemException` fırlatmasını
  /// BEKLENEN davranış sayar. Bugün çökmüyoruz çünkü BU çağıranın
  /// `on Object` yakalayıcısı depoyla ARANIN olmadığı bu iki hatayı da
  /// örtüyor — ama bu ÖRTÜK bir sözleşme, hiçbir testte adı yok. Silahsız
  /// bir sözleşme bir gün dar bir catch'e sessizce kaybolabilir
  /// (H-25 sınıfı: "kusur bulamamak sonuç değil, korumasızlık kusurdur").
  group('DOSYA-GENELİ hatalar (depo katmanı korumasız, YALNIZ bu çağıran '
      'korur — H-20/21 regresyon kilidi)', () {
    test('sessions.jsonl yerine bir DİZİN varsa — çökmeden HistoryUnavailable',
        () async {
      Directory('${tmp.path}/sessions.jsonl').createSync(recursive: true);

      final HistoryStatus s = await ContentRepository.readHistoryStatus(
        lessons: JsonlSessionStore(File('${tmp.path}/sessions.jsonl')),
        free: store('free_sessions.jsonl', ''),
      );

      expect(s, isA<HistoryUnavailable>(),
          reason: 'Depo `FileSystemException` fırlatır (kasten — pinli '
              'pakette ölçüldü); bu test yalnız BU çağıranın onu yakaladığını '
              'sabitliyor. Kayıp SESSİZ değil, "unavailable" adıyla görünür.');
    });

    test('free_sessions.jsonl geçersiz UTF-8 bayt dizisi taşıyorsa — '
        'çökmeden HistoryUnavailable', () async {
      File('${tmp.path}/free_sessions.jsonl').writeAsBytesSync(
          <int>[0x7B, 0x22, 0x76, 0x22, 0xFF, 0xFE, 0x80, 0x0A]);

      final HistoryStatus s = await ContentRepository.readHistoryStatus(
        lessons: store('sessions.jsonl', ''),
        free: JsonlSessionStore(File('${tmp.path}/free_sessions.jsonl')),
      );

      expect(s, isA<HistoryUnavailable>(),
          reason: '`readAsString()` sıkı UTF-8 çözer; bozuk bayt satır-içi '
              'kusur DEĞİL, dosya-geneli bir okuma hatasıdır ve satır-bazlı '
              'try/catch\'in erişemediği yerde (dosya okumanın kendisinde) '
              'fırlar.');
    });
  });
}
