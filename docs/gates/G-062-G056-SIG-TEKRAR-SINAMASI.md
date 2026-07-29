# G-062 — G-056 ikincil hipotez sınaması: sığ tekrarlar mı kararsızlığı üretiyor?

**Bağlam:** G-056 "kapalı (yapısal)" olarak kapatılmıştı: push-up referansında
sol-sağ eklem farkı (≈5,03°) sıra-bağımlılığı deltasına (≈4,67°) yakın
bulunmuş, sonuç "şınav ayna-duyarsız bir malzeme, kararsızlık kovalanacak bir
kusur değil" diye yorumlanmıştı (M-F-57(2)'de aile kuralına da girdi).

**İkincil hipotez (bu oturumun görevi):** kararsızlık gerçekten malzemenin
simetrisinden mi geliyor, yoksa referans havuzundaki SIĞ tekrarların
(FSM'i saydı ama `romTarget.bottomAngleMax=95°`'e ulaşmadı — V16/G-054
anlamında) gürültüsü mü kararsızlığı üretiyor?

**Yöntem:** `packages/gravita_engine/tool/g056_shallow_mirror_probe.dart` —
push_up fixture havuzunu build_reference.dart ile AYNI şekilde işler (M-F-38
eğitmen-yeterlilik kapısı, StructuralValidator, RepEngine), sığ/derin ayrımını
`Rep.extremeAngleDeg > 95°` ile yapar, sonra build_reference.dart'ın KENDİ
G-056/M-F-48 ölçümünü (meanLeftRightDiffDeg + shuffle-yeniden-kur sıra testi)
hem TÜM tekrarlarda hem yalnız DERİN tekrarlarda tekrarlar.

⚠️ **Metodolojik not:** `ReferenceBuilder.resolveMirroring(takes).confident`
n>12'de (havuzumuzda her iki set de: 91 ve 52) tükenmez aramayı YAPMAZ —
`reference_builder.dart` (pub-cache v0.5.0, ~satır 400) `runnerUpTotal`ı sabit
bir placeholder'la (`bestTotal + mirrorMargin*pairs*2`) doldurur, bu da HER
ZAMAN `confident=true` üretir; veriye bakmaz. İlk deneme bu API'yi çağırıp
`confident` DEĞİŞMEDİ diye yanlış bir "tutarlı" sonucu raporluyordu — kendi
hatamı fark edip (M-F-57'nin "doğrulayıcının kendisi de denetlenmeli" dersinin
küçük bir tekrarı) build_reference.dart'ın GERÇEKTEN kullandığı ölçüme
(shuffle+yeniden-kur + meanLeftRightDiffDeg) geçtim.

## Sonuç

| | contributingTakes | excluded | meanLeftRightDiffDeg | sıra-deltası | orderIndependent | sameMirrorSet |
|---|---|---|---|---|---|---|
| BASELINE (tüm tekrar, n=91) | 41 | 50 | 4,29° | 6,47° | **false** | **false** |
| DERİN-YALNIZ (n=52, sığ 38 tekrar çıkarıldı) | 37 | 15 | 6,04° | **0,000°** | **true** | **true** |

**⚠️ G-056'nın kapanışı EKSİK görünüyor.** Sığ tekrarları çıkarınca sıra-
bağımlılığı deltası 6,47°'den TAM SIFIRA düşüyor ve ayna-atama kümesi sıra
karışsa da AYNI kalıyor — yani en azından bu 91-tekrarlık havuzda, sıra/ayna
KARARSIZLIĞI büyük ölçüde sığ-tekrar gürültüsünden geliyormuş, malzemenin
saf simetrisinden değil. Buna karşın sol-sağ fark endeksi (malzemenin KENDİSİ
ne kadar simetrik) derin-yalnız sette KÜÇÜLMEDİ, tersine biraz büyüdü
(4,29°→6,04°) — yani "şınav genel olarak iki-taraflı simetrik bir hareket"
iddiası hâlâ makul duruyor; EKSİK olan, "bu YÜZDEN sıra-kararsızlığı zaten
beklenir ve önemsizdir" çıkarımı.

**Bu, G-056'yı tersine ÇEVİRMİYOR — iki farklı iddiayı ayırıyor:**
1. "Şınav sol-sağ simetriktir" — hâlâ destekleniyor (~4-6°, düşük).
2. "Referans-kurma sürecinin sıra/ayna kararsızlığı bu simetriden kaynaklanır,
   dolayısıyla kovalanmaz" — bu koşumda YANLIŞLANDI: kararsızlık, havuzdaki
   düşük-kaliteli (sığ) tekrarların payı büyükken ortaya çıkıyor ve onlar
   çıkarılınca kayboluyor.

## Koordinatöre taşınan karar

G-056'nın DEFTER/PROGRESS kaydı ve ondan türeyen aile kuralı (M-F-57(2)) şu an
"kararsızlık malzemenin özelliği" diyor. Bu ölçüm, en azından KISMEN farklı bir
resim çiziyor. Olası aksiyonlar (kararı ben vermiyorum — yeni ölçü yorumu /
aile kuralı revizyonu YÜKSELTME kapsamında):

1. **G-056 kaydını GÜNCELLE:** "malzeme simetrik AMA referans havuzu
   sığ-tekrar filtresi olmadan sıra-kararsız; üretimde/referans inşasında sığ
   tekrarların (romTarget altı) dışlanması ÖNERİLİR" — bu hem push_up hem
   ileride benzer sığ/derin ayrımı olan her hareket için bir aile pratiği
   olabilir (build_reference.dart'a bir `excludeShallow` seçeneği eklenmesi
   anlamına gelir — bu YENİ bir tasarım kalemi).
2. **Mevcut kaydı DEĞİŞTİRME, yalnız not düş:** n=91 küçük bir örneklem
   olduğundan (44 tekrarlık orijinal ölçümle aradaki fark de dikkate
   alınmalı — bkz. aşağıdaki uyarı), bulguyu "ilginç ama teyit gerektirir"
   diye işaretle, aile kuralını hemen değiştirme.

## Uyarı — örneklem farkı

Bu koşumun BASELINE'ı 91 ham tekrar / 41 contributing take verdi; PROGRESS.md
ve DEFTER'deki orijinal G-056/push_up referansı "9 eğitmen · 44 take"
diyordu. Fark küçük ama sıfır değil — muhtemelen harvest havuzu gece boyunca
büyüdü (yeni fixture eklendi) ya da windowing/StructuralValidator sürüm farkı
var. Sayılar bu yüzden BİREBİR eşleşmiyor; yöntem ve yön (sıra-kararsızlığı
sığ-tekrar-duyarlı) güvenilir, ama tam sayılar yeniden üretilirken bu fark
göz önünde bulundurulmalı.

## Kanıt / komutlar

```bash
cd packages/gravita_engine
dart run tool/g056_shallow_mirror_probe.dart
```
