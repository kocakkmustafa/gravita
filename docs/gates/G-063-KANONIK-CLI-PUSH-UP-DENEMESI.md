# G-063 — push_up referansı kanonik CLI (v0.8.2) ile: çalıştı, ama havuz ÇOK küçüldü

> **GÜNCELLEME (v2, koordinatör kararı):** Aşağıdaki v1 bölümü PENCERE-düzeyi
> granüleriteyle (1 kesintisiz-hareket penceresi = 1 take) ölçülmüştü.
> Koordinatör bunu REDDETTİ ve TEKRAR-düzeyi granüleriteyi (ürünün kendi
> rep-FSM'i kesici) zorunlu kıldı — sonuç ve karşılaştırma en altta, "## v2
> — REP-düzeyi (koordinatör kararı, GEÇERLİ SÜRÜM)" başlığında. v1 tarihsel
> kayıt olarak bırakıldı (aynı aracın nasıl evrildiğinin kanıtı).

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

## v2 — REP-düzeyi (koordinatör kararı, GEÇERLİ SÜRÜM)

**Koordinatör hükmü:** "tekrar-sınıfı malzemenin doğal take birimi TEKRARDIR
... ürünün kendi rep-FSM'i kesicidir ... kesme eşiği = zaten isimli 110°
partial_rom." Uygulandı: her derin tekrar (`rom_bottom_angle≤110°`) kendi
`Fixture`'ına kesildi, provenance'a `windowRule: rep_fsm@9b8f0ca
partial_rom=110.0` beyanı gömüldü (hangi kuralla/hangi commit'le kesildiği
izlenebilir).

| | eski (build_reference.dart) | v1 (pencere=take) | **v2 (tekrar=take)** |
|---|---|---|---|
| toplam tekrar (derin/sığ) | — | — | 97 (76/21) |
| contributingTakes | 44 | 7 | **37** |
| distinctSources (eğitmen) | 9 | 4 | **5** |
| excludedOutlierIds | 47 | 22 | 34 |
| cycleSegmentation | yok | notApplied (3/30 periyodik) | **notApplied (1/71 periyodik) — BEKLENEN, tek-tekrarlık fixture aperiyodiktir** |
| meanLeftRightDiffDeg | 5,03° | 4,51° | **4,90°** |
| mirrorAgnostic | true | true | **true (4. bağımsız doğrulama)** |
| unreliableJoints | [] | [trunk_tilt] | **[] (küçük-n artefaktıydı, düzeldi)** |

**v2, v1'den belirgin şekilde daha sağlıklı:** 37/5 hâlâ eskinin (44/9)
altında ama v1'in (7/4) çok üstünde — M-F-38 tabanının rahatça üstünde.
`unreliableJoints` boşaldı (v1'in `[trunk_tilt]`'i küçük-n artefaktıydı).
Çevrim-segmentasyonunun devreye girmemesi artık gerçekten BEKLENEN/dürüst
bir sonuç (koordinatörün öngördüğü gibi) — tek-tekrarlık fixture'lar tanım
gereği periyodik değildir; segmentasyon rep-FSM'siz çok-tekrarlı malzeme
için kalıyor. mirrorAgnostic DÖRDÜNCÜ kez (eski + v1 + v2'nin iki hesabı)
bağımsız doğrulandı (4,3-5,0° bandında istikrarlı).

**Hâlâ karar bekleyen:** 37/5, eskiden (44/9) daha küçük — `reference.
push_up.json`'ı bu artefaktla değiştirmek mi, yoksa havuzu (özellikle 1-2
tekrarlık eğitmenler: Antranik Kizirian, Kayla Itsines, THENX, TappBrothers,
Tom Merrick) yeni hasatla büyütüp sonra mı değiştirmek, karar koordinatörde.
Dosya HENÜZ değiştirilmedi.

## ✅ YAYIMLANDI (koordinatör hükmü M-F-90) — 3 şart karşılandı

Koordinatör: "37/5 kanonik artefakt `reference.push_up.json`'ı DEĞİŞTİRİR" —
üç şartla:

1. **mirrorAgnostic beyanı artefakta girdi:** `$mirrorAgnostic: true`,
   `$meanLeftRightDiffDeg: 4.90`, `$mirrorAgnosticNote` DÖRT bağımsız
   doğrulamayı (5,03° · 4,51° · 4,90°) kayda geçiriyor.
2. **thinEvidence eğitmenler isimlendirildi:** `$thinEvidenceInstructors` —
   Antranik Kizirian (1), Kayla Itsines (1), THENX (1), TappBrothers (1),
   GMB Fitness (Praxis) (2), Tom Merrick (2).
3. **9→5 düşüşün sebebi isimli:** `$instructorDropFromOldReference` —
   **Jeremy Ethier**: hiç derin tekrar üretmedi (ön-filtrede elendi, CLI'ye
   hiç girmedi). **Calisthenicmovement (12), THENX (1), GMB Fitness (Praxis)
   (2)**: derin tekrar ürettiler ama M-F-47 anlaşma-kapısında (14° küme
   toleransı) aykırı sayıldılar. Gelecekteki hasat hedeflemesi: Jeremy
   Ethier için YENİ derin-tekrarlı klip aranmalı; diğer üçü için mevcut
   klipler yeniden gözden geçirilebilir (aykırılık nedeni — kurulum mu stil
   mi — ayrı bir M-F-55(2) sınıflandırması gerektirir, bu turda yapılmadı).

**⚠️ Yan bulgu — sync_provenance.py/validate_catalog.py yeni şemayla
KIRILIYORDU, düzeltildi.** İlk `validate_catalog.py` koşumu **V17'yi
İHLAL ETTİ**: `sync_provenance.py` ve V17'nin kendisi eski düz şemanın
(`instructors`/`tolerances` kök-düzeyinde) alan adlarını okuyordu; kanonik
şema (`result.*`/`tolerance.perJointSource`, TARAF-BAŞINA) hiç eşleşmedi ve
"0 eğitmenden türedi" gibi yanlış sıfırlar üretti. İkisi de düzeltildi
(`_extract()` ortak okuyucu, `sync_provenance.py`'de tanımlı, `validate_
catalog.py` import edip kullanıyor — iki yerde ayrı yorumlanan şema tekrar
sessiz sapma üretmesin diye).

**İkinci yan bulgu — G-014 sayısı 3 varyans/6 taban'dan 0 varyans/9 taban'a
DÜŞTÜ, bu bir REGRESYON DEĞİL daha DÜRÜST bir sayı.** Eski build_reference.
dart PAIR düzeyinde (sol+sağ ortalanmış) tek bir dispersion hesaplıyordu;
kanonik CLI TARAF-BAŞINA hesaplıyor ve yalnız `right_knee` varyans-eşiğinin
üstünde çıktı (floorShare 0,365), `left_knee` taban-bağlı kaldı (0,615).
Pair-düzeyi toleransı "varyans-türetimli" saymak (eski davranış), görünen
tarafın HANGİSİ olduğuna bakılmaksızın bir iddiada bulunuyordu — ADR-003'ün
"görünen taraf" ilkesiyle tutarsız bir iyimserlikti. Yeni kural: **bir çiftin
BİR tarafı bile taban-bağlıysa çift "floor" sayılır** (zayıf halka kadar
güçlü, G-050 ilkesinin taraf-düzeyi uzantısı). G-014 bu yüzden KAPANMADI
(hâlâ 9/9 taban-bağlı) — ama artık doğru sayıyor.

## Kanıt / komutlar

```bash
cd packages/gravita_engine
dart run tool/canonical_push_up_reference.dart   # reference.push_up.json'ı YAZAR
cd ../..
python3 tools/sync_provenance.py                 # katalog provenance'ı senkronlar
python3 tools/validate_catalog.py                # V17 dahil tüm kapılar
```
