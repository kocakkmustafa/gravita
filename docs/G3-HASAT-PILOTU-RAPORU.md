# G3 — Hasat Pilotu Raporu (Gravita)

**Tarih:** 2026-07-29 · **Rig:** motion-core `tools/harvest_rig` · **Kural:** M-F-32
**Kütüphane:** `~/motion-harvest/gravita/` (ham medya repoda YOK — M-F-26)
**Provenance:** `content/harvest/queue.gravita.json`

---

## 1. Kuyruk keşfi — 23 aday / 5 hareket

Sayım birimi **eğitmen** (M-F-32). Video kimlikleri uydurulmadı; `yt-dlp`
aramasıyla çözüldü, sorgu/kanal/süre/keşif-tarihi provenance'a yazıldı.

| Hareket | Bağımsız eğitmen | Durum |
|---|---:|---|
| push_up | 5 | ✓ |
| pull_up | 5 | ✓ |
| bodyweight_squat | 6 | ✓ |
| dip | 4 | ~ |
| plank | 3 | ~ (triyaj sonrası ≥3 kalmayabilir) |

### ⚠️ Bulgu H-1: "kanal başına en uzun video" sezgisi YANLIŞ hareketi seçiyor

İlk koşumda push_up için bulunan 5 eğitmenin **3'ü başka hareket** anlatıyordu:
mobilite rutini · **handstand** push-up · **Hindu** push-up. Üçü de bizim
kataloğumuzda ayrı hareket.

O kuyrukla üretilecek "şınav referansı" handstand push-up'ların ortalaması
olurdu. Katalog §6.0 toleransı **eğitmenler-arası varyanstan** türetiyor —
yanlış hareketin varyansı toleransı değil **gürültüyü** ölçer.

**Düzeltme:** alaka süzgeci (`require` + `reject` token'ları; reddedilenler
provenance'a yazılıyor). Ayrıca kanal başına **en KISA** alakalı video tercih
ediliyor — uzun video genelde derleme/vlog.

## 2. Uçtan uca pilot — 4 video

| Video | Kanal | Süre | Netlik | Üst-gövde | Sonuç |
|---|---|---:|---:|---:|---|
| kKHxpbBGiuM | GMB (push_up) | 120s | 70,2 | 1,00 | ✅ fixture üretildi |
| XB_7En-zf_M | FitnessFAQs (pull_up) | 144s | 79,5 | 0,50 | ⛔ üst-gövde < 0,6 |
| l41SoWZiowI | FitnessFAQs (dip) | 341s | 471,3 | 0,50 | ⛔ üst-gövde < 0,6 |
| Tp7jFLRmXu8 | FitnessFAQs (plank) | 217s | **37,6** | — | ⛔ netlik < 40 |

**Hayatta kalma: 1/4 = %25.** M-F-32'nin varsaydığı ~%60'ın çok altında.
Bu oran sürerse "5 eğitmen" hedefi triyaj sonrası ~1,3 eğitmene düşer —
≥3 şartı karşılanmaz ve referans kurulamaz.

Rig doğru çalıştı: reddedilen her klip de manifest bıraktı, "neden havuzda yok"
sorusu cevaplanabilir durumda.

## 3. ⚠️ Bulgu H-2 (P1) — Triyaj kapısı, işe yarar içerikle KORELE DEĞİL

Hipotezim "tüm-video triyajı kullanılabilir malzemeyi çöpe atıyor"du. Ölçtüm —
**kısmen yanlış çıktı, ama asıl sorun daha kötü.**

2 Hz örneklemeyle her videonun **tam-gövde** görünürlüğünü ve en uzun kesintisiz
penceresini ölçtüm:

| Video | Triyaj | Tam-gövde oranı | En uzun kesintisiz pencere |
|---|---|---:|---:|
| pull_up FitnessFAQs | ⛔ RED | 0,01 | **0,5 s** |
| dip FitnessFAQs | ⛔ RED | 0,09 | **6,0 s** |
| push_up GMB | ✅ GEÇTİ | 0,15 | **5,0 s** |

Üç gözlem:

1. **pull_up reddi DOĞRUYDU** — 0,5 s kullanılabilir pencere gerçekten yetersiz.
   Hipotezimin bu yarısı çürüdü.
2. **Ama geçen video, reddedilenden DAHA AZ kullanılabilir malzeme taşıyor**
   (5,0 s < 6,0 s). Kapı, önemli olan büyüklüğü ölçmüyor.
3. **Asıl bulgu:** eğitmen tutorial'larında tam-gövde görünürlüğü **%1-15**.
   Ders videoları ağırlıkla konuşan-kafa, yakın çekim ve b-roll; gösterim
   saniyelerle ölçülüyor.

**Sebep:** rig'in kapısı **üst-gövde** oranına bakıyor — bu konuşan-kafa
karelerinde de geçer. Gravita'nın ölçtüğü şey (omuz-kalça-ayak hattı, diz
açısı, hat sapması) **tam gövde** ister. Kapı bizim ihtiyacımızı ölçmüyor.

