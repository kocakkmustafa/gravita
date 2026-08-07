import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/camera_release_latch.dart';

/// C-195 nöbeti — **sıra** ölçülüyor, "çalışıyor mu" değil.
///
/// Bu kusurun tanımı gereği N=1'de görünmez: tek seans her zaman çalışır.
/// O yüzden her test **iki** seans kurar ve İKİNCİNİN birinciyi beklediğini
/// ölçer.
void main() {
  setUp(CameraReleaseLatch.resetForTest);

  test('POZİTİF KONTROL: bekleyecek kapanış yoksa maliyet SIFIR', () async {
    bool done = false;
    // Mikro-görev sırası: nöbet boşsa `awaitRelease` hiçbir gerçek bekleme
    // eklememeli. Bir zamanlayıcı turu bile beklemediğini ölçüyoruz.
    unawaited(CameraReleaseLatch.awaitRelease().then((_) => done = true));
    await Future<void>.value();
    await Future<void>.value();
    expect(done, isTrue,
        reason: 'N=1 yolunda bekleme doğdu — nöbet, koruması gereken '
            'durumu olmadığı hâlde maliyet ekliyor.');
  });

  test('SIRA: ikinci seans, birincinin kapanışını BEKLER', () async {
    final Completer<void> close = Completer<void>();
    final List<String> order = <String>[];

    // 1. seans kapanıyor (dispose).
    CameraReleaseLatch.hold(close.future.then((_) => order.add('stop bitti')));

    // 2. seans hemen açılmak istiyor.
    final Future<void> start =
        CameraReleaseLatch.awaitRelease().then((_) => order.add('start başladı'));

    await Future<void>.delayed(Duration.zero);
    expect(order, isEmpty, reason: 'start, kapanış bitmeden ilerledi');

    close.complete();
    await start;

    expect(order, <String>['stop bitti', 'start başladı'],
        reason: 'İkinci seans, birincinin kapanışıyla YARIŞTI — '
            'cihazda bu `already-running` demek.');
  });

  test('SENKRON YAYIN: `hold` kilidi ilk await\'ten ÖNCE görünür kılar', () {
    // ⭐ Choreia'nın en ince notu: `async` bir gövde, atamayı ilk `await`'ten
    // SONRA yayınlar. Kilit `dispose` içinde senkron kurulmazsa, bir sonraki
    // `start` onu göremez ve yarış AYNEN kalır — kod "düzeltilmiş" görünerek.
    //
    // Bu yüzden burada tek bir `await` bile yok: `hold`dan hemen sonra
    // nöbetin tutuyor olması ŞART.
    expect(CameraReleaseLatch.isHolding, isFalse);
    CameraReleaseLatch.hold(Completer<void>().future);
    expect(CameraReleaseLatch.isHolding, isTrue,
        reason: 'Kilit senkron yayınlanmıyor — `hold` bir `async` gövdeye '
            'sarılmış olabilir. Bu, yarışı kapatmadan kapatmış GÖRÜNMEK.');
  });

  test('HATA YUTULUR: kapanış patlarsa bir sonraki açılış ENGELLENMEZ',
      () async {
    CameraReleaseLatch.hold(Future<void>.error(StateError('stop failed')));
    // Nöbetin işi SIRALAMAK, hüküm vermek değil: başarısız bir kapanış
    // kullanıcıyı uygulamanın dışında bırakmamalı.
    await expectLater(CameraReleaseLatch.awaitRelease(), completes);
  });

  test('NEGATİF İKİZ: nöbet olmadan sıra GERÇEKTEN bozuluyor', () async {
    // Kapının kendisi ölçülüyor: `hold` çağrılmazsa `awaitRelease` hiçbir
    // şey beklemez — yani testin yeşili nöbetten geliyor, tesadüften değil.
    final Completer<void> close = Completer<void>();
    final List<String> order = <String>[];
    unawaited(close.future.then((_) => order.add('stop bitti')));

    await CameraReleaseLatch.awaitRelease();
    order.add('start başladı');

    expect(order, <String>['start başladı'],
        reason: 'İKİZ ÖLDÜ: nöbet kurulmadığı hâlde bekleme oluştu — '
            'bu testin yeşili başka bir şeyden geliyor.');
    close.complete();
  });

  test('TERS İKİZ: nöbeti erken TEMİZLEYEREK geçilemez', () async {
    // ⚠️ Aile standardı: bir kapı, kendisini geçmenin YANLIŞ yolunu da
    // kapatmalı. Buradaki yanlış yol "yarışı çöz" değil, "nöbeti bırak" —
    // `hold` bitmeden `_closing`i düşürmek testi yeşile döndürürdü ve
    // koruma sessizce ölürdü.
    final Completer<void> close = Completer<void>();
    CameraReleaseLatch.hold(close.future);

    // Araya İKİNCİ bir kapanış giriyor; birincisi bitince nöbet
    // BIRAKILMAMALI, çünkü hâlâ uçmakta olan bir kapanış var.
    final Completer<void> second = Completer<void>();
    CameraReleaseLatch.hold(second.future);

    close.complete();
    await Future<void>.delayed(Duration.zero);

    expect(CameraReleaseLatch.isHolding, isTrue,
        reason: 'Eski kapanış bitince nöbet düştü — oysa yeni bir kapanış '
            'hâlâ uçmakta. `whenComplete` içindeki kimlik kontrolü '
            'kaldırılmış olabilir.');
    second.complete();
  });
}
