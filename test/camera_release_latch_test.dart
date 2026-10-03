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
    expect(
      done,
      isTrue,
      reason:
          'N=1 yolunda bekleme doğdu — nöbet, koruması gereken '
          'durumu olmadığı hâlde maliyet ekliyor.',
    );
  });

  test('SIRA: ikinci seans, birincinin kapanışını BEKLER', () async {
    final Completer<void> close = Completer<void>();
    final List<String> order = <String>[];

    // 1. seans kapanıyor (dispose).
    CameraReleaseLatch.hold(close.future.then((_) => order.add('stop bitti')));

    // 2. seans hemen açılmak istiyor.
    final Future<void> start = CameraReleaseLatch.awaitRelease().then(
      (_) => order.add('start başladı'),
    );

    await Future<void>.delayed(Duration.zero);
    expect(order, isEmpty, reason: 'start, kapanış bitmeden ilerledi');

    close.complete();
    await start;

    expect(
      order,
      <String>['stop bitti', 'start başladı'],
      reason:
          'İkinci seans, birincinin kapanışıyla YARIŞTI — '
          'cihazda bu `already-running` demek.',
    );
  });

  test('SENKRON YAYIN: `hold` kilidi ilk await\'ten ÖNCE görünür kılar', () {
    // `dispose` tamamlanmadan nöbet kurulmalı. Mekanizma değil, çağrının
    // hemen ardından görünür kaynak sahipliği ölçülüyor; araya await yok.
    expect(CameraReleaseLatch.isHolding, isFalse);
    CameraReleaseLatch.hold(Completer<void>().future);
    expect(
      CameraReleaseLatch.isHolding,
      isTrue,
      reason:
          'Kilit senkron yayınlanmıyor — `hold` bir `async` gövdeye '
          'sarılmış olabilir. Bu, yarışı kapatmadan kapatmış GÖRÜNMEK.',
    );
  });

  test(
    'başarısız kapanış tamamlanır ama kurtarma ACK almadan bırakılmış sayılmaz',
    () async {
      final error = StateError('stop failed');
      CameraReleaseLatch.hold(Future<void>.error(error));
      final failed = await CameraReleaseLatch.awaitRelease();
      expect(failed.released, isFalse);
      expect(failed.error, same(error));
      expect(CameraReleaseLatch.requiresRecovery, isTrue);
      final gate = Completer<void>();
      int recoveries = 0;
      final recovered = CameraReleaseLatch.awaitRelease(
        recover: () {
          recoveries++;
          return gate.future;
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(recoveries, 1);
      expect(CameraReleaseLatch.isHolding, isTrue);
      expect(CameraReleaseLatch.requiresRecovery, isTrue);
      gate.complete();
      expect((await recovered).released, isTrue);
      expect(CameraReleaseLatch.requiresRecovery, isFalse);
    },
  );

  test('NEGATİF İKİZ: nöbet olmadan sıra GERÇEKTEN bozuluyor', () async {
    // Kapının kendisi ölçülüyor: `hold` çağrılmazsa `awaitRelease` hiçbir
    // şey beklemez — yani testin yeşili nöbetten geliyor, tesadüften değil.
    final Completer<void> close = Completer<void>();
    final List<String> order = <String>[];
    unawaited(close.future.then((_) => order.add('stop bitti')));

    await CameraReleaseLatch.awaitRelease();
    order.add('start başladı');

    expect(
      order,
      <String>['start başladı'],
      reason:
          'İKİZ ÖLDÜ: nöbet kurulmadığı hâlde bekleme oluştu — '
          'bu testin yeşili başka bir şeyden geliyor.',
    );
    close.complete();
  });

  test('TERS İKİZ: nöbeti erken TEMİZLEYEREK geçilemez', () async {
    // ⚠️ Aile standardı: bir kapı, kendisini geçmenin YANLIŞ yolunu da
    // kapatmalı. Erken biten bir kapanış diğer uçmakta olan kapanışı silemez.
    final Completer<void> close = Completer<void>();
    CameraReleaseLatch.hold(close.future);

    // Araya İKİNCİ bir kapanış giriyor; birincisi bitince nöbet
    // BIRAKILMAMALI, çünkü hâlâ uçmakta olan bir kapanış var.
    final Completer<void> second = Completer<void>();
    CameraReleaseLatch.hold(second.future);

    close.complete();
    await Future<void>.delayed(Duration.zero);

    expect(
      CameraReleaseLatch.isHolding,
      isTrue,
      reason:
          'Eski kapanış bitince nöbet düştü — oysa yeni bir kapanış '
          'hâlâ uçmakta.',
    );
    second.complete();
  });

  for (final firstFinishesFirst in <bool>[true, false]) {
    test(
      'beklerken eklenen kapanış da beklenir; ilk önce birinci=$firstFinishesFirst',
      () async {
        final first = Completer<void>();
        final second = Completer<void>();
        CameraReleaseLatch.hold(first.future);
        bool admitted = false;
        final waiter = CameraReleaseLatch.awaitRelease().then((result) {
          admitted = result.released;
          return result;
        });
        await Future<void>.delayed(Duration.zero);
        CameraReleaseLatch.hold(second.future);
        (firstFinishesFirst ? first : second).complete();
        await Future<void>.delayed(Duration.zero);
        expect(
          admitted,
          isFalse,
          reason: "tek kapanışın ACK'i bütün sahipliği bırakmaz",
        );
        expect(CameraReleaseLatch.isHolding, isTrue);
        (firstFinishesFirst ? second : first).complete();
        expect((await waiter).released, isTrue);
        expect(CameraReleaseLatch.isHolding, isFalse);
      },
    );
  }

  test("eşzamanlı açılışlar tek başarılı kurtarma Stop'unu paylaşır", () async {
    CameraReleaseLatch.hold(Future<void>.error(StateError('old stop failed')));
    await CameraReleaseLatch.awaitRelease();
    final gate = Completer<void>();
    int recoveries = 0;
    Future<void> recover() {
      recoveries++;
      return gate.future;
    }

    final first = CameraReleaseLatch.awaitRelease(recover: recover);
    final second = CameraReleaseLatch.awaitRelease(recover: recover);
    await Future<void>.delayed(Duration.zero);
    expect(recoveries, 1);
    gate.complete();
    expect((await first).released, isTrue);
    expect((await second).released, isTrue);
    expect(CameraReleaseLatch.requiresRecovery, isFalse);
  });

  test(
    'başarısız paylaşılan kurtarma otomatik retry döngüsü yaratmaz',
    () async {
      CameraReleaseLatch.hold(
        Future<void>.error(StateError('old stop failed')),
      );
      await CameraReleaseLatch.awaitRelease();
      final gate = Completer<void>();
      int recoveries = 0;
      Future<void> recover() {
        recoveries++;
        return gate.future;
      }

      final first = CameraReleaseLatch.awaitRelease(recover: recover);
      final second = CameraReleaseLatch.awaitRelease(recover: recover);
      await Future<void>.delayed(Duration.zero);
      gate.completeError(StateError('recovery did not release'));
      expect((await first).released, isFalse);
      expect((await second).released, isFalse);
      expect(recoveries, 1);
      expect(CameraReleaseLatch.requiresRecovery, isTrue);
      expect(CameraReleaseLatch.isHolding, isFalse);
      final explicitRetry = await CameraReleaseLatch.awaitRelease(
        recover: () async {
          recoveries++;
        },
      );
      expect(explicitRetry.released, isTrue);
      expect(
        recoveries,
        2,
        reason: 'yeni açık istek bir kurtarma daha deneyebilir',
      );
    },
  );
}
