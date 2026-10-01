/// İÇERİK/GEÇMİŞ YÜKLEME HATASININ TİPLİ MODELİ.
///
/// **JabLab `6601b1b` (J-079) deseninin Gravita uyarlaması** — sıfırdan
/// yazılmadı (M-F-193/194 talimatı). Gravita İKİNCİ tüketici; deltalar
/// `docs/design/CONTENT-FAILURE-DELTA.md`de.
///
/// **Neden tip, neden string değil** (JabLab gerekçesi, aynen geçerli): ekranın
/// davranışı hata SINIFINA göre değişmek zorunda — bütünlük hatasında "tekrar
/// dene" yalandır, aynı asset aynı sonucu verir. Bunu hata METNİNDEN çıkarmak
/// ("mesajda 'wave' geçiyorsa…") tam o sessiz-kırılma sınıfı olurdu: metin bir
/// gün değişir, sınıflandırma sessizce yanlışa döner, hiçbir test görmez.
library;

import 'package:motion_content/motion_content.dart';

/// Ne tür bir başarısızlık — ve bu ayrım kullanıcıya SUNULAN EYLEMİ belirler.
enum ContentFailureKind {
  /// İçerik okunabildi ama KENDİ İÇİNDE tutarsız: `wave` beyanı yok, katalog
  /// config'i çözümlenemiyor, ders bulunmayan bir harekete atıf yapıyor…
  ///
  /// Bizim-hatamız sınıfı ve **kasıtlı olarak bloklayıcı**: doğruluğuna kefil
  /// olamadığımız bir kütüphaneyi göstermek yerine hiç göstermiyoruz. Tekrar
  /// denemek anlamsız.
  integrity,

  /// İçerik OKUNAMADI: asset yok, zaman aşımı veya I/O hatası. Kurulum
  /// bozulmuş olabilir; yeniden kurmak GERÇEKTEN çözebilir. Paketlenmiş
  /// manifestin bozuk şeması ise bütünlük hatasıdır.
  unreadable,
}

/// Kütüphane doğrulaması başarısız olduğunda fırlatılan tip.
final class ContentIntegrityException implements Exception {
  const ContentIntegrityException(this.errors);

  final List<String> errors;

  @override
  String toString() =>
      'ContentIntegrityException(${errors.length} ihlal):\n${errors.join("\n")}';
}

/// Ekranın okuduğu şey. Sınıflandırma BURADA yapılır, ekranda değil — ekran
/// hata nesnesini yorumlamaya başlarsa yorum mantığı iki yere dağılır.
final class ContentFailure {
  const ContentFailure({required this.kind, required this.detail});

  /// Herhangi bir yakalanmış hatayı sınıflandırır.
  ///
  /// Bilinmeyen tip [ContentFailureKind.unreadable] sayılır: yanlış tarafa
  /// düşmek gerekiyorsa, "yeniden kurmayı dene" demek "bu bizim içerik
  /// hatamız" demekten daha az yanlıştır — ikincisi kullanıcıya bizim adımıza
  /// teşhis koyar.
  factory ContentFailure.from(Object error) {
    if (error is ContentException) {
      final ContentFailureKind kind = switch (error.error.code) {
        ContentErrorCode.missingAsset ||
        ContentErrorCode.timeout ||
        ContentErrorCode.io => ContentFailureKind.unreadable,
        _ => ContentFailureKind.integrity,
      };
      return ContentFailure(kind: kind, detail: error.error.toString());
    }
    if (error is ContentIntegrityException) {
      return ContentFailure(
        kind: ContentFailureKind.integrity,
        detail: error.errors.join('\n'),
      );
    }
    // `ContentRepository` eksik `wave` beyanını, `MovementConfig.parse` bozuk
    // config'i `StateError`/`ArgumentError` ile bildiriyor: dosya OKUNDU,
    // içeriği tutmuyor → bütünlük.
    if (error is StateError || error is ArgumentError) {
      return ContentFailure(
          kind: ContentFailureKind.integrity, detail: error.toString());
    }
    return ContentFailure(
        kind: ContentFailureKind.unreadable, detail: error.toString());
  }

