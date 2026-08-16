# G-123 — Pull-Up Kimlik Kapısı: TASARIM (eşik DEĞİL)

**Tarih:** 2026-08-16 · **Kapsam:** hasat turu-1 kapı-tasarımı bacağı, ikinci hareket —
orkestratörün yöntemsel önerisiyle KASITLI seçildi: *"lunge değil, pull_up (ya da dip) —
squat ailesine YAKIN değil, MAKSİMUM farklı. Yaklaşımın kırılacaksa orada kırılır, ve
erken kırılması iyidir."* **Girdi:** yalnız `gravita_engine` kaynağı +
`content/catalog/w1/pull_up.json`'ın kendi mevcut alanları + G-121'in (glute_bridge)
kendi tasarım deneyimi. Hiçbir hasat adayına bakılmadı.

## 0 · Bu dosyanın ÇÖZMEDİĞİ şey — G-121'le aynı sınır

`pull_up.json`'ın rationale'ı BİREBİR aynı şablon uyarıyı taşıyor: *"Eşik BURADA
UYDURULMAZ (G-014/G-050)."* Bu dosya sayı ÖNERMİYOR.

## 1 · Kapının çözmesi gereken gerçek risk

Motor bugün `elbow` açısının `hang(≥160°)→top(≤75°)` salınımını sayıyor
(`pull_up.json:29-48`). Aynı kusur sınıfı (G-043): **bu salınımı BAŞKA bir bağlam da
üretebilir** — en olası aday, AYAKTA/OTURARAK yapılan bir dirsek-fleksiyon hareketi
(biceps curl, lastikle çekiş) — bunlar da dirseği ~160°'den ~75°'ye kadar aynı yönde
kıvırır.

## 2 · İLK REFLEKS ELENDİ — kendi yöntemimin sınırını buldum

G-121'de (glute_bridge) VE push_up'ta iş gören araç `torso_angle_from_vertical`di:
"yerde mi ayakta mı" ayrımı temiz çalışıyordu çünkü ikisi de YATAY/DİKEY karşıtlığı
taşıyordu. **Burada TAŞINMIYOR** — ve bunu ölçmeden, yalnız akıl yürüterek görebiliyorum:

**Pull-up'ta gövde DİKEYDİR** (asılı, düz aşağı sarkar) — `torso_angle_from_vertical`
DÜŞÜK okur, tıpkı AYAKTA duran bir insan gibi. Bir standing biceps curl da DİKEY bir
gövdedir. **İki durum da aynı okur — bu metrik SIFIR ayırt edicilik taşır.**

> ***BİR ARACIN İKİ HAREKETTE İŞ GÖRMESİ, ÜÇÜNCÜDE DE İŞ GÖRECEĞİNİ KANITLAMAZ — VE
> BUNU KEŞFETMENİN EN UCUZ YOLU, ARACI EN FARKLI VAKAYA UYGULAMAK VE İZLEMEKTİR.***

Bu, G-121'in kendi ilkesinin (§2, "kanıtlanmış mekanizmayı taşımak kinematik temeli
kanıtlamaz") kendi üstünde ikinci kez doğrulanmasıdır — orkestratörün öngördüğü tam an.

## 3 · Önerilen yaklaşım — `shoulder_angle`, YENİ bir metrik seçimi

`MovementMetrics.shoulderAngle` (`metrics.dart:70`, `hip–shoulder–elbow` üç noktalı iç
açı) bugüne dek hiçbir kimlik kapısında KULLANILMADI (push_up: `torso_angle_from_
vertical` · squat: `hip`/`knee` pencere-korelasyonu · glute_bridge: `torso_angle_from_
vertical`) — burada İLK KEZ öneriliyor, çünkü pull-up'ın kendine özgü yapısal imzası
BUDUR: **asılma anında kol TAM YUKARIDA** (omuz-kalça hattının UZANTISINDA veya ona
yakın) — bu, `hip–shoulder–elbow` açısını BÜYÜK (düzleşmiş/geniş) yapar. Standing biceps
curl'de kol YANDA sarkar (dirsek kalça hizasına yakın) — aynı açı KÜÇÜK kalır (kol
gövdeye katlanmış).

