# G-078 — Kopyalama imzası push_up'ta POZİTİF · ve kendi `mirrorAgnostic` metriğimin kusuru

**Koordinatör hükmü (M-F-141 hüküm 2):** ters-çevirme hipotezini görünürlük-
koşullu |L−R| ile sına. İmza: *|L−R| görünürlük DÜŞTÜKÇE KÜÇÜLÜYORSA anlaşma
ÜRETİLMİŞTİR.*

İki bulgu çıktı. İkincisini ararken değil, **birincisini doğrularken** buldum.

---

## BULGU A — imza push_up'ta POZİTİF, squat'ta NEGATİF (hipotez DOĞRULANDI)

`tool/copying_signature_probe.dart` · uzak-uzuv görünürlüğü = eklem çiftinin
iki tarafının gerekli-landmark görünürlüklerinin MİNİMUMU (hangi tarafın
kameraya yakın olduğunu varsaymaya gerek yok, kendini tanımlar).

### push_up

| uzak-uzuv görünürlük | mean\|L−R\| | n |
|---|---|---|
| 0,0–0,2 | **12,75°** | 832 868 |
| 0,2–0,4 | 11,83° | 516 525 |
| 0,4–0,6 | 14,49° | 298 432 |
| 0,6–0,8 | 39,08° | 168 193 |
| 0,8–1,0 | **36,83°** | 417 534 |

**Model uzak uzvu GÖRDÜĞÜNDE fark ~37°; GÖREMEDİĞİNDE ~13°'ye çöküyor
(2,9× küçülme).** İmza POZİTİF: fark tam belirsizlik arttığında kayboluyor —
dürüst bir ölçümde tersinin olması gerekirdi.

### bodyweight_squat

| uzak-uzuv görünürlük | mean\|L−R\| | n |
|---|---|---|
| 0,0–0,2 | **44,11°** | 13 590 |
| 0,2–0,4 | 34,26° | 8 410 |
| 0,4–0,6 | 25,77° | 11 923 |
| 0,6–0,8 | 28,89° | 23 062 |
| 0,8–1,0 | **33,42°** | 91 239 |

**Görünürlük düştükçe fark BÜYÜYOR** (33,42° → 44,11°). İmza NEGATİF =
dürüst ölçüm davranışı: belirsizlik arttıkça uyum artmıyor.

> **Ters-çevirme hipotezi DOĞRULANDI.** push_up'ın küçük sol-sağ farkı bir
> SİMETRİ KANITI değil, en azından kısmen **MODEL KÖRLÜĞÜNÜN** eseri. Squat'ın
> büyük farkı ise modelin gerçek belirsizliğinin dürüst ölçümü. İşaretleri
> gerçekten ters okuyorduk.

**Metodolojik beyan:** görünürlük kapısı KASITLI uygulanmadı. Kanonik
`prepareTake` düşük-görünürlüklü kareleri eler / açıları NaN yapar (J-056,
ÜRÜN için doğru) — ama bu probe tam o rejimi inceliyor, kapıyı uygulamak
ölçmek istediğim şeyi silerdi. Açı çıkarımı kanonik `JointAngleExtractor` +
`PoseNormalizer` (formül aynı, kopya yok); yalnız görünürlük-NaN kapısı
atlandı. Buradan ÜRÜN hükmü çıkmaz.

---

## BULGU B — ⚠️ kendi `meanLeftRightDiffDeg` metriğim iki şeyi karıştırıyor

Bulgu A'yı doğrularken şunu fark ettim: probe **`mean|L−R|`** hesaplıyor,
ama referans artefaktına yazdığım `meanLeftRightDiffDeg` **`|mean|`**
hesaplıyor (konsensüs açıları üzerinde). `|E[X]| ≤ E[|X|]` her zaman — yani
ikisi AYNI NİCELİK DEĞİL.

| hareket | take-düzeyi `mean|L−R|` | referansta `|mean|` | şişme oranı |
|---|---|---|---|
| push_up | 19,25° | **5,16°** | **3,73×** |
| bodyweight_squat | 33,13° | **32,26°** | **1,03×** |

**Squat'ta iki sayı neredeyse aynı (1,03×) — push_up'ta referans sayısı 3,73×
daha küçük.** Sebep: `|mean|`, take'ler arasında sol−sağ farkının İŞARETİ
tutarsızsa iptal olur. Yani:

