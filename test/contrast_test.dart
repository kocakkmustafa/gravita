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
