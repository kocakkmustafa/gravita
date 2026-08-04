# G-113 — A5 SONUÇ: **UÇ (ii)** — ayrışma anatomik modda SÜRÜYOR (gövde eğiminde)

**Ön-kayıt:** `G-112-A5-ON-KAYIT.md`, sonuçlardan önce commit (`45fd1b0`)
**mocore:** yerel checkout `05aacaf`, salt okuma · **havuz:**
`gravita-squat/landmarks-rep-sliced` 234/41 MB · küme M-THENX 23 · M-KBOGES 69
**Yayımlı artefakt değişmedi.**

---

## 1. ⚠️ ÖNCE: ön-kaydımın pozitif-kontrol tasarımı HATALIYDI

G-112'de şöyle yazmıştım: *"B4 anatomik modda ölmek ZORUNDA … ayrışması
sürerse mod bağlanmamış demektir ve A5'in tamamı geçersizdir."*

**Yanlıştı.** `MetricDef` doc'unu yanlış okudum. `evaluate` yalnız şu dallara
girer:

```python
if anatomical and metric.frame_ref in ("gravityYaw", "proximal"): axes = body_axes(...)
if anatomical and metric.frame_ref == "none":                     plane = "none"
```

`frame_ref="camera"` **hiçbirine girmez** — camera-çerçeveli metrik anatomik
moddan **tanım gereği etkilenmez**. Doc'un "sabitleşir / ölü metrik" uyarısı,
metrik **anatomik çerçeveye zorlanırsa** geçerliydi; `camera` beyanı zaten o
ölümü önlemek için konmuş. Ben korunmuş bir metriği "çökmeli" diye
kurgulamışım.

Ölçüm bunu doğruladı: POSCTL'in ayrışması **0,472 → 0,472**, ham değer kayması
**tam 0,0000°**.

**Doğru kontrol dolaylı ayrışma değil, ham değerin kendisidir** — aynı karede
aynı metrik iki modda farklı sayı veriyor mu:

| metrik | frame_ref | \|Δ\| ortalama | durum |
|---|---|---|---|
| hip_flexion | proximal | **2,676°** | DEĞİŞİYOR |
| knee_flexion | none | **6,190°** | DEĞİŞİYOR |
| trunk_tilt | gravityYaw | **2,187°** | DEĞİŞİYOR |
| POSCTL_shoulder_foreshortening | camera | 0,000° | SABİT (mod bu sınıfa dokunmuyor) |

**3/4 metrik iki modda farklı değer veriyor → anatomik mod BAĞLI**, üç
metriğin sonuçları okunabilir. POSCTL okunmaz: onda "fark yok", modun o
sınıfa dokunmadığının tekrarıdır (M-F-230).

---

## 2. Sonuç tablosu

Çapalar (G-112, değiştirilmedi): ALT = \|AUC−0,5\| ≤ 0,077 **ve** OVL ≥ 0,40 ·
ÜST = \|AUC−0,5\| ≥ 0,30 **ve** OVL ≤ 0,40.

| metrik | mod | OVL | AUC | ayrışma | perm-p | bant |
|---|---|---|---|---|---|---|
| hip_flexion | camera | 0,174 | 0,098 | **0,402** | 0,0000 | ÜST |
| hip_flexion | **anatomical** | 0,420 | 0,221 | **0,279** | 0,0000 | **ARA** |
| knee_flexion | camera | 0,246 | 0,152 | **0,348** | 0,0000 | ÜST |
| knee_flexion | **anatomical** | 0,377 | 0,358 | **0,142** | 0,0250 | **ARA** |
| **trunk_tilt** | camera | 0,014 | 0,999 | **0,499** | 0,0000 | ÜST |
| **trunk_tilt** | **anatomical** | **0,101** | **0,934** | **0,434** | 0,0000 | **ÜST** |

### Ön-kayıt uçlarına göre: **UÇ (ii) — SÜRME**

