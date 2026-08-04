# G-108 — A4 + A1 ÖN-KAYIT (koşumdan ÖNCE yazıldı)

**Tarih:** 2026-08-04 · **Yetki:** koordinatör hüküm 3 (A4+A1 onaylı, "regen
sonrası" şartı M-F-230 kapsam düzeltmesiyle KALDIRILDI).

Bu dosya **ölçüm koşulmadan önce** yazıldı ve sonuçlar geldikten sonra
DEĞİŞTİRİLMEYECEK. Amaç: hangi sonucun hipotezi desteklediğini, hangisinin
öldürdüğünü sonradan değil ÖNCEDEN sabitlemek.

---

## Sınanan hipotez (G-106 §3)

> Squat'ın knee/shin/trunk_tilt toleransları floor-bound, çünkü referansın
> %72'si tek kaynaktan (THENX 18/25) geliyor; ölçülen dispersiyon büyük ölçüde
> **o kaynağın iç varyansı**, eğitmenler-arası anlaşmazlık değil.

**Rakip hipotez:** popülasyon çok-modlu; tek konsensüs bulutu yok (G-069:
tolerans 14°→30° genişletmek kümelenmeyi hiç değiştirmedi).

## Ölçüm mekaniği (taban)

`build_reference`/`canonical_*_reference` bir eklem çiftini şöyle sınıflar:

```
source = measuredDispersionDeg < 8.0 ? 'floor' : 'variance'
```

Yani **floor↔variance geçişi tek bir eşikte: 8,0°.** Zayıf-halka (M-F-95)
gereği çiftin bir tarafı floor ise çift floor.

### Yayımlı taban (kamera modu, `frameBasis: camera`)

| eklem | sol | sağ | çift |
|---|---|---|---|
| hip | variance (0,37) | variance (0,45) | **derived** |
| thigh | variance (0,11) | variance (0,37) | **derived** |
| knee | variance (0,32) | **floor (0,53)** | **FLOOR** |
| shin | **floor (0,53)** | variance (0,32) | **FLOOR** |
| trunk_tilt | — | — | **floor (0,63)** |

(parantez içi `floorBoundShare`) · katkı **25** · aykırı **202** · havuz **227**
· medoid THENX kümesinden · `distinctSources` 5.

---

## A4 — THENX çıkarılıp referans yeniden kurulur

**Yöntem:** `canonical_squat_reference.dart`, girdi
`~/motion-harvest/gravita-squat/landmarks-rep-sliced` (234 dosya / 41 MB),
`passChannels`'tan THENX **çıkarılır**, başka hiçbir parametre değişmez
(`clusterToleranceDeg` aynı merdiven: 14 → gerekirse 30). Çıktı **scratch'e**.

### İki dürüst uç (önceden sabit)

**UÇ (i) — hipotez DESTEKLENİR.** Şu ikisinden **en az biri**:
- knee / shin / trunk_tilt'ten **≥1 çift** `floor` → `variance` geçer
  (yani `measuredDispersionDeg` 8,0°'yi aşar); **veya**
- aykırı oranı %89'dan **≥10 puan** düşer (yani <%79).

Okuma: THENX baskınlığı eğitmenler-arası dispersiyonu bastırıyormuş.

**UÇ (ii) — hipotez ÖLÜR.** İkisi birden:
- knee/shin/trunk_tilt'in üçü de `floor` kalır, **ve**
- aykırı oranı ±5 puan bandında kalır.

Okuma: tek-kaynak baskınlığı floor-bound'luğun açıklaması **değil**; G-106 §3
hipotezi kayda geçmiş ölümüyle kapanır ve çok-modluluk tek ayakta kalan
açıklama olur (ama onu A1 sınar, A4 değil).

**ÜÇÜNCÜ UÇ (öngörülen, dürüstlük gereği önceden yazılıyor):** referans
**hiç kurulamaz** (`ReferenceAgreementError`, G-069'daki gibi 14°'de de 30°'de
de). Bu bir başarısızlık değil **bilgidir**: THENX olmadan konsensüs yok
demektir — ki bu, "referans aslında THENX'in kendi iç tutarlılığıydı"
okumasını güçlendirir ve hipotezi (i) yönünde destekler, ama tolerans
tablosu üretilemeyeceği için (i)'nin sayısal ölçütü uygulanamaz. Bu durumda
sonuç **"(i)-nitel"** diye raporlanır, (i) sayılmaz.

### A4'ün SINIRI — koordinatör hükmü, aynen kabul

**A4 tek başına PROBE'dur.** Leave-one-out, "farklı mod"u "gürültü"den
ayıramaz. **Hiçbir DIŞLAMA kararı A4'e dayandırılmayacak.** THENX bir gün
dışlanacaksa gerekçe M-F-47 gereği **bağımsız ve İSİMLİ varyant kanıtı**
olmak zorundadır (emsal: barbell dışlaması G-089/091) — "kalanların uyuşması
gerekçe değildir".

---

## A1 — 202 aykırının mod yapısı

**Soru:** aykırılar tek dağınık bulut mu, yoksa k>1 ayrı küme mi?

**Yöntem:** aykırı take'lerin hizalanmış açı vektörleri üzerinden ikili
mesafe dağılımı + medoid etrafında yarıçap histogramı. Kümelenme ölçütü
**önceden** sabit:

**UÇ (i) — ÇOK-MODLU.** İkili mesafe dağılımı **çok-tepeli**, ve k=2..4 için
küme-içi ortalama mesafe, küme-arası ortalamanın **≤ 0,6 katı**.
→ "farklı geçerli stiller" okuması desteklenir; varyant ayrımı (G-053/G-089
ailesi) doğru yol olur.

**UÇ (ii) — TEK-MOD / GÜRÜLTÜ.** Mesafe dağılımı **tek-tepeli** ve oran
**> 0,6**. → aykırılık "başka mod" değil kalite/gürültü; çözüm varyant ayırmak
değil kaynak/kadraj kalitesi olur.

**Belirsiz bant** (oran 0,6 civarı, tepe sayısı net değil): "ayrışma
türetilemedi" diye İSİMLİ dürüst kapanış — zorlama yok. G-104'ün dersi burada
da geçerli: ayırıcı istatistik **kuyruktan** okunur, ortalamadan değil; bu
yüzden ikili mesafe dağılımının **p90**'ı da raporlanır.

---

## Ortak beyanlar

- Her sayı `frameBasis: camera` etiketiyle raporlanır (M-F-230). Anatomik mod
  bu hatta **bağlı değil** (G-107) — bu koşum kamera modudur ve öyle yazılır.
- **Hiçbir yayımlı artefakt değiştirilmez.** Çıktılar `scratch/`e.
- `bodyweight_squat` `coming_soon` kalır; form dersi K7 gereği kilitli kalır.
  Bu koşum **hiçbir ders durumunu açmaz** — sonuç ne olursa olsun.
- Pozitif kontrol (M-F-230 ruhu): A4 koşumu, THENX'in gerçekten çıkarıldığını
  kanıtlayan bir değer içermek zorunda (`distinctSources` ve katkı sayısı
  değişmeli). Bit-aynı çıktı "fark yok" değil **"filtre bağlanmamış"** demektir
  ve koşum geçersiz sayılır.
