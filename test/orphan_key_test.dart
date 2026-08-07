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

  test('KATALOG katmanında PROSE taşıyan anahtar öksüz kalamaz', () {
    // ⭐ KATMAN sorusu (koordinatör aktarımı): *"kapı yazarken ilk soru
    // 'hangi kelimeler' değil, 'hangi KATMANLAR'."* Öksüz-anahtar kapım
    // yalnız `library.json`a bakıyordu — oysa terfi `content/catalog/*`ten
    // besleniyor ve J-129 riski ORADA da var.
    //
    // Ölçüldü: katalogda **`cues`** anahtarı 31/31 harekette duruyor ve
    // ~150 satır KULLANICI KOÇLUK METNİ taşıyor (`setup` · `during` ·
    // `success`). **Hiçbir parser okumuyor, hiçbir ekran çizmiyor.**
    //
    // Yanlış DEĞİL — ama `cues.during` tam da ürünün *"canlı seansta hiçbir
    // ipucu ekranda görünmüyor"* dediği şey. Yani içerik hazır, yol yok.
    // Bu meşru bir hazırlık havuzudur (katalogun kendisi gibi) — ama
    // BEYAN EDİLMİŞ olmalı, sessizce öksüz değil.
    //
    // ⚠️ Kapı DAR tutuluyor: yalnız PROSE taşıyan anahtarlar. Bütün
    // anahtarları taramak sahte alarm üretirdi, çünkü `phases`/`via`/`axis`
    // gibi yapılar sarmalayıcısıyla birlikte DİNAMİK okunuyor ve kaynak
    // taraması onları göremiyor. Fazla geniş bir kapı, doğru şeyi öldürür
    // (ters-ikiz dersi) — o yüzden kapsam kasten dar.
    const Map<String, String> proseKeys = <String, String>{
      // Motor/ürün tarafından OKUNAN prose
      'cue': 'MovementConfig.formErrors[].cue → hareket sayfası',
      'label': 'MovementConfig.formErrors[].label → hareket sayfası',
      'measured': 'measurementContract → promote_library → dürüstlük kutusu',
      'notMeasured': 'measurementContract → promote_library → kalıcı sınırlar',
      'name': 'MovementConfig.name → displayName',
      'aliases': 'library.json aliases → Library araması',
      'warnings': 'safety.warnings → hareket sayfası (kırpılamaz)',
      'rationale': 'precondition.rationale → iç kayıt (name_preconditions)',
      // OKUNMAYAN — beklediği yüzey ADIYLA
      'setup': 'ÖKSÜZ: kurulum ipuçları — kalibrasyon sihirbazı inşa edilmedi',
      'during': 'ÖKSÜZ: canlı koçluk ipuçları — canlı seansta cue yolu YOK '
          '(ürün bunu zaten dürüstlük kutusunda BEYAN ediyor)',
      'success': 'ÖKSÜZ: seans-sonu ipuçları — deneme özeti ekranı '
          '(tasarım `attempt`) inşa edilmedi',
      'notes': 'ÖKSÜZ: kamera kurulum notu — kalibrasyon sihirbazı yok',
    };

    final RegExp internal = RegExp(r'_tr$|Rationale$|Note$|note$');
    final Set<String> found = <String>{};
    void walk(Object? node, [String? key]) {
      if (node is Map) {
        node.forEach((Object? k, Object? v) => walk(v, k! as String));
      } else if (node is List) {
        for (final Object? v in node) {
          walk(v, key);
        }
      } else if (node is String && key != null) {
        if (key.startsWith('_') || key.startsWith(r'$')) return;
        if (internal.hasMatch(key)) return;
        if (node.split(' ').length >= 3 &&
            node.isNotEmpty &&
            node[0].toUpperCase() == node[0]) {
          found.add(key);
        }
      }
    }
    for (final FileSystemEntity d
        in Directory('content/catalog').listSync()) {
      if (d is! Directory) continue;
      for (final FileSystemEntity f in d.listSync()) {
        if (f is File && f.path.endsWith('.json')) {
          walk(jsonDecode(f.readAsStringSync()));
        }
      }
    }

    final List<String> undeclared =
        found.where((String k) => !proseKeys.containsKey(k)).toList()..sort();
    expect(undeclared, isEmpty,
        reason: 'KATALOGDA beyansız prose anahtarı: $undeclared. Kullanıcı '
            'metni taşıyan her anahtar ya bir tüketiciye bağlı olmalı ya da '
            'beklediği yüzeyi ADIYLA beyan etmeli (J-129 · katman sorusu).');
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

    // ⚠️ YASAK KOŞULLU — ve bu bir DÜZELTMENİN ürünü.
    //
    // İlk hâli bu iki cümleyi **sonsuza dek** yasaklıyordu. Ama tempoyu
    // yüzeye çıkarmak DOĞRU bir ürün ilerlemesi; o gün geldiğinde iddiayı
    // geri eklemek gerekecek ve bu test **kırmızı yanacaktı** — yani
    // kırmızı bir KUSURU değil, bir KORUMAYI gösterecekti. *"Terfi
    // sırasında kırmızı yanan şey kusur değil koruma olur"* riski.
    //
    // Doğrusu: iddia, onu ÇİZEN yüzey VARSA serbesttir. Kural bu; "tempo
    // yasak" bir OLGU'ydu, ve olgular ürün ilerledikçe değişir.
    final String liveScreen =
        File('lib/app/live_session_screen.dart').readAsStringSync();

    for (final (String claim, String surfaceKey, String why)
        in <(String, String, String)>[
      ('and tempo on', 'tempoKey', 'tempo hiçbir ekranda çizilmiyor'),
      ('which depth actually counts', 'shallowCueKey',
          'sığ-tekrar için canlı cue yolu yok'),
    ]) {
      final bool surfaced = liveScreen.contains(surfaceKey);
      if (surfaced) continue; // Yüzey geldi → iddia meşru.
      expect(prose.contains(claim), isFalse,
          reason: 'YÜZEYSİZ iddia hayatta: "$claim" — $why. Ya iddiayı '
              'kaldır, ya da onu çizen yüzeyi ekleyip anahtarını '
              '`$surfaceKey` olarak adlandır; o zaman bu kapı kendiliğinden '
              'susar.');
    }
  });

  test('TERS İKİZ: yasak KOŞULLU — yüzey gelince kapı susuyor', () {
    // ⚠️ Üstteki kapı, koşulu hiç okumasa da (yani yasak MUTLAK olsa da)
    // bugün geçerdi — çünkü yüzey bugün YOK. Bu ikiz, koşulun gerçekten
    // okunduğunu kanıtlıyor: kapı, kaynağa bakmadan karar veremiyor.
    //
    // Olmadan: "yasak koşullu" bir yorum satırı olurdu, bir davranış değil.
    final String src = File('test/orphan_key_test.dart').readAsStringSync();
    expect(src.contains('if (surfaced) continue;'), isTrue,
        reason: 'Yasak MUTLAK hâle dönmüş — tempo yüzeye çıktığı gün doğru '
            'ürün ilerlemesi kırmızı yanacak.');
    expect(src.contains("File('lib/app/live_session_screen.dart')"), isTrue,
        reason: 'Kapı yüzey kaynağını hiç okumuyor: koşul ölü.');
  });
}
