# G-090 — Kopyalama imzası ANATOMİK modda da AYNI işaretle duruyor (M-F-56 eksik halka)

**Koordinatör hükmü (M-F-172/3):** G-078'de dürüstçe açık bıraktığım bacağı
kapat — kopyalama-imzası probe'unu anatomik modda tekrarla; **anatomik mod
push_up↔squat ayrımcılığını değiştiriyor mu?** Bu, MOCORE_ANATOMICAL
kurucu-kaleminin kanıt zincirinin eksik halkası.

## Sonuç: AYRIMCILIK KORUNUYOR — anatomik mod teşhis yeteneğini SİLMİYOR

| hareket | KAMERA çerçevesi | ANATOMİK mod |
|---|---|---|
| push_up | 8,60° → 22,67° · **imza POZİTİF** | 6,05° → 25,22° · **imza POZİTİF** |
| bodyweight_squat | 45,25° → 12,03° · **imza NEGATİF** | 37,62° → 11,49° · **imza NEGATİF** |

(Okuma yönü: düşük görünürlük bandı → yüksek görünürlük bandı. push_up'ta fark
görünürlük düştükçe KÜÇÜLÜYOR = üretilmiş anlaşma; squat'ta BÜYÜYOR = dürüst
ölçüm.)

**İki hareket anatomik modda da ZIT yönde ayrışıyor, işaretler değişmiyor.**
Yani anatomik varsayılana geçmek bu teşhis yeteneğini maliyet olarak
almıyor — M-F-56 zincirinin bu halkası **LEHTE** kapandı.

## Ek gözlem: anatomik mod sahte asimetriyi AZALTIYOR

Orta bantlarda anatomik değerler sistematik olarak DAHA KÜÇÜK — en belirgin
push_up 0,4-0,6 bandında: **31,17° → 17,96°** (%42 azalma). Anatomik
projeksiyonun işi tam bu: kamera-yaw kaynaklı asimetriyi kaldırmak (M-F-53).

Yani ölçüm iki şeyi birden gösteriyor: **sahte asimetri azalıyor, gerçek
teşhis sinyali kalıyor.** Bu, anatomik varsayılan için argüman — ama karar
kurucunun, ben yalnız ölçümü koydum.

## Yöntem beyanları

- **Sol metrik tanımı İCAT EDİLMEDİ.** Lissom dosyasında yalnız `_right`
  sürümleri var; ikisi de `"mirror": true` beyanı taşıyor, yani tanım
  kendisi aynalanabilir olduğunu söylüyor. Sol ikiz, landmark ADLARI
  `RIGHT_`→`LEFT_` çevrilerek kuruldu: **aynı formül, aynalanmış küme.**
- Metrikler: `hip_flexion` (frameRef `proximal`) + `knee_flexion`
  (frameRef `none`), ikisi de `mz.evaluate(..., anatomical=False|True)`.
- **Eşik yok, kapı yok, hüküm yok** — salt rapor.

## ⚠️ Bant dağılımları iki havuzda KARŞILAŞTIRILABİLİR DEĞİL

squat'ın düşük-görünürlük bantları neredeyse boş (0 · 0 · 183 örnek), push_up'ta
13k. İki sebep var ve ikisi de yöntemsel:

1. push_up **ham** landmark havuzunu, squat **rep-FSM-dilimli** havuzu
   kullanıyor (dilimleme zaten yukarıda görünürlük süzüyor).
2. Bu probe görünürlüğü **yalnız BACAK zinciri** üzerinden koşullandırıyor
   (hip/knee metrikleri, omuz-kalça-diz-ayak), G-078'in Dart probe'u ise
   KOL çiftleri dahil her eklem çifti için ayrı koşullandırıyordu — squat'ta
   bacaklar iyi görünür olduğu için örnekler yüksek bantlara toplanıyor.

Bu yüzden **karşılaştırılabilir olan şey EĞİLİMİN YÖNÜ, bant nüfusları
değil.** squat'ın düşük-uç eğilimi 183 örneğe dayanıyor — yön açık ama
istatistiksel güç zayıf; tek başına hüküm taşımaz.

## Kanıt

```bash
python3 tools/anatomical_copying_signature.py
```
→ `content/harvest/anatomical-copying-signature.json`
