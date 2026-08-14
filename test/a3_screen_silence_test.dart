import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/library_model.dart';
import 'package:gravita/app/movement_page.dart';
import 'package:gravita/app/theme.dart';

/// ⭐ G-217 — **`A3`ün EKRAN YARISI: sebep İÇERİKTE var da, ÇİZİLİYOR mu?**
///
/// Koordinatör `H-17` ③: *"`A3` sessiz oran — paydalı süpürme desenin
/// `library_surface_test.dart:924-937`'de hazır, **ekrana taşı**."*
///
/// ## İki ayrı soru — ve bugüne dek yalnız biri soruluyordu
///
/// `tools/dead_end_census.py` (`A3`) *"kaç kapalı hareket sebebini
/// **BEYAN EDİYOR**"* diye sorar ve `library.json`daki dürüstlük listelerini
/// okur. Bugün cevabı **sessiz 0/31**.
///
/// Ama bir sebep içerikte olup **ekranda çizilmeyebilir**: bölüm bir koşulun
/// arkasında kalabilir, liste boş dallanabilir, kart katlamanın altında hiç
/// kurulmayabilir.
/// > ***BİR SEBEBİN DOSYADA OLMASI, KULLANICIYA SÖYLENDİĞİ ANLAMINA
/// > GELMEZ.***
/// Bu dosya ikinci soruyu sorar: **29 kapalı hareketin SAYFASI sebebini
/// gerçekten çiziyor mu.**
///
/// ## Payda SÜPÜRÜLÜR, örneklenmez
///
/// `library_surface_test.dart:924-937`in bedelle öğrendiği ders: kapı
/// `firstWhere` ile **tek** bloklu hareketi alıyordu ve `bodyweight_squat`
/// **curated** olduğu için yapısal ayrımı hiç almamıştı — kapı onu **hiç
/// görmedi**. Bu yüzden burada da tek örnek YOK: **kapalı olanların hepsi**.
/// > ***BİR ÖRNEK, BİR PAYDA DEĞİLDİR.***
///
/// ## 🪤 Katlama-altı körlüğü — koordinatör `H-10`, Lissom'un tuzağı
///
/// Lissom'un çelişki kapısı yalnız `pump` anında çizilmiş `Text`leri
/// tarıyordu; suçlu kart **`ListView`in katlaması altındaydı** ve hiç
/// kurulmamıştı. Bu yüzden bütün aramalar **`skipOffstage: false`** ile
/// yapılıyor — aksi hâlde kapı "çizilmiş" ile "görünür alanda" arasındaki
/// farkı ölçmeden yeşil yanardı.
void main() {
  Future<ContentRepository> loadReal(WidgetTester tester) async {
    late ContentRepository c;
    await tester
        .runAsync(() async => c = await ContentRepository.load(rootBundle));
    return c;
  }

  Widget host(Widget child) =>
      MaterialApp(theme: GravitaTheme.light, home: child);

  testWidgets('KAPALI her hareketin sayfası sebebini EKRANDA çiziyor',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ContentRepository c = await loadReal(tester);
    final List<MovementEntry> kapali = c.catalogue.movements
        .where((MovementEntry m) => !m.isLive)
        .toList(growable: false);

    // ⚠️ VAKUM: kapalı hareket yoksa döngü hiç dönmez ve kapı "sessizlik yok"
    // diye okunur. *"0 sessiz yüzey" en kolay sahtelenen sayıdır.*
    expect(kapali, isNotEmpty, reason: 'VAKUM: kapalı hareket bulunamadı.');
    expect(kapali, hasLength(29),
        reason: 'Payda kaydıysa bu ölçüm yeniden gerekçelendirilmeli — '
            'A4 artefaktı da 29 diyor (docs/gates/kanit/a4-cikmaz-dagilimi.json).');

    final List<String> sessizYuzeyler = <String>[];
    for (final MovementEntry m in kapali) {
      // İçerik tarafı zaten `library_surface_test`te sınanıyor; burada onu
      // ÖN KOŞUL olarak alıyoruz — yoksa ölçtüğümüz şey içerik boşluğu olurdu.
      if (m.honesty.waitingOnMeasurement.isEmpty) continue;
      final String sebep = m.honesty.waitingOnMeasurement.first;

      await tester.pumpWidget(host(MovementPage(movement: m, content: c)));
      await tester.pump();

      if (find.text(sebep, skipOffstage: false).evaluate().isEmpty) {
        sessizYuzeyler.add(m.id);
      }
    }

    expect(sessizYuzeyler, isEmpty,
        reason: 'Bu hareketlerin sebebi İÇERİKTE var ama SAYFASI onu '
            'çizmiyor — kullanıcı neden kapalı olduğunu ekranda öğrenemez. '
            'A3 içerik yarısı yeşil olsa bile bu bir sessiz yüzeydir: '
            '$sessizYuzeyler');
  });

  /// ⭐ POZİTİF İKİZ — kapı gerçekten ARIYOR mu?
  ///
  /// Bu olmadan üstteki test, `find.text` her zaman bulsa da (ya da döngü hiç
  /// dönmese de) geçerdi. Burada ekranda **olmadığını bildiğimiz** bir metni
  /// arıyoruz: bulunursa arama değil, sabit bir "evet" ölçülüyor demektir.
  testWidgets('POZİTİF İKİZ: sayfada OLMAYAN metin bulunmuyor',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ContentRepository c = await loadReal(tester);
    final MovementEntry m =
        c.catalogue.movements.firstWhere((MovementEntry x) => !x.isLive);

    await tester.pumpWidget(host(MovementPage(movement: m, content: c)));
    await tester.pump();

    expect(
        find.text('bu cümle hiçbir sayfada yok — sentetik', skipOffstage: false),
        findsNothing,
        reason: 'Arama her metni buluyorsa üstteki kapı hiçbir şey ölçmez.');
  });
}
