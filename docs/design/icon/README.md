# Gravita uygulama ikonu — D8 (F4, 2026-08-16)

## 2026-09-23 — yeni görsel seçimi

Kurucu, siyah/kırmızı zeminli tek el straddle handstand görselinin ilk özenli yeniden çizimini seçti ve figür değişmeden dış köşelerin hafif yumuşatılmasını istedi. Seçilen kaynak, yuvarlatılmış önizleme ve kare/opak mağaza boyutu adayları [`docs/store/icon-candidates/`](../../store/icon-candidates/README.md) altında kayıtlıdır. Aşağıdaki D8 üretim ve cihaz doğrulama kaydı tarihsel olarak önceki, eklem çizgili ikona aittir; yeni aday henüz native uygulama ikon varlıklarına uygulanmadı.

**Durum: build'e girdi** (`ios/Runner/Assets.xcassets/AppIcon.appiconset/` +
`android/app/src/main/res/mipmap-*/ic_launcher.png`, 2026-08-16). Şablon ikon (Flutter'ın
varsayılan mavi "F" logosu — orkestratörün "turuncu" dediği DEĞİL, gerçek renk mavi; bu
küçük düzeltme adıyla not edilsin) tamamen değiştirildi.

## Aile dili — ölçüldü, icat edilmedi

Beş kardeş app'ten yalnız **Ostinato**'nun gerçek bir özel ikonu var (Choreia/Lissom/JabLab
hâlâ Flutter şablonunda) — koyu lacivert zemin + TEK beyaz glif, nokta-çizgi (eklem-uzuv)
sözlüğüyle bir duruş figürü. Bu, D8'in referans aldığı somut örnek.

## Renk — Gravita'nın KENDİ zaten kurulu marka rengi

Zemin `#A11019` — icat edilmedi, `lib/app/theme.dart`daki `GravitaColors.accent`ın
BİREBİR aynısı (her ekran görüntüsündeki "Continue"/"Start" düğmelerinin rengi). Ostinato
kendi lacivertini kullandı, Gravita kendi kırmızısını — aynı GRAMER (koyu zemin + beyaz
glif), farklı ürün kimliği.

## Glif — uygulamanın KENDİ ölçtüğü mekanizma

Bükülü bir uzuv (kalça/diz/ayak bileği ya da dirsek/omuz/bilek): üç eklem NOKTASI, iki
uzuv ÇİZGİSİ, aynı Ostinato'nun nokta-çizgi sözlüğü ama FARKLI siluet (duran bir figür
değil, bükülü/hareket hâlindeki bir eklem). Bu bir dekorasyon değil — Gravita'nın canlı
kimlik-kapısı TAM OLARAK bunu ölçüyor: squat'ta kalça-diz açısı (Pearson korelasyonu),
push_up'ta gövde-dikey açısı (`M-F-38-PILOT-RAPORU.md`). İkon, uygulamanın "yalnız hareketi
GERÇEKTEN gördüğünde sayar" vaadinin görsel kısaltması.

## Süreç — 3 aday üretildi, biri seçildi

`comparison-preview.png` (`alternatives/`) üçünü yan yana + küçük boyutta (120px, gerçek
ana ekran ikonuna yakın) gösteriyor — hepsi AYNI kavram (bükülü eklem), üç farklı ağırlık/
açı. Seçilen (`gravita-icon-master.svg`) en KALIN çizgili + en DERİN açılı — küçük boyutta
en güçlü görünen oydu, ölçülerek karşılaştırıldı (gözle, `comparison-preview.png` üzerinden).
Elenen ikisi SİLİNMEDİ, `alternatives/`de duruyor.

⛔ **Elenen iki farklı KAVRAM da adıyla kayıtta:** bir tik/onay-işareti (jenerik, "sayım"ı
temsil ediyordu ama eklem-sözlüğünü kaybediyordu) ve bir tekrar-çemberi/ok (geometri
hatası nedeniyle dağınık çıktı, yeniden tasarlanmadı — zaman bütçesi bükülü-eklem
kavramının zaten güçlü olmasına ayrıldı). İkisi de kaydedilmedi (yalnızca scratchpad'de
kaldılar) — yalnız AYNI kavramın üç varyantı depoya girdi, iki FARKLI kavram girmedi. Bu
adıyla söyleniyor, gizlenmiyor.

## Üretim

`rsvg-convert` ile `gravita-icon-master.svg`den HER hedef piksel boyutuna doğrudan
render edildi (bir rasterden küçültme değil — vektörden her boyut için ayrı render,
keskinlik kaybı yok). iOS 15 dosya (`Contents.json`ın KENDİ listesiyle birebir eşleşti,
python ile doğrulandı) + Android 5 yoğunluk (`mdpi`–`xxxhdpi`, adaptive-icon XML'i bu
uygulamada YOK — var olan düz `ic_launcher.png` yapısına uyuldu, yeni bir sistem
icat edilmedi).

## Doğrulama — gerçek cihazda

`gravita-hatti` simülatöründe gerçek `flutter build ios --simulator` + ana ekrana dönüş
(`HOME` düğmesi) ile GERÇEK ana ekranda görüldü — yalnız izole bir önizleme değil, sistem
diğer uygulama ikonlarının YANINDA nasıl durduğu.
