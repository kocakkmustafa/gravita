# G-124 — Dip Kimlik Kapısı: TASARIM — ve İLK KEZ TAM GÜVEN YOK, adıyla

**Tarih:** 2026-08-16 · **Kapsam:** hasat turu-1 kapı-tasarımı bacağı, ÜÇÜNCÜ ve
orkestratörün belirlediği üst sınırdaki ("2-3 kapı, sonra dur") son hareket. **Girdi:**
yalnız `gravita_engine` kaynağı + `content/catalog/w1/dip.json`'ın kendi mevcut alanları
+ G-121/G-123'ün kendi tasarım deneyimi. Hiçbir hasat adayına bakılmadı.

## 0 · Bu dosyanın FARKI — önceki ikisinden daha zayıf bir sonuçla bitiyor, ve bu KASITLI

G-121 (glute_bridge) ve G-123 (pull_up) tek bir aday sinyalde karar kıldı. Bu dosya
**karar kılmıyor** — iki adayı da denedim, ikisi de YETERSİZ çıktı, ve bunu ZORLA bir
sonuca bağlamak yerine yetersizliği adıyla yazıyorum. *Bir tasarımın "emin değilim"
demesi, "emin" demekten daha ucuz bir hatadır.*

## 1 · Kapının çözmesi gereken risk

Motor `elbow` açısının `top(≥160°)→bottom(≤116°)` salınımını sayıyor
(`dip.json:31-44`). Aynı sınıf (G-043): AYAKTA/OTURARAK yapılan bir triceps extension
veya benzer dirsek-fleksiyon hareketi aynı aralığı üretebilir.

## 2 · İKİ ADAY DA DENENDİ, İKİSİ DE ZAYIF

