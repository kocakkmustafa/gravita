# G-072 — M-F-120 uygulandı: doktrin ailede ZATEN VARDI, Gravita BAYAT aletle ölçüyordu

**Koordinatör hükmü (M-F-120):** M-F-113 iptal; cevap seçenek 4 = M-F-45/62'nin
sınıf-düzeyi doktrinini rig'e uygulamak. rep-sınıfı hareketler YAPISAL-AKTİF
(kimse birine pasif şınav/squat yaptıramaz) → o sınıfta `romMode` metin-kanıtı
uygunluk ŞARTI değil; pasif-YETENEKLİ sınıflarda fail-closed aynen kalır.

## En önemli bulgu: KOD YAZMAK GEREKMEDİ

Hüküm "rig uygunluk hesabına `activityClass` boyutu ekle" diyordu. Rig'i
okudum ve mekanizma **zaten tam olarak orada**:

- `rom_mode.classify(..., passive_execution_possible: bool)` — `False` ise
  `unknown` verdict'i UYGUN sayıyor, gerekçesi kelimesi kelimesine M-F-45:
  *"pasif icra bu harekette biyomekanik olarak MÜMKÜN DEĞİL — tehdit yapısal
  olarak yok, referansa girebilir (M-F-45)"*.
- `harvest.load_rom_policy(profile, movement)` — bunu triyaj profilinin
  `movementRomPolicy` blokundan okuyor; hareket blokta yoksa **sert hata**
  ("sessizce varsayılana düşmek kuralın hangi harekette uygulandığını
  belirsizleştirir").

**Yani çekirdekte hiçbir değişiklik gerekmedi — dal/merge de gerekmedi.**
Sorun şuydu: Gravita'nın hasadı `scratch/2026-07-29-gravita-harvest/tools/
harvest_rig/` altındaki **BAYAT bir rig kopyasıyla** koşmuştu ve o kopyada
`passive_execution_possible` HİÇ YOK (grep: 0 eşleşme). Ayrıca Gravita'nın
triyaj profilinde `movementRomPolicy` bloku hiç yoktu.

> **Yeni bulgu sınıfı: paylaşımlı bir aracın scratch kopyası sessizce
> bayatlar ve ESKİ KURALI uygular.** Ürettiği çıktı geçerli görünür (fixture
> provenance'ı düzgün, `referenceEligible: false` dürüstçe yazılmış) —
> yalnız kural bir sürüm gerisindendir. Bu, gecenin "bir sabit beyan
> etmediği bir şeye bağlıysa yalan söyler" dersinin araç-sürümü hâli.

## Uygulama

1. **`content/harvest/triage-profile.gravita.v2.json`** → `movementRomPolicy`
   (20 hareket, hepsi AÇIKÇA listeli). `false` YALNIZ **push_up** ve
   **bodyweight_squat**'ta.
   *Neden 20'sinin hepsi değil:* hüküm rep-FSM sınıfını structurally-active
   ilan ediyor, ama bu profildeki 14 rep-FSM hareketinin hepsi aynı derecede
   açık DEĞİL — `dead_bug`/`bird_dog` gibi sırtüstü/dörtayak düşük-yüklü
   motor-kontrol drillerini bir klinisyen gevşek uzuvla yürütebilir, yani
   orada muafiyet kapıyı GEVŞETİR. Muafiyet hasadı yapılan ve hükmü
   tartışmasız olan ikisine verildi. Kalan 12 rep-FSM + `burpee` + 5 statik
   tutuş **isimli açık kalem** (hasat sırası gelmeden `movement-science-advisor`
   ikinci gözüyle hareket-başına hüküm).
2. **`tools/reclassify_eligibility.py`** (yeni) — ham video YENİDEN
   İNDİRMEDEN, manifest `title`/`description`'ından uygunluğu yeniden
   hesaplar. **Kendi sınıflandırma mantığı YOK:** kanonik rig'in
   `rom_mode.classify()`'ını çağırır (rig `origin/main@e882a96`'dan scratch'e
   materyalize edildi, SHA kayıtlı). Bayat kopyaya karşı kendi nöbetçisi var
   (`FIRST_PERSON_DEMO_MARKERS` yoksa reddeder).
3. **`canonical_push_up_reference.dart`** — bilinçli bayrak-düşürmesi
   KALDIRILDI; `referenceEligible`/`romMode` artık ham fixture'dan BİREBİR
   korunuyor. İki araç tek disiplin (G-070'in zıt-disiplin bulgusu kapandı).

## Ölçüm: iki etki AYRI ölçüldü (`--pep-override` kontrolü)

Uygunluk artışını tek etkiye yazmamak için kontrol koşumu eklendi:

| Hareket | başlangıç | yalnız KANONİK sınıflandırıcı | + M-F-120 muafiyeti |
|---|---|---|---|
| bodyweight_squat | 4 uygun | **4** (değişmedi) | **28** |
| push_up | 1 uygun | **2** | **35** |

- **Squat'ta artışın TAMAMI muafiyetten.** Kanonik sınıflandırıcı tek başına
  hiçbir uygunluk değiştirmiyor (3 manifestin *modu* değişiyor, uygunluğu
  değişmiyor).
- **push_up'ta 1 klip kanonik sınıflandırıcının kendi düzeltmesi:**
  *Cara Kuykens* bayat rigde `passive`, kanonikte `active` — yani bayat rig
  onu **YANLIŞ YERE dışlıyordu** (WEAK_PASSIVE ayrımı + J-058 birinci-şahıs
  sınıfı). Sahte-pasif bir ret.
- **Kapı hâlâ ISIRIYOR:** `romMode: passive` olan kaynaklar (squat'ta GMB
  Fitness, push_up'ta 2 klip) muafiyete RAĞMEN uygun değil. Muafiyet yalnız
  *kanıt-yokluğunu* kurtarıyor, *pasif kanıtını* değil — doktrinin tam da
  istediği davranış.

## Sonuç 1 — squat: M-F-47 İLK KEZ meşru havuzda soruldu ve KÜMELENDİ

Uygunluk düzeltmesinden sonra **233 take / 12 kaynak** kapıya ulaşıyor
(önce: 100 take / 3 kaynak; 133'ü kapıya hiç varmıyordu — G-070).

**`clusterToleranceDeg=14°` (varsayılan) ile KÜMELENDİ — genişletme
GEREKMEDİ.** Ailenin **ÜÇÜNCÜ ürün referansı** yayımlandı:

| | değer |
|---|---|
| `measurementProvenance` | **ATTESTED** |
| contributingTakes / distinctSources | **36 / 6** |
| excludedOutlierIds | 197 (adlarıyla) |
| katkı veren kaynaklar | Jeff Nippard · Jeremy Ethier · K boges · **Strength Side** · **THENX** · WeShape |
| meanAgreement | 0,685 |
| cycleSegmentation | notApplied (7/233 periyodik — azınlık, dürüst) |
| `unreliableJoints` | left/right elbow + forearm |

⚠️ **M-F-113 uygulanmış olsaydı HATA olurdu:** kaynak-düzeyinde dışlanması
istenen **Strength Side ve THENX, kümenin İÇİNDE** — katkı veren 6 kaynaktan
ikisi. G-069'un "bu 3 kaynak aykırı" teşhisi tamamen yanlıştı; aykırılık
uygunluk-katmanının havuzu 3 kaynağa indirmesinin bir eseriydi.

### Ama squat referansı BACAKLARI notlayamaz (dürüstlük kaydı)

Tolerans kaynağı: **9 varyans / 8 taban** (taraf başına) → çift düzeyinde
`derivedJoints: [elbow, forearm, shoulder, upper_arm]`,
`floorBoundJoints: [hip, knee, shin, thigh, trunk_tilt]`.

**Varyans-türetimli olanların hepsi KOL; squat'ın notlayacağı her eklem
(kalça/diz/baldır/uyluk/gövde) TABAN-bağlı.** Üstelik elbow/forearm ayrıca
`unreliableJoints`. Yani referans var ve attested, ama squat derinliği ya da
gövde eğimi hâlâ ölçülmüş eğitmen-varyansına dayanmıyor.

**`mirrorAgnostic: FALSE` — ölçülen sol-sağ farkı 32,26°** (push_up: 5,16°).
Squat'ta yandan çekimde yakın bacak uzağı kapatıyor; G-061'in
kneeAngleAsymmetry bulgusunun (6°-50°) referans düzeyindeki karşılığı.
M-F-46 kural 7 gereği **bu referanstan TARAF-BAĞLI hiçbir hüküm çıkarılamaz**
— eksik ölçüm değil, yapısal olarak yok.

## Sonuç 2 — push_up: PROVISIONAL → **ATTESTED** terfisi

Aynı malzeme, dürüst attestation ile yeniden türetildi:

| | eski | yeni |
|---|---|---|
| `measurementProvenance` | PROVISIONAL | **ATTESTED** |
| contributingTakes / distinctSources | 36 / 5 | **36 / 5** |
| `derivedJoints` (çift) | [] | **[]** (değişmedi) |
| mirrorAgnostic | true (5,03°) | **true (5,16°)** — 6. bağımsız doğrulama |

Artefakt **geri çekilmedi, provenance'ı YÜKSELDİ** (koordinatörün öngördüğü
gibi). Taraf-başına dağılım kaydı: 6 eklem `variance`→`floor`, 1 eklem
`floor`→`variance` (havuz kompozisyonu 2 `passive` kaynağın çıkmasıyla
değişti) — **ama çift düzeyinde zayıf-halka kuralı (M-F-95) sonucu
DEĞİŞTİRMİYOR: `derivedJoints` yine boş, G-014 yine açık.** Yani ders
katmanının "Body-line check KİLİTLİ" hükmü aynen geçerli kalıyor.

⚠️ İki eksen karıştırılmasın: artefakt `ATTESTED` (kaynak uygunluğu) iken
katalog `harvested_provisional` (tolerans dayanağı). İkisi farklı soru ve
ikisi de doğru.

## Sonuç 3 — kendi kapımda delik buldum: K7 vekil ölçüyordu

G-071'de yazdığım K7 kuralı şunu soruyordu: *"`derivedJoints` BOŞ mu?"*
push_up'ta boş olduğu için doğru çalışıyor görünüyordu. **Squat referansı
üretilince delik ortaya çıktı:** squat'ın `derivedJoints`i boş DEĞİL
(4 kol eklemi) — yani K7'nin eski hâli, bacakları notlayan bir squat form
dersinin AÇIK olmasına izin verirdi. Kol eklemlerinde varyans olması,
bacaklarda hüküm kurma yetkisi vermez.

**"Bir yerde varyans var" sorusu, "NOTLADIĞIM yerde varyans var mı"
sorusunun yerine geçemez** — vekil ölçen kapı sınıfı hata; bu defterin gece
boyu avladığı desenin ta kendisi, bu kez benim kendi kapımda.

Düzeltme: ders artık `gradedJoints` ile notladığı eklemleri BEYAN eder; K7
(a) beyanın varlığını, (b) `gradedJoints ⊆ derivedJoints`, (c)
`gradedJoints ∩ unreliableJoints = ∅` denetler. Üç dal da kasıtlı ihlalle
ateşlendi (`--self-test`: **10/10**).

## Ders katmanı güncellendi (bayat iddia bırakılmadı)

- **push_up:** honesty metni "attested referans var AMA 9 eklemin 9'u
  taban-bağlı" olarak düzeltildi; "Body-line check" KİLİTLİ kalıyor,
  `gradedJoints: [shoulder, hip, trunk_tilt, upper_arm]` beyan edildi.
- **bodyweight_squat:** `coming_soon` KALIYOR ama gerekçe **3'ten 2'ye
  düştü** — "referans yok" maddesi artık YALAN olurdu, kaldırıldı. Kalan
  iki blokaj: kimlik ön koşulu `pending` (K8) + hata kuralları gerçek veride
  hiç ateşlenmemiş (replay fixture yok). Yeni iki dürüstlük maddesi eklendi:
  bacak eklemlerinin taban-bağlı olduğu ve `mirrorAgnostic: false` yüzünden
  sol/sağ geri bildiriminin **yapısal olarak** yok olduğu.

## Kapılar

`dart analyze` temiz · **69/69** test · replay **0 ölü** ·
`validate_catalog.py` **0 hata** (29 uyarı) · `validate_library.py` temiz ·
`--self-test` **10/10 kapı ateşlendi**.

## Kanıt / komutlar

```bash
# uygunluk yeniden sınıflandırma (kuru koşum + etki ayrıştırma kontrolü)
python3 tools/reclassify_eligibility.py --library ~/motion-harvest/gravita-squat \
    --movement bodyweight_squat
python3 tools/reclassify_eligibility.py --library ~/motion-harvest/gravita-squat \
    --movement bodyweight_squat --pep-override true      # yalnız sınıflandırıcı etkisi
python3 tools/reclassify_eligibility.py --library ~/motion-harvest/gravita-squat \
    --movement bodyweight_squat --apply
python3 tools/reclassify_eligibility.py --library ~/motion-harvest/gravita \
    --movement push_up --apply

cd packages/gravita_engine
dart run tool/slice_deep_reps_squat.dart          # dilimleri yeni provenance'la yenile
dart run tool/diag_squat_eligibility.dart         # 233 take / 12 kaynak, 0 ineligible
dart run tool/canonical_squat_reference.dart      # ÜÇÜNCÜ referans, 14°'de kümelendi
dart run tool/canonical_push_up_reference.dart    # PROVISIONAL → ATTESTED
cd ../.. && python3 tools/sync_provenance.py && python3 tools/validate_catalog.py
python3 tools/validate_library.py --self-test
```

Kanonik rig: `origin/main@e882a96` → `scratch/2026-07-30-rig-canonical/`
(`RIG_SHA.txt`). Koşum kaydı: `scratch/g069-rerun.log`.

## Koordinatöre açık kalemler

1. **Kalan 18 hareketin `movementRomPolicy` hükmü** — 12 rep-FSM + burpee +
   5 statik tutuş; hasat sırası gelmeden hareket-başına biyomekanik hüküm
   gerekiyor (`movement-science-advisor`). Sessizce `false`a çevirmedim.
2. **Bayat-kopya sınıfı** — Gravita'nın scratch rig kopyası bir sürüm
   gerisindeydi. Aile genelinde başka app'lerin de scratch kopyaları varsa
   aynı risk taşıyorlar; bir "aracın SHA'sını çıktıya damgala" kuralı
   (M-F-07 köken alanlarının araç-sürümü karşılığı) işe yarar mı? Öneri,
   karar sende.
3. **G-071'in motor kararı hâlâ açık** — `conditions:[]` + `status:pending`
   sessizce "kapı yok" demeli mi (a: RepEngine fail-closed / b: mevcut kalsın
   ama `camera.calibrationGate` ölçülsün).
