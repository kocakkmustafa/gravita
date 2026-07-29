# G1 / D1 — Ters-Duruş Fizibilite Kapısı: ÖLÇÜM RAPORU

**Tarih:** 2026-07-26 · **Protokol:** [`G1-D1-PROTOKOL.md`](G1-D1-PROTOKOL.md) (eşikler ölçümden ÖNCE yazıldı)
**Defter:** G-001 (Gravita P0) · M-001 (aile P0) · **Kanıt:** [`kanit/`](kanit/) · **Koşum araçları:** [`../../tools/d1-gate/`](../../tools/d1-gate/)

---

## 0. HÜKÜM

> ## 🟢 ŞARTLI GEÇTİ — ŞARTA BAĞLI
> Ters-duruş hattında üretim kodu **açılabilir**, ancak **yalnızca yönelim-farkında çıkarım (S2) mimarisiyle.**
> Düz çıkarım (S1) tek başına kullanılırsa kapı **GEÇMEZ.**

Gece modu uyarınca "şartlı geçti" ilan edildi (`20-URETIM-SURECI §2.6`); **kurucu onayı sabah retrospektiftir.**

| Eşik (protokol §8) | Hedef | Ölçülen (S2, `full`, INV n=42) | Sonuç |
|---|---|---|---|
| M1 `detect_rate` | ≥ 0.95 | **1.000** | ✅ |
| M2 `vis_crit` | ≥ 0.80 | **0.845** | ✅ |
| M4 kapı geçiş oranı | ≥ 0.85 | **0.929** (yan-zincir tanımı, §5.1) | ✅ |
| M5 `CORRECT` | ≥ %80 | **%100** (42/42) | ✅ |
| M5 `GROSS` | ≤ %5 | **%0** | ✅ |
| **(ek) eksen hatası** | — | **0/42** | ✅ |

**Karşılaştırma — S1 (düz çıkarım) aynı sette:** eksen hatası **3/41 (%7,3)** + 1 tespit kaybı → **%9,5 kullanılamaz kare.** Bu bandda üretim koduna girilmezdi.

---

## 1. Kapının bulduğu asıl şey (planda YAZMIYORDU)

Kapı, beklenen riski (ters-duruşta güven düşer mi?) ölçmek için kuruldu. **Beklenen risk çıkmadı; onun yerine çok daha tehlikeli bir hata modu bulundu.**

**Beklenen risk — gerçekleşmedi:** MediaPipe'ın ters-duruşta landmark güveni düşmüyor. Ters-duruş seti dik kontrol setiyle neredeyse aynı: `vis_crit` 0,842 (ters) vs 0,873 (dik) — fark 0,03. Güven kapısı açısından ters-duruş **sorun değil.**

**Bulunan gerçek risk — EKSEN TERSLEMESİ (sessiz semantik hata):**

Model, ters-duruştaki vücudu bazen **dik bir insan olarak yorumluyor**: kol zincirini bacaklara, bacak zincirini kollara oturtuyor. Sonuç:

- İskeletin **ŞEKLİ doğru çizilir** (omuz-dirsek-bilek ile kalça-diz-ayak zincirleri neredeyse simetriktir) → **gözle fark edilmez.**
- **Güven YÜKSEK kalır** — #21'de `vis_crit = 0,93` iken vücut tamamen ters etiketlenmişti.
- Kural motoru "dirsek açısı" sanıp **diz açısını** ölçer; "omuz-kalça-ayak hizası" ters yönde hesaplanır.

→ **Kendinden emin, makul görünen, tamamen yanlış koçluk.** Ürün planının en kritik kalite metriği olan "yanlış-pozitif geri bildirim oranı" (plan §14) tam olarak buradan patlardı.

**Kritik çıkarım:** *Güven eşiği bu hatayı YAKALAYAMAZ.* Güven kapısı tek başına yeterli bir emniyet mekanizması değildir; **yapısal/anatomik tutarlılık kontrolü zorunludur** (§4.2).