  final ContentFailureKind kind;

  /// Geliştirici ayrıntısı. Kullanıcıya İKİNCİL olarak, katlanmış hâlde —
  /// gizlenmiyor (sahada tek teşhis malzemesi) ama BİRİNCİL de değil
  /// (kullanıcıya `StateError` gövdesi göstermek dürüstlük değil, sorumluluğu
  /// ona devretmektir).
  final String detail;
}

/// ⭐ GRAVITA DELTASI — GEÇMİŞ okunamadı, ama İÇERİK sağlam.
///
/// JabLab'ın modelinde karşılığı YOK ve Gravita'da olmak ZORUNDA, çünkü
/// olmadığında kodum **yalan söylüyor**: `ProgressSummary` kayıt listesi boş
/// gelince her dersi `notStarted` gösteriyor ve yüzey "Not started" yazıyor.
/// Depo okunamadığında (izin hatası, `path_provider` başarısız, dosya bozuk)
/// bu cümle *"hiç çalışmadın"* demektir — kullanıcının aylarca birikmiş işini
/// yok saymak.
///
/// **Bu sınıf BLOKLAYICI DEĞİL** (içerik sağlam, dersler açılabilir) ama
/// **BEYAN EDİLMEK zorunda**: ölçüm bölümü sayı göstermez, yerine ne olduğunu
/// söyler. Sessizlik yalandır (J-066 disiplini).
///
/// ## Neden ÜÇ hâl (çekirdek 0.10.0 adopsiyonu)
///
/// İlk model ikiliydi: geçmiş ya okundu ya okunmadı. Çekirdek
/// `unreadableRecords()` zorunlu üye olunca üçüncü hâl ÖLÇÜLEBİLİR oldu ve
/// ikili model onu taşıyamıyor:
///
/// * bir kısmı okunduysa eldeki sayılar **gerçektir** — `unavailable` demek
///   kullanıcının okunabilmiş işini çöpe atardı;
/// * ama taban eksiktir — `ok` demek eksikliği gizler ve sayıyı **tam sayım**
///   gibi sunar.
///
/// Üçüncü hâl tam bu "doğru ama eksik" durumu için var: sayı gösterilir,
/// yanında tabanın tam olmadığı söylenir. `partial` ile `unavailable` AYRI
/// cümlelerdir — uç değer (hiç okunamadı) kısmi dalı susturamaz.
sealed class HistoryStatus {
  const HistoryStatus();
}

/// Geçmiş TAM okundu: kayıp satır yok, hata yok. Yüzeyde beyan gerektirmez —
/// beyan edilecek bir şey olmadığı için (gürültü, dürüstlük değildir).
final class HistoryOk extends HistoryStatus {
  const HistoryOk();
}

/// Geçmiş okundu ama [unreadableRecords] kayıt ÇÖZÜLEMEDİ (bozuk satır ya da
/// bilinmeyen şema sürümü; v1 göçü kayıp SAYILMAZ — çekirdeğin sayımı).
///
/// Sayılar gösterilir çünkü doğrudur; **alt sınır** oldukları söylenir.
final class HistoryPartial extends HistoryStatus {
  const HistoryPartial(this.unreadableRecords)
      : assert(unreadableRecords > 0,
            'kayıp yoksa hâl HistoryOk — sıfırlı "kısmi" beyan yalan olur');

  final int unreadableRecords;
}

/// Depo HİÇ okunamadı (izin, `path_provider`, dosya erişimi). Sayı
/// GÖSTERİLMEZ: bilmediğimizi sıfır yazmıyoruz.
final class HistoryUnavailable extends HistoryStatus {
  const HistoryUnavailable(this.detail);

  final String detail;
}
