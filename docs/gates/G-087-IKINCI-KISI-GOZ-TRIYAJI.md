# G-087 — İkinci-kişi göz triyajı: 1 asistanlı-demo, 1 ayna, 3 varyant-kirlenmesi

**Koordinatör ölçümü (M-F-167):** `num_poses=2` sondası koşuldu; `>0,3` ham
oranlı **7 aday** klip ve "ikinci poz birinci pozla paritede (0,90-0,9997)
→ leke/poster değil, GERÇEK eş-mevcut ikinci kişiler" okuması. Hüküm: gözle
sınıfla, sonra eşik sorusu gerçek zeminde sorulur.

Gözle sınıfladım (her klipten 9 kare, `ffmpeg` tile). Üç düzeltme + iki yeni
bulgu çıktı.

## DÜZELTME 1 — 7 aday değil **5**: ikisi YETİM dosya

`gravita/raw`'da **manifesti OLMAYAN 9 mp4** var ve `>0,3` çıkan iki
"push_up" adayı bu yetimlerden: `0KtrNQre5rQ` (0,65) ve `WkdXHQ74khI` (0,31).
İkisi de aslında **SQUAT klibi** (School of Calisthenics "Fix Your Squat",
Tom Merrick "Can't Squat? Fix Your Ankles") — G-057'nin uyardığı
kütüphane-karışması, kesintiye uğramış bir indirme turundan kalma
(`.info.json` bile yok).

- **Referans TEMİZ:** 9 yetimin HİÇBİRİ `landmarks/`'ta yok → fixture
  hattına girmemişler, push_up referansı yalnız 27 manifestli fixture'dan
  türedi. Doğrulandı.
- **Ama sonda onları saydı** (`raw/*.mp4` körlemesine taranıyor). Yani
  push_up havuzunun gerçek paydası 44 değil **35 manifestli klip**, ve
  **manifestli push_up kliplerinde `>0,3` aday YOK.**
- `0KtrNQre5rQ`'nun "iki kütüphanede de" görünmesi de bu: aynı dosyanın
  yetim kopyası, iki ayrı hasatta meşru varlığı değil.

**Sayım mutabakatı (benim hatam):** "79+61 klip" demiştim — `ls | wc -l`
saymışım, oysa 79 = **44 mp4 + 35 `.info.json`** ve 61 = **29 mp4 + 32
json**. Senin 44+29'un doğru; benim sayım yan-dosyaları klip sanmış.

## DÜZELTME 2 — ⚠️ görünürlük paritesi "gerçek kişi" KANITLAMIYOR: AYNA

`X0qC1k0Zi6k` (0,32 · Calisthenicmovement): **tek kişi**, ama spor salonu
**AYNALARI** karede. İkinci "poz" ayna yansıması.

**Bir ayna yansıması, landmark görünürlüğü bakımından gerçek insandan
AYIRT EDİLEMEZ** — keskin, tam, iyi aydınlatılmış bir insan figürüdür ve
0,9+ visibility verir. Yani "2. poz vis ≈ 1. poz vis → gerçek eş-mevcut
kişi" çıkarımı **ayna sınıfını dışlayamıyor.** Kıyas tabanı leke/poster'ı
eler (o tasarım işini gördü), **aynayı elemez.**

Sonda `$rawShareCaveat`'ında "ayna/poster/leke" diye uyarmıştım ama kıyas
tabanının aynayı da çözeceğini varsaymıştım — çözmüyor. Ayna ayrımı
GÖRÜNTÜ gerektiriyor (ya da yansımanın sol-sağ ters olması gibi geometrik
bir sinyal).

## Sınıflandırma — 5 gerçek aday

| klip | oran | kaynak | **sınıf** |
|---|---|---|---|
| `H1H1WKSm5CU` | **0,82** | Vast Fitness Academy | **ASİSTANLI DEMO** ✅ advisor'ın sınıfı |
| `0KtrNQre5rQ` | 0,71 | School of Calisthenics | **İKİ-KİŞİ EGZERSİZ** (ikisi de kendi üretiyor) |
| `my0tLDaWyDU` | 0,43 | Squat University | **EŞ-SUNUCU KONUŞMA** + anatomi animasyonu + barbell |
| `X0qC1k0Zi6k` | 0,32 | Calisthenicmovement | **AYNA** (tek kişi) |
| `-W19J4VR7D0` | 0,32 | FitnessFAQs | tek kişi; ikinci poz cam/ayna ya da arka plan |

### `H1H1WKSm5CU` — asistanlı demo, gözle KESİN

Eğitmen (kadın) elinde bir **çubuk/dowel** tutuyor, onu deneğin (erkek)
omurgasına dayıyor ve eliyle duruşunu yönlendiriyor. 9 karenin en az
3'ünde fiziksel temas var. Başlık da bunu söylüyor: *"PT TIPS: Correct
technique for performing the squat."*