**Görsel kanıt:** [`kanit/kanit-eksen-terslemesi.jpg`](kanit/kanit-eksen-terslemesi.jpg) — KOL=kırmızı, BACAK=mavi, BAŞ=sarı. Sol sütun S1 (renkler ters), sağ sütun S2 (doğru).

**Çözüm ölçüldü ve işe yarıyor:** giriş görüntüsünü 180° döndürüp çıkarım yapmak (S2), landmark'ları geri döndürmek → **42/42 doğru eksen, 42/42 tespit.** Bu, katalog §1'in "en ucuz çözüm" adayıydı; artık **ölçülmüş** durumda.

---

## 2. Ölçüm koşulları

| | |
|---|---|
| Model | `pose_landmarker_full.task` (birincil) + `heavy` (çapraz kontrol) — SHA-256'lar [`kanit/metrics.json`](kanit/metrics.json) |
| MediaPipe | 0.10.35, Tasks Vision, Python (⚠️ vekil — üretim native, §6 borç) |
| Parametreler | `detection/presence/tracking = 0.5`, `num_poses=1`, uzun kenar 900px — protokol §6, oynatılmadı |
| Veri | Wikimedia Commons, **yalnız CC0/CC BY/CC BY-SA/kamu malı** — 100 görüntü indirildi, envanter [`kanit/veri-envanteri.json`](kanit/veri-envanteri.json) |
| Eleme | 33 elendi (heykel/gravür/pul/çok-kişi/uzak-özne/yarım-kadraj), 3 yeniden sınıflandı → **INV n=42, UPR n=25**. Gerekçeler [`kanit/screen.json`](kanit/screen.json) |
| Video | Gymnastics Australia klipleri (CC BY-SA 3.0), 144 + 396 kare @25fps |

**Ham medya repoya girmedi** (protokol §7) — yalnız türetilmiş metrikler, hükümler ve envanter.

---

## 3. Sayılar

### 3.1 Ana tablo (`full` modeli)

| Set · Strateji | n | tespit | `vis_crit` | yan-zincir kapı | eksen hatası |
|---|---:|---:|---:|---:|---:|
| UPR · S1 (dik, düz) | 25 | 0,960 | 0,873 | 0,840 | 0/24 |
| UPR · S2 (dik, 180°) | 25 | 0,960 | 0,872 | 0,880 | 1/24 (%4,2) |
| **INV · S1 (ters, düz)** | 42 | 0,976 | 0,842 | 0,881 | **3/41 (%7,3)** |
| **INV · S2 (ters, 180°)** | 42 | **1,000** | 0,845 | **0,929** | **0/42 (%0)** |

### 3.2 Confound ataması (protokol §2/§8)

| Etki | Ölçüm | Yorum |
|---|---|---|
| **A — yönelim** (UPR → UPR-ROT) | `vis_crit` farkı **0,000** | Güven açısından yönelim bedava… |
| **A — yönelim, eksen ekseninde** | dik %0 → ters %7,3 eksen hatası | …ama **semantik** açıdan yönelim TEK suçlu |
| **B — poz alışılmadıklığı** (UPR → INV-ROT) | `vis_crit` farkı **+0,028** | İhmal edilebilir |

**Atama: A baskın, ve A ucuz çözülüyor.** Bu, protokol §8'in "A baskın → döndürme/tracking ile çözülür" dalıdır. Model merdiveninde yukarı çıkmaya (RTMPose, fine-tune) **gerek yok** — katalog §1 merdiveninin 1. basamağı yeterli. *(Kırmızı-bayrak notu: `vis_crit` bazlı confound analizi "A etkisi = 0" diyordu; asıl A etkisi ancak yapısal ölçümle görüldü. Metrik seçimi, bulguyu gizleyebilir.)*

### 3.3 `heavy` çapraz kontrolü — aynı desen

`heavy` modelinde de S1 eksen hatası %9,5 → S2'de %0. **Desen model varyantına özgü değil, model ailesinin davranışı** → mimari karar sağlam zeminde.

