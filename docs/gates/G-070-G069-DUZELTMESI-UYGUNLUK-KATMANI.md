# G-070 — G-069'un TEŞHİSİ YANLIŞTI: sapan set = rig-UYGUN setin TAMAMI

**Bu belge kendi bulgumu geri çekiyor.** G-069'un SAYILARI doğru (sapan
take'ler, dereceler, 14°/30° ikisinde de kilitlenme). **Teşhisi yanlış:**
"3 kaynak diğer 9'dan sapıyor" dedim — gerçekte **diğer 9 kaynak M-F-47
anlaşma kapısına HİÇ ULAŞMADI.** Koordinatörün M-F-113 hükmü (seçenek c:
"referansı kümelenen 9 kaynaktan kur") bu yanlış teşhis üzerine kuruldu ve
**mekanik olarak uygulanamaz** — aşağıda kanıtlanıyor.

## Kanıt 1 — sapan set, uygun setle BİREBİR AYNI

`tool/diag_squat_eligibility.dart` (yeni), `ReferenceCli.eligibilityOf`'u
233 take'in hepsinde çağırıyor:

| kanal | attested | unattested | **ineligible** |
|---|---|---|---|
| Calisthenicmovement | 0 | 0 | 2 |
| GMB Fitness (Praxis) | 0 | 0 | 1 |
| Jeff Nippard | 0 | 0 | 23 |
| Jeremy Ethier | 0 | 0 | 6 |
| K boges | 0 | 0 | 59 |
| Sebastian Oreb | 0 | 0 | 4 |
| Squat University | 0 | 0 | 16 |
| **Strength Side** | **30** | 0 | 0 |
| **THENX** | **68** | 0 | 0 |
| TappBrothers | 0 | 0 | 1 |
| **Tom Merrick** | **2** | 0 | 9 |
| WeShape | 0 | 0 | 12 |
| **TOPLAM** | **100** | **0** | **133** |

M-F-47 kapısına ulaşan havuz: **100 take · 3 KAYNAK.** Diğer 133 take
kapıdan ÖNCE `ineligible` olarak düşüyor (`referenceEligible: false` —
`allowUnattested` bunu KURTARMAZ, o bayrak yalnız `unattested`ı kabul eder).

Küme kimliği betikle sınandı: G-069'un hata mesajındaki 100 sapan take ID'si
ile `referenceEligible: true` olan 100 take **BİREBİR AYNI küme** (fark:
her iki yönde de boş). Yani M-F-47 "sapan" dediği şey, havuzun **uygun
olan tamamıydı** — 100/100'ü sapıyor, `cluster` BOŞ kalıyor,
`cluster.length < minTakes` → `ReferenceAgreementError`.

## Kanıt 2 — seçenek (c) mekanik olarak İMKÂNSIZ

Strength Side + THENX kaynak-düzeyinde çıkarılıp koşuldu (M-F-113 seçenek c):

```
135 fixture → 134 ineligible → 2 usable take / 1 source (need 3/3)
→ ArgumentError: pool thinned below gates
```

Çünkü M-F-113'ün "kümelenen 9 kaynak" dediği kaynakların **hepsi
rig-uygunsuz** (`romMode: unknown` ya da `passive`). Onlar kümelenmedi —
kümeye hiç girmediler. Kalan 2 take, Tom Merrick'in zaten sapan
`w14_r0`/`w14_r1`'i.

## DOĞRU bulgu (G-069'un yerine geçen)

