# G-075 — Paket 1b: squat'ın 32,26°'si ÜÇ PROBE'un HİÇBİRİYLE açıklanmadı

**Koordinatör hükmü (M-F-131 hüküm 4):** kaynak-başına
`shoulder_line_foreshortening` ölç, kaynak-başına sol-sağ farkıyla korele et.
Korelasyon çıkarsa 32° projeksiyon artefaktıdır → ölçüm **MOCORE_ANATOMICAL
varsayılan-çevirme** kurucu-kaleminin kanıt zinciri olur (M-F-56).

**SONUÇ: kanıt zinciri ÜRETİLMEDİ.** Üç bağımsız probe da null/kararsız.
Bu, hükmün beklediği sonucun tersi değil — beklediği sonucun **çıkmadığı**.
M-F-56 kalemi bu turdan kanıt ALMIYOR.

## Probe 1 (istenen) — `shoulder_line_foreshortening` × sol-sağ farkı

Kanonik yol: metrik Lissom `lissom-metrics.v1.json`'dan BİREBİR okundu
(`kind=distance_norm`, `plane=frontal`, `frameRef=camera`), `mocore.measures.
evaluate(anatomical=False)` ile hesaplandı — anatomik mod bu bilgiyi tanım
gereği siler (M-F-53), o modda metrik ölür (A9). Sol-sağ farkı Dart tarafında
kanonik `ReferenceCli.prepareTake` ile ölçüldü (aynı kod yolu, kopya yok).

| kaynak | take | kare | ön-kısalma | sol-sağ° |
|---|---|---|---|---|
| Calisthenicmovement | 2 | 220 | **0,1667** | 33,70 |
| FitnessFAQs | 1 | 10 | **1,1211** | 38,62 |
| GMB Fitness (Praxis) | 1 | 62 | 0,8948 | 65,09 |
| Jeff Nippard | 23 | 1879 | 0,6450 | 24,44 |
| Jeremy Ethier | 6 | 649 | 0,6101 | 17,77 |
| K boges | 59 | 3999 | 0,5565 | 19,13 |
| Sebastian Oreb | 4 | 323 | 0,5960 | 41,96 |
| Squat University | 16 | 1874 | 0,6225 | 28,32 |
| Strength Side | 30 | 2566 | 0,5448 | 20,36 |
| THENX | 68 | 4060 | 0,6801 | 46,06 |
| TappBrothers | 1 | 101 | 0,7004 | 29,70 |
| Tom Merrick | 11 | 1941 | 0,5488 | 49,63 |
| WeShape | 12 | 819 | 0,5782 | 18,78 |

Ham korelasyon: **r = +0,342** (n=13) — hipotezin TERSİ yön. **Ama bu sayıyı
raporlamak yanlış olurdu:** dayanıklılık sınaması korelasyonun tamamen
alt-küme seçimine bağlı olduğunu gösterdi.

| alt-küme | n | pearson | spearman |
|---|---|---|---|
| TÜM kaynaklar | 13 | **+0,342** | +0,313 |
| thinEvidence çıkarıldı (FitnessFAQs 10 kare · GMB 62 · TappBrothers 101) | 10 | **−0,034** | +0,030 |
| uç ön-kısalma çıkarıldı (0,167 ve 1,121) | 11 | **+0,655** | +0,409 |
| ikisi de çıkarıldı | 9 | **+0,225** | +0,150 |

**−0,03 ile +0,66 arasında geziniyor.** 2-4 noktayı çıkarmak işareti ve gücü
tamamen değiştiriyor → korelasyon **bilgi taşımıyor**. Sebep açık: 13
kaynağın 10'u dar bir ön-kısalma bandında (0,54-0,70) yığılıyor, yani
YORDAYICIDA VARYANS YOK; gerçek varyansı olan iki nokta da ya çok ince
(10 kare) ya da uç değer.

> Bu, bu defterin tekrar tekrar avladığı desenin yeni bir örneği: **tek bir
> `r` sayısı yayımlanmadan önce alt-küme dayanıklılığı sınanmalı.** İlk
> koşumun "POZİTİF — hipotezin tersi" okuması, thinEvidence'ı atınca sıfıra
> düşüyor. Sayıyı olduğu gibi rapor etmek yanlış bir hükmü belgelemek olurdu.

## Probe 2 (kendi eklediğim teşhis) — uzuv DERİNLİK-AYRIMI × sol-sağ farkı

`shoulder_line_foreshortening` gövdenin dikey eksen etrafındaki dönüşünü
(yaw) ölçer. Ama yandan çekilmiş bir squat'ta sol-sağ farkının asıl sürücüsü
**yakın uzvun uzağı kapatması** — yani kamera eksenindeki DERİNLİK AYRIMI,
gövde yaw'ı değil. Yani istenen probe muhtemelen YANLIŞ EKSENİ ölçüyordu
(vekil-ölçme sınıfı).

Ölçtüm: kalça/diz/ayak-bileği çiftlerinin world-z ayrımı, gövde uzunluğuna
normalize (`mocore.geometry.torso_length`), kaynak-başına ortalama.

| alt-küme | n | pearson | spearman |
|---|---|---|---|
| TÜM kaynaklar | 13 | **−0,045** | −0,154 |
| thinEvidence çıkarıldı | 10 | **−0,194** | +0,006 |

