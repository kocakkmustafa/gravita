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

## ③④ TEMİZ KARELER — `gravita-hatti` (G-218)

`H-15` hükmünden sonra hatta **kendi simülatörü** alındı
(`gravita-hatti`, `2F59E2DB-8F02-4D24-BAD6-8313576FAB98`) ve kanıt orada
yeniden üretildi. **Başka hiçbir Motion app'i kurulu değil** ⇒ karelerde
`◀ <başka hat>` geri-etiketi **hiç yok**; ön-plan belirsizliği yapısal olarak
ortadan kalktı.

· `g213-duzeltme-ilk-ekran-temiz.png` — ilk kart, düzeltilmiş metin, **geçiş
  animasyonu yok, geri-etiketi yok**.
· `g213-duzeltme-kamera-gerekcesi.png` — **kamera izni gerekçesi**:
  *"Gravita needs your camera to **count your reps**. Nothing is recorded or
  uploaded…"* ⇒ *"and check your form"* kaldırılmış hâliyle **ekranda**.

## Kanıtlanmayan — adıyla

⛔ **KUSUR karesi (①) `H-15` ölçütünü KARŞILAMIYOR** ve öyle sayılmıyor:
geçiş anında alınmış, durum çubuğunda başka bir hattın adı var. İçeriği
tartışmasız Gravita olsa da **kanıt sayılmıyor.**
⇒ Kusurun otoritesi **git geçmişidir**:
`git show 27f5f2c:lib/app/onboarding_strings.dart` yalanı birebir taşır.
*Ekran görüntüsü kaybolur ya da şüpheli olur; commit olmaz.*

⛔ Onboarding **bayrağının kalıcılığı** bu turda ÖLÇÜLEMEDİ: üç adım
yürünürken `flutter run` sona erdi ve uygulama kapandı, yani akışın
tamamlanıp tamamlanmadığı **belirsiz**. *Belirsiz bir gözlemden sebep
üretmiyorum* (`G-215`in dersi).
