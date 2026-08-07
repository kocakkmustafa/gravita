import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ⭐ ÖKSÜZ ANAHTAR nöbeti — J-129 aktarımı (JabLab, 2026-08-07).
///
/// ## Neden bu dosya var
///
/// JabLab `Lesson.fromJson`ın **tanımadığı anahtarı sessizce düşürdüğünü**
/// buldu: `library.json`da 10 öksüz anahtar vardı ve **ikisi YANLIŞTI** —
/// biri kendi ölçümüyle ÇÜRÜTTÜĞÜ bir iddianın üçüncü bir yerde hayatta
/// kalmış hâliydi.
///
/// > ***Okunmayan anahtar, çürütülmüş iddiaların hayatta kaldığı yerdir.***
///
/// **Bende de vardı ve aynı türdendi.** `push_foundations.goal` hiçbir
/// parser tarafından okunmuyordu ve şöyle diyordu: *"Get honest rep counting
/// and **tempo** on your push-up, and learn **which depth actually counts**."*
/// Bu gece ikisini de ölçüp `measured`dan ÇIKARMIŞTIM (`ae8a14d`): tempo
/// hesaplanıyor ama hiçbir ekran çizmiyor; sığ-tekrar kuralı fixture'da
/// ateşleniyor ama canlı seansta cue görünmüyor. İddia, okunmayan anahtarda
/// **hayatta kalmıştı.**
///
/// **Ve neden hiçbir kapı görmedi:** gecenin bütün dürüstlük turları
/// YÜZEYLERİ taradı; öksüz anahtar hiçbir yüzeyde değil. Dil nöbeti o dosyayı
/// tarıyor ama **kelimeye** bakıyor, doğruluğa değil —
/// ***yanlış ama nazik bir cümle her kapıdan geçer.***
///
/// ## Kapı tasarımı: okunan anahtarlar KAYNAKTAN türer
///
/// Tanınan anahtarların listesi ELLE TUTULMUYOR. Elle liste, doğruyu iki yere
/// yazmak olurdu ve ayrıştıkları gün kapı **sessizce yalan söylerdi** — bu
/// defterin `--self-test` sayacında ve `_surfacedClaims` defterinde
/// tekrarlanan aynı disiplin.
void main() {
  /// Bir kaynak dosyada okunan JSON anahtarlarını çıkarır.
  ///
  /// Dart tarafı `j['key']` / `m['key']`, Python tarafı `.get("key")` /
  /// `["key"]` yazıyor. Yorum satırları da taranıyor: bir anahtarı yorumda
  /// anmak onu okumak değil — ama FAZLA anahtar toplamak kapıyı yalnız
  /// GEVŞETİR, sahte alarm üretmez. Kapının hata yönü bilinçli.
  Set<String> keysReadIn(Iterable<String> paths) {
    final RegExp dart = RegExp(r"\[\s*'([A-Za-z_][\w]*)'\s*\]");
    final RegExp py = RegExp(r'''\.get\(\s*["']([A-Za-z_][\w]*)["']|\[\s*["']([A-Za-z_][\w]*)["']\s*\]''');
    final Set<String> out = <String>{};
    for (final String p in paths) {
      final File f = File(p);
      if (!f.existsSync()) continue;
      final String src = f.readAsStringSync();
      for (final RegExpMatch m in dart.allMatches(src)) {
        out.add(m.group(1)!);
      }
      for (final RegExpMatch m in py.allMatches(src)) {
        out.add((m.group(1) ?? m.group(2))!);
      }
    }
    return out;
  }

  /// `_` ya da `$` ile başlayan anahtar İÇ KAYITTIR ve bilerek okunmaz
  /// (`_why_unlocked` gerekçe defteri, `$comment` doküman). Ön ek bir
  /// BEYANDIR: "bunu kimse okumuyor ve okumamalı".
  bool declaredInternal(String key) => key.startsWith('_') || key.startsWith(r'$');

  test('library.json\'da OKUNMAYAN anahtar yok — ya okunur ya beyan edilir', () {
    final Set<String> read = keysReadIn(<String>[
      'lib/app/library_model.dart',
      'lib/app/content_repository.dart',
      'packages/gravita_engine/lib/src/progress_summary.dart',
      'tools/validate_library.py',
      'tools/promote_library.py',
    ]);

    /// Okunmayan ama BİLEREK tutulan anahtarlar — her biri GEREKÇELİ.
    ///
    /// ⚠️ Bu liste bir muafiyettir, ve muafiyet kapının kör noktasını
    /// üretir (G-134). O yüzden dar: yalnız "bir ekran bekliyor" sınıfı,
    /// ve her satır o ekranı adıyla söylüyor.
    const Map<String, String> declaredUnread = <String, String>{
      // Kurs sayfası (tasarımın `course` ekranı) İNŞA EDİLMEDİ. Bu üç alan
      // onun verisi ve orada çizilecek. Bugün hiçbir yüzeyde değiller.
      'goal': 'Kurs sayfası (tasarım `course`) inşa edilmedi',
      'estimatedMinutes': 'Kurs sayfası inşa edilmedi',
      'minutes': 'Kurs sayfası inşa edilmedi (ders süresi)',
      // Dosya kimliği — İÇERİK değil. Ürün adı ve dil kabukta SABİT
      // (`MaterialApp.title`, PRD §7 V1 yalnız `en`); buradan okumak ikinci
      // bir doğruluk kaynağı yaratırdı. `schemaVersion` ise artık OKUNUYOR:
      // öksüzken bir nöbete çevrildi (`ContentRepository.load`).
      'productName': 'dosya kimliği; ürün adı kabukta sabit',
      'language': 'dosya kimliği; V1 yalnız `en`, kabukta sabit',
    };

    final Map<String, dynamic> lib =
        (jsonDecode(File('content/library.json').readAsStringSync()) as Map)
            .cast<String, dynamic>();

    final Set<String> present = <String>{};
    void collect(Object? node) {
      if (node is Map) {
        for (final Object? k in node.keys) {
          present.add(k! as String);
          collect(node[k]);
        }
      } else if (node is List) {
        node.forEach(collect);
      }
    }
    collect(lib);

    final List<String> orphans = present
        .where((String k) => !declaredInternal(k))
        .where((String k) => !read.contains(k))
        .where((String k) => !declaredUnread.containsKey(k))
        .toList()
      ..sort();

    expect(orphans, isEmpty,
        reason: 'ÖKSÜZ ANAHTAR: $orphans — hiçbir parser okumuyor. '
            'Okunmayan anahtar, çürütülmüş iddiaların hayatta kaldığı yerdir '
            '(J-129). Ya bir tüketiciye bağla, ya `_`/`\$` ön ekiyle iç kayıt '
            'ilan et, ya da bu testteki `declaredUnread`e GEREKÇESİYLE ekle.');
  });

  test('VAKUM İKİZİ: kapı gerçekten anahtar topluyor', () {
    // ⚠️ Üstteki test, `read` kümesi yanlışlıkla HER ŞEYİ toplasaydı da
    // geçerdi — ve o hâlde kapı hiçbir şey ölçmezdi. Bu ikiz onu kapatıyor:
    // parser kaynağından GERÇEKTEN bilinen anahtarlar çıkmalı, ve
    // uydurulmuş bir anahtar çıkmamalı.
    final Set<String> read = keysReadIn(<String>[
      'lib/app/library_model.dart',
      'lib/app/content_repository.dart',
    ]);
    expect(read, contains('displayName'));
    expect(read, contains('honesty'));
    expect(read, contains('waitingOnMeasurement'));
    expect(read.contains('bu_anahtar_hicbir_yerde_yok'), isFalse);
  });

  test('okunmayan alanlarda ÇÜRÜTÜLMÜŞ iddia yok', () {
    // ⚠️ Öksüz-anahtar kapısı anahtarın OKUNUP OKUNMADIĞINI ölçer,
    // İÇERİĞİNİN doğru olup olmadığını değil. Bu ikinci kapı, bu gece
    // ölçülüp `measured`dan ÇIKARILAN iddiaların başka bir alanda hayatta
    // kalmasını engelliyor — `goal`da tam olarak bu olmuştu.
    //
    // Çürütülen üç iddia (ae8a14d): tempo GÖSTERİLMİYOR · ROM gösterilmiyor ·
    // sığ-tekrar için canlı cue YOK.
    final String prose = jsonEncode(
        (jsonDecode(File('content/library.json').readAsStringSync()) as Map)
            .cast<String, dynamic>()['movements']).toLowerCase();

    for (final (String claim, String why) in <(String, String)>[
      ('and tempo on', 'tempo hiçbir ekranda çizilmiyor (ae8a14d)'),
      ('which depth actually counts', 'sığ-tekrar için canlı cue YOK'),
    ]) {
      expect(prose.contains(claim), isFalse,
          reason: 'ÇÜRÜTÜLMÜŞ iddia hayatta: "$claim" — $why');
    }
  });
}
