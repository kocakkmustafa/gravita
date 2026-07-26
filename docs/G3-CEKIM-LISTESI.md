# G3 — Çekim Listesi (kurucu eli gerektiren iş)

**Tarih:** 2026-07-26 · **Amaç:** D1 kapısının açık bıraktığı borçları kapatmak (rapor §6: B2, B3, B4) ve **birincil fixture hattını** kurmak (katalog §6: "kendi kayıtlarımız birincil").
**Neden gerekli:** kapı ölçümü kamuya açık fotoğraflarla yapıldı — rastgele açı/uzaklık. Ürün ise **sabit, kalibre, tek kişi** kamerası kullanıyor. Mutlak oranlar bu koşulda YENİDEN ölçülmeden taahhüde dönüşemez (G-009).

---

## 0. Önce oku: bu çekim ne işe yarıyor

| Çekim grubu | Hangi borcu kapatır | Hangi işi açar |
|---|---|---|
| A — Kalibre tutuş | B2 (temsili kadraj) | Gerçek kapı oranı; `analysis_confidence` eşiğinin kalibrasyonu (borç D-4) |
| B — Yavaş giriş/çıkış | B4 + **G-006** | Kick-up metriği gerçekten ölü mü? (yarışma taklası zorluğun ÜST sınırıydı) |
| C — Kasıtlı hatalar | — | **Fixture kütüphanesinin çekirdeği**: motor kodu bunlar olmadan yazılamaz (`20-URETIM-SURECI` G3 kapısı: her teknik için ≥1 doğru + ≥2 hatalı) |
| D — Bozuk koşullar | — | "Analiz edemedim" yolunun testi (yanlış hüküm vermemenin kanıtı) |
| E — Çeşitlilik | B6 | Vücut tipi/kıyafet/ışık dayanıklılığı |

---

## 1. Kamera kurulumu (her çekimde AYNI — bu bir deney, tatil videosu değil)

- **Telefon:** dikey değil **YATAY** (landscape). Handstand dikey bir hareket ama yatay kadraj duvar/zemin bağlamını ve yana devrilmeyi yakalar.
- **Yükseklik:** yerden **~60-80 cm** (bel hizası değil — kalça/gövde ortası ters-duruşta kadrajın ortasına düşsün).
- **Mesafe:** kişinin tam boyu + **her iki uçta ~%20 boşluk** kalacak kadar. Eller ve ayaklar ASLA kadraj dışına çıkmasın.
- **Açı:** kameraya **YAN** profil (birincil) — hiza hattı (omuz-kalça-ayak) en iyi yandan görünür. Ek olarak aynı denemenin **önden** çekimi (ikincil, varsa).
- **Sabit:** tripod/kitap yığını. **Elde tutulmuş çekim yok** (kamera hareketi ayrı bir test grubudur, D-3).
- **Ayarlar:** 1080p, **60 fps** (varsa; sonradan 30/25'e düşürüp fps etkisini ölçebiliriz — 60'tan düşmek mümkün, tersi değil), otomatik pozlama kilitli olursa daha iyi.
- **Süre:** her deneme ayrı klip; başında ve sonunda **2 sn dik duruş** bırak (yönelim temel çizgisi — ADR-001 kalibrasyon mantığı).

## 2. Çekim listesi

### Grup A — Kalibre tutuş (öncelik 1, en kritik)
| # | Ne | Adet | Not |
|---|---|---|---|
| A1 | Chest-to-wall handstand tutuş | 5 klip × 10-20 sn | Ana hiza referansı |
| A2 | Duvara sırt dönük handstand tutuş | 5 klip | Farklı duvar ilişkisi |
| A3 | Serbest handstand denemesi (tutabildiğin kadar) | 8 klip | Kısa da olsa değerli |
| A4 | Crow pose tutuş | 3 klip | Yardımcı dal |
| A5 | Headstand tutuş | 3 klip | ⚠️ Boyun yükü — zorlamadan |
| A6 | Hollow + arch hold | 2+2 klip | Ters DEĞİL — dik kontrol grubu |

### Grup B — Yavaş giriş/çıkış (öncelik 1 — G-006 yeniden ölçümü)
| # | Ne | Adet | Not |
|---|---|---|---|
| B1 | **Yavaş** kick-up duvara (başlangıç hızı) | 6 klip | Kapıdaki yarışma taklası ≠ bu. Asıl soru burada cevaplanır |
| B2 | Kasıtlı **yetersiz** kick-up (havada kalıp geri gelme) | 4 klip | Hata fixture'ı |
| B3 | Kasıtlı **aşırı** kick-up (duvara çarpma / öne devrilme) | 4 klip | Güvenli ortamda |
| B4 | Kontrollü çıkış (adım adım inme) | 4 klip | |
| B5 | Kontrolsüz çıkış / yana dönerek bail-out | 4 klip | Güvenlik cue'sunun referansı |

