# Cihaz günü reçetesi (F5, 2026-08-16)

**Amaç:** kurucu telefonunu bağladığında beş dakikada yürünecek, üç adımlı
bir akış. **Kurulum** (adım 2) otomatik/betiklenebilir — **yürüyüş**
(adım 3) kurucunun elini ister (`H-9`: fiziksel cihazda dokunuş MCP ile
sürülemez, simülatör araçları yalnız simülatör listeler).

Şema Ostinato'dan alındı (`docs/device-day/RECIPE.md`, O-160, aile-geneli
emsal — orkestratörün kendi sevki); adımların içeriği Gravita'nın kendisi.

---

## 1 — Ön-uçuş (30 saniye, komut satırından)

```bash
python3 tools/device_day_preflight.py
```

Telefon USB ya da güvenilir Wi-Fi ile bağlıyken koş. Üç şeyi ölçer —
tahmin etmez: geçerli codesign kimliği var mı, `com.yulalab.gravita`
profili var/güncel mi, **bağlı cihazın GERÇEK UDID'si** (`devicectl`'in
kendi eşleşme kimliği DEĞİL — `H-9` dersi, ikisi ayrı değer) profilin
`ProvisionedDevices` listesinde mi.

**Bugün ölçülen durum (2026-08-16, kurucunun eşleşmiş iPhone'u — gerçek
cihaz USB/Wi-Fi ile bağlıydı, betik onu bizzat tespit etti):** ✅ TEMİZ.
UDID `00008120-001804D83E13C01E` zaten kayıtlı, profil `2027-08-13`e
kadar geçerli (Ostinato'nunkiyle AYNI tarih — aynı takım hesabı, aynı
kayıt turu). Cihaz günü bu profil ve bu telefonla yapılırsa **tazeleme
adımına gerek YOK.**

⚠️ Betik `✅ ÖN-UÇUŞ TEMİZ` DEMEZSE, aşağıdaki adım 2'ye geçme —
önce şu komutla profili tazele (Automatic signing kendi üretir, kod
değişmez):

```bash
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Release -destination "id=<GERÇEK-UDID>" \
  -allowProvisioningUpdates build
```

## 2 — Kurulum (tek komut)

```bash
flutter install --release -d <cihaz-adı-veya-id-öneki>
```

**Neden `--release`, `--debug` DEĞİL** (`H-9`/aile ölçümü, bu kod
tabanında da doğrulanmış — `feedback-ios-cihaz-kurulum-imza.md`): Flutter
debug motoru cihazda JIT ister, iOS onu engelliyor — paket kurulur,
süreç başlatılabilir bile görünebilir, ama anında `signal 11` ile ölür.
Yalnız `--release` (AOT derleme) cihazda GERÇEKTEN çalışır. `--release`
zaten `flutter install`ın VARSAYILANI — ekstra bayrak GEREKMEZ, ama
yanlışlıkla `--debug` yazılmasın diye burada adıyla uyarılıyor.

## 3 — Yürüyüş (kurucu eli ister — beklenen kanıt listesi)

Bu turun kendi simülatör ekran görüntülerinden (`docs/store/screenshots/
gravita-hatti-iphone16/`) türetildi — cihazda AYNI ekranların GERÇEKTEN
böyle davrandığını doğrulamak bu reçetenin işi.

