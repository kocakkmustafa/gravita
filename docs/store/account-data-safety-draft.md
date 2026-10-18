# Gravita hesap veri beyanı taslağı — 2026-09-25

Bu taslak uygulama kodundaki ortak Motion hesabına göredir. App Store Connect
gizlilik yanıtı ve Google Play Data safety formu henüz gönderilmiş değildir.

## Kaynakla uzlaştırma — 2026-09-26

Başlıktaki 2026-09-25 ilk taslak tarihidir. Bu güncelleme mevcut ilk kurs,
yerel ilerleme, çözümlenen hesap paketi ve native izin kaynaklarının
kontrolüdür; canlı sağlayıcı, fiziksel cihaz veya mağaza formu kabulü değildir.

## Sağlayıcı günlükleri ve kimlik doğrulama — 2026-09-27

Üretim sağlayıcısının 2026-09-26 21:36 UTC tarihli salt okunur alan/sayı
makbuzu, cihaz dışındaki Auth ve edge günlüklerinin saklandığını doğrular.
Ölçüm anına kadar dönen örnekte edge günlüklerinin 6/6 kaydında IP, user-agent ve
ülke/bölge/şehir alanları; Auth günlüklerinin 6/6 kaydında IP ve 2/6 kaydında
hesap kimliği; ayrı Auth audit deposunun 1/1 kaydında kimlik ve user-agent
vardır. Veritabanındaki `auth.audit_log_entries` satır sayısının sıfır olması,
[ayrı Auth günlük deposunun](https://supabase.com/docs/guides/auth/audit-logs)
boş olduğu anlamına gelmez. Ham IP, kimlik, parola veya günlük içeriği bu
belgeye alınmamıştır. Makbuz ortak servise aittir; her uygulamada yeni bir
canlı ağ oturumu ölçüldüğü iddiası değildir.

| Sunucuda saklanan veri | Apple manifest türü | Amaç ve bağlantı |
|---|---|---|
| IP, user-agent, istemci platform/sürüm bilgisi ve Auth/istek güvenlik günlükleri | `NSPrivacyCollectedDataTypeOtherDiagnosticData` | İşletim, güvenlik ve teknik tanılama; App Functionality, kullanıcıya bağlı, tracking yok |
| Edge isteğine eklenen IP tabanlı ülke/bölge/şehir | `NSPrivacyCollectedDataTypeCoarseLocation` | Aynı hizmetin işletim/güvenlik kaydı; App Functionality, kullanıcıya bağlı, tracking yok; GPS veya kesin konum izni değildir |
| Parola kimlik doğrulama verisi ve saklanan parola hash'i | `NSPrivacyCollectedDataTypeOtherDataTypes` | Hesap doğrulama; App Functionality, kullanıcıya bağlı, tracking yok |

[Supabase Auth](https://supabase.com/docs/guides/auth/password-security)
parolanın bcrypt hash'ini `auth.users.encrypted_password` alanında tutar;
parola uygulamanın kurs/seans geçmişine yazılmaz. Apple parola için ayrı
bir tür adlandırmadığından **Other Data Types eşlemesi bu projede yapılan
bir sınıflandırma çıkarımıdır**. Kullanıcı kimliğinin tek yönlü özetiyle
tutulan hesap silme makbuzu da güvenlik/hesap verisidir; hash olması tek
başına anonim veri olduğu anlamına gelmez. IP ve hesap ilişkisinin toplama
öncesinde kaldırıldığı kanıtlanmadığından bu üç tür `Linked=true` beyan edilir.

Manifest artık e-posta, isteğe bağlı ad, kullanıcı ID'si ve bu üç türden
oluşan **altı** collected-data kaydı taşır. Hepsinde
`NSPrivacyCollectedDataTypePurposeAppFunctionality`, `Linked=true` ve
`Tracking=false` vardır. Bu, davranış analitiği veya reklam amacı eklendiği
anlamına gelmez. Kamera/kareler, cihazda kalan kurs ilerlemesi ve seans
geçmişi için collection beyanı eklenmez; Ostinato'nun isteğe bağlı ham sesi
de yalnız cihazdaki sınırlı RAM'de kalır. Diğer dört uygulama mikrofon
kullanmaz. Sunucu günlükleri, cihaz içi geçici işleme ile aynı şey değildir.

[Apple collection ve kullanım tanımları](https://developer.apple.com/app-store/app-privacy-details/)
ve [manifest tür/anahtarları](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests)
bu ayrımın temelidir. Apple manifestinin güncellenmesi App Store Connect
veya Play Data safety formunun girildiği/onaylandığı anlamına gelmez.
Play kategorileri kendi form tanımlarıyla ayrıca eşleştirilir. Sağlayıcı
saklama süreleri, günlüklerin silme/erişim politikası, gerçek hesap silme
akışı ve son paket/SDK gizlilik raporu ayrı kabul kapılarıdır.

| Veri | Cihaz dışına çıkar mı? | Kullanım | Hesapla bağlı mı? |
|---|---|---|---|
| E-posta adresi | Evet, Motion Auth | Kayıt, giriş, doğrulama, şifre sıfırlama | Evet |
| Görünen ad | Kullanıcı girerse evet, Motion profili | Profil | Evet |
| Kullanıcı kimliği | Evet, Motion Auth/profil/uygulama üyeliği | Oturum ve hesap veri ayrımı | Evet |
| Satın alma geçmişi | Hayır; ilk sürümde satış ve ücretli oturum kapalı | Bu sürümde kullanılmaz | Hayır |
| Şifre | Auth isteğinde sunucuya gider; uygulama geçmişine yazılmaz | Kayıt, giriş, şifre değiştirme | Evet |
| Kamera görüntüsü ve kare ölçümü | Hayır | Bu ilk sürümde kamera oturumu kapalı; ertelenen akış cihaz içindir | Sunucuya kamera verisi aktarımı açılmaz |
| Calisthenics, DB/KB ve temel kurs taslaklarının ilerlemesi | Hayır | Görüldü, çalışıldı ve kullanıcı beyanıyla tamamlandı durumları | Konuk/hesap kapsamına ayrılmış yerel JSON; Motion hesabına senkronize edilmez |
| Mikrofon/ses | Kullanılmaz | İlk kurs mikrofon istemez | iOS mikrofon gerekçesi ve Android `RECORD_AUDIO` yoktur |
| Seans özeti/geçmişi | Hayır | Bu cihazdaki geçmiş | Yerel, hesap dizinine ayrılmış |

İlk sürümün Apple gizlilik manifestinde e-posta, isteğe bağlı ad,
kullanıcı kimliği ve sağlayıcı tanılama/konum/kimlik doğrulama
verileri uygulama işlevi için kullanıcıyla bağlantılı, izleme dışı beyan edilir.
Play için yalnız üç kişisel veri türünü beyan etmek yeterli değildir.
E-posta, ad ve kullanıcı ID'sine ek olarak sağlayıcıdaki yaklaşık konum,
teknik/güvenlik günlükleri ve kimlik doğrulama verisi de değerlendirilir.
[Altı kaynak türünün eşleme taslağı](privacy-review.json) Apple manifestiyle
uzlaştırılmıştır. Google tarafında IP'den türetilen konum için Approximate
location; teknik tanılama için Diagnostics; parola/hash için Other info
önerilir. Son ikisi ve IP'nin kullanımına göre ek kimlik sınıflandırması
kesin konsol yanıtı değildir; geliştirici incelemesi bekleyen çıkarımlardır.
Google Analytics amacı teknik hata tanılamayı da kapsar; davranış analitiği
SDK'sının bulunmaması bu amaç seçeneğini tek başına dışlamaz.
Abonelik satışı ve satın alma geçmişi
aktarımı bu sürümde kapalıdır; ileride etkinleştirilirse Apple/Play
formları ve bu belge birlikte güncellenir.
Görünen ad kullanıcı için isteğe bağlıdır. Kamera ve cihazda kalan geçmiş
“toplanan veri” diye işaretlenmez. Sağlayıcı günlükleri makbuzu ve Auth
saklama belgesi temelinde tanılama, yaklaşık konum ve kimlik doğrulama
verileri de beyanlıdır; konsol formu ve saklama politikası ayrıca doğrulanır.

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
kapalıdır. Manifestte e-posta, ad, kullanıcı ID'si ve yukarıdaki üç sağlayıcı veri türü
collected olarak beyanlıdır; purchase-history türü yoktur. Final paket/SDK raporu, sağlayıcı
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

## 18 Ekim 2026 · gönderim öncesi uzlaştırma

Bu güncelleme uygulama davranışını veya Apple manifestini değiştirmez.
Play'in üç veri türüyle sınırlı eski paragrafı düzeltilmiştir.
[Google tanımları](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)
gereği SDK ile cihaz dışına gönderilen veriler de incelenir; yalnız cihazda
kalan ilerleme collection değildir. Saklanan sağlayıcı günlükleri geçici RAM
işlemesi sayılamaz. Hizmet sağlayıcı aktarımının sharing istisnasına girmesi,
işleyenin geliştirici adına çalışması koşuluyla değerlendirilir.

Konuk kullanımında da eski hesap dizinleri için silme makbuzu sorgulanabilir;
misafir akışını kullanabilmek bütün teknik günlüklerin isteğe bağlı olduğunu
kanıtlamaz. Bu yüzden günlük/konum için required/optional seçimi ve sağlayıcı
saklama gün sayıları uydurulmadı; JSON'da gönderimi durduran açık alanlardır.
Hesaba bağlı UUID özeti anonim kabul edilmez. Analytics/Diagnostics ve
Other info eşlemesi, teknik amaçlar ve hizmet sağlayıcı rolü final formda
kurucu tarafından güncel fiilî kullanım üzerinden doğrulanır.

[Canlı Motion sayfası](https://yulalab.com/en/privacy/motion) 18 Ekim'de
okundu: Gravita adı, üst bölümde hesap/veri silme bağlantısı, uygulama
olmadan e-postayla talep yolu, aboneliği mağazada ayrıca iptal etme ve
günlük/yedek saklama istisnası mevcut. Bu, silme talebinin yerine getirildiği
veya belirli bir saklama süresinin doğrulandığı anlamına gelmez.
[Google](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)
uygulama dışı bir talep yolu ve belirgin bağlantı ister; konsol onayı ayrıdır.
`https://yulalab.com/support` bu turda içerik okuyucuda açılamadı; HTTP hata
kodu tespit edilmiş değildir. Kurucu tarafından seçilen URL değiştirilmedi.

Supabase bağlantısının salt okunur proje listesinde bu paketin Motion projesi
görünmüyor. İlgisiz projede tablo, SQL veya kullanıcı sorgusu yapılmadı.
Son canlı sağlayıcı kanıtı yukarıdaki 26 Eylül makbuzudur; bu tarihte yeni
backend/retention kabulü üretilmedi. Güncel gönderim kapıları ve kullanıcı
adımları [RELEASE-REVIEW.tr.md](RELEASE-REVIEW.tr.md) içindedir.
