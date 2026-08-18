# PREP — 31 Katalog Öğesi A/B/C/D Sınıflandırma Analizi (2026-08-19)

**Oturum:** GRAVITA (PREP lane) · **Kapsam:** okuma + analiz, kod/içerik değişikliği YOK · **Kaynak otorite:** `content/schema/movement-classes.json` (kurucu-onaylı, `docs/GRAVITA-BLUEPRINT.md` §1)

## 0. Kritik ön-bulgu: roadmap ile repo şeması AYNI HARFLERİ FARKLI TANIMLIYOR

`22-GRAVITA-MASTER-ROADMAP.md` §4'ün A/B/C/D tanımı ile `content/schema/movement-classes.json`'un tanımı **kavramsal olarak farklı eksenler**:

| | Roadmap §4 (üst otorite) | `movement-classes.json` (repo, kurucu-onaylı, canlı uygulanan) |
|---|---|---|
| A | rep/phase/tempo + **doğrulanmış** form cue | Açık-zincir, kamera **geometrisi** form hükmüne izin veriyor mu (doğrulanmış olsun/olmasın) |
| B | rep/tempo/setup; form hükmü yok | Sırtüstü/yüzüstü VEYA derinlik-ekseni kesişimi → foreshortening |
| C | program ve manuel log; kamera sonucu yok | **Makine-kılavuzlu** — kataloğa bile girmiyor (`exclusions.json`'a gider) |
| D | ürün dışı/açıklamalı içerik | Prop/nesne takibi gerektirir (kutu, ip, bant, bar) — gövde koçlanır, prop koçlanmaz |

Roadmap'in "A" tanımı **doğrulama durumunu** sınıfın içine gömüyor; repo şeması sınıfı yalnız **kamera-geometrisi** olarak tanımlıyor ve doğrulama durumunu AYRI bir eksende (`provenance.status`, `engine.precondition.status`) tutuyor. Bu, protokol §13'ün "roadmap satırları doğrulanmamış varsayımdır" ilkesinin bir örneği — **sayısal bir sapma değil, tanımsal bir sapma**. Bu raporun geri kalanı repo şemasını (canlı, uygulanan) esas alıyor; roadmap'in "A/B/C/D" sözü geçen her yerini okuyan oturum bu ayrımı bilmeli. Karar gerektiren bir çelişki değil (ikisi de tutarlı, farklı sorulara cevap veriyor) ama isimlendirme çakışması kafa karıştırabilir — orkestratöre bu raporla birlikte bildiriliyor.

## 1. Baseline doğrulama (ölçülmüş, iddia değil)

- `content/library.json`: **31 hareket**, `status:"live"` yalnız **`bodyweight_squat`** ve **`push_up`** — roadmap'in "31 katalog hareketi; squat ve push-up canlı" iddiası **DOĞRULANDI**.
- Ama "live" ölçüm-katmanlı: squat'ın rep-sayımı canlı, form-notu dersi (`depth_and_lean_check`) **`lockClass:"measurement"`** ile KİLİTLİ (knee/shin/trunk_tilt eklemleri `derivedJoints` dışında — bkz. DEFTER G-096/G-071). "Live" ≠ "her ders açık" — bu ayrım kullanıcı yüzeyinde zaten dürüstçe taşınıyor (`honesty.notMeasured`).
- **Sınıflandırma katmanı 31/31 TAMAM:** her hareketin `content/catalog/w1|w2/*.json` dosyasında `class` + `classRationale` + `camera.setup` dolu. Bu PREP görevinin "sıfırdan sınıf ata" değil "mevcut atamayı denetle" olması gerektiği anlamına geliyor.

## 2. Tam tablo (31/31, `content/catalog/w1,w2/*.json`'dan üretildi)

| id | wave | family | class | camera | engine | precondition | provenance |
|---|---|---|---|---|---|---|---|
| bodyweight_squat | 1 | legs | A | side45 | repFsm | **derived** | harvested_provisional (n=5) |
| push_up | 1 | push | A | side45 | repFsm | **derived** | harvested_provisional (n=5) |
| bird_dog | 1 | core | A | side | repFsm | pending | pending_harvest |
| burpee | 1 | plyo | A | side45 | multiPhaseFsm | pending | pending_harvest |
| calf_raise | 1 | legs | A | side | repFsm | pending | pending_harvest |
| dead_bug | 1 | core | A | side | repFsm | pending | pending_harvest |
| dip | 1 | push | A | side | repFsm | pending | pending_harvest |
| glute_bridge | 1 | legs | A | side | repFsm | pending | pending_harvest |
| hanging_leg_raise | 1 | core | A | side | repFsm | pending | pending_harvest |
| hollow_hold | 1 | core | A | side | staticHold | pending | pending_harvest |
| inverted_row | 1 | pull | A | side | repFsm | pending | pending_harvest |
| lunge | 1 | legs | A | side | repFsm | pending | pending_harvest |
| mountain_climber | 1 | core | A | side | repFsm | pending | pending_harvest |
| plank | 1 | core | A | side45 | staticHold | pending | pending_harvest |
| pull_up | 1 | pull | A | side | repFsm | pending | pending_harvest |
| side_plank | 1 | core | A | **front** | staticHold | pending | pending_harvest |
| step_up | 1 | legs | **D** | side | repFsm | pending | pending_harvest |
| superman_hold | 1 | core | A | side | staticHold | pending | pending_harvest |
| toes_to_bar | 1 | core | A | side | repFsm | pending | pending_harvest |
| wall_sit | 1 | legs | A | side | staticHold | pending | pending_harvest |
| db_curl | 2 | pull | A | side | repFsm | pending | pending_harvest |
| db_row | 2 | pull | A | side | repFsm | pending | pending_harvest |
| db_shoulder_press | 2 | shoulders | A | side | repFsm | pending | pending_harvest |
| farmer_carry | 2 | carry | A | **walking_frame** | staticHold | pending | pending_harvest |
| floor_press | 2 | dbkb | **B** | side | repFsm | pending | pending_harvest |
| goblet_squat | 2 | legs | A | side | repFsm | pending | pending_harvest |
| kb_swing | 2 | dbkb | A | side | repFsm | pending | pending_harvest |
| lateral_raise | 2 | shoulders | A | **front** | repFsm | pending | pending_harvest |
| romanian_deadlift | 2 | dbkb | A | side | repFsm | pending | pending_harvest |
| tuck_planche | 2 | skill | A | side | staticHold | pending | pending_harvest |
| wall_handstand | 2 | skill | A | side | staticHold | pending | pending_harvest |

**Dağılım:** A=29 · B=1 (floor_press) · C=0 · D=1 (step_up). Kamera: side=24 · side45=4 · front=2 · walking_frame=1. Engine: repFsm=22 · staticHold=8 · multiPhaseFsm=1. Precondition: derived=2 · pending=29.

## 3. Örneklem denetimi — sınıf gerekçeleri okundu, itiraz aranmadı, BULUNMADI

Şüpheli görünen 5 kalem tek tek `classRationale` alanından doğrulandı (kendi ilk sezgim başta 3 kalemde YANLIŞTI — kayıt bunun için):

- **dead_bug** (sırtüstü, ilk sezgi: "B olmalı"): rationale "sagittal düzlemde yandan TAM görünür, derinlik ekseni kesilmiyor — bench press'ten farkı bu" → **A doğru**, sırtüstü olmak tek başına B'yi tetiklemiyor, foreshortening tetikliyor.
- **superman_hold** (yüzüstü, aynı ilk sezgi): "ekstansiyon sagittal düzlemde yandan görünür" → **A doğru**, aynı ayrım.
- **bird_dog** (dört ayak, ilk sezgi: A muhtemel): "sagittal düzlem yandan görünür, açık zincir" → **A doğru**, teyit edildi.
- **floor_press** (tek B örneği): "SIRTÜSTÜ VE itiş yolu derinlik eksenini kesiyor" — iki koşul birden → **B doğru**, "sınıf B adlandırılmış istisnası" olarak şemaya bağlanmış (blueprint §1/§2 atfı var).
- **lateral_raise** (frontal düzlem, ilk sezgi: "yan kameradan foreshorten olur"): rationale bunu ZATEN görmüş — `camera.setup:"front"` (side DEĞİL) atanmış, "kamera ÖNE alınır ve o kadrajda abduksiyon dürüstçe ölçülür" → **A doğru, ama farklı kamera kurulumuyla**.

**Sonuç:** 5/5 örneklemde gerekçe sağlam. Kendi ilk-sezgi hata payımı (3/5) not ediyorum çünkü bu tam olarak DEFTER'in "testler yeşil ≠ kod doğru" / "beyanı ölçmeden kabul etme" disiplinin bir PREP-analiz karşılığı: schema'nın LİTERAL testini (yalnız "sırtüstü mü?") okumak yeterli değildi, `classRationale`'ın kendisini okumak gerekti.

## 4. Gerçek bulgu: şema-kelime dağarcığı boşluğu (küçük, dokümantasyon sınıfı)

`content/schema/movement-classes.json`'un Class A testi yalnız `primaryPlaneVisibleFrom: ["side45","side"]` değerlerini belgeliyor; Class B testi yalnız `["depthAxis"]`. Ama pratikte katalogda **3 farklı `camera.setup` değeri** kullanılıyor: `side`/`side45` (24+4 hareket), **`front`** (2 hareket: side_plank, lateral_raise), **`walking_frame`** (1 hareket: farmer_carry) — son ikisi şemanın test-enum'unda YOK. Gerekçe metinleri (yukarıdaki §3) tutarlı ve savunulabilir, yani bu bir SINIFLANDIRMA hatası değil — ama şemanın `test.primaryPlaneVisibleFrom` enum'u `front` ve `walkingFrame`'i içerecek şekilde güncellenmezse, ileride otomatik bir doğrulayıcı yazılırsa (K7/K8/K9 ailesindeki `validate_library.py`/`validate_catalog.py` gibi) bu iki kurulumu "test'e uymuyor" diye hatalı reddedebilir. **Öneri:** `movement-classes.json`'a küçük bir sürüm artışıyla (`assignmentRules_tr`'nin kendi kuralı: "sınıf değişimi = DEFTER kaydı + config sürümü artışı") `front` (frontal-plane hareketler) ve `walkingFrame` (translating-subject hareketler) test değerleri eklensin. Kod değişikliği DEĞİL, WRITE-lane onayı gerektirir — burada yalnız isimlendiriliyor.

