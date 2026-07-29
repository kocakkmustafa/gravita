# M-F-38 Yeterlilik Kapısı — Pilot Raporu (push_up)

**Tarih:** 2026-07-29 · **Hareket:** `push_up` · **Kaynak:** 10 eğitmen, ~78k kare
**Karar:** 🔴 **KAPI KAPALI** — eşikler muhafazakâr + `provisional` kalıyor.

> Bu rapor bir turda verilen "kapı AÇIK" hükmünü **geri alır**. Sayım doğruydu,
> sayılan şey yanlıştı.

---

## 1. Ne ölçüldü

M-F-38 varyans-türetimi için ≥3 eğitmen × ≥3 temiz tekrar ister. Pilot üç
aşamada koştu: pencere-histerezis taraması → tekrar toplama → **M-F-47
küme-anlaşma kapısı**. Üçüncü aşama ilk ikisini çürüttü.

### 1.1 Pencere-histerezis taraması (G-041)

| varyant | tekrar | ≥3 veren |
|---|---:|---:|
| taban (10/10 landmark, köprü 0.5 sn) | 3 | 0/10 |
| histerezis 1.0 sn | 8 | 0/10 |
| histerezis 2.0 sn | 9 | 0/10 |
| 8/10 + zorunlu-çekirdek | 64 | 3/10 |
| **8/10 + histerezis 2.0 sn** | **85** | **6/10** |

Histerezis tek başına 3×, küme daraltması 21× kazandırdı — darboğaz histerezis
değildi. Kazanan yapılandırma uygulandı ve kapı "AÇIK" ilan edildi.

### 1.2 M-F-47 küme-anlaşma kapısı — hükmü çürüten ölçüm

M-F-47, kaynak tepe-değerlerinin skorlama tabanı (≤14°) içinde anlaşmasını
şart koşar. Önce tepe-değer tanımı düzeltildi: `Rep.extremeAngleDeg`
karşılaştırılabilir DEĞİL — çevrim hangi uçtan başladıysa uç onun karşıtıdır
(üstten başlayanda min, alttan başlayanda maks), yani aynı sütunda 8° ile 179°
yan yana durur ve bu bir anlaşmazlık değil, **iki farklı büyüklüğün aynı ada
yazılmasıdır**. Ayrıca uç, çevrim boyunca görülen tek karelik min/maks'tır: tek
bozuk kare ROM hükmünü zehirler.

Her tekrarın tam açı izi çıkarıldı, tepe değer **yüzdelikle** (p10) yeniden
ölçüldü:

| eğitmen medyanı (ALT p10) | 19° | 46° | 53° | 55° | 55° | 67° | 81° | 99° | 101° | 151° |
|---|---|---|---|---|---|---|---|---|---|---|

**Yayılım 132°** (eşik 14°). Üstelik ham minimumlarda 0°–15° arası dirsek
açıları var — anatomik olarak imkânsız. Bu bir eğitmen anlaşmazlığı değil,
bir **ölçüm geçerliliği** sorunu.

---

## 2. Kök neden — G-043: FSM hareketi değil, salınımı sayar

İki aday sınandı:

**(a) Foreshortening** (kameraya uzanan kol projeksiyonda kısalır, açısı keyfî
olur). Ön kol/üst kol projeksiyon oranı ile alt-tepe arasında r = **+0.31**;
bant medyanları 55° → 69° → 76° → 99° biçiminde tekdüze artıyor. **Gerçek ama
ikincil** bir etken; tek başına kapıyı 26°'nin altına indiremedi.

**(b) Hareket kimliği.** Gövde ekseninin yataya göre eğimi ölçüldü:

| gövde eğimi | tekrar | ALT p10 medyanı |
|---|---:|---:|
| 0–15° (yatay = şınav) | 10 | 99° |
| 15–30° | 6 | 81° |
| 30–50° | 4 | 75° |
| **50–90° (dik = ayakta)** | **65** | **55°** |

**85 tekrarın 65'i (%76) ayakta duran insanlardan geldi.** THENX tek videodan 58
"tekrar" verdi, gövde eğimi 87°. Jeremy Ethier 89°, GMB 87°, Antranik 79°.

Sebep yapısal: tekrar FSM'i **sinyal ekleminin salınımını** sayar, hareketi
değil. Konuşurken el hareketi yapan bir eğitmenin dirseği de 155°↔100° arasında
gezinir ve FSM bunu şınavdan ayırt edemez. Güven kapısı "net görüyor muyum",
yapısal denetim "bu bir vücut mu" sorusunu cevaplar; **hiçbiri "bu vücut ŞINAV
mı yapıyor" sorusunu cevaplamaz.**

### Neden üründe patlamadı, hasatta patladı

Ürün bu kapıyı **bedava** alır: kullanıcı hareketi seçer ve
`camera.calibrationGate` pozisyona girmesini şart koşar. Hasatta böyle bir beyan
**yoktur** — eğitmen videoya "şimdi şınav yapıyorum" demez.

