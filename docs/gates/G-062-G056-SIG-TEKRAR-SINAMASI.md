# G-062 — G-056 ikincil hipotez sınaması: sığ tekrarlar mı kararsızlığı üretiyor?

**Bağlam:** G-056 "kapalı (yapısal)" olarak kapatılmıştı: push-up referansında
sol-sağ eklem farkı (≈5,03°) sıra-bağımlılığı deltasına (≈4,67°) yakın
bulunmuş, sonuç "şınav ayna-duyarsız bir malzeme, kararsızlık kovalanacak bir
kusur değil" diye yorumlanmıştı (M-F-57(2)'de aile kuralına da girdi).

**İkincil hipotez:** kararsızlık gerçekten malzemenin simetrisinden mi
geliyor, yoksa referans havuzundaki SIĞ tekrarların gürültüsü mü
kararsızlığı üretiyor?

## ❌ İLK TUR SONUCU GERİ ÇEKİLDİ — yanlış (probe-icadı) eşikle ölçülmüştü

İlk tur `Rep.extremeAngleDeg > romTarget.bottomAngleMax(95°)` ile "sığ"
tanımladı ve **sıra-deltasının 6,47°→0,000°'ye düştüğünü, G-056'nın kısmen
yanlış olduğunu** raporlamıştı. **Koordinatör bunu doğru şekilde reddetti:**
`romTarget.bottomAngleMax` (95°) hiçbir canlı hükmü beslemiyor — yalnız
perturbasyon/synthetic-fixture hedefi, "İSİMLİ" bir üretim eşiği DEĞİL. Bu tam
olarak M-F-57'nin uyardığı **eşik yeniden-kullanımı** hatasıydı: probe kendi
sayısını icat edip onu "sığlık" tanımı yapmıştı.

**Doğru kaynak:** ürünün KENDİ, canlı-kullanılan, İSİMLİ kalite eşiği —
`formErrors` içindeki `partial_rom` (id, `priority: blocking`, "Not going
deep enough"), `rom_bottom_angle` metriğiyle çalışır ve eşiği **110°**'dir
(95° değil). `rom_bottom_angle` = `Rep.extremeAngleDeg` (metrics.dart
`unimplemented` yorumu: "rep motorundan gelir").

## ✅ Düzeltilmiş sonuç: G-056 DOĞRULANDI, ikincil hipotez ÇÜRÜTÜLDÜ

`shallowThreshold = formErrors.partial_rom.detect.value = 110°` ile yeniden
koşuldu (`g056_shallow_mirror_probe.dart`, motion_core v0.8.2):

| | contributingTakes | excluded | meanLeftRightDiffDeg | sıra-deltası | orderIndependent | sameMirrorSet |
|---|---|---|---|---|---|---|
| BASELINE (tüm tekrar, n=91) | 41 | 50 | 4,38° | 60,97° | **false** | **false** |
| DERİN-YALNIZ (n=68, sığ **21** tekrar çıkarıldı — partial_rom) | 44 | 24 | 5,26° | **69,29°** | **false** | **false** |

**Sığ tekrarları (doğru, İSİMLİ eşikle) çıkarmak kararsızlığı GİDERMİYOR —
sıra-deltası düzelmedi, hafifçe ARTTI (60,97°→69,29°).** İlk turun "kapanıyor"
sonucu, 95°'nin (çok daha agresif bir kesim — 38 tekrar çıkarıyordu, 110°'nin
çıkardığı 21'in neredeyse ikisi katı) HANGİ take'leri elediğine bağlı bir
tesadüftü; gerçek/İSİMLİ eşikle bu tesadüf tekrarlanmıyor.

**G-056'nın orijinal kapanışı ("kararsızlık malzemenin özelliği, kovalanacak
bir kusur değil") bu ikinci ölçümle DOĞRULANDI, geri çekilmedi.** Aile kuralı
(M-F-57(2)) DEĞİŞMİYOR.

**İlginç ama beklenmeyen yan bulgu:** sığ tekrarları çıkarınca M-F-47
kümelenmesi İYİLEŞTİ (excluded 50→24, contributingTakes 41→44 — kalanlar
konsensüse daha çok benziyor, mantıklı: sığ bir tekrarın açı-izi zaten
derinden farklı). Ama bu, sıra/ayna KARARLILIĞIYLA (ayrı bir eksen) birlikte
hareket etmedi — biri iyileşirken öteki bozuldu. **Ders:** "kümeye ne kadar
uyuyor" (M-F-47 boyutu) ile "referans-kurma sırayla değişiyor mu" (M-F-48/
G-056 boyutu) BAĞIMSIZ sorular; biri iyi çıktı diye öteki de iyidir
varsayılamaz.

## Metodolojik öz-düzeltme (iki kez, aynı turda)

1. İlk deneme `resolveMirroring().confident` API'sine güvenmişti — n>12'de
   (sonra n>18) tükenmez arama yapmaz, sabit placeholder döner; asıl ölçüme
   (shuffle+yeniden-kur) geçildi.
2. İkinci deneme (bu belge) kendi icat ettiği eşiği "sığ" tanımı yapmıştı;
   koordinatör düzeltmesiyle ürünün İSİMLİ `partial_rom` eşiğine geçildi VE
   sonuç TERSİNE döndü.

Her iki düzeltme de aynı sınıf: **doğrulayıcının/ölçümün kendisi de
denetlenmeli** (M-F-57) — ama bu kez yön "sorun var" değil "sorun YOK, ilk
bulgu yanlış alarmdı" çıktı. M-F-58(6)'nın "kapı hiç kırmızı yanabilir mi"
sorusunun aynısı, tersine: "kırmızı yanan bu ölçüm gerçek mi?"

## Örneklem uyarısı (hâlâ geçerli, çözülmedi)

BASELINE 91 ham tekrar / 41 contributing veriyor; orijinal G-056/push_up
referansı (`content/harvest/reference.push_up.json`) **44 contributingTakes**
diyor. Ham havuz TAM eşleşiyor (44+47=91=41+50) — disk kaybı YOK; fark yalnız
M-F-47 kümeleme sınırında 3 take'lik marjinal bir kayma. En olası neden:
`ReferenceBuilder` varsayılan `clusterToleranceDeg`/`mirrorMargin` veya
`StructuralValidator` toleransları motion_core v0.5.0→v0.8.2 arasında hafifçe
değişti (gece boyunca birden çok M-F kararıyla ayarlandı — ör. M-F-59/61
eşik revizyonları); tam commit'i izole etmek bu sınamanın kapsamı dışında.

## Kanıt / komutlar

```bash
cd packages/gravita_engine
dart run tool/g056_shallow_mirror_probe.dart
```
