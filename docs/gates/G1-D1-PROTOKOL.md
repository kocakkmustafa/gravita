# G1 / D1 — Ters-Duruş Fizibilite Kapısı: ÖLÇÜM PROTOKOLÜ

**Tarih:** 2026-07-26 · **Statü:** Eşikler ÖLÇÜMDEN ÖNCE yazıldı (bağlayıcı — `20-URETIM-SURECI.md §2.6`)
**Defter bağı:** G-001 (Gravita P0) · M-001 (aile P0) · **Hiyerarşi:** `00-AILE-MIMARISI.md §3/D1` > `10-ARAC-KATALOGU.md §1` > bu dosya.

> ⚠️ Bu doküman ölçüm SONUÇLARINI içermez. Sonuç: `G1-D1-RAPOR.md`.
> Eşiklerin sonradan gevşetilmesi yasaktır; gerekçeli değişiklik = yeni protokol sürümü + DEFTER kaydı.

---

## 1. Kapının cevaplayacağı soru

**Ürün sorusu (kapıyı bu belirler):** Handstand yapan bir kullanıcının denemesinde, deterministik kural motorumuz **kaç karede hüküm verebilir**? Kullanılabilir landmark üretilemiyorsa ürün "analiz edemedim" der — bu dürüsttür ama oran yüksekse ürün YOKTUR.

**Teknik soru:** MediaPipe Pose Landmarker (BlazePose GHUM), ters-duruştaki bir vücutta hangi güven ve hangi mekânsal isabetle landmark üretir; bu, dik vücuda göre ne kadar bozulur; hangi strateji bozulmayı geri alır?

## 2. Ayrıştırılacak iki confound (deney tasarımının çekirdeği)

Naif ölçüm ("handstand videosunda güven düşük mü?") yorumlanamaz, çünkü iki değişken aynı anda değişir:

| Confound | Tanım | Ürün açısından anlamı |
|---|---|---|
| **A — Yönelim** | Baş kadrajın altında, vücut 180° dönük | Çözülebilir (döndürme hilesi / tracking) |
| **B — Poz alışılmadıklığı** | Yük ellerde, omuz fleksiyonda kapalı, bacaklar yukarı | Çözülemez (modelin eğitim dağılımı dışı) |

Tasarım bunları **kontrol setleriyle** ayırır (§4). A baskınsa D1 ucuz çözülür (kod-tek). B baskınsa model merdiveninde yukarı çıkılır (RTMPose / fine-tune) → kurucu kararı.

## 3. Ölçülecek stratejiler

| Kod | Strateji | Gerekçe |
|---|---|---|
| **S1** | IMAGE modu, giriş olduğu gibi | Temel çizgi (baseline) |
| **S2** | IMAGE modu, giriş **180° döndürülmüş**, landmark'lar geri döndürülür | Katalog §1 "döndürme hilesi" — kod-tek çözüm adayı |
| **S3** | VIDEO modu (tracking), klip **dik girişten** başlar | 🔑 Ürün-gerçekçi senaryo: kullanıcı kadrajda dik durur → kick-up → tracking ters-duruşa TAŞINIR; detector'ın ters vücudu sıfırdan bulması gerekmez |
| **S4** | VIDEO modu + 180° döndürülmüş akış | S2×S3 birleşimi |

**S3 neden kritik:** BlazePose iki aşamalıdır (detector → landmark). Detector kişi-merkezli ROI + omuz-kalça ekseniyle **rotasyon normalize eder**; landmark modeli teorik olarak dikleştirilmiş kırpıntı görür. Bozulma detector'da ise tracking bunu **tamamen** atlar (ROI önceki kareden gelir). Bu, mimarimizin en ucuz sigortasıdır ve ölçülmeden varsayılamaz.

## 4. Veri setleri (lisansı kayıtlı; §7)

| Set | İçerik | Rol |
|---|---|---|
| **INV** | Gerçek ters-duruş (handstand, headstand, ellerin üstünde denge; yoga adho mukha vrksasana) | Ana ölçüm hedefi (A+B birlikte) |
| **UPR** | Aynı kaynak havuzundan **dik** insan (ayakta, yoga ayakta pozları, spor) | Temel çizgi (ne A ne B) |
| **UPR‑ROT** | UPR'nin **yazılımla 180° döndürülmüş** hali | 🔬 **Saf A izolasyonu**: poz normal, yönelim ters. UPR→UPR‑ROT düşüşü = yönelim etkisi |
| **INV‑ROT** | INV'in 180° döndürülmüş hali (= dik görünen handstand) | 🔬 **Saf B izolasyonu**: yönelim düzeltilmiş, poz hâlâ alışılmadık. UPR→INV‑ROT düşüşü = poz etkisi |
| **VID** | Dik girişten ters-duruşa geçen klip(ler) | S3/S4 tracking ölçümü |

