import 'dart:async';

/// Süreç-geneli kamera KAPANIŞ nöbeti — C-195'in (Choreia) bu hattaki hâli.
///
/// ## Kusur
///
/// `State.dispose` **senkron**dur, yani `camera.stop()` beklenemez. Ama
/// `stop` bir platform-kanalı gidiş-dönüşüdür. Kullanıcı bir seanstan çıkıp
/// **hemen** yenisini açarsa `start()`, sistem kamerayı hâlâ kapatırken
/// çağrılır → `already-running`.
///
/// > ***İkinci hareket, birinci hareketin sebep olduğu arızayla
/// > karşılanır.***
///
/// **N=1'de yapısal olarak görünmez.** Bu hattın 145 testlik süiti bunun
/// altından geçti: hepsi *"ekran çalışıyor mu"* diye soruyordu ve cevap
/// **ilk seferinde** evetti.
///
/// ## Neden `static` (yani süreç-geneli)
///
/// Her ekran kendi controller'ını kurar — ama **cihazda tek kamera var.**
/// Kaynak paylaşılıyorsa nöbet de paylaşılmalı; ekran-başına bir kilit
/// hiçbir şeyi korumaz.
///
/// ## Neden [hold] `async` DEĞİL
///
/// `async` bir gövde, ilk `await`'e kadar senkron koşar ama **atamayı
/// yayınlaması** çağıranın görebileceği ana bağlıdır. Kilidi `dispose`
/// içinde **senkron** kurabilmek şart: `stop()` Future'ı anında döner,
/// [hold] onu anında saklar, ve bir sonraki `start` onu **görmüş** olur.
/// Sarmalayıcı `async` olsaydı kilit ilk `await`'ten sonra görünür olurdu
/// ve yarış aynen kalırdı.
///
/// ## Maliyet
///
/// N=1'de **sıfır**: bekleyecek bir kapanış yoksa [awaitRelease] hemen döner.
class CameraReleaseLatch {
  CameraReleaseLatch._();

  static Future<void>? _closing;

  /// Uçmakta olan kapanışı kaydeder. `dispose` içinden SENKRON çağrılmalı.
  ///
  /// Hatalar burada yutulur: kapanışın başarısız olması, bir sonraki açılışı
  /// ENGELLEMEMELİ — nöbetin işi sıralamak, hüküm vermek değil.
  static void hold(Future<void> closing) {
    final Future<void> guarded = closing.catchError((Object _) {});
    _closing = guarded;
    unawaited(guarded.whenComplete(() {
      // Yalnız KENDİ kapanışını temizle: araya yeni bir kapanış girdiyse
      // onu silmek nöbeti sessizce kaldırırdı.
      if (identical(_closing, guarded)) _closing = null;
    }));
  }

  /// Kapanış bitene kadar bekler. Bekleyecek bir şey yoksa maliyeti yok.
  static Future<void> awaitRelease() async {
    final Future<void>? c = _closing;
    if (c != null) await c;
  }

  /// Testler için: nöbeti sıfırlar. Süreç-geneli durum testler arasında
  /// sızarsa bir sonraki test öncekinin kapanışını beklerdi.
  static void resetForTest() => _closing = null;

  /// Şu an uçmakta olan bir kapanış var mı — yalnız ölçüm için.
  static bool get isHolding => _closing != null;
}
