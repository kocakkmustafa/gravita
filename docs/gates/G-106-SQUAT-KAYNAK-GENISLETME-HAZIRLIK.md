# G-106 — squat kaynak-genişletme HAZIRLIĞI: "daha fazla eğitmen" varsayımı ölçüldü

**Durum:** hazırlık notu — ölçüm turu KOŞULMADI (gerekçe §6). İndirme YOK.
**Tetik:** koordinatör kuyruk maddesi 3 (2026-08-04) — "hasat SLOT'u JabLab'da;
başlık=aday katmanında aday-listeni hazırla (M-F-200 üç-katmanlı huni)".

Bu not, aday listesi üretmeden ÖNCE bir varsayımı sınıyor: *squat'ın
knee/shin/torso toleransları floor-bound kaldı çünkü yeterli eğitmen yok.*
Ölçüm bu varsayımı **desteklemiyor** — havuzda kaynak var, kullanılmıyor.

---

## 1. Ölçülmüş durum — eleme muhasebesi

`content/harvest/reference.bodyweight_squat.json` (ATTESTED, 2026-07-30):

| kalem | sayı |
|---|---|
| havuzdaki take | **227** |
| referansa KATKI veren | **25** |
| `excludedOutlierIds` | **202** |
| `excludedIneligibleIds` | 0 |
| `excludedUnattestedIds` | 0 |
| `excludedNoMeasurableFrameIds` | 0 |
| `$excludedVariantMismatch` | 6 (barbell — G-089/G-091) |

**Eleme neredeyse tamamen tek kapıdan:** aykırı (%89). Uygunluk kapısı artık
HİÇ elemiyor — G-072'nin M-F-120 sınıf-muafiyeti uygulandığından beri
(G-070'te 133 take'i düşüren kapı bu, artık sıfır).

### Kaynak-başına katkı (ölçüldü)

| kaynak | dışlanan | **giren** | havuzdaki ayna-farkı |
|---|---|---|---|
| THENX | 50 | **18** | 46,06° |
| K boges | 59 | **0** | 19,13° |
| Strength Side | 29 | **1** | 20,37° |
| Squat University | 16 | **0** | 28,32° |
| Jeff Nippard | 16 | **2** | 24,44° |
| Tom Merrick | 11 | **0** | 49,63° |
| WeShape | 9 | **3** | 18,78° |
| Sebastian Oreb | 4 | **0** | 41,96° |
| Jeremy Ethier | 4 | **1** | 17,77° |
| Calisthenicmovement | 2 | **0** | 33,70° |
| GMB Fitness (Praxis) | 1 | **0** | 65,09° |
| TappBrothers | 1 | **0** | 29,70° |

**Referansın %72'si tek kaynaktan (THENX 18/25).** Yedi kaynak SIFIR katkılı.

### Toleransın bugünkü hâli

`tolerance.perJointSource` + `floorBoundShare`:

| eklem çifti | sol | sağ | çift sonucu |
|---|---|---|---|
| hip | variance (0,37) | variance (0,45) | **derived** |
| thigh | variance (0,11) | variance (0,37) | **derived** |
| knee | variance (0,32) | **floor (0,53)** | **FLOOR** |
| shin | **floor (0,53)** | variance (0,32) | **FLOOR** |
| trunk_tilt | — | — | **floor (0,63)** |

Zayıf-halka kuralı (M-F-95) gereği bir taraf floor ise çift floor.
`derivedJoints` = `[elbow, forearm, hip, shoulder, thigh, upper_arm]` — yani
**squat form dersinin notlamak isteyeceği üç eklemin üçü de dışarıda**
(K7 bu yüzden dersi kilitli tutuyor; G-094).

---

## 2. KAPATILMIŞ yollar — yeniden açılmasın

İkisi de bu üründe ÖLÇÜLDÜ ve olumsuz çıktı. Tekrar denemek tur harcar:

**(a) Kümeleme toleransını genişletmek — ETKİSİZ (G-069).**
Kapı 14° → 30° (2×) çıkarıldı: *aynı kaynaklar, aynı take'ler, birebir aynı
sapma derecesiyle YİNE reddedildi.* Genişletme kümelenmeyi **hiç**
değiştirmedi. Bu, push_up'taki G-050 bulgusunun TERSİ bir başarısızlık modu:
orada genişletme dağılımı iki katına çıkarmıştı ama küme yine oluşuyordu.
Sapma **kapının değil malzemenin yapısı.**
⚠️ G-069'un sayıları geçerli, TEŞHİSİ G-070'te geri çekildi — o dönemde
uygunluk kapısı havuzun 133'ünü kapıdan önce düşürüyordu. Bugün o kapı sıfır
eliyor, ama *kümelenmeme olgusu* aykırı sayısında (202/227) sürüyor.

**(b) Kamera açısı açıklaması — ÇÜRÜTÜLDÜ.**
`camera-angle.bodyweight_squat.json`: `shoulder_line_foreshortening` ile
ayna-farkı arasında Pearson **0,342** — *pozitif, yani hipotezin TERSİ yönde.*
Artefaktın kendi okuması: "32° kamera açısıyla açıklanamıyor, başka bir sebep
aranmalı". (n=13, zayıf güç — yön göstergesi, kesin hüküm değil.)

---

## 3. Asıl kısıt — HİPOTEZ, ölçülmedi

