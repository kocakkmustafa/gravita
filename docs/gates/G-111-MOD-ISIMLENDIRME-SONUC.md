# G-111 — MOD-İSİMLENDİRME SONUÇ: ayrıştıran boyut **omuz hattı kısalması**

**Ön-kayıt:** `G-110-MOD-ISIMLENDIRME-ON-KAYIT.md`, sonuçlardan önce commit
(`fe11f20`) · **frameBasis:** `camera` · **havuz (beyanlı):**
`~/motion-harvest/gravita-squat/landmarks-rep-sliced` — 234 dosya / 41 MB
**Yayımlı artefakt değiştirilmedi.** Çıktı: scratch, probe damgalı.

Küme: **M-THENX n=23 · M-KBOGES n=69** (örtüşen 2 çıkarıldı) · ölçülemeyen 0.

---

## 1. Sonuç tablosu — iki uzayda birden

Ön-kayıt eşikleri (değiştirilmedi): AYRIŞTIRICI = OVL ≤ 0,40 **ve**
|AUC−0,5| ≥ 0,30 · AYRIŞTIRMAYAN = OVL ≥ 0,70 **veya** |AUC−0,5| ≤ 0,10.

| boyut | uzay | OVL | AUC | perm-p | hüküm |
|---|---|---|---|---|---|
| **B4 omuz hattı kısalması** | **world** | **0,000** | **1,000** | **0,0000** | **AYRIŞTIRICI** |
| **B4** | **lm** | **0,000** | **1,000** | **0,0000** | **AYRIŞTIRICI** |
| B1 duruş genişliği | world | 0,188 | 0,152 | 0,0000 | AYRIŞTIRICI |
| B1 | lm | 0,261 | 0,455 | 0,5200 | **AYRIŞTIRMAYAN** |
| B2 derinlik (diz açısı) | world | 0,464 | 0,407 | 0,1700 | AYRIŞTIRMAYAN |
| B2 | lm | 0,304 | 0,798 | 0,0000 | **BELİRSİZ** |
| B3 kalça/diz baskınlık | world | 0,174 | 0,423 | 0,2600 | AYRIŞTIRMAYAN |
| B3 | lm | 0,478 | 0,510 | 0,8300 | AYRIŞTIRMAYAN |

### Tek isimlendirilebilir boyut: **B4**

Kuyruklar (world): **M-THENX p10/50/90 = 0,921 / 1,104 / 1,338** ·
**M-KBOGES = 0,610 / 0,651 / 0,674**. Aralıklar **hiç kesişmiyor**.

**B1 ve B2 İSİMLENDİRİLMEZ — iki uzay çelişiyor.** B1 world'de ayrıştırıcı,
`lm`'de ayrışmayan (perm-p 0,52); B2 tam tersi. Ön-kayıt bu sağlamayı tam da
bunun için koymuştu. B1'in world'deki ayrışması büyük olasılıkla **payda
etkisi**: B1 = ayak arası ÷ omuz arası, ve omuz arası (B4'ün payı) kümeler
arasında zaten ~1,7× farklı — yani B1, B4'ün türevi olabilir. Bağımsız boyut
sayılamaz.

---

## 2. B4 nedir — ve ne DEĞİLDİR

Ölçülen: **omuz arası mesafe ÷ omuz-kalça uzunluğu**, dip karesinde.
Bu, gövdenin kameraya göre **yönelimi**yle küçülen bir orandır: önden
bakışta omuz hattı geniş, yandan bakışta dar.

**M-THENX ≈ 1,10 (geniş omuz hattı) · M-KBOGES ≈ 0,65 (dar omuz hattı).**

### ⚠️ "Kamera açısı" hükmü KURULMUYOR — üç gerekçe

1. **Dolaylı vekil.** `camera-angle.bodyweight_squat.json`'un kendi uyarısı:
   *"transvers rotasyon tek kameradan güvenilir geri çıkarılamaz — DOLAYLI
   vekil, açı değil; nitel bant olarak okunur."* Aynı büyüklüğü ölçüp
   "kamera açısı" demek o uyarıyı çiğner.
2. **Bağımsız artefakt DOĞRULAMIYOR.** Aynı dosyadaki kaynak-başına
   `shoulderLineForeshortening`: **THENX 0,6801 · K boges 0,5565** — birbirine
   çok yakın, benim küme farkım (1,10 vs 0,65) kadar ayrık değil. İki sayı
   doğrudan karşılaştırılamaz (farklı normalizasyon; onlarki **kaynak**
   ortalaması ve tüm kareler, benimki **küme** ve dip karesi) — ama bu, "bağımsız
   doğrulama var" demeyi engeller. Ayrışma, kanalın tamamında değil **referansa
   katkı veren alt kümesinde** görünüyor.
3. **Alternatif açıklamalar elenmedi:** gövde rotasyonu (kişinin duruşu),
   vücut tipi, kol pozisyonu da omuz hattını kısaltır.

**Dürüst ad:** *"gövdenin kameraya göre yönelimi (omuz hattı kısalmasıyla
ölçülen)"* — kamera kurulumu **en olası** açıklamadır, kanıtlanmış değil.

