# G-082 — `alignedDistinctShare` bir KARE-sayısı vekilidir, SÜRE vekili DEĞİL

**Koordinatör sorusu (M-F-159):** aile hipotezi *"share ≈ süre / medoid-süresi mi?"*
Ostinato'nun guitar verisi share'in pencere SÜRESİYLE neredeyse monoton
gittiğini gösterdi. Gravita'nın iki havuzu bu soruya ayrımcı cevap veriyor.

## Cevap: İKİSİ DE yordar, ama KARE oranı hem daha güçlü hem GEÇERLİ TAVAN

| | pearson(share, **kare** oranı) | pearson(share, **süre** oranı) |
|---|---|---|
| push_up | **+0,991** (spearman +0,971) | +0,947 (+0,899) |
| bodyweight_squat | **+0,970** (spearman +0,973) | +0,935 (+0,918) |

Asıl ayrım korelasyon gücü değil, **tavan geçerliliği**:

| tavan tanımı | doluluk medyanı | <0,70 | **tavanı AŞAN (>1,05)** |
|---|---|---|---|
| push_up · `min(1, frames/medoidFrames)` | 1,000 | 0/36 | **0/36** |
| push_up · `min(1, dur/medoidDur)` | 0,971 | 3/36 | **3/36** |
| squat · `min(1, frames/medoidFrames)` | 0,922 | 0/36 | **0/36** |
| squat · `min(1, dur/medoidDur)` | 0,977 | 1/36 | **4/36** |

**Kare-tavanı hiç aşılmıyor** (mekanik olarak aşılamaz: DTW KARE hizalar).
**Süre-tavanı 3-4 take'te aşılıyor** — yani süre bir tavan DEĞİL, yalnız
gevşek bir vekil.

## Aşan take'lerin sebebi ÖLÇÜLDÜ: fps heterojenliği

**push_up** (etkin fps, bildirilen fps'in ALTINDA — kare düşüşü):
`Renaissance Periodization#w6 r1` 16,0 vs 24 · `FitnessFAQs#w8 r1` 17,0 vs 25 ·
`K boges#w1 r2` 15,6 vs 30. Bu, G-081'de bulduğum 3040 raporsuz ön-süzgeç
düşüşünün buradaki yansıması: kareler düşünce SÜRE örneklem sayısını
OLDUĞUNDAN FAZLA gösteriyor.

**squat** (etkin fps medoidin ÜSTÜNDE): dört THENX take'i ~25,7 fps, medoid
(`Jeff_Nippard_w13_r0`) 107 kare / 4,42 sn = 24,2 fps. Kaynaklar arası fps
farkı (24/25/30) süre oranını kare oranından ayırıyor.

## Sonuç — çekirdek alan tasarımına doğrudan cevap

`share` **büyük ölçüde bir UZUNLUK VEKİLİ** (senin (a) mekanizman), ama
uzunluğun doğru birimi **KARE**, saniye değil. Yani eklenecek normalize alan:

```
capFillShare = alignedDistinctShare / min(1, takeFrames / medoidFrames)
```

Süreyle normalize etmek 3-4 take'te 1,0'ı aşan değerler üretir ve
"doluluk" yorumunu bozar.

**Ostinato verisiyle çelişki YOK, ayrım var:** onların 7 guitar take'i aynı
gün/aynı hat olduğu için fps sabit olsa gerek — sabit fps'te süre ve kare
oranı birbirinin katı olur, o yüzden onların verisi iki denominatörü
AYIRT EDEMEZ. Gravita havuzu ayırt ediyor çünkü (1) kaynaklar arası fps
24/25/30 değişiyor, (2) ön-süzgeç kare düşürüyor. İki veri kümesi aynı
mekanizmayı gösteriyor; hangi birimin doğru olduğunu yalnız bu havuz söylüyor.

## Kanıt
`content/harvest/reference.{push_up,bodyweight_squat}.json` →
`evidenceThickness.takes[*].{frames,durationS,alignedDistinctShare}` +
`result.length` (= medoid kare sayısı; medoid take'i kare sayısı eşitliğinden
bulunur: push_up `K boges#w2 r4`, squat `Jeff_Nippard_w13_r0`).
