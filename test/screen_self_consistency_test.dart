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

  /// ⭐ G-214 — **DÜRÜSTLÜK KUTUSUNUN KENDİSİ yalan söylüyordu.**
  ///
  /// `honesty.scoring` (hareket sayfasındaki *"None of this is a score…"*
  /// kartı) şunu diyordu:
  /// > *"…and **when a rule fires we tell you what to change** — but no
  /// > number grades your form…"*
  ///
  /// Aynı sayfanın birkaç blok altı ise:
  /// > *"during a live session no cue appears on screen, so **nothing
  /// > actually tells you**."*
  ///
  /// **Tek kartta iki cümle, birbirinin tam tersi** — ve `G-212`de ölçülmüştü
  /// ki doğru olan ikincisi.
  ///
  /// 📌 Kusur `content/library.json`da DEĞİL, onu ÜRETEN
  /// `tools/promote_library.py`dedeydi; çıktı düzeltilseydi ilk `--write`ta
  /// geri gelirdi. *Üretilmiş bir metnin kusuru, üretecinde aranır.*
  testWidgets('dürüstlük kutusu, sayfanın kendi eksik-listesiyle ÇELİŞMİYOR',
      (WidgetTester tester) async {
    late ContentRepository repo;
    await tester
        .runAsync(() async => repo = await ContentRepository.load(rootBundle));

    final List<MovementEntry> canlilar = repo.catalogue.movements
        .where((MovementEntry m) => m.isLive)
        .toList(growable: false);
    expect(canlilar, isNotEmpty, reason: 'VAKUM: canlı hareket yok.');

    for (final MovementEntry m in canlilar) {
      if (!canliUyariYokBeyani(m)) continue;
      final String skor = (m.honesty.scoring ?? '').toLowerCase();
      expect(skor, isNot(contains('we tell you what to change')),
          reason: '${m.id}: dürüstlük kutusu "bir kural ateşlenince ne '
              'değiştireceğini söyleriz" diyor, ama AYNI SAYFA "hiçbir şey '
              'sana söylemiyor" diyor. Ölçüm ikincisini doğruluyor (G-212).');
    }
  });

  /// ⭐ G-213 süpürmesi — **HİÇBİR sınıf açıklaması KOÇLUK vaat etmiyor.**
  ///
  /// `classBadgeExplainer('D')` *"we **coach** your body"* diyordu. Ürün
  /// hiçbir harekette koçluk etmiyor: kural değerlendirmesi üründe hiç
  /// çağrılmıyor (`G-212`), yani kimseye bir şey söylenmiyor.
  ///
  /// ⚠️ Bu, `G-213`ün **yanlış VARLIK** sınıfı — *"yok"* derken var olan
  /// bayat cümlelerin (`G-210`) TERSİ. Yokluk kalıbı arayan süpürge bunu
  /// bulamaz; ayrı ağ gerekiyor ve bu test o ağın kalıcı hâli.
  ///
  /// 📌 `'B'` dalı bilerek DIŞARIDA: *"we count and time it but never judge
  /// its shape"* — sayma ve tempo GERÇEKTEN yapılıyor, cümle doğru. Doğru
  /// olanı da yasaklamak, ürünü hak ettiğinden kötü göstermek olurdu.
  test('sınıf açıklamaları KOÇLUK/DÜZELTME vaat etmiyor', () {
    for (final String? cls in <String?>[null, 'A', 'B', 'D', 'bilinmeyen']) {
      final String s = LibraryStrings.classBadgeExplainer(cls).toLowerCase();
      for (final String vaat in <String>[
        'we coach',
        'coaches you',
        'tell you what to change',
        'we correct',
      ]) {
        expect(s, isNot(contains(vaat)),
            reason: 'classBadgeExplainer($cls) "$vaat" vaat ediyor; ürün '
                'bunu hiçbir harekette yapmıyor (G-212).');
      }
    }
  });

  /// ⭐ G-213 süpürmesinin ÜÇÜNCÜ vakası — **Today ekranı**.
  ///
  /// `homeNoPlanBody` *"the movements **we can coach** right now"* diyordu.
  /// Ürün koçluk etmiyor; **ölçüyor**.
  ///
  /// 🪞 Ve en can alıcısı: aynı dosyanın **dört satır aşağısındaki** yorum
  /// zaten şunu kaydediyor — *"`to be coached` iddiası KALDIRILDI (yayın
  /// envanteri, J-124)"*. Yani bu düzeltme bir kez YAPILMIŞ, ama **komşu
  /// cümleye uygulanmamıştı.**
  /// > ***BİR DÜZELTMEYİ BİR CÜMLEDE YAPMAK, KOMŞUSUNDA YAPMIŞ OLMAZ*** —
  /// > `G-205`→`G-206`nın (başlık düzeltildi, kapı cümlesi kaldı) aynı şekli,
  /// > ve koordinatörün Lissom'dan aktardığı *"bir dersi bir testte uygulamak,
  /// > sonrakinde uygulamış olmaz"* kuralının metin tarafı.
  test('Today ekranı KOÇLUK vaat etmiyor — ölçtüğünü söylüyor', () {
    final String s = LibraryStrings.homeNoPlanBody.toLowerCase();
    expect(s, isNot(contains('we can coach')),
        reason: 'Ürün koçluk etmiyor (G-212: kural değerlendirmesi hiç '
            'çağrılmıyor). Aynı iddia homeOpenBody\'den J-124\'te '
            'kaldırılmıştı; komşusunda kalmış.');
    expect(s, contains('we can measure'),
        reason: 'Yasak sözcüğü silmek yetmez — ürünün GERÇEKTEN yaptığı '
            'söylenmeli, yoksa cümle anlamsızlaşır.');
  });

  /// Pozitif yön: D sınıfının AYRIMI kaybolmadı — cümle boşaltılarak da
  /// yasağı geçebilirdi, ama o zaman sınıf hiçbir şey anlatmazdı.
  test('D sınıfı hâlâ KENDİ ayrımını anlatıyor (beden ↔ ekipman)', () {
    final String d = LibraryStrings.classBadgeExplainer('D').toLowerCase();
    expect(d, contains('your body'));
    expect(d, contains('equipment'),
        reason: 'Yasak sözcüğü silmek yetmez; sınıfın ayrımı kalmalı.');
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
