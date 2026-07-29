# G-071 — ders/kurs katmanı: içerik yazarken ürün tarafında bir kimlik-kapısı boşluğu bulundu

Gece paketi 2: "push_up+squat için JabLab G6 / Ostinato library deseni —
kurslar, kilitli-ders isimli gerekçelerle, validate portu."

Üretilenler: `content/library.json` · `tools/validate_library.py`
(8 değişmez + `--self-test` kapı-ateşleme sınaması).

## ⚠️ Yan bulgu (asıl kazanç) — `preconditionStatus`'un ÜRÜN tarafında OKUYANI YOKTU

Kilitli-ders gerekçelerini "ölçüme dayandır" derken squat'ın neyi
ölçebildiğini kontrol ettim ve şunu buldum:

- `rep_engine.dart:194` kimlik kapısını `config.precondition.isNotEmpty`
  koşuluyla uyguluyor — yani **koşul LİSTESİ boşsa kapı hiç kurulmuyor.**
- `bodyweight_squat` kataloğunda `precondition.status: "pending"` VE
  `conditions: []`.
- Sonuç: **üründe squat tekrarları HİÇBİR kimlik kapısı olmadan sayılır.**
  G-043'ün tam olarak kapattığı sınıf (ayakta konuşan birinin uzuv salınımı
  "tekrar" sayılması) squat'ta AÇIK.
- `preconditionDerived` getter'ı var (`movement_config.dart:440`) ama
  tüketicileri YALNIZ hasat araçları: `harvest_reps.dart:74`,
  `build_reference.dart:113` ve bir test. **Ürün yolunda tek okuyan yok.**

Yani hasat tarafı fail-closed reddederken (exit 65), ürün tarafı aynı beyanı
hiç sormuyordu. Bu, G-059'un beşinci canlılık sorusunun ("bu kapıya SORAN
var mı?") bir kez daha ateşlenmesi — ve bu kez kendi ürettiğim bir beyanda.

**Bu turda kapatılan kısım:** yeni `validate_library.py` K8 kuralı, bir
hareketin kütüphanede `status: live` olabilmesi için
`engine.precondition.status == derived` şartını koyuyor — yani beyanın
ürün tarafında **İLK tüketicisi** oldu. Bu, motorun kendi davranışını
düzeltmez (aşağıda açık kalem), ama "kimlik kapısı olmayan hareket
kullanıcıya ders olarak sunulamaz" sözünü mekanik hâle getiriyor.

**Açık kalem (koordinatöre):** motor tarafında `conditions: []` + `status:
pending` birleşiminin sessizce "kapı yok" demesi doğru mu? İki seçenek var
ve ikisi de tasarım kararı: (a) `status != derived` ise `RepEngine` hiç
tekrar üretmesin (fail-closed, hasat tarafıyla simetrik), (b) mevcut
davranış kalsın ama `camera.calibrationGate`in gerçekten bu boşluğu
kapattığı ÖLÇÜLSÜN (bugün yalnız varsayılıyor — kataloğun kendi rationale'i
"kısmi koruma sağlar" diyor, ölçüm yok). Seçmedim.

## İçerik kararları — hepsi bir ölçüme bağlı

### push_up → `status: live`, kurs `push_foundations`, 2 ders

| Ders | Durum | Dayanak |
|---|---|---|
| **Reps that count** | **AÇIK** | Üç ölçüm de canlı: kimlik ön koşulu DERIVED ve üründe aktif (`torso_angle_from_vertical>=60`, G-043 testli) · rep FSM 69/69 yeşil + replay kapısında push_up'ın **8 biriminin 8'i gerçek veride ateşleniyor, 0 ölü** · tempo eşik geçişinden değil gerçek dönüş anından ölçülüyor (G-055). `partial_rom` İSİMLİ ürün eşiği (110°) ve G-054'ten beri gerçek veride ateşleniyor. **Hiçbiri referans toleransına bağlı değil.** |
| **Body-line check** | **KİLİTLİ** | `provenance.derivedJoints: []` — **9 eklemin 9'u taban-bağlı** (G-014/G-050). Kural gerçek veride ateşleniyor ama eşik ölçümden değil VARSAYILANDAN geliyor; form NOTU vermek o varsayılanı hüküm olarak sunmak olurdu. |

`lockedReason` (kullanıcıya, İngilizce) eşik değerini değil **eksik ölçümü**
adlandırıyor (Ostinato K5 kuralı): *"...every one of the 9 joint tolerances
still sits at our default floor value, because the instructors' own measured
spread came out narrower than that floor. That means a 'good line' number
would come from our default, not from real instructors."*

### bodyweight_squat → `status: coming_soon`, kurs YOK

Üç bağımsız eksiklik, her biri tek başına kapatmaya yeter:

1. **Referans yok** — `provenance: pending_harvest`, `consensusN: 0`. 27
   hasat videosunun yalnız 4'ü uygunluk geçti, 3 eğitmenden geliyorlar ve
   üçü birbiriyle ne 14° ne 30°'de anlaşıyor (G-069/G-070).
2. **Kimlik ön koşulu türetilmemiş** — yukarıdaki yan bulgu.
3. **Hata kuralları gerçek veride hiç ateşlenmemiş** — squat için replay
   fixture'ı YOK (`replay_gate`: "fixture YOK"), yani `shallow_depth` /
   `excessive_forward_lean` / `heel_lift` / `butt_wink` kurallarının doğru
   anda ateşlendiğine dair kanıt yok.

`butt_wink` ayrıca kalıcı olarak not düşülüyor: `lumbar_flexion_proxy` derin
fleksiyonda landmark jitter riski taşıyor ve `pendingVerification`
(blueprint §4.7) — referans gelse bile notlanmaz.

## Değişmezler (8) + kapı-ateşleme sınaması

Ostinato/JabLab'dan altısı (coming_soon'da kurs yok · boş kurs yok · olmayan
kurala atıf yok · `notMeasured` dolu · kilit isimli gerekçeli · comingSoon
gerekçeli) + Gravita'ya özel ikisi:

- **K7:** `gradesFormAgainstReference: true` olan bir ders, hareketin
  `provenance.derivedJoints` listesi BOŞSA açık olamaz (G-050/G-014).
- **K8:** `status: live` hareket DERIVED ön koşul taşımak zorunda (G-043) —
  `preconditionStatus`'un ürün tarafındaki ilk tüketicisi.

Ayrıca katalog↔kütüphane kurs listesi **iki yönlü** karşılaştırılıyor (biri
diğerinde olmayan kurs iddia edemez).

**`--self-test` sekiz kuralı KASITLI ihlalle ateşliyor ve 8/8 yakalandı** —
artı "taban temiz" kontrolü (mutasyonsuz kütüphane ihlalsiz), çünkü kirli bir
tabanda "yakaladı" demek anlamsız olurdu. Hiç ateşlenmemiş kapıya güvenmek
bu defterde defalarca avlanan desendi (G-037, G-052).

## Kanıt / komutlar

```bash
python3 tools/validate_library.py             # ✅ 2 hareket · 2 ders (1 kilitli) · 8 değişmez
python3 tools/validate_library.py --self-test # ✅ 8/8 kapı ateşlendi
```

Dosyalar: `content/library.json` · `tools/validate_library.py`.
Kaynaklar: `content/catalog/w1/{push_up,bodyweight_squat}.json` (provenance +
formErrors + precondition) · `docs/W0-BILGI-MIMARISI.md §1-3` · G-043 · G-050 ·
G-054/055 · G-059 · G-069/G-070.