| # | Ekran/eylem | Ne YAPILACAK | "Çalışıyor" NASIL görünür | Sorun işareti |
|---|---|---|---|---|
| 1 | Uygulama açılışı | Ana ekrandan `Gravita` ikonuna dokun | Kırmızı zemin + beyaz bükülü-eklem glifiyle açılış ekranı bir an görünür (artık uygulamanın gerçek `#F2EFEE` zeminiyle AYNI tonda geçiş, G-245), sonra "What Gravita is — and isn't" onboarding kartı gelir | Beyaz ekran/kırpışma/çökme (debug paketiyse SIGNAL 11 burada olur) |
| 2 | Onboarding (3 kart) | "Continue" ile ilerlet | "Your phone camera counts your reps…" → "Before you start" (güvenlik) → "Camera access" kartları sırayla | Metinler boş/placeholder görünüyorsa içerik paketi eksik demektir |
| 3 | Kamera izni | "Allow camera access" | Sistem izin diyaloğu ÇIKAR (uygulamanın kendi ekranı DEĞİL) — "Allow" seçilirse gerçek kamera akışına geçilir | İzin diyaloğu HİÇ çıkmazsa `NSCameraUsageDescription` sorunu |
| 4 | Today sekmesi | Onboarding biter, kabuk açılır | "OPEN RIGHT NOW: 2 movements" (Bodyweight Squat, Push-Up) + "CLOSED MOVEMENTS: 29 of 31…" kartları | Sayılar 31/2/29 dışında bir şey gösteriyorsa `content/library.json` paketleme sorunu |
| 5 | Bir hareket seç → canlı seans | "Start"a dokun, Push-Up ya da Bodyweight Squat seç | Canlı kamera görüntüsü ÜZERİNE iskelet-nokta çizimi biner, hareketi yapınca tekrar SAYAR | Kare gelmiyor/donuk görüntü → kamera köprüsü canlılık sorunu (bu turda YALNIZ simülatörde, kamera izni orada otomatik reddedildi — cihaz günü bunun İLK gerçek kanıtı olacak) |
| 6 | Bir tekrar TAM yapma (örn. sığ squat) | Bilerek eksik hareket yap | Rep SAYILMAZ — motor yalnız gerçek hareketi gördüğünde sayar (identity gate) | Her hareket sayılıyorsa kimlik-kapısı devre dışı kalmış demektir (P0) |
| 7 | Seansı bitir | Dur/bitir düğmesi | Progress sekmesinde o hareketin "Reps that count" kartı "Not started"tan gerçek sayıya döner | Kart güncellenmiyorsa `JsonlSessionStore` yazmıyor demektir |
| 8 | Library sekmesi | Alt menüden Library'e dokun | "31 movements · 2 open · 29 waiting on a measurement" + arama kutusu + aile başlıkları (PUSH/PULL/…) | Sayı değişmişse (yeni hareket açıldıysa) bu reçete GÜNCELLENMELİ, kod sorunu değil |
| 9 | Bir hareket detayına gir (Push-Up) | Library'de Push-Up'a dokun | "MEASURED / not built a demonstration" dürüstlük kutusu görünür | Kutu yoksa/boşsa `library_strings.dart` render sorunu |
| 10 | Uygulamayı tamamen kapat, YENİDEN aç | Home'a dön, app switcher'dan kapat, yeniden aç | Onboarding TEKRAR ÇIKMAZ (bir kez tamamlandı, hatırlanır), doğrudan Today'e düşer | Onboarding her seferinde çıkıyorsa `onboarding_store.dart` yazmıyor demektir |

**Bu turda YAPILMAYAN, cihaz günü İLK KEZ ölçülecek olanlar (adıyla,
belirsizlik gizlenmedi):** kamera köprüsünün canlılığı (madde 5-6) —
bu turda simülatörde kamera izni OTOMATİK REDDEDİLDİ (`docs/store/
screenshots/gravita-hatti-iphone16/README.md`), yani GERÇEK bir telefon
kamerasının GERÇEK bir insan gövdesini okuyup okumadığı, ve identity-
kapısının (madde 6: eksik hareketi reddetme) cihazda da aynen çalışıp
çalışmadığı bu proje için **hiç ölçülmedi.** Cihaz günü bunun ilk kanıtı
olacak — reçete bunu bir "son kontrol" değil **asıl soru** olarak
çerçeveliyor.

---

## Kaynaklar

- Ön-uçuş betiği: `tools/device_day_preflight.py`
- İmza/kurulum dersi: kişisel hafıza `feedback-ios-cihaz-kurulum-imza.md`
  (aile çapında `H-9`, Ostinato `O-129`/`O-130`)
- İçerik/dürüstlük zemini: bu reçete `docs/store/screenshots/
  gravita-hatti-iphone16/` ile AYNI ekranları anlatır — simülatörde
  ÇEKİLENLERİN cihazda da GERÇEKTEN böyle davrandığını doğrulamak bu
  reçetenin işi.
