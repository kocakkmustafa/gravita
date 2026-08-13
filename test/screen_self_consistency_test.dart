import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/library_model.dart';
import 'package:gravita/app/library_strings.dart';

/// ⭐ G-212 — **AYNI EKRANDAKİ İKİ CÜMLE BİRBİRİNİ ÇÜRÜTÜYOR MU?**
///
/// Koordinatör `H-10`un adını koyduğu boşluk:
/// > *"Her iki metin de çiziliyor, her iki test de yeşil, ve **hiçbir kapı bir
/// > ekrandaki İKİ CÜMLEYİ birbirine karşı okumaz.**"*
///
/// Bu dosya tam olarak onu yapıyor.
///
/// ## Kapattığı kusur
///
/// `movement_page.dart`, `m.isLive` olan her harekete
/// *"$n rules run during a session."* diyordu (squat'ta **4**, şınavda **5**).
/// Ama ölçüldü: kuralları değerlendiren API (`RepEngine.correctionFor` /
/// `topCorrection` / `repMetrics`) **üründe HİÇ ÇAĞRILMIYOR** — tek çağıran
/// `tool/replay_gate.dart`, yani KAYITLI görüntü üzerinde koşan çevrimdışı
/// kapı.
///
/// Ve aynı sayfanın *"What is missing"* bölümü zaten şunu diyordu:
/// *"during a live session no cue appears on screen, so nothing actually
/// tells you."*
/// ⇒ **Bir ekran, kendi kendini yalanlıyordu.**
///
/// Kaynak bir VEKİLDİ: `isLive` *"kurallar koşuyor"* sanıldı; oysa yalnız
/// *"tekrar sayımı açık"* demek.
/// > ***BİR HAREKETİN ÖLÇÜLÜYOR OLMASI, KURALLARININ KOŞTUĞU ANLAMINA
/// > GELMEZ.***
///
/// ## Neden bu kapı BAŞLIK değil ANLAM üzerinden kuruluyor
///
/// Dizgi eşitliği aramak kırılgan olurdu (metin değişir, kapı sessizce
/// geçerdi). Kapı bunun yerine **iki iddiayı** karşılaştırıyor:
/// içerik *"canlı seansta uyarı çıkmıyor"* diyorsa, yüzey *"kurallar seans
/// sırasında koşuyor"* DİYEMEZ.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// İçeriğin "canlı seansta sana bir şey söylenmiyor" beyanı.
  bool canliUyariYokBeyani(MovementEntry m) => m.comingSoon.any((String s) {
        final String c = s.toLowerCase();
        return c.contains('no cue appears') ||
            c.contains('nothing actually tells you');
      });

  testWidgets('canlı hareketin sayfası KENDİ KENDİNİ yalanlamıyor',
      (WidgetTester tester) async {
    late ContentRepository repo;
    await tester
        .runAsync(() async => repo = await ContentRepository.load(rootBundle));

    final List<MovementEntry> canlilar = repo.catalogue.movements
        .where((MovementEntry m) => m.isLive)
        .toList(growable: false);

    // VAKUM: canlı hareket yoksa döngü hiç dönmez ve kapı "temiz" görünürdü.
    expect(canlilar, isNotEmpty, reason: 'VAKUM: canlı hareket yok.');

    // ⚠️ Ve ikinci vakum: beyanı TAŞIYAN en az bir hareket olmalı, yoksa
    // aşağıdaki kontrol hiçbir vakada ateşlenmez.
    expect(canlilar.any(canliUyariYokBeyani), isTrue,
        reason: 'VAKUM: hiçbir canlı hareket "canlı uyarı yok" demiyor ⇒ '
            'çelişki kontrolü hiç ateşlenmez, kapı tanım gereği yeşil olur.');

    for (final MovementEntry m in canlilar) {
      if (!canliUyariYokBeyani(m)) continue;

      final int kuralSayisi =
          repo.loadedCatalog(m.catalogId)?.formErrors.length ??
              (await repo.catalogFor(m.id)).formErrors.length;
      final String yuzey =
          LibraryStrings.formErrorsBodyLive(kuralSayisi).toLowerCase();

      expect(yuzey, isNot(contains('run during a session')),
          reason: '${m.id}: içerik "canlı seansta uyarı çıkmıyor" diyor ama '
              'yüzey "kurallar seans sırasında koşuyor" diyor. Aynı ekranda '
              'iki cümle birbirini çürütüyor (H-10).');
      expect(yuzey, isNot(contains('runs during a session')),
          reason: '${m.id}: tekil hâli de aynı iddiayı taşıyor.');
    }
  });

  /// ⭐ Kuralların KOŞMADIĞI, yüzeyin de bunu SÖYLEDİĞİ — pozitif yön.
  /// Üstteki test yalnız yasak cümleyi kovalıyor; bu test doğru cümlenin
  /// gerçekten kurulduğunu istiyor, yoksa metin boşaltılarak da geçilebilirdi.
  test('canlı metin, kuralların seans sırasında KOŞMADIĞINI söylüyor', () {
    for (final int n in <int>[1, 4, 5]) {
      final String s = LibraryStrings.formErrorsBodyLive(n).toLowerCase();
      expect(s, contains('nothing checks'),
          reason: 'Yasak cümleyi silmek yetmez; yerine DOĞRU olanı koymalı.');
      expect(s, contains('recorded footage'),
          reason: 'Kurallar kayıtlı görüntüde GERÇEKTEN ateşleniyor — bunu '
              'söylememek, ürünü hak ettiğinden kötü göstermek olurdu.');
    }
  });
}
