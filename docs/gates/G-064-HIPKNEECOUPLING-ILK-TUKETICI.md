# G-064 — hipKneeCoupling: squat kimliğinin İLK gerçek tüketicisi

**Bağlam (M-F-73/80 beşinci-soru):** Lissom rig `perMovement.identity`'ye
`hipKneeCoupling` sinyalini yazmıştı (`deep_squat`, `pearson(hip_flexion_right,
knee_flexion_right)`, `status: provisional`, `min: 0.2`, kendi n=4 ölçümüyle:
iyi kaynaklar +0,56/+0,45/+0,57, çömelme-olmayan kaynak -0,46). Squat kimliği
artık BU sinyal üstünde kapılanacaktı (G-061'in koordinatör nihai hükmü) ama
sinyalin HİÇ tüketicisi yoktu — beşinci canlılık sorusu ("bu kapıya SORAN
var mı?") boştaydı.

## Yöntem

`packages/gravita_engine/tool/hip_knee_coupling_squat.dart` — Gravita'nın 27
squat fixture'ını (16 eğitmen) `measure_knee_symmetry.dart`'ın kademe-D
penceresiyle (FSM-tamamlanmış tekrar ∩ StructuralValidator.plausible) işler;
her eğitmenin `hipAngle`/`kneeAngle` zaman-serisi arasında Pearson r hesaplar.

**Metrik eşdeğerliği notu:** Lissom `RIGHT_SHOULDER-RIGHT_HIP-RIGHT_KNEE` /
`RIGHT_HIP-RIGHT_KNEE-RIGHT_ANKLE` sabit uçları + `frameRef: proximal`
(M-F-54 taksonomisi) kullanıyor. Burada Gravita'nın taraf-agnostik (ADR-003)
GÖRÜNEN-taraf açıları (`MovementMetrics.hipAngle`/`kneeAngle`, düz izotropik
açı) kullanıldı — aynı üç-nokta geometrik iskelet, farklı taraf-seçimi ve
çerçeve-projeksiyonu. Sayı birebir Lissom'unkiyle eşleşmeyebilir; Lissom'un
kendi notu ("ayrım kategorik, ince eşik ayarı değil") bu yaklaşıklığı meşru
kılıyor, ama tam uyum için ileride iki app'in AYNI hesaplamayı paylaşması
gerekecek (rig/çekirdek koordinasyonu, henüz yapılmadı).

## Sonuç

**14/15 eğitmen GEÇTİ, 1 reddedildi** (eşik r≥0,2):

| Eğitmen | n | r | Gate | kneeSymmetry (advisory) |
|---|---|---|---|---|
| K boges | 3272 | 0,990 | ✅ | 18,2° |
| WeShape | 1774 | 0,971 | ✅ | 6,2° |
| Jeremy Ethier | 874 | 0,966 | ✅ | 8,8° |
| Strength Side | 2633 | 0,958 | ✅ | 18,0° |
| THENX | 3566 | 0,951 | ✅ | 23,1° |
| Sebastian Oreb | 179 | 0,951 | ✅ | 15,2° |
| School of Calisthenics | 15 | 0,936 | ✅ (n küçük) | 24,2° |
| Jeff Nippard | 1911 | 0,916 | ✅ | 12,5° |
| Squat University | 2598 | 0,900 | ✅ | 10,2° |
| Minus The Gym | 419 | 0,896 | ✅ | 8,1° |
| GMB Fitness (Praxis) | 512 | 0,858 | ✅ | 12,2° |
| FitnessFAQs | 295 | 0,760 | ✅ | 8,7° |
| Calisthenicmovement | 1278 | 0,456 | ✅ | 32,1° |
| **Tom Merrick** | 3137 | **0,334** | ✅ | **49,8°** |
| **TappBrothers** | 130 | **0,150** | ❌ | 31,3° |
| Vast Fitness Academy | 0 | — | noSignal | — |

**Kritik gözlem — iki sinyal BAĞIMSIZ eksen.** Tom Merrick, kneeSymmetry'de
EN YÜKSEK asimetriye sahipti (G-061'de kare-kare denetimde split-stance
şüphesi doğrulanmıştı) ama hipKneeCoupling'de RAHAT geçiyor (r=0,334). Bu
tutarlı: kneeSymmetry KARE-İÇİ sol-sağ simetriyi (kamera-açısına/oklüzyona
çok duyarlı — G-061) ölçer, hipKneeCoupling ZAMAN-İÇİ kalça-diz eş-güdümünü
(kamera açısından bağımsız, squat'ın asıl mekanik imzası) ölçer. Koordinatörün
G-061 kararı (kneeSymmetry'yi advisory'e indir, hipKneeCoupling'e güven)
bu ölçümle DOĞRULANDI: hipKneeCoupling gerçekten daha sağlam bir sinyal.

**Tek ret (TappBrothers, r=0,150) sınırda:** eşiğin (0,2) hemen altında VE
küçük örneklem (n=130, havuzun en küçüklerinden). Gerçek bir confounder mı
yoksa gürültü mü, bu tek ölçümle kesin ayırt edilemez — Lissom'un kendi
notuyla tutarlı bir hassasiyet sınırı.

## Ne DEĞİŞTİRİLDİ

- `content/harvest/triage-profile.gravita.v2.json`: `bodyweight_squat.
  identity.hipKneeCoupling` eklendi (`status: provisional`, `min: 0.2`,
  basis) — motion-core `8765977` şemasına karşı doğrulandı.
- `content/harvest/hip_knee_coupling.bodyweight_squat.json`: ham gate
  sonuçları (araç bunu üretiyor).
- `content/harvest/identity-triage.bodyweight_squat.json`: GÜNCELLENDİ —
  birincil sınıflandırma artık hipKneeCoupling gate'i (eskiden yalnız
  kneeSymmetry'den türetilmiş danışma etiketleriydi); kneeSymmetry advisory
  olarak yanında duruyor.

`bodyweight_squat.engine.precondition` (katalog, üretim kapısı) HENÜZ
DEĞİŞTİRİLMEDİ — bu ayrı bir karar (hangi koşulun `conditions[]`e yazılacağı,
V15'in `derived` beklediği yer); bu ölçüm yalnız RIG identity sözlüğünü ve
hasat-triyaj sınıflandırmasını besliyor.

## Kanıt / komutlar

```bash
cd packages/gravita_engine
dart run tool/hip_knee_coupling_squat.dart
```