## 5. GRA-P1-002 (20 hareketli paid foundation) için sıralama önerisi

Roadmap §10 "Paid foundation" şartı: push/pull/squat/hinge/core/carry/hold pattern'lerinin hepsi + en az 2 skill tree. Mevcut 29 pending hareketin family dağılımı bu şartı zaten karşılıyor (push: dip · pull: pull_up/inverted_row/db_row/db_curl · legs(squat/hinge): goblet_squat/romanian_deadlift/lunge/step_up · core: 8 kalem · carry: farmer_carry · hold: wall_sit/plank/side_plank/hollow_hold/superman_hold · skill: tuck_planche/wall_handstand). **Harvest önceliği için öneri (kesin karar orkestratörde):** ilk dalga, `class:A` + `camera.setup:side/side45` + `passiveExecutionPossible:false` (pasif kirlenme riski yapısal olarak yok, referans inşası daha basit) kesişimindeki hareketlerden başlasın — bu, squat/push_up'ta zaten kanıtlanmış pipeline'ı en az sürtünmeyle tekrarlar. `front`/`walking_frame` kamera kurulumu gerektiren 3 hareket (side_plank, lateral_raise, farmer_carry) ve tek `multiPhaseFsm` hareketi (burpee) ikinci dalgaya bırakılabilir — yeni kamera-kurulum/motor-tipi kombinasyonları ilk kanıtlanmış tekrarı karmaşıklaştırır.

## 6. Kapsam dışı bırakılan

Bu rapor kod/içerik dosyalarına dokunmadı (`content/library.json`, `content/catalog/*/*.json`, `content/schema/*.json` hepsi salt-okundu). GRA-P0-001 (catalog/class truth görev paketi) WRITE-lane işidir; bu rapor onun ÖN analizi/girdisidir, kendisi değil.
