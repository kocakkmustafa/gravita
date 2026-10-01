# Gravita calisthenics kursu — yerel kanıt / 2026-09-26

## Sonuç ve kapsam
HEAD `a308f8f03295cc4c8c4bb545aa8155a30afc76e9` üstünde, commit/push yapılmadan 56 özgün TR/EN ders, 10 modül, çalışan Home/Library girişleri, kurs/ders yüzeyi ve hesaba ayrılmış ilerleme eklendi. 44 fiziksel seçenekli ders, 12 yazılı/gözlem öğrenme görevi. İlk modül yeni tekniği öğretmeden tekrar istemez. İleri dört beceri (amut, planche, front lever, muscle-up) yalnız beceri bilgisi; tek başına deneme veya tıbbi uygunluk onayı yok. Gebelikte düşme riski taşıyan inversiyonlara başlanması önerilmez.

İlk WIP `.github/workflows/checks.yml` korunur. Root'un ayrıca yazdığı `docs/store/listing.json` ve `listing.tr-TR.json` yerel taslaklarına bu ajan dokunmadı. Holding/Vault/core/provider/simülatör/imza/store/deploy değişmedi.

## Değişen gerçek yollar
- `tool/generate_calisthenics_course.py`: özgün iki dilli authoring, deterministik `--check`.
- `content/courses/calisthenics.v1.json`: 185056 B, SHA-256 `10ca089a71ba03c01d3ab8839a26003a1934a8f24ad8ed111a11bec1d4d8bb75`. `pubspec.yaml` exact asset beyanı; runtime rootBundle eşitliği test edildi.
- `content/courses/calisthenics.media-briefs.v1.json`: 40840 B, SHA-256 `584b95b2bfa913fb4120b62eed51fea98bd047de3223fbe8890585cdb6d1e2d2`; 56 özel shot brief. `brief_only_not_generated_or_coach_reviewed`, trainingData=false. Medya yokken varmış gibi video butonu çizilmez.
- `lib/app/calisthenics_course.dart`: TR/EN, 56/10, benzersiz kimlik, HTTPS kaynak bağlama, önceki-ders önkoşulu, ileri learning_only validator.
- `lib/app/calisthenics_progress.dart`, `course_progress_io.dart`: seen/practised/selfReportedComplete, ayrı tarihler ve pratik sayısı; sürüm ayrımı; dosya başına seri RMW; flush+temp+rename; silinmiş hesap lease/tombstone.
- `lib/app/account_data_directory.dart`: mevcut hesap silme yolu, kurs yazılarını invalidation+drain sonrası siler; misafir ve diğer hesap korunur.
- `lib/app/content_repository.dart`: exact ayrı öğretim assetini yükler, mevcut ölçüm LessonSurface/skill/program kapılarını değiştirmez. Yeni path_provider store seam.
- `lib/app/calisthenics_course_screen.dart`, `home_screen.dart`, `library_screen.dart`: Gravita tokens/typography; toplam/modül kayıt sayısı, önerilen sonraki ders; giriş/çıkış, pratik doz seçenekleri, öz denetim, kolay yol, durma işareti, kaynak URL/copy; hesap değişiminde bellek/checkbox sıfırlama, async epoch.
- `test/calisthenics_course_test.dart`: 9 içerik, paket, gerçek dosya, eski sürüm, bozuk kayıt, hesap/eşzamanlı/silme testi.
- `test/calisthenics_flow_test.dart`: 3 dar 375×812 ekran akışı. Home ve Library'den görünür kurs+ilk derse gerçek dokunuş; görevin pratiği/checkbox/tamamlama ve yeni store/file/reopen1/56; A→B switch veriyi/checkbox'ı ayırır.
- `integration_test/calisthenics_course_smoke_test.dart`: native SDK smoke hazır. Gerçek rootBundle, native path_provider, uygulama destek altında yalnız kendi timestamp dizini ve UUID scope; pratik/kayıt/yeni store1/56/yeniden ekran1/56; kendi dizinini teardown eder. Auth provider veya kamera hareketi doğrulaması değildir. `integration_test` SDK ve6transitif lock girişi eklendi; mevcut paketler/corepin yükseltilmedi.

