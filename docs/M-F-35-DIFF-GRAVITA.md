# M-F-35 Faz-Config Taslağı — Gravita diff'i

**Tarih:** 2026-07-29 (tur 6) · **Kaynak:** motion-core `docs/40-FAZ-CONFIG-SEMASI-TASLAK.md` v1
**Karşılaştırılan:** `content/schema/movement.schema.json` + `packages/gravita_engine` (20 hareket, 48 test yeşil)

> Taslak "sessizlik = onay" diyor. Aşağıdakiler Gravita'nın **çalışan** motorunda
> ifade edilen ama taslakta karşılığı olmayan şeyler. Sıralama: ürünü bozma
> riskine göre.

---

## D1 (P0) — Döngüsel teknik / tekrar sayımı kavramı YOK

**Taslakta:** faz makinesi `terminal?: bool` ile biter → bir **deneme** üretir.
**Gravita'da:** 12 şınav = aynı fazlardan 12 kez geçmek. Motorun sayım birimi
**tam çevrim**: başlangıç ucu → karşı uç → başlangıç ucu.

Taslakta bir tekniğin döngüsel olduğunu, çevrimin nerede tamamlandığını ve
çevrimler arasında neyin sıfırlandığını söyleyecek alan yok. Bu yalnız Gravita'yı
ilgilendirmiyor: JabLab'ın tekrarlı yumrukları da aynı kavrama muhtaç.

**Öneri:** teknik düzeyinde
```jsonc
"cyclic": true,
"repCompletedOn": "<fazId>",      // bu faza DÖNÜŞ bir tekrar tamamlar
"resetBetweenReps": ["..."]        // çevrimler arası sıfırlanan biriktiriciler
```
Sıfırlananın açıkça yazılması şart: bizde uç-açı biriktiricisi (`extreme`)
çevrim başında sıfırlanmazsa ikinci tekrarın ROM hükmü birincinin uç değerini
taşır — sessiz ve fark edilmesi zor bir hata.

## D2 (P0) — Faz-giriş eşiği ile KALİTE hedefi aynı şey değil

**Taslakta:** faz `enter` koşulu tek bir eşik; kalite hedefi için yer yok.
**Gravita'da** bu ikisi **bilerek farklı**:

| | şınav |
|---|---|
| Faz girişi (`phases.bottom.angleMax`) | 100° — tekrar SAYILIR |
| Kalite hedefi (`romTarget.bottomAngleMax`) | 95° — "yeterince derin" HÜKMÜ |

Ayrım olmazsa iki kötü seçenekten birine düşülür: ya sığ tekrar hiç sayılmaz
(kullanıcı 12 tekrar yapar, uygulama 4 gösterir — güveni yok eder), ya da
sayılır ve "iyi" muamelesi görür (yaptığı işi abartırız). Gravita bilerek
**sayar ama hükümde ayırır**.

**Öneri:** faza `qualityTarget?: { metric, op, value, label }` — geçiş
koşulundan ayrı, `measureHere` ile birlikte okunur.

## D3 (P1) — "Bu faz skorlanmaz" (checkpoint) bayrağı YOK

**Taslakta:** her faz eşit; skorlanmayan faz kavramı yok.
**Gravita'da** burpee'nin `jump_up` fazı `checkpointOnly`: patlayıcı faz
20-30 fps'te 1-2 kare + blur olduğu için **sıçrama yüksekliği ölçülmez**;
sıçramanın gerçekleştiği ve inişin yumuşaklığı checkpoint olarak değerlendirilir
(G-006 ölçümü: yarışma hızındaki taklada kare 94-112 arası poz HİÇ üretilemedi).

Bu bir aile dürüstlük kuralı ("blur'lu fazlar checkpoint koçluğu olarak açık" —
standart §8) ama config'te ifade edilemiyor. İfade edilemeyen kural, uygulanmaz.

**Öneri:** faz düzeyinde `scoring: "full" | "checkpoint" | "none"` + gerekçe alanı.

## D4 (P1) — Metrik ad uzayının TARAF politikası tanımsız