**Öneri (koordinatöre — rig çekirdek-sahipli):**
- Gravita için `TriageThresholds`: `min_full_body_ratio` (üst-gövde yerine) ve
  eşik oran değil **en uzun kesintisiz pencere ≥ N saniye** olsun. Oran, uzun
  bir vlog'da yüksek çıkabilir ama hiç kesintisiz gösterim içermeyebilir.
- Netlik eşiği 40 mutlak: 37,6'lık 1080p bir tutorial reddedildi, başka bir klip
  471,3 aldı. Bu dağılımda sabit eşik kırılgan — içerik-göreli (ör. medyan-
  normalize) daha sağlam olur.

## 4. ⚠️ Bulgu H-3 (P1) — Referans hattı VERİ-FAKİRİ olacak

En iyi durumda bile eğitmen başına **~5-6 saniye** kesintisiz tam-gövde
gösterimi var. Bir şınav tekrarı ~2-3 sn olduğuna göre bu **eğitmen başına
≈2 tekrar** demek; 3 eğitmenle **≈6 tekrar**.

Katalog §6.0 toleransı eğitmenler-arası varyanstan türetiyor. 6 tekrarlık bir
örneklemden türetilen tolerans, **istatistiksel olarak zayıf** olur — ve o
tolerans 180 hareketin form hükümlerini belirleyecek.

Bu, G-014'ün ("provizyonel eşikleri kaynak varyansıyla değiştir") kapanışını
doğrudan etkiliyor: hasat, eşikleri kalibre etmeye tek başına yetmeyebilir.

**Sonuç olarak açık kalan:** eğitmen sayısını artırmak (10-15?) mi, yoksa
tolerans türetimini başka bir kaynağa (sentetik varyasyon + literatür normları)
dayamak mı gerekiyor — bu bir **ölçüm** sorusu ve daha geniş bir pilot ister.

## 5. G-026 dersinin fixture etiketlerine taşınması

Temas metriklerinin **eklemden değil temas eden yüzeyden** ölçülmesi kuralı
(G-026) hasat fixture'larında da geçerli: eğitmen videolarında parmak-ucu
pozisyonları (plank, şınav, lunge, calf raise) aynı tuzağı kurar. Fixture
etiket şemasına `contactPoint: "foot" | "hand" | "forearm"` alanı eklenmeli;
ayak bileği/bilek yüksekliğinden zemin kestiren her etiket yanlıştır.

## 6. Durum

- Kuyruk + provenance: `content/harvest/queue.gravita.json` (23 aday, alaka
  redleri dahil)
- Ham kütüphane: `~/motion-harvest/gravita/` — 4 video, 1 fixture, 4 manifest
- **Blokaj yok**, ama H-2 ve H-3 kapanmadan geniş hasat başlatmak veri israfı
  olur: eşikler bizim ihtiyacımızı ölçmüyor ve verim ölçülmedi.
