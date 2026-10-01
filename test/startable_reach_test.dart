import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/library_model.dart';
import 'package:gravita_engine/gravita_engine.dart';

/// Açık hareketlerin hepsinin kendi id'siyle başlatılabilir config'i vardır.
/// `liveConfig` kabuğun tek hızlı girişidir; hareket sayfasının id'ye bağlı
/// girişini [ContentRepository.startableConfigFor] sağlar. Widget testi de
/// butondan açılan gerçek seans ekranının config'ini ayrıca denetler.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ContentRepository> yukle(WidgetTester tester) async {
    late ContentRepository c;
    await tester.runAsync(() async => c = await ContentRepository.load(rootBundle));
    return c;
  }

  testWidgets('beyan-açık her hareket kendi id’siyle başlatılabilir',
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

    final Set<String> ulasilabilir = c.catalogue.movements
        .where((MovementEntry m) => c.startableConfigFor(m.id) != null)
        .map((MovementEntry m) => m.id)
        .toSet();
    expect(ulasilabilir, beyanAcik,
        reason: 'AÇIK etiketi olan hareketin kendi id’siyle canlı seans '
            'başlatılamıyorsa kullanıcı çıkmaza girer.');
    expect(c.startableConfigFor('tuck_planche'), isNull,
        reason: 'kapalı hareket için ölçüm girişi açılmamalı');
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