> **bodyweight_squat havuzunda YALNIZ 3 rig-uygun kaynak var (Strength Side,
> THENX, Tom Merrick'in 1 videosu) ve bu üçü BİRBİRİYLE ne 14°'de ne 30°'de
> anlaşıyor.** Squat'ın uygun-malzeme konsensüsü YOK — dar değil, hiç yok.

Ham sayı daha da çıplak: 27 ham squat fixture'ının **yalnız 4'ü**
`referenceEligible: true` (Strength Side 1 · THENX 2 · Tom Merrick 1).
M-F-38'in "≥3 kaynak" tabanı tam sınırda ve o üç kaynak anlaşmıyor.

## Hatam nasıl oldu (ders)

`result.excludedOutlierIds`'i okudum, **`result.excludedIneligibleIds`'i
okumadım.** CLI 133 take'i attığını söylüyordu; ben sormadım. Bu, G-059'un
kendi dersinin bana dönmesi: *"bu kapıya soran var mı?"* — beşinci canlılık
sorusunu kendi teşhisime uygulamadım. Sapan setin havuzun %43'ü olmasını
"3 kaynak" diye özetlemek, kalan %57'nin nerede olduğunu sormamak demekti.

Tetikleyici: kod arkeolojisi için koşturduğum alt-ajan aritmetiği
tutmadığını AÇIKÇA bayrakladı ("233−98=135 take, ≥9 kaynak kalıyor, bu
`minTakes=3`/`minSources=3`'ün rahat üstünde — neden fırlattığını statik
okumayla uzlaştıramadım"). Bu dürüst uyarı olmasa yanlış teşhis daha uzun
yaşardı. **Sonuç: raporlanan bir çelişki, kapatılacak bir pürüz değil, en
kısa yoldur.**

## Yan bulgu — push_up referansı TERS disiplini kullanıyor (aynı app!)

`reference.push_up.json` YAYIMDA ve `excludedIneligibleIds: []` diyor —
hiçbir take uygunsuzluktan düşmemiş. Sebep `canonical_push_up_reference.dart`
satır 39-44'te AÇIKÇA yazılı: araç, yeniden kurduğu tekrar-fixture'larının
provenance'ına `referenceEligible`'ı **hiç yazmıyor**, böylece CLI onları
`unattested` sınıflıyor ve `allowUnattested:true` kabul edip artefaktı
`PROVISIONAL` damgalıyor. Ham push_up dağılımı: 27 fixture → 1 `active/true`
· 1 anahtarsız · **25 uygunsuz** (24 `unknown` + 1 `passive`).

Yani **aynı app'in iki referansı zıt uygunluk disiplini uyguluyor:**
push_up uygunsuz malzemeyi `unattested`a çevirip PROVISIONAL ile alıyor,
squat (slicer provenance'ı BİREBİR koruduğu için) fail-closed reddediyor.

⚠️ M-F-43'ün kendi gerekçesi bu yolu doğrudan uyarıyor: *"`provisional`
etiketi YETMEZ: provisional istatistiksel zayıflığı örter, SİSTEMATİK
yanlılığı örtmez"* — ve `unknown`/`passive` tam olarak sistematik yanlılık
sınıfı. push_up'ın notu ("bu koşum ayrı bir eşiği ölçüyor, rig-triyaj
sorusunu yanıtlamıyor") tutarlı bir gerekçe ama M-F-43'ün fail-closed
kuralını yumuşatıyor. **Hangisi doğru disiplin — benim kararım değil.**

## Muhtemel KÖK NEDEN (yukarı akış, ölçülmedi)

Rig `romMode`'u **metinden** sınıflandırıyor (`rom_mode.py`: başlık +
açıklama + transkript içinde AROM/PROM/"passive"/"therapist" gibi işaretler)
ve işaret bulamazsa fail-closed `unknown` diyor. Fitness tutorial'larının
ezici çoğunluğu bu kelimeleri hiç kullanmaz → push_up'ta 24/27, squat'ta
23/27 `unknown`. Yani **kanıt-yokluğu, uygunsuzluk kanıtı gibi
davranıyor.** Bu doğruysa darboğaz Gravita'ya özgü değil, AİLENİN TÜM
referans hattının darboğazı (M-F-43'ün fail-closed'u doğru, ama sınıflandırma
sinyali fitness malzemesi için fazla dar olabilir).

## Koordinatöre — üç seçenek (SEÇMEDİM)

1. **Rig sınıflandırmasını genişlet** (yukarı akış, aile geneli): fitness
   tutorial'ları için `active` işaret sözlüğü yetersizse ölç ve genişlet;
   ya da "eğitmen kendi vücudunu gösteriyor + klinisyen/ikinci kişi yok"
   gibi LANDMARK-ölçülebilir bir ek sinyal tanımla (M-F-43'ün metin-şartı
   ROM modu için kaldı, ama `unknown`'ın tamamı pasif değil).
2. **push_up disiplinini squat'a taşı** (`referenceEligible` düşürülür →
   `unattested` → PROVISIONAL): squat referansı üretilebilir hale gelir ama
   `unknown`/`passive` malzemeden türer — M-F-43'ün açıkça uyardığı yol.
3. **Ters yön: push_up referansını fail-closed yeniden kur** — tutarlılık
   sağlanır ama push_up'ta yalnız 2 kabul edilebilir ham kaynak kalır, yani
   **yayımdaki push_up referansı geri çekilir** (M-F-38 tabanı kırılır).

Seçenek 2 ve 3 birbirinin zıddı ve ikisi de yayımdaki bir artefaktı ya da
aile kuralını değiştiriyor — bu yüzden hiçbiri tek taraflı uygulanmadı.
`reference.bodyweight_squat.json` YAZILMADI.

## Kanıt / komutlar

```bash
cd packages/gravita_engine
dart run tool/diag_squat_eligibility.dart          # uygunluk tablosu
dart run tool/canonical_squat_reference.dart --include-all   # G-069 orijinali (exit 1)
dart run tool/canonical_squat_reference.dart       # M-F-113 seçenek c (exit 255, pool thinned)
```

Ham koşum kaydı: `scratch/g069-rerun.log`. Küme-kimliği sınaması bu
belgenin "Kanıt 1" bölümünde.