## Çalıştırılan kanıt
| Kapı | Sonuç | Sınır |
|---|---|---|
| `flutter analyze --no-pub` | 0 issue | Native smoke dahil kaynak analizi; cihaz çalıştırması değil |
| `flutter test --no-pub --reporter expanded` | 328 PASS, 2 mevcut skip | 12 yeni test dahil; native, camera, provider, satın alma yok |
| engine `dart test --reporter expanded` | 176 PASS | Mevcut fixture regresyonu, yeni kişi holdout'u değil |
| `python3 tool/generate_calisthenics_course.py --check` | 56/10 exact PASS | Authoring/asset/manifest tutarlılığı |
| `python3 tools/validate_library.py` | 31, 2 live /29 queued PASS | Statü değiştirilmedi |
| `python3 tools/validate_catalog.py` | 0 hata, 29 mevcut provenance uyarısı | Uyarılar düzelmiş gibi sunulmaz |
| `python3 tools/validate_reference_model.py` | PASS, 2 KAYITSIZ tarihsel artefakt | Kaynak provenance hâlâ eksik |
| `git diff --check` | PASS | Yalnız whitespace kapısı |
| Mevcut reachability yürüyüşü | 10 strict /13 loose; yeni iki rota gerçekten gezildi | 1 kök +9push;4sekme aynı kabuk. Tek varılamayan ContentFailure sistem dalı |

UI testindeki ilk hatalar model/kayıt başarısı iddiasına dönüştürülmedi: route transition, lazy scroll body ve save bitmeden disabled checkbox okuma test harness'inde giderildi. IO için callback-enabled koşulu gerçek süreyle beklenir, sahte pump tek başına kabul edilmez.

Native smoke bu ajan tarafından çalıştırılmadı; root seri slotunun sonucu ve açık READBACK/CLEANUP markerları ayrıca gerekir. Physical movement/heat/performance/person-holdout, signed binary, accessibility-device, source-media coach review ve store readback ayrı tamamlanmamış kapılardır.

## Model, izin ve değişmeyen ölçüm sınırı
Üç fixture: squat14103022B SHA`b7323c349cfd766d64c34daa417a88f51fedc829b51850cf2e6680df7f5d0ecd`; axis_swap21013B SHA`d3d2bc55d48779d3d4f18ca6cbe915032d7d984020cc305170f8399c6f4aceee`; correct_frames119476B SHA`1d03fecf76e5b5d1ae1aad9a303e45739429492408ab90ac9fb7f6f168519a05`. 19 historical harvest JSON, push15eğitmen/27video/9qualified iddiası. `standard-youtube` indirme/training/rıza lisansı değildir. Yeni izinli bağımsız kişi holdout'u bulunamadı. Yeni video indirilmedi, etiket üretilmedi, model eğitilmedi. Mevcut 2live/29coming_soon kapısı aynen kaldı. Öğretim ilerlemesi tekrar sayısı, güvenli açı, kuvvet, uzman onayı veya kamera ustalığına çevrilmez.

August `model-gate.json` eşikleri/ölçümleri tarihsel korunur; yalnız dated latestReview eklendi. Eski 20/200 eşikleri yeni kabul protokolü diye icat edilmez. Current engine PASS yalnız o mevcut mantığın regresyonudur.

## Pedagoji ve kaynak doğrulaması
Birincil sayfalar 2026-09-26 açıldı. Ders copy özgündür; kaynak videolar/fotoğraflar kopyalanmadı. Genel prensipler ders sırasını gerekçelendirir; bu 56derslik paket için klinik etkinlik doğrulaması yok. Kaynaklar ve özel hareket bağlamı asset sourceIds ile bağlıdır.
- ACSM2026: https://acsm.org/resistance-training-guidelines-update-2026/ — düzenlilik, ana gruplar, vücut ağırlığı/evde direnç seçenekleri, bireyselleştirme; failure/karmaşık dönemleme zorunlu değil. Sağlıklı yetişkin pozisyonu sağlık gruplarına otomatik uygunluk değildir.
- WHO: https://www.who.int/initiatives/behealthy/physical-activity — temel kuvvet+aktivite çerçevesi, kişiye özel reçete değil.
- NHS: https://www.nhs.uk/live-well/exercise/strength-exercises/ — sabit tekerleksiz sandalye, yavaş başlangıç/sit-to-stand/wallpress/calfrise.
- ACE: https://www.acefitness.org/resources/everyone/exercise-library/ ; özel bird-dog https://www.acefitness.org/resources/everyone/exercise-library/14/bird-dog/ — gövde kontrolü ve kontrollü aralık.
- NASM özel https://www.nasm.org/resource-center/exercise-library/push-up ; /pull-up ; /plank ; /dead-bug ; /pike-push-up — teknik ve regressions bağlamı. Sayfalarda şablon tekrarları ve mutlak ifadeler vardır; açı/yaralanma önleme garantisi aktarılmadı, bir beden için zorunlu açı kullanılmadı.
- ACOG https://www.acog.org/womens-health/faqs/exercise-during-pregnancy — web renderer error, resmi HTTP200 ayrıca readback; resmî committee-opinion arama içeriği ve NHS https://www.nhs.uk/pregnancy/keeping-well/exercise/ ile contact/fall-risk/prolonged-supine genel sınırlar karşılaştırıldı. Tedavi/rehab reçetesi veya otomatik medical suitability yok.

