# G-065 — hipKneeCoupling diferansiyel testi: TappBrothers'ın reddi FORMÜL ARTEFAKTI

**Bağlam:** G-064'te Gravita kendi taraf-agnostik/düz-izotropik 2D formülüyle
hipKneeCoupling'i ölçmüş, TappBrothers'ı reddetmişti (r=0,150 < 0,2). Lissom'a
sorulunca gerçek formülün yeri bulundu: `mocore/geometry.py body_axes(mode:
"proximal")` + `measures.py evaluate(anatomical: true)` — VE Lissom'un kendi
atıf verdiği sayıların (+0,56/+0,45/+0,57/−0,46) bu bayrağı HİÇ geçmediği
ortaya çıktı (düzeltilmiş: +0,31/+0,77/+0,62/−0,07). Koordinatör talimatı:
üç-yönlü diferansiyel test — Gravita formülü ↔ Lissom-düzeltilmiş formülü,
ortak fixture'larda yan yana.

## Yöntem

`packages/gravita_engine/tool/hip_knee_coupling_differential.dart` — 5
eğitmen (gate-sonucu yayılımını temsil eden: temiz/yüksek-r WeShape,
kneeSymmetry-şüpheli Tom Merrick, reddedilen TappBrothers, en-zengin-n
K boges, orta Squat University), aynı FSM-tamamlanmış-tekrar ∩
StructuralValidator penceresinde İKİ formülle:

- **Gravita:** `MovementMetrics.hipAngle`/`kneeAngle` — görünen taraf
  (ADR-003), düz izotropik 2D açı (image-plane).
- **Lissom-düzeltilmiş (bu testte BİREBİR mocore'dan taşındı):**
  `hip_flexion`: RIGHT_SHOULDER-RIGHT_HIP-RIGHT_KNEE, WORLD 3D, `proximal`
  gövde eksenine (kalça-ortası→omuz-ortası) sagittal-düzlem izdüşümüyle.
  `knee_flexion`: RIGHT_HIP-RIGHT_KNEE-RIGHT_ANKLE, WORLD 3D, izdüşümsüz
  (menteşe eklem, `frameRef=none`).

## Sonuç

| Eğitmen | n | r (Gravita) | r (Lissom-düzeltilmiş) | Fark |
|---|---|---|---|---|
| WeShape | 1774 | 0,971 | 0,933 | 0,038 |
| Tom Merrick | 3137 | 0,334 | 0,298 | 0,036 |
| **TappBrothers** | 130 | **0,150** | **0,818** | **0,668** |
| K boges | 3272 | 0,990 | 0,978 | 0,012 |
| Squat University | 2598 | 0,900 | 0,929 | 0,029 |

**4/5 eğitmende iki formül YAKIN uyuşuyor** (fark ≤0,04) — kopya-sürüklenme
riski bu 4 vakada gerçekleşmemiş, iki app'in bağımsız formülleri aynı
kararı veriyor. **TappBrothers'ta ise fark MADDİ: 0,668.** Gravita'nın
formülüyle REDDEDİLEN (0,150) bu eğitmen, Lissom-düzeltilmiş formülle RAHAT
GEÇİYOR (0,818).

**Sonuç: G-064'teki TappBrothers reddi muhtemelen FORMÜL ARTEFAKTI, gerçek
bir confounder sinyali DEĞİL.** TappBrothers en küçük örneklemli (n=130)
eğitmen — muhtemelen kamera açısı/kadraj Gravita'nın 2D-izotropik formülünün
zayıf olduğu bir bölgede (G-061'in tüm oturum boyunca defalarca bulduğu
"kamera-açısı 2D açıları bozar" deseninin BİR BAŞKA örneği — bu kez
hipKneeCoupling'de). Lissom'un WORLD-3D + proximal-projeksiyon formülü bu
bozulmayı düzeltiyor gibi görünüyor.

**Kararı KENDİM vermiyorum** (koordinatör: "ayrışma maddiyse kanonik
uygulamanın nereye konacağına ben karar veririm, muhtemelen rig/mocore
tek-ev"): `hip_knee_coupling.bodyweight_squat.json`/`identity-triage.
bodyweight_squat.json`'daki TappBrothers `fail` etiketi SİLİNMEDİ ama
formül-duyarlı olduğu AÇIKÇA işaretlendi — koordinatör hangi formülün
kanonik olacağına karar verene dek "sınırda/formüle bağlı" sayılmalı,
kesin ret değil.

## Ne değişti

- `triage-profile.gravita.v2.json`: `identity.hipKneeCoupling.basis`
  Lissom'un DÜZELTİLMİŞ sayılarıyla (+0,31/+0,77/+0,62/−0,07) ve bu
  diferansiyel test bulgusuyla güncellendi. Eşik (0,2) **PROVISIONAL**
  kalıyor (koordinatör: confounder örneklemi büyüyünce yeniden türetilecek).
- `content/harvest/hip_knee_coupling.bodyweight_squat.json` /
  `identity-triage.bodyweight_squat.json`: TappBrothers kaydına
  `formulaSensitive: true` + bu rapora referans eklendi.

## Kanıt / komutlar

```bash
cd packages/gravita_engine
dart run tool/hip_knee_coupling_differential.dart
```
