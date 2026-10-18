# Gravita gönderim kontrol paketi · 18 Ekim 2026

Bu paket yerel inceleme içindir; yükleme/yayın kararı değildir. Model eğitimi
bu turdan ayrıdır. Tam öğretim hedefi ve beş alan korunur; uzman/gösterim
kabulü bekleyen fiziksel görevler tamamlanmış sayılmaz.

## Mevcut aday ve tamamlanan yerel işler

Çalışan kaynak `c05721d73b838859af976f8c06f09b9857d6960d`; kimlik
`com.yulalab.gravita`, ASC `6794714365`, sürüm `1.0.0`, build `2`.
56 calisthenics dersi ve mevcut DB/KB yollarına üç ayrı 12 dersli temel
taslak eklenmiştir. Yeni 24 fiziksel görev uzman/gösterim/öğrenci kabulü
bekler. Kullanıcının onayladığı sağlıklı yetişkin temel seviye, boş bar ve
rack/safety, alçak sabit halka, yükseltilmiş el desteği/duvar kapsamı korunur.

Host kabulü: 752 test geçti; analiz temiz; altı EN/TR host görünümü mevcut.
Bu sonuçlar fiziksel cihaz, gerçek hesap veya model doğruluğu kanıtı değildir.
18 Ekim düzenlemesi mağaza dokümanlarıdır; runtime, içerik, native ayar ve
kilit dosyası değiştirilmez. Bu yüzden önceki tam test turu tekrarlanmaz.

Güncel IPA SHA256:
`de1f88b0013fc784002ae2c2133d124cbf6a257c268ce4d84bde29c5f04e5b53`.
Varlık/model/config eşliği ve Runner/App dSYM UUID eşliği doğrulanmıştır.
**OS katı imza doğrulaması başarısız: `CSSMERR_TP_NOT_TRUSTED`.** Statik
sertifika/profil/entitlement eşliği bu engeli kapatmaz. Güncel AAB yoktur.
Tarihsel AAB/IPA güncel kaynak paketi olarak kullanılamaz.

## Görev ve kabul sırası

| ID | İşlem / önkoşul | Kanıt ve kapanış ölçütü | Durum |
|---|---|---|---|
| N01 | Güncel kaynak, hesap ve mağaza erişimini oku | Kaynak SHA; satış/kamera politikası; oturum kapsamı | Yerel kontrol tamam; ASC login ve Motion proje erişimi bekliyor |
| N02 | Gizlilik eşlemesi ve tarihsel ekran etiketini düzelt | Altı manifest türünün Play inceleme karşılığı; eski üçlü beyan kaldırıldı | Yerel taslak tamam |
| N03 | İnceleme notu, ekran ve gerçek hesap prosedürü | Bu dosya, privacy-review.json, review-notes.en.txt | Yerel paket tamam; uygulama/dış kabul aşağıda |
| N04 | Dar commit ve eşlik kaydı | Yalnız bu turdaki docs/store yolları; runtime eşliği | Commit makbuzu görev kanıt dizininde |
| R01 | Mevcut IPA'yı kullanıcı Terminalinde salt okunur doğrula | Strict codesign exit 0; sorun varsa mevcut korumalarla teşhis | Bekliyor; trust/anahtar/profil değiştirilmedi |
| R02 | Tek Android AAB; yeni geçici UDP bind kapsamı onayı | Ortak native kilit; 20 dk; offline; AAB SHA/imza/varlık eşliği | Genişletilmiş izin bekliyor; build başlamadı |
| R03 | Gerçek test hesabı ve cihaz kabulü | Aşağıdaki matris; sentetikten ayrı makbuz | Oturum/cihaz önkoşulu bekliyor |
| R04 | Sağlayıcı/privacy alanlarını doğrula | Retention, paylaşım/amaçlar, guest ağ davranışı, final SDK raporu | privacy-review.json P01–P06 açık |
| R05 | Yeni native EN/TR mağaza görüntüleri | Tam kaynak/paket kimliğine bağlı ham görüntü ve boyutlar | Native kabul sonrası; eski set kullanılamaz |
| R06 | Üç kurs fiziksel içerik kabulü | Yetkili uzman incelemesi, izinli gösterimler, gözlenmiş öğrenci akışı | Veri/uzman gelmedi; üretildi varsayılmadı |
| R07 | Final gönderim kararı | İlk üç kabul grubunun sonucu; hedef track/build, ücret ve kullanıcı onayı | Yükleme/yayın başlatılmadı |

## Gerçek hesap ve cihaz kabulü

1. Önce kabul edilebilir imzalı paketi seç; cihaz/OS, paket SHA, uygulama
   sürümü, runtime kaynak SHA ve tarih kaydedilir. Video çekimi/yükleme gerekmez.
2. Uçak modunda konuk derslerini aç, okuma durumunu değiştir, uygulamayı
   kapat/aç; kayıt korunmalı. Üç yeni kursun fiziksel kapıları açılamamalı.
3. Kullanıcı kendi güvenli giriş ekranında onaylı test hesabı A'ya girer.
   E-posta doğrulama/redirect `com.yulalab.gravita://auth/callback` ve bağlantı
   hatası/girişte gecikme gerçek oturumda kontrol edilir. Token/parola kaydedilmez.
4. A ilerlemesi oluştur, çıkış yap; konuk kaydı ayrı kalmalı. Kullanıcı onaylı
   B hesabına girer; A kaydı görünmemeli. A'ya dönünce yalnız A kaydı dönmeli.
   Arka plan/foreground ve çevrimdışı dönüşte hesap kimliği karışmamalı.