### Grup C — Kasıtlı hatalar (öncelik 2 — fixture kütüphanesi)
Her biri **bilerek yanlış** yapılacak; kural motorunun neyi yakalaması gerektiğini bunlar tanımlıyor.
| # | Hata | Adet |
|---|---|---|
| C1 | Aşırı bel çukuru ("banana back") | 4 |
| C2 | Bükülü dirsek (belirgin) | 4 |
| C3 | Eller çok geniş / çok dar | 3+3 |
| C4 | Omuzlar kapalı (kalça öne kaçmış, "L şekli") | 4 |
| C5 | Bacaklar ayrık / dizler bükülü | 3+3 |
| C6 | Baş aşırı yukarı / aşırı içe | 3+3 |
| C7 | Denge kaybı: **öne** · **arkaya** · **yana** | 3 × 3 |

### Grup D — Bozuk koşullar (öncelik 2 — "analiz edemedim" testi)
| # | Ne | Adet |
|---|---|---|
| D1 | Ayaklar kadraj dışında | 3 |
| D2 | Eller kadraj dışında | 3 |
| D3 | Çok karanlık / arkadan güçlü ışık (pencere) | 3+3 |
| D4 | Kamera çekim ortasında kaydırılıyor | 3 |
| D5 | Kadrajda ikinci kişi geçiyor | 3 |
| D6 | Bol/sarkan kıyafet (vücut hattı gizli) | 3 |

### Grup E — Çeşitlilik (öncelik 3 — gönüllü gerekir)
| # | Ne | Not |
|---|---|---|
| E1 | 2-3 farklı kişi, aynı kurulumla A1+A3+B1 | Vücut oranı/tip çeşitliliği |
| E2 | Aynı kişi, 2 farklı kıyafet (dar/bol) | |
| E3 | Aynı kişi, 2 farklı ışık (gündüz/akşam yapay) | |
| E4 | 2 farklı cihaz (varsa bir Android + bir iPhone) | Kamera farkı |

**Yapamadığın hareket varsa boş bırak, uydurma.** Eksik grup, yanlış veriden iyidir; ilgili metrik "doğrulanmadı" olarak kalır ve rapora yazılır.

## 3. Güvenlik (bu liste bir antrenman programı DEĞİLDİR)

- Grup B3 (aşırı kick-up) ve C7 (denge kaybı) **kasıtlı düşme senaryolarıdır** — yalnız kendini güvende hissettiğin ortamda, mat/boş alan ile, ısınmış halde çek. Zorlanma varsa ATLA.
- Ağrı varsa çekim durur. Bu veri seti için sakatlanmak, projenin hiçbir maddesine değmez.
- Headstand (A5): boyun yükü — kısa tut, rahatsızlıkta bırak.

## 4. Gönüllüler için (Grup E)

Yazılı/sözlü **açık onay** şart, ve kapsamı net olsun:
- Videolar **yalnız uygulamanın iç geliştirme ve testinde** kullanılacak.
- **Yayınlanmayacak, paylaşılmayacak, model eğitiminde kullanılmayacak** (katalog §6: kendi kayıtlarımız fixture içindir).
- Videolardan **landmark koordinatları** çıkarılıp saklanacak; ham videolar yerelde kalacak, repoya girmeyecek.
- Kişi isterse verisi silinir.

## 5. Teslim ve adlandırma

Dosya adı: `<grup><no>_<kisi>_<varyant>_<sira>.mp4` → örn. `A1_kaan_ctw_01.mp4`, `C1_kaan_banana_03.mp4`
Klasör: `~/gravita-fixtures/2026-07-xx/` (⚠️ **repo içine KOYMA** — ham medya commit edilmez, protokol §7)
Her oturum için tek satır not: cihaz · yaklaşık ışık · zemin · varsa aksaklık.

## 6. Tahmini süre

| Grup | Süre |
|---|---|
| A + B (öncelik 1) | ~60-75 dk |
| C + D (öncelik 2) | ~60 dk |
| E (gönüllü) | kişi başı ~20 dk |

**Sadece A + B çekilirse bile G3 başlayabilir** — C/D sonradan eklenebilir (G3↔G4 iteratiftir, `20-URETIM-SURECI §1`).

## 7. Çekim sonrası (oturumda otomatik)

1. `tools/d1-gate/` hattı klipler üzerinde koşar → landmark JSON + metrik tabloları.
2. **D1 kapısı gerçek veriyle YENİDEN ölçülür** (borç B2/B3/G-009 kapanır) — sonuç `G1-D1-RAPOR-v2` olarak eklenir; eşikler değişirse gerekçesiyle.
3. Fixture'lar aile şemasına (katalog §6) çevrilir + replay harness'a bağlanır → G3 kapısı.
4. **G-006 yeniden değerlendirilir:** yavaş kick-up'ta tespit tutuyorsa `kickup_impulse` kapı-olabilir sınıfına terfi eder (içerik paketinde tek satır).
