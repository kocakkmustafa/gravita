# ADR-005 — Her denemede köken (provenance) alanları zorunlu

**Durum:** kabul (2026-07-26) · **Kaynak:** `00-AILE-MIMARISI §7` (ölçüm dürüstlüğü) + G-008/M-020 · **Defter:** G-008

## Bağlam
Gravita'nın vaadi "haftalar boyunca ölçülebilir gelişme". Bu vaat, ölçüm koşulları sabit kalmadıkça **yanlıştır**: model varyantı, model sürümü, kural seti veya yönelim stratejisi değişirse eski ve yeni sayılar kıyaslanamaz.

D1 ölçümü bunu somutlaştırdı: `full` ve `heavy` aynı sette farklı güven bandı verdi (0,842 vs 0,697) ama tespit oranı ters yönde. `visibility` **model-özgü bir kalibrasyondur**; varyantlar arası doğrudan kıyaslanamaz (M-020).

## Karar
Her `Attempt` kaydı şu alanları **zorunlu** taşır:

| Alan | Neden |
|---|---|
| `modelVariant` (lite/full/heavy) | Eşikler varyant-başına kalibre (M-020) |
| `modelVersion` + `sha256` | Katalog §1: model pinlenir; "latest" sessizce değişir |
| `ruleSetVersion` | Kural değişimi skor değişimidir |
| `packVersion` | Kriter/eşik değişimi ilerleme anlamını değiştirir (ADR-004) |
| **`orientationStrategy`** | Düz / döndürülmüş / çift-geçiş — ADR-001 |
| `analysisConfidence` | Hükmün ağırlığı |
| `structuralCheckOutcome` | ADR-002 denetiminin sonucu |
| `deviceProfileId`, `fps`, `lighting` notu | Koşul etiketi (00-AILE-MIMARISI §7) |

**Kural:** iki deneme **yalnız** köken alanları uyumluysa doğrudan kıyaslanır. Uyumsuzsa arayüz kıyaslamayı ya yapmaz ya da "measurement changed" etiketiyle yapar.

## Sonuçlar
- ✅ Model/eşik değiştiğinde geçmiş yeniden yorumlanabilir; "gelişme" iddiası model gürültüsü olmaktan korunur.
- ✅ Pazarlanacak herhangi bir sayı, koşullarıyla etiketli üretilir (aile kuralı).
- Depolama maliyeti ihmal edilebilir (deneme başına ~200 bayt).
- Migration disiplini: yeni köken alanı eklemek şema sürümü artırır.

## Reddedilen alternatifler
- **Yalnız skorları saklamak:** geçmiş yorumlanamaz hale gelir; BF'nin "eğitim backtest'i" dersinin tekrarı olur.
- **Köken alanlarını yalnız oturum düzeyinde tutmak:** aynı oturumda varyant değişebilir (assessment `heavy`, canlı `full`).
