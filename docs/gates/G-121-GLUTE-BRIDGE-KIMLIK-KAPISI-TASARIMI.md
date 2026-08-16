# G-121 — Glute Bridge Kimlik Kapısı: TASARIM (eşik DEĞİL)

**Tarih:** 2026-08-16 · **Kapsam:** F3 hasat turu-1'in kapı-tasarımı bacağı (orkestratör
onayı, `motion-core` M-F-651/H-45 zinciri) · **Girdi:** yalnız `gravita_engine` kaynak
kodu + `content/catalog/w1/glute_bridge.json`'ın kendi mevcut alanları + push_up/
bodyweight_squat'ın ZATEN KAPANMIŞ kimlik-kapısı emsali. **Hiçbir hasat adayı video/
transkriptine bakılmadı** (F3 Faz-0'ın kendi dondurma şartı, `docs/F3-HASAT-OLCUTLERI-
DONDURULMUS.md` §2 madde 4).

## 0 · Bu dosyanın ÇÖZMEDİĞİ şey — adıyla

`glute_bridge.json`'ın kendi `precondition.rationale`'ı (muhtemelen `tools/
name_preconditions.py` tarafından üretilmiş şablon metin) zaten şart koşuyor: *"Eşik
BURADA UYDURULMAZ (G-014/G-050): taban değeri varsayılandır, ölçüm değil."* Bu dosya o
kuralı ÇİĞNEMİYOR — **sayısal bir eşik ÖNERMİYOR.** Önerdiği şey: hangi ÖLÇÜNÜN üstüne
kurulacağı, o ölçünün NEDEN doğru seçim olduğu, ve NEDEN squat'ın kendi deseni buraya
KÖRÜ KÖRÜNE taşınamayacağı. Eşiğin kendisi hasat turu-1'in GERÇEK ölçümünden gelecek
(bkz. §4).

## 1 · Kapının çözmesi gereken gerçek risk

Motor bugün `hip` eklem açısının `bottom(≤110°)→top(≥165°)` salınımını sayıyor —
`glute_bridge.json:22-42`. Ama **sinyalin kendisi kimlik değildir** (dosyanın kendi
rationale'ı, G-043'ün push_up'taki emsaline atıfla): aynı açı-salınımını BAŞKA bir
hareket de üretebilir. Somut risk: **ayakta derin bir kalça-menteşesi hareketi**
(örn. "good morning", derin eğilme) kalça açısını 110°-165° aralığında GEÇEBİLİR —
motor bunun sırtüstü mü ayakta mı yapıldığını `hip_angle`in kendisinden BİLEMEZ, çünkü
bu metrik yalnız üç noktalı bir iç açı (omuz-kalça-diz), vücudun mekân içindeki
yönelimini taşımaz.

Bu, push_up'ın kendi G-043 dersinin BİREBİR aynası: *"ayakta el hareketi şınav tekrarı
SAYILMAZ"* — orada gövde açısı bu riski kapatmıştı (`torso_angle_from_vertical >= 60`).

## 2 · REDDEDİLEN yaklaşım — squat'ın hip-knee korelasyonu buraya TAŞINMAZ

Squat'ın kapısı (`bodyweight_squat.json`): `Pearson(hip, knee) >= 0.2` — kalça VE diz
BİRLİKTE fleksiyona gider, bu korelasyon GERÇEK squat'ın imzasıdır.

**Glute bridge'de bu yanlış temel:** hareketin kendi tanımı (`glute_bridge.json:23-27`,
sinyal eklemi YALNIZ `hip`) ve `formErrors`i (`incomplete_extension`, `hip_angle`
üzerinden) diz açısının SABİT kalmasını (~90°, ayaklar yerde) VARSAYAR — yalnız kalça
açısı salınır. Squat'ın deseni burada iki sebepten çalışmaz:

1. **Biyomekanik temel yok:** diz'in kalça ile birlikte DEĞİŞMESİ beklenmiyor; iyi bir
   glute bridge'de diz açısı NEREDEYSE SABİT kalmalı. Yüksek bir korelasyon eşiği
   koymak GERÇEK, doğru yapılan tekrarları REDDEDER.
2. **Düşük korelasyon POZİTİF bir imza DEĞİL:** "korelasyon ≈ 0" hem "diz gerçekten
   sabit kaldı" hem de "iz/gürültü hiç anlamlı sinyal taşımıyor" durumunda AYNI okur —
   biri doğru hareketin imzası, öteki izleme başarısızlığı. İkisini ayırt edemeyen bir
   eşik, ayırt edici değildir.

> ***BİR KARDEŞ HAREKETİN KAPISINI KOPYALAMAK, YALNIZ AYNI MOTOR MEKANİZMASINI
> KULLANDIĞI İÇİN DEĞİL, AYNI BİYOMEKANİK TEMELİ PAYLAŞTIĞI İÇİN MEŞRUDUR — VE BU
> İKİSİ AYRI ŞEYDİR.***

## 3 · Önerilen yaklaşım — `torso_angle_from_vertical`, push_up'ın ROLÜNDE ama farklı KARAKTERDE

`MovementMetrics.torsoAngleFromVertical` (`gravita_engine/lib/src/metrics.dart:97-103`)
zaten var, `MetricCondition` ile `precondition.conditions[]`e doğrudan yazılabilir
(push_up'ın kullandığı BİREBİR mekanizma, `movement_config.dart:190-212`) — yeni bir
metrik icat ETMİYORUM.

**Önerilen çerçeve/koşul biçimi** (eşik `<TÜR>` yer tutucu, §4'te ölçülecek):

```json
"precondition": {
  "status": "pending",
  "conditions": [
    { "metric": "torso_angle_from_vertical", "op": ">=", "value": "<HASAT ÖLÇÜMÜNDEN>" }
  ]
}
```

**Neden bu doğru ROL ama farklı KARAKTER:** push_up'ta bu açı hareketin İÇİNDE dinamik
bir ayırt edici (durma/şınav arasında salınmaz, ama şınav gövdesi zaten sabit yatay —
asıl iş ayaktaki insanı REDDETMEK). Glute bridge'de de AYNI iş: sırtüstü yatan gövdeyi
ayaktaki bir gövdeden ayırmak — ama bu açı REP BOYUNCA neredeyse SABİT kalacak (omuzlar
yerde sabit, yalnız kalça kalkıyor), yani dinamik bir sinyal değil, TEK SEFERLİK bir
"pozisyon doğru mu" kapısı. Bu bir ZAYIFLIK değil — dosyanın kendi motoru zaten `hip`i
DİNAMİK sinyal olarak kullanıyor; bu kapının işi yalnız BAĞLAMI doğrulamak.

**⚠️ Adıyla bırakılan risk (ölçülmeden çözülemez):** derin bir ayakta kalça-menteşesi de
gövdeyi ANLIK olarak yataya YAKLAŞTIRABİLİR. Bu koşul TEK BAŞINA bu riski tam
KAPATMAYABİLİR — push_up'ın kendi G1 ölçümü de (`docs/gates/` ailesindeki "eksen
terslemesi" bulgusu, motion-core tarafı) biyomekanik akıl yürütmenin ÖNGÖREMEDİĞİ bir
kusur sınıfı bulmuştu. **Bu satırın kendisi, hasat turu-1'in gerçek footage'ıyla test
edilmesi gereken bir HİPOTEZ, kapanmış bir hüküm DEĞİL.**

## 4 · Hasat turu-1'in bu kapıyı kapatmak için ÖLÇMESİ gereken şey

`status: pending` kalır ta ki:

1. **Gerçek glute bridge tekrarlarında** `torso_angle_from_vertical`in dağılımı ölçülsün
   (≥3 bağımsız eğitmen, `F3-HASAT-OLCUTLERI-DONDURULMUS.md` §1) — beklenen: dar, yüksek
   bir bant (sürekli sırtüstü).
2. **Mümkünse bir KARŞIT örnek** (ayakta kalça-menteşesi/eğilme footage'ı, hasat
   HEDEFİ değil ama negatif kontrol için) — beklenen: DAHA DÜŞÜK ve/veya DAHA GENİŞ
   dağılım. İki dağılım net ayrışmıyorsa (§3'teki risk gerçekleşirse), bu koşul TEK
   BAŞINA yeterli DEĞİLDİR ve ikinci bir sinyal (adayı: `knee_angle` üstünde bir ÜST
   sınır, "diz aşırı düz DEĞİL" — feet-planted varsayımını doğrudan sınayan bir kapı)
   ayrıca tasarlanmalı.
3. Eşik iki dağılımın ARASINDAN, push_up/squat'ın kendi eşiklerinin türetildiği
   yöntemle (ölçülmüş ayrışma noktası, varsayılan/yuvarlak sayı DEĞİL) seçilir.
4. Ölçüm tamamlanınca `status: "derived"`e çevrilir, `conditions[].value` gerçek
   sayıyla doldurulur, `tools/name_preconditions.py` rationale metnini YENİDEN üretir
   (elle yazılmaz — dosyanın kendi kuralı).

## 5 · Kapsam dışı bırakılan, adıyla

- **`knee_angle` üst-sınır kapısı** (§3'teki karşıt-örnek riski gerçekleşirse gereken
  ikinci sinyal) — bu turda TASARLANMADI, yalnız ADI konuldu. Motor bunu
  `precondition.conditions[]`e ikinci bir `MetricCondition` olarak destekler
  (birden fazla koşul VE'lenir, `rep_engine.dart:375-395`) — mekanik engel yok, yalnız
  gerekliliği ölçülmedi.
- **Pencere-korelasyonu (`windowCondition`) mekanizması** genel olarak KULLANILABİLİR
  (`RepEngine`'in her `repFsm` hareketi için çalışır) ama bu hareket için biyomekanik
  gerekçesi YOK (§2) — ileride başka bir amaç için (örn. sol-sağ simetri) gerekirse ayrı
  değerlendirilir, bu turun kapsamı değil.
- **`camera.setup: "side"` alanı** motor tarafından hiç OKUNMUYOR (yalnız içerik/çekim
  talimatı, `movement_config.dart:454,488` — hiçbir engine kodunda dallanmıyor) — bu
  kapının GÜVENCESİ değil, insan çekim rehberidir. Karıştırılmasın diye adıyla not
  edildi.

---

**Sonraki adım:** bu tasarım orkestratöre raporlanacak (fiilî hasada geçmeden önce
onay istendiği gibi). Onay sonrası hasat turu-1'in ilk fiilî işi §4'ün ölçüm protokolü
olacak — ki bu, F3 Faz-0'ın kendi sınırının (ölçütler donmuş, aday görülmeden) bittiği
ve gerçek hasadın başladığı nokta.