**Null.** Doğru eksen olduğunu düşündüğüm ölçüm de açıklamıyor.

## Probe 3 (kendi eklediğim teşhis) — KOL mu BACAK mı sürüklüyor?

Squat'ta kollar SERBESTTİR (eğitmene göre göğüste/önde/başta/kalçada), yani
kol asimetrisi **gerçek davranıştır**, izdüşüm artefaktı değil. Referansın
`unreliableJoints` listesi de tam olarak kol eklemleriydi
(left/right elbow + forearm). Hipotez: 32,26° kolların ortalamaya
karışmasından geliyor.

| eklem çifti | grup | ort. fark | örnek |
|---|---|---|---|
| upper_arm | **KOL** | **60,95°** | 12368 |
| forearm | **KOL** | **51,84°** | 10973 |
| thigh | bacak | **37,61°** | 17983 |
| hip | bacak | 27,62° | 17983 |
| knee | bacak | 24,90° | 17983 |
| shoulder | **KOL** | 24,13° | 12368 |
| elbow | **KOL** | 21,17° | 10973 |
| shin | bacak | 18,06° | 17983 |

**KOL ortalaması 39,52° · BACAK/GÖVDE ortalaması 27,05°.**

Hipotez **KISMEN** doğrulandı (kollar 1,46× daha yüksek) ama **olguyu
AÇIKLAMIYOR**: kolları tamamen atsak bile bacak/gövde farkı **27,05°**, yani
push_up'ın bütünündeki **5,16°**'nin hâlâ **5 katı**. Yani squat'ın
mirrorAgnostic=false hükmü kolları çıkarınca da geçerli kalır — kol
serbestliği bunun yalnız bir parçası.

## Ne biliyoruz, ne bilmiyoruz

**Biliyoruz:**
- 32,26° kamera-yaw ile açıklanmıyor (probe 1, kararsız/null).
- Uzuv derinlik-ayrımı ile de açıklanmıyor (probe 2, null).
- Kol serbestliği bir kısmını açıklıyor ama bacaklar tek başına 27° (probe 3).
- `mirrorAgnostic: false` hükmü ayakta kalıyor → M-F-46 kural 7 gereği bu
  referanstan taraf-bağlı hüküm çıkmaz. **Ürün etkisi değişmedi.**

**Bilmiyoruz — ve sıradaki en güçlü hipotez BU (ölçülmedi):**
Soruyu ters çevirmek gerekebilir. Belki asıl soru "squat neden 32°?" değil,
**"push_up neden yalnız 5,16°?"** — yandan çekilmiş bir şınavda sol ve sağ
uzuvlar görüntüde neredeyse ÜST ÜSTE düşer; model uzak uzvu göremediğinde
yakın uzvun değerini kopyalamaya/yansıtmaya meyilli olabilir. Öyleyse
push_up'ın küçük farkı **modelin körlüğünün eseri**, squat'ın 32°'si ise
modelin gerçek belirsizliğinin DÜRÜST ölçümü olur — yani işaretler ters
okunuyor olabilir. (J-056'nın "görünmeyen eklem için de sayı üretiyor"
bulgusunun kardeşi.)

Bu **yeni bir ölçüm tasarımı** (push_up ↔ squat karşılaştırmalı, görünürlük
katmanlı) — tek taraflı başlatmadım.

## Yöntem notları (dürüstlük kaydı)

- Probe 1 hükmü koda YAZILMADI: script yön/güç raporluyor, yorumu
  koordinatöre bırakıyor; `$thinEvidence` alanı n=13'ün zayıflığını artefakta
  gömüyor.
- Hiçbir eşik icat edilmedi; hiçbir kapı kurulmadı.
- Probe 2 ve 3 hükümde İSTENMEDİ — teşhis olarak ben ekledim (analiz serbest,
  karar değil). İkisi de yeni bir metrik/eşik tanımlamıyor, mevcut veriden
  türetiliyor.

## Kanıt / komutlar

```bash
cd packages/gravita_engine && dart run tool/per_source_mirror_diff.dart
cd ../.. && python3 tools/mirror_vs_foreshortening.py
```

Çıktılar: `content/harvest/mirror-diff-by-source.bodyweight_squat.json`
(kaynak-başına + `$byJointPair` + `$armVsLeg`) ·
`content/harvest/camera-angle.bodyweight_squat.json` (ön-kısalma + korelasyon
+ `$thinEvidence`).

## Koordinatöre

1. **M-F-56 kanıt zinciri bu turdan BESLENMEDİ** — MOCORE_ANATOMICAL
   varsayılan-çevirme kalemi için bu ölçüm dayanak sağlamıyor (ne lehte ne
   aleyhte; ölçüm gücü yok).
2. **Bacak-taban-bağlılığı için not:** senin "bu kusur olmayabilir"
   uyarın bu turda ayrıştırılamadı — foreshortening null çıktığı için
   "eğitmenler gerçekten 8°-tabanın altında anlaşıyor" ile "projeksiyon
   sıkıştırıyor" ayrımı hâlâ AÇIK.
3. **Sıradaki hipotez** (yukarıdaki ters-çevirme) yeni ölçüm tasarımı —
   yönlendirmeni bekliyorum.
