# G-061 — kneeAngleAsymmetry dağılım ölçümü (bodyweight_squat)

**Amaç:** rig `perMovement.identity.kneeSymmetry` (M-F-60/63, motion-core `cdaa74f`)
için `status`/`basis`/`max` üçlüsünü ÖLÇÜMDEN türetmek — 27 landmark fixture
(16 eğitmen, `~/motion-harvest/gravita-squat/landmarks/`).

**Araç:** `packages/gravita_engine/tool/measure_knee_symmetry.dart` — ürünün
GERÇEK motorunu (RepEngine + MovementMetrics) koşturur, paralel bir Python/
heuristic yeniden yazımı DEĞİLDİR (M-F-21/25). Bilinçli olarak
`preconditionDerived` kilidinden geçmez: bu araç kilidi AÇACAK ölçümü üretiyor
(tavuk-yumurta) — referans/yeterlilik iddiası yapmaz, dosyaya yazmaz.

## Sonuç: **eşik ÖLÇÜMDEN türetilemedi. `status: pending` kalır.**

Dört kademe ölçüldü (en gevşekten en sıkıya):

| Kademe | n | mean | p50 | p90 | p95 | p99 | max |
|---|---|---|---|---|---|---|---|
| A) tüm yargılanabilir kare | 169.489 | 30,08° | 13,23° | 101,64° | 121,36° | 133,53° | 175,24° |
| B) hareket-penceresi | 169.489 | 30,08° | 13,23° | 101,64° | 121,36° | 133,53° | 175,24° |
| C) FSM-tamamlanmış TEKRAR | 33.262 | 24,89° | 13,76° | 63,31° | 84,79° | 125,29° | 171,93° |
| D) C ∩ StructuralValidator.plausible | 22.593 | 21,02° | 10,03° | 54,58° | 76,51° | 119,32° | 167,74° |