Bağımsız root pedagojik kontrolü sonrası ilk6dersin öğretilmemiş fiziksel tekrarları çıkarıldı; row bar/askı girişleri ayrıldı; destekli diz kaldırmada karşı ayak sürekli basamakta ve tam geri koyma öğretildi; pike eller-dizler→parmak→küçük yükseliş→dizle çıkış netleştirildi. Teknik/adaptation/mediaBrief birlikte güncellendi.
Katalog kapsam matrisi `docs/plans/2026-09-26-calisthenics-course.md` içinde; ağırlıklı9hareket ayrı ağırlık eğitimine ait, asılı ileri gövde varyasyonları küçük destekli diz alternatifiyle önceleniyor, wall_sit/superman ayrı zorunlu ders değil. Ölçüm dosyaları değiştirilmedi.

## Depolama ve temizleme fişi
Kaynak medya indirmesi 0B, eğitim dataseti/artifaktı 0B. Testlerin kendi geçici veri dizinleri teardown ile silindi; native test de yalnız kendi dizinini temizlemek için hazırlandı. Kalıcı asset yaklaşık226KB ve metindir.
- `/Users/mustafakaankocak/Developer/YULAlab-AI/scratch/2026-09-26-motion-courses/gravita/app-tests.log`: 69513 B, SHA-256 `49bdaf9b06ab2ca220d150d380df812e6e5cfcbdb2f3194c642012a849b4bb08`; tamamlanan koşumun geçici çıktısı, bu not yazıldıktan sonra yalnız bu dosya silindi.
- `/Users/mustafakaankocak/Developer/YULAlab-AI/scratch/2026-09-26-motion-courses/gravita/engine-tests.log`: 27986 B, SHA-256 `856676e734fa611a8027aa051e749ea92c4d7c0f68c6a1de74ee47300db8c6b4`; tamamlanan koşumun geçici çıktısı, bu not yazıldıktan sonra yalnız bu dosya silindi.
Bu silme bir APFS fiziksel-reclaim iddiası değildir. Başka scratch, model asseti, kullanıcı verisi veya çalışan çıktı silinmedi.

## Mağaza kaynak kapısının son onarımı
Root yetkisiyle `tools/validate_store_listing.py` güncel EN+TR kamu ders/modül iddialarını gerçek course assetine bağlar; metadata'daki exact asset yolu, SHA-256, lessonCount ve moduleCount ayrıca doğrulanır. Doğru metadata eksik kamu iddiasını telafi etmez. `STORE-LISTING-TASLAK.md` eski 31/2/29 katalog satırı bağımsız korunur. Eski ve zaten kaybolmuş `covers N movements / Today N` metin deseni artık zorunlu değildir.
`--self-test`: 1 pozitif +13 negatif kontrol PASS: EN/TR yanlış kamu ders sayısı, kamu iddiası yokluğu, hash, moduleCount ve lessonCount metadata; gerçek kaynakta ders artıp metnin bayat kalması; eski katalog sayı/yokluk kontrolleri. Gerçek kapının son ajan koşumu yalnız root taslaklarındaki eski SHA için FAIL verdi: beklenen finalSHA `10ca089a71ba03c01d3ab8839a26003a1934a8f24ad8ed111a11bec1d4d8bb75`. Bu doğru fail, içerik ile taslağın ayrışmasını yakaladı. Root iki taslağın hash'ini son kez tazeleyecek ve kapının readback'ini ayrı kaydedecek. Bu ajan taslaklara yazmadı.
Native `scratch/2026-09-26-motion-courses/gravita/ios-native.log` root'un çalışan kaydıdır; korunur. Yukarıdaki temizleme yalnız tamamlanan app/engine logları içindir.


## Root son readback

Final56ders assetine göre2yerel taslak SHA'sı yenilendi;
`python3 tools/validate_store_listing.py` gerçek EN/TR iddia, SHA,56/10
ve eski31/2/29 kapısını PASS verdi.
Native iPhone iOS27 simülatör testinde gerçek rootBundle/path-provider
ile ilk görev kaydedildi, yeni store1/56 okudu ve ekran yeniden kuruldu.
Yalnız teste ait child directory teardown sonrası `exists=false` verdi.
Log: `scratch/2026-09-26-motion-courses/gravita/ios-native.log`.
Bu test provider kimliği, fiziksel hareket veya mağaza paket kabulü değildir.