- squat'ta işaret TUTARLI (hep aynı taraf daha bükülü okunuyor) → konsensüste
  korunuyor,
- push_up'ta işaret RASTGELE (model kopyaladığında fark gürültüye düşüyor) →
  konsensüste birbirini yiyor.

**Sonuç: yayımladığım `meanLeftRightDiffDeg` bir "ayna simetrisi" ölçüsü
DEĞİL — büyüklük ile take'ler-arası işaret tutarlılığını KARIŞTIRAN bir
bileşik.** `mirrorAgnostic` bayrağını da bu sayıdan `<7°` eşiğiyle
türetiyordum.

### Bunun neyi etkilediği

- **squat `mirrorAgnostic: false` SAĞLAM** — iki hesap da aynı yeri gösteriyor
  (32,26 ≈ 33,13). Hüküm değişmiyor, ürün etkisi yok.
- **push_up `mirrorAgnostic: true` DAYANAKSIZ KALDI.** 5,16° işaret-iptalinin
  eseri; take düzeyinde gerçek fark 19,25°, modelin GÖRDÜĞÜ karelerde ~37°.
  `<7°` eşiği bu sayıya uygulandığında "ayna-agnostik" demek, ölçmediğim bir
  şeyi iddia etmek oluyor.
- ⚠️ **Bu bayrak gece boyu "6 bağımsız kez doğrulandı" diye kaydedildi**
  (G-056 → G-063 → v0.8.4 → G-072). **Altı koşumun altısı da AYNI hatalı
  işlem sırasını kullandı.** Altı kez aynı yanlış niceliği hesaplamak onu
  doğrulamıyor — G-052'nin ("doğrulayıcının kendisi de denetlenmeli") ve
  G-060'ın ("özetler sessizce bayatlar") birleşimi, bu kez benim kendi
  metriğimde.

### Neden KENDİM DÜZELTMEDİM

`mirrorAgnostic` **M-F-46 kural 7'yi** besliyor (ayna-agnostik olmayan
referanstan taraf-bağlı hüküm çıkmaz) — yani bir AİLE KAPISI. İki seçenek
var ve ikisi de aile kararı:

1. **Metriği düzelt** (`|mean|` → `mean|L−R|`, yani take-düzeyi) ve
   `mirrorAgnostic`i yeniden türet. Sonuç: push_up 19,25° → `<7°` eşiğini
   GEÇEMEZ → push_up `mirrorAgnostic: false` olur. Yayımlı iki referansın da
   taraf-bağlı hüküm yetkisi kalkar.
2. **İki ayrı alan olarak beyan et:** `meanLeftRightDiffDeg` (konsensüs,
   mevcut) + yeni `takeLevelMeanAbsLeftRightDeg` + işaret-tutarlılık oranı;
   `mirrorAgnostic` hangisinden türeyeceği açıkça yazılır.

Seçenek 1 yayımlı bir bayrağı tersine çevirir ve iki app'in referansını
etkiler; seçenek 2 daha bilgilendirici ama eşik sorusunu açık bırakır.
**Karar sende.** Hiçbir dosyada `mirrorAgnostic` değiştirilmedi.

---

## Kanıt / komutlar

```bash
cd packages/gravita_engine && dart run tool/copying_signature_probe.dart
```

Çıktı: `content/harvest/copying-signature.json` (bant tabloları + okuma +
`$visibilityGateDeliberatelyOff` beyanı).

## Koordinatöre — üç sonuç, hükmün istediği gibi ÖLÇÜMDEN SONRA

1. **(i) kanıt-okuma tersinmesi ONAYLANDI:** yandan çekimde küçük |L−R|
   simetri kanıtı DEĞİLDİR — push_up'ta 2,9× çöküş ölçüldü.
2. **(ii) MOCORE_ANATOMICAL kanıt zinciri görünürlük-koşullu şart kazanabilir:**
   probe iki hareketi ZITT yönde ayırıyor, yani ölçüm ayrımcı. Ama bu turda
   anatomik-mod karşılaştırması KOŞULMADI (probe kamera çerçevesinde) —
   zincirin o ayağı hâlâ eksik.
3. **(iii) push_up 5,16°'sine dürüstlük şerhi GEREKLİ** — ve şerhten fazlası
   gerekebilir: Bulgu B, sayının kendisinin yanlış nicelik olduğunu gösteriyor.
