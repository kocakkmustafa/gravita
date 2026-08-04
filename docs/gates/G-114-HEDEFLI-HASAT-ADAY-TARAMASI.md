# G-114 — Hedefli hasat AŞAMA 1: aday taraması + D1 ön-kapısı

**Yetki:** koordinatör M-F-240 aşama 1 (ağ-hafif, **indirme YOK**).
**Sonuç:** havuzda temiz "aynı eğitmen, iki kadraj" çifti **YOK** —
dört adayın dördü de ön-kapıda düştü veya zayıfladı. **İndirme yapılmadı,
ölçüm ön-kaydı yazılmadı** (ölçülecek çift çıkmadığı için).

---

## 1. Önce M-F-200 refleksi: çift havuzda olabilir mi?

Web'e gitmeden önce eldeki **234 take / 13 kanal** B4 (omuz hattı kısalması)
ile tarandı — kanal-içi kadraj varyasyonu aranıyor. **Ağ kullanılmadı.**

| kanal | video | B4 medyan aralığı | yayılım |
|---|---|---|---|
| **Squat University** | 3 | 0,489 – 1,284 | **0,795** |
| Tom Merrick | 3 | 0,722 – 0,894 | 0,172 |
| Jeff Nippard | 2 | 0,659 – 0,818 | 0,160 |
| THENX | 2 | 1,022 – 1,078 | 0,055 |
| diğer 9 kanal | 1'er | — | 0,000 |

İlk bakışta **Squat University güçlü aday**: kadraj kontrastı B4'ün küme
ayrımı kadar geniş, ve bu kanal referansa **sıfır katkı** vermiş (16 take,
hepsi aykırı) — yani hiç kullanılmamış bir kaynak.

## 2. D1 ön-kapısı (yayımlı metin) — ve adayın düşüşü

Manifestler `title` + `description` taşıyor, yani **ön-kapı diskten
çalıştırılabildi; ağa çıkılmadı.**

| video | B4 | başlık | ön-kapı bulgusu |
|---|---|---|---|
| `8Kls95w2jFA` | 1,284 | *Perfect Your Squat: Step-By-Step Form Guide* | temiz |
| `my0tLDaWyDU` | 0,642 | *How To Squat Correctly (NO BACK PAIN)* | ⚠️ **"Collab with Micah Marino!"** |
| `5alpa1IikQM` | 0,489 | *How To Perform The Perfect Squat (FOR ANY BODY TYPE)* | ⚠️ **"Special thanks to Bailey Haslam … and Tori Millist"** + başlık zaten *farklı vücut tipleri* diyor |

**Üç video farklı kişileri gösteriyor.** Aranan şey "aynı kişi, iki kadraj"
idi; bulunan şey "farklı kişiler, farklı kadraj" — yani kadraj kontrastı
gerçek ama **kişi sabiti yok**, dolayısıyla stil↔stüdyo ayrımını kesemez.
Aday **DÜŞTÜ**.

Bu, M-F-200'ün kanonik dersinin aynadaki hâli: orada başlık adayı *yanlış
düşürüyordu*, burada ön-kapı adayı *doğru düşürdü*. Katman 2 iki yönde de
çalışıyor.

### İkincil adaylar — hepsi zayıf

| kanal | durum |
|---|---|
| **Jeff Nippard** | 2 video (0,659 · 0,818); ikincisinde **"ft."** işareti → başka kişi olasılığı. Kontrast zaten orta. **ZAYIF** |
| **Tom Merrick** | 3 video (0,722–0,894), başka-kişi işareti yok — ama içerik *"Fix Your Ankles / Fix Your Hips (FULL ROUTINE)"*, yani **squat değil hareketlilik rutini** (G-103'te aynı tespit yapılmıştı) ve n çok küçük (2 · 1 · 8). **ZAYIF** |
| **THENX** | yayılım 0,055 — **kadraj kontrastı yok**, aday değil |

---

## 3. ⚠️ Kendi yöntemimin sınırı — isimli

Aday taramasını **video medyanı** üzerinden yaptım, yani örtük olarak
"aynı video = aynı kadraj" varsaydım. Bu varsayım **yanlış**:

G-111'de Jeff Nippard'ın referansa katkı veren take'leri M-THENX tarafında
**0,945 / 0,949**, M-KBOGES tarafında **0,596** ölçülmüştü. Bu turda aynı
kanalın video medyanları **0,659** ve **0,818** — 0,945'e yakın hiçbir video
medyanı yok.

Tek tutarlı açıklama: **kadraj video İÇİNDE de değişiyor** (kamera hareketi,
kesme, çoklu çekim). Yani video-medyanı kaba bir ölçüttür ve gerçek kadraj
çiftleri **video düzeyinde değil çekim düzeyinde** aranmalıdır. Bu turun aday
listesi bu yüzden *alt sınır*: kaçırdığı çift olabilir.

---

## 4. Ne yapılmadı

- **İndirme yok** (koordinatör izni ≤2 çift kullanılmadı — çift bulunamadı).
- **Ölçüm ön-kaydı yazılmadı**: ölçülecek çift çıkmadığında ön-kayıt yazmak,
  olmayan bir ölçümün uçlarını sabitlemek olurdu.
- Hüküm yok, dışlama yok. `bodyweight_squat` `coming_soon`, form dersi
  kilitli, `validate_library` TEMİZ.

## 5. Koordinatöre giden okuma

Havuz bu ayrımı taşımıyor — **ek eğitmen değil, ek kadraj** gerektiği
doğrulandı, ve üstelik aranan şey daha dar: *aynı kişi, aynı stil, iki
kadraj, pitch/yükseklik varyasyonu dahil.*

**Pitch hipotezine (M-F-240) not:** aday taramam yalnız B4'e (omuz hattı =
yaw vekili) baktı; **pitch'i ölçmedi.** İki kurulum aynı yaw'da ama farklı
kamera yüksekliğinde olabilir ve B4 bunu görmez. Hedefli çekim tasarlanırsa
pitch varyasyonu **ayrıca beyan edilmeli** — B4 kontrastı onun vekili
değildir. (Bu, bu turun kendi ölçüm sınırı.)
