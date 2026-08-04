# G-116 — Üç süpürme: L-197 valid · pozitif-ikiz sayımı · fiziksel aralık

**Yetki:** koordinatör M-F-244 paketi (üçü de disk-işi).
**Özet:** iki gerçek kusur bulundu, ikisi de **benim kendi yeni araçlarımda**;
düzeltildi. **Hiçbir sayı değişmedi** — kirli↔temiz karşılaştırması bit-aynı.
Üçüncü süpürmede ihlal bulunamadı.

---

## 1. L-197 — `valid` okuma süpürmesi

`mz.evaluate` doc'u: *"Güven eşiğin altındaysa değer hesaplanır ama
`valid=False` döner ve çağıran taraf bunu skora KATMAMALIDIR."*

Gravita'da `evaluate` çağıran **4 Python aracı** var (iki Dart aracı yalnız
yorumda anıyor, gerçek çağrı yok):

| araç | `valid` okunuyor mu |
|---|---|
| `anatomical_copying_signature.py` | ✅ `if not (a.valid and b.valid): continue` |
| `mirror_vs_foreshortening.py` | ✅ `if m.valid:` |
| `hip_knee_coupling_canonical.py` | ✅ `if h.valid and k.valid:` |
| **`a5_anatomical_probe.py`** | ❌ **`v = float(r.value)` — valid HİÇ okunmuyordu** |

**Tek ihlal benim bu turda yazdığım araçta.** Mevcut üç araç standarda
uyuyordu; standardın altına düşen yeni koddu.

### Kontrollü karşılaştırma (L-187 tarzı)

`A5_STRICT` bayrağı eklendi (varsayılan açık; `0` eski kirli davranışı geri
getirir, yalnız karşılaştırma için).

```
invalidDropped: hip_flexion 0 · knee_flexion 0 · trunk_tilt 0 · POSCTL 0
kirli ↔ temiz  : FARK YOK (bit-aynı)
```

**G-113'ün sonuçları etkilenmedi.** Neden etkilenmediği de ölçüldü:

- `lm` **her karede var** (3331/3331) → güven değerleri gerçek, uydurulmuyor.
- Havuz genelinde kare-içi min-visibility **düşük** (2002/3331 kare < 0,5;
  medyan 0,416) — ama `Frame.confidence` *en zayıf halkayı yalnız metriğin
  kullandığı indeksler üzerinden* alır, tüm kare üzerinden değil. Seçilen dip
  karelerinde ilgili landmark'lar eşiğin (0,6) üstünde kalmış.

⚠️ **Açık kalan, isimli:** `deepest_frame` dip kareyi *diz açısı en küçük*
ölçütüyle seçiyor. Landmark gürültüsü açıyı küçültebileceği için bu seçim,
gürültülü kareye yanlı olabilir. Bu turda ölçülmedi.

---

## 2. Pozitif-ikiz sistematik sayımı (Choreia 42-iddia emsali)

18 test dosyası tarandı; yokluk-iddiası (`findsNothing`, `isEmpty`, `isNull`,
`, 0)`) ve varlık-iddiası (`findsOneWidget`, `isNotEmpty`, `isNotNull`)
sayıldı.

```
18 dosya · yokluk 38 · varlık 83 · oran 2,18
```

Kaba ölçüt 3 dosyayı "yokluk ağır, ikiz notu yok" diye işaretledi. **Üçü de
elle incelendi ve ÜÇÜ DE TEMİZ ÇIKTI:**

| dosya | işaretlenen yokluk | bulunan ikiz |
|---|---|---|
| `progress_summary_test` | `unitTotals isEmpty` (116) · `withheld 0` (187) | `unitTotals` dolu (221) · `withheld` pozitif (158) |
| `progress_view_test` | gerekçe ölçüm bölümünde `findsNothing` (107) · birimsiz sayı `findsNothing` (126-127) | gerekçe kilit bölümünde `findsOneWidget` (101/104) · birimli sayı (123-124) |
| `hold_engine_test` | `breaks isEmpty` (63, 100) · `holdDurationUs 0` (112) | `breaks isNotEmpty` (81) · süre işliyor (57-63) |

**Repo-genelinde ikizsiz yokluk kapısı BULUNAMADI.**

⚠️ **Ölçütün kendi sınırı:** tarama "ikiz" *kelimesini* arıyordu, ikizin
*kendisini* değil — bu yüzden üç yanlış pozitif üretti. İkizler mevcut ama
çoğu **etiketsiz**. Yani bu bir kapı eksiği değil **belge eksiği**; ikiz
notu olmayan bir kapı, sonraki turda yeniden incelenmeyi gerektiriyor.

---

## 3. Fiziksel aralık (`value_range`) mini-süpürmesi

B4 vakasının (G-115: 5,27 ölçüldü, imkânsız) genellemesi. **Bulgu: kendi iki
probe aracımın hiçbirinde `value_range` beyanı yoktu.** `MetricDef` alanı
mevcut ve doc'u L-107'yi anlatıyor; ben hiçbirinde doldurmamışım.

Eklenen aralıklar — **gerekçeli, icat değil**:

| ölçü | aralık | gerekçe |
|---|---|---|
| `hip_flexion` · `knee_flexion` · `trunk_tilt` | 0–180° | üç-noktalı açının **tanımı**; eşik değil geometri |
| `POSCTL_shoulder_foreshortening` | 0–3,0 | oran; cömert ama **sonlu** (payda ~0'da patlar) |
| `B1_stance_width` | 0–4,0 | ayak arası ÷ omuz arası |
| `B2_depth_knee_deg` | 0–180° | açı tanımı |
| `B3_hip_knee_ratio` | 0–5,0 | açı ÷ açı |
| `B4_shoulder_foreshortening` | 0,05–2,0 | G-115'te türetildi |

`mode_naming_probe`'da kapı artık **kalıcı** (G-115'te ad-hoc yapılmıştı).

### Kontrollü karşılaştırma

```
A5    kirli ↔ temiz : FARK YOK (bit-aynı)
G-111 kirli ↔ temiz : FARK YOK (bit-aynı)
```

---

## 4. Dürüst kapanış

**Bu turda hiçbir sayı düzelmedi.** Üç süpürmenin çıktısı: iki gerçek kusur
(ikisi de benim yeni kodumda) kapatıldı, bir süpürmede ihlal çıkmadı — ve
kapatılan kusurların **hiçbiri mevcut sonuçları etkilemiyordu.**

Kazanılan şey geçmiş değil gelecek: aynı sızıntı yolları bir daha açık
kalmayacak. Kayıtlı açık: `deepest_frame`'in gürültüye yanlılığı (§1) ve
ikiz notu olmayan kapılar (§2).

`bodyweight_squat` `coming_soon`, form dersi kilitli, `validate_library`
TEMİZ. Yayımlı artefakt değişmedi.
