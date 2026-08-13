import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/library_model.dart';
import 'package:gravita_engine/gravita_engine.dart';

/// **AÇIK BEYAN EDİLEN HER HAREKET GERÇEKTEN BAŞLATILABİLİYOR MU?**
///
/// `A4`ün yürüyüş yarısı. `tools/dead_end_census.py` içerik tarafını sayar
/// (payda 31 = beyan-açık 2 ⊎ çıkmaz 29); bu dosya **beyanın karşılığı var
/// mı** diye sorar.
///
/// ## Neden ayrı bir ölçüm — ve neden Dart'ta
///
/// Sayım *"kaç hareket açık BEYAN EDİLDİ"*i söyler. *"Kaç hareket
/// BAŞLATILABİLİYOR"* başka bir sorudur ve cevabı JSON'da değil **widget
/// ağacında** yaşar.
///
/// > ***BİR ÖLÇÜMÜ ASIL YAŞAYACAĞI YERİN DIŞINDA KURMAK, ÖLÇÜLEN ŞEYİ DEĞİL
/// > PROXY'Yİ ÖLÇMEKTİR*** — bu hattın `G-199`'da ödediği bedel: montaj
/// > kanalını python probuyla saymıştım, prob **4** dedi, gerçek yerinde
/// > **7** çıktı.
///
/// ## ⛔ BUGÜN ÖLÇÜLEN AYRIŞMA (G-202)
///
/// Ürün **iki** hareketi *"open for live rep counting"* diye ilan ediyor
/// (Today ekranı ve Library sayacı). Ama canlı seansa **tek giriş** var —
/// kabuktaki seans düğmesi — ve o düğme `ContentRepository.liveConfig`i
/// açıyor; `liveConfig` ise **İLK** uygun hareketi döndürüp `return` ediyor.
/// `movement_page.dart` hiçbir başlatma eylemi taşımıyor.
///
/// ⇒ `push_up` **AÇIK etiketli ama başlatılamayan** bir çıkmazdır:
/// taksonominin **B sınıfı** (*içerik VAR, bağlı DEĞİL*) — ve B, taksonomide
/// **hattın kapattığı** iki sınıftan biri.
///
/// 🛑 **DÜZELTMENİN BİÇİMİ KOORDİNATÖRE SORULDU, tek başıma seçmedim:**
/// hareket sayfasına düğme koymak *yeni bir görünür öğe* (tasarım yönü,
/// M-F-77) · kabuk düğmesini bağlam duyarlı yapmak *davranış değişikliği*.
/// İkisi de savunulabilir ⇒ gerçek çatal. **Kusur kesin, biçimi değil.**
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Bugün ölçülmüş borç — **taban, envanter DEĞİL.**
  ///
  /// ⚠️ İki ZORUNLU şerh (Lissom M-F-577, elle küme kuralının borç hâli):
  /// · Bu küme bir **ALT SINIRDIR, tam envanter DEĞİLDİR.**
  /// · Buraya ekleme yapmak **envanter güncellemesi değil, KONTROLÜN TABANINI
  ///   YÜKSELTMEKTİR** — yani bir kusuru kabullenmektir, kaydetmek değil.
  const Set<String> bilinenUlasilamaz = <String>{'push_up'};

  Future<ContentRepository> yukle(WidgetTester tester) async {
    late ContentRepository c;
    await tester.runAsync(() async => c = await ContentRepository.load(rootBundle));
    return c;
  }

  testWidgets('beyan-açık ⊇ başlatılabilir; fark ADIYLA ve BÜYÜMÜYOR',
      (WidgetTester tester) async {
    final ContentRepository c = await yukle(tester);

    final Set<String> beyanAcik = c.catalogue.movements
        .where((MovementEntry m) => m.isLive)
        .map((MovementEntry m) => m.id)
        .toSet();

    // ⚠️ VAKUM: beyan-açık boşsa aşağıdaki fark denetimi **tanım gereği**
    // geçer ve "0 ulaşılamaz" diye okunur. *"0 kusur" en kolay sahtelenen
    // sayıdır* — payda önce kanıtlanır.
    expect(beyanAcik, isNotEmpty,
        reason: 'VAKUM: hiç canlı hareket bulunamadı; fark ölçümü anlamsız');

    // Ürünün TEK canlı girişi. Bir küme değil, tek bir config döner —
    // ölçülen şey tam olarak budur.
    final MovementConfig? giris = c.liveConfig;
    final Set<String> ulasilabilir =
        giris == null ? <String>{} : <String>{giris.id};

    // ⭐ POZİTİF İKİZ (M-F-194): giriş HİÇ yoksa fark = beyanAcik olurdu ve
    // test "borç büyüdü" diye kırmızı yanardı — doğru yön, ama YANLIŞ SEBEP.
    // Bu beklenti, kırmızının sebebini ayırt edilebilir kılıyor.
    expect(ulasilabilir, isNotEmpty,
        reason: 'Ürünün canlı seansa HİÇ girişi yok — bu, ulaşılamazlık '
            'borcundan farklı ve daha ağır bir kusurdur');

    final Set<String> ulasilamaz = beyanAcik.difference(ulasilabilir);

    // ALT KÜME — eşitlik DEĞİL. `G-197`'de bu hat kendi kapısını tam da
    // eşitlikle sınadığı için kırdı: borç DÜŞTÜĞÜNDE kapı kırmızı olmuştu.
    //
    // > ***BİR KAPI KENDİ ÜRÜNÜNÜN İLERLEMESİNİ CEZALANDIRIYORSA ÜRÜNÜN
    // > DÜŞMANIDIR.***
    expect(ulasilamaz.difference(bilinenUlasilamaz), isEmpty,
        reason: 'YENİ ulaşılamaz hareket doğdu — "açık" ilan edilip '
            'başlatılamayan bir hareket, ürünün kendi beyanını yalanlar');

    if (ulasilamaz.length < bilinenUlasilamaz.length) {
      // ignore: avoid_print
      print('⭐ BORÇ ÖDENDİ — ulaşılamaz ${bilinenUlasilamaz.length} → '
          '${ulasilamaz.length}. `bilinenUlasilamaz` tabanı DARALTILMALI: '
          '${bilinenUlasilamaz.difference(ulasilamaz)}');
    }

    // Ölçümün kendisi her koşumda BASILIYOR — bir sayı, yalnız yazıldığında
    // okunur. (Bu hattın `5.10` kuralı: düşen şeyin adı kayda geçmezse
    // çalışan hâli de gömülür.)
    // ignore: avoid_print
    print('BAŞLATILABİLİRLİK — beyan-açık ${beyanAcik.length} '
        '(${beyanAcik.join(", ")}) · ulaşılabilir ${ulasilabilir.length} '
        '(${ulasilabilir.join(", ")}) · ulaşılamaz ${ulasilamaz.length} '
        '(${ulasilamaz.join(", ")})');
  });

  testWidgets('canlı giriş TEK config döndürür — çokluk İDDİA EDİLMİYOR',
      (WidgetTester tester) async {
    final ContentRepository c = await yukle(tester);

    // Bu, `liveConfig`in YAPISAL gerçeği: bir liste değil, bir config.
    // Test bunu *şikâyet* olarak değil **kayıt** olarak tutuyor — biçim
    // değişirse (ör. `liveConfigs` çoğul olursa) burası derlenmez ve
    // ulaşılabilirlik ölçümü yeniden düşünülür.
    //
    // > ***BİR ÖZ-TEST ÜRÜNÜN BİÇİMİNE ÇAPALANIR, İÇERİĞİNE DEĞİL.***
    final MovementConfig? giris = c.liveConfig;
    expect(giris, isNotNull,
        reason: 'canlı giriş yok — kabuktaki seans düğmesi hiç çizilmez');
    expect(c.catalogue.movements.where((MovementEntry m) => m.isLive).length,
        greaterThanOrEqualTo(1));
  });
}
