# G-089 — ⛔ Yayımlı squat referansının MEDOİDİ 198 kg'lık bir barbell squat'ı

**Koordinatör hükmü (M-F-171/4):** barbell varyant-kirlenmesini ÖNCE ÖLÇ —
(a) üç barbell-ağır klipten herhangi biri yayımlı referansa take verdi mi
(*"G-067 yakınsaması 'hayır' diyor ama beyan değil doğrulama istiyorum"*),
(b) transkript-işaret taraması, salt-rapor.

Doğrulama istemen doğruydu: **(a) temiz çıktı, ama (b) DAHA BÜYÜK bir vaka
buldu ve o vaka yayımlı artefaktın İÇİNDE.**

## (a) Göz-triyajının üç klibi: KATKI = 0 ✅

Take düzeyinde doğrulandı (`$windowRule`'daki `source=` yolundan
take-id → videoId eşlemesi):

| klip | kaynak | dilim | **katkı** | dışlanan |
|---|---|---|---|---|
| `my0tLDaWyDU` | Squat University | 2 | **0** | 2 |
| `X0qC1k0Zi6k` | Calisthenicmovement | 2 | **0** | 2 |
| `-W19J4VR7D0` | FitnessFAQs | 0 | **0** | 0 |

G-067 yakınsaması doğrulandı — ama *beyan değil ölçümle*.

## (b) İşaret taraması ÜÇ YENİ klip buldu — ve ÜÇÜ DE KATKI VERİYOR

`rom_mode` sözlük deseniyle yük-işareti taraması (başlık+açıklama; transkript
YOK, o yüzden kanıt zayıf tarafta). **Yalnız yük-işareti taşıyan (bodyweight
işareti hiç olmayan) 5 klip** çıktı; üçü göz-triyajının HİÇ görmediği
kliplerdi çünkü ikinci-kişi sondasında düşük oranlıydılar (tek kişi, ayna yok):

| klip | kaynak | işaretler | dilim | **KATKI** |
|---|---|---|---|---|
| `sdeQjm7avi8` | Jeff Nippard | `1rm, bar, lbs, powerlift, pr, rack` | 8 | **2** |
| `bEv6CCg2BC8` | Jeff Nippard | `lbs, powerlift, weight` | 15 | **3** |
| `gcNh17Ckjgg` | Jeremy Ethier | `back squat, bar, barbell, plates, rack, weight` | 6 | **1** |

**36 katkı take'inin 6'sı (%17) bu üç klipten.**

### Gözle DOĞRULANDI — işaret değil, görüntü

İşaret taraması tek başına zayıf kanıt (bir bodyweight tutorial'ı barbell'den
*bahsedebilir*), o yüzden baktım:

- **`sdeQjm7avi8`** (Jeff Nippard, *"The Fastest Way To Blow Up Your Squat"*):
  rack, kemer, "WALKOUTS"/"PIN SQUATS" bölümleri ve ekranda açık altyazı:
  **"SQUAT [TOP SET] 435 LBS (198 KG) × 3 REPS."**
- **`bEv6CCg2BC8`** (Jeff Nippard): kemerli rack squat'ları, *"…of the
  Barbell Squat"* başlıklı EMG makalesi kareleri.
- **`gcNh17Ckjgg`** (Jeremy Ethier): yüklü rack squat'ları, bar-sırtta
  overlay okları, goblet tutuşları.

Üçü de tartışmasız **barbell** içerik.

## ⛔ VE MEDOİD BUNLARDAN BİRİ

`result.medoidTakeId = Jeff_Nippard_w13_r0` → kaynağı **`sdeQjm7avi8`**, yani
**198 kg'lık barbell top-set'i.**

Medoid, tüm referansın **hizalama tabanıdır**: bütün take'ler DTW ile onun
zaman çizgisine büküldü. `bodyweight_squat` referansının hizalama tabanı bir
198 kg barbell triple'ı.

### Bu, M-F-155'in "yavaş medoid" bilmecesini de ÇÖZÜYOR

