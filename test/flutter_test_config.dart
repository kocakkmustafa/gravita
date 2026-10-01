import 'dart:async';
import 'dart:io';

/// Tüm test koşumlarının ortak kurulumu (Flutter bunu OTOMATİK çağırır).
///
/// ## ✅ F2 (D1, 2026-08-16) — doğuş sebebi ÇÖZÜLDÜ, mekanizma KALICI KAPI oldu
///
/// Bu dosya `google_fonts`un test-zamanı ağ davranışını yönetmek için
/// doğdu (aşağıda, tarihsel). O bağımlılık artık YOK — fontlar paketli,
/// `lib/` içinde `GoogleFonts.` çağrısı sıfır (`tools/network_claim_audit.py`
/// bunu her turda ölçer). **Ölçüldü, yazılarak değil:** `_DeadClient.
/// openUrl`e geçici bir sayaç eklenip tüm 217 test koşturuldu — 25 test
/// dosyasının HER BİRİ `0` bastı. Sayaç geri alındı, bu dosya artık
/// enstrümansız.
///
/// **Mekanizma SİLİNMEDİ — ağsız widget/birim testi kapısı:** Ortak Motion
/// hesabı artık ağ-yetenekli paketler getiriyor; bunlar
/// `network_claim_audit.py` içinde sınıflandırıldı. Bu test ortamı gerçek
/// Auth E2E'si için kullanılmaz. Yanlışlıkla ağa çıkan bir widget/birim testi
/// açık bir `SocketException` alır; gerçek servis kabulü ayrı koşulur.
///
/// ## Tarihsel not (artık geçerli değil, silinmedi) — ailenin ölçülmüş
/// tuzağı, ve tuzağın YANLIŞ panzehiri
///
/// `google_fonts`, istenen aile/ağırlık uygulama asset'lerinde yoksa
/// `fonts.gstatic.com`'dan İNDİRMEYE çalışırdı. `flutter_test` altında ağ
/// yoktu → her istek patlar ve konsol her koşumda hata basardı.
///
/// İlk denenen panzehir YANLIŞTI ve ölçümle düştü: aile defterindeki not
/// `GoogleFonts.config.allowRuntimeFetching = false` demeyi akla
/// getiriyordu; denendi ve testleri DÜŞÜRDÜ:
///
///     Exception: GoogleFonts.config.allowRuntimeFetching is false but font
///     PublicSans-Regular was not found in the application assets.
///
/// O bayrak "indirme, sistem yazı tipine düş" demiyordu; "indirme ve
/// bulamazsan FIRLAT" diyordu. Fontlar o zaman paketlenmediği için hepsi
/// fırlatıyordu. Hastalıktan kötü bir ilaçtı — doğru çözüm hep paketlemekti,
/// şimdi öyle.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  HttpOverrides.global = _NoNetwork();
  await testMain();
}

/// Her isteği ANINDA reddeden istemci — testte dış ağ YOK.
class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _DeadClient();
}

class _DeadClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      Future<HttpClientRequest>.error(
          const SocketException('test: dış ağ kapalı'));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
