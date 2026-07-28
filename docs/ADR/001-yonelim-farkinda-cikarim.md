# ADR-001 — Yönelim-farkında çıkarım hattı

**Durum:** kabul (2026-07-26) · **Kanıt:** [`../gates/G1-D1-RAPOR.md`](../gates/G1-D1-RAPOR.md) · **Defter:** G-002 · **Aile:** M-019

## Bağlam
MediaPipe Pose (BlazePose GHUM) ağırlıkla dik insan görüntüsüyle eğitilmiştir. Handstand baş-aşağı bir vücuttur. D1 kapısı bunu ölçtü.

## Ölçüm ne buldu
Beklenen risk (güven düşüşü) **çıkmadı**: ters-duruş `vis_crit` 0,842 vs dik 0,873.
Bulunan risk: **eksen terslemesi** — model ters vücudu dik sanıp kol↔bacak zincirlerini takas ediyor. Düz çıkarımda **3/41 (%7,3)**, `heavy`'de %9,5. Hata **yüksek güvenle** geliyor (#21: `vis_crit`=0,93) ve iskelet şekli üst/alt gövde simetrisi nedeniyle **doğru görünüyor**.
180° döndürülmüş giriş + landmark geri döndürme: **0/42 eksen hatası, 42/42 tespit** (düz çıkarımda 41/42).

## Karar
Poz kaynağı, **yönelim-farkında tek bir soyutlama** arkasına alınır (`OrientationAwarePoseSource`):
1. Yönelim, **beceri durum makinesinin beklentisinden** kestirilir (kullanıcı beceriyi kendi seçtiği için uygulama zaten ters-duruş beklediğini bilir) + önceki karenin ekseni (**histerezis**, N kare tutarlılık).
2. Kestirilen yönelime göre giriş düz veya 180° döndürülmüş verilir; landmark'lar **her zaman orijinal kadraja** geri döndürülür (`x→1-x, y→1-y`; 180° in-plane rotasyon yansıma DEĞİLDİR, indeks takası gerekmez).
3. Belirsiz fazlarda (`ENTRY`, `EXITING`) **çift-geçiş**: iki yönelimde çıkarım, yapısal denetimi geçen ve güveni yüksek olan seçilir.

## Sonuçlar
- ✅ Ters-duruş hattı açılabilir; model merdiveninde yukarı çıkmaya (RTMPose, fine-tune) gerek yok.
- ⚠️ Çift-geçiş 2× çıkarım maliyeti — yalnız geçiş penceresinde, TUTUŞ boyunca değil. **Maliyet G5'te ölçülecek.**
- ⚠️ Dik pozlarda döndürülmüş çıkarım kullanılırsa **ters yönde hata** doğar (UPR-S2'de 1/24 = %4,2). Strateji "her zaman döndür" DEĞİL, "doğru yönelimi seç"tir.
- Model/strateji değişimi tek noktadan yapılır; `orientationStrategy` her denemeye yazılır (ADR-005).

## Reddedilen alternatifler
- **Her zaman düz çıkarım:** kapıyı geçmiyor (%9,5 kullanılamaz kare).
- **Her zaman döndürülmüş çıkarım:** dik fazları bozar; onboarding/kalibrasyon/hazırlık düğümleri dik.
- **Tracking'e güvenmek (VIDEO modu tek başına):** ölçüldü — ani eksen sıçraması üretmiyor ama *sistematik* yanlış etiketlemeyi de dışlamıyor; ayrıca hızlı fazda tespit tamamen kayboluyor. Yardımcıdır, çözüm değildir.
- **RTMPose / fine-tune:** gereksiz maliyet; merdivenin 1. basamağı sorunu çözdü.
