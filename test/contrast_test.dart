import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/theme.dart';

/// WCAG 2.2 kontrast nöbeti — **görünmeyen bir dürüst hâl, susmakla aynı şey.**
///
/// ## Neden bu dosya var (J-114 aktarımı, 2026-08-07)
///
/// JabLab dürüst hâllerinin görsel ayrımını kurduktan sonra kendi işini ölçtü
/// ve *"analiz hiç yok"* kovasının ikonunu **1.80:1** buldu — WCAG 1.4.11'in
/// metin-dışı eşiği 3.0. İkon pratikte GÖRÜNMÜYORDU, üstelik en sık görülecek
/// hâllerden birindeydi. Testi bunu göremedi çünkü *"üç renk birbirinden
/// farklı"* diye ölçüyordu: `Color` **kimliğini**. Üç renk gerçekten
/// farklıydı; biri sadece görünmüyordu.
///
/// Bu, bu hattın kendi iki bulgusunun aynı ailesi: `Parallel_bars` (ham
/// anahtar) ve solgun "Start" düğmesi — **varlığı sınayan test görünürlüğü
/// sınamaz.** Ve solgun düğme, bu sınıfın burada BİR KEZ gerçekleştiğinin
/// kanıtı; o zaman gözle yakalanmıştı, şimdi ölçülüyor.
///
/// ## İki yöntem kuralı (JabLab'dan aktarıldı)
///
/// 1. **Kontrast, ekranda GERÇEKTEN oluşan renkten hesaplanır.** Yarı saydam
///    bir rengin kendi parlaklığını ölçmek, ölçülmeyen bir pikseli ölçmektir.
///    Bu yüzden [_over] alfayı zemine bindirir.
/// 2. **Eşik İCAT DEĞİL:** WCAG dış standart, formül standardın kendisi
///    (relative luminance + `(L1+0.05)/(L2+0.05)`).
///
/// ## Bu kapının SINIRI — bilerek dar
///
/// WCAG kontrastı *"bu iki renk ayırt edilebilir mi"* sorusunu **ÖLÇMEZ**,
/// luminans ölçer. Yani burası **görünürlüğü** kapatır, **ayırt
/// edilebilirliği** değil; ikincisi göz işidir ve bu dosyanın iddiası değil.
void main() {
  // `GravitaType.*` google_fonts'a dokunuyor ve o da asset bundle istiyor —
  // binding olmadan varsayılan-renk testi çöker (kontrast değil, altyapı).
  TestWidgetsFlutterBinding.ensureInitialized();

  /// WCAG 2.2 bağıl parlaklık.
  double luminance(Color c) {
    double ch(double v) =>
        v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  double contrast(Color a, Color b) {
    final double la = luminance(a);
    final double lb = luminance(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// [fg]'yi [bg] üstüne alfasıyla bindirir — ekranda oluşan GERÇEK renk.
  Color over(Color fg, Color bg, double alpha) => Color.fromARGB(
        255,
        ((fg.r * alpha + bg.r * (1 - alpha)) * 255).round(),
        ((fg.g * alpha + bg.g * (1 - alpha)) * 255).round(),
        ((fg.b * alpha + bg.b * (1 - alpha)) * 255).round(),
      );

  // ── Ekranda GERÇEKTEN oluşan zeminler ─────────────────────────────────
  //
  // `GravitaCard` beyaz bir gradyanı sayfa zeminine bindiriyor (0.56 → 0.28).
  // KOYU metin için EN KÖTÜ hâl gradyanın ALT ucudur (zemin en koyu orada),
  // o yüzden nöbet hep alt ucu ölçer — ortalamayı değil.
  final Color cardBottom =
      over(const Color(0xFFFFFFFF), GravitaColors.page, 0.28);
  final Color sealedBottom =
      over(const Color(0xFFFAE7E5), GravitaColors.page, 0.70);
  final Color scoringBox =
      over(GravitaColors.honestySeal, sealedBottom, 0.05);

  /// Normal metin (WCAG 1.4.3 AA). Bu üründe ölçüm-dili mono ve KÜÇÜK
  /// (10-12pt) — "büyük metin" muafiyeti (18pt) buraya HİÇ uygulanmaz.
  const double textMin = 4.5;

  /// Metin-dışı: ikon, kenarlık, durum göstergesi (WCAG 1.4.11).
  const double nonTextMin = 3.0;

  void expectText(String what, Color fg, Color bg) {
    final double r = contrast(fg, bg);
    expect(r >= textMin, isTrue,
        reason: '$what → ${r.toStringAsFixed(2)}:1 (metin eşiği $textMin). '
            'Görünmeyen bir dürüst hâl, susmakla aynı şeydir.');
  }

  void expectNonText(String what, Color fg, Color bg) {
    final double r = contrast(fg, bg);
    expect(r >= nonTextMin, isTrue,
        reason: '$what → ${r.toStringAsFixed(2)}:1 (metin-dışı eşiği '
            '$nonTextMin, WCAG 1.4.11)');
  }

  group('WCAG — açık yüzeyler', () {
    test('METİN tokenleri her gerçek zeminde eşiği geçiyor', () {
      for (final (String name, Color c) in <(String, Color)>[
        ('ink', GravitaColors.ink),
        ('inkMuted', GravitaColors.inkMuted),
        ('textSecondary', GravitaColors.textSecondary),
        ('accent', GravitaColors.accent),
        ('honestySeal', GravitaColors.honestySeal),
        ('honestyText', GravitaColors.honestyText),
      ]) {
        expectText('$name / sayfa', c, GravitaColors.page);
        expectText('$name / kart-alt', c, cardBottom);
        expectText('$name / mühür-alt', c, sealedBottom);
        expectText('$name / scoring kutusu', c, scoringBox);
      }
    });

    test('textTertiary METİN eşiğini GEÇMEZ — bu yüzden non-text tokenidir', () {
      // ⚠️ Bu test bir KISITI sabitliyor, bir doğruyu değil. `#7A6C69` sayfa
      // zemininde 4.40, mühür kartında 4.26 veriyor — ikisi de 4.5'in
      // ALTINDA. Token silinmedi çünkü ikon/kenarlıkta MEŞRU; ama METİN
      // olarak kullanılırsa kusur geri gelir.
      //
      // Nöbet ters yönde: gün gelip renk metin eşiğini geçerse bu test öter
      // ve o zaman `theme.dart`taki "metin için kullanma" uyarısı BAYAT olur.
      expect(contrast(GravitaColors.textTertiary, GravitaColors.page) < textMin,
          isTrue,
          reason: 'textTertiary artık metin eşiğini geçiyor — theme.dart\'taki '
              '"METİN İÇİN KULLANMA" uyarısı gözden geçirilmeli.');
      // Ama ikon olarak GEÇMELİ, yoksa hiçbir yerde kullanılamaz.
      expectNonText('textTertiary ikon / kart-alt', GravitaColors.textTertiary,
          cardBottom);
      expectNonText('textTertiary ikon / mühür-alt',
          GravitaColors.textTertiary, sealedBottom);
    });

    test('rozet (pill) — dolgu ZEMİNİ üstünde etiket okunuyor', () {
      // Pill dolgusu `tone.withValues(alpha: 0.1)`; etiket AYNI tonun tam
      // hâli. Etiketin kendi dolgusuyla arasındaki kontrast ölçülmeli —
      // sayfa zeminiyle değil.
      for (final (String name, Color tone) in <(String, Color)>[
        ('accent (OPEN)', GravitaColors.accent),
        ('textSecondary (MEASURING)', GravitaColors.textSecondary),
        ('honestySeal (LOCKED)', GravitaColors.honestySeal),
      ]) {
        expectText('$name pill etiketi', tone, over(tone, cardBottom, 0.10));
      }
    });
  });

  group('WCAG — KOYU seans yüzeyi', () {
    test('koyu zeminde metin eşiği geçiliyor', () {
      expectText('sessionInkOnDark / sahne', GravitaColors.sessionInkOnDark,
          GravitaColors.sessionStage);
      expectText('sessionInkOnDark / kamera', GravitaColors.sessionInkOnDark,
          GravitaColors.sessionCamera);
      // ⚠️ Bu token bir DÜZELTMENİN ürünü: açık-zemin tokenleri koyu zeminde
      // ters çevrilerek kullanılamıyor — ölçüldü, `textTertiary` 3.37 ve
      // `textSecondary` 2.88 veriyordu, ikisi de eşik ALTI.
      expectText('sessionInkMutedOnDark / kamera',
          GravitaColors.sessionInkMutedOnDark, GravitaColors.sessionCamera);
      expectText('sessionInkMutedOnDark / sahne',
          GravitaColors.sessionInkMutedOnDark, GravitaColors.sessionStage);
    });
  });

  group('KAPSAM — kapı örneği mi tokenı mı ölçüyor', () {
    // ⚠️ Bu grup, koordinatörün sorusunun ve JabLab J-116'nın ürünü.
    //
    // J-116: JabLab bir ikonu düzeltip "kapandı" dedi; aynı renk BİR DOSYA
    // ÖTEDE altyazıda duruyordu ve en ağırı `JText.mono`nun VARSAYILANIYDI —
    // paylaşılan token, yani mono'yu çıplak kullanan HER yüzey. Kendi
    // cümlesi: *"örüntüyü değil örneği düzeltmişim."*
    //
    // Bende `mono` varsayılanı ZATEN düzeltilmişti (G-137) — ama kapının
    // kendisi hâlâ ELLE SAYILMIŞ bir token listesine bakıyordu: 17 token
    // tanımlıyken 7'si ölçülüyordu. Yani kapı da örnek düzeyindeydi.
    // Aşağıdaki üç test bunu kapatıyor.

    test('theme.dart\'taki HER renk tokeni sınıflandırılmış', () {
      // Kaynak taraması burada MEŞRU: sorulan şey davranış değil KAPSAM —
      // "ölçmediğim bir token var mı". Yeni bir token eklendiği gün bu test
      // öter ve ekleyeni bir KARAR vermeye zorlar: metin mi, metin-dışı mı,
      // yoksa zemin mi. Sessizce ölçülmeden kalamaz.
      final RegExp decl =
          RegExp(r'static const Color (\w+) =', multiLine: true);
      final Set<String> declared = decl
          .allMatches(File('lib/app/theme.dart').readAsStringSync())
          .map((RegExpMatch m) => m.group(1)!)
          .toSet();

      // Testin kendi kayıt defteri — her token ÜÇ kovadan birinde olmalı.
      const Set<String> asText = <String>{
        'ink', 'inkMuted', 'textSecondary', 'accent', 'accentHover',
        'honestySeal', 'honestyText', 'sessionInkOnDark',
        'sessionInkMutedOnDark',
        // `GravitaType` varsayılanları — palet tokeni değil, ONLARA işaret
        // eden takma adlar; yine de METİN olarak ölçülüyorlar (yukarıdaki
        // varsayılan testi). Kapı bunları da istedi ve bu doğru: regex'i
        // daraltıp "şu sınıfın dışındakine bakma" demek, kapsam kapısının
        // kendisine muafiyet açmak olurdu.
        'defaultDisplayColor', 'defaultBodyColor', 'defaultMonoColor',
      };
      const Set<String> asNonText = <String>{'textTertiary', 'hairline'};
      const Set<String> asSurface = <String>{
        'page', 'surfaceTop', 'surfaceBottom', 'sessionStage',
        'sessionStageDeep', 'sessionCamera', 'sessionSheetSealed',
      };

      final Set<String> classified = <String>{
        ...asText, ...asNonText, ...asSurface
      };
      expect(declared.difference(classified), isEmpty,
          reason: 'theme.dart\'ta SINIFLANDIRILMAMIŞ token var — kontrast '
              'kapısı onu ölçmüyor. Metin mi, ikon mu, zemin mi: karar ver '
              've bu listeye ekle. (J-116: örüntüyü düzelt, örneği değil.)');
      expect(classified.difference(declared), isEmpty,
          reason: 'Listede olan ama theme.dart\'ta OLMAYAN token — kayıt '
              'defteri bayatlamış.');
    });

    test('GravitaType VARSAYILANLARI eşiği geçiyor — çıplak çağrı güvenli', () {
      // J-116'nın en ağır bulgusu buydu: paylaşılan bir tip yardımcısının
      // VARSAYILAN rengi eşik altındaysa, rengi elle vermeyen her çağıran
      // sessizce kusurlu olur. Kusurun varsayılan olması en kolay çoğalma
      // yolu — o yüzden varsayılan AYRI sınanıyor, tokenlardan bağımsız.
      // ⚠️ `GravitaType.mono()` ÇAĞRILMIYOR ve bu bilinçli: o çağrı
      // `google_fonts`a gidiyor, fontlar paketlenmediği için ağ deniyor ve
      // bu makinenin önbelleğine bağımlı hâle geliyor (G-126 — açık kök,
      // burada İKİNCİ kez ısırdı). Varsayılan renk zaten ayrı bir sabit ve
      // yardımcılar `color ?? <sabit>` diyor: bağ YAPISAL, o yüzden sabiti
      // ölçmek çağrının aldığı rengi ölçmektir.
      for (final (String name, Color c) in <(String, Color)>[
        ('mono()', GravitaType.defaultMonoColor),
        ('body()', GravitaType.defaultBodyColor),
        ('display()', GravitaType.defaultDisplayColor),
      ]) {
        expectText('GravitaType.$name varsayılanı / sayfa', c,
            GravitaColors.page);
        expectText('GravitaType.$name varsayılanı / kart-alt', c, cardBottom);
        expectText('GravitaType.$name varsayılanı / mühür-alt', c,
            sealedBottom);
      }

      // Yapısal bağın GERÇEKTEN kurulu olduğunu kaynak üzerinden doğrula:
      // biri `color ?? GravitaColors.xxx` diye geri yazarsa sabit atlanır
      // ve yukarıdaki ölçüm sessizce anlamsızlaşır.
      final String theme = File('lib/app/theme.dart').readAsStringSync();
      for (final String d in <String>[
        'color ?? defaultDisplayColor',
        'color ?? defaultBodyColor',
        'color ?? defaultMonoColor',
      ]) {
        expect(theme.contains(d), isTrue,
            reason: 'GravitaType varsayılanı sabitten KOPMUŞ ($d) — kontrast '
                'ölçümü artık gerçek çağrıyı temsil etmiyor.');
      }
    });

    test('YERİNDE tanımlanmış renk YOK — kapının dışında zemin kalamaz', () {
      // ⭐ J-126 aktarımının yapısal hâli. JabLab kontrast kapısının token
      // varsayılanlarını ölçtüğünü, ama yüzeylerin rengi YERİNDE geçtiğini
      // buldu — o yol kapının DIŞINDAYDI ve içinde iki canlı ihlal vardı.
      //
      // Bende ölçüldü: `live_session_screen.dart` mühürlü alt-sayfanın
      // zeminini `const Color(0xFFFFF4F3)` diye YERİNDE tanımlıyordu. Bugün
      // güvenliydi (honestyText 9.29:1) ama kapı onu HİÇ ölçmüyordu —
      // *yeşil bir kapı, bakılmayan bir alan üretir.*
      //
      // Bu test sınıfı kapatıyor: renk tanımı TEK evde (`theme.dart`)
      // olmak zorunda, çünkü kapı yalnız orayı tarayabiliyor.
      final RegExp literal = RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)');
      final List<String> offenders = <String>[];
      for (final FileSystemEntity f
          in Directory('lib/app').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.endsWith('theme.dart')) continue;
        if (literal.hasMatch(f.readAsStringSync())) offenders.add(f.path);
      }
      expect(offenders, isEmpty,
          reason: 'Yerinde tanımlanmış renk kontrast kapısının DIŞINDA kalır. '
              'theme.dart\'a token olarak taşı: ${offenders.join(", ")}');
    });

    test('mühürlü seans zemini de ölçülüyor', () {
      // Token'a terfi etmenin karşılığı: artık ölçülebiliyor.
      expectText('honestyText / mühürlü seans sayfası',
          GravitaColors.honestyText, GravitaColors.sessionSheetSealed);
      expectText('ink / mühürlü seans sayfası', GravitaColors.ink,
          GravitaColors.sessionSheetSealed);
    });

    test('HİYERARŞİ korunuyor — okunurluk uğruna feda edilmedi', () {
      // JabLab'ın ikinci kapısı, ve bende özellikle kritik: kontrastı
      // yükseltmenin ucuz yolu her şeyi en koyu tona çekmektir, o da
      // hiyerarşiyi öldürür. *"Referans YOK"* hâli 31 hareketin 30'unda
      // BASKIN ve tasarımı gereği sönük — ama sönüklüğün ALT sınırı (WCAG)
      // kadar ÜST sınırı da (hiyerarşi) artık bir sayı.
      double ratio(Color primary, Color muted, Color bg) =>
          contrast(primary, bg) / contrast(muted, bg);

      for (final (String name, Color bg) in <(String, Color)>[
        ('sayfa', GravitaColors.page),
        ('kart-alt', cardBottom),
        ('mühür-alt', sealedBottom),
      ]) {
        final double r =
            ratio(GravitaColors.ink, GravitaColors.textSecondary, bg);
        expect(r >= 2.0, isTrue,
            reason: '$name: birincil ↔ sönük ayrımı ${r.toStringAsFixed(2)}× '
                '— 2×\'in altına inerse metin okunur ama HİYERARŞİ ölür.');
      }
      final double dark = ratio(GravitaColors.sessionInkOnDark,
          GravitaColors.sessionInkMutedOnDark, GravitaColors.sessionCamera);
      expect(dark >= 2.0, isTrue,
          reason: 'koyu yüzey: ${dark.toStringAsFixed(2)}×');
    });
  });

  group('formülün kendisi doğru mu', () {
    test('bilinen değerler — kapı kendi aritmetiğini kanıtlıyor', () {
      // Ateşlenmemiş kapıya güvenilmez; ölçen kapı da ölçüsünü kanıtlamalı.
      expect(contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)),
          closeTo(21.0, 0.01));
      expect(contrast(const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)),
          closeTo(1.0, 0.001));
      // WCAG'in kendi örneği: #777777 üzerine beyaz ≈ 4.48 (4.5'i GEÇMEZ).
      expect(contrast(const Color(0xFF777777), const Color(0xFFFFFFFF)),
          closeTo(4.48, 0.02));
    });

    test('alfa bindirme GERÇEKTEN zemine bakıyor', () {
      // Aynı yarı-saydam renk, farklı zeminde farklı sonuç vermeli — vermiyorsa
      // bindirme çalışmıyordur ve bütün ölçüm sahtedir.
      final Color onLight = over(const Color(0xFF000000), const Color(0xFFFFFFFF), 0.5);
      final Color onDark = over(const Color(0xFF000000), const Color(0xFF808080), 0.5);
      expect(luminance(onLight) > luminance(onDark), isTrue);
    });
  });
}
