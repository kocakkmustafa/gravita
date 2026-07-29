# G-069 — squat referansı M-F-47 anlaşma kapısında KİLİTLENDİ (14°'de de 30°'de de)

**Bağlam:** G-068'in hazırlık notundaki 3. açık karar ("hipKneeCoupling eşiği
hâlâ provisional, ilk referans buna dayanırsa risk taşır mı") koordinatör
M-F-106 hükmüyle KAPATILMIŞ ve yeşil ışık verilmişti: 12 PASS eğitmenin
rep-FSM-dilimli take'leri → kanonik CLI → squat'ın İLK ürün referansı, iki
yeni beyanla (`identityGateBasis`, `minAcceptedR`). Bu, o yeşil ışığın
uygulama denemesidir — SONUÇ: referans üretilemedi, artefakt YAZILMADI.

## Ne yapıldı

`packages/gravita_engine/tool/canonical_squat_reference.dart` (yeni):

1. `hip_knee_coupling.bodyweight_squat.json`'dan `gate=="pass"` olan 12
   eğitmeni filtreledi → `passChannels`.
2. `minAcceptedR` hesaplandı: **0,274** (Tom Merrick) — eşik (0,2) üstünde,
   marj 0,074. push_up emsalindeki gibi beyan edilecekti.
3. `~/motion-harvest/gravita-squat/landmarks-rep-sliced/` içinden (G-067'nin
   rep-FSM dilimleri, 260 derin tekrar) `provenance.channel ∈ passChannels`
   olan fixture'lar yüklendi: **233 fixture, 12 eğitmen**.
4. `ReferenceCli(allowUnattested:true, clusterToleranceDeg:14).buildArtifact(
   technique:'bodyweight_squat', fixturesById: <233 fixture>)` çağrıldı.

## Sonuç: iki kademede de `ReferenceAgreementError`

**14° (varsayılan):** 98 take konsensüsten sapıyor, TAMAMI 3 kaynaktan:

| Kaynak | Sapan take | Havuzdaki toplam | Sapma aralığı |
|---|---|---|---|
| Strength Side | 30/30 (tümü) | 30 | 12,9°–49,9° |
| THENX | 68/68 (tümü) | 68 (havuzun **en büyük tek kaynağı**, ~%29) | 10,2°–36,1° |
| Tom Merrick | 2/11 | 11 | 40,3°, 78,7° |

**G-050 deseni uygulandı** (asla körlemesine genişletme; önce ölç): kapı
30°'ye (2×) çıkarıldı. **AYNI 3 kaynak, AYNI takeler, birebir aynı sapma
derecesiyle YİNE reddedildi** — 30°'de bile kümelenmiyorlar. Bu, sapmanın
kapının kendisi değil malzemenin yapısı olduğunu gösterir (G-050'nin push_up
bulgusunun tersi: orada genişletme dağılımı 2 katına çıkarmıştı ama YİNE de
kümeleniyordu; burada genişletme kümelenmeyi HİÇ değiştirmedi — nitelik
olarak farklı bir başarısızlık modu).

**Karar: 45°/60° ile körlemesine devam EDİLMEDİ.** Aracın çıktısı `exit(1)`
ile durdu, `reference.bodyweight_squat.json` YAZILMADI — teyit: dosya yok,
`git status` yalnız yeni aracın kendisini + bir `.pyc` gösteriyor.

## Yorum (kendi payım — karar değil, gözlem)

Bu bir kodlama hatası DEĞİL: `dart analyze` temiz, `exit(1)` beklenen dalda,
sapan set iki farklı toleransta da birebir aynı (rastgele/gürültü değil,
tutarlı bir yapı). İki olası açıklama, ikisi de ÖLÇÜLMEDİ:

1. **Gerçek iki-kümeli stil/kamera-açısı farkı** — Strength Side + THENX +
   (kısmen) Tom Merrick, kalan 9 kaynaktan sistematik olarak farklı bir squat
   varyantı/kamera açısı/derinlik konvansiyonu kullanıyor olabilir (M-F-55(2)
   emsali: push_up'ta "wide grip" ayrı varyant sayılmıştı).
2. **Bu 3 kaynağa özgü veri-kalitesi sorunu** — ör. rep-FSM dilimleyicisinin
   bu kaynaklarda sistematik bir kenar-durum kestiği (kamera açısı nedeniyle
   izdüşüm-bükülmesi arttığı — G-061'in tüm gece bulduğu desen) ya da
   THENX'in havuzun ~%29'unu tek başına oluşturması ölçüm hassasiyetini
   THENX'in kendi iç-varyansına duyarlı kılıyor olabilir.

THENX'in havuzun en büyük TEK kaynağı olması özellikle dikkat çekici: onu
dışlamak/ayrı incelemek yalnız 3 kaynağı değil havuzun neredeyse üçte birini
etkiler.

## Karar KENDİM verilmedi — üç seçenek koordinatöre

1. **Stil-ayrımı sınıflandırması** (M-F-55(2) örneği) — 3 kaynağın
   fixture'ları elle/yarı-otomatik incelenir, gerçekten farklı bir squat
   varyantı mı yoksa aynı hareket mi diye karar verilir.
2. **3 kaynak ayrı incelenir** — Strength Side/THENX/Tom Merrick'in sapan
   take'lerinden örnek kareler çekilip görsel/sayısal teşhis yapılır (kamera
   açısı? derinlik konvansiyonu? dilimleme kenar-durumu?).
3. **Referans yalnız kümelenen 9 kaynaktan üretilir** (Calisthenicmovement,
   GMB Fitness (Praxis), Jeff Nippard, Jeremy Ethier, K boges, Sebastian
   Oreb, Squat University, TappBrothers, WeShape) — squat'ın İLK referansı
   bu 9'dan yayımlanır, 3 kaynak `excludedClusterOutlier` olarak
   provenance'a işaretlenir ve ayrı bir kuyruk kalemi olarak durur.

Bu, ambiguous-data-interpretation + yeni-gate-tasarımı sınıfı bir karar
(YÜKSELTME KURALI) — tek taraflı seçilmedi.

## Kanıt / komutlar

```bash
cd packages/gravita_engine
dart analyze tool/canonical_squat_reference.dart   # temiz
dart run tool/canonical_squat_reference.dart        # exit 1, diagnostik yazdırır
ls ../../content/harvest/reference.bodyweight_squat.json  # YOK (yazılmadı)
```

Kaynak: `content/harvest/hip_knee_coupling.bodyweight_squat.json` (gate),
`~/motion-harvest/gravita-squat/landmarks-rep-sliced/` (233/260 fixture, 12
eğitmen).
