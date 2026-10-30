# Güncel mağaza metni girişi · 18 Ekim 2026

Yayıma hazırlanacak TR/EN metinlerin kaynağı [listing.json](listing.json) ve
[listing.tr-TR.json](listing.tr-TR.json) dosyalarıdır. Güncel adayda
**beş beceri alanında 7 kurs / 117 ders** vardır: **56 ders / 10 modül
calisthenics**, üç DB/KB yolu (yazılı yol 12, tutuş 11, geçişler 2) ve üç ayrı
12 dersli barbell, halka, el desteği temel kursu. Yeni 24 fiziksel görev
uzman, gösterim ve öğrenci kabulü bekler. Varlık kimlikleri ve hashleri JSON
içindeki `$` kaynak notlarındadır.

**Satış (2026-10-26 metni, GRV-04):** ilk sürümde abonelik açıktır (Gravita +
Motion+). Paywall A: her kursun ilk bölümü ücretsiz, toplam **117 dersin 44'ü**
(Y4-1); kalan dersler ve bağımsız pratik (program oluşturma, yeni seans kaydı)
abonelikle; ilerleme, kayıtlı program ve geçmiş her zaman okunur. Deneme süresi
metinde iddia edilmez, mağaza gösterir. `tools/validate_store_listing.py` kurs,
ders ve ücretsiz ders iddialarını kaynaktan yeniden sayar. Kamera koçluğu ve
form puanı açık değildir; etkileşimli beceri ağacı vaat edilmez.

**14 dil (2026-10-27, K-6):** EN/TR'ye ek 12 çeviri taslağı
`listing.<dil>.json` (es-419, pt-BR, de, fr, ja, ar, it, ko, id, pl, hi,
zh-Hans); her biri EN kaynağın olgularını paragraf paragraf taşır, mağaza yerel
kodları `$storeLocales` içindedir, kamera gerekçesi o dilin `InfoPlist.strings`
metnidir. Dersler yalnız İngilizce ve Türkçedir; çeviriler bunu açıkça söyler.
`test/store_listing_locales_test.dart` alan sınırlarını, sayıları ve URL'leri
denetler. Anadili, hukuk ve mağaza incelemesi UNRUN. Barbell/halka/el desteği
kursları yetişkinler ve gözetimli 13–17 yaş gençler içindir (GRV-08 i).

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
- **Kamera izin gerekçesi önce kapalı olduğunu söyler.** `ios/Runner/Info.plist` ve
  14 dilin `InfoPlist.strings` dosyası (2026-10-30, JabLab kalıbı): kamera koçluğu
  bu sürümde kapalı; ileride ayrıca açılırsa cihaz üstünde hareket geri bildirimi;
  görüntü ve vücut konumu yüklenmez veya saklanmaz; oturum geçmişi cihazda kalır.
  Tekrar sayımı ve tempo ölçümü vaat edilmez.

## Ekran görüntüleri

`docs/store/screenshots/gravita-hatti-iphone16/` — `gravita-hatti` simülatöründen (UDID
`2F59E2DB-8F02-4D24-BAD6-8313576FAB98`, iPhone 16), `mcp__Claude_Code_iOS_Simulator__control`
`screenshot` eylemiyle. `attach`/`detach` ÇAĞRILMADI (H-46: panel paylaşımlı, cihaz-kapsamlı
`screenshot` güvenli).


## 17 Ekim 2026 · yeni yerel kaynak adayı

EN/TR JSON taslaklarına mevcut DB/KB yolları ve üç ayrı 12 dersli temel kurs taslağı eklendi: barbell, alçak halka, el desteği. 56 calisthenics dersi değişmedi. Yeni 24 fiziksel görev uzman incelemesi, özgün izinli gösterim ve gözlenmiş öğrenci kabulü bekler; okuma bu kapıları açmaz. Yeni görevlerde kalibrasyon tamamlanmadan tekrar/faz/referans ölçümü yoktur. Eğitim sonraki sürüme bırakılmıştır.

Bu yerel ek ASC'ye yazılmadı. 17 Ekim canlı ASC sürümü 1.0.0 / Prepare for Submission, build yok. Final paket, fiziksel cihaz, gerçek hesap/IAP, gizlilik ve yayın kararı açık. Tarihsel screenshotlar yeni 36 dersi göstermez; yeni ekran kabulü ayrıca yapılır.
