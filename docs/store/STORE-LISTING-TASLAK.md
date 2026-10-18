# Güncel mağaza metni girişi · 18 Ekim 2026

Yayıma hazırlanacak TR/EN metinlerin kaynağı [listing.json](listing.json) ve
[listing.tr-TR.json](listing.tr-TR.json) dosyalarıdır. Güncel adayda
**56 ders / 10 modül calisthenics**, mevcut DB/KB yolları ve üç ayrı 12 dersli
barbell, halka, el desteği temel kurs taslağı vardır. Yeni 24 fiziksel görev
uzman, gösterim ve öğrenci kabulü bekler. Varlık kimlikleri ve hashleri JSON
içindeki `$` kaynak notlarındadır. Beş alanda tam öğretim hedefi korunur.
Kamera koçluğu, form puanı ve abonelik satışı açık değildir.

Kurs ilerlemesi kullanıcının kendi çalışma kaydıdır; ustalık veya fiziksel öğretim
kabulü değildir. Hesap ve destek/gizlilik metinleri güncel JSON'dan alınır.
Yerel metin, eski ekran görüntüsü veya kaynak testi mağazada kaydedildiği, güncel
imzalı pakette bulunduğu ya da fiziksel cihazda kabul edildiği anlamına gelmez.
Bu bakımda mağaza paneline yazılmadı ve yükleme yapılmadı.

Gönderim ve gerçek hesap/cihaz kontrol paketi:
[RELEASE-REVIEW.tr.md](RELEASE-REVIEW.tr.md). Gizlilik eşlemesi:
[privacy-review.json](privacy-review.json); inceleme notu:
[review-notes.en.txt](review-notes.en.txt). 18 Ekim ASC kontrolü yeniden
giriş istedi; aşağıdaki 17 Ekim durum okuması güncel konsol kanıtı değildir.

## Tarihsel araştırma · aşağıdaki metni yayın metni olarak kullanmayın

Aşağıdaki eski katalog/kamera incelemesi kendi tarihinin kanıtıdır. Eski “bugün”,
“sıradaki” ve simge onayı ifadeleri güncel yayın durumu değildir; yukarıdaki iki
JSON ve kaynaklarına bağlı güncel kabul kullanılır.

# Mağaza Liste Metni — TASLAK (D6, 2026-08-16)

**Makine-okur kaynak:** `docs/store/listing.json`. Bu dosya insan-okur bağlam; metnin
kendisi `listing.json`da, her cümlenin `$`-önekli bir gerekçe alanı var (H-44'ün "yokluk
beyanına bitişik falsification-link" ilkesiyle aynı disiplin — çürütecek/kaynaklayan şey
CÜMLENİN YANINDA durur, ayrı bir belgede değil).

**Gönderim KURUCU kalemi (B7).** Bu yalnız taslak — ASC/Play'e hiçbir şey yüklenmedi,
yüklenmeyecek. Orkestratör `PASS`ı olmadan submit yok.

## Neden bu kadar dar

Kütüphane 31 hareket listeliyor ama bugün yalnız **2**sinin (`bodyweight_squat`, `push_up`)
gerçek bir kimlik ön-koşulu var (`content/library.json`, `status: live`). Mağaza metni
kütüphanenin TAMAMINI değil, bugün ÇALIŞANI baz aldı — `LibraryStrings.libraryCount`'ın
kendi ekranda kullandığı "$total movements · $live open · rest waiting on a measurement"
deseniyle birebir aynı çerçeve.

## Kontrol listesi (her cümle bir kaynağa bağlı)

| İddia | Kaynak |
|---|---|
| Kamerayla, cihazda, hareket gerçekten yapılınca sayar | `lib/app/onboarding_strings.dart` `valueWhatWeDo` (G-213'te bir kez yalan söyleyip düzeltilmiş) |
| Form derecelendirmiyor, canlıda düzeltme yok | Aynı dizge, ikinci yarı |
| Tıbbi değil, koç yerine geçmez, düşmeyi engelleyemez | `valueWhatWeDont`, birebir |
| 31 hareket, 2 açık, 29 ölçüm bekliyor | `LibraryStrings.libraryCount` deseni + `content/library.json` (bu oturumda ölçüldü) |
| Video yüklenmiyor; hesap için ağ kullanılıyor | Kamera akışı cihazda; `lib/app/motion_account_bootstrap.dart` ortak Auth/profil hizmetini başlatıyor |
| İsteğe bağlı ortak hesap var | `lib/app/profile_screen.dart` hesap girişine yönlendiriyor; `lib/app/gravita_app.dart` misafir akışını koruyor |
| Sosyal paylaşım/UGC ve serbest web gezintisi yok | Ortak hesap ekranı gizlilik bağlantısını dış tarayıcıda açabilir; kamera veya seans paylaşım akışı yok |

## Ne YAZILMADI (bilerek)

- **Cihazda-kanıtlı hiçbir cümle** — bu taslak `lib/` + `content/library.json` okumasına
  dayanıyor, gerçek cihazda "description'daki her şey doğru render oluyor" turu AYRI bir
  kalem (D6'nın kapsamı: taslak + ekran görüntüsü, cihaz-üstü metin-doğrulaması değil).
- **"Coach"/"training plan"/kişisel antrenör dili** — `valueWhatWeDont`ün yasakladığı tam
  sınıf, description hiçbir yerde kullanmıyor.
- **Kamera izin gerekçesi hareket adı saymaz.** `ios/Runner/Info.plist` ve
  `en.lproj`/`tr.lproj/InfoPlist.strings` aynı gerçek kullanım sınırını anlatır:
  tam tekrar sayımı, tempo ölçümü, cihazda kalan video ve yerel seans özeti.

## Ekran görüntüleri

`docs/store/screenshots/gravita-hatti-iphone16/` — `gravita-hatti` simülatöründen (UDID
`2F59E2DB-8F02-4D24-BAD6-8313576FAB98`, iPhone 16), `mcp__Claude_Code_iOS_Simulator__control`
`screenshot` eylemiyle. `attach`/`detach` ÇAĞRILMADI (H-46: panel paylaşımlı, cihaz-kapsamlı
`screenshot` güvenli).


## 17 Ekim 2026 · yeni yerel kaynak adayı

EN/TR JSON taslaklarına mevcut DB/KB yolları ve üç ayrı 12 dersli temel kurs taslağı eklendi: barbell, alçak halka, el desteği. 56 calisthenics dersi değişmedi. Yeni 24 fiziksel görev uzman incelemesi, özgün izinli gösterim ve gözlenmiş öğrenci kabulü bekler; okuma bu kapıları açmaz. Yeni görevlerde kalibrasyon tamamlanmadan tekrar/faz/referans ölçümü yoktur. Eğitim sonraki sürüme bırakılmıştır.

Bu yerel ek ASC'ye yazılmadı. 17 Ekim canlı ASC sürümü 1.0.0 / Prepare for Submission, build yok. Final paket, fiziksel cihaz, gerçek hesap/IAP, gizlilik ve yayın kararı açık. Tarihsel screenshotlar yeni 36 dersi göstermez; yeni ekran kabulü ayrıca yapılır.