> **Genel kural:** ürünün çalışma zamanında bedavaya sahip olduğu her varsayım,
> hasatta açık bir ÖLÇÜME dönüşmek zorundadır. Bu tek yönlü bir tercüme değil,
> hasat hattının kuruluş şartıdır.

---

## 3. Uygulanan düzeltme

`engine.precondition` sözleşmesi (kural = versiyonlu config, ADR-004):

```json
"precondition": {
  "status": "derived",
  "conditions": [{"metric": "torso_angle_from_vertical", "op": ">=", "value": 60}]
}
```

* **Motor** (`RepEngine`): güven kapısı → yapısal denetim → **hareket kimliği** →
  açı okuma. Ölçülemeyen ön koşul "geçti" sayılmaz (fail-closed). Üründe de
  geçerli: kalibrasyonu atlayan her yol artık sahte sayım üretemez.
* **Eşik gerekçesi:** şınavın gövdesi tanımı gereği yatay; 60° = yataydan en çok
  30° sapma (metrik `noiseBand` 5°, `camera.setup=side45` ve tripod yüksekliği
  görünür eğim katar). **Eşik ölçüme UYDURULMADI** — kalan eğitmen sayısını en
  çoklamak için oynatılmadı.
* **V15 değişmezi:** her hareket ön koşulunu `derived`/`pending` olarak BEYAN
  eder; tekrar çıkarımı yapılmış her hareket `derived` olmak zorundadır. Boş
  liste ile "henüz bakmadık" ayrı alanlarda durur — ikisini aynı göstermek
  sessiz deliğin ta kendisidir.
* **Üretim noktasında kapı:** `harvest_reps.dart` türetilmemiş ön koşulla
  çıkarım yapmayı reddeder (exit 65). Artefaktı sonradan elemek yerine hiç
  üretmemek — bir tur boyunca 85 el hareketi tekrar sanıldı.
* **Regresyon testi:** ayakta 170°↔80° salınım → 0 tekrar; aynı salınım yatay
  gövdeyle → 5 tekrar. Kapı ayrım yapıyor, körleştirmiyor.

---

## 4. Düzeltme sonrası dürüst sayım

| kaynak | eğitmen | tekrar | uç açı (medyan) |
|---|---|---:|---|
| GxW9MAMQSv0 | FitnessFAQs | **4** | 71° |
| 5aRHy5ZPjwk | Renaissance Periodization | **3** | 74° |
| yvgp8R0fbWg | Tom Merrick | 2 | 77° |
| -w6r23P-fy8 | Calisthenicmovement | 1 | 59° |
| MO10KOoQx5E · _eKHSsHky5U · v3sJMaB7q1E | Jeremy Ethier · THENX · TappBrothers | 1 | — |
| Ggb2rXUL5kg · Ua7B2q21UHg · kKHxpbBGiuM | K boges · Antranik · GMB | 0 | — |

**13 tekrar · ≥3 veren eğitmen: 2/10 → M-F-38 KAPALI** (≥3 gerekli).

Kalanların **kalitesi** bambaşka: 59°/71°/74°/77°, yayılım 18°. Gerçek şınav
dibi burada. Yani hat çalışıyor, veri yetmiyor — doğru teşhis bu.

---

## 5. Sonuç ve kalan iş

* **G-014 KAPANMADI.** `provisional` eşikler yerinde kalır; `ReferenceBuilder`
  varyans-türetimi çalıştırılmadı (`minTakes: 3` zaten reddederdi — çekirdeğin
  kapısı da aynı yöne bakıyor).
* **M-F-48 (take-sırası bağımsızlığı) sınanmadı** — build hiç koşmadı. Referans
  üretimi başladığında ilk iş olarak koşulacak.
* **G-044 (yeni, açık):** metrik-başına geçerlilik katmanı. Foreshortening
  gerçek bir etken (r = +0.31) ama hareket kimliğinden AYRI bir sorudur: kimlik
  "bu şınav mı", geçerlilik "bu metrik bu karede ölçülebilir mi". G-042/M-F-48
  ilkesinin doğal devamı; çekirdek düzeyinde iş gerektirir.
* **Kuyruk genişletmesi gerekiyor:** 2 eğitmen 3'e çıkmalı. Mevcut havuzda
  kapıyı geçen 4. aday yok; triyaj profiline **gövde eğimi ön-filtresi** eklenip
  yeni eğitmen aranmalı — böylece ayakta-konuşan videolar indirilmeden elenir.
* **`bodyweight_squat`** kuyrukta ama ön koşulu `pending`. Squat'ta gövde dik
  olduğu için ayrım ölçütü farklı (diz fleksiyonu + simetri); ölçüm kanıtı
  olmadan eşik **uydurulmadı**.

**Doğrulama:** 69/69 test yeşil · `dart analyze` temiz · doğrulayıcı 15
değişmez, 0 hata.
