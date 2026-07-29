# G-066 — hipKneeCoupling kanonik ev kararı uygulandı: hasat-anında-bir-kez + damga

**Koordinatör hükmü (M-F-96):** kanonik formül = mocore `anatomical=True`
yolu (WORLD-3D + sagittal-projeksiyon). Mimari karar: kimlik metriği HASAT
ANINDA BİR KEZ hesaplanır ve provenance'a damgalanır; tüketiciler sayıyı
OKUR, yeniden hesaplamaz — kopya-sürüklenmesi sınıfı (G-065'in bulduğu)
kökten kapanır.

## Uygulama

1. **`tools/hip_knee_coupling_canonical.py`** — paylaşımlı `fixture_pipeline`
   venv'inde çalışır, `motion-core/lib/tools/fixture_pipeline/mocore`'u
   içe aktarır. Metrik tanımları Lissom'un `lissom-metrics.v1.json`'undan
   `MetricDef.from_dict` ile OKUNUR (elle kopyalanmadı — iki app aynı
   sözlüğü paylaşıyor). Her squat fixture'ının WORLD koordinatlarını
   `mocore.measures.evaluate(anatomical=True)` ile işler, eğitmen başına
   Pearson r hesaplar VE her fixture'ın KENDİ `provenance.hipKneeCoupling`
   alanına damgalar (`{pearsonHipKnee, n, method, computedBy}`).
2. **Gravita'nın eski Dart formülü (`hip_knee_coupling_squat.dart`) EMEKLİ
   edildi** — silinmedi, dosyanın başına RETIRED beyanı + gerekçe (G-065
   diferansiyel testi, TappBrothers 0,668 fark) eklendi. Artık hiçbir iş
   akışı bu dosyayı çağırmıyor.
3. `content/harvest/hip_knee_coupling.bodyweight_squat.json` ve
   `identity-triage.bodyweight_squat.json` kanonik sayılarla YENİDEN
   YAZILDI. `triage-profile.gravita.v2.json`'ın `hipKneeCoupling.basis`
   metni güncellendi (eşik 0,2 hâlâ provisional).

## Sonuç: 16/16 eğitmen GEÇTİ (r=0,44-0,98)

| Eğitmen | n | r (kanonik) |
|---|---|---|
| K boges | 8252 | 0,980 |
| THENX | 12387 | 0,963 |
| Minus The Gym | 1859 | 0,971 |
| WeShape | 9914 | 0,941 |
| Jeff Nippard | 9618 | 0,880 |
| Jeremy Ethier | 5404 | 0,853 |
| Sebastian Oreb | 7233 | 0,857 |
| Strength Side | 6242 | 0,950 |
| Vast Fitness Academy | 2537 | 0,821 ⚠️ (bkz. aşağı) |
| GMB Fitness (Praxis) | 9444 | 0,808 |
| Squat University | 22880 | 0,732 |
| School of Calisthenics | 3298 | 0,707 |
| Calisthenicmovement | 16460 | 0,616 |
| **TappBrothers** | 1881 | **0,642** |
| Tom Merrick | 54313 | 0,442 |
| FitnessFAQs | 4642 | 0,495 |

**TappBrothers artık GEÇER** (G-064'te kendi 2D formülümle r=0,150 REDDEDİLMİŞTİ
— G-065'in formül-artefaktı teşhisi doğrulandı). Kanonik hasat (rep-FSM'siz,
n=1881) VE G-065'in rep-FSM-pencereli diferansiyel testi (n=130, r=0,818)
AYNI yönde: gate kararı iki bağımsız yöntemde de PASS — sağlam.

## ⚠️ Metodolojik sınır — silinmedi, açıkça beyan edildi

Kanonik script mocore'un KENDİ frame-başına güven kapısını kullanır
(visibility×presence), **Gravita'nın FSM-tamamlanmış-tekrar penceresini
KULLANMAZ.** Somut kanıt: **Vast Fitness Academy** önceden `noSignal`'di
(FSM hiç tamamlanmış squat tekrarı üretmedi — 27 fixture'ın 1'i) ama kanonik
hasatta n=2537/r=0,821 ile GEÇİYOR. Bu videoda gerçekten squat yapıldığı
FSM ile hiç doğrulanmadı; yalnız görünür/güvenli kareler var — bu tam olarak
G-043'ün uyardığı kontaminasyon riski (konuşma/geçiş kareleri squat sanılır).

**Bunu gizlemedim, GÖRÜNÜR bıraktım:** `identity-triage.bodyweight_squat.json`
Vast Fitness Academy kaydında bu uyarıyı taşıyor. **Rep-FSM pencerelemesinin
Python/mocore tarafına taşınması AYRI bir iş kalemi** — bu turda yapılmadı,
koordinatöre kuyruk kalemi olarak bildiriliyor (isimli, "sonraki hasat turuna
katlanır" değil, çünkü bu ÜRETİM KAPISININ kendisini etkiliyor).

## Kanıt / komutlar

```bash
V=motion-core/lib/tools/fixture_pipeline/.venv/bin/python
$V tools/hip_knee_coupling_canonical.py
```
