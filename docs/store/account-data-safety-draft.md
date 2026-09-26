# Gravita hesap veri beyanı taslağı — 2026-09-25

Bu taslak uygulama kodundaki ortak Motion hesabına göredir. App Store Connect
gizlilik yanıtı ve Google Play Data safety formu henüz gönderilmiş değildir.

## Kaynakla uzlaştırma — 2026-09-26

Başlıktaki 2026-09-25 ilk taslak tarihidir. Bu güncelleme mevcut ilk kurs,
yerel ilerleme, çözümlenen hesap paketi ve native izin kaynaklarının
kontrolüdür; canlı sağlayıcı, fiziksel cihaz veya mağaza formu kabulü değildir.

| Veri | Cihaz dışına çıkar mı? | Kullanım | Hesapla bağlı mı? |
|---|---|---|---|
| E-posta adresi | Evet, Motion Auth | Kayıt, giriş, doğrulama, şifre sıfırlama | Evet |
| Görünen ad | Kullanıcı girerse evet, Motion profili | Profil | Evet |
| Kullanıcı kimliği | Evet, Motion Auth/profil/uygulama üyeliği | Oturum ve hesap veri ayrımı | Evet |
| Satın alma geçmişi | Hayır; ilk sürümde satış ve ücretli oturum kapalı | Bu sürümde kullanılmaz | Hayır |
| Şifre | Auth isteğinde sunucuya gider; uygulama geçmişine yazılmaz | Kayıt, giriş, şifre değiştirme | Evet |
| Kamera görüntüsü ve kare ölçümü | Hayır | Cihazdaki canlı çalışma | Yerel, sunucuda yok |
| Calisthenics kursu ilerlemesi | Hayır | Görüldü, çalışıldı ve kullanıcı beyanıyla tamamlandı durumları | Konuk/hesap kapsamına ayrılmış yerel JSON; Motion hesabına senkronize edilmez |
| Mikrofon/ses | Kullanılmaz | İlk kurs mikrofon istemez | iOS mikrofon gerekçesi ve Android `RECORD_AUDIO` yoktur |
| Seans özeti/geçmişi | Hayır | Bu cihazdaki geçmiş | Yerel, hesap dizinine ayrılmış |

İlk sürümün Apple gizlilik manifestinde e-posta, isteğe bağlı ad ve
kullanıcı kimliği uygulama işlevi için kullanıcıyla bağlantılı, izleme dışı
beyan edilir. Play taslağında bunlar Personal info / Email address, Name ve
User IDs olarak değerlendirilir. Abonelik satışı ve satın alma geçmişi
aktarımı bu sürümde kapalıdır; ileride etkinleştirilirse Apple/Play
formları ve bu belge birlikte güncellenir.
Görünen ad kullanıcı için isteğe bağlıdır. Kamera ve cihazda kalan geçmiş
“toplanan veri” diye işaretlenmez. Şifre ve sağlayıcı günlükleri için nihai
form yanıtı canlı Supabase yapılandırmasıyla ayrıca doğrulanır.

[Apple](https://developer.apple.com/app-store/app-privacy-details/) ve
[Google Play](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)
yalnız cihazda kalan işlem/kaydın collection beyanı gerektirmediğini açıklar.
Cihaz dışına gönderilen türetilmiş veri veya SDK trafiği ayrı değerlendirilir.
Kurs öz beyanı form/ustalık puanı değildir. Ostinato'nun izinli isteğe bağlı
mikrofon kararı Gravita'ya mikrofon eklemez.

Kaynaklar: `lib/main.dart`, `lib/app/calisthenics_progress.dart`,
`lib/app/account_data_directory.dart`, `lib/app/account_connection.dart`,
native izin dosyaları ve `ios/Runner/PrivacyInfo.xcprivacy`. Çözümlenen
`motion_account` paketindeki `motion_release_policy.dart` değeri
`motionPaidFeaturesAvailable=false`; satış/üyelik ve paid-session girişleri
kapalıdır. Manifestte yalnız e-posta, ad ve kullanıcı ID'si collected olarak
beyanlıdır; purchase-history türü yoktur. Final paket/SDK raporu, sağlayıcı
günlükleri/saklama ve gerçek Apple/Play yanıtları ayrıca doğrulanır.

Hesap ekranı ortak hesabı silme yolu sunar; başarılı uzak silmenin ardından
yalnız bu uygulamanın ilgili kullanıcıya ait yerel dizinini siler. Play'in
istediği uygulama dışı hesap silme bağlantısının canlı içeriği, mağaza
konsolundaki veri beyanı, sağlayıcı saklama süresi ve abonelik iptali açıklaması
yayın kapılarıdır. Abonelik satışı açılmadan önce hesap silme ve mağaza aboneliği ilişkisi
ayrıca açıklanır.

Kaynak: [Apple privacy manifest](https://developer.apple.com/documentation/BundleResources/describing-data-use-in-privacy-manifests),
[Google Play Data safety](https://support.google.com/googleplay/android-developer/answer/10787469),
[Google Play hesap silme](https://support.google.com/googleplay/android-developer/answer/13327111).
