# G-109 — A4+A1 SONUÇ: hipotez ÖLDÜ (ters yönde) · çok-modluluk KANITLANDI

**Ön-kayıt:** `G-108-A4-A1-ON-KAYIT.md` (sonuçlardan önce commit'lendi,
`8178ad1`) · **frameBasis:** `camera` (anatomik mod bu hatta bağlı değil, G-107)
**Yayımlı artefakt DEĞİŞTİRİLMEDİ** — çıktılar scratch'te, probe damgalı.

---

## 0. Golden — "davranış değişmedi" ÖLÇÜLDÜ

Araç parametreleri eklendikten sonra varsayılan mantık `--out` ile scratch'e
koşuldu ve yayımlı artefaktla karşılaştırıldı:

```
anahtar farkı: YOK · değer farkı olan anahtar: YOK  (generatedAt hariç)
→ BİT-AYNI
```

İddia değil ölçüm. (`--out` ve `--exclude-source` verilmezse kod yolu
öncekiyle özdeş; ayrıca `test/tool_args_test.dart` 10 test.)

---

## 1. A4 — THENX çıkarılıp referans yeniden kuruldu

| ölçüt | yayımlı (THENX dahil) | **A4 (THENX yok)** |
|---|---|---|
| katkı veren take | 25 | **71** |
| aykırı | 202 (%89) | **88 (%55)** |
| distinctSources | 5 | **4** |
| katkı kaynakları | THENX, Strength Side, WeShape, Jeff Nippard, Jeremy Ethier | **K boges, Strength Side, Jeff Nippard, Jeremy Ethier** |
| **tolerans: varyans / taban** | **14 / 3** | **5 / 12** |
| hip | **variance** | **floor** (0,37→1,00) |
| thigh | **variance** | **floor** (0,11→0,57) |
| knee | floor | floor |
| shin | floor | floor |
| trunk_tilt | floor | floor |
| meanAgreement | — | 0,836 |
| cycleSegmentation | uygulandı | **notApplied** — *"no take shows periodic structure"* |
| takeMeanAbsLRDiff | 32,41° | 27,61° |

**Pozitif kontrol geçti (M-F-230):** `distinctSources` 5→4, katkı 25→71,
aykırı 202→88 — filtre gerçekten bağlı, çıktı bit-aynı DEĞİL.

### Ön-kayıt karşılaştırması — ve ölçütümün kusuru

Ön-kayıt UÇ (i): *"knee/shin/trunk_tilt'ten ≥1 çift floor→variance geçer
**VEYA** aykırı oranı ≥10 puan düşer."*

- İlk şart: **karşılanmadı** — üçü de floor kaldı.
- İkinci şart: **karşılandı** — %89 → %55, **34 puan** düşüş.

Yani ön-kaydım harfiyen okunursa (i) tetiklendi. **Ama bu okuma yanlış olur ve
kusur ön-kaydımdadır:** aykırı oranını *tolerans türetilebilirliğinin vekili*
saymıştım. Ölçüm o vekilin **yanlış** olduğunu gösterdi — kümelenme düzeldi
(88 aykırı) ama tolerans **kötüleşti**: kazanılmış iki eklem (hip, thigh)
`variance`'dan `floor`'a düştü.

Bu, bu defterde tekrarlanan **vekil-ölçüm** sınıfının (G-072 ailesi) kendi
ön-kaydımda tekrarıdır. Ön-kayıt yanlış ölçütü dondurur — ama faydası tam da
budur: kusuru sonradan değil, karşılaştırma anında görünür kıldı.

### Hüküm: hipotez ÖLDÜ, üstelik TERS yönde

G-106 §3 hipotezi: *"knee/shin/trunk_tilt floor-bound, çünkü referansın %72'si
tek kaynaktan; ölçülen dispersiyon THENX'in iç varyansı."*

Doğruysa THENX çıkınca dispersiyon **artmalıydı**. **Azaldı** — taban-bağlı
eklem sayısı 3'ten 12'ye çıktı. **THENX dispersiyonu bastırmıyordu; dispersiyonun
KAYNAĞIYDI.** Hipotez ölü olarak kapanır.

