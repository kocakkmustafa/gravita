# G-110 — MOD-İSİMLENDİRME ÖN-KAYIT (koşumdan ÖNCE yazıldı)

**Yetki:** koordinatör onayı 2026-08-04, beş şart · **frameBasis:** `camera`
**Havuz (beyanlı, G-109 §4 düzeltmesiyle):**
`~/motion-harvest/gravita-squat/landmarks-rep-sliced` — **234 dosya / 41 MB**

Bu dosya ölçüm koşulmadan önce yazıldı ve sonuçlar geldikten sonra
DEĞİŞTİRİLMEYECEK.

---

## Soru

G-109 iki neredeyse-ayrık küme kanıtladı (%97 ayrık). **Bu iki modu AYIRAN
boyut hangisi?** İsimlendirme sorusu — dışlama sorusu değil (M-F-47).

## Küme etiketleri (A4'ten, verili)

| etiket | tanım | n |
|---|---|---|
| **M-THENX** | yayımlı referansın katkı kümesi | 25 |
| **M-KBOGES** | A4 (THENX'siz) koşumun katkı kümesi | 71 |
| (örtüşen) | her ikisinde de katkı — analizden çıkarılır | 2 |

Örtüşen 2 take çıkarılır ki karşılaştırma iki **ayrık** küme arasında olsun.

---

## Aday boyutlar — ve her birinin DOĞRUDAN ölçüsü

Vekil yok (G-109 dersi): her boyut, adlandırdığı şeyin kendisini ölçer.
Hepsi **dip karesinde** (en derin nokta) hesaplanır, ölçek-bağımsız orandır.

| # | boyut | doğrudan ölçü |
|---|---|---|
| **B1** | duruş genişliği | ayak bileği arası mesafe ÷ omuz arası mesafe |
| **B2** | derinlik | dipteki diz fleksiyon açısı (derece) |
| **B3** | kalça/diz baskınlığı | dipteki kalça fleksiyonu ÷ diz fleksiyonu |
| **B4** | kadraj / görüş açısı | omuz hattı kısalması: omuz arası ÷ omuz-kalça uzunluğu |

**B4 neden landmark'tan türetiliyor:** `recordingMeta` ÖLÜ — 234 dosyanın
**hepsinde** `plane: frontal`, `distance_cm: 0`, `camera_setup: unknown`
(harvest'ta doldurulmamış). Beyandan okunamaz, ölçülmek zorunda. *(Bu
gözlem koşumdan önce, format keşfinde yapıldı.)*

**Uzay beyanı:** ölçümler MediaPipe `world` landmark'ları (metrik, kalça
merkezli) üzerinden yapılır — `lm` görüntü uzayının aspect-ratio bozulması
oranları kirletir. **z kullanılmaz** (tek kameranın en zayıf kanalı, G-107).
Bu, referans hattının image-plane uzayından bir SAPMADIR ve burada ilan
edilir; sağlama için B1 ve B4 `lm` uzayında da hesaplanıp iki uzayın aynı
yönü gösterip göstermediği raporlanır. Göstermezlerse bu, sonucun kendisi
kadar önemli bir bulgudur.

---

## Ayrışma ölçüsü — önceden sabit, İKİ ölçü birlikte

1. **Örtüşme payı (OVL):** iki kümenin histogramlarının kesişim alanı.
   `0` = tam ayrık, `1` = tam örtüşük.
2. **AUC** (Mann-Whitney): `0,5` = ayrışma yok; `1,0`/`0,0` = tam ayrışma.
   Dağılım varsayımı yok.

Ayrıca **her küme için p10 / p50 / p90** raporlanır — G-104'ün dersi: ayırıcı
bilgi kuyrukta olabilir, medyan ayırmayabilir.

### Uçlar (önceden sabit)

| sonuç | ölçüt |
|---|---|
| **AYRIŞTIRICI** | OVL ≤ 0,40 **ve** \|AUC − 0,5\| ≥ 0,30 |
| **AYRIŞTIRMAYAN** | OVL ≥ 0,70 **veya** \|AUC − 0,5\| ≤ 0,10 |
| **BELİRSİZ** | arada kalan her şey |

**Belirsiz banttaki boyut isimlendirilmez.** "Ayrışma zayıf, boyut
türetilemedi" diye İSİMLİ dürüst kapanış yazılır — zorlama yok (G-069'un
"45°/60° ile körlemesine devam EDİLMEDİ" kararının aynısı).

Birden çok boyut AYRIŞTIRICI çıkarsa hepsi raporlanır; **tek bir "asıl
boyut" seçilmez** — seçmek hüküm olur, şart 2 hüküm yasaklıyor.

---

## POZİTİF/NEGATİF KONTROL (M-F-230) — zorunlu

**Permütasyon kontrolü:** küme etiketleri rastgele karıştırılıp aynı ölçüm
tekrarlanır (n=200 permütasyon). Beklenen: AUC ≈ 0,5, OVL yüksek.

**Bir boyut permütasyonda da ayrışma gösteriyorsa ölçüm SAHTEDİR** ve o
boyutun gerçek sonucu geçersiz sayılır. Bu, "ölçüm herhangi bir bölünmede
ayrışma uyduruyor mu" sorusudur ve olmadan hiçbir AUC değeri okunamaz.

Her boyut için **permütasyon-p** raporlanır: gerçek |AUC−0,5| değerinin
permütasyon dağılımında hangi yüzdelikte olduğu.

---

## İsimli maliyet notu (şart 4)

Referans hangi kümeden kurulursa kurulsun ne kaybedilir — G-109'da ölçüldü,
burada tekrarlanıyor ki karar anında görünür olsun:

| | M-THENX kümesi | M-KBOGES kümesi |
|---|---|---|
| tolerans | **14 varyans / 3 taban** | 5 varyans / 12 taban |
| hip · thigh | **variance** | floor |
| knee/shin/trunk_tilt | floor | floor |
| **cycleSegmentation** | **uygulandı** | **notApplied** — periyodik yapı YOK |
| katkı / aykırı | 25 / 202 | 71 / 88 |

**İkisi de ürün için eksikli** (koordinatör hükmü): THENX-kümesi
varyans-türetimi + periyodiklik taşıyor; KBOGES-kümesi sıkı anlaşma
(taban-kısılmış) ama periyodik yapı yok.

---

## Sınırlar (şart 2 ve 3)

- **Hiçbir dışlama/varyant hükmü üretilmez.** Çıktı = ayrıştıran boyutun ADI
  + ayrışma gücü + kaynak-başına profil.
- **Hangi modun `bodyweight_squat` olduğu bu turda KARARLAŞTIRILMAZ.** O karar
  popülerlikten değil ürünün kendi hareket tanımından gelir (katalog/blueprint
  hakemdir) ve ölçümle birlikte koordinatöre döner. İki mod da meşru varyantsa
  yol "iki varyant = iki içerik girdisi" olabilir — **dışlama tek seçenek
  değildir.**
- Yayımlı artefakt değişmez; çıktı scratch'e. `bodyweight_squat`
  `coming_soon`, form dersi kilitli kalır.
