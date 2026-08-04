# G-120 — Kamera entegrasyonu: push_up CANLI yolu

**Yetki:** kurucu direktifi 2026-08-05 → koordinatör M-F-263.
**Pin:** `f13bdc93b2eae2f741bfcdb4c9270a88e5d75e5d`
(= `motion_core-v0.11.0` **ve** `motion_camera-v0.1.2`, tek commit).
**Kapılar:** motor 128/128 · kabuk **59/59** (40→59) · analyze temiz ·
validate_library TEMİZ + self-test 19/19 · validate_catalog 0 hata ·
replay 8 ateşlenen/0 ölü · **iOS sim + Android debug DERLENDİ**.

> ## ⚠️ CİHAZDA DOĞRULANMADI
> Bu turun hiçbir beyanı "cihazda kanıtlı" demez. Gerçek kamera + MediaPipe
> çıkarımı **isimli release-gate**tir (M-F-263): fps, ısı, gerçek landmark
> güveni, izin diyaloğunun gerçek akışı ve saat alanı ölçülmedi.
> Simülatörde iOS kamerası **yoktur** — aşağıdaki izin ekranı o yüzden
> gerçek bir donanım kanıtı değil, **dürüst hâlin** kanıtıdır.

---

## 1. Pin çifti ve nöbetlerin DÖNÜŞÜMÜ

Üç ref birden aynı commit: kabuk `motion_core` · kabuk `motion_camera` ·
motor `motion_core`. Plugin core'u **path** ile çekiyor, farklı ref pub'a
aynı paket için iki kaynak gösterirdi (J-071).

**İki eski nöbet kırıldı ve YERİNE GEÇEN kuralla değiştirildi — silinmedi:**

| eski nöbet | neden kırıldı | yerine |
|---|---|---|
| `ref` bir **sürüm TAG'i** olmalı | tag adı pub tarafında çözülmüyor ("incompatible … from path") | `ref` **TAM-40-SHA** olmalı |
| `motion_camera` **HENÜZ yok** | kamera bağlandı | **ÜÇLÜ pin eşitliği** |

Eklenen üçüncü nöbet: model asset listesinde **var**, git'te **yok**, fetch
betiği **mevcut** (yokluk+varlık ikizi tek testte).

## 2. Model pini

`assets/models/pose_landmarker_full.v1.task` (9 MB) — **git'te değil**
(`.gitignore`), `tool/fetch_pose_model.sh` aile hattından kopyalar ve
**SHA-256 doğrular**. `modelId` her zarfa damgalanıyor: bir model takası
bir seansı sessizce yeniden yorumlayamaz. `latest` yasak (M-L-01: aynı
boyut, farklı hash).

## 3. Canlı zincir

```
frames() [push] → EnvelopeDriver.load → OrientationAwarePoseSource.next [pull]
                → RepEngine.addFrame → Rep listesi
```

`LiveSessionRunner` bu zinciri **ekrandan ayrı** tutuyor; ekran yalnız izin
ister, kamerayı açar, akışı runner'a verir ve hâli çizer.

**Yönelim beklentisi ÜRÜNDEN geliyor ve gerekçesi kayıtlı:** push-up gövdesi
yataydır, çekirdeğin `observedOrientation`ı yatay gövdede `null` döner
("yatan bir vücudun ileri süreceği dikey yönelim yoktur"). `exactly(upright)`
seçildi; `ambiguous()` her kareye **çift çıkarım** maliyeti bindirir ve
burada ayırt edilecek iki yönelim yok. Hareketin gerçekten yapıldığını
yönelim değil **kimlik kapısı** söyler (torso ≥60°, G-043) — o motorda.

**Kare boyutu OTURUMDAN alınıyor** (`CameraSessionInfo.width/height`), sabit
yazılmadı: izotropik düzeltme buna bağlı ve yanlış boyut açıları sessizce
kaydırırdı (J-028).

## 4. Dürüst hâller — TİPLİ

`LiveState`: `LiveIdle` · `LiveStarting` · `LiveRunning(reps, personVisible,
framesSeen)` · `LiveFailed(CameraFailure?, detail)`.