Koordinatör M-F-155'te medoidin muhtemelen "yavaş bir tekrar" olduğunu
öngörmüştü (medoid 107 kare / 4,42 sn iken take medyanı ~52 kare) ve
`capFillShare` medyanının 0,44'te kalmasını buna bağlamıştık. **Sebep artık
isimli: 198 kg'lık bir triple YAVAŞTIR.** Yani şu üç bulgu tek kök nedene
bağlanıyor:
- medoid anormal uzun (107 kare),
- `capFillShare` medyanı 0,444 (take'ler uzun medoide karşı sıkışıyor),
- bacak eklem toleranslarının taban-bağlı kalması.

## Kirlenme ÖLÇÜLEBİLİR biçimde BOZUYOR

"Kirlenme var" demek yetmez; etkisini ölçtüm
(`tool/barbell_distortion_probe.dart` → `content/harvest/barbell-distortion.json`).
Katkı veren take'ler, **dip anında** (diz açısı en küçük kare) iki gruba
ayrıldı:

| grup | take | gövde eğimi medyan | diz açısı medyan |
|---|---|---|---|
| **barbell** | 6 | **−4,8°** | **77,7°** |
| diğer | 31 | **+3,4°** | **59,5°** |

- **Gövde eğimi farkı: 8,2°** — ve `freeFloorDeg` tolerans tabanı **8°**.
  Yani kirlenmenin büyüklüğü, tolerans bandının TAMAMI kadar.
- **Diz açısı: barbell take'leri 18,2° DAHA SIĞ** (77,7° vs 59,5°). Beklenen:
  198 kg'lık bir triple bodyweight squat kadar derine inmez.

Yani barbell take'leri referansı **daha sığ ve farklı gövde açısına** doğru
çekiyor — `bodyweight_squat` için yanlış yöne.

⚠️ Sayı mutabakatı: 6+31 = **37**, artefakt 36 katkı take'i diyor. Fark,
dilim dizininde artefaktta bulunmayan bir dosya olması (`FitnessFAQs_w17_r0`
— 234 dosya vs 233 take). Gizlemiyorum; grup medyanlarını etkilemeyecek
kadar küçük ama sayım tam değil.

## Ne YAPMADIM

**Artefakta DOKUNMADIM.** Yayımlı bir referansı yeniden kurmak, hükmün
"kapı tasarımı ölçümden SONRA" dediği yerdir; ayrıca M-F-66'nın
intent-variant sorusu açık (*barbell ↔ bodyweight FARKLI teknikler — tag,
havuzlama değil*). Rebuild kararı verilirse dışlanacak take'ler ADIYLA hazır:

```
sdeQjm7avi8 → Jeff_Nippard_w13_r0 (MEDOİD), Jeff_Nippard_w20_r0
bEv6CCg2BC8 → Jeff_Nippard_w11_r0, Jeff_Nippard_w14_r0, Jeff_Nippard_w24_r1
gcNh17Ckjgg → Jeremy_Ethier_w4_r1
```

⚠️ Medoid dışlanırsa hizalama tabanı DEĞİŞİR, yani sayılar bit-özdeş
kalmaz — bu bir regresyon değil, tabanın düzelmesi olur. Ama Jeff Nippard
katkı veren 6 kaynaktan biri; 5 take'i düşerse `minSources` yine 5'te kalır
(sınırın üstünde), Jeremy Ethier ise tek take'liydi → kaynak sayısı 6→5'e
iner. Bu, M-F-38 tabanının hemen üstü.

## Kapılar

`dart analyze` temiz · 77/77 test · replay 0 ölü · validate_catalog 0 hata.
Artefakt değişmedi.

## Koordinatöre

1. **Rebuild kararı** — 6 take (medoid dahil) isimle dışlanacak mı?
2. **M-F-66 intent-variant:** `barbell_squat` ayrı teknik olarak mı
   etiketlenecek (havuzlanmadan), yoksa yük-işareti bir triyaj kapısı mı
   olacak? Kapı olursa transkript yokluğu (kanıt zayıflığı) hesaba katılmalı:
   tarama yalnız başlık+açıklamaya bakıyor.
3. **Aile sorusu:** bu sınıf `romMode`'un kardeşi — *"gösterilen hareket
   aranan VARYANT mı?"* Metin sınıflandırıcısı `active/passive` soruyor ama
   `loaded/bodyweight` sormuyor. Lissom/Ostinato'da karşılığı var mı?
