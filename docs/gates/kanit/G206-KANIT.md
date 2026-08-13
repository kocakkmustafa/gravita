# G-206 kanıtı — kapı cümlesi yanlış hareketi anlatıyordu

**Cihaz:** iPhone 17 Pro Max simülatörü (iOS 26.4), debug derleme, 2026-08-14.
**Yürüyüş:** Today → `Start` (kabuktaki tek seans girişi) → seans sayfası.

> ⚠️ Bu iki görüntü **aynı gecenin iki anıdır**, ikisi de Gravita'nın kendi
> ekranıdır (içerikten teyit edildi — o gece beş Motion app'i aynı simülatörü
> paylaşıyordu ve ön-plan doğrulaması yapılmadan alınan bir görüntü başka bir
> ürünün olabilir).

## ① `g206-kusur-sinav-kapisi-squat-seansinda.png` — KUSUR

`G-205` uygulanmış: başlık artık doğru, **"Bodyweight Squat"**.
Ama kapı cümlesi hâlâ sabit ve şunu diyor:

> *"We only count a rep when we can see your **torso is actually horizontal**."*

Bu **şınavın** kimlik kapısıdır (`engine.precondition`:
`torso_angle_from_vertical >= 60`). Squat'ınki **başkadır**:
`windowPrecondition` — kalça-diz Pearson `>= 0,2`, çevrim başına.

⇒ Ürünün **tek ulaşılabilir seansı**, kullanıcıya **ölçmediği bir şeyi
ölçtüğünü** söylüyordu.

📌 Bu kare, kusurun statik okumayla değil **uygulamayı çalıştırarak**
bulunduğunun kanıtıdır: ekran görüntüsü `G-205`i doğrulamak için alınmıştı,
kusur aynı karenin içinde duruyordu.

## ② `g206-duzeltme-squat-kendi-kapisi.png` — DÜZELTME

Aynı yürüyüş, düzeltme sonrası. Kapı cümlesi artık içerikten
(`measurementContract.gateNote`) geliyor ve squat'ın **kendi** kapısını
anlatıyor:

> *"We only count a rep when your **hip and knee move through it together**.
> That is how we tell a real squat from a knee that simply bends."*

## Bu görüntülerin KANITLAMADIĞI şey — adıyla

Her ikisi de **kabuk + seans giriş sayfasıdır**. Kamera akışı, tekrar sayımı
ve `G-207`in seans-sonu özeti **bu karelerde YOKTUR** ve bu bir eksiklik
değil bir **olgudur**: iOS simülatöründe `AVCaptureDevice` yok, oturum
yapısal olarak başlamaz. O yarı `A12`ye aittir.