- **"Kimse yok" bir ARIZA DEĞİL** — `LiveRunning` içinde ayrı bir bayrak.
  İkisini aynı hâle koymak "kamera bozuk" ile "geri çekil" farkını silerdi.
- **Tanınmayan arıza `null` failure** taşır — bilinmeyeni bilinen bir arızaya
  haritalamak yalan olurdu.
- **Ayrıntı gizlenmez, ikincilleştirilir** (G-102 dersi).
- Her `CameraFailure` **ayrı** başlık + gövde alıyor (test: iki arıza aynı
  cümleyi paylaşamaz — biri diğerinin arkasına saklanırdı).

## 5. Testler (40 → 59)

**Canlı yol (8, kamerasız ama TAKLİTSİZ):** gerçek `LiveSessionRunner`,
gerçek `EnvelopeDriver`, gerçek `OrientationAwarePoseSource`, gerçek
`RepEngine`. Sahte olan tek şey zarfların **kaynağı** (sentetik iskelet).
- gerçek tekrar dizisi canlı yoldan geçince **sayılıyor** (3/3);
- **pozitif ikiz**: sığ tekrarlar **sayılmıyor**;
- kişi yokken çökmüyor ve tekrar **uydurmuyor**, görülmeyen kareler yine
  **payda**ya giriyor;
- kişi kaybolup dönünce hâl **geri dönüyor** (yapışkan değil).

⚠️ **Bu süit bir kez beni yakaladı:** ilk "sığ tekrar" dizimde basamaklar
sabitti (150/120/100) ve `bottom: 140` hiçbir şeyi değiştirmiyordu — ara
basamak 100 zaten dip eşiğini (116°) geçiyordu. Yani "sığ" dizim aslında
**derin** bir tekrardı ve motor onu haklı olarak saydı. **Testim kırıktı,
motor değil.** Basamaklar artık `bottom`dan türetiliyor.

**Yüzey (11):** her arıza ayrı cümle · bilinmeyen de adlandırılıyor · izin
metni gizliliği söylüyor · "0 rep" yazmak yerine ne beklendiği söyleniyor ·
kalibrasyon beyanı kapının **davranışını** anlatıyor · hâller birbirinin
yerine geçmiyor.

## 6. Ekran kanıtı (simülatör)

| kanıt | ne gösteriyor |
|---|---|
| `g120-hal-1-giris-fab.png` | canlı seans girişi (FAB) — **ölü buton değil**: yalnız kimlik ön koşulu `derived` olan harekette çiziliyor |
| `g120-hal-3-izin-reddi.png` | **"Camera access is off"** + gizlilik cümlesi (*"video stays on this device and never leaves it"*) + ikincilleştirilmiş teknik ayrıntı + yeniden dene |

Canlı seans **idle** ekranı da görüldü: kadraj talimatı (katalog
`camera.setup: side45` ile tutarlı) + kalibrasyon kapısı beyanı + Start.

## 7. Platform duvarları (aşıldı, kayıtlı)

1. **iOS deployment target 13.0 → 14.0** — plugin MediaPipeTasksVision
   0.10.21 pini gereği 14.0 istiyor.
2. **`use_frameworks!` → `:linkage => :static`** — MediaPipe **statik**
   xcframework dağıtıyor, dinamik linkleme CocoaPods tarafından reddediliyor.
   Pin M-L-02 gereği sabit, çözüm bizim tarafta. (JabLab J-071 emsali.)
3. **CocoaPods UTF-8** — `LANG=en_US.UTF-8` olmadan `pod install` düşüyor.
   Makine ortamı sorunu, kod değil; komut satırında verildi.

## 8. Değişmeyen

`identityGapShare` **rapor-only** (p90 eşiği cihaz-günü iki-popülasyon
verisini bekliyor — kendi kuralım). Form-notu dersi **kilitli** kalıyor:
kamera onu **açmaz**, çünkü kilit ölçüm eksikliğinden (G-094) geliyor,
kameradan değil. `bodyweight_squat` `coming_soon`.