**Taslakta:** `metric := { metric, op, value }` — metrik bir isim.
**Gravita'da** `elbow_angle` "modelin sol/sağ etiketine göre" değil **görünen
taraf zincirine göre** çözülür (ADR-003 / M-F-06; D1'de model etiketlerinin
ters-duruşta takas olduğu ölçüldü).

Taslak bunu söylemezse her app kendi politikasını uydurur ve biri kaçınılmaz
olarak ham `LEFT_*`/`RIGHT_*` kullanır — D1'in yasakladığı şey.

**Öneri:** metrik kayıt defterinde zorunlu alan
`sideResolution: "visible" | "midline" | "bilateral" | "n/a"`.

## D5 (P1) — Metrik kayıt defterinde `range` ve `noiseBand` zorunlu değil

Taslak §2.8 "bilinmeyen metrik = sert hata" diyor, ama metriğin **birimi,
fiziksel aralığı ve gürültü bandı** zorunlu değil. İkisi de bizde gerçek hata
yakaladı:

- **G-016:** diz açısı eşiği >165°, marjı çarpımsal (%25) hesaplamıştım → 206°
  gerekiyordu; **diz 180°'yi geçemez**. `range` olmadan bu doğrulanamaz.
- **G-024 (zaten §2.6'da):** taban değeri; ama taban ancak `noiseBand` ile
  birlikte anlamlı — "taban 6,5°, bant 4°" ile "taban 6,5°, bant 0,5°" farklı
  eşikler gerektirir.

**Öneri:** metrik kaydı `{unit, range:[lo,hi], noiseBand, baseline, sideResolution}`
zorunlu; doğrulayıcı eksikse reddeder.

---

## Doğrulayıcı değişmez önerisi (taslak §2'ye ek)

**#9 — Karşıt uç koşulları BİRBİRİNİ DIŞLAMALI.** Aynı metriğin iki zıt ucunu
tanımlayan koşullar aynı anda doğru olamaz. Bizde bu V11: `angleMin ≤ angleMax`
olan config, her karede iki uçta birden sayılır ve motor **durmadan tekrar
üretir**. İki hareketimde (dead bug, calf raise) gerçekten oldu; JSON "makul"
göründüğü için gözden kaçtı, betik yakaladı.

Genel biçimi: bir metrik üzerinde `gte a` ve `lte b` koşulları varsa `a > b`
zorunlu (aralarında ölü bant olmalı).

**#10 (daha zayıf öneri) — Ölü metrik yasağı.** Lissom M-L-05: sabit değer üreten
metrik tanımı yükleme anında reddedilmeli. Taslakta yok; §2.3'ün ("doğru duruşta
guard tetiklenmez") tamamlayıcısı — o kural yanlış-pozitifi, bu kural
hiçbir-şey-ölçmemeyi yakalar.

---

## Taslakta ifade EDİLEBİLEN, sorun olmayanlar

`timeoutMs` zorunluluğu (bizde V9) · `signalConditioning`/`cutoffHz` (bizde V10)
· uç-tipi tanımanın derleme katmanı olarak korunması · saniye-birimli delta
(bizde kullanılmıyor, sorun yok) · `requiredLandmarks` · abort semantiği.

**Kapsam dışı bıraktıklarım (itiraz değil, not):** form-hata kuralları
(`detect`+`perturbation`+`priority`+`cue`) ve ölçüm sözleşmesi
(`measured`/`notMeasured`/`scoreDisplay`) bu şemada yok — bunlar faz-config
değil, komşu şemalar. Yalnız şunu not ederim: `detect` ile `perturbation`ın
**aynı yerde** durması bizde bir değişmez (G-013/G-015/G-016) — fixture'ın
sınadığı toleransı gerçekten aştığı ancak ikisi yan yanayken betikle
denetlenebiliyor.

---

# v2 ONAY TURU — kalan üç pürüz (2026-07-29, tur 7)

v2 beş boşluğu da kapattı. `movement.schema.json` → v2 çevirisini 20 hareket
üzerinde denedim; **rep-FSM, statik tutuş ve çok-faz zincirlerinin tamamı
çevrilebiliyor.** Kalan pürüzler v2'nin YENİ hata katmanından (§3) doğuyor —
v1'de bu katman olmadığı için "komşu şema" diye geçmiştim, artık var ve iki
alanı eksik.

## F1 (P1) — Hata kaydında ÖNCELİK alanı yok

`hata := {code, evaluateAt, koşul, cooldownMs?, maxPerRound?, suppressesJudgement?}`

`maxPerRound` **kaç** hata söyleneceğini sınırlıyor ama **hangisinin** söyleneceğini
söylemiyor. Aynı karede iki hata birden ateşlendiğinde sıralama yoksa seçim
keyfî olur.

Bizde bu bir ürün kuralı, kozmetik değil: *aynı anda EN FAZLA bir düzeltme* ve
sıra **güvenlik > engelleyici > denge > büyük hiza > küçük form > optimizasyon**
(plan §9). Squat'ta aynı anda "yeterince derin değil" (blocking) ve "bel
yuvarlanıyor" (safety) ateşlenirse **güvenlik önce söylenmeli** — testimiz bunu
sabitliyor.

**Öneri:** `priority: safety|blocking|balance|major_alignment|minor_form|optimization`
(veya sayısal rank). Sesli koçun tek-düzeltme disiplini bu alan olmadan
uygulanamaz.

## F2 (P1) — `perturbation` hata kaydında yok → detect↔fixture bağı kopuyor

Bizde tespit kuralı ile onu üreten bozulma **aynı kayıtta** durur:

```jsonc
{ "id": "hip_sag",
  "detect":      { "metric": "line_deviation_deg", "op": ">", "value": 14 },
  "perturbation":{ "metric": "line_deviation_deg", "targetValue": 22 } }
```

Yan yana olmalarının sebebi estetik değil: nöbetçi betik **perturbasyonun eşiği
gerçekten aştığını** ancak ikisini birlikte görünce denetleyebiliyor (G-013 /
G-015 `targetValue` / G-016 `noiseBand`). Ayrılırlarsa Choreia'nın C-011 tuzağı
geri gelir — fixture toleransın içinde kalır ve test **hiçbir şeyi sınamadan**
yeşil yanar.

**Öneri:** hata kaydına `perturbation: {metric, targetValue, via?}` + değişmez
**#11**: *perturbasyon hedefi, tespit eşiğini metriğin `noiseBand`ı kadar
aşmalıdır.* (v2'de `noiseBand` zaten zorunlu — değişmez bedava geliyor.)

## F3 (P2) — Varyanta bağlı ATLANABİLİR faz yok

Faz kaydında `optional` yok. Burpee'de `chest_to_floor` fazı varyanta göre
zorunlu ya da atlanabilir; zinciri baştan sona kopyalayıp ikinci bir teknik
tanımlamak tek fazlık fark için pahalı.

**Öneri:** `optional?: bool` (veya `requiredInVariants: [...]`). `branchProfiles`
beklenen DEĞERİ branşa göre değiştiriyor; buradaki ihtiyaç fazın VARLIĞI.

## Pürüz olmayan, teyit

`cyclic`/`repCompletedOn`/`resetBetweenReps` → tam karşılık · faz `quality`
bloku → `romTarget` · `checkpoint: true` → `checkpointOnly` · `sideResolution`
→ `signal.side: "visible"` · metrik `range`/`noiseBand`/`baseline` → metrics.json
· değişmez #9 → V11 · #10 → ölü-metrik.

**Not:** `measurementContract` (dürüstlük kutusu) hâlâ v2 dışında ve bu doğru —
faz-config değil, sunum sözleşmesi. Yalnız `gateableMetrics` (G-006: patlayıcı
faz metrikleri progresyon kapısı OLAMAZ) `checkpoint: true`'dan tam türetilemiyor;
app-side kalmasında sakınca görmüyorum, not olarak bırakıyorum.