**Not:** UPR‑ROT ile S2 aynı şey DEĞİLDİR: UPR‑ROT bir veri seti (yönelim etkisini ölçer), S2 bir strateji (yönelim etkisini geri alır). INV üzerinde S2 uygulamak = INV‑ROT'a S1 uygulamakla sayısal olarak eş; rapor bunu tutarlılık kontrolü olarak kullanır.

## 5. Metrikler

**Kritik landmark seti (Gravita kural motorunun kullandıkları):** omuzlar (11,12) · dirsekler (13,14) · bilekler (15,16) · kalçalar (23,24) · dizler (25,26) · ayak bilekleri (27,28). Baş (0) ikincil.

| # | Metrik | Tanım | Neden |
|---|---|---|---|
| M1 | `detect_rate` | Poz döndürülen kare/görüntü oranı | Hiç landmark yoksa hüküm yok |
| M2 | `vis_crit` | 12 kritik landmark'ın ortalama `visibility` | Güven kapımızın hammaddesi |
| M3 | `vis_crit_min` | Kare içindeki EN DÜŞÜK kritik güven | Kural motoru en zayıf halkaya bağlıdır |
| M4 | `gate_pass_rate` | `min(kritik visibility) ≥ 0.5` olan kare oranı | **Ürün metriği: hüküm verilebilen kare oranı** |
| M5 | **`overlay_verdict`** | Elle görsel denetim: `CORRECT` / `PARTIAL` / `GROSS` | ⭐ Güven ≠ doğruluk. İskelet çizilip GÖZLE denetlenir |
| M6 | `lr_swap` | Sol/sağ kimlik karışması (bkz. §6) | Hiza kuralları taraf-duyarlı |
| M7 | `bone_cv` | Kemik uzunluklarının kare-arası varyasyon katsayısı (VID) | Titreşim/kararsızlık vekili |
| M8 | `strategy_agreement` | S1↔S2 landmark mesafesi / gövde uzunluğu | Uyuşmazlık = en az biri yanlış |

> **⚠️ ÖLÇÜM SONRASI DÜZELTME (2026-07-26, rapor §5.1/§5.2 — gerekçe ve kanıt orada):**
> - **M4 tanımı değişti:** "12 kritik landmark'ın hepsi ≥0.5" ölçütü **geçersiz çıktı** — DİK kontrol grubunda da yalnız %32 geçiyor (kendine-kapanmayı ölçüyor, ters-duruşu değil). Geçerli tanım: **görünen taraf zincirinin** min güveni ≥0.5. Eşik (0.85) DEĞİŞMEDİ.
> - **M5 yöntemi değişti:** sade tek-renk iskelet bindirmesi **eksen terslemesini göremiyor**. Uzuv-sınıfı renk kodlu render (KOL=kırmızı · BACAK=mavi · BAŞ=sarı) artık ZORUNLU.
> - **Yeni zorunlu metrik M9 — eksen terslemesi:** ters-duruş setinde yapısal değişmez (baş kalçadan aşağıda) ihlali. `visibility` bu hatayı YAKALAYAMAZ; M9'suz kapı eksiktir.

**M5 protokolü (elle denetim):** her görüntüye **uzuv-renkli** iskelet bindirilir, ana oturum görüntüyü açıp sınıflandırır.
- `CORRECT` — iskelet anatomik olarak doğru; kritik eklemler yerinde (göz kararı ≲ el genişliği hata).
- `PARTIAL` — gövde doğru ama ≥1 uzuv yanlış (ör. ayaklar kayık, bir kol düşük).
- `GROSS` — iskelet vücutla ilgisiz / uzuvlar takas / poz tamamen yanlış yorumlanmış.
Sınıflandırma kaydı rapora eklenir (görüntü kimliği + hüküm), böylece üçüncü taraf tekrar denetleyebilir.

**M6 tanımı (lr_swap):** Ters-duruşta "sol" landmark'ın görüntüde nerede olduğu kameraya bağlıdır, dolayısıyla mutlak taraf testi geçersizdir. Bunun yerine **iç tutarlılık** ölçülür: aynı klipte kare-arası sol/sağ eklem çiftlerinin ani yer değiştirmesi (bir karede sol-omuz solda, ertesi karede sağda, vücut dönmemişken) = swap olayı. Tekil görüntülerde M6 yerine M5 (`GROSS` sınıfı uzuv-takasını yakalar) kullanılır.

