# Gravita — App Store 4.3(a) farklılaşma dosyası (hazırlık, gönderim YOK)

Bilet: GRA-P1-01 · Tarih: 2026-11-14 · Kapsam: yalnız belge. Resolution Center'a ve mağazaya hiçbir şey gönderilmez; kod değişmez. Gravita 1.0.0 ASC durumu `REJECTED` (görev emri; bu depoda ASC okuması yok, `DOĞRULANMADI`). Ret gerekçesinin resmî metni henüz okunmadı; aşağıdaki boşluklar ve taslak, ret metni görülünce yeniden yazılacaktır.

Kaynak kuralı: yollar bu depo köküne göredir. Emsal: Lissom'un `docs/store/FARKLILASMA-4.3a.tr.md` dosyası (salt-okur; §2 tablosu orada, burada yeniden yapılmadı). Satır numarası yoksa "dosya düzeyinde" demektir. Ders/kurs sayıları `content/courses/*.v1.json` dosyalarından Python ile ayrıca sayıldı (modül→ders toplamı).

## 1. Gravita'ya özgü olanların kanıtlı envanteri

| # | Özgü öğe | Kanıt (dosya:satır) |
|---|---|---|
| 1 | 7 yazılı kurs, 117 ders (JSON sayımı): calisthenics 56 (10 modül), dumbbell/kettlebell yazılı yol 12 (4 modül), kontrollü kullanım 11 (1), geçişler 2 (1), halter temelleri 12 (3), alçak halka 12 (3), el desteği 12 (3). 12+56+11+2+12+12+12 = 117 | `content/courses/calisthenics.v1.json`, `dbkb-written.v1.json`, `dbkb-handling.v1.json`, `dbkb-transitions.v1.json`, `barbell-foundations.v1.json`, `rings-foundations.v1.json`, `hands-foundations.v1.json`; mağaza iddiası `docs/store/listing.json:12`; `review-notes.en.txt:9-14` |
| 2 | 56 derslik calisthenics kursu (squat/hinge, itme, çekme, core, denge, seans planı) | `content/courses/calisthenics.v1.json`; `lib/app/calisthenics_course.dart`, `lib/app/calisthenics_course_screen.dart`; `listing.json:12` |
| 3 | Dumbbell/kettlebell: 3 yol, 25 ders (yazılı yol 12 + kullanım 11 + geçiş 2) | `content/courses/dbkb-*.v1.json`; `lib/app/dbkb_course_entry.dart:146`; `content/motion_content/dbkb-*.manifest.json` |
| 4 | 3 temel kurs (halter, alçak halka, el desteği), 12'şer ders, 3 modül; her birinde 4 `learning_only` + 8 `physical` ders (JSON sayımı) = **24 fiziksel görev**, hepsi bekletmede (uzman inceleme, izinli gösterim, gözlemli kabul beklenir). Okumak bekletmedeki görevi açmaz; ters duruş öğretilmez | `content/courses/{barbell,rings,hands}-foundations.v1.json` (`practiceType`); `lib/app/calisthenics_course.dart:78,101,115`; ekranda "Physical practice awaiting review" `lib/app/calisthenics_course_screen.dart:686,779-790`; `review-notes.en.txt:14-17`; `listing.json:12` |
| 5 | Ücretsiz bölüm: ders sayısı 44/117, modül hizalı (calisthenics 21, yazılı yol 6, kullanım 4, geçiş 1, üç temel kurs 4'er; `freeLessonCount` mantığı JSON'a uygulanarak yeniden hesaplandı) | `lib/app/paywall_policy.dart:40-60`; `review-notes.en.txt:21-27` |
| 6 | Bağımsız pratik de abonelikle: sekiz haftalık programı kurma ve yeni seans kaydı ücretli; kayıtlı program, geçmiş ve ilerleme her zaman okunur | `lib/app/paywall_policy.dart:13-19,106-116`; `lib/app/home_screen.dart:208`; `lib/app/workout/workout_screen.dart:301,406,425` |
| 7 | Sekiz haftalık program üretici (8 hafta, deload haftaları, gün/seans) | `content/programs/foundation.v1.json:18`; `lib/app/program/program_builder.dart:32,72`; `lib/app/program/program_setup_screen.dart`; `home_screen.dart:212` |
| 8 | Ders ilerlemesi (kendi bildirimli pratik kaydı; ustalık/form puanı değil) | `lib/app/calisthenics_progress.dart:11,60,94`; `lib/app/progress_view.dart:43`; `review-notes.en.txt:44-47` |
| 9 | Beceri grafı: handstand 15 düğüm, planche 6 düğüm (JSON sayımı) | `content/skill-graph/handstand.v1.json`, `planche.v1.json`; `lib/app/skills/skill_tree_screen.dart:28`; `lib/app/skills/skill_progress.dart:61,136,193`; erişim `lib/app/home_screen.dart:290`. Not: `listing.json:91` mağaza metninde "interactive skill tree" iddia edilmediğini söyler |
| 10 | Yazılı geri çağırma (kaynağı gizleyip yeniden yazma, dört geri bildirim durumu; notlar geçici) | `lib/app/study_review.dart:15,41,174`; `lib/app/study_review_content.dart:29-34`; `docs/WRITTEN-RECALL-2026-10-12.md` |
| 11 | Hasat ölçütleri ve kütüphane (31 hareket, 2'si "live") — kamera ölçümüne bağlı araç/kayıt olduğundan bayrak kapalıyken özellik "yok" sayılır, farklılaştırıcı olarak kullanılmaz | `content/library.json` (31 hareket, sayıldı); `docs/F3-HASAT-OLCUTLERI-DONDURULMUS.md`; `content/harvest/`; `listing.json:16` |
| 12 | 14 dil: arayüz; mağaza metni 14 dosya (`listing.json` + 13 `listing.<dil>.json`) | `lib/app/localization/locale_catalog.dart`; `docs/store/listing.*.json`; `review-notes.en.txt:8` |
| 13 | Mağaza kimliği: "Gravita: Skills & Strength" / "Calisthenics at your pace" | `docs/store/listing.json:4-5` |
| 14 | İkon: koyu bordo zemin, krem "G" biçimli halter plakası, kırmızı çubuk (görüntü okundu). `docs/store/icon-candidates/` içindeki "one-hand-handstand" görselleri tarihsel adaydır, güncel ikon değil | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`; `docs/store/icon-candidates/README.md:1-9` |

**Kamera/ölçüm "yok" sayılır.** Bayrak: `motionCameraCoachingAvailable = false`, derleme zamanı sabiti (`~/.pub-cache/git/motion-core-5b15308ea2a89dd5adebe29635f8e7b18fff68e4/packages/motion_account/lib/src/motion_release_policy.dart:6`; pin `pubspec.yaml:50-53` ref `5b15308e…`). Gravita buna `motionPaidCameraLaunchEnabled` ile bağlanır (`lib/app/camera_release_policy.dart:7`). Kapalıyken çizilmeyen yerler: kütüphane (`library_screen.dart:139,142,162`), ana ekran başlığı "ÖLÇÜM KATALOĞU" (`home_screen.dart:85-106`), ilerleme sınır notu (`progress_view.dart:117`), hareket sayfası (`movement_page.dart:144,365,576,700`), antrenman ekranı canlı rozet (`workout/workout_screen.dart:668-682`), canlı oturum girişi (`gravita_app.dart:456`). Abonelik satışı ayrıdır ve açıktır (`paywall_policy.dart:21-25`; Core `motion_release_policy.dart:11`).

**Kapalıyken geriye kalan izler (tutarlılık gerektirir):**
- Onboarding 3 adımın 3.'sü kamera adımı olarak duruyor (`onboarding_screen.dart:42,104`); bayrak kapalıyken başlık "Camera unavailable / Kamera kapalı", tek düğme "izin vermeden devam" ve izin istenmez (`:19,60-64,299-318`; gövde metni `:353`, `onboarding_strings.dart:80`). Ekran render olarak doğrulanmadı (`DOĞRULANMADI`), yalnız kaynak okundu.
- Ana kabukta videocam simgeli, devre dışı düğme "Kamera kapalı" etiketiyle çiziliyor (`gravita_app.dart:525-535`).
- iOS `NSCameraUsageDescription` (`ios/Runner/Info.plist:5`, 14 dilde `*.lproj/InfoPlist.strings:1`) bildirimde duruyor (Android `CAMERA` izni GRA-P1-02 ile kaldırıldı, `test/android_camera_permission_test.dart`); metin "disabled in this release" der (`listing.json:20-22`).
- Kamera kodu derlemede: `lib/app/live_session_screen.dart`, `camera_release_latch.dart`, `packages/gravita_engine`.
- Mağaza JSON'unun `$`-önekli iç notları kamera sayımını anlatır (`listing.json:14,16,17`, ör. `$whatItDoesWhy`); gönderilen alan değildir. `docs/store/STORE-LISTING-TASLAK.md:68-74` eski kamera iddialarını içerir, aynı dosya `:40`'ta "tarihsel, yayın metni olarak kullanmayın" der.

## 2. Ortak şablon tablosu — yalnız Gravita sütunu doğrulaması

Tablo Lissom emsalinin §2'sindedir; yeniden yapılmadı.

| Öğe | Lissom §2'deki Gravita hücresi | Depoda doğrulama | Sonuç |
|---|---|---|---|
| İkon | koyu bordo, krem "G" halter plakası | görüntü okundu: bordo zemin, krem "G" plaka, kırmızı çubuk (öğe 14) | Doğru |
| Ana düzen | `NavigationBar`, 4 sekme: Bugün / Kütüphane / İlerleme / Profil, `gravita_app.dart:539` | `gravita_app.dart:539-565` (etiketler `:549,554,559,564` civarı: Bugün, Kütüphane, İlerleme, Profil); `IndexedStack` `:483` | Doğru |
| Onboarding | 3 adım: value, safety, camera, `onboarding_screen.dart:42` | `enum _Step { value, safety, camera }` `:42` | Doğru |
| Paywall/erişim | `paywall_policy.dart:106-109` | Satırlar yalnız `PaywallStrings` metinleri; erişim mantığı `:40-82`, abonelik açıklaması `:13-25`. Gravita'ya özgü: 44/117 modül hizalı ücretsiz kısım ve bağımsız pratik (program kurma/seans kaydı) de ücretli (öğe 5-6) | Satır atfı dar; içerik eksik (aşağıya bak) |
| Abonelik düzeni | "ilk dersler ücretsiz; üyelik" | "Gravita" aylık/yıllık + ortak "Motion+" (`review-notes.en.txt:18-20`; `paywall_policy.dart:108-110`) | Çelişki yok, ama özet eksik: Lissom hücresi program kurma kilidini ve modül hizalı 44/117'yi söylemiyor |
| ASC metni | "Gravita: Skills & Strength" / "Calisthenics at your pace" | `listing.json:4-5` | Doğru |
| Core import | 6 | `grep -rl "package:motion_core/motion_core.dart" lib \| wc -l` → **6** (`live_session_screen.dart`, `account_session_store.dart`, `motion_observation.dart`, `account_store_epoch.dart`, `workout/feedback_controller.dart`, `live_session.dart`) | Doğru |

Lissom hücreleriyle çelişen yer: yalnız paywall satır atfı (yukarıda). Not: hesap/üyelik çekirdeği `motion_account` paketiyle gelir (`pubspec.yaml:17-22`), bu sayıma girmez.

## 3. Boşluk listesi ve önerilen düzeltmeler

Resmî ret metni okunmadığından boşluklar, kurucunun aynı-gün-beş-uygulama özetine (`DOĞRULANMADI`, Gravita için metin yok) ve §1-2 kanıtlarına dayanır. Beden: S ≈ metin/not, M ≈ küçük kod+mağaza varlığı, L ≈ ürün farklılığı. Hiçbiri bu bilette uygulanmaz.

| # | Boşluk | Kanıt | Önerilen düzeltme | Beden |
|---|---|---|---|---|
| G1 | Beş Motion uygulaması aynı çatı ve erişim kalıbıyla gönderildi | §2 (Core pin, `course_access` kalıbı, ortak "Motion+") | Gönderimleri zamana yay; Resolution Center'da olgusal açıklama | S |
| G2 | Sekme düzeni ve abonelik kalıbı Lissom'la neredeyse aynı | `gravita_app.dart:539-565`; §2 | Ana sayfanın Gravita'ya özgü yönü öne çıkarılsın (sekiz haftalık program + beceri grafı kartları `home_screen.dart:212,290` zaten var); yapısal değişiklik kurucu kararı | M |
| G3 | Mağaza kimliği dar: alt başlık "Calisthenics at your pace" yalnız bir kurs alanını söylüyor; 7 kurs / 5 alan / dumbbell-kettlebell-halter-halka yolu başlıkta yok. Mevcut ekran görüntüleri ve ASC okuması güncel değil | `listing.json:4-5`; `review-notes.en.txt:4` ("current screenshots … pending") | Alt başlık ve tanıtım metninde çok alanlı kapsam; yeni ekran görüntüleri (kurs yolları, program, beceri grafı) | S–M |
| G4 | Kamera bayrağı kapalı, ama onboarding'in 3. adımı, "Kamera kapalı" etiketi, `NSCameraUsageDescription` ve Android `CAMERA` izni duruyor; "kamera yok" ile izin bildirimi hakem gözünde tutarsız görünebilir | §1 izler listesi | Hakem notuna tek cümle (onboarding kamera adımı kapalı durumda izin istemez); izin bildirimini kaldırmak veya adımı gizlemek kurucu/Motion orchestration kararı | S (not) / M (kod) |
| G5 | İçerik "tamamlanmamış" okunabilir: 24 fiziksel görev bekletmede, gösterim videosu yok | `calisthenics_course_screen.dart:779-790`; `review-notes.en.txt:14-17,47-48` | Bekletmenin bilinçli güvenlik kapısı olduğu zaten notta yazılı; ret metnine göre vurgula. İçeriğin üretim sürecine dair cümle için kanıt yok (`DOĞRULANMADI`) | S |
| G6 | İçerik özgünlüğü: kaynak/hazırlayan kanıtı hakem notunda yok | `review-notes.en.txt:9-17` ("original English and Turkish text" der; kaynak kapsamı yok); ders JSON'larında `sources`, `sourceIds` alanları var (`barbell-foundations.v1.json` anahtarları) | Nota kaynak kapsamı özeti; üretim süreci cümlesi yalnız kurucu/Motion orchestration kanıtı verirse | S |
| G7 | Paywall/plan ekranı Core'dan geliyor olabilir; Gravita'ya özgü sunum doğrulanmadı | `paywall_policy.dart:78-82` (`requirePaidAccess` Core'dan) | Ekranı gerçek cihazda gör; sonra karar | S |
| G8 | Eski belgelerde kamera iddiaları (tarihsel) güncel metinle karışabilir | `STORE-LISTING-TASLAK.md:40-74`; `listing.json` iç `$` notları | Gönderimden önce tek geçişte tutarlılık taraması | S |

## 4. Resolution Center yanıt taslağı (GÖNDERİLMEZ)

Gravita 1.0.0 ret metni henüz okunmadı. Taslak ret metni görülünce yeniden yazılacaktır; aşağıdaki metin yalnız §1'deki kanıtlı maddelere dayanır.

> Merhaba,
> Gravita, Yula Lab'ın beş Motion uygulamasından biri olarak [KURUCU DOĞRULAMASI GEREKİR: gönderim zamanı olgusu ve zamana yayma kararı] benzer bir paket gibi göründüğünü anlıyoruz; Gravita'yı ayrı ele alıyoruz.
> Gravita beceri ve kuvvet gelişimine yöneliktir: 14 dilde arayüz, İngilizce ve Türkçe özgün yazılı 7 kurs ve 117 ders (56 derslik calisthenics kursu, üç dumbbell/kettlebell yolu ve halter, alçak halka ve el desteği için üç temel kurs). Sekiz haftalık program üretici ve ders ilerleme kaydı Gravita'ya aittir [beceri grafı ve yazılı geri çağırma: cihazda erişilebilirliği DOĞRULANMADI; doğrulanmadan yazılmaz]. Ücretsiz bölüm 117 dersin 44'üdür.
> Hesap, abonelik ve güvenlik altyapısı ortaktır; içerik, ikon, ad ve alan ayrıdır. Bu sürümde kamera koçluğu ve canlı ölçüm kapalıdır ve bir farklılık olarak öne sürülmemektedir. Üç temel kursun fiziksel görevleri uzman incelemesi bekleyerek kapalı tutulur.
> Ek bilgi isterseniz memnuniyetle sağlarız.

Notlar: (a) Taslak yalnız kanıtlı maddelere dayanır; ret metni görülünce yeniden yazılmalıdır. (b) "Diğer uygulamalarda bu içerik yok" biçiminde bir cümle eklenecekse Motion orchestration doğrulamalıdır. (c) Köşeli parantezli yerler kurucu/Motion orchestration doğrulamasına kadar gönderilemez; "Gönderimleri zamana yayıyoruz" bir karar değil G1 önerisidir. (d) Beden sütununda L kullanılmadı; aralıklı hücreler (S–M, S/M) kodlu düzeltme gerekirse M sayılır. (e) Gönderim, mağaza yazışması ve zamanlama kurucu/Motion orchestration işidir.

## 4a. App Review notu kontrolü (kabul ölçütü 4)

- `docs/store/review-notes.en.txt`: kamera/ölçüm özelliğine **dayanmıyor**; yalnız kapalı olduğunu söylüyor: "Camera coaching, live measurement and form grades are disabled in this version and are not part of the subscription" (`:39-41`) ve "The lessons do not need camera or microphone permission" (`:47-48`). Bayrak kapalı özelliğe atıf yok; **metin değişmedi**. (Onboarding'deki kapalı kamera adımı notta anılmıyor; G4'te S düzeltme olarak önerildi, bu bilette yazılmadı.)
- `docs/store/` içinde başka reviewer notu: `RELEASE-REVIEW.tr.md:56` kamera/üyelik/satın almanın kapalı olması gerektiğini söyleyen dahili kontrol listesi, App Review metni değil; kapalılığa atıf, dayanma yok.
- `docs/privacy/`: yalnız `sqlite-release-boundary-2026-10-13.md` var; kamera sözcüğü geçmiyor (`grep -il camera` boş).
- `docs/camera/`: **yok**. Backlog'taki `docs/camera/ACILIS-METINLERI.tr.md` yolu Lissom'a aittir, Gravita'da yok.

## 5. Doğrulanmayanlar

- Gravita 1.0.0 resmî 4.3(a) ret metni ve ASC `REJECTED` durumunun kendisi (bu repoda yok); Apple'ın güncel yönerge metni.
- Onboarding kamera adımının ve "Kamera kapalı" etiketinin ekranda render hali (yalnız kaynak okundu).
- Paywall/plan ekranının düzeni ve fiyat sunumu (Core'dan; ekran okunmadı); abonelik grubunun adı Gravita için okunmadı.
- Beceri grafı ve yazılı geri çağırmanın gerçek cihazda erişilebilirliği (yalnız kaynak çağrıları okundu); mağaza metni skill tree'yi iddia etmiyor (`listing.json:91`).
- İçeriğin üretim/kaynak süreci ve "özgün" olgusunun dış kanıtı.
- Mevcut ekran görüntüleri klasörünün içeriği (`docs/store/screenshots/gravita-hatti-iphone16`) okunmadı.
- Android `mipmap` ikonlarının görsel içeriği okunmadı; yalnız iOS 1024 ikonu görüldü.
- Diğer Motion depolarındaki hücreler (Lissom §2) bu bilette yeniden okunmadı.
- Core bayrağı pub önbelleğindeki pinli SHA'dan okundu; gerçek derleme çıktısı denetlenmedi.