⚠️ Ek gözlem, aynı yönde: THENX'siz havuzda `cycleSegmentation` hiç uygulanmadı
— *hiçbir take periyodik yapı göstermiyor.* Squat'ın tekrarlı yapısını taşıyan
kaynak büyük ölçüde THENX'miş. Bu, "THENX'i çıkar" yolunun ürün için
maliyetini de gösteriyor.

---

## 2. A1 — aykırıların mod yapısı: ÇOK-MODLU (kesin)

Ön-kayıttaki mesafe-oranı ölçütü yerine **daha doğrudan** bir ölçüt kullanıldı
(bu bir sapmadır ve burada ilan edilir): iki koşumun **küme üyelikleri**
karşılaştırıldı — mesafe eşiği seçmeye gerek kalmadan ayrıklık okunur.

```
A4'ün 71 katkısı, yayımlı referansta neredeydi?
  yayımlıda AYKIRI : 69
  yayımlıda KATKI  :  2
→ %97 ayrık
```

Kaynak düzeyinde daha da keskin:

| kaynak | yayımlıda | A4'te |
|---|---|---|
| **THENX** (68 take) | **18 katkı** | çıkarıldı |
| **K boges** (59 take) | **0 katkı** (59'u aykırı) | **59 katkı** |
| Strength Side | 1 | 10 |
| WeShape | 3 | 0 |

**THENX ve K boges birbirini dışlıyor:** hangisi konsensüs olursa öteki
*tamamen* aykırı oluyor. Bu, tek dağınık bulut değil **en az iki ayrı mod**
demektir → ön-kayıt A1 **UÇ (i): ÇOK-MODLU**.

Bu, G-069'un "tolerans genişletmek kümelenmeyi hiç değiştirmedi" bulgusunu da
açıklıyor: tek bulutu genişletmek değil, **iki bulut arasında seçim yapmak**
gerekiyormuş.

---

## 3. Ne YAPILMADI — ve neden

**Hiçbir dışlama kararı alınmadı.** A4 tek başına PROBE'dur (koordinatör hükmü
aynen kabul); leave-one-out "farklı mod"u "gürültü"den ayıramaz. Burada
çok-modluluk *kanıtlandı* ama **hangi modun `bodyweight_squat` olduğu
ÖLÇÜLMEDİ** — bu bir varyant kimliği sorusudur ve M-F-47 gereği bağımsız,
İSİMLİ kanıt ister (emsal: barbell dışlaması G-089/091, "198 kg top-set"
adıyla). *"Kalanların uyuşması gerekçe değildir."*

**Açık soru — sıradaki iş:** iki mod NEDİR? Adaylar (ölçülmedi): duruş
genişliği · derinlik (paralel-altı vs parçalı) · kalça-baskın vs diz-baskın
kalıp · kadraj/kamera mesafesi. Ayrımı isimlendiren ölçüm, varyant kararının
ön koşuludur.

**Değişmeyen:** `bodyweight_squat` `coming_soon`; form dersi K7 gereği kilitli;
`validate_library` TEMİZ. Bu tur hiçbir ders durumunu açmadı — ön-kayıtta
söylendiği gibi.

---

## 4. Düzeltme — G-106'da yanlış havuzu göstermiştim

G-106 §4'te "ham havuz diskte: `~/motion-harvest/gravita/landmarks`,
674 MB / 27 dosya" yazmıştım. **O push_up havuzudur.** Squat referansının
girdisi `~/motion-harvest/gravita-squat/landmarks-rep-sliced` —
**234 dosya / 41 MB** (rep-FSM dilimli).

Sonuç değişmiyor (indirme/slot gerekmiyor, ki bu tur onu kanıtladı), ama sayı
yanlıştı: aracın girdi yolunu okumadan, komşu dizinden devraldım. Bu, kendi
defterimdeki **G-087 "dar kapıdan devralınan sayı"** desenidir.
