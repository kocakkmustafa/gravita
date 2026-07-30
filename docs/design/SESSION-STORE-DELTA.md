# SessionStore — Gravita delta sözleşmesi (ÜÇÜNCÜ tüketici)

**Tarih:** 2026-07-30 · **Statü:** sözleşme + PORT YAPILDI (Choreia'nın aksine)
**Kaynak desen:** `ventures/jablab/app/lib/app/session_store.dart` (205 satır, okundu) + `test/session_store_test.dart` (12 test, okundu)
**İkinci girdi:** `ventures/choreia/app/docs/design/SESSION-STORE-DELTA.md` (109 satır, okundu)

Koordinatör: *"SEN ÜÇÜNCÜ TÜKETİCİSİN → üçler kuralı tetikleniyor… çekirdek-terfi
ÖNERİSİNİ tek taraflı YAPMA."* Bu belge deltayı kaydeder; terfi arayüzünü
koordinatör hakemleyecek.

## 0. ⚠️ Choreia'nın "port yapılamaz" hükmü Gravita'da GEÇERSİZ — ölçtüm

Choreia §0 portu erteledi çünkü SessionStore'u bir **ürün** bileşeni saydı
(`path_provider` + Flutter yaşam döngüsü). **JabLab'ın kodunu okuyunca bu
doğru çıkmadı:**

- `JsonlSessionStore(this._file)` — yalnız bir `File` alıyor. `dart:io` +
  `dart:convert`, **Flutter bağımlılığı YOK.**
- `path_provider` yalnız ÇAĞRI YERİNDE (`content_repository.dart:90`):
  `JsonlSessionStore(File('${dir.path}/sessions.jsonl'))`.

Yani **depo saf Dart, yalnız KABLOLAMA Flutter gerektiriyor.** Gravita'nın da
Flutter app'i yok (`app/lib` yok) ama `packages/gravita_engine` var → **port
BUGÜN yapılabilir ve test edilebilir.** Yaptım.

> Bu, delta kaydının ilk somut faydası: Choreia'nın kapsam hükmü tek bir
> okumayla düzeldi. Dizin sağlayıcısı **enjekte edilirse** kalıcılık katmanı
> app-bağımsız olur — terfi arayüzü bunu korumalı (`File` alan kurucu,
> `path_provider`ı ÇAĞIRAN değil).

## 1. Taşınan yapısal kararlar (delta YOK)

JabLab'ın dördü Gravita'da da aynen geçerli: **append-only JSONL** (3. taraf DB
yok) · **SATIR-düzeyi şema sürümü** · **atomik tmp+rename** · **bilerek-az alan,
hüküm/skor alanı YOK**.

Arıza davranışlarının hepsi porta alındı ve test edildi: bozuk satır tüm
geçmişi silmez · yarım son satır sağlamları götürmez · bilinmeyen `v` atlanır ·
dosya yokluğu hata değil · `_readAll` **değiştirilebilir** liste döner
(JabLab'da `const []` ilk-açılışı çökertmişti).

## 2. ⭐ DELTA 1 — birim etiketi **KAYIT-BAŞINA** olmalı, app-başına DEĞİL

Choreia §2 nötr biçimi önerdi ve etiketi **app düzeyinde** örnekledi:
*"JabLab `round` · Choreia `cycle` · Lissom `rep`"*.

**Gravita bu varsayımı kırıyor — ve bu ölçülmüş bir olgu, tasarım tercihi
değil.** Katalogda üç motor tipi var ve birimleri AYNI APP İÇİNDE farklı:

| motor tipi | hareket örneği | birim |
|---|---|---|
| `repFsm` (22) | push_up · bodyweight_squat · pull_up · db_row | **tekrar** |
| `staticHold` (8) | plank · wall_sit · hollow_hold · side_plank · superman_hold · farmer_carry · tuck_planche · wall_handstand | **saniye** |
| `multiPhaseFsm` (1) | burpee | **tekrar** |

> ⚠️ **DÜZELTME (kalem 3 sırasında ölçüldü):** bu tablo ilk hâlinde `14/5/1`
> yazıyordu — o sayılar `content/catalog/w1`in sayılarıydı, kataloğun DEĞİL.
> Gerçek katalog **31 hareket** (W1: 20, W2: 11). Kök neden ilginç ve kendi
> başına bir bulgu: `catalog_smoke_test.dart` da yalnız `w1` okuyordu, yani
> *"motor kataloğun TAMAMINI tüketebilmeli"* iddiası 20/31 hareketle
> sınanıyordu ve ben sayımı o kapıdan devraldım. Kapı genişletildi (artık
> `content/catalog/w*` taranıyor + dalga-körlüğü nöbeti olarak sayı çivilendi)
> ve **W2'nin 11 hareketi de sorunsuz yükleniyor** — gizli bir kusur yoktu,
> ama iddia doğru olmadan geçiyordu. Delta 1'in SONUCU değişmiyor, GÜÇLENİYOR:
> saniye-birimli hareket 5 değil 8.

Bir plank seansının "birimi" saniyedir, bir şınav seansının tekrardır. Tek bir
app-düzeyi `unitLabel` bunu ifade EDEMEZ.

**Öneri (terfi girdisi):** `unitLabel` **`SessionRecord` alanı** olarak kalsın —
kayıt kendi birimini taşısın. Choreia'nın gerekçesi (*"yüzey onu okuyacak: '6 of
8 cycles' ≠ '6 of 8 rounds'"*) Gravita'da bir adım daha ileri gidiyor: aynı
ilerleme ekranında *"3 of 5 reps"* ile *"45 of 60 seconds"* YAN YANA görünecek.

### Ve bir dejenerasyon uyarısı: `staticHold`'da iki alan AYNI sayı olur

`staticHold` dersinde `unitsCompleted` (saniye) ile `workedSeconds` **aynı
değeri** taşır. Bu sessiz bir tekrar; iki seçenek de terfi gününe not:
(a) kabul edilir ve belgelenir, (b) `unitLabel == 'second'` ise `unitsCompleted`
**türetilir** (yazılmaz). Kararı tek taraflı vermiyorum — ama **belgelenmemiş
hâli en kötüsü**, çünkü yüzey iki alanı bağımsız sanıp ikisini birden gösterir.

## 3. DELTA 2 — `lessonClass`: Choreia'yla BAĞIMSIZ YAKINSAMA

Choreia §3 `lessonClass` (`scored | demoOnly`) önerdi; gerekçesi *"sınıf zamanla
DEĞİŞEBİLİR, kaydı yazıldığı günün sınıfıyla saklamak retroaktif yeniden
yorumlamayı engeller."*

**Gravita'da aynı ihtiyaç aynı sebeple var — ve sebebi bu gece ölçüldü:**
push_up'ın `form_check` dersi bugün KİLİTLİ çünkü hiçbir eklem toleransı
varyans-türetimli değil (`derivedJoints: []`). Squat'ta rebuild sonrası
kalça+uyluk varyansa GEÇTİ (G-091) — yani **ders sınıfı ölçüm geliştikçe
gerçekten terfi ediyor.** K9 değişmezi bunu zaten mekanikleştirdi (bloker
ölürse "BAYAT KİLİT").

Öyleyse: bir seans kaydı, o gün dersin **skorlanıp skorlanmadığını** taşımak
zorunda. Aksi hâlde form-notu açıldığı gün, açılmadan ÖNCEKİ seanslar geçmişte
"notlanmış" görünür.

**Öneri:** `lessonClass` (`scored | measurementOnly`) kayda girer. Ad farkı
kasıtlı: Choreia'nın `demoOnly`'si "gösterim" çağrışımı taşıyor; Gravita'da
kilitli ders **ölçülüyor ama notlanmıyor** (rep sayımı çalışır, form notu
çalışmaz). Terfi günü ortak ad seçilir — iki app aynı AYRIMI istiyor, bu
yakınsama terfinin en güçlü kanıtı.

## 4. DELTA 3 — Gravita-özgü: **ÖLÇÜLEMEYEN birimler kaydedilmek zorunda**

Bu, diğer iki app'te karşılığı OLMAYAN gerçek delta.

PRD §3.4 açık söz veriyor: *"Analiz edilemeyen deneme: 'Couldn't analyse that
one' + neden. **İlerleme düşmez.**"* UI-BRIEF §5-6 bunu tasarım-kısıtı yaptı:
*"ölçülemedi ≠ başarısızlık"*. Motor tarafında kanal HAZIR: `RepEngine.
skippedFrames` ve `refusalReason` (M-F-122).

**JabLab'ın kaydında bunu söyleyecek alan YOK.** `roundsCompleted: 3` yazan bir
kayıt, "3 tur yaptım ve 3'ü de ölçüldü" ile "3 tur yaptım, 1'i ölçülemedi"
arasında ayrım yapamaz. Gravita'da bu ayrım vaadin kendisi.

**Öneri:** `unmeasuredUnits: int` (ölçülemeyen birim sayısı) + isteğe bağlı
`unmeasuredReason: String?` (kadraj/ışık/çok-kişi/kamera-hareketi — PRD §3.4'ün
kendi listesi). Sözleşme: `unitsCompleted` ÖLÇÜLENleri sayar; `unmeasuredUnits`
görünür ama hüküm verilemeyenleri. **İkisinin toplamı kullanıcının yaptığı iştir.**

⚠️ Alternatif (daha az alan): hiç kaydetmemek ve "ölçülemedi"yi yalnız o anki
ekranda göstermek. **Reddediyorum, gerekçeli:** o zaman yarın ilerleme yüzeyi
"3 tekrar" der ve kullanıcının 4 tekrar yaptığını, birinin ölçülemediğini
SAKLAR. Bu, gecenin tekrar eden dersinin ta kendisi — *sessizlik yalandır*
(J-066 disiplini, UI-BRIEF'e "geçilemez-kapı beyanı" olarak işlenmiş).

## 5. Gravita'da ŞU AN kaydedilemeyenler (dürüstlük sınırı)

Port bir veri katmanı; onu besleyen canlı seans HENÜZ YOK (kamera köprüsü
ailenin en büyük eksik bloku). Bu yüzden:

- Depo çalışır ve testli, ama **üretimde bugün hiçbir kayıt yazılmıyor.**
- `analysisConfidence`, `orientationStrategy`, `modelVersion`+SHA gibi ADR-005
  köken alanları **bu kayda EKLENMEDİ.** Gerekçe: onlar `Attempt` düzeyi
  (deneme-başına), `SessionRecord` ise seans düzeyi. İkisini karıştırmak
  JabLab'ın "bilerek-az alan" kararını çiğnerdi. Attempt kalıcılığı AYRI bir
  kalem — kamera köprüsüyle birlikte gelir.

## 6. Bu belgenin sınırı

Delta 1'in olgusu (birim çeşitliliği) **katalogdan ölçüldü**. Delta 2 ve 3'ün
gerekçeleri bu geceki ölçümlere dayanıyor (G-091 tolerans terfisi · PRD/
UI-BRIEF sözleri) ama **kullanıcı üzerinde sınanmadı** — canlı seans yok.
Port'un kendisi test edilmiş koddur; delta ÖNERİLERİ hâlâ öneridir.
