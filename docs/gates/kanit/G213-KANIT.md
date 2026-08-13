# G-213 kanıtı — ürünün İLK cümlesi

**Cihaz:** iPhone 17 Pro Max simülatörü (iOS 26.4), debug, 2026-08-14.
**Yürüyüş:** uygulama onboarding'de açıldı ve kusur **aranmıyordu**; ekrandaydı.

> 🔧 **DÜZELTME (G-215, aynı gece):** ilk hâlinde burada *"yeni derleme
> kurulumu sıfırladı"* yazıyordu. **Yanlış sebep.** Koordinatör `H-12`
> (JabLab `J-253`) ölçtü: **cihaz derlemesi paylaşılan native-asset
> artefaktının üzerine yazıyor**, simülatöre cihaz-platformlu ikili giriyor,
> `dyld` reddediyor ve `path_provider` her çağrıda patlıyor ⇒ onboarding
> bayrağı **sessizce ölüyor**. O gece `G-208`de gerçek cihaza derleme
> yapmıştım; bu kareler o derlemeden SONRA alındı.
> Panzehir uygulandı (`flutter clean` + `build/` symlink'i geri kondu) ve
> ölçüldü: uygulama artık **doğrudan Today'e açılıyor**, bayrak kalıcı.
> ⇒ *Durum kaybının sebebi kurulum değil, zehirlenmiş artefaktmış.*
> **Kusurun ve düzeltmenin kendisi bundan ETKİLENMEZ** — ekrandaki metin
> derleme-zamanı sabitidir, `path_provider` onu değiştirmez.

> ⚠️ O gece beş Motion app'i aynı simülatörü paylaşıyordu. Her iki kare de
> **içerikten** Gravita olduğu teyit edilerek alındı (başlık *"What Gravita
> is — and isn't"*).

## ① `g213-kusur-ilk-ekran-vaadi.png` — KUSUR

> *"Your phone camera **watches your form** and counts your reps, on-device.
> **When a rule fires, we tell you what to change.**"*

`G-212`de ölçüldü: kural değerlendirmesi (`RepEngine.correctionFor` /
`topCorrection` / `repMetrics`) **üründe hiç çağrılmıyor** — tek çağıran
çevrimdışı `tool/replay_gate.dart`. Canlı seansta hiçbir kural ateşlenmiyor
ve kimseye bir şey söylenmiyor. ⇒ **Her yeni kullanıcının gördüğü ilk cümle
yalandı.**

⚠️ Kare bir uygulama-değiştirme animasyonu sırasında alındı (solda başka bir
app'in kenarı görünüyor); **metin tam ve okunaklıdır**, kanıtın konusu odur.

## ② `g213-duzeltme-ilk-ekran.png` — DÜZELTME

> *"Your phone camera counts your reps, on-device, and only counts one when
> it can see you are really doing the movement. **It does not grade your
> form, and nothing corrects you while you train.**"*

Ürünün bugün GERÇEKTEN yaptığı: sayma + kimlik kapısı. Yapmadığı: notlama ve
düzeltme — ve artık **söyleniyor**.

## Kanıtlanmayan — adıyla

Bu kareler onboarding'in **ilk kartıdır**. Kamera izni gerekçesindeki ikinci
düzeltme (*"and check your form"* kaldırıldı) bu karelerde **görünmüyor**;
onun kanıtı `test/onboarding_claims_test.dart`ta, ekran görüntüsünde değil.