⚠️ `heavy`'nin `vis_crit`'i düşük çıktı (0,697 vs 0,842). Bu **"heavy daha kötü" demek DEĞİLDİR**: `visibility` model-özgü bir kalibrasyondur, varyantlar arası doğrudan kıyaslanamaz. Karşılaştırılabilir olan tespit oranı (heavy INV-S1'de 1,000 — full'den yüksek) ve eksen hatasıdır. **Assessment modunda `heavy` kullanma kararı bu ölçümle çürütülmedi; eşikler varyant-başına ayrı kalibre edilecek.**

### 3.4 Video / tracking (S3-S4)

| | 027 (dik→takla) | 020 (barfiks) |
|---|---|---|
| Tespit (VIDEO tracking, düz) | 0,861 | 0,967 |
| Gövde ekseni sıçraması | 0/117 | 2/369 |

**Bulgu 1 — tracking stabil ama tek başına kanıt değil:** ani eksen sıçraması yok; ancak *sürekli ve sistematik* bir yanlış etiketleme sıçrama üretmez. Bu yüzden video kanıtı, tekil görüntü kanıtının yerine geçmez (destekleyicidir).

**Bulgu 2 — ⚠️ HIZLI FAZDA TESPİT TAMAMEN KAYBOLUYOR:** takla anında (kare 94-112) hareket bulanıklığıyla poz **hiç** üretilemedi. Kanıt: [`kanit/kanit-video-tracking.jpg`](kanit/kanit-video-tracking.jpg).
→ **Ürün etkisi:** plan §7.2'nin "kick-up aşırı/yetersiz" metriği, tespitin en zayıf olduğu fazda çalışmak zorunda. **V1 metrik seti TUTUŞ fazı üzerine kurulur; giriş/çıkış metrikleri "best-effort" sınıfına alınır ve güven kapısıyla susturulur.** (Yeni bulgu: G-006.)
*Muhafazakâr okuma:* bu klip yarışma hızında bir takla; yeni başlayanın duvar kick-up'ı çok daha yavaştır. Yani bu, zorluğun ÜST sınırıdır — ama riskin gerçekliğini gösterir.

---

## 4. Mimari kararlar (bu ölçümden doğan, bağlayıcı)

### 4.1 KARAR — Yönelim-farkında çıkarım hattı (`OrientationAwarePoseSource`)

D1 stratejisi **tek bir pipeline aşamasına soyutlanır** (başlangıç promptu: "model değişirse tek nokta"):

```
Kamera karesi
  → [YÖNELİM KESTİRİMİ]   ← beceri durumu (state machine) + önceki karenin ekseni (histerezis)
  → çıkarım (düz | 180° döndürülmüş)
  → landmark'lar orijinal kadraja geri döndürülür
  → [YAPISAL TUTARLILIK KONTROLÜ]  ← §4.2
  → güven kapısı → smoothing → normalizasyon → kural motoru
```

- Kullanıcı **beceriyi kendisi seçer** (handstand denemesi) → uygulama zaten ters-duruş beklediğini bilir. Yönelim kestirimi sıfırdan çözülecek bir problem değil, **ürünün elindeki bilgi.**
- Geçiş anlarında (kick-up) belirsizlik varsa **çift-geçiş** (her iki yönelimde çıkarım, tutarlı olanı seç). Maliyet 2× — yalnız geçiş penceresinde, TUTUŞ boyunca değil. Cihaz bütçesi G5'te ölçülecek.
- Yönelim durumu **histerezisli** tutulur (tek karelik gürültü hattı çevirmesin).

### 4.2 KARAR — Yapısal tutarlılık kontrolü (güven kapısına EK, onun yerine değil)

Kural motoruna girmeden önce her kare deterministik anatomik denetimden geçer:

- beklenen beceri fazıyla eksen uyumu (ters-duruşta baş kalçadan aşağıda, bilekler omuzdan aşağıda),
- kemik uzunluğu tutarlılığı (üst kol ≉ uyluk — takas tespiti),
- kare-arası fiziksel imkânsızlık (40 ms'de >120° gövde dönüşü).

İhlalde: **hüküm YOK** ("analiz edemedim" — plan §7.4 ilkesi), diğer yönelimde yeniden çıkarım denenir.
Bu kontrol **motion-core'a** aittir (beceri-bağımsız; Lissom'un ters pozları, Choreia'nın yer figürleri, JabLab'ın eğilmeleri aynı kontrolden yararlanır) → **M-serisi çekirdek gereksinimi.**