Bu **tam olarak** advisor'ın adlandırdığı sınıf: *"koç elini kalçaya koyup
ideal hattı gösterir → öznenin KENDİ üretemeyeceği bir hedef postür."*

### `0KtrNQre5rQ` — iki-kişi egzersiz, asistanlı DEĞİL

İki sunucu **yan yana, ikisi de kendi squat'ını yapıyor.** El teması yok,
kimse kimseyi yönlendirmiyor. Asistanlı-postür riski YOK.

Ama **başka bir risk var ve bu yeni:** üretim `num_poses=1` koştuğu için
MediaPipe iki gövdeden BİRİNİ seçiyor ve hangisini seçtiği klip içinde
**değişebilir** → ölçüm "hangi bedeni ölçüyorum" sorusunu kaybediyor
(*denek-kayması*). Bu, asistanlı-postürden farklı bir bozulma kanalı.

## YENİ BULGU — 3/5 adayda **BARBELL** squat (varyant kirlenmesi)

Sonda ikinci-kişi ararken bunu tesadüfen yüzeye çıkardı: `my0tLDaWyDU`,
`X0qC1k0Zi6k` ve `-W19J4VR7D0`'da **yüklü barbell sırt squat'ı** var
(`-W19J4VR7D0` neredeyse TAMAMEN barbell; başlığı bile *"Lift More
Weight"*). `X0qC1k0Zi6k` ayrıca **tek-bacak/pistol** ve mobilite bölümü
içeriyor ("WARM UP & MOBILITY" kartı).

Havuzun adı `bodyweight_squat`. Yüklü squat'ın gövde açısı ve derinlik
mekaniği farklıdır — bu, ikinci-kişi sorunundan **bağımsız** bir
kirlenme sınıfı ve şu an hiçbir kapı sormuyor.

## YAKINSAMA — 3/5 aday, G-067'nin ZATEN işaretlediği kaynaklar

| kaynak | ikinci-kişi sondası | G-067 kimlik kapısı |
|---|---|---|
| Vast Fitness Academy | 0,82 (asistanlı demo) | **0 derin tekrar** (noSignal) |
| School of Calisthenics | 0,71 (iki kişi) | **0 derin tekrar** (noSignal) |
| FitnessFAQs | 0,32 | **tek FAIL** (r=−0,233, n=10, thinEvidence) |

**İki bağımsız sinyal aynı kaynakları gösteriyor.** Rep-FSM'in "burada
derin tekrar doğrulayamadım" demesi ile sondanın "burada ikinci kişi var"
demesi örtüşüyor — ve şimdi gözle sebebi görüyoruz: Vast Fitness'ta denek
zaten çubukla YÖNLENDİRİLİYOR (serbest tekrar yapmıyor), FitnessFAQs'ta
hareket barbell squat (bodyweight FSM'i tutmuyor, n=10 bu yüzden).

G-067'de FitnessFAQs'ın FAIL'ini "n=10, thinEvidence, güvenilir ret
sayılmaz" diye şerh düşmüştüm. **Şerh hâlâ doğru ama sebebi artık biliniyor:
örneklem ince çünkü klip bodyweight squat DEĞİL.**

## Eşik sorusu — hükmün aynen geçerli, ve şimdi gerekçesi ölçülü

Dağılım gerçekten iki-kümeli değil; **ve göz triyajı sebebini gösterdi:
`>0,3` kümesi TEK bir olguya karşılık gelmiyor** — içinde asistanlı-demo
(1), iki-kişi egzersiz (1), eş-sunucu konuşma (1), ayna (1), belirsiz (1)
var. **Tek bir `twoPoseShare` eşiği bu beş sınıfı ayırmaz**, çünkü sayı
"karede kaç gövde var"ı ölçüyor, "o gövdeler ne YAPIYOR"u ölçmüyor.

Yani eşik arayışı bu alanda **yanlış soru** olabilir: ayrım gövde SAYISINDA
değil, ikinci gövdenin **TEMAS/rol** durumunda. Bu bir öneri değil gözlem;
sınıf tanımı senin.

**6 advisor-`false` BLOKLU KALIR** — asistanlı-demo sınıfı artık yalnız
teorik değil, Gravita havuzunda **gözle doğrulanmış bir vakası var**
(`H1H1WKSm5CU`).

## Kanıt

Kareler: `scratch/triage-frames/tile_<videoId>.jpg` (9 kare/klip, ffmpeg).
Sonda raporları koordinatörde (`workspace/artifacts/second-person-*.json`).
Yetim envanteri: `gravita/raw` 44 mp4 − 35 manifest = 9 yetim, hiçbiri
`landmarks/`'ta yok.