**Aday-1: `torso_angle_from_vertical` (G-121/G-123'ün deseni).** Dip'te gövde DİKEY
durur (paralellerde dik, kollar yanda) — `dip.json`'ın kendi `excessive_lean`
formError'ı (satır 102-120) bunu zaten DOĞRULUYOR: DÜŞÜK açı = doğru form, YÜKSEK (>35°)
= aşırı öne eğilme uyarısı. Ama bu AYNI ZAMANDA ayakta duran/oturan bir insanın da doğal
duruşu — pull_up'ta bulduğum tam kusur burada TEKRARLANIYOR: dikey gövde, dip'e ÖZGÜ
değil.

**Aday-2: `shoulder_angle` (G-123'ün deseni).** Pull-up'ta işe yaramıştı çünkü kol
YUKARIDAYDI (büyük açı). Dip'te kol AŞAĞIDA/yanda — gövdeye YAKIN (paralellere basan
kollar, dirsek gövdenin yanında) — bu da KÜÇÜK bir açı üretir, **tıpkı standing bir
triceps extension'daki gibi.** İkinci aday da AYNI kusura düşüyor: dip'in kol
konfigürasyonu, reddetmek istediğim yanlış-pozitif sınıfıyla (ayakta kol hareketi)
GEOMETRİK OLARAK BENZER.

> ***İKİ HAREKETİN "AYAKTA/DİKEY, KOL YANDA" ORTAK BİR YAPISI VARSA, TEK EKLEM AÇISI
> BUNLARI AYIRAMAZ — AYIRT EDİCİ OLAN, GÖVDENİN DEĞİL BÜTÜN VÜCUDUN NEREDE OLDUĞUDUR.***

## 3 · Gerçek ayırt edici muhtemelen engine'in BUGÜNKÜ kelime dağarcığında YOK

Dip'i standing bir kol hareketinden GERÇEKTEN ayıran şey: kullanıcının **tüm vücut
ağırlığı düz kollar üzerinde asılı, ayaklar YERDEN KESİK.** Bu bir "vücut YÜKSEKLİĞİ"
ya da "ayak-yer teması" sorusu — `MovementMetrics`in bugünkü alan listesinde (metrics.
dart:20-303) böyle bir metrik YOK. En yakın aday, `heel_rise_torso_norm` (topuk-parmak
yükseklik farkı ÷ gövde boyu, metrics.dart:163-166) — ama bu metriğin dip'teki anlamı
BELİRSİZ (dip'te bacak pozisyonu düz/bükük değişken, standart bir "topuk kalkması"
imzası taşımayabilir) ve KENDİM ÖLÇMEDEN bunu önermek tam da G-014/G-050'nin yasakladığı
şey — bir varsayımı bir başka varsayımla örtmek olurdu.

## 4 · Bu turda ÖNERİLEN — zayıf ama YANLIŞ olmayan bir taban, açıkça İSİMLİ eksikle

**Geçici, PARÇALI koruma:** `torso_angle_from_vertical` düşük bir tavan olarak KALSIN
(dip.json'ın kendi `excessive_lean` mantığıyla tutarlı — aşırı yatık bir gövde zaten
dip DEĞİLDİR, bu YÖNDE bir bilgi taşıyor) ama bu tek başına YETERLİ bir kimlik kapısı
OLARAK SUNULMASIN. `status: pending` kalmalı — `derived`e çevrilebilecek bir aday
formül henüz YOK, yalnız ELENEN iki aday var.

```json
"precondition": {
  "status": "pending",
  "conditions": []
}
```

**Bu, önceki iki dosyadan FARKLI bir teslimat:** G-121/G-123 birer aday formülle
bitti (eşiği hasat ölçsün). Bu dosya adayı EKSİK bırakıyor çünkü elimdeki iki aday da
akıl yürütmeyle ELENDİ — sahte bir formül önermek, hiç önermemekten DAHA KÖTÜ olurdu
(yanlış güven verirdi).

## 5 · Hasat turu-1'in bu kapı için ÖNCE ÖLÇMESİ gereken şey — farklı bir sıra

Diğer iki tasarımda hasat "eşiği ölçer." Burada hasat ÖNCE **"ayırt edici bir sinyal
var mı"** sorusunu ölçmeli:

1. Gerçek dip tekrarlarında `torso_angle_from_vertical` VE `shoulder_angle`in birlikte
   dağılımı — ikisi de standing bir kol hareketininkiyle örtüşüyorsa (beklenen sonuç,
   §2'nin akıl yürütmesine göre), **motor kelime dağarcığına yeni bir metrik gerekir**
   (aday: bir "vücut-yüksekliği" ya da "ayak-görünürlüğü" sinyali) — bu, kapsamı hasat
   turu-1'in ÖTESİNE, bir "kod" kuyruğu kalemine taşır.
2. Alternatif, daha ucuz bir yol: dip'in KENDİ camera.notes'u zaten "tam boy kadrajda
   kalmalı" diyor (`dip.json:22`) — ayakların GÖRÜNÜRLÜĞÜ (visibility skoru, motorun
   zaten her landmark için taşıdığı bir değer) düşükse bu "ayaklar kadraj dışı/asılı"
   için ZAYIF bir vekil olabilir. Ölçülmeden ÖNERİLMEDİ, yalnız ADI kondu.

## 6 · Kapsam dışı, adıyla

- Bu hareketin identity-kapısı, hasat turu-1'in ÜÇÜ arasında en olası "kod kuyruğuna
  düşecek" aday — orkestratöre bu turun özetinde adıyla iletiliyor.
- `shoulder_elevation_proxy` (formError'da kullanılan) bu turda araştırılmadı,
  kimlik kapısıyla ilgisiz.

---

**Hipotez defterine eklendi:** `docs/gates/G-122-HASAT-TURU1-HIPOTEZ-DEFTERI.md` H3 —
ama bu satır diğerlerinden FARKLI biçimde: "çürütülecek bir hipotez" değil "bulunacak
bir sinyal" arıyor.

**Orkestratörün üst sınırı (2-3 kapı) burada doldu. Bu turun kapı-tasarımı bacağı
KAPANDI.**