---

## 3. 🔴 CONFOUND — zayıflatıldı, ELENMEDİ

Kümeler kanallarca baskın: M-THENX = THENX 18 + WeShape 3 + Jeff Nippard 2 ·
M-KBOGES = K boges 59 + Strength Side 9 + Jeff Nippard 1.

**Küme ≈ kanal olduğu sürece, herhangi bir kanal-sabiti (stüdyo kadrajı,
kamera kurulumu, çekim alışkanlığı) mükemmel ayrışma üretir — ve permütasyon
testi bunu YAKALAYAMAZ**, çünkü etiketleri karıştırır ama kanal yapısını
bozmaz. perm-p = 0 bu confound'a karşı kanıt değildir.

**Kanal-içi kontrol** (tek elde edilebilir test): aynı kanalın take'leri iki
kümeye dağılıyorsa, B4 onların arasında da ayrışmalı.

| kanal | M-THENX | M-KBOGES |
|---|---|---|
| **Jeff Nippard** | **2 take: 0,945 · 0,949** | **1 take: 0,596** |
| K boges | — | 59 (medyan 0,654) |
| THENX | 18 (medyan 1,140) | — |
| WeShape | 3 (medyan 1,082) | — |
| Strength Side | — | 9 (medyan 0,615) |

**Yalnız BİR kanal iki kümede birden var (n=3).** O kanalda B4 küme etiketine
göre ayrışıyor (0,95 ↔ 0,60) — yani B4 salt kanal kimliği **değil**, take
düzeyinde bir özellik. Aynı eğitmenin farklı videoları farklı kadrajlarda.

**Ama n=3 bir işarettir, kanıt değildir.** Confound zayıfladı, elenmedi. Bunu
kesmek için aynı kanalın çok sayıda take'inin iki moda dağıldığı bir vaka
gerekir; havuzda yok.

---

## 4. İsimli maliyet (şart 4) — karar anında görünsün

| | M-THENX (geniş omuz hattı) | M-KBOGES (dar omuz hattı) |
|---|---|---|
| tolerans | **14 varyans / 3 taban** | 5 varyans / 12 taban |
| hip · thigh | **variance** | floor |
| knee / shin / trunk_tilt | floor | floor |
| **cycleSegmentation** | **uygulandı** | **notApplied** — periyodik yapı YOK |
| katkı / aykırı | 25 / 202 | 71 / 88 |
| meanAgreement | — | 0,836 |

**Periyodik yapı M-THENX'te.** Referans hangi kümeden kurulursa kurulsun:
KBOGES'i seçmek `cycleSegmentation`'ı ve hip+thigh'ın varyans-türetimini
kaybettirir; THENX'i seçmek 202 take'i aykırı bırakır.

---

## 5. Ne YAPILMADI

- **Hiçbir dışlama/varyant hükmü yok** (şart 2). Hangi modun
  `bodyweight_squat` olduğu **kararlaştırılmadı** — o karar ürünün kendi
  hareket tanımından gelir (katalog/blueprint hakem) ve koordinatöre döner.
- İki mod da meşru varyantsa yol **"iki varyant = iki içerik girdisi"**
  olabilir; dışlama tek seçenek değil (şart 3).
- `bodyweight_squat` `coming_soon`; form dersi K7 gereği kilitli;
  `validate_library` TEMİZ. Bu tur hiçbir ders durumu açmadı.

## 6. Koordinatöre giden soru

B4 ayrımı **ürün için de anlamlı olabilir**: dar omuz hattı = yandan çekim,
ve squat'ın gövde eğimi/derinlik notlaması yan görüş ister. Yani iki mod
"iki geçerli squat stili" değil, **"iki çekim kurulumu"** olabilir — bu
durumda varyant ekseni hareket değil **kadraj** olur ve ürünün çekim
talimatına (PRD/blueprint) bağlanır. Bu ayrımı kesmek için gereken şey ek
eğitmen değil, **aynı kanalın iki kadrajda çekilmiş take'leri** — havuzda
yok, ama hedeflenmiş küçük bir hasat bunu doğrudan sınar.
