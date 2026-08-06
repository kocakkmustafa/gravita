import 'dart:async';
import 'dart:io';

/// Tüm test koşumlarının ortak kurulumu (Flutter bunu OTOMATİK çağırır).
///
/// ## Neden var — ailenin ölçülmüş tuzağı, ve tuzağın YANLIŞ panzehiri
///
/// `google_fonts`, istenen aile/ağırlık uygulama asset'lerinde yoksa
/// `fonts.gstatic.com`'dan İNDİRMEYE çalışır. `flutter_test` altında ağ yoktur
/// → her istek patlar ve konsol her koşumda hata basar.
///
/// ⚠️ **İlk denediğim panzehir YANLIŞTI ve ölçümle düştü.** Aile defterindeki
/// not `GoogleFonts.config.allowRuntimeFetching = false` demeyi akla getiriyor;
/// denendi ve testleri DÜŞÜRDÜ:
///
///     Exception: GoogleFonts.config.allowRuntimeFetching is false but font
///     PublicSans-Regular was not found in the application assets.
///
/// Yani o bayrak "indirme, sistem yazı tipine düş" demiyor; **"indirme ve
/// bulamazsan FIRLAT"** diyor. Fontlar bu projede paketlenmediği için hepsi
/// fırlatıyordu. Hastalıktan kötü bir ilaç.
///
/// **Doğrusu:** indirmeyi AÇIK bırak, ama ağı testte ölü bir istemciyle kes.
/// `google_fonts` başarısız indirmeyi YAKALAR ve sessizce sistem yazı tipine
/// düşer — testler yapıyı ve metni ölçüyor, glif biçimini değil.
///
/// Yan fayda: testler gerçekten hermetik olur. Önceki hâlde her koşum
/// `fonts.gstatic.com`'a çıkmayı DENİYORDU; ağı olan bir makinede yavaş, ağı
/// olmayanda gürültülü, ikisinde de dışarıya bağımlıydı.
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
