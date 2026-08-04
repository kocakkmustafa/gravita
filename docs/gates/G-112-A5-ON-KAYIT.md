# G-112 — A5 ANATOMİK KÜME-ÇÖZÜLME TESTİ: ÖN-KAYIT (koşumdan ÖNCE)

**Yetki:** koordinatör hükmü M-F-237 (2026-08-04) · **havuz (beyanlı):**
`~/motion-harvest/gravita-squat/landmarks-rep-sliced` — 234 dosya / 41 MB
**mocore sürümü:** yerel checkout `05aacaf` (`feat/lissom-v3-onayi`) —
kanonik `mz.evaluate(..., anatomical=)` bu sürümden çağrılır, salt okuma,
dal DEĞİŞTİRİLMEZ (M-F-22).

Sonuçlardan önce yazıldı; sonradan değiştirilmeyecek.

---

## Soru

G-111 iki modu **omuz hattı kısalmasıyla** ayırdı (B4, tam ayrışma) ve bu
büyüklük bir **bakış-açısı vekili**. Referans hattı ise image-plane (G-107).
Öyleyse: **iki küme, PLANAR ölçümün bakış-açısı artefaktı mı?**

Anatomik mod (M-F-53) düzlemleri iskeletten türetir ve kamera yönelimini
tanım gereği siler. Eğer kümeleri ayıran şey bakış açısıysa, **anatomik açı
uzayında ayrışma çökmeli**.

---

## Ölçülecek

Her take'in **dip karesinde** üç açı, üç farklı `frame_ref` sınıfından
(taksonomi M-F-54), her biri **iki modda** (`anatomical=False|True`):

| metrik | kind | frame_ref | neden bu sınıf |
|---|---|---|---|
| `hip_flexion` | angle3 (SHOULDER-HIP-KNEE) | `proximal` | küresel eklem, pitch dahil |
| `knee_flexion` | angle3 (HIP-KNEE-ANKLE) | `none` | menteşe, doğrudan 3B |
| `trunk_tilt` | angle_vertical (HIP→SHOULDER) | `gravityYaw` | postür, yerçekimi-göreli |

Girdi: MediaPipe **world** landmark'ları (metrik 3B) — anatomik mod 3B
girdi gerektirir. `geo.Frame(xyz, visibility, presence, t_ms)`.

Ayrışma ölçüsü **G-110/G-111 ile AYNI makine**: OVL (histogram kesişimi) +
AUC (Mann-Whitney) + her küme için p10/p50/p90 + permütasyon (n=200).
Küme etiketleri değişmedi: **M-THENX 23 · M-KBOGES 69**.

---

## ⚠️ POZİTİF KONTROL — zorunlu, ve bu turda TANIMDAN geliyor

`MetricDef` dokümantasyonu şunu yazıyor:

> `shoulder_line_foreshortening` tam bu sınıf: anatomik çerçeve yaw
> bağımlılığını **tanım gereği kaldırdığı için metrik orada SABİTLEŞİR** —
> göç kapısı bunu **ölü metrik** olarak yakaladı (A9).

Yani **B4 anatomik modda ölmek ZORUNDA.** Bu, A5 için mükemmel bir pozitif
kontroldür (M-F-230):

- **B4'ün ayrışması anatomik modda ÇÖKERSE** → anatomik mod gerçekten bağlı,
  diğer sonuçlar okunabilir.
- **B4'ün ayrışması anatomik modda SÜRERSE** → anatomik mod **bağlanmamış**;
  bit-aynı çıktı "fark yok" değil "bayrak bağlanmamış" demektir (M-F-230) ve
  **A5'in tamamı GEÇERSİZ** sayılır, isimli bulgu olarak döner.

Bu kontrol olmadan hiçbir A5 sayısı okunamaz.

---

## Çapalar — ÖLÇÜLÜ, icat edilmedi (koordinatör şartı 3)

Karşılaştırma bantları bu turun kendi ölçümlerinden (G-111):

| bant | kaynak | değerler |
|---|---|---|
| **ÜST (ayrışan)** | B4, iki uzayda | OVL **0,000** · \|AUC−0,5\| **0,500** |
| **ALT (ayrışmayan)** | B3, iki uzayda tutarlı | OVL 0,174–0,478 · \|AUC−0,5\| **0,010–0,077** |

B1 ve B2 çapa olarak KULLANILMAZ — iki uzayda çeliştiler (G-111 §1), yani
kendileri güvenilir bant değil.

### İki uç (önceden sabit)

**UÇ (i) — ÇÖZÜLME: ayırıcı büyük ölçüde BAKIŞ AÇISI.**
Üç metriğin **planar modda** ölçülen ayrışması anatomik modda **ALT BANDA
düşerse** (\|AUC−0,5\| ≤ 0,077 **ve** OVL ≥ 0,40).
→ "iki mod = iki çekim kurulumu" desteklenir; varyant ekseni hareket değil
**PRD/blueprint çekim talimatı** olur. Ayrıca M-F-230'un ertelenmiş çekirdek
sorusu ("anatomik ekstraksiyon eğitmenler-arası dispersiyonu iyileştirir mi")
ilk gerçek kanıt-vakasını alır → çekirdek-tasarım girdisi, koordinatöre.

**UÇ (ii) — SÜRME: gerçek stil-modu.**
En az bir metrik anatomik modda **ÜST BANDA yakın** ayrışma sürdürürse
(\|AUC−0,5\| ≥ 0,30 **ve** OVL ≤ 0,40).
→ varyant kararı katalog hareket-tanımı hakemliğiyle koordinatöre döner.

**ARA BANT:** ikisi de değilse **"kısmi çözülme — isimli belirsiz"**.
Zorlama yok, ad konmaz (G-069'un "körlemesine devam edilmedi" kararı).

---

## Taşınan notlar (koordinatör şartları 4 ve 5)

**Confound — A5'te de geçerli, isimli:** anatomik mod **bakış-sabitini**
siler, **stüdyo-dışı kanal-sabitlerini SİLMEZ** (aydınlatma, kıyafet,
model-davranışı, çekim alışkanlığı). Küme ≈ kanal olduğu sürece bu confound
durur; permütasyon testi onu yakalayamaz (G-111 §3, aile-notu). A5'in uç (i)
sonucu bile kanal-sabitini elemez — yalnız **bakış-açısı** bileşenini eler.

**Periyodiklik maliyeti — her iki uçta geçerli:** periyodik yapı
M-THENX'tedir; KBOGES'i seçmek `cycleSegmentation`'ı ve hip+thigh'ın
varyans-türetimini kaybettirir (G-109/G-111 §4). A5 bu tabloyu değiştirmez,
yalnız *ayrımın ne olduğunu* söyler.

---

## Sınırlar

- **Hüküm yok, dışlama yok** (rapor-önce). Çıktı = iki modun ayrışma tablosu
  + pozitif kontrol verdikti + çapa karşılaştırması.
- Yayımlı artefakt değişmez; çıktı scratch'e, probe damgalı.
- `bodyweight_squat` `coming_soon`, form dersi kilitli kalır.
- Her sayı `frameBasis` etiketli: `camera` (planar) / `anatomical`.