## 6. Ölçüm koşulları (sabitlenir)

- Model: `pose_landmarker_full.task` (canlı koçluk varyantı; katalog §1) — **ana karar bunun üstünden**. `heavy` ikinci geçişte kıyas için ölçülür (assessment modu).
- `min_pose_detection_confidence=0.5`, `min_pose_presence_confidence=0.5`, `min_tracking_confidence=0.5` (Tasks varsayılanları) — eşik oynatarak sonuç güzelleştirme YASAK; varyasyon denenirse rapora ayrı satır olarak yazılır.
- `num_poses=1` (ürün tek-kişi senaryosu).
- Model dosyası SHA-256 + sürüm rapora yazılır (katalog §1: model pinlenir).
- ⚠️ **Vekil ortam uyarısı:** ölçüm Python Tasks API ile yapılır; üretim hattı native (Kotlin/Swift) Tasks API'dir. Aynı model + aynı graf → sonuçlar taşınabilir kabul edilir, ama **G5'te gerçek cihazda yeniden doğrulama zorunludur** (rapora bekleyen-doğrulama olarak yazılır).

## 7. Lisans disiplini (M-014 / katalog §0, §6)

- Her görüntü/klip için kaynak URL + lisans + yazar `veri-envanteri.json`'a yazılır.
- Bu sette YALNIZ **ölçüm** yapılır. Repoya ham medya COMMIT EDİLMEZ; yalnız türetilmiş landmark JSON'ları + metrik tabloları girer.
- Non-commercial / belirsiz lisanslı kaynakla **ship edilen model eğitilmez** (katalog §0). Bu kapı model eğitmez, yalnız ölçer.
- Birincil fixture hattı yine kurucu çekimleridir (katalog §6) — bu set onun yerine geçmez, kapıyı gece açmak için **ön-ölçüm** sağlar.

## 8. KARAR EŞİKLERİ (ölçümden önce sabit)

Eşikler **en iyi stratejinin** INV seti üzerindeki sonucuna uygulanır.

### 🟢 NET GEÇTİ — ters-duruş hattında üretim kodu açılır (gece: "ŞARTLI GEÇTİ", onay sabah)
Hepsi birden sağlanmalı:
- M1 `detect_rate` ≥ **0.95**
- M2 `vis_crit` ≥ **0.80**
- M4 `gate_pass_rate` ≥ **0.85**
- M5 `CORRECT` ≥ **%80** ve `GROSS` ≤ **%5**
- M8 seçilen strateji ile alternatifin uyuşmazlığı raporlanmış (karar gerekçeli)

### 🟡 SINIRDA — ters-duruş ÜSTÜ üretim kodu AÇILMAZ (gece kuralı); kapıya bağımsız işler öne çekilir
- M1 ≥ 0.90 **veya** M2 ≥ 0.70 **veya** M4 ≥ 0.70 bandında kalıp yeşili tutturamayan her sonuç.
- Aksiyon: model merdiveni 2. basamağı (RTMPose) aynı sette ölçülür → kurucuya karşılaştırmalı karar.

### 🔴 ALTINDA — hat kapalı
- M1 < 0.90 veya M4 < 0.70 veya M5 `GROSS` > %15.
- Aksiyon: kurucuya "MediaPipe tek başına yetmez" raporu + merdiven 2-4 maliyet/fayda tablosu.

### Ek karar kuralı — confound ataması (§2)
- `UPR − UPR‑ROT` farkı büyük **ve** `UPR − INV‑ROT` farkı küçük → **A baskın** → döndürme/tracking ile çözülür (ucuz).
- `UPR − INV‑ROT` farkı büyük → **B baskın** → yönelim düzeltmesi yetmez; merdiven yukarı (pahalı) — bu bulgu yeşil eşiği geçse bile rapora KIRMIZI-BAYRAK olarak yazılır (ileride zor pozlarda kırılganlık).

## 9. Kapı çıktısı

`G1-D1-RAPOR.md`: koşullar + veri envanteri + metrik tabloları + elle denetim kayıtları + confound ataması + **strateji kararı önerisi** + mimari yansıması (pipeline'da nereye oturur) + gerçek-cihaz doğrulama borcu. Kurucu onayı sabah retrospektif (gece modu).
