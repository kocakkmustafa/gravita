# G-068 — bodyweight_squat referansı: hazırlık notu (push_up emsali)

Koordinatör: "sonraki tur squat-referansı hattına (bodyweight_squat için
aynı rep-FSM→kanonik CLI zinciri, push_up emsalin hazır) geçebilirsin —
hazırlık notunu şimdiden yazmaya başla." Bu not YÜRÜTÜLMEDİ, yalnız planı
ve AÇIK kararları kaydediyor.

## Zincir (push_up'tan aynen)

1. `slice_deep_reps_squat.dart` — ZATEN VAR (G-067), 260 derin-tekrar
   fixture'ı `~/motion-harvest/gravita-squat/landmarks-rep-sliced/`'te
   hazır duruyor.
2. `canonical_push_up_reference.dart`'ın squat karşılığı yazılmalı
   (`canonical_squat_reference.dart` veya genelleştirilmiş tek araç +
   `--movement` parametresi) — `ReferenceCli(allowUnattested:true).
   buildArtifact(technique:'bodyweight_squat', fixturesById: <dilimli
   fixture'lar>)`.
3. Yayım şartları (M-F-90, push_up'ta uygulanan): `$mirrorAgnostic` beyanı +
   `$thinEvidenceInstructors` + eski-referans yoksa "ilk üretim" notu (squat
   için "eski" yok — bu İLK squat referansı, kıyas tablosu gerekmez).

## AÇIK KARARLAR (koordinatöre — kendim yürütmüyorum)

1. **`engine.precondition.status` hâlâ `pending`.** G-061 (kneeSymmetry→
   advisory) + G-064..G-067 (hipKneeCoupling→gate, rep-fsm, 12/16 PASS)
   sonrası: precondition'ı `derived`e taşımak için `conditions[]`'a NE
   yazılacak? Aday: `hipKneeCoupling >= 0.2` — ama bu bir TAKE/EĞİTMEN
   düzeyi istatistiği (çok-kare Pearson r), `engine.precondition.conditions`
   ise KARE-BAŞINA değerlendirilen `MetricCondition` listesi (bkz.
   rep_engine.dart satır ~194: `pre.byName(c.metric)` her kare için tek
   sayı ister). hipKneeCoupling'i kare-başına bir koşula NASIL çevrilir
   (ör. kayar-pencere korelasyonu?) HENÜZ TASARLANMADI — bu YENİ bir ölçüm
   tasarımı kalemi, benim kararım değil.
2. **Referans YALNIZ precondition pending İKEN de üretilebilir mi?**
   push_up'ta precondition zaten `derived`di (G-043'ten beri). Squat'ta
   `harvest_reps.dart`/`build_reference.dart` (Gravita'nın KENDİ araçları,
   artık kullanılmıyor) `preconditionDerived` şart koşuyordu (G-043 fail-
   closed). `ReferenceCli` (kanonik) bu şartı hiç KONTROL ETMİYOR (kodda
   böyle bir kapı yok) — yani teknik olarak squat referansı precondition
   pending'ken de üretilebilir. Ama bu, G-043'ün ta kendisinin
   BEKLEDİĞİ disiplini (kimlik doğrulanmadan referans üretme) es geçmek
   olur mu? Muhtemelen HAYIR çünkü artık dilimleme zaten kimlik-benzeri bir
   filtre uyguluyor (yalnız derin tekrarlar) — ama "derin tekrar" ≠ "gerçek
   squat" (G-043'ün orijinal riski hâlâ teorik olarak açık: ayakta konuşan
   biri de diz açısını 116° altına indirebilir mi? Ölçülmedi). Bu ayrım
   koordinatör kararı gerektirir.
3. **hipKneeCoupling eşiği (0,2) hâlâ PROVISIONAL** — referans üretimi bu
   eşiğe dayanıyorsa (hangi eğitmenler dahil edilir), provisional bir
   eşikle "ilk" bir referans üretmek G-050/G-052 sınıfı bir risk taşır mı?

## Kanıt

Kaynak dizinler: `~/motion-harvest/gravita-squat/landmarks-rep-sliced/`
(260 dosya, hazır) · `content/harvest/hip_knee_coupling.bodyweight_squat.json`
(gate sonucu, windowBasis=rep-fsm).