Tolerans varyanstan türer. Referansın %72'si tek kaynaktan geliyorsa ölçülen
şey büyük ölçüde **o kaynağın iç varyansıdır, eğitmenler-arası anlaşmazlık
değil.** Bu, hip/thigh'ın derived olup knee/shin/torso'nun floor'da kalmasıyla
tutarlı — ama **tutarlılık kanıt değildir**, alternatif açıklamalar duruyor
(§4). Hipotez olarak işaretlenmiştir; §5'in ölçümü bunu sınamak içindir.

**Rakip hipotez (bence daha güçlü): squat popülasyonu ÇOK-MODLU.**
G-069'un "genişletme işe yaramıyor" bulgusu, tek bir konsensüs bulutu olmadığına
işaret eder. Squat'ın geçerli stil ayrımları vardır (ayak genişliği, derinlik
tercihi, gövde eğimi/kalça-baskın vs diz-baskın) ve bunlar tek havuzda karışık
duruyor. Eğer öyleyse **daha fazla eğitmen eklemek kümelenmeyi
İYİLEŞTİRMEZ — kötüleştirir** (her yeni kaynak yeni mod getirir).

Bu, push_up'ta zaten bir kez görülen desenin kardeşidir: **G-053**, şınavda
"stil" sanılan kararlı sapmanın aslında *geniş tutuş varyantı* olabileceğini
buldu ve `styleExcluded` provenance'ıyla ayırdı. Barbell dışlaması (G-089/091)
aynı ailenin ikinci vakasıydı ve **hip+thigh'ı tam da o dışlama derived
yaptı** — yani bu üründe varyant ayırmanın tolerans kazandırdığı ÖLÇÜLMÜŞ bir
emsal var; kaynak eklemenin kazandırdığına dair yok.

---

## 4. Aday katmanı (M-F-200 katman 1) — İNDİRME GEREKTİRMEYEN adaylar ÖNCE

M-F-200'ün kanonik dersi: *"kaynak yok" izlenimi yanlıştı; kaynak vardı, seçim
yöntemi kördü.* Squat'ta bu birebir geçerli — ham landmark havuzu **diskte**:

```
~/motion-harvest/gravita-squat/landmarks-rep-sliced/   41 MB · 234 dosya
```

> ⚠️ **DÜZELTME (G-109 §4):** bu satırda önce
> `~/motion-harvest/gravita/landmarks/ 674 MB · 27 dosya` yazıyordu — **o
> push_up havuzudur.** Squat referansının girdisi yukarıdaki rep-FSM dilimli
> dizindir (`canonical_squat_reference.dart`). Sonuç değişmedi (indirme/slot
> gerekmiyor; G-109 turu bunu koşarak kanıtladı), ama sayı yanlıştı: aracın
> girdi yolunu okumadan komşu dizinden devraldım — kendi defterimdeki G-087
> "dar kapıdan devralınan sayı" deseni.

Yani aşağıdaki adayların hiçbiri indirme, slot veya ağ erişimi gerektirmez.

| # | aday | ne sorar | maliyet |
|---|---|---|---|
| **A1** | **202 aykırının mod yapısı** | Aykırılar tek bulut mu, k>1 küme mi? (k-medoid / ikili mesafe histogramı) | betik, havuz diskte |
| **A2** | **Duruş-genişliği ayrımı** | Ayak/kalça genişliği normalize edilip aykırılıkla ilişkisi — G-053'ün squat karşılığı | betik |
| **A3** | **Sıfır-katkılı 7 kaynağın profili** | K boges (59), Squat University (16), Tom Merrick (11) neden hiç girmiyor — sistematik mi, dağınık mı | betik |
| **A4** | **Tek-kaynak baskınlığının etkisi** | THENX'i çıkarıp yeniden kur: knee/shin/torso derived olur mu? (§3'ün doğrudan sınaması) | betik |

**A4 §3'ün hipotezini doğrudan öldürebilir veya doğrulayabilir** ve en ucuzu.
Sırası: A4 → A1 → A2 → A3.

### Yeni-kaynak profili (yalnız A1-A4 tükendiyse)

İndirme gerekirse aranacak şey **eğitmen sayısı değil, eksik MOD**: yan-profil
kadraj (gövde eğimi ölçülebilsin), tam derinlik, ağırlıksız, tek kişi, kesintisiz
çok tekrar. M-F-200 gereği **başlık aday üretir, hüküm ölçümdedir** — bu profil
bir arama sorgusu değil, bir kabul kapısıdır.

---

## 5. Neden bugün KOŞULMADI

MOCORE_ANATOMICAL hükmü **ÇEVİR** (M-F-225) ve uygulama koordinatörde. Anatomik
mod eklem açısı hesabını değiştirir → varyans değişir → hangi take'in aykırı
olduğu değişir → `derivedJoints` değişir. §4'ün dördü de bu zincire bağlı.

**Çevrimden önce koşulan her ölçüm bayat doğar.** Koordinatör direktifi de
aynı yöndeydi ("bağlı ölçümleri yeniden ÜRETME"). Bu yüzden hazırlık yazıldı,
ölçüm yazılmadı.

**Çevrim sonrası ilk iş:** A4.

---

## 6. Kapanış kanıtı bu notun kendisi DEĞİL

Bu not bir hazırlıktır; hiçbir tolerans, hiçbir ders durumu değişmedi.
`bodyweight_squat` `coming_soon` kalır, form dersi K7 gereği kilitli kalır ve
**bu dürüst durumdur** (G-094). Kilidin `blockedBy` zinciri hâlâ doğrulanıyor —
`validate_library.py` bugün TEMİZ.