5. Kamera/üyelik/satın alma bu sürümde kapalı olmalı; ders okuması izin
   istememeli. Mikrofon istemi olmamalı. Reddedilmiş izin başka araçla açılmaz.
   Ertelenen kamera background lifecycle testleri host kanıtıdır; bu pakette
   erişilemeyen seansı cihaz kabulünden geçmiş gibi işaretleme.
6. Silme testi kalıcı ve beş uygulamanın ortak hesabını etkiler: kullanıcı
   yalnız adlandırılmış, atılabilir test hesabı için ayrıca onay verdikten sonra
   Account > Delete account son eylemine geçilir. Uzak silme, yeniden giriş
   reddi, bu uygulamada yalnız ilgili hesap dizininin temizlenmesi ve diğer
   Motion uygulamasının sonraki çevrimiçi makbuz kontrolü ayrı kaydedilir.
   Konuk/B verisi korunmalı; log/yedeklerin anında silindiği iddia edilmez.
7. Satış kapalı olduğundan mevcut sürümde satın alma/restore uygulanmaz;
   gerçek store testi geçti denmez. Sonradan açılırsa ayrı güncel karar,
   ürün/sandbox hesapları, makbuz doğrulama, restore, çapraz hesap sızıntısı,
   iptal/expiry/revocation ve ortak Motion+ kapsamı kabul edilmeden açılmaz.

## Yeni ekran setinin somut çekim planı

EN ve TR için, mevcut yetkili native cihaz/simülatörde: Home beş alan girişi;
calisthenics modülleri; DB/KB yolları; üç temel kurs listesi; bir fiziksel
dersin kapalı görev/önkoşul/progression/regression/dinlenme/gösterim bekliyor
durumu; yerel ilerleme. İsim/e-posta gibi özel veriler görünmeyen konuk akışı
kullanılır. Gerçek ekran boyutu ve kaynak/paket SHA her ham PNG ile kaydedilir;
yazı taşması, büyük metin ve ekran okuyucu sırası native kabulünde kontrol edilir.
Host render'ı mağaza/native ekranı diye yeniden etiketlenmez. Kamera izni
istenmez, cihaz silinmez/yeniden oluşturulmaz. Ekran çıktısı mağazaya bu
karar kapsamında yüklenmez.

## Kullanıcının ana oturumda tamamlayacağı adımlar

İlk güvenli giriş adımı: Chrome'da
https://appstoreconnect.apple.com/apps/6794714365/distribution/ios/version/inflight
adresine mevcut Apple hesabıyla giriş/2FA'yı tamamla. Son kontrol login'e döndü;
yeniden sözleşme kabul etme. Bu adım yalnız mağaza durumunu okumayı açar,
uygulama test hesabını açmaz. Paylaşılan Supabase bağlantısında Motion projesi
`aljdbngmeqwmsqhvfeau` görünmeli; mevcut yetkili hesap/organizasyona geçiş ayrı
gereklidir. Bu oturum ilgisiz projeye sorgu çalıştırmadı ve yeni erişim vermedi.

İmza için kullanıcı normal Terminalde yalnız şu salt okunur komutu çalıştırıp
çıkış kodu/çıktıyı ana oturuma iletir:

```sh
/usr/bin/codesign --verify --deep --strict \
  '/Users/mustafakaankocak/Documents/Codex/2026-10-17/task-12/current-packages/ios-ipa-inspection/Payload/Runner.app'
```

Android için önceki otomatik UDP port kapsamı sandbox sözdiziminde uygulanamadı;
build başlamadı. Tek AAB için önerilen yeni kapsam UDP `*:*` bind (sabit
portları da içerir), yalnız loopback paket trafiği/TCP IPC, en çok 20 dakika,
tek process-tree ve mevcut ortak kilittir. Yerel süreçlerin IPC'ye erişebilmesi
riski vardır; dış ağ, yeni credential, kalıcı güvenlik ayarı ve upload yok;
ek provider/CI hizmet bedeli $0. Bu daha geniş kapsam onaysız çalıştırılmaz.
Tam öneri görev kanıtındaki NEXT-AAB-SOLUTION.tr.txt içindedir. En hızlı
alternatif: aynı tek offline AAB işlemini kullanıcının normal Terminalde
mevcut imzalama ayarlarıyla yürütmesi ve paket SHA/imza çıktısını iletmesi;
bu yol da kullanıcı eylemi ve ortak kilit koordinasyonu gerektirir.

## Mağaza alanları

EN/TR liste metni: [listing.json](listing.json), [listing.tr-TR.json](listing.tr-TR.json).
İnceleme notu: [review-notes.en.txt](review-notes.en.txt).
Gizlilik: [account-data-safety-draft.md](account-data-safety-draft.md),
[privacy-review.json](privacy-review.json). Null/bekleyen alanlar No değildir.
Canlı dış silme sayfası içeriği okunmuştur; talep gönderilmedi. Support URL
bu turda doğrulanamadı; kırık olduğu iddia edilmez. SKU'ların tarihsel durumu,
güncel kaynak imzası ve build 2'nin sağlayıcıda kullanılabilirliği yeniden
oturum açılınca salt okunur okunur; ürün oluşturma veya abonelik açma yapılmaz.
Apple/Play yaş/içerik sorularının konsol sonucu tahmin olarak kapatılmaz.
PR/ücretli CI/deploy bağlantısı yoktur; bu turda push veya yayın yapılmadı.
