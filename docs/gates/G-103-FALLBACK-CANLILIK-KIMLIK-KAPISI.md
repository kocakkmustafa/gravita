# G-103 — Fallback canlılık ölçümü: kimlik kapısı KARE düzeyinde, iddia TEKRAR düzeyinde

**Aile reçetesi M-F-184/1'in Gravita bacağı**
(`ventures/motion-core/workspace/FALLBACK-CANLILIK-RECETESI.md`). Reçete:
*"Bir fallback sınıfının VAR olması, tanımadığı girdinin ORAYA DÜŞTÜĞÜ anlamına
gelmez — ölçülmedikçe dekoratiftir."*

Sonda: `packages/gravita_engine/tool/fallback_liveness_probe.dart` ·
çıktı: `content/harvest/fallback-liveness.json`

## Adım 1 — Gravita'nın sözlüğü, İSİMLE

⚠️ **Gravita'da "unclassified movement" sınıfı YOK — ve bu bir kusur değil,
mimari bir olgu:** ürün *"bu hangi hareket?"* diye SORMAZ; kullanıcı dersi
seçer, motor o hareketin config'iyle koşar. Sözlük-dışı girdinin düşecek iki
yeri var:

| yol | durum |
|---|---|
| `refusalReason` (ön koşul `derived` değil → hiç sayma, M-F-122) | **ÜRETİMDE ERİŞİLEMEZ.** Tek canlı hareket `push_up` ve ön koşulu `derived`; K8 zaten `live`+`pending` birleşimini yasaklıyor. Beyan doğru — ama bugün tetiklenemez, o yüzden "canlı" YAZILMADI. |
| **kimlik kapısı → `skippedFrames`** (`torso_angle_from_vertical >= 60`, G-043) | asıl yol; ölçüldü |

## Adım 2 — sözlük-dışı GERÇEK girdi

**27 gerçek video, tam-video landmark'ı, `push_up` config'iyle.** Sentetik
değil: güven/görünürlük/faz kapılarını gerçek bir kayıt gibi zorluyor.

**POZİTİF KONTROL (M-F-194):** aynı hat 27 gerçek `push_up` videosuyla da
koşuldu. Bu olmadan "0 tekrar" hiçbir şey kanıtlamazdı — bozuk bir düzenek de 0
verir.

## Adım 3 — üç sayaç BİRLİKTE

| | sözlük-dışı | pozitif kontrol |
|---|---|---|
| dosya | 27 | 27 |
| **tekrar** | **25** | **97** |
| hükümlü kare | 7.642 | 18.436 |
| atlanan kare | 139.824 (**%94,8 reddedildi**) | 78.005 |
| tekrar üreten dosya | **6 / 27** | 20 / 27 |
| gövde görünürlük medyanı (tekrar pencerelerinde) | **1,000** | 1,000 |

## ⚠️ Teşhis: NE "A" NE "B" — ve ilk yazdığım hâl FAZLA İDDİAYDI

Sondanın ilk hâli doğrudan **"A: MISCLASSIFICATION"** diyordu. Yanlıştı ve
reçetenin §4 kapısı tam bunu önlemek için var: ***"X videosu" ≠ "X olayı".***

Üç ölçüm birlikte okununca tablo değişti:

1. **Yoğunlaşma.** 25 tekrarın **17'si TEK dosyadan**, ve 27 dosyanın **21'i
   SIFIR** üretti. Sistematik yanlış-sınıflama bunun tersini gerektirir
   (kontrolde 20/27 dosya üretiyor). Sonda artık dosya payı ≤1/3 ise
   **"INDETERMINATE (not A)"** diyor.
2. **Hipotezim çürütüldü.** "Kapı, modelin TAHMİN ettiği gövdeyle geçiyor"
   dedim (G-078 ailesi: MediaPipe görmediği uzvun güvenini düşürmez, konum
   uydurur). Ölçtüm: tekrar pencerelerinde gövde görünürlüğü **1,000** —
   kontrolle aynı. Kapı uydurma geometriyle DEĞİL, gerçekten görünen gövdeyle
   geçiyor.