C/D, `content/catalog/w1/bodyweight_squat.json`'ın kendi FSM'i (stand≥165°→
bottom≤116°→stand) tamamladığı tekrarlarla sınırlıdır — konuşan/yürüyen
kesitleri büyük ölçüde eler (ayrıntı: metrics.dart `kneeAngleAsymmetry` doc'u).
StructuralValidator (D) bilateral kemik-uzunluğu + eklem-oranı + zamansal
süreklilik kontrol eder; ölçülebilir ama mütevazı bir iyileşme verir (mean
24,9°→21,0°).

**Kritik bulgu — kademe C/D bile TEK bir eşiğe yakınsamıyor.** Eğitmen başına
(D, dünya-koordinatı ile tekrarlandı, aşağıya bakın) ortalama **5,5°'den
47°'ye** (>8×) dağılıyor:

```
WeShape                 mean= 6,17°  p95=18,16°  max= 74,92°
Minus The Gym           mean= 8,08°  p95=11,89°  max=102,89°
Jeremy Ethier           mean= 8,78°  p95=45,56°  max= 77,46°
FitnessFAQs             mean= 8,66°  p95=29,67°  max=122,79°
Squat University        mean=10,24°  p95=44,42°  max=128,36°
GMB Fitness (Praxis)    mean=12,22°  p95=46,12°  max= 73,34°
Jeff Nippard            mean=12,51°  p95=52,53°  max=113,39°
Sebastian Oreb          mean=15,22°  p95=81,90°  max=106,60°
Strength Side           mean=17,99°  p95=47,99°  max= 99,16°
K boges                 mean=18,17°  p95=54,23°  max= 67,33°
THENX                   mean=23,06°  p95=60,15°  max=112,31°
School of Calisthenics  mean=24,24°  p95=49,03°  max= 52,87° (n=15, düşük güven)
Calisthenicmovement     mean=32,13°  p95=85,98°  max=167,74°
TappBrothers            mean=31,32°  p95=99,27°  max=101,80°
Tom Merrick             mean=49,82°  p95=127,72° max=153,74°
```

**Kamera-projeksiyonu hipotezi SINANDI ve TEK BAŞINA yetersiz bulundu.**
`metrics.dart`'ın kendi doc'u (`toIsotropic`) offline referans için DÜNYA
(world) koordinatını önerir — 2D görüntü-düzlemi açıları kamera açısına göre
bükülür. Fixture'ların `world` alanı (3D, metrik) kullanılarak aynı ölçüm
tekrarlandı (ayrı script, `scratchpad/diag_world_vs_image.py` — commit
edilmedi, tek seferlik):

```
                    n_img  img_mean img_p95   n_world world_mean world_p95
WeShape             10047     5,51   20,54     10047       6,63    19,14
Tom Merrick         58817    46,95  128,64     58817      41,07    97,72
OVERALL            177191    25,79  118,92    177191      21,36    86,98
```

World-koordinatı ortalamayı hafifçe düşürür (25,8°→21,4°) ama **eğitmenler
arası 8× fark KAPANMIYOR** — yani asıl kaynak salt 2D-projeksiyon bükülmesi
değil.

**Karesel örnekleme (Tom Merrick, en yüksek ortalama) ne gösteriyor:**
tek bir klip içinde asimetri saniyeler içinde 1°'den 122°'ye sıçrıyor
(ör. t=202,78s: sol diz 162° / sağ diz 39,5° — bir bacak neredeyse düz,
öteki derin bükülü). Bu, simetrik iki-bacaklı bir squat'ın gürültüsü değil;
tek-bacak/split-stance bir kesitin (ayrık squat, ağırlık aktarımı, bacak-
uzatma varyasyonu) tutorial içine KARIŞTIĞINA işaret ediyor. Metriğin kendi
tasarım amacı da bu ("squat'ta iki diz BİRLİKTE bükülür, ötekilerde ayrışır")
— yani metrik muhtemelen İŞİNİ YAPIYOR, ama havuzdaki her video saf bir
bilateral-squat akışı değil.

**Havuzlanmış histogram (world, 10° kutular) tek-tepeli/uzun-kuyruklu —
build_reference.dart'ın `classifyOutlier`'da bulduğu türden temiz bir iki-
kümeli boşluk YOK:**

```
  0-10°: 86.079 ############################################################
 10-20°: 39.776 ###########################
 20-30°: 14.044 #########
 30-40°:  6.652 ####
 ...  (0-110° arası tekdüze azalan, doğal bir eşik-boşluğu belirmiyor)
```

## Neden `status: provisional` DEĞİL, `pending`

Rig doğrulayıcısı (`harvest_rig/harvest.py` cdaa74f) `pending` dışı her
durumda `basis` + en az bir sınır (`min`/`max`) zorunlu kılıyor. Bir sayı
yazmak, bu ölçümün ürettiği asıl sonucu (dağılımın NET bir eşiğe
yakınsamadığı) gizler — tam da G-050/G-052'nin uyardığı sınıf: sayı "ölçüldü"
görünür ama taşıdığı iddia (bu eşik squat'ı confounder'lardan ayırır) hiç
sınanmadı, çünkü **karşılaştırma sınıfı (lunge/step-up/yürüyüş fixture'ı)
henüz hasat edilmedi.** Bir eşiğin "confounder'ları eler" iddiası, yalnız
squat-kendi-dağılımına bakarak doğrulanamaz.

## Koordinatöre taşınan karar (YÜKSELTME — belirsiz-veri yorumu)

Üç seçenek, hiçbiri tek başına "doğru" değil, seçim tasarım kararı:

1. **Karşıt-sınıf hasadı bekle:** lunge/step-up/walking'den birkaç fixture
   hasat et, kneeAngleAsymmetry'yi İKİ sınıfta ölç, eşiği AYIRIM noktasından
   (confounder'ın en düşüğü ile squat'ın en yükseği arasında) türet — aile
   sözleşmesinin normal yolu (M-F-38/47 deseni), ama zaman maliyeti var.
2. **Fazı daralt:** yalnız rep'in BOTTOM ucuna (extremeAngleDeg civarı, ör.
   son %20 pencere) bakılırsa kontaminasyon (yürüme/geçiş kareleri) azalabilir
   — ucuz ama ayrı bir ölçüm gerektirir, ben denemedim (kapsam dışı bıraktım,
   YÜKSELTME kapsamında karar bekliyor).
3. **kneeSymmetry'yi advisory'e indir, hipKneeCoupling'e (Lissom) güven:**
   M-F-60 zaten iki sinyalin BİRLİKTE kullanılmasını öngörüyordu; belki
   kneeSymmetry tek başına gate-worthy değil ve yalnız hipKneeCoupling ile
   BİRLEŞİK bir skorda (ör. ikisi de "confounder" derse reddet) anlamlı.

**Bu üç seçenek arasında karar YÖNLENDİRME KURALI gereği koordinatöre
bırakıldı** (yeni ölçü/kapı tasarımı + belirsiz-veri yorumu = kendi kararım
değil).

## Kanıt / komutlar

```bash
cd packages/gravita_engine
dart run tool/measure_knee_symmetry.dart   # tam çıktı yukarıdaki tablo
```
