# G-063 — push_up referansı kanonik CLI (v0.8.2) ile: çalıştı, ama havuz ÇOK küçüldü

**Talimat:** push_up referansını Gravita'nın kendi `build_reference.dart`/
`harvest_reps.dart` aracıyla DEĞİL, motion-core'un kanonik `ReferenceCli`'siyle
(v0.8.2, L-139/0.8.0 çevrim-segmentasyonu dahil) yeniden üretmek; sığ-tekrar
dışlamasını İSİMLİ `formErrors.partial_rom` (110°) eşiğiyle uygulamak.

**Araç:** `packages/gravita_engine/tool/canonical_push_up_reference.dart`.

## Yöntem

`ReferenceCli.buildArtifact` fixture-DÜZEYİNDE çalışır (bir `Fixture` = bir
"take"; periyodikse `CyclePeriodEstimator`/`CycleAligner` içeride TEK temsilci
çevrim çıkarır) — Gravita'nın önceki aracı REP-düzeyinde çalışıyordu (her FSM-
tamamlanmış tekrar kendi `ReferenceTake`'iydi, aynı videodan onlarca tekrar
onlarca bağımsız "kaynak" gibi sayılıyordu). Bu iki granülerite FARKLI şeyler:

- Ham 27 push_up landmark dosyası → **638 kesintisiz-hareket penceresi**
  (2sn boşluk kesimi, önceki araçlarla aynı).
- Her pencereye kendi RepEngine'i koşturuldu; pencere **EN AZ BİR** derin
  tekrar (`rom_bottom_angle ≤110°`, formErrors.partial_rom) içeriyorsa
  `Fixture` olarak üretildi, değilse dışlandı (adıyla).
- **638 pencerenin yalnız 30'u** (%4,7) uygun: 595'i (`%98`'i) HİÇ tamamlanmış
  tekrar içermiyordu (konuşma/geçiş — G-043'ün beklediği tam da bu), 12'si
  tekrar içeriyordu ama hepsi sığ.
- Bu 30 pencere `ReferenceCli(allowUnattested:true)` ile işlendi (provenance
  `referenceEligible` bilinçli olarak yazılmadı — rig-triyaj sorusu ayrı,
  artefakt dürüstçe `PROVISIONAL` damgalanıyor, zaten öyleydi).

## Sonuç

| | eski (build_reference.dart) | yeni (kanonik CLI) |
|---|---|---|
| contributingTakes | 44 | **7** |
| distinctSources (eğitmen) | 9 | **4** (M-F-38 tabanına yakın) |
| excludedOutlierIds | 47 | 22 |
| mirrorConfident/gapMeasured | — | false/false (n=30>18, ölçülemez — doğru davranış) |
| cycleSegmentation | yok (kavram yoktu) | **notApplied** — "periyodik tekrar azınlıkta (3/30)" |
| meanLeftRightDiffDeg | 5,03° | **4,51°** (kendi hesabımız — CLI bu alanı taşımıyor) |
| mirrorAgnostic | true | **true** (KORUNDU — G-056 bu granülerite değişikliğinde de tutarlı) |
| unreliableJoints | [] | **[trunk_tilt]** |

**Çevrim-segmentasyonu BEKLENDİĞİ GİBİ devreye GİRMEDİ.** 30 uygun
pencerenin yalnız 3'ü periyodik ölçüldü (çoğunluk değil) → segmentasyon
"notApplied" dedi, malzeme bütün-pencere yoluyla işlendi. Yani "malzemen
periyodik, cycleCount gerçek olur" beklentisi BU granülerite ve BU havuzda
gerçekleşmedi — çoğu uygun pencere zaten TEK bir temiz tekrar civarı
uzunlukta, tekrarlı bir set değil.

**G-056/mirrorAgnostic SAĞLAM çıktı** — tamamen farklı bir pipeline'da
(fixture-düzeyi, rep-düzeyi değil) bile sol-sağ fark endeksi aynı bölgede
(4,51° vs 5,03°) ve `mirrorAgnostic=true` KORUNDU. Bu, G-056'nın yapısal
hükmüne (G-062 ile birlikte) üçüncü bağımsız destek.

## ⚠️ Karar gerektiren gerilim: havuz 44→7 take'e küçüldü

Bu granülerite tercihinin (pencere=take, rep=take değil) MADDİ bir bedeli
var: kullanılabilir referans havuzu **6× küçüldü** ve eğitmen sayısı M-F-38
tabanına (3) yakın kaldı (4). Nedeni muhtemelen basit: build_reference.dart
AYNI videodan çıkan onlarca tekrarı onlarca ayrı "take" sayıyordu (aynı
eğitmenin AYNI setinin farklı tekrarları, bağımsız-kaynak GİBİ davranıyordu);
kanonik CLI bunun yerine "1 video/pencere = 1 kaynak" diyor ve o kaynaktan
TEK bir temsilci alıyor — istatistiksel olarak daha DÜRÜST (M-F-32/G-049'un
"birim eğitmendir, video değil" ilkesinin video-içi analoğu) ama eldeki
havuzda çok daha AZ veri bırakıyor.

**Bunu KENDİM karar veremem** (yeni ölçü/kapı tasarımı + belirsiz-veri
yorumu): `content/harvest/reference.push_up.json` bu 7-take'lik artefaktla
DEĞİŞTİRİLMEDİ — üretilen artefakt yalnız bu raporda, dosyaya yazılmadı.
Olası yönler:
1. **Bu daha ince ama daha dürüst referansı KABUL ET** — 4 eğitmen/7 take
   M-F-38'in tam sınırında, kırılgan ama "yanlış çoğunluk" riski yok.
2. **Granüleriteyi REP-düzeyine geri çek** (her uygun REP kendi sentetik
   `Fixture`'ı olsun, pencere değil) — havuz büyür (muhtemelen eskiye yakın)
   ama çevrim-segmentasyonu HİÇ tetiklenmez (tek-çevrimlik fixture'lar
   periyodik sayılmaz) — "0.8.0 devreye girecek" beklentisinden vazgeçilir.
3. **Havuzu genişlet** — `~/motion-harvest/gravita/landmarks`'a yeni push_up
   fixture'ları hasat et (K boges 8 pencereyle en zengin kaynak; benzerlerini
   ara), sonra kanonik CLI'yi yeniden koş.

## Kanıt / komutlar

```bash
cd packages/gravita_engine
dart run tool/canonical_push_up_reference.dart
```