3. **Gözle bakınca dosya kimliği de değişti.** En yüklü dosya
   (`OEsW3S_NAuc`, 17 tekrar) squat tutorial'ı DEĞİL: *"Can't Squat? Fix Your
   Hips! (FULL ROUTINE)"* — 11 dakikalık **kalça hareketliliği rutini**
   (derin lunge / hip-flexor açma). Yani havuzun kendisi "squat videosu"
   varsayımımı da taşımıyordu.

## 🔴 ASIL BULGU (ayrı ölçüldü, GERÇEK): kare-düzeyi kapı, tekrar-düzeyi iddia

Kapının uygulandığı yeri okudum: `RepEngine.addFrame` adım 3'te kapı
**KARE başına** değerlendiriliyor ve kapı kapalı kare `skippedFrames++` +
`return` yapıyor — **çevrim durumu OLDUĞU GİBİ KALIYOR.** Yani bir tekrar,
aralarında yüzlerce kapısız kare olan iki kapı-açık parçadan **birleştirilebilir**;
tek sınır `timeoutUs`.

Ölçüm bunu doğruladı — pencerelerde gövde-dikeyden-açı **medyanı 8-41°**, yani
kapının kendi eşiğinin (**60°**) ALTINDA, ama tekrar yine sayıldı:

| | sözlük-dışı | pozitif kontrol |
|---|---|---|
| **kimlik boşluğu İÇEREN tekrar** | **9 / 25 (%36)** | 19 / 97 (%19,6) |
| çevrim İÇİNDE kapı-kapalı kare | 18.855 | 6.958 |

Kontrolde de %19,6 çıkması önemli: bu **sözlük-dışına özgü değil, genel bir
granülerite açığı.** Aile sınıfı: *yanlış granülerite yanlış güvence*
(G-088'in `minPhaseMs` vakasıyla aynı aile — take-düzeyi taban geçiyordu,
faz-düzeyi geçmiyordu).

## Ne YAPTIM / ne YAPMADIM

**Yaptım — SALT RAPOR (M-F-162 emsali):** `RepEngine.identityClosedFramesInCycle`
ve `repsWithIdentityGap` sayaçları. **Hiçbir tekrar bu yüzden reddedilmiyor;
davranış bit-bit aynı.** Reçetenin adım-4 kalıcı testi + pozitif ikizi eklendi
(kapı hep açıkken sayaç SIFIR kalmalı — ikizi olmayan yokluk-kapısı kendi
yazım hatasını göremez, M-F-194).

**YAPMADIM — zorlama.** Çevrimi kapı kapanınca sıfırlamak mı, yoksa
"tekrarın karelerinin ≥%X'inde kapı açık olmalı" payı mı — bu bir **KAPI
TASARIMI** ve yükseltme kuralı gereği koordinatör hükmü bekler. Sıfırlama
seçeneğinin bilinen riski: gerçek bir kullanıcı seansında kadraj dışına çıkan
tek kare bile tekrarı iptal eder ve kullanıcı sıfır-sayım + sıfır-geri-bildirim
durumunda kalır (G-054'te bir kez yapılmış hata).

**Ölçmedim:** olay-başı ground truth. 25 tekrarın kaç tanesi gerçek yatay-gövde
hareketi, kaç tanesi kapı-boşluğu artefaktı — bu, damga-başına insan
doğrulaması ister. Sonda zaman damgalarını (`windowStartsS`) tam bu iş için
yazıyor; 4 damga gözle bakıldı (biri lunge, biri kadraj-dışı gövde), 25'i
bakılmadı. **Bu yüzden "squatlar şınav sayılıyor" cümlesi KURULMADI.**

## Ürün metnine etkisi

Bugün YOK ve bu bilinçli: kapı-boşluğu ölçümü henüz kullanıcıya dönük bir iddia
DEĞİL, salt rapor. `library.json`ın `notMeasured` bloğu hâlâ doğru
(*"form karşılaştırması yapılmıyor"*). Zorlama kararı verilirse
`honesty.measured` satırı *"tekrar sayımı"* yanına kapı-sürekliliği koşulunu
yazmak gerekir.

## Kapılar

`dart analyze` temiz (motor+kabuk) · motor **118/118** · kabuk **33/33** ·
`validate_library` TEMİZ + self-test **15/15** · `validate_catalog` 0 hata ·
replay 8 ateşlenen **0 ÖLÜ**.
