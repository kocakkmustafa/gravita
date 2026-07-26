# ADR-006 — Değerlendirme-kapılı soft paywall

**Durum:** **ÖNERİ** — nihai fiyat ve paywall yeri kurucu kararıdır (`20-URETIM-SURECI §0`) · **Kaynak:** `10-ARAC-KATALOGU §8` · **Faz:** G9

## Bağlam
Gravita bir "ölç → geliş" ürünüdür. Değer, kullanıcı **kendi ölçümünü görene kadar** soyuttur. Katalog §8 aile deseni olarak GOWOD tarzı **değerlendirme-kapılı soft paywall** öneriyor; kategori medyanı ~$9,70/ay, koridor $9,99-14,99/ay · $59,99-89,99/yıl.

## Öneri
1. **Paywall ÖNCESİ ücretsiz:** onboarding + kalibrasyon + **başlangıç değerlendirmesi** + ilk beceri yolunun ilk düğümleri (`wrist_prep`, `hollow_body`, `wall_plank`) — yani kullanıcı ilk gerçek ölçümünü ve ilk düzeltmesini görür.
2. **Paywall SONRASI:** tam skill-graph · deneme geçmişi + karşılaştırma · tüm drill kütüphanesi · yardımcı/ayrı beceri dalları.
3. Yıllık plan "Best Value" vurgusu (katalog §8: yıllık tutundurma 44,1% vs aylık 17,5%).
4. Trial 7 gün varsayılan; **14+ gün ciddi değerlendirilmeli** — beceri gelişimi bir haftada görünmez (katalog §8).

## Neden bu yer
- Değerlendirme, ürünün *farkının* kanıtlandığı andır (kamerayla ölçüm — rakiplerin çoğu ölçmüyor, roadmap §2).
- İlk düğümler zaten **hazırlık** düğümleri: kullanıcı bedelsiz gerçek fayda alır, ileri (ve riskli) beceriler abonelik arkasında kalır — güvenlikle de uyumlu.

## Sonuçlar / şartlar
- Ücretsiz katman **çevrimdışı** çalışmalı (plan §3.7) — paywall ağ bağımlılığı yaratmamalı.
- ⚠️ "Ücretsizken kırık özellik satmak" yasak: LifeOS dersi (Export özelliği Pro'ya paralı ama kırıktı). Paywall arkasındaki her özellik **çalışır kanıtlı** olacak (G9 kapısı).
- IAP kurgusu riskli sınıftadır: Fable yönetir + **Opus bağımsız doğrular** + sandbox kanıtı (holding sert kuralı).
- Fiyat ilanı, `privacy-data-guardian` + `store-policy-officer` turlarından önce YAPILMAZ.

## Kurucuya sorular (G9)
1. Koridorun neresi? (öneri: aylık $11,99 · yıllık $69,99 ≈ %51 indirim — LifeOS'taki yıllık-ağırlıklı desenle uyumlu)
2. Trial 7 mi 14 mü?
3. Aile paketi lansmanda YOK (katalog §8) — onaylanıyor mu?