- UÇ (i) çözülme: *üç metrik de ALT banda düşerse.* **Hiçbiri düşmedi.**
- UÇ (ii) sürme: *en az bir metrik ÜST bantta kalırsa.* **trunk_tilt kaldı**
  (ayrışma 0,434 · OVL 0,101).

→ Ayrım **salt bakış-açısı artefaktı DEĞİL.** Gövde eğiminde, kamera
yöneliminden arındırılmış açı uzayında da duruyor.

---

## 3. Asıl desen: kısmi çözülme, ve çözülme miktarı sırayla

| metrik | camera → anatomical | düşüş |
|---|---|---|
| knee_flexion | 0,348 → 0,142 | **−59 %** |
| hip_flexion | 0,402 → 0,279 | −31 % |
| trunk_tilt | 0,499 → 0,434 | **−13 %** |

**Bakış açısı ayrımın bir kısmını açıklıyor ama tüketmiyor.** En çok diz
açısı çözüldü, en az gövde eğimi.

⚠️ **Bu okumanın kendi zayıflığı — isimli:** çözülme miktarı, modun o metriğe
ne kadar dokunduğuyla da ilişkili. Ham kayma knee'de **6,19°**, trunk'ta
**2,19°** — yani trunk_tilt'in ayrışmayı sürdürmesi kısmen *modun ona daha az
müdahale etmesinden* olabilir. "Gövde eğimi gerçek stil farkı" okuması bu
yüzden **güçlü ama tek başına kesin değil**; kayma-normalize bir okuma
(ayrışma düşüşü ÷ ham kayma) knee 9,5 %/° · hip 11,5 %/° · trunk 5,9 %/°
verir — trunk yine en dirençli, ama fark tabloya bakıldığı kadar keskin değil.

---

## 4. Ürün açısından anlamı (yorum, hüküm değil)

Ayrışmayı sürdüren metrik **gövde eğimi** — ve bu, squat'ın notlanmak istenen
iki boyutundan biri (öteki diz derinliği; G-106: *"knee depth plus torso lean
are exactly what a squat coach would grade"*). İki mod gövde eğiminde gerçekten
farklı olabilir: kalça-baskın ↔ diz-baskın squat kalıbı bu eksende ayrılır.

Ama G-111'deki **B3 (kalça/diz oranı) hiç ayrışmamıştı** — kalıp farkı
beklenirse orada da görünmeliydi. İki bulgu tam örtüşmüyor; bu, "stil farkı"
okumasını zayıflatan kayıtlı bir çelişkidir ve çözülmeden ad konmaz.

---

## 5. Taşınan notlar

**Confound — A5 sonrasında da geçerli:** anatomik mod **bakış-sabitini** eler,
**kanal-sabitlerini elemez** (aydınlatma, kıyafet, model davranışı, çekim
alışkanlığı). Küme ≈ kanal olduğu sürece trunk_tilt'in sürmesi "stil" kadar
"stüdyo" da olabilir. Permütasyon testi bunu yakalayamaz (G-111 §3 aile-notu).
**Kanal-içi kontrast hâlâ tek kesici** ve havuzda yalnız n=3 var.

**Periyodiklik maliyeti değişmedi:** periyodik yapı M-THENX'te; KBOGES'i
seçmek `cycleSegmentation`'ı ve hip+thigh varyans-türetimini kaybettirir.

**M-F-230'un ertelenmiş çekirdek sorusu** ("anatomik ekstraksiyon
eğitmenler-arası dispersiyonu iyileştirir mi") için bu tur **kısmi girdi**
üretti: anatomik mod küme ayrışmasını **azaltıyor** (3 metrikte de), yani
bakış kaynaklı sahte dispersiyonu gerçekten siliyor — ama **tüketmiyor**.
Tam cevap referans-rebuild günü ölçülür.

---

## 6. Ne YAPILMADI

Hüküm yok, dışlama yok, varyant kararı yok. `bodyweight_squat` `coming_soon`,
form dersi K7 gereği kilitli, `validate_library` TEMİZ. Hangi modun
`bodyweight_squat` olduğu hâlâ katalog hareket-tanımının hakemliğinde ve
koordinatöre aittir.