**Önerilen çerçeve** (eşik yer tutucu):

```json
"precondition": {
  "status": "pending",
  "conditions": [
    { "metric": "shoulder_angle", "op": ">=", "value": "<HASAT ÖLÇÜMÜNDEN>" }
  ]
}
```

Mekanizma AYNI (`MetricCondition`, `precondition.conditions[]`) — SEÇİLEN metrik farklı,
çünkü hareketin kendi kinematiği farklı. Bu, G-121 §2'nin olumlu yüzünün burada tekrarı:
push_up'ın ROLÜNÜ (bağlamı doğrulayan tek koşul) alıp KAYNAĞINI (hangi ölçü) hareketin
kendi anatomisinden yeniden türetmek.

## 4 · Adıyla bırakılan risk — YENİ bir sınıf, glute_bridge'inkinden FARKLI

G-121'in riski "aynı aralık, farklı bağlam" sınıfıydaydı (ayaktaki eğilme de benzer açı
ÜRETİR). Buradaki risk BAŞKA bir sınıf: **"aynı UÇ DURUM, farklı hareket."** Ayakta bir
**omuz üstü itiş (overhead press)** hareketinin ÜST noktasında da kol yukarıda olur —
`shoulder_angle` orada da BÜYÜK okuyabilir. Fark potansiyel olarak FAZ YÖNÜNDE saklı:
pull-up dirseği `hang(açık)→top(kapalı)` gider (`repCountedOn: "top->hang"`), omuz üstü
itiş muhtemelen TERS yönde (dirsek kapalı başlar, açılarak biter) — motorun kendi faz-
yönü mantığı (`descent`/`ascent` `direction` alanları, `rep_engine.dart`) bu ikisini
zaten AYIRABİLİR, ama bu bir ÖLÇÜM DEĞİL bir ÇIKARIM. **Hasat turu-1 bunu doğrulamalı,
varsaymamalı.**

## 5 · Hasat turu-1'in bu kapıyı kapatmak için ÖLÇMESİ gereken şey

1. Gerçek pull-up tekrarlarında `shoulder_angle`in `hang`/`top` fazlarındaki dağılımı.
2. KARŞIT örnek-1: standing biceps curl (negatif kontrol, hasat hedefi değil) —
   beklenen: sürekli düşük `shoulder_angle`.
3. KARŞIT örnek-2: standing overhead press (negatif kontrol) — beklenen: fazın YÖNÜ
   pull-up'ınkinden ters, ama `shoulder_angle`in KENDİSİ benzer üst değerlere
   ulaşabilir — bu örnek §4'ün varsayımını (faz-yönü ayırt eder) DOĞRUDAN sınar.
4. Üç dağılım ayrışmıyorsa, faz-yönü TEK BAŞINA yeterli değildir ve ikinci bir kapı
   (aday: kolun `hang` fazında GERÇEKTEN düz olması, `elbow_angle` alt sınırı zaten
   `rom_bottom_angle` formError'ında var ama PRECONDITION'a taşınmamış) gerekebilir.

## 6 · Kapsam dışı, adıyla

- `hip_swing_amplitude_torso` (kipping-swing formError'ı, `pull_up.json:127-145`) —
  araştırma sırasında bu metriğin `MovementMetrics.unimplemented` listesinde olduğu
  görüldü (henüz KODLANMADI, yalnız içerikte adı var). Bu kimlik kapısının parçası
  DEĞİL (o formError, o AYRI bir konu) ama adıyla not ediyorum: bu hareket canlıya
  çıkmadan önce bu metrik ya kodlanmalı ya da formError'ı adıyla kilitli kalmalı —
  bu turun kapsamı değil, gelecekteki bir "kod" kuyruğu kalemi.
- Pencere-korelasyonu (squat deseni) burada da düşünülmedi — pull-up'ın tek sinyali
  `elbow`, ikinci bir eklemle korelasyon aranacak biyomekanik gerekçe YOK (glute_
  bridge'deki gerekçenin aynısı, tekrar yazılmadı).

---

**Hipotez defterine eklendi:** `docs/gates/G-122-HASAT-TURU1-HIPOTEZ-DEFTERI.md` H2.
