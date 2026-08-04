# G-115 — (b) çekim-düzeyi tarama: temiz çift YOK; B4 take düzeyinde gürültülü

**Yetki:** koordinatör M-F-243 hükmü (b) — bedava, havuz diskte, indirme yok.
**Sonuç:** iki aday bulundu, **ikisi de gürültü tabanının altında kaldı.**
İndirme yapılmadı, ölçüm ön-kaydı yazılmadı.

---

## 1. Önce kendi ölçümümde bir kusur: `value_range` kapısı yoktu

Tarama sırasında B4'te **5,27** gibi değerler çıktı — omuz arası ÷ gövde
uzunluğu için fiziksel olarak imkânsız (gövde uzunluğu ~0'a düşünce oran
patlıyor). `MetricDef.value_range` doc'unun tam uyardığı sınıf:

> *"ölçülen veriyi süzer. İkincisi olmadan izleme artefaktları referansa
> sızar — Lissom'da diz fleksiyonu 0-3° ölçüldü … trunk_lateral_tilt 180°
> verdi (L-107)."*

`[0,05 – 2,0]` kapısı eklendi: **234 take → 2 artefakt elendi.**
Aday listesi **değişmedi** — yani artefaktlar sonucu bozmuyordu, ama kapı
yine de doğru yerdeydi (ve sahte "en büyük boşluk" değerlerini siliyor).

---

## 2. Çekim-çifti adayları (video-içi B4 ayrıklığı)

Ölçüt (önceden ilan): take'lerin B4 değerleri sıralanır, en büyük ardışık
boşluk bulunur; **boşluk ≥ 0,25 ve her iki tarafta ≥ 2 take** → aday.

| video | kanal | boşluk | kanıt sınıfı |
|---|---|---|---|
| `gcNh17Ckjgg` | Jeremy Ethier | 0,347 | **kişi-sabiti-muhtemel** (metadata temiz) |
| `sdeQjm7avi8` | Jeff Nippard | 0,345 | **KİRLİ** — açıklamada `ft.` |

19 videonun yalnız ikisi eşiği geçti.

---

## 3. 🔴 Ama iki aday da GÜRÜLTÜ TABANININ ALTINDA

**Gürültü tabanı nereden geliyor:** aynı **pencere** = saniyeler arayla
ardışık tekrarlar. Kadraj o sürede değişemez, dolayısıyla pencere-içi yayılım
**ölçümün kendi gürültüsüdür.**

| ölçek | n | medyan yayılım | p90 | maks |
|---|---|---|---|---|
| **pencere-içi (gürültü)** | 33 | **0,145** | **0,463** | 1,011 |
| video-içi | 15 | 0,542 | 0,810 | 1,011 |

**Oran 3,73×** — video-içi yayılım toplu düzeyde gürültü tabanının belirgin
üstünde. *B4 küme düzeyinde sinyal taşıyor.*

**Ama tek take düzeyinde taşımıyor, ve adaylar tam oraya düşüyor:**

- İki adayın boşluğu **0,345 / 0,347** → gürültü **p90'ı 0,463'ün ALTINDA.**
- Üstelik adayların kendi pencereleri **gürültü listesinin tepesinde**:
  `gcNh17Ckjgg w15` yayılım **0,720** (2.), `sdeQjm7avi8 w12` **0,701** (3.).
- Yani her iki adayda da düşük/yüksek grupları **aynı pencere kesiyor**
  (Ethier w15: 0,13 ↔ 0,85 · Nippard w12: 0,14 ↔ 0,84) — saniyeler arayla,
  aynı çekimde.

**Hüküm: "çekim çifti" değil, ölçüm gürültüsü.** Basit açıklama yeterli;
kadraj hipotezine gerek yok. **(b) yolu çıkmadı.**

---

## 4. ⚠️ Bunun G-111'e etkisi — kendi kanıtımı zayıflatıyorum

G-111'de tek confound-kesicim Jeff Nippard'ın kanal-içi kontrastıydı:
**0,945 / 0,949 ↔ 0,596**, fark **0,349**. O zaman "n=3, işaret sayılır kanıt
sayılmaz" demiştim. **Şimdi nedeni ölçüldü:** o fark da gürültü p90'ının
(0,463) altında. Yani zayıflığı yalnız n'den değil, **ölçüm gürültüsünden**
geliyordu.

**Ayakta kalan:** B4'ün **küme düzeyi** ayrımı (23 vs 69 take, AUC 1,000,
OVL 0,000, iki uzayda) — toplu ölçüm gürültüyü ortalıyor ve 3,73× oran bunu
destekliyor. **Düşen:** B4'ten **tek take veya küçük-n kanal-içi** kadraj
okuma. Confound hâlâ kesilmedi ve artık kesicisi de yok.

---

## 5. Ne yapılmadı

İndirme yok (izin kullanılmadı). Ölçüm ön-kaydı yok (ölçülecek temiz çift
çıkmadı). Hüküm yok, dışlama yok. `bodyweight_squat` `coming_soon`, form
dersi kilitli, `validate_library` TEMİZ.

## 6. Okuma

Havuz bu ayrımı **take düzeyinde taşıyacak çözünürlükte değil.** Kalan iki
yol:

- **(a) indirme (≤2 çift):** dış kaynakta "aynı kişi + aynı stil + iki kadraj
  + pitch varyasyonu" kombinasyonunu bulmak zor — kanallar tek kurulum
  kullanıyor; bu turda 13 kanalın 9'u tek videolu, kalan 4'ünde de kadraj
  kontrastı ya yok ya kişi sabiti kirli.
- **(c) iki-telefon çekimi (manuel liste, M-F-13 opsiyonel):** aynı kişi,
  aynı stil, iki kadraj, **pitch dahil** — confound'u tek çekimde keser ve
  gürültü sorunu da ortadan kalkar (kontrollü kadraj, bilinen kurulum).

Ölçüm tarafında elimde kaldıraç kalmadı: bu bir **veri** eksiği, yöntem
eksiği değil.