### 4.3 KARAR — Kural motoru sol/sağ etiketlerine GÜVENMEZ

S1↔S2 karşılaştırmasında bir görüntüde (#22) model sol/sağ kimliğini takas etti. Ters-duruşta "sol" görsel olarak belirsizdir.
→ Kurallar **taraf-agnostik** yazılır: taraf seçimi *geometrik* yapılır (kameraya yakın zincir / güveni yüksek zincir), modelin `LEFT_*`/`RIGHT_*` etiketiyle değil. Hiza/dirsek kuralları "görünen taraf zinciri" üzerinden çalışır (§5.1 ile aynı mantık).

### 4.4 KARAR — Model merdiveninde YUKARI ÇIKILMIYOR

MediaPipe Pose (`full` canlı / `heavy` assessment) **aile standardı olarak kalır** (katalog §1). RTMPose/fine-tune yatırımı **gerekmiyor**; merdivenin 1. basamağı (döndürme) sorunu çözdü. Bu karar, ileride gerçek cihaz ölçümü veya kurucu çekimleri aksini gösterirse yeniden açılır.

---

## 5. Protokolden sapmalar (şeffaflık — gizlenmedi)

Protokol §8 "eşiklerin sonradan gevşetilmesi yasaktır" der. Aşağıdaki üç değişiklik **eşik gevşetmesi değil, metrik/veri düzeltmesidir**; hepsi gerekçeli ve kanıtlıdır:

**5.1 — M4 tanımı düzeltildi (12'li min → yan-zincir).**
Protokoldeki M4 ("12 kritik landmark'ın HEPSİ ≥0,5") **kontrol grubunda da başarısız oldu**: DİK insanlarda geçiş oranı yalnızca **0,320**. Yani metrik ters-duruşu değil, **kendine-kapanmayı** ölçüyordu (yan görünümde uzak kol/bacak zaten görünmez — bu doğru davranıştır). %68'i reddeden bir kapı ürünü imkânsız kılardı.
→ Ürün-gerçekçi tanım: **görünen taraf zincirinin** min güveni (kural motoru zaten görünen tarafı kullanır — §4.3).
→ **Kapı kararı bu değişiklikten bağımsızdır:** her iki tanımda da INV ≈ UPR ve S2 > S1. Değişen tek şey, mutlak sayının anlamlı olması.

**5.2 — M5 metodolojisi düzeltildi (sade render → uzuv-renkli render).**
İlk M5 turu tek-renk iskeletle yapıldı ve **eksen terslemesini göremedi** (#9/#21/#53 "doğru" sanıldı). Uzuv-sınıfı renk kodlu render zorunlu kılındı; hükümler yeniden verildi. Kayıt: [`kanit/m5-verdicts.json`](kanit/m5-verdicts.json) — her iki tur da saklandı.

**5.3 — #23 ölçümden SONRA elendi.**
Eleme kaynağa dayanır (Commons kategorisi `Handstands in art` = heykel), ölçüm sonucuna değil. Ölçüm sonrası eleme kural olarak risklidir; bu yüzden gerekçe ve kaynak `screen.json`'a yazıldı. Etkisi: n 43→42; **hiçbir eşik hükmü değişmedi.**

---

## 6. Sınırlar ve borçlar (kapı bunları KAPATMADI)

| # | Borç | Neden önemli | Ne zaman kapanır |
|---|---|---|---|
| B1 | **Vekil ortam** — ölçüm Python Tasks API'de yapıldı; üretim native (Kotlin/Swift) | Aynı model + aynı graf, taşınabilir kabul edildi; ama kanıt değil | G5: gerçek cihazda aynı fixture'larla yeniden ölçüm |
| B2 | **Kadraj temsili değil** — Commons fotoğrafları rastgele açı/uzaklık; ürün sabit, kalibre, tek kişi | Mutlak kapı oranı (0,929) ürün koşullarında muhtemelen DAHA İYİ, ama doğrulanmadı | G3: kurucu çekimleri (birincil fixture hattı) |
| B3 | **Tekil görüntü ≠ deneme** | Tutuş süresi, denge kaybı yönü, salınım vekili zaman serisi ister | G3-G4: video fixture'ları |
| B4 | **Kick-up/çıkış fazı ölçülmedi** (yalnız hızlı taklada tespit kaybı görüldü) | Plan §7.2 metriklerinin bir kısmı riskte (G-006) | G3: yavaş kick-up çekimleri |
| B5 | **fps/ısı/pil ölçülmedi** | Çift-geçiş maliyeti bilinmiyor | G5 benchmark |
| B6 | **Vücut/kıyafet/ışık çeşitliliği kontrolsüz** | Adalet ve gerçek dünya dayanıklılığı | G3 + G8 cihaz matrisi |

**Ölçüm dürüstlüğü taahhüdü (00-AILE-MIMARISI §7):** bu rapordaki hiçbir sayı pazarlama malzemesi DEĞİLDİR. Sayılar kamuya açık fotoğraf setinde, vekil ortamda, tek annotatörle üretilmiştir. Pazarlanacak her doğruluk iddiası kendi ölçümünü ister.

---

## 7. Defter etkisi

| ID | Değişiklik |
|---|---|
| **G-001** (P0) | **KAPANMAYA HAZIR** — kapanış kanıtı bu rapor + `kanit/`. Kurucu onayıyla kapanır; şart: §4.1 mimarisi uygulanır. |
| **M-001** (aile P0) | Aynı kanıtla kapanmaya hazır; aile geneline devreden ders §4.2'nin çekirdek gereksinimi olması |
| **G-006** (yeni, P1) | Hızlı faz (kick-up/çıkış) tespit kaybı → V1 metrik seti TUTUŞ üzerine kurulur, giriş metrikleri best-effort |
| **G-007** (yeni, P1) | Model sol/sağ etiketleri ters-duruşta güvenilmez → kurallar taraf-agnostik (§4.3) |
| **G-008** (yeni, P2) | `visibility` model-varyantları arasında kıyaslanamaz → eşikler varyant-başına kalibre edilir |
| **M-017** (yeni, aile) | Yapısal tutarlılık kontrolü motion-core zorunlu bileşeni (§4.2) — 5 ürünü ilgilendirir |

---

## 8. Kurucudan beklenen (sabah)

1. **Kapı onayı:** §0 hükmü + §4 mimari kararları onaylanıyor mu? (Onaylanırsa G-001/M-001 kapanır, G2 PRD açılır.)
2. **Çekim listesi onayı:** B2/B3/B4 borçları için gerçek çekim planı — ayrı listede sunulacak.
3. Bu raporda para/submission/fiyat kararı **yoktur** — gece kısıtı ihlal edilmedi.

### Ek düzeltme — 2026-07-29: eksen-sıçraması eşiği fps'e gizlice bağlıydı

`tools/d1-gate/vid.py` eşiği `FLIP_DEG = 120.0` idi: **kare başına**, ama 25fps
varsayımından türetilmiş. Kod gerçek fps'i OKUYOR ama eşiği ölçeklemiyordu.
Sonuç: 60fps'te aynı eşik 7200°/s'ye karşılık gelir ve **gerçek bir eksen
terslemesini KAÇIRIR**; düşük fps'te ise sahte-pozitif üretir.

Düzeltme: eşik **°/saniye** cinsine çevrildi (`FLIP_DEG_PER_S = 3000.0`) ve
kare-farkı `dt` ile normalize edildi (60-DSP-SOZLESMESI §1: zamana bağlı eşik
kare-başına değil saniye-başına ifade edilir).

**Bu raporun hükmü DEĞİŞMEZ.** Ölçüm klipleri @25fps'ti: `3000 × (1/25) = 120°`,
yani yeni eşik orijinal koşumda eski sabitin birebir aynısını verir. Düzeltme
davranış-koruyucudur; kazanç, kapının başka kare hızlarında da doğru olmasıdır.
