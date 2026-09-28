# PROGRESS — Gravita

## 2026-09-28 — Calisthenics ilk kursu; kaynak PASS, ürün kabulü açık

İlk calisthenics kursu **56 ders** ve canlı v8d kaynak paketinde. Ders
gösterim briefi ve hazırlık/ekipman çiti kaynak düzeyinde denetlendi;
gerçek onaylı video, uzman kişi-ayrık hareket hata verisi ve tam-kurs
form modeli **0**. Ortak `motion_content` için uygulama içi okuyucu dar
kaynak köprüsü düzeyinde bağlı; üretim manifesti, medya oynatıcı ve fiziksel
cihaz kabulü açık. Held Squat ZIP ve başarısız bir-seferlik deneyler korunur.

**2026-09-28 yerel devam:** Paketlenmiş kurs baytları için app-local
`FlutterBundleContentAssetReader` eklendi. `motion_content` aynı mühürlü Core
commitine (`f2ea161c…`) bağlandı; kilit sürümü `0.1.0`. Yalnız testte üretilen
manifest, mevcut `calisthenics.v1.json` dosyasını 261.754 bayt ve
`eca53870…40f83d` SHA ile okuyup 10 modül/56 dersi doğruladı. Yanlış hash ve
güvensiz yol içerik açılmadan reddedildi. Kurs kaynağı değiştirilmedi;
üretim manifesti, gerçek medya ve oynatıcı hâlâ açık. Üç odaklı test dosyası
25/25 geçti, üç ilgili Dart dosyasında analiz temiz. Köprü `7b6524b`
commitinde mevcut PR #1 dalına push edildi; GitHub güncel başı doğruladı.
Yeni baştaki yararlı CI sonucu ve ürün kabulü hâlâ açık.

Güncel kurs önce `b8b1147` commitinde mevcut PR #1 incelemesine taşındı;
PR'ın güncel kaynak başı köprü sonrasında `7b6524b`.
Üreticinin denetlenmiş 56 derslik v8d kaynağı eski metne döndürme riski,
SHA bağlı içerik katmanı ve `--check` CI kapısıyla giderildi; kök ve bağımsız
inceleme dar PASS. GitHub Actions'ın üç işi bütçe engeliyle başlamadı;
bu kaynaklar için yararlı CI, merge veya mağaza kabulü yok. Kanonik devam:
`holding/plans/MOTION-MODEL-RESUME-2026-09-27.md`.

## 2026-08-19 — SOLO model (v3): GRA-P1-003 kapandı + GRA-P1-004 Step 1/2 canlı yola kablı + Step 3 temeli (G-272…G-277)

> Orkestrasyon/koordinatör katmanı bu turda iptal edildi — hat roadmap'ini
> (`22-GRAVITA-MASTER-ROADMAP.md`) tek başına, kurucu-sorusu sormadan yürüttü. `HEAD 87075bf`,
> origin ile senkron, çalışma ağacı temiz, **6 commit hepsi push'lu**. Kapılar: `app 295/295 ·
> engine 176/176 · python 22/22`, üçü de yeşil (`network_claim_audit` dahil).

**GRA-P1-003 TAMAMEN kapandı** (roadmap'in beş adımının beşi de ✅ VERIFIED, G-272/G-273):
`ProgramSetupScreen`/`WorkoutScreen`/`ProgramStore` + RPE toplama + kaçırılan gün yeniden
sıralama. Yol boyunca `test/reachability_test.dart`ın (aile-geneli SHARED test altyapısı) kendi
pop-mantığı kusuru bulunup düzeltildi (`witness.pushes` deltası).

**GRA-P1-004 Step 1/2 kapandı, GERÇEKTEN canlı yola kablı** (G-274/G-275): `LiveFeedbackController`
`LiveSessionRunner.consume()`a bağlı, sınıf-B iki katmanlı garantiyle form hükmü üretmiyor. Ses/
görsel teslim EXTERNAL_GATE (cihaz+kayıtlı ses gerektirir).

**GRA-P1-004 Step 3 temeli atıldı — Gravita'nın İLK veritabanı** (G-276/G-277): kendi G-274 hatam
("Drift eklenmeyecek") `02-MOTION-AILESI-ORKESTRASYON.md` §8.1 okununca düzeltildi; `drift`+
`sqlite3_flutter_libs` gerçekten çalıştığı ölçülerek eklendi, `SessionProjector.rebuild()`
idempotent replay'i tam-yeniden-kurma stratejisiyle sağlıyor.

Detay: `workspace/DEFTER.md` G-272…G-277 · Obsidian: [[🔄 Oturum Devri 2026-08-19 — Gravita GRA-P1-003 Kapanışı + GRA-P1-004 Feedback&Storage Temeli]].

Sıradaki: GRA-P1-004 Step 3'ün kalanı (şifreleme/export/delete/Step 5) — `EVIDENCE-LEDGER.md`nin
GRA-P1-004 satırında tam kapsam.

## 2026-08-19 — Üretim hattı bağlantısı + PREP turu (G-260…G-264)

Oturum `holding/plans/URETIM-HATTI-OTURUM-PROTOKOLU-2026-08-18.md` sistemine bağlandı: başlık
**GRAVITA** mühürlendi, orkestratör **Motion Orchestration**'a `[TIP: HAZIR]` gönderildi. Hat:
**PREP lane** — yazma slotu yok, kod/içerik dosyalarına DOKUNULMADI.

**Baseline mühürü:** `git log -1` `2137382` roadmap'in 2026-08-18 iddiasıyla BİREBİR eşleşti, ağaç
temiz, origin ile 0/0 fark, ortak SHA pini (`f13bdc93b2eae2f741bfcdb4c9270a88e5d75e5d`) 2/2 doğru.
Roadmap §6'nın 10 "mevcut" + 15 "planlanan" dosya yolu tek tek doğrulandı, sapma yok.

**4 PREP işi tamamlandı, üçü yeni doküman üretti** (`app/docs/PREP-*-2026-08-19.md`):
1. **Katalog sınıflandırma** — 31/31 hareketin `class`+`classRationale` zaten dolu (kod yazmaya
   gerek yoktu); asıl boşluk sınıf değil ÖLÇÜM-DOĞRULAMASI (29/31 `precondition:pending`). Roadmap
   §4'ün A/B/C/D tanımı ile `content/schema/movement-classes.json`'un tanımı FARKLI eksenler
   ölçüyor — isimlendirilmiş sapma, orkestratöre iletildi.
2. **Replay fixture envanteri** — squat+push_up için gerçek, ölçülmüş 6 aşamalı hat var
   (`~/motion-harvest/`, 64 manifest); diğer 29 hareket için sıfır. Darboğaz bu makinede cv2/
   mediapipe eksikliği — PREP kuyruk hazırlayabilir, hasat koşturamaz (ortam kapısı).
3. **Uzman kapısı çerçevesi** — gerçek pazar verisiyle (WebSearch, kaynaklı) iki kademeli
   yeterlilik bar + ücret çıpası + sourcing kanalları taslağı. Hiçbir adayla temas KURULMADI —
   gerçek sözleşme R3 kurucu kapısı.
4. **iCloud build/codesign kontrolü** — symlink doğru (`build → ~/gravita_buildout`, iCloud
   dışı), tuzak YOK; küçük bir belge-yolu tutarsızlığı bulundu ve memory'ye düzeltildi (fiilen
   aktif codesign wrapper `~/.local/bin/` değil `/opt/homebrew/bin/`da).

Detay: `workspace/DEFTER.md` G-260…G-264. Slot beklenirken PREP kadansında (/loop) devam.

## 2026-08-07 — GECE İNŞA TURU: 3 ekran → 8 yüzey · kütüphane 2 → 31 hareket

`main = d631b55`, 0/0 temiz, 4 commit push'landı. Kabuk **79/79** (61'den),
motor **128/128**, `analyze` temiz, dört içerik kapısı da TEMİZ.

**Ne inşa edildi:** dört sekmeli navigasyon kabuğu (Today · Library ·
Progress · Profile) + nöbetli seans düğmesi · Home · Library (arama +
9 aile) · Hareket sayfası (W0 §2'nin 9 bloku) · "Neden yok?" sayfası ·
Profil. Kullanıcı artık kataloğun tamamını görüyor — önceki hâlde 31
hareketin 29'unu gösterecek ekran YOKTU.

**İçerik:** `library.json` 2 → **31 hareket** (koordinatör hükmü: katalog
hazırlık havuzu, kütüphane kullanıcı-gerçeği). Terfi ölçütünü (precondition
derived + replay fixture + eğitmen kaynağı) yalnız `push_up` geçiyor; kalan
30 `coming_soon` ve her biri KENDİ blokerlerini isimli taşıyor. 30 bekleyen
hareketin `precondition.rationale`'ı da tek kopyala-yapıştır paragraftan
hareket-özel isimli gerekçeye çevrildi.

**Dört üretim aracı, dördü de `--check` drift kapılı:** `promote_library.py`
(katalog→kütüphane, kapsam+drift) · `build_exclusions_page.py` (kullanıcı
altkümesi; iç Türkçe alanlar uygulamaya GİRMİYOR) · `build_skill_tree_index.py`
· `name_preconditions.py`. Kütüphane denetçisine ÜÇÜNCÜ bloker anahtarı
eklendi (`provenance.sources:empty`) — self-test 20/20, sayı artık sayaçtan.

**Cihaz kanıtı:** iPhone 16e sim (390pt, mevcut en dar cihaz). Library'nin
kritik kısıtı ekranda doğrulandı: *"leg press"* → boş sonuç DEĞİL, iki
gerekçeli bölüm. Hareket sayfasında dürüstlük kutusu üst yarıda, esnek
yükseklikte, "Nothing yet" onurlu hâliyle; sahte iskelet-avatar YOK.

**8 bulgu DEFTER'de (G-121…G-128).** Üçü kendi çıktımda, ikisi cihazda,
biri devir notunda (katalog 28 değil **31**; tasarımın "31/9" iddiası
kataloğa TAM oturuyor).

🔴 **Açık kök:** `google_fonts` fontları paketlenmiyor → test paketi bu
makinenin önbelleğine bağımlı; temiz makinede/CI'da MEVCUT testler de düşer.
Semptom alındı, kök koordinatör kuyruğunda (paketleme + OFL lisans kararı).

⏸️ **Koordinatör kararı bekleyen:** beceri ağacı çizimi (iki paket de DRAFT
eşikli) · "yet" sözcüğü M-F-186 kapsamında mı (mevcut onaylı metin kullanıyor)
· 5-faz canlı seans modeli · kamera önizlemesi.


> 🔒 **VARDİYA MÜHÜRLENDİ 2026-08-06.** origin'le senkron, çalışma ağacı
> temiz (push bekliyor), açık dal/merge/kırmızı kapı YOK. Yeni oturum için
> TEK devir kaynağı: **`ventures/gravita/workspace/YENI-OTURUM-PROMPT.md`**
> (bekleme-modu bloğu artık ESKİ — giydirme turu KAPANDI) — başka hiçbir
> dosyayı taramadan oradan başla.
>
> ⚠️ **AÇIK RELEASE-GATE: cihaz günü.** Kamera entegrasyonu KOD olarak bitti
> ve iki platformda derlendi, ama gerçek kamera + MediaPipe çıkarımı
> ÖLÇÜLMEDİ. Hiçbir beyan "cihazda kanıtlı" demez.
>
> ✅ **Kart malzemesi KAPANDI (2026-08-06): kurucu CAM KALSIN dedi**
> (`DESIGN-AHEAD-OF-CODE.md` §3.1) — brief §1 "cam değil" satırı süpersede;
> token yine `theme.dart`'ta TEK adreste (hijyen, karar değil).
> 🆕 **Açık uç: Hareket ekseni doğrulanamadı** (ne dosyada sayı var ne kodda
> uygulama) — kardeş-ayrışması artık 5 eksende, 3'ü sıkı kanıtlı.

## 2026-08-06 (kırk ikinci tur) — M-F-282: GİYDİRME (design panel v1)

Koordinatör görevlendirdi: `claude.ai/design` projesi `6ccaab1e-…`'i içe
aktar, **önce** IA deltasını ölç ve DUR. Ölçüm: design 10 ekran tipi/21 kart
(`GravitaScreen.dc.html`'in kendi `screen` enum'u kapalı), kodda gerçekte 2
ekran + 1 hata yüzeyi. Onboarding/kalibrasyon/ilk-değerlendirme design'da da
YOK (3 dosya çapraz doğrulandı). Koordinatör hükmü: yalnız var olan 3 yüzeyi
giydir, 8 eksik yüzeyi + 5 fazlı seans modelini İNŞA ETME.

`lib/app/theme.dart` yeni (Choreia `theme.dart` deseni): `GravitaColors` ·
`GravitaType` (Public Sans + Roboto Mono, `google_fonts` eklendi) ·
`GravitaCard` · `GravitaPill` · `GravitaTheme.light`. **Kart malzemesi
(cam/blur) TEK token'da izole** (`GravitaMaterial.cardBlur/.cardSaturation`)
— brief "cam DEĞİL" diyordu, delivered dosya cam getirdi (§6/M-F-282
çelişkisi); koordinatör hükmü: cam OLDUĞU GİBİ uygulandı, kurucu kararı
bekleniyor, token tek satırlık geri-dönüş sağlıyor.

Üç yüzey giydirildi (YAPI/Key/davranış AYNEN, yalnız görsel katman):
`progress_view.dart` (measured/locked/notes → kart, `HistoryUnavailable`
çıplak Text'ten "sealed" karta yükseltildi) · `live_session_screen.dart`
(4 gerçek hâl — Idle/Starting/Failed/Running — koyu zemin + açık alt-sayfa;
5 faz UYGULANMADI, sahte kamera/skeleton/confidence UYDURULMADI) ·
`content_failure_screen.dart` (panelde karşılığı yok, kendi dürüstlük dilimle
tasarlandı, davranış korunarak).

İki Flutter kısıtı test koşumunda/kod-okumasında yakalandı: (1) `Border` +
`borderRadius` birlikte TEK-RENKLİ olmak zorunda — sealed kartın üst-vurgusu
Border'dan ayrı düz dikdörtgene taşındı, 10 test bunu yakaladı; (2)
`boxShadow` `ClipRRect` İÇİNDEyken kırpılıyor — dışa taşındı.

Kapılar: `flutter analyze` temiz · kabuk **61/61** · motor **128/128** ·
`validate_library` TEMİZ+19/19 · `validate_catalog` 0 hata · replay
**8 ateşlenen/0 ölü**. Ekran kanıtı: iPhone 17 Pro Max simülatöründe GERÇEK
içerikle koştu — en uzun gerçek metin (`push_foundations.form_check`
kilit-gerekçesi, ~400 karakter) taşmadan/kırpılmadan render oldu; koyu
seans ekranı kontrast hatası (ilk taslakta beyaz-üstü-beyaz) koşum ÖNCESİ
kod-okumayla yakalanıp düzeltildi, sonra ekranda doğrulandı.

Ayrıca ölçüldü (delta değil, bulgu): `library.json` kullanıcıya açık **2
hareket** taşıyor, motor-seviyesi katalog (`content/catalog/`) **28**
tanımlı — design'ın "31 hareket/9 aile" iddiası ikisiyle de tam örtüşmüyor.

`docs/design/DESIGN-AHEAD-OF-CODE.md` + `PLACEHOLDER-REGISTER.md` yeni
(ikinci dosya bu turda BOŞ — placeholder yok, gerekçesi yazılı).

**Koordinatöre 4 açık soru iletildi, cevaplandı ve uygulandı** (bu turun
hükümleri yukarıda). Kurucu hükmü BEKLEYEN tek kalem: cam/düz-kart kararı.

## 2026-08-05 (kırk birinci tur) — G-120: KAMERA ENTEGRASYONU

Kurucu direktifi: cihaz günü tek sefere ertelendi, kamera ŞİMDİ bağlandı.

Pin `f13bdc9` (core 0.11.0 + camera 0.1.2, tek commit). Canlı zincir kuruldu:
`frames()` → `EnvelopeDriver` → `OrientationAwarePoseSource` → `RepEngine`.
`LiveSessionRunner` ekrandan ayrı, **kamerasız ama taklitsiz** test ediliyor
(gerçek driver/source/engine; sahte olan yalnız zarfın kaynağı).

İki eski nöbet kırıldı ve yerine geçen kuralla değiştirildi (silinmedi):
tag-regex → TAM-40-SHA, "kamera yok" → üçlü pin eşitliği.

Testler 40 → 59. Süit bir kez beni yakaladı: "sığ tekrar" dizim aslında
derin bir tekrardı (ara basamak dip eşiğini geçiyordu) — motor haklıydı,
testim kırıktı.

Platform duvarları: iOS 13→14, `use_frameworks! :linkage => :static`
(MediaPipe statik xcframework), CocoaPods UTF-8.

Kamera form-notu dersini AÇMADI — kilit ölçüm eksikliğinden geliyor (G-094).



## 2026-07-30 (gece, otuz sekizinci tur) — G-104: damga kondu, eşik ERTELENDİ

Koordinatör hükmü (c): işaretle, zorlama. `Rep.identityGapShare` rapor-only.

Ölçüm hükmü DOĞRULADI ve fazlasını verdi: damga, ikili bayraktan **6,8× daha
iyi ayırıyor** (p90 0,832 vs 0,123; bayrak yalnız 1,8×). Ve ayırma KUYRUKTA —
medyan da maks da ayırmıyor. Yani eşik bir gün konacaksa kuyruk
istatistiğinden konacak; ortalamaya bakan bir eşik bu ayrışmayı görmezdi.

Reçeteye SINIF C yazıldı (157→209 satır): "kapı popülasyon düzeyinde tutar ama
granülerite iddiasıyla uyuşmaz".

118/118 motor · 33/33 kabuk · self-test 15/15 · replay 0 ölü · iOS sim ✓.
Gravita hattı bu vardiya için TEMİZ. `5f37fe4`

## 2026-07-30 (gece, otuz yedinci tur) — aile-kuralları hizalaması (G-101/102/103)

Üç kalem, üçü de main'de.

**G-101 SessionStore adopsiyonu:** yerel port silindi, çekirdek 0.9.0. Silinen 15
testi varsaymadım, SAYARAK doğruladım (hepsi çekirdek süitinde). İki davranış
değişikliği çivilendi — `isComplete` artık ATTEMPTED sayıyor (benim portum PRD
§3.4 ile çelişiyordu) ve `lessonClass` açık sözlük olduğu için
`measurementOnlySessions` → `unscoredSessions`. Anahtar-kümesi nöbeti bu
yeniden-adlandırmayı adıyla yakaladı.

**G-102 dürüst hata ekranı:** JabLab'dan uyarlandı. Delta: `HistoryFailure` —
çünkü kodum yalan söylüyordu (geçmiş okunamazsa yüzey "Not started" diyordu =
"hiç çalışmadın"). İki kendi hatam kayıtta; ikincisi öğreticiydi: kablolama
testim ürünün kablolamasını değil kendi TAKLİDİNİ sınıyordu.

**G-103 fallback canlılık:** ilk teşhisim FAZLA İDDİAYDI ve reçetenin kendi §4
kapısı beni düzeltti. Hipotezimi de ölçüm çürüttü. Asıl bulgu daha derin:
**kimlik kapısı KARE düzeyinde, iddia TEKRAR düzeyinde** — bir tekrar,
aralarında yüzlerce kapısız kare olan parçalardan birleşebiliyor (%36 sözlük-dışı,
%19,6 KONTROLDE de → genel granülerite açığı). Salt rapor; zorlama koordinatörde.

118/118 motor · 33/33 kabuk · self-test 15/15 · replay 0 ölü.

## 2026-07-30 (gece, otuz altıncı tur) — G-100: app kabuğu CANLI (iki platform)

Gravita artık bir uygulama. iOS simülatör `.app` + Android debug APK derlendi,
kabuk iPhone 17 Pro Max simülatöründe GERÇEKTEN koştu ve dürüst yüzeyi gösterdi
(ekran görüntüsü `app/docs/gates/`).

Motor/kabuk ayrımı korundu: veri katmanı motorda kaldı, kabuk yalnız "nereden
okunur"u cevaplıyor. `path_provider` kablolamada — uçtan uca test platform
kanalına hiç dokunmadan koşuyor (terfi şartı #1'in somut faydası).

⚠️ İki ders, ikisi de pahalı ve ikisi de nöbetçili:
1. Uçtan uca testin ilk hâli 10 dk ASILDI (FakeAsync bölgesinde gerçek G/Ç) →
   `tester.runAsync`. Sahte-async bölgede gerçek iş = ÖLÜ test.
2. **18 test yeşilken simülatör iki kusur gösterdi:** ekranda ders adı yerine
   kimlik, ve boş bir "Notes" başlığı. Testlerim `lessonId`yi iddia ettiği için
   kimliğin sızmasını kutsamışlardı. Aile dersi önerisi: **"testler yeşil ≠
   kullanıcı doğru şeyi görüyor"** — G-095'in bir adım ötesi.

Ayrıca iCloud/codesign tuzağı: `build/` iCloud DIŞINA symlink şart.
18/18 + 121/121 · `e0b89ab`

## 2026-07-30 (gece, otuz beşinci tur) — G-099: kalem 3 veri katmanı + dalga-körlüğü

İlerleme yüzeyinin veri katmanı TAM. Üç kural (ölçüm-değil-not · geçilemez-kapı
beyanı · retroaktif kredi yok) yorum olarak değil ALAN/TİP olarak taşınıyor;
anahtar kümesi teste çivili, yani "skor koymayacağız" sözünün canlı bir bekçisi
var.

`unitLabel`in üreticisi yoktu — katalog oldu (kapsayıcı switch: yeni motor tipi
DERLENMEZ). Yüzey listesi artık gerçek library.json+katalogdan TÜRETİLİYOR.

⚠️ Aynı DALGA-KÖRLÜĜÜ üç yerde çıktı: smoke test + validate_library + kendi
delta sayımım hepsi `w1` okuyordu; katalog 31 hareket. Üçü kapatıldı, W2'nin 11
hareketi sorunsuz yükleniyor. Ders: **bir kapı DOĞRU olup KAPSAMI dar olabilir;
dar kapının çıktısını ölçüm olarak alıntılamak hatayı çoğaltır.**

Widget: Gravita'da Flutter paketi YOK → kapsam kararı koordinatörde.
121/121 test · self-test 15/15 · replay 0 ölü. `8b8c1f5`

## 2026-07-30 (gece, otuz dördüncü tur) — G-098: enjeksiyon dikişi (ve dikiş kendini kanıtladı)

G-095'in yapısal panzehiri kuruldu: `probe(detector=...)` + `main()`→`scan(...,
clip_probe=...)`. İkisi de varsayılanda üretim davranışını değiştirmiyor; ama
orkestrasyon katmanı artık mediapipe/cv2 OLMADAN uçtan uca koşulabiliyor —
`reports` NameError'ının tam olduğu katman.

⚠️ **Dikiş işini İLK KOŞUMDA kanıtladı:** parametreyi `out` diye adlandırmışım
ve gövdedeki rapor sözlüğü olan yerel `out` ile gölgelenmiş → TypeError. Uçtan
uca test hemen yakaladı; `out_path`e çevirdim ve tuzağı koda not ettim. Aynı
sınıftan ikinci hata, bu kez üretime gitmeden.

Uçtan uca test 7/7 (mediapipe gerektirmez), regresyon kontrolü 11/11.
Dal: `feat/rig-probe-injection`.

## 2026-07-30 (gece, otuz üçüncü tur) — G-097: SessionStore portu + üç delta (üçüncü tüketici)

⚠️ **Choreia'nın "port yapılamaz" hükmünü ölçümle düzelttim:** JabLab'ın
`JsonlSessionStore(this._file)` yalnız bir `File` alıyor — Flutter bağımlılığı
YOK; `path_provider` sadece çağrı yerinde. Depo saf Dart → Gravita'nın Flutter
app'i olmamasına rağmen port bugün yapıldı ve test edildi.

**DELTA 1 (en güçlü katkı):** birim etiketi **kayıt-başına** olmalı, app-başına
değil. Choreia etiketi app düzeyinde örneklemişti; Gravita katalogda 14 repFsm
(tekrar) + 5 staticHold (**saniye**) taşıyor — aynı app içinde iki birim, aynı
ekranda "3 of 5 reps" ile "45 of 60 seconds" yan yana. Ayrıca staticHold'da
`unitsCompleted`=`workedSeconds` dejenerasyonunu terfi gününe not düştüm.

**DELTA 2:** `lessonClass` — Choreia ile bağımsız yakınsama. Ders sınıfı ölçüm
geliştikçe terfi ediyor (G-091), kayıt yazıldığı günün sınıfını taşımalı.

**DELTA 3 (Gravita-özgü):** ölçülemeyen birimler kaydedilmeli. PRD §3.4
"ilerleme düşmez" sözü; JabLab kaydında bunu söyleyecek alan yok.
`unmeasuredUnits` + `attemptedUnits`.

JabLab'ın 12 arıza testi port edildi + 4 delta testi → 15/15, toplam **92/92**.
Çekirdek-terfi önerisini tek taraflı YAPMADIM.

## 2026-07-30 (gece, otuz ikinci tur) — G-096: K9 kilit izlenebilirliği + bir varsayım düzeltmesi

⚠️ Paket "squat(temiz-tabanlı) için kurslar" diyordu; **ölçtüm ve squat hâlâ
kurs alamaz:** `precondition.status` = `pending`, `conditions: []` — rebuild
bunu değiştirmedi (temiz referans kimlik ön koşulunu türetmiyor) + replay
fixture hâlâ yok. Blokerler REFERANS değil KİMLİK+KANIT. Kurs eklemek yerine
raporladım.

**K9 (yeni değişmez):** kilitli ders `lockClass: measurement` + `blockedBy[]`
taşımak zorunda; her bloker DOĞRULANIR ve **artık bloklamıyorsa "BAYAT KİLİT"**
hatası verir. `lockClass: structural` reddedilir — yapı/ekran kilidi ölçüm
kilidi gibi sunulamaz. Gerekçe: bir kilit sebebi ölünce sessizce durabilir —
"okuyanı olmayan beyan"ın aynası.

5 yeni negatif test, self-test **15/15**. Bayat-kilit vakasını kurarken ilk
denemem ölü testti; gerçek vaka `precondition!=derived` blokerini push_up'a
(status=derived) vermekle kuruldu.

## 2026-07-30 (gece, otuz birinci tur) — G-095: iki öngörüm de çürüdü + koşum-yolu hatam

**Kendi hatam:** v2 refaktöründe `reports` başlatması düşmüş → ilk gerçek
koşumda NameError. Sözleşme testlerim ayırıcının matematiğini sınıyordu,
`main()`'i sınamıyordu ve bu makinede o yol hiç çalıştırılamıyordu.
**Ders: "testler yeşil" ≠ "kod koşuyor"** — gece boyu avladığım "beyan ≠ canlı"
sınıfının kendi kodumda tekrarı.

**İki isimli öngörüm de tutmadı:**
- `X0qC1k0Zi6k` (gözle AYNA) → "gerçek ikinci kişi" okundu. Sebep: sentetik
  ayna modelim yalnız görüntü-düzlemine PARALEL aynayı kapsıyor; gerçek salon
  aynası AÇILI, yansıma farklı bir 3B projeksiyon — 2B flip değil.
- `0KtrNQre5rQ` (gözle iki kişi) → "AYRIM YOK". Sebep: ikisi de squat yapıyor,
  squat simetrik duruş. **Kapı-testimde beyan ettiğim "simetrik duruşta
  ayırt edilemez" sınırı, squat malzemesinde kenar durum değil BASKIN durum.**

Hüküm: ayırıcı rapor alanı olarak kalıyor (asimetrik malzemede çalışıyor) ama
squat-sınıfında yapısal kör → o sınıfta göz tek güvenilir sınıflandırıcı.

İronik: kapı-testimin en önemsiz sandığım üçüncü vakası, gerçek veride baskın
dal çıktı.

## 2026-07-30 (gece, otuzuncu tur) — G-092 sonda v2 + G-093 yetim karantinası

**Sonda v2** dalda (`feat/rig-second-person-v2`): payda manifestli kliplere
sınırlandı · yetimler `orphans:[...]` ile ayrıca raporlanıyor · **AYNA
ayırıcısı** eklendi (yansıma aynalanmış+eşzamanlıdır → aynalanmış vs takassız
şekil mesafesi, İKİ ölçü birlikte çünkü tek sayı ayna ile iki-kişi-paralel'i
ayırt edemez).

⚠️ **Ölçüyü iki kez ölçümle düzelttim:** (a) ilk benzerlik formülüm
`max(0,1−mesafe)` her vakada 0'a kırpılıyordu — ölü ölçü; ham mesafeye
geçtim. (b) ilk sentetik vakam sol/sağı düzgün kaydırıyordu, o şekil hâlâ
ayna-simetrikti → test ölçtüğü şeyi ayırt edemiyordu. Ders: sentetik vaka,
ölçtüğü şeyi gerçekten ayırt etmeli.

Kapı testi 4/4 (mediapipe gerektirmez), simetrik duruşta "ayrım yok" demesi
dahil — kusur değil, gerçek sınır.

**G-093:** 9 yetim `raw-orphaned/`e taşındı (silinmedi) + README. `raw/` artık
35 mp4 = 35 manifest. Taşımadan önce doğruladım: 8'inin squat havuzunda kendi
kopyası var (biri squat referansına 13 take veriyor), tek gerçek evsiz
`LszCaPOFWHg`.

⚠️ Sonda v2 ölçümü bu makinede koşulamaz (cv2+mediapipe yok) → koordinatörde.

## 2026-07-30 (gece, yirmi dokuzuncu tur) — ⭐ G-091: rebuild + G-050 kısmi kapanış

Squat referansı 6 barbell take'i ADIYLA dışlanarak yeniden kuruldu.

**Kalıcı hüküm kaydı kuruldu** (Choreia deseni): dışlamalar
`decisions.bodyweight_squat.json`'da yaşıyor ve **build onu OKUYOR** — elle
artefakta yazılsa regen'de kaybolurdu. **İki kapı kurdum ve ateşlendiğini
sınadım:** kayıt yoksa `exit 78`, kayıt bayatsa (dilim adı değişmişse) yine
`exit 78`. İkisini de sahte veriyle denedim, ikisi de yakaladı.

**ÖNCE → SONRA:**
- medoid `Jeff_Nippard_w13_r0` (107 kare, **198 kg barbell**) → **`THENX_w3_r2`
  (38 kare, dürüst bodyweight)**
- contributingTakes 36→25 · sources 6→5 · meanAgreement 0,685→0,682 (aynı)
- **capFillShare medyanı 0,9231 → 1,0000** — koordinatörün öngörüsü birebir
- mirrorAgnostic false (değişmedi)

⭐ **G-050 bilmecesi KISMEN KAPANDI:** varyans-türetimli taraf 9→14, taban-bağlı
8→3. Çift düzeyinde **kalça ve uyluk artık ölçülmüş eğitmen-varyansından
geliyor** (önce dördü de KOL eklemiydi). Yani barbell kirlenmesi bacak
eklemlerindeki gerçek varyansı MASKELİYORDU. Diz/baldır/gövde hâlâ taban-bağlı.

Bit-özdeşlik bozuldu — doğru olan bu, hizalama tabanı düzeldi.

Kullanıcı metnini de güncelledim: "bacakların hepsi taban-bağlı" ifadesi artık
yanlış olurdu.

## 2026-07-30 (gece, yirmi sekizinci tur) — G-090: anatomik mod ayağı LEHTE kapandı

G-078'de açık bıraktığım bacak kapandı: **kopyalama imzası anatomik modda da
aynı işaretle duruyor.** push_up POZİTİF (kamera 8,6→22,7 · anatomik
6,1→25,2) · squat NEGATİF (45,3→12,0 · 37,6→11,5). İki hareket anatomik modda
da zıt yönde ayrışıyor → anatomik varsayılan bu teşhis yeteneğini maliyet
olarak almıyor.

Ek gözlem anatomik lehine: orta bantlarda sahte asimetri belirgin azalıyor
(push_up 0,4-0,6: 31,2°→18,0°, %42) — projeksiyonun amacı tam bu. Yani sahte
asimetri azalıyor, teşhis sinyali kalıyor. Karar kurucuda.

Yöntem: sol metrik tanımı icat edilmedi — Lissom'da yalnız `_right` var ama
`"mirror": true` beyanı taşıyor, sol ikiz landmark adları çevrilerek kuruldu.

⚠️ Bant nüfusları iki havuzda karşılaştırılabilir değil (squat düşük-uçta 183
örnek, push_up 13k) — sebep: ham vs dilimli havuz + bu probe yalnız bacak
zinciri üzerinden koşullandırıyor. Karşılaştırılabilir olan eğilimin YÖNÜ.

## 2026-07-30 (gece, yirmi yedinci tur) — ⛔ G-089 P0: referansın medoidi 198 kg barbell squat'ı

Koordinatörün "beyan değil doğrulama istiyorum" talebi haklı çıktı.

**(a)** Göz-triyajının üç barbell klibi take düzeyinde doğrulandı: **katkı 0** ✅

**(b) Ama işaret taraması ÜÇ YENİ klip buldu, üçü de katkı veriyor** —
göz-triyajı onları görmemişti (ikinci-kişi sondasında düşük oranlı: tek kişi,
ayna yok). 36 katkı take'inin **6'sı (%17)** barbell kliplerinden.

Gözle doğruladım: `sdeQjm7avi8`'te ekranda **"SQUAT [TOP SET] 435 LBS
(198 KG) × 3 REPS"**, kemer, rack, walkout/pin-squat bölümleri.

⛔ **Ve MEDOİD bu klipten:** `Jeff_Nippard_w13_r0`. Medoid tüm referansın
hizalama tabanı — `bodyweight_squat` referansının tabanı 198 kg'lık bir triple.

**M-F-155'in "yavaş medoid" bilmecesi çözüldü:** 198 kg triple yavaştır →
medoid 107 kare + capFillShare 0,444 + bacak toleranslarının taban-bağlılığı,
üçü tek kök nedene bağlandı.

**Kirlenme ölçülebilir biçimde bozuyor** (dip anında): barbell gövde eğimi
−4,8° / diz 77,7° · diğerleri +3,4° / 59,5° → **gövde farkı 8,2°** (tolerans
tabanı da 8°) ve barbell tekrarları **18,2° daha sığ**.

Artefakta dokunmadım; rebuild kararı koordinatörde, 6 take adıyla hazır.

## 2026-07-30 (gece, yirmi altıncı tur) — G-088: minPhaseMs bağlandı, kendi iddiamı düzeltti

Dördüncü ölü-config vakasına tüketici verildi: `phasesBelowMinMs` +
`phasesCounted` sayaçları. **Zorlama YOK** (G-054 koruması). Şema açıklaması
tek adreste gerçeğe çevrildi ("RAPORLANIR, ZORLANMAZ").

İki test dengeyi kilitliyor: taban altı fazlar sayılıyor AMA tekrar
reddedilmiyor · taban üstünde sayaç sıfır kalıyor (sahte alarm yok). 77/77.

⚠️ **Ölçüm G-081'deki kendi iddiamı düzeltti.** Orada "mevcut kontaminasyon
YOK" demiştim — o iddia TAKE süresine bakıyordu ve take düzeyinde doğruydu.
Ama fazlar take'in İÇİNDE: **push_up %3,8 (12/314) · squat %7,0 (59/840)
faz taban ALTINDA.** Yanlış granülerite, yanlış güvence — "take tabanı
geçiyor" ≠ "her faz tabanı geçiyor". Zorlama kararı artık bu dağılıma
dayanabilir.

## 2026-07-30 (gece, yirmi beşinci tur) — G-087: göz triyajı üç düzeltme + iki yeni bulgu

Koordinatörün koştuğu num_poses=2 sondasının 7 adayını gözle sınıfladım
(ffmpeg, 9 kare/klip).

**Düzeltme 1:** 7 değil **5** aday — iki push_up adayı `gravita/raw`'daki
**9 yetim mp4**'ten (manifest yok, aslında squat klibi, G-057 karışması).
Referans temiz (yetimler `landmarks/`'a hiç girmemiş) ama sonda onları saydı.
Manifestli push_up kliplerinde `>0,3` aday YOK. **Sayım mutabakatı benim
hatam:** "79+61 klip" dedim, `ls|wc -l` saymışım — 79 = 44 mp4 + 35 info.json.

**Düzeltme 2:** ⚠️ görünürlük paritesi "gerçek kişi" kanıtlamıyor —
`X0qC1k0Zi6k` tek kişi ama salon **AYNALARI** karede. Ayna yansıması
landmark görünürlüğü bakımından gerçek insandan ayırt edilemez. Kıyas tabanı
leke/poster'ı eliyor, **aynayı elemiyor.**

**Sınıflar:** `H1H1WKSm5CU` (0,82) **ASİSTANLI DEMO gözle kesin** (eğitmen
çubuğu omurgaya dayıyor, "PT TIPS") — advisor'ın sınıfının ilk doğrulanmış
vakası · `0KtrNQre5rQ` iki-kişi egzersiz (yeni risk: denek-kayması) ·
`my0tLDaWyDU` eş-sunucu konuşma · `X0qC1k0Zi6k` ayna · `-W19J4VR7D0` tek kişi.

**Yeni bulgu:** 3/5 adayda **yüklü BARBELL squat** — havuz `bodyweight_squat`,
ikinci-kişiden bağımsız bir kirlenme sınıfı, hiçbir kapı sormuyor.

**Yakınsama:** 3/5 aday G-067'nin zaten işaretlediği kaynaklar. FitnessFAQs'ın
n=10 thinEvidence şerhim doğruydu — sebebi artık belli: klip barbell squat.

## 2026-07-30 (gece, yirmi dördüncü tur) — G-085 pin 0.8.8 + G-086 bayat-yokluk taraması

**G-085:** pin `v0.8.8` (`03ff936`). Beşinci bit-özdeşlik (push_up 21 · squat 23
alan). `medoidTakeId` çekirdeğe girdi ve **G-082'de kare-eşitliğiyle
geri-mühendislik ettiğim medoid ile birebir aynı** çıktı (push_up
`K boges#w2 r4` · squat `Jeff_Nippard_w13_r0`) — çıkarımım doğruydu, artık
gerekmiyor. capFillShare uyumu yine 0,00e+00.

**G-086 (M-F-165 bayat-yokluk):** üç havuz tarandı (27+27+234 fixture),
`referenceEligible` alanı olmayan fixture **sıfır**. Sebep G-072'de kurulmuş:
`reclassify_eligibility.py --apply` alanı her fixture'a yazıyor (o turda
push_up'ta 1 alan-yok vakası vardı).

Kendi başıma bir bütünlük denetimi ekledim: muafiyetin `passive` kanıtını
kurtarmadığını doğruladım — `romMode=passive` ama `eligible=True` olan fixture
**0**. Muafiyet yalnız kanıt-yokluğunu kurtarıyor, kanıt varlığını değil.

**Kapılar:** 75/75 · replay 0 ölü · validate_catalog 0 hata · self-test 10/10.

## 2026-07-30 (gece, yirmi üçüncü tur) — G-084: ikinci-kişi sondası (ölçüm bekliyor)

Koruma-1 adım (i) yazıldı: `second_person.py`, `num_poses=2`, SALT RAPOR
(eşik yok, klip reddedilmiyor). Üretim `num_poses=1` kullandığı için ikinci
iskelet hiç görülmüyordu; sondanın tek farkı bu.

Yalnız sayı yetmez diye ikinci pozun KALİTESİNİ de raporluyor ve birinci pozu
KIYAS TABANI veriyor — MediaPipe ayna/poster/lekeyi de ikinci kişi sayabilir,
kıyas tabanı olmadan oran olduğundan yüksek okunur.

Sözleşme testi rig süitine eklendi (mediapipe gerektirmez, 5/5): oran doğru
bölünüyor mu · kıyas tabanı var mı · örneksiz klipte çökmüyor mu ·
num_poses=2 mi · salt-rapor olduğunu beyan ediyor mu (eşik-icadına nöbetçi).

⚠️ **ÖLÇÜM KOŞULAMADI:** cv2+mediapipe bu makinede yok. Ham videolar duruyor
(79+61 klip, 4,6 GB) yani feasible — mediapipe'lı ortamda koşulmalı.
Dal: `feat/rig-num-poses-probe`.

## 2026-07-30 (gece, yirmi ikinci tur) — G-083: pin v0.8.7, capFillShare doğrulandı

Pin `motion_core-v0.8.7` (`07bbeb2`). Çekirdeğe giren `capFillShare` benim
G-082'de önerdiğim formülle **birebir aynı** (fark 0,00e+00, 72/72 take) —
denominatör kare, aynen. Dördüncü bit-özdeşlik: push_up 21 · squat 23 alan
korundu, tek fark yeni alan.

Dağılım: push_up medyan 1,0000 · squat 0,9231 · **0/72 take <0,70** → gerilme
sınıfı hâlâ gözlenmedi.

**Kapılar:** 75/75 · replay 0 ölü · validate_catalog 0 hata · sync "değişiklik yok".

## 2026-07-30 (gece, yirmi birinci tur) — G-081: incelik ayrıştırıldı + raporsuz düşüş

**Ayrıştırma (M-F-155):** tavana-göre doluluk her iki harekette de ~1,0
(push_up medyan 1,000 · squat 0,922; ikisinde 0/36 take <0,70) → incelik
**uzunluk-oranı eseri, gerilme DEĞİL.** Koordinatörün squat öngörüsü tuttu:
medoid 107 kare, take tavan-medyanı 0,491 — yavaş bir tekrar medoid seçilmiş.

**6-karelik take:** "slicer half-cut" hipotezi çürüdü. Süre 1,07 sn (makul);
sebep aralıktaki 33 ham kareden 27'sini benim `judge()` ön-süzgecimin
düşürmesi. Take olduğu gibi kaldı, raporlu.

⚠️ **Asıl bulgu — kendi aracımda raporsuz düşüş:** `takes[].gateDroppedFrames`
yalnız prepareTake'in kendi elemesini sayıyor, benim ön-süzgecimi görmüyordu →
artefakt "0 kare düştü" diyordu. Gerçek: **68 take'te 3040 kare** raporsuz
düşmüş (uçta %76). `$preFilterFrameDrops` ile kapatıldı. Boşluk push_up'a
özgü — squat dilimleyicisi ham kayıtları aynen kopyaladığı için orada eleme
dürüstçe sayılıyor.

**Yan bulgu:** `minPhaseMs` ölü config — ayrıştırılıyor, hiç okunmuyor
(G-059/G-071 sınıfı, üçüncü kez). Mevcut kontaminasyon yok; motor davranışı
olduğu için uygulamadım.

**Kapılar:** 75/75 · replay 0 ölü · validate_catalog 0 hata · sync "değişiklik yok".

## 2026-07-30 (gece, yirminci tur) — G-080: pin v0.8.6, sayılar korundu, kanıt-kalınlığı sürprizi

Pin `motion_core-v0.8.6` (`7f4bf6a`). İki artefakt yeniden üretildi ve
koordinatörün öngörüsü doğrulandı: **push_up 17, squat 21 alan BİREBİR aynı.**
Tek fark yeni `evidenceThickness` bloğu + `gates.agreementGateJoints:"all"`.
(push_up'ın `$windowRule`u da değişti ama yalnız gömülü repo-SHA'sı yüzünden.)

⚠️ **Yeni blok yeni bir dürüstlük sorusu açtı:** `alignedDistinctShare`
squat'ta çok düşük — push_up ort 0,797 / medyan 0,873 iken squat ort **0,480**
/ medyan **0,444**, ve **36 take'in 33'ü 0,70'in altında**. Yani squat
referansının "36 katkı take'i" sayısı etkin kanıt kalınlığını olduğundan
KALIN gösteriyor. push_up'ta ise medyan iyi ama uçta çok ince take'ler var
(en düşük 0,109 = 6 kare).

Eşik icat etmedim; dağılımı raporladım — HIGH-1 eşik-tabanı için ilk gerçek
veri bu.

**Kapılar:** analyze temiz · 75/75 · replay 0 ölü · validate_catalog 0 hata ·
validate_library temiz.

## 2026-07-30 (gece, on dokuzuncu tur) — G-079: metrik ayrıldı, push_up bayrağı düştü

M-F-145 hükmü (seçenek 1+2 birleşik) uygulandı. `meanLeftRightDiffDeg` öldü;
yerine **`takeMeanAbsLRDiffDeg`** (büyüklük) + **`signConsistencyRatio`**
(sistematik tek-yanlılık) geldi. Bayrak artık YALNIZ büyüklükten türüyor.

Hesabı TEK EVE aldım (`MirrorSymmetry`, engine lib) — iki referans aracı da
onu çağırıyor. Aynı formülün iki kopyası bu gece iki kez ayrıştığı için
(kopya-sürüklenmesi) bu bilinçli.

**Yeniden üretilen artefaktlar:** push_up **14,74°** · işaret-tutarlılığı
**0,034** (neredeyse sıfır — işaretli ortalama yalnız 0,51°) →
**`mirrorAgnostic: false`**. squat **32,02°** · 0,216 → `false`
(32,26'dan neredeyse değişmedi: squat sayısı baştan sağlamdı).

`sync_provenance` `$mirrorAgnostic` okuduğu için katalog kendiliğinden
düzeldi. Eşik (7°) yeniden türetilmedi ama isimli not düşüldü.

**Kullanıcı metnini de düzelttim:** "push-ups 5.2 degrees" iddiası
`library.json`'da YAYIMLI kullanıcı metniydi. Artık ikisinin de
ayna-agnostik olmadığı + yanlışın iki katmanı (iptal-eden ortalama +
modelin görmediği uzvu kopyalaması) sade dille yazılı.

**Regresyon testi:** sentetik +20°/−20° take çifti eski kusuru birebir
üretiyor ve bayrağın yine `false` kaldığını kanıtlıyor; küçük gerçek fark
`true` yapıyor (kapı körlük değil). **75/75.**

## 2026-07-30 (gece, on sekizinci tur) — G-078: hipotez doğrulandı + kendi metriğimin kusuru

**Ters-çevirme hipotezi DOĞRULANDI.** Görünürlük-koşullu ölçümde push_up'ta
kopyalama imzası POZİTİF: model uzak uzvu gördüğünde sol-sağ farkı ~36,8°,
göremediğinde **12,75°**'e çöküyor (2,9×). Squat'ta imza NEGATİF (fark
belirsizlikte büyüyor: 33,4°→44,1°) = dürüst ölçüm davranışı.
**push_up'ın küçük farkı simetri kanıtı değil, model körlüğü.**

**Ve doğrularken kendi metriğimin kusurunu buldum.** Probe `mean|L−R|`
hesaplıyor, referansa yazdığım `meanLeftRightDiffDeg` ise `|mean|`. Take
düzeyi vs referans: push_up 19,25° vs 5,16° (**3,73× şişme**), squat 33,13° vs
32,26° (1,03×). Yani yayımladığım sayı bir ayna-simetrisi ölçüsü değil —
büyüklük ile take'ler-arası **işaret tutarlılığını** karıştıran bir bileşik.
squat `false`'ı sağlam; **push_up `mirrorAgnostic:true` dayanaksız kaldı.**

⚠️ O bayrak gece boyu "6 bağımsız kez doğrulandı" diye kaydedilmişti —
**altı koşumun altısı da aynı hatalı işlem sırasını kullandı.** Altı kez aynı
yanlış niceliği hesaplamak onu doğrulamıyor.

Kendim düzeltmedim: `mirrorAgnostic` M-F-46 kural 7'yi besliyor (aile kapısı),
iki düzeltme seçeneği de aile kararı. Hiçbir dosyada değiştirilmedi.

Ayrıca **G-077b:** merge sonrası (main `87e4f84`) scratch rig kopyası
kendini `vendored:true` damgalıyor — bayat-kopya panzehiri Gravita hattında
canlı, doğrulandı.

## 2026-07-30 (gece, on yedinci tur) — G-077: rig SHA damgası (dal, merge koordinatörde)

M-F-135 hüküm 2a: rig artık her hasat çıktısının provenance'ına kendi
sürümünü damgalıyor (`toolVersions.harvestRig = {sha, dirty, vendored}`).

Kopya tespitini SHA'ya bırakmadım — **ölçtüm ve ilk sürümün deliği vardı:**
rig başka bir git deposuna kopyalanıp commit edilirse `rev-parse HEAD` O
deponun SHA'sını döndürüyor, damga *inandırıcı ama yanlış* oluyordu.
Senaryoyu kurup gördükten sonra ikinci kademe ekledim: depo kimliği
içerikten doğrulanıyor (`packages/motion_core/pubspec.yaml` o commit'te var
mı). Şimdi `vendored:true` + `observedSha` ile şeffaf.

Kapı ateşleme testi rig'in kendi süitine eklendi (iki kopya senaryosu, 2/2).

⚠️ Bu makinede cv2 yok → `test_rig.py`nin tamamı koşulamadı; py_compile
temiz, yeni kapı izole geçti, damga uçtan uca doğrulandı. Tam süit merge
öncesi cv2'li ortamda koşulmalı — koordinatöre bildirildi.

Dal: `feat/rig-tool-version` (origin'de, `144b767` üstüne). Merge koordinatörde.

## 2026-07-30 (gece, on altıncı tur) — G-075 üç-probe NULL + G-076 advisor turu

**G-075 / Paket 1b:** koordinatörün istediği kamera-açısı ölçümü yapıldı ve
**M-F-56 kanıt zinciri ÜRETİLMEDİ.** İstenen probe (foreshortening) ham hâlde
r=+0,342 verdi ama alt-küme dayanıklılığı sınayınca **−0,03 ile +0,66 arasında
geziniyor** — 2-4 nokta işareti çeviriyor, yani sayı bilgi taşımıyor
(yordayıcıda varyans yok). Kendi eklediğim iki teşhis de olguyu açıklamadı:
uzuv derinlik-ayrımı NULL (−0,05), kol-vs-bacak kırılımı kısmen açıklıyor ama
bacaklar tek başına 27° (push_up 5,16°'nin 5 katı). **Ders: tek bir `r`
yayımlanmadan önce alt-küme dayanıklılığı sınanmalı.** Sıradaki hipotez soruyu
TERS çeviriyor ("push_up neden yalnız 5°?" — üst üste düşen uzuvlarda model
kopyalıyor olabilir); yeni ölçüm tasarımı olduğu için başlatmadım.

**G-076 / advisor turu:** 18 hareket tek turda hükme bağlandı (12 true /
6 false). Advisor tek denetlenebilir eksen kurdu (özne pasifken gövdenin
ağırlığı yerde mi askıda mı) ve o eksen iki emsali kendiliğinden üretiyor.
`dead_bug`/`bird_dog`ı açmaktan kaçınmam **doğrulandı**.
⚠️ Advisor 6 `false`ın devreye alınmasını iki koruma olmadan önermedi ve
**yeni bir zarar kanalı adlandırdı: "asistanlı ideal postür gösterimi"** —
pasif-ROM değil, "passive" kelimesi içermiyor, `unknown` düşüyor, `false`
verilince referansa giriyor. Koruma 2 (k≥3) **zaten var** (minSources=3;
squat 6 kaynak); koruma 1 (pose ile ikinci-kişi tespiti) **eksik**. Bu yüzden
**politika değerlerine dokunmadım** — 6 hareket fail-closed kaldı, hüküm
kayıtlı, aktivasyon isimli-bloklu, maliyet sıfır (hiçbiri hasat edilmiyor).
7 sınır beyanı + advisor'ın kendiliğinden bulduğu **ters yönlü
kontaminasyon** (gösteren kişi kısıtlı olabilir → referans fazla DAR olur)
uzman envanterine katlandı.

**Kapılar:** analyze temiz · 72/72 · replay 0 ölü · validate_catalog 0 hata ·
self-test 10/10 · rig şema doğrulayıcısı profili kabul etti.

## 2026-07-30 (gece, on beşinci tur) — M-F-122: motor fail-closed + dil kararı

**Hüküm 1 (a — fail-closed) uygulandı.** `RepEngine` artık
`precondition.status != derived` ise tekrar ÜRETMEZ; sebep `refusalReason`da
İSİMLİ durur (sessiz sıfır değil — UI-BRIEF §5 "ölçülemedi" sınıfı) ve
reddedilen kareler `skippedFrames`e yazılır.

**Kapının ısırdığını gerçek hatta ÖLÇTÜM:** düzeltmeden sonra squat slicer'ı
260 yerine **0 tekrar** üretti. ⚠️ O koşum 233 dilim-fixture'ı da sildi;
artefakt git'te güvendeydi, ham fixture'lar sağlamdı, dikiş eklenip yeniden
üretildi (234 dosya). Ders: *fail-closed bir kapı, o kapıdan beslenen ARA
ÜRÜNLERİ de siler — ara ürün git'te değilse yeniden-üretilebilirliği önce
doğrula.*

**Yumurta-tavuk çözümü açık DİKİŞ, muafiyet değil:** `harvestIdentityAttested`
yalnız hasat araçlarında. Gerekçe kodda: hasat, ön koşulu türetecek malzemeyi
üreten yerdir; squat referansı meşru çünkü malzemesi **take-düzeyi**
hipKneeCoupling kapısından geçti (kare-düzeyi ön koşul yerine take-düzeyi
kanıt — G-039/G-048: farklı sorular, farklı kapılar). Ürün yolunda asla açık
değil. Üç dal da test edildi → **72/72**.

Squat referansı düzeltmeden sonra yeniden üretildi: `generatedAt` dışında
**birebir aynı** — hat tam yeniden-üretilebilir.

**Hüküm 2 (dil):** V1 EN-ONLY kesinleşti; UI-BRIEF §0 karara çevrildi, §7'deki
açık kalem kapatıldı. Tasarıma tek not: metin uzunluğu esnek kalsın (TR ~%20-30
daha uzun) ki v1.x çeviri turu yeniden-tasarım gerektirmesin.

**Kapılar:** analyze temiz · 72/72 · replay 0 ölü · validate_catalog 0 hata ·
validate_library temiz · self-test 10/10.

## 2026-07-30 (gece, on dördüncü tur) — 🎯 ÜÇÜNCÜ REFERANS + push_up ATTESTED

Koordinatör M-F-120 (M-F-113 iptal): sınıf-düzeyi doktrini rig'e uygula.

**Kod yazmak gerekmedi.** Rig'i okudum: mekanizma zaten orada
(`rom_mode.classify(passive_execution_possible=False)` + profil
`movementRomPolicy`). Gerçek sebep **Gravita'nın hasadının BAYAT bir rig
kopyasıyla koşmuş olması** — o kopyada muafiyet mekanizması hiç yok.
Çekirdek değişikliği ve merge gerekmedi.

**Yeni bulgu sınıfı:** paylaşımlı bir aracın scratch kopyası sessizce
bayatlar ve ESKİ kuralı uygular; çıktı geçerli görünür, yalnız kural bir
sürüm gerisindendir.

**İki etkiyi ayrı ölçtüm** (`--pep-override` kontrolü): squat'ta artışın
TAMAMI muafiyetten (4→4 yalnız sınıflandırıcı, →28 muafiyetle); push_up'ta
1 klip kanonik sınıflandırıcının kendi düzeltmesi (Cara Kuykens sahte-pasif
retti). Kapı hâlâ ısırıyor: `romMode:passive` kaynaklar muafiyete RAĞMEN
dışarıda.

🎯 **SQUAT REFERANSI YAYIMLANDI — ailenin ÜÇÜNCÜSÜ.** 233 take / 12 kaynak
kapıya ulaştı (önce 100/3) ve **varsayılan 14°'de kümelendi, genişletme
gerekmedi**: ATTESTED · 36 take / 6 kaynak · 197 adlandırılmış dışlama.
⚠️ M-F-113 uygulanmış olsaydı hata olurdu — dışlanması istenen Strength Side
ve THENX kümenin İÇİNDE.
⚠️ Ama squat BACAKLARI notlayamaz: varyans-türetimli 4 eklem KOL, squat'ın
notlayacağı her eklem (kalça/diz/baldır/uyluk/gövde) taban-bağlı; ayrıca
`mirrorAgnostic:false` (sol-sağ 32,26° — push_up 5,16°) → taraf-bağlı hüküm
YAPISAL olarak yok.

**push_up PROVISIONAL → ATTESTED.** Artefakt geri çekilmedi, provenance
yükseldi. `derivedJoints` yine boş (G-014 açık) → "Body-line check KİLİTLİ"
hükmü aynen geçerli.

**G-073 — kendi kapımda delik:** K7 "bir yerde varyans var mı" soruyordu,
"NOTLADIĞIM yerde var mı" değil. Squat referansı deliği gösterdi (kol
eklemlerinde varyans, bacaklarda yok). Ders artık `gradedJoints` beyan
ediyor; K7 üç dalı denetliyor ve üçü de kasıtlı ihlalle ateşlendi →
`--self-test` **10/10**.

**Kapılar:** analyze temiz · 69/69 · replay 0 ölü · validate_catalog 0 hata ·
validate_library temiz · self-test 10/10.

## 2026-07-29 (gece, on üçüncü tur) — G-071 ders/kurs katmanı + UI-BRIEF

Gece paketinin 2. ve 3. kalemi (ikisi de G-070 kararından bağımsız).

**Paket 2 — ders/kurs katmanı.** `content/library.json` +
`tools/validate_library.py` (Ostinato/JabLab deseni). Kilitli-ders
gerekçelerini ölçüme dayandırırken **ürün tarafında bir kimlik-kapısı
boşluğu buldum:** `rep_engine.dart:194` kapıyı `precondition.isNotEmpty`
ile kuruyor, squat'ın `conditions` listesi BOŞ → **üründe squat tekrarları
hiçbir kimlik kapısı olmadan sayılıyor** (G-043'ün sınıfı squat'ta açık).
`preconditionDerived`'ı yalnız hasat araçları okuyordu; yeni K8 kuralı onun
ürün tarafındaki İLK tüketicisi oldu.

İçerik: push_up **live** (2 ders — "Reps that count" AÇIK, "Body-line check"
KİLİTLİ çünkü 9 eklemin 9'u taban-bağlı) · bodyweight_squat **coming_soon**,
kurs YOK (referans yok + ön koşul yok + hata kuralları gerçek veride hiç
ateşlenmemiş). 8 değişmez; **`--self-test` 8/8 kapıyı kasıtlı ihlalle
ateşledi** + taban-temiz ön kontrolü.

**Paket 3 — UI-BRIEF.** `docs/design/UI-BRIEF.md`: 11 ekran (onboarding 5
adım → kalibrasyon → assessment → Home/Library/Movement/Course → canlı seans
→ özet → Progress/skill-tree → Profile), 9 zorunlu durum tablosu (boş ·
yükleniyor · hata · izin-reddi · **ölçülemedi** · düşük-güven · kilitli ·
referans-yok · kısmi-ölçüm), metin akış diyagramı, marka tonu ve **tasarımın
ihlal edemeyeceği 8 ölçülmüş kısıt** (tek genel skor yok · tek düzeltme ·
düşük güvende cue yok · ölçülemedi≠başarısızlık · dürüstlük kutusu üretilir ·
güvenlik kapıları kırpılamaz · aspirasyonel düğümler rozetsiz · ses birincil).
⚠️ Dil: PRD §7 V1'i `en`e bağlıyor; brief TR, kullanıcı metni EN — TR ürün
dili kapsam kararı, koordinatöre not düşüldü.

## 2026-07-29 (gece, on ikinci tur) — G-070: kendi teşhisimi geri çektim

Gece paketi 1 (M-F-113 seçenek c) uygulanırken **G-069'un teşhisinin yanlış
olduğu ortaya çıktı** ve paket durdu.

Koordinatörün hükmü "referansı kümelenen 9 kaynaktan kur" idi. Uygulama
`ArgumentError: pool thinned below gates — 135 fixture → 2 usable take /
1 source` verdi. Sebebi araştırınca: **o 9 kaynağın hepsi rig-uygunsuz**
(`referenceEligible:false`) ve M-F-47 anlaşma kapısına **hiç ulaşmıyorlar**.
Kapıya yalnız 100 take / 3 kaynak ulaşıyor — ve G-069'un "sapan" dediği 100
take, o uygun setin **birebir tamamı** (küme kimliği betikle sınandı, fark
iki yönde de boş).

**Doğru bulgu:** squat'ta yalnız 3 rig-uygun kaynak var (27 ham fixture'ın
YALNIZ 4'ü `eligible`) ve üçü birbiriyle ne 14° ne 30°'de anlaşıyor.
Konsensüs dar değil — YOK.

**Hatamın kökü:** `excludedOutlierIds`'i okudum, `excludedIneligibleIds`'i
okumadım. G-059'un beşinci canlılık sorusunu ("bu kapıya soran var mı?")
kendi teşhisime uygulamamışım. Kod arkeolojisi için koşturduğum alt-ajan
aritmetiğin tutmadığını açıkça bayraklamıştı — o dürüst uyarı olmasa yanlış
teşhis daha uzun yaşardı.

**Yan bulgu (aynı app, ZIT disiplin):** yayımdaki `reference.push_up.json`
uygunsuz malzemeyi `unattested`a çevirip PROVISIONAL ile kabul ediyor
(`canonical_push_up_reference.dart:39-44`, bilinçli ve belgeli); squat
slicer'ı bayrağı koruduğu için fail-closed reddediyor. M-F-43'ün kendi
gerekçesi bu yolu uyarıyor ("provisional sistematik yanlılığı örtmez").

**Muhtemel kök neden (ölçülmedi, aile geneli olabilir):** rig `romMode`'u
metinden sınıflandırıyor; fitness tutorial'ları AROM/PROM kelimelerini
kullanmadığı için push_up 24/27 + squat 23/27 `unknown` → kanıt-yokluğu
uygunsuzluk kanıtı gibi davranıyor.

Üç seçenek koordinatöre bildirildi, hiçbiri tek taraflı uygulanmadı;
`reference.bodyweight_squat.json` YAZILMADI. Paket 1'in kalanı (sapma
profili) bu karara bağlı — bekliyor.

## 2026-07-29 (devam, on birinci tur) — G-069: squat referansı kümelenme kapısında KİLİTLENDİ (⛔ teşhis G-070'te geri çekildi)

Koordinatör yeşil ışığı (M-F-106): 12 PASS eğitmenin rep-FSM-dilimli
take'leri (233 fixture) → kanonik CLI → squat'ın İLK ürün referansı,
`identityGateBasis`+`minAcceptedR` beyanlarıyla. `minAcceptedR=0,274`
(eşik 0,2'nin 0,074 üstünde) hesaplandı, beyan hazırdı.

`ReferenceCli.buildArtifact` **varsayılan 14°'de** `ReferenceAgreementError`
verdi: 98 take sapıyor, TAMAMI 3 kaynaktan (Strength Side 30/30, THENX
68/68 — havuzun en büyük tek kaynağı, Tom Merrick 2/11). **G-050 deseni**
uygulandı — kapı 30°'ye (2×) çıkarıldı, **AYNI 3 kaynak AYNI sapma
dereceleriyle YİNE reddedildi**. push_up'ın G-050 bulgusunun tersi: orada
genişletme dağılımı değiştiriyordu (kapı etkisi), burada HİÇ değiştirmedi
(malzemenin kendisi olabilir). Kodlama hatası değil — `dart analyze` temiz,
sapma iki toleransta birebir aynı.

**45°/60° ile körlemesine devam EDİLMEDİ.** Araç `exit(1)` ile durdu,
`reference.bodyweight_squat.json` YAZILMADI (dosya yok, `git status` temiz).
Üç seçenek koordinatöre: (a) stil-ayrımı sınıflandırması (M-F-55(2) emsali),
(b) 3 kaynak ayrı incelensin, (c) referans yalnız kümelenen 9 kaynaktan
üretilsin. Bu bir ambiguous-data-interpretation kararı — tek taraflı
seçilmedi (YÜKSELTME KURALI).

**Kapılar:** `dart analyze` temiz; tam gate suite (test/replay/validate)
bu turda ayrıca koşulacak.

## 2026-07-29 (devam, onuncu tur) — G-067: windowBasis sıralaması, FitnessFAQs yeni bulgu

Koordinatör G-066'nın metodolojik sınırını (FSM penceresi yok) FSM'i Python'a
taşımadan çözdü: **sıralama** — `tool/slice_deep_reps_squat.dart` (yeni)
önce rep-FSM'in derin-tekrarlarını kendi fixture'larına keser, kanonik
script SADECE onları işler (`--window-basis rep-fsm`).

**Dilimleme 3 eğitmenin SIFIR derin-tekrar ürettiğini buldu** (Minus The Gym,
School of Calisthenics, Vast Fitness Academy — koordinatör yalnız birini
öngörmüştü). **Nihai: 12/16 PASS, 1 FAIL (YENİ: FitnessFAQs, r=-0,233,
n=10 — aşırı küçük örneklem, güvenilir ret değil), 3 noSignal.**
TappBrothers üç bağımsız ölçümde de PASS — sağlam.

Bu turda oturum "Connection closed mid-response" ile kesildi; koordinatör
devriyede commit'lenmemiş işi tespit edip devam ettirdi (M-F-77: local
bekletme yok kuralının somut kanıtı). `git status` ile durum teyit edildi,
kayıp yoktu.

**Kapılar:** dart tarafı bu turda değişmedi (yalnız Python+yeni Dart slicer
aracı) — analyze/test doğrulanacak.

## 2026-07-29 (devam, dokuzuncu tur) — G-066: hipKneeCoupling kanonik ev kuruldu

Koordinatör mimari kararı (M-F-96): kimlik metriği hasat-anında-bir-kez
paylaşımlı `mocore` ile hesaplanır, fixture provenance'ına damgalanır;
tüketiciler okur, yeniden hesaplamaz. `tools/hip_knee_coupling_canonical.py`
yazıldı (Lissom'un `lissom-metrics.v1.json`'undan metrik tanımını birebir
okuyor, `mocore.measures.evaluate(anatomical=true)` çağırıyor). Gravita'nın
eski 2D Dart formülü EMEKLİ edildi (silinmedi, RETIRED beyanıyla arşivlendi).

**Sonuç: 16/16 eğitmen GEÇTİ. TappBrothers artık PASS** (r=0,642 — G-064'teki
reddin formül-artefaktı olduğu doğrulandı, G-065'in rep-FSM-pencereli
diferansiyeliyle (0,818) aynı yönde).

**Metodolojik sınırı gizlemedim:** kanonik script Gravita'nın FSM-tekrar
penceresini kullanmıyor — Vast Fitness Academy (önceden FSM'siz noSignal)
artık n=2537/r=0,821 ile geçiyor, bu videoda gerçek squat yapıldığı hâlâ
doğrulanmadı. İsimli kuyruk kalemi olarak bırakıldı (rep-FSM↔mocore köprüsü).

**Kapılar:** 69/69 test · 17 değişmez 0 hata · replay 0 ölü · analyze temiz
(Dart tarafı bu turda değişmedi, Python-yalnız iş).

## 2026-07-29 (devam, sekizinci tur) — v0.8.4 (J-056 görünürlük-kapısı), G-063 yeniden yayımlandı

Koordinatör mesajları çakışmıştı: G-063'ü v0.8.2'de yayımlarken, JabLab'ın
bulduğu çekirdek P0 (kanonik `prepareTake` görünürlük-kapısını hiç
çağırmıyordu — görünmez eklemlerin fabrike sayıları konsensüse giriyordu)
kuyrukta bekliyordu. motion_core v0.8.4'e (`eb28039`, v0.8.3 kırık)
yükseltildi, 37/5 artefaktı YENİDEN üretildi.

**Yol boyunca ikinci küçük kırılma bulundu:** kendi mirrorAgnostic hesabım
düzeltme sonrası ortaya çıkan DÜRÜST `null` hücrelerde çöktü (`num` cast
hatası) — `null→NaN` ile düzeltildi.

**Sonuç:** contributingTakes 37→36, kaynak kümesi değişti (Cara
Kuykens→Calisthenicmovement), **meanAgreement 0,879→0,890 İYİLEŞTİ**
(koordinatörün beklediği yönde — çöp temizlenince anlaşma sıkılaşıyor).
mirrorAgnostic BEŞİNCİ bağımsız kez doğrulandı (5,16°). G-014 hâlâ 0/9 ama
sol taraf eklemleri (hip/knee/thigh/shin) floorShare TAM 1,00'a çıktı.
G-064/G-065 diferansiyeli v0.8.4'te de koşuldu, sonuç AYNI (bu test
ReferenceCli kullanmıyor, etkilenmedi — beklenen).

Koordinatör iki yan-bulgumu (V17 okuyucu düzeltmesi + "çiftin bir tarafı
taban-bağlıysa çift floor sayılır" kuralı) aile standardı yaptı (M-F-95).

**Kapılar:** 69/69 test · 17 değişmez 0 hata · replay 0 ölü · analyze temiz
· validate_catalog 0 hata.

## 2026-07-29 (devam, yedinci tur) — G-065: hipKneeCoupling diferansiyel testi tamamlandı

Lissom G-064 engelini açtı (L-154): gerçek formülün yeri `mocore/geometry.py
body_axes(mode:"proximal")` + `measures.py evaluate(anatomical=true)` —
Lissom'un kendi atıf sayıları bu bayrağı hiç geçmemiş üretilmişti (kritik
kendi-kendini-denetim: beyan≠canlı, metrik düzeyinde). Düzeltilmiş sayılar
+0,31/+0,77/+0,62/-0,07 (kapı kararları değişmedi).

Üç-yönlü diferansiyel test (Gravita 2D-taraf-agnostik ↔ Lissom-düzeltilmiş
3D-proximal, birebir mocore'dan Dart'a taşındı) 5 ortak eğitmende koşuldu.
**4/5'te iki formül yakın uyuşuyor, ama TappBrothers'ta fark maddi (0,668)**
— Gravita formülüyle RED (0,150), Lissom-düzeltilmiş formülle RAHAT GEÇİŞ
(0,818). TappBrothers'ın G-064 reddi muhtemelen formül artefaktı (kamera-
açısı + küçük örneklem). `formulaSensitive:true` işaretlendi, `fail` etiketi
silinmedi — hangi formülün kanonik olacağı koordinatörde.

**Kapılar:** 69/69 test · 17 değişmez 0 hata · replay 0 ölü · analyze temiz
· validate_catalog 0 hata.

**Ayrıca:** koordinatör M-F-77 ekini iletti — kurucuya soru/AskUserQuestion
artık TÜM oturumlar için yasak, tereddüt koordinatöre SendMessage ile
gidiyor. motion-ailesi hafızasına işlendi.

## 2026-07-29 (devam, altıncı tur) — G-063 YAYIMLANDI + sync_provenance/V17 düzeltmesi

Koordinatör nihai hükmü: 37/5 kanonik artefakt yayımlansın (3 şartla:
mirrorAgnostic beyanı, thinEvidence eğitmenler, 9→5 düşüş sebebi — üçü de
artefakta gömüldü). `content/harvest/reference.push_up.json` artık kanonik
`motion-core/reference@1` şemasında.

**Yayım sırasında bulunan iki yan bulgu:**
- `sync_provenance.py`/`validate_catalog.py` (V17) yeni şemayla KIRILIYORDU
  — eski düz şemanın alan adlarını arıyorlardı, "0 eğitmenden türedi" gibi
  yanlış sıfırlar ürettiler. İkisi ortak `_extract()` okuyucusuyla
  düzeltildi (schema-aware, eski şemayı da destekliyor).
- G-014 sayısı 3 varyans/6 taban→**0 varyans/9 taban**'a düştü — REGRESYON
  DEĞİL, daha dürüst: kanonik şema taraf-başına hesaplıyor, eski pair-
  ortalaması `right_knee`'nin taban-altı olduğunu maskeliyordu.

Kapılar (V17 dahil) yeniden koşuldu, temiz: 69/69 test · 17 değişmez 0 hata
· replay 0 ölü · analyze temiz · validate_catalog 0 hata.

G-064 diferansiyel testi Lissom'un yanıtını bekliyor.

## 2026-07-29 (devam, beşinci tur) — G-063 v2: rep-düzeyi granülerite, kapılar sağlam

Koordinatör G-063'ü rep-düzeyi granüleriteye çevirmemi istedi (pencere yerine
her derin tekrar kendi Fixture'ı). Uygulandı, sonuç belirgin iyileşti:
contributingTakes 7→**37**, distinctSources 4→**5** (eskinin — 44/9 — altında
ama v1'in çok üstünde). `unreliableJoints` boşaldı, mirrorAgnostic dördüncü
kez bağımsız doğrulandı (4,90°). `reference.push_up.json` hâlâ değiştirilmedi
— 37/5 kabul mü, havuz genişletilsin mi, koordinatörde.

G-064 diferansiyel testi için Lissom oturumuna hipKneeCoupling'in gerçek
`frameRef:proximal` implementasyonunu sordum (kod tabanında bulunamadı, yalnız
config'te deklare edilmiş) — yanıt bekleniyor.

**Kapılar:** 69/69 test · 17 değişmez 0 hata · replay 0 ölü · analyze temiz.

## 2026-07-29 (devam, dördüncü tur) — G-063: kanonik CLI çalıştı, havuz küçüldü

Koordinatörün yeni paketinden ilk kalem: push_up referansını Gravita'nın
kendi aracıyla değil motion-core'un kanonik `ReferenceCli`'siyle (v0.8.2)
yeniden üretmek. **Çalıştı** — ama fixture-düzeyi granülerite (1 pencere=1
take, eski araç 1 tekrar=1 take idi) havuzu 44→7 take'e, 9→4 eğitmene
küçülttü (638 pencerenin yalnız 30'u ≥1 derin tekrar içeriyordu). Çevrim-
segmentasyonu beklenenin aksine devreye girmedi (periyodik azınlıktaydı).
**G-056/mirrorAgnostic üçüncü kez, tamamen farklı bir pipeline'da bile
doğrulandı** (4,51° vs eski 5,03°). `reference.push_up.json` DEĞİŞTİRİLMEDİ
— havuz küçülmesinin kabul edilebilir olup olmadığı koordinatöre soruldu
(G-063).

**G-064 — hipKneeCoupling ilk tüketici, tamamlandı.** Lissom'un rig identity
sinyali (pearson(hip_flexion,knee_flexion)>=0,2) 27 squat fixture'ında
ölçüldü: 14/15 eğitmen GEÇTİ, yalnız TappBrothers reddedildi (r=0,150, sınırda).
Önemli: Tom Merrick (kneeSymmetry'de EN kötü, mean=49,8°) hipKneeCoupling'de
rahat geçti (r=0,334) — iki sinyal bağımsız eksen, koordinatörün "kneeSymmetry
advisory + hipKneeCoupling gate" kararı doğrulandı. `triage-profile.gravita.
v2.json`'a `identity.hipKneeCoupling` eklendi (provisional, min:0.2);
`identity-triage.bodyweight_squat.json` bu gate'e göre yeniden yazıldı.
`engine.precondition` (üretim kapısı) HENÜZ değiştirilmedi.

**Kapılar (dördüncü tur sonunda):** 69/69 test · 17 değişmez 0 hata · replay
0 ölü · analyze temiz.

## 2026-07-29 (devam) — kneeSymmetry ölçümü SONUÇSUZ kaldı + G-056 kısmen yeniden açıldı

Devir promptunun İLK İŞİ: 27 squat fixture'dan (16 eğitmen) diz-simetri
dağılımını ölçüp rig `perMovement.identity.kneeSymmetry`yi doldurmak.
**Sonuç eşik DEĞİL, bir bulgu:** dağılım net bir eşiğe yakınsamıyor (bkz.
G-061), `status: pending` bilinçli olarak korundu — bu YÜKSELTME kuralının
tam da beklediği "belirsiz-veri yorumu" durumu, koordinatöre taşındı.

- **G-061 (yeni, P1, açık):** kneeAngleAsymmetry eğitmen-başı 6°-50° arası
  dağılıyor (>8×), world-koordinatı yalnız kısmen düzeltiyor, histogram
  tek-tepeli/uzun-kuyruklu (doğal boşluk yok). Kare-kare denetim split-
  stance/tek-bacak kesitlerin tutorial'lara karıştığını gösteriyor. Danışma-
  amaçlı eğitmen triyajı (`identity-triage.bodyweight_squat.json`) üretildi,
  hiçbir kapı tüketmiyor. Rig şeması (`triage-profile.gravita.v2.json`)
  `identity.kneeSymmetry: {metric, status: pending}` ile GÜNCEL — önceden
  bu anahtar hiç yoktu, şimdi en azından "bakıldı ama ölçülemedi" açıkça
  beyan ediliyor.
- **G-062 (yeni, P1, açık):** ikinci iş (G-056 ikincil hipotez ucuz sınaması)
  beklenenin ÖTESİNDE bir sonuç verdi — sığ tekrarları push_up havuzundan
  çıkarınca referans-kurmanın sıra/ayna kararsızlığı TAM SIFIRA iniyor
  (6,47°→0,000°), G-056'nın "kararsızlık malzemenin özelliği" kapanışını
  KISMEN sorguluyor (malzeme simetrisi hâlâ ayakta, ama "bu yüzden sıra-
  kararsızlığı önemsiz" çıkarımı bu koşumda tutmuyor). Metodolojik not:
  ilk deneme yanlış API'ye (`resolveMirroring().confident`, n>12'de
  anlamsız placeholder) güvenip yanlış "değişmedi" sonucu üretiyordu — kendi
  hatam fark edilip build_reference.dart'ın gerçek ölçüm yöntemine geçildi.
- **Squat havuzu (task 3):** 27 fixture, kneeSymmetry sinyaliyle danışma-
  amaçlı sınıflandırıldı (clean/mixed/suspect/noSignal) — gate DEĞİL.
- Üçüncü iş (havuz elemesi) ikinciye (G-056 sınaması) bağımlı değildi, ikisi
  de tamamlandı.

**Kapılar (bu oturumda değişmedi, yeniden koşuldu):** 69/69 test · 17
değişmez 0 hata · replay 0 ölü · `dart analyze` temiz.

### Koordinatör dönüşü + ikinci tur

- **motion_core pin'i v0.5.0→v0.8.2'ye (`c1f8ed3`) yükseltildi** (koordinatör
  talimatı). Tüm kapılar sürüm sonrası da yeşil (69/69 · 17 değişmez · 0 ölü ·
  analyze temiz) — pubspec.yaml git-ref güncel.
- **G-062 v0.8.2'de yeniden üretildi:** yeni `mirrorGapMeasured`/
  `mirrorSearchDecisive` alanları eklendi ama havuzumuz (91/52 take) hâlâ
  18-tükenmez-arama sınırının üstünde → ikisi de sabit `false`, ayrım
  YAPMIYOR (doğrulandı). Shuffle-testi (n'den bağımsız) v0.8.2'de bulguyu
  DAHA GÜÇLÜ doğruladı: baseline sıra-deltası 6,47°→60,97°, deep-only hâlâ
  0,000°.
- **G-061 seçenek 2 (bottom-fazı daraltması) sınandı — NEGATİF.** Genel
  ortalama iyileşmedi (21,02°→26,03°), K boges'te kötüleşti (18,17°→48,56°).
  Histogram yine tek-tepeli. Sıradaki adım (seçenek 1: confounder hasadı)
  saatler sürebilir — başlatılmadı, koordinatöre bildirildi.
- **Push onaylandı ve yapıldı** — kurucudan ayrıca soruldu, `a1bfcfb` push
  edildi. Ardından koordinatörden M-F-77: karar-sınıfı sorular kurucuya değil
  KOORDİNATÖRE yükseltilir (istisna: harcama/submission/nihai-fiyat/lisans);
  commit+push+merge bu vardiya için KALICI İZİNLİ — motion-ailesi hafızasına
  işlendi, bundan sonra tekrar sorulmuyor.

### Üçüncü tur — koordinatör nihai hüküm + G-062 düzeltmesi

- **G-061 → seçenek 3 (advisory).** Koordinatör kararı: dip aynı zamanda en
  kötü ölçülen an (seçenek 2 negatif), seçenek 1 aynı projeksiyon sorununu
  miras alır + spekülatif getiri; ölçülmüş alternatif zaten var (Lissom
  hipKneeCoupling). `identity.kneeSymmetry` → `status: advisory` + `basis`
  (motion-core `8765977` yeni şema: basis zorunlu, sınır yasak). Squat
  kimliği artık hipKneeCoupling + movementPresence üstünde kapılanacak;
  seçenek 1 isimli-şartlı kalem olarak duruyor.
- **G-062 DÜZELTİLDİ — ilk tur bulgusu GERİ ÇEKİLDİ.** Koordinatör "sığ
  tekrar eşiği probe-icadı olamaz" dedi: `romTarget.bottomAngleMax(95°)`
  hiçbir canlı hükmü beslemiyordu. Ürünün İSİMLİ eşiğine (`formErrors.
  partial_rom`, blocking, `rom_bottom_angle>110°`) geçilince sonuç TERSİNE
  döndü — sıra-deltası düzelmedi, arttı (60,97°→69,29°). **G-056'nın orijinal
  kapanışı DOĞRULANDI**, aile kuralı M-F-57(2) değişmiyor. İlk turun "kapanış
  eksik" alarmı yanlış (agresif, üretim-dışı) bir eşikle ölçülmüş bir yanlış
  alarmdı — kayıt düzeltilerek DEFTER'de bırakıldı, silinmedi.

**Kapılar (üçüncü tur sonrası da):** 69/69 test · 17 değişmez 0 hata · replay
0 ölü · analyze temiz.

**Commit/push geçmişi:** ilk iki tur `e25b4f8` + `a1bfcfb` push'lu (origin/main
eşit). Üçüncü tur (advisory geçişi + G-062 partial_rom düzeltmesi) push
izni kalıcı (M-F-77) — sıradaki commit'te gidecek, ayrıca sorulmayacak.

## 2026-07-29 — 🏁 OTURUM SONU: hasat→referans hattı UÇTAN UCA kanıtlı (push_up)

Gecenin ana kazanımı bir özellik değil, **hattın dürüstlüğü**: üç ayrı turda
"tamam" dediğim şeyi ölçüm çürüttü ve her seferinde kapı kodun içine yazıldı.

### Bitti (kanıtlı)

- **push_up referansı üretildi** — 9 eğitmen · 91 take · 44 hayatta · M-F-47
  47 aykırıyı dışladı. `content/harvest/reference.push_up.json`.
- **Türetilen provenance + V17** — katalog `provenance` bloğu artefakttan
  TÜRETİLİR (`tools/sync_provenance.py`), V17 ikisinin çelişmesini yasaklar.
  Somut tetikleyici: 9-eğitmenli referans üretildikten SONRA bile katalog
  `pending_harvest, consensusN: 0` diyordu ve hiçbir kapı itiraz etmiyordu.
- **G-043 hareket-kimliği kapısı** — 85 "tekrarın" 65'i ayakta konuşan
  eğitmenlerdendi. `engine.precondition` sözleşmesi + V15 + üretim noktasında
  fail-closed reddetme + regresyon testi.
- **G-054 ROM kuralı ULAŞILAMAZDI** (5 harekette) — sayım eşiği hatayı
  kapıyordu; sığ çalışan kullanıcı sıfır tekrar + sıfır geri bildirim alıyordu.
  V16 sınıfı mekanik yakalıyor. Yan ürün: **G-055** tempo artık eşikten değil
  gerçek dönüş anından ölçülüyor (`_extremeUs`) — eşik ayarı tempo'yu sessizce
  bozamaz.
- **FLIP eşiği °/saniyeye çevrildi** (G-058) — `FLIP_DEG=120` kare-başınaydı ama
  25fps'ten türemişti; 60fps'te gerçek eksen terslemesini KAÇIRIRDI. D1 hükmü
  DEĞİŞMEDİ (klipler @25fps → birebir 120°): davranış-koruyucu düzeltme.
- **G-050 ampirik kapanış** — kapı 14°→30°: dağılım 7,45°→16,01°, yani darlık
  gerçekten kapının eseri; AMA giren fazladan take'lerin çoğu `setup` çöpü
  (M-F-55 sınıflandırması: 41 setup / 6 stil) → kapı FİLTRE kalır.
- **G-056 kapandı (yapısal)** — simetri endeksi 5,03° ≈ sıra farkı 4,67°:
  şınav ayna-duyarsız, kararsızlık kovalanacak kusur değil. `mirrorAgnostic`.
- **`kneeAngleAsymmetry` tanımlandı** — dik hareketlerin kimlik sinyali gövde
  açısı DEĞİL diz simetrisidir (ayakta konuşmak da dik duruştur).
- **Replay kapısı** (Ostinato deseni) — metrikler yeniden yazılmadan ürünün
  KENDİ motoru koşuruldu; ölü birim 1→0.
- **Rig katkısı:** duruş kapısı (`trunk_angle_band_deg` + `min_posture_ratio`)
  motion-core main'e merge edildi.

### Açık (yeni oturuma devir)

1. **Diz-simetrisi eşiği** — squat hasadı 21/32 park edildi
   (`content/harvest/park.bodyweight_squat.json`). Eşik ölçmeden yazılmaz.
2. **G-014: 6 eklem TABAN-bağlı** (3'ü varyans-türetimli). Bu dürüstlük,
   eksiklik değil — `provenance.status: harvested_provisional`.
3. **Squat havuzu** — 4 × HTTP 403 yeniden denenecek, 11 aday hiç denenmedi.
4. G-044 (metrik-başına ölçülebilirlik, core kalemi) · G-053 (kol-zinciri stil
   adayları = geniş-tutuş şüphesi) · G-056 ikincil hipotez (sığ tekrarlar).

### Gecenin kalıcı dersi

**Bir sabit, beyan etmediği bir şeye bağlıysa er ya da geç yalan söyler.**
Sayım eşiği hatayı kapıyordu · anlaşma kapısı ölçtüğü varyansı kırpıyordu ·
FLIP eşiği örnekleme hızına bağlıydı · ve provenance'ımın okuyanı yoktu.
İkinci ders: **doğrulayıcının kendisi de denetlenmeli** — iki kez sahte alarm
verdim (dairesel fark, sahte permütasyon); kırmızı yanan bozuk bir doğrulayıcı,
yeşil yanan kadar tehlikelidir çünkü olmayan bir sorunu kovalatır.

**Kapılar:** 69/69 test · 17 değişmez 0 hata · replay 0 ölü · `analyze` temiz.

## 2026-07-26 — 🔓 KOD KİLİDİ AÇILDI + G1/D1 KAPISI ÖLÇÜLDÜ (şartlı geçti)
Kurucu tetiği: "Gravita'ya başlayalım". Vault başlangıç promptu uygulandı; otonom gece modu aktif.

**Yapılanlar (kanıtlı):**
- `docs/gates/G1-D1-PROTOKOL.md` — eşikler **ölçümden ÖNCE** yazıldı (gece modu bağlayıcı kuralı).
- Ölçüm hattı kuruldu: Python 3.12 + MediaPipe 0.10.35 Tasks API; `full` + `heavy` modelleri SHA-256 ile pinlendi. Koşum araçları repoda: `tools/d1-gate/`.
- Veri: Wikimedia Commons API'den 100 lisanslı görüntü (CC0/CC BY/CC BY-SA/kamu malı) + 2 CC BY-SA video. Gözle eleme (33 elendi: heykel/gravür/pul/çok-kişi/uzak-özne) → INV n=42, UPR n=25. Envanter+gerekçeler `docs/gates/kanit/`.
- 4 strateji × 2 model ölçüldü (düz / 180°-döndürülmüş × IMAGE / VIDEO-tracking) + confound ayrıştırma (yönelim vs poz) + elle görsel denetim.

**KAPI SONUCU: 🟢 ŞARTLI GEÇTİ** — ters-duruş hattında üretim kodu açılabilir, **yalnız yönelim-farkında çıkarımla**.
- S2 (180°-döndürülmüş çıkarım), INV n=42: tespit **1,000** · `vis_crit` **0,845** · yan-zincir kapı **0,929** · eksen hatası **0/42** · elle denetim **42/42 doğru, 0 ciddi hata**.
- S1 (düz çıkarım) aynı sette: **%9,5 kullanılamaz** (3 eksen hatası + 1 tespit kaybı) → tek başına kapıyı GEÇMEZDİ.

**Asıl bulgu (planda yoktu):** Beklenen risk (ters-duruşta güven düşer) **gerçekleşmedi** — güven dik insana neredeyse eşit. Bunun yerine **EKSEN TERSLEMESİ** bulundu: model ters vücudu dik sanıp kol↔bacak zincirlerini takas ediyor; **güven yüksek kalıyor** (#21: 0,93) ve iskelet şekli simetrik olduğu için **gözle fark edilmiyor**. Kural motoru "dirsek açısı" diye dizi ölçerdi → kendinden emin, tamamen yanlış koçluk. Görsel kanıt: `docs/gates/kanit/kanit-eksen-terslemesi.jpg`.

**Doğan bağlayıcı kararlar:** G-002 yönelim-farkında çıkarım hattı · G-003 yapısal tutarlılık kontrolü (güven kapısına EK) · G-007 taraf-agnostik kurallar · G-006 V1 metrikleri TUTUŞ fazı üzerine (hızlı fazda tespit kayboluyor — video kanıtı) · aile geneline M-017/M-018.

### Aynı oturum, 2. yarı — G2 + G4 tasarımı
- **G2 PRD** (`app/docs/PRD.md`): akışlar (onboarding+güvenlik → kalibrasyon → başlangıç değerlendirmesi → beceri oturumu) · **12 durumlu inversion state machine** (her duruma beklenen yönelim atandı) · analiz hattı · skorlama · geri bildirim motoru · veri modeli · V1 kabul kriterleri.
  **Kapının kapsam kesintileri PRD'ye açıkça yazıldı** (dürüstlük > vitrin): kick-up kuvvet analizi + çıkış skoru **gösterilir ama kapı değil** (G-006) · baskın-taraf kuralları **YOK** (G-007) · denge kaybı yönü kaba sınıf.
- **6 ADR** (`app/docs/ADR/`): 001 yönelim-farkında çıkarım · 002 yapısal tutarlılık kontrolü · 003 taraf-agnostik kurallar · 004 motor beceri-bağımsız · 005 köken alanları · 006 değerlendirme-kapılı paywall (öneri; fiyat kurucu). Her ADR hangi ölçüme dayandığını ve **reddedilen alternatifleri** yazıyor.
- **G4 tasarımı + içerik paketi:** `app/docs/G4-BECERI-GRAFI-TASARIMI.md` + `app/content/skill-graph/handstand.v1.json` — **15 düğüm**, DAG doğrulandı, kırık ön-koşul yok, kapı-olamaz metrik hiçbir kriterde kullanılmıyor (betikle kontrol edildi). `l_sit_prep`/`pistol_prep` handstand zincirine bağlı olmayan ayrı dallar = motorun beceri-bağımsızlığının çalışan kanıtı. İçerik İngilizce.
- **G3 çekim listesi** (`app/docs/G3-CEKIM-LISTESI.md`): kamera kurulumu spesifik (yatay · 60-80 cm · yan profil · sabit · 60 fps), 5 grup, her grubun hangi borcu kapattığı yazılı, güvenlik ve gönüllü onayı dahil.
- Commit'ler (yerel, `feat/g1-d1-gate`): `cf7dab8` kapı · `44e9a64` beceri grafı · `0b9594b` PRD+ADR+çekim listesi.

**Eşzamanlı oturum durumu (M-016/M-017 disiplini):** aynı gece 4 oturum çalıştı (Ostinato · JabLab · Choreia · Gravita). motion-core'da yabancı commit'siz işe **DOKUNULMADI**; Choreia oturumu Dart çekirdeğini tamamlamış (84/84 test, `feat/motion-core-bootstrap`). Defter ID çakışması nedeniyle kendi kayıtlarım M-017/M-018 → **M-019/M-020**'ye taşındı.

**Kurucu onayı bekleyen:** kapı hükmü + ADR-001/002/003 (sabah retrospektif) · G3 çekimi · remote push (`feat/g1-d1-gate`, 3 commit) · M-017 çekirdek iş bölümü kararı (ADR-002'yi çekirdeğe kim yazacak) · fiyat/paywall (ADR-006) · izinli video kaydı V1'de olsun mu.

## 2026-07-25 — Venture AÇILDI (ayrı repo; kod YOK)
- Kurucu kararıyla monorepo'dan ayrı repoya kuruldu (`kocakkmustafa/gravita`); plan + kilitli CLAUDE.md + defterler hazır; bundle-id `com.yulalab.gravita` rezerve.

## 2026-08-12 — 🔒 OTURUM MÜHRÜ: yayın engelleri + kapı katmanı (G-181…G-195)

**Kapanış anı:** SHA `f2c877e` · `origin/main` ile eşit (0/0, `ls-remote` ile
doğrulandı) · **ağaç temiz** · app **175/175** · engine **175/175** · python
**15/15** · **defter TAZE** (tazelik kapısı gedik 0).

### Kapanan gerçek kusurlar (hepsi ölçümle, çoğu sabotajla)
onboarding'in **korumasız açılış yolu** (sabotaj: satır koparıldı, 161/161
yeşil kaldı) · depolama arızasında **atlanan güvenlik onayı** (hüküm b) ·
kamera izni kalıcı reddindeki **ölü döngü** (ayrımsızlık; `CN=Android Debug`
kimliğiyle doğrulandı) · izin metnindeki **yanlış saklama beyanı** ·
release'in **sessizce debug anahtarıyla imzalanması** · eksik
**`PrivacyInfo.xcprivacy`**.

### Kurulan kapılar
açılış yolu · dördüncü bloker anahtarı (`metric:unimplemented@entry`,
**türetimli**) · bağımlılık **bölmesi** (63/63) · **font teslimi** (iki
yönlü) · **defter tazeliği** (aile referans uygulaması) · gizlilik manifesti
(ölçüm + **paketleme**) · imza sessizliği (üç yönde ölçüldü).

### Yayın denetimi (JabLab'ın 12 kalemlik yöntemi)
**hat-yereli açık 0** · çekirdek **0** · **kurucu açık 6**: ⑤b keystore · ⑦
ikon (md5 şablonla birebir) · ⑨ `AFTER_APPROVAL` **CANLI** (app 6794714365) ·
⑩ cihaz kanıtı · ⑪ sürüm · ⑫ makine-geneli JDK.

### 🔴 AÇIK KALEMLER — nerede durduğu + SIRADAKİ ADIM

**① `metric_support` öz-test fixture'ı canlı KUSURA dayanıyor.**
`if "planche_lean_deg" not in named_gaps` → o metriğin **uygulanması istenen
sonuç**; uygulandığı gün öz-test kırmızıya döner, ayrıştırıcı kusursuzken.
*Bir kapı, kendi ürününün ilerlemesini cezalandırıyorsa ürünün düşmanıdır.*
**NEREDE:** ölçüldü, sınıflandırıldı, **düzeltilmedi.**
**SIRADAKİ ADIM (tasarım hükmü VERİLDİ, M-F-598):** *okumayı ayrıştırmadan
ayır* — öz-test ayrıştırıcıya **sentetik dizge** verir (gerçek Dart sabitini
değil) ve *"bu girdi `named_gaps`e şöyle çözülür"* diye sınar. Kapı gerçek
sabiti okumaya **devam eder** (ayrı kontrol). ⛔ Ürün kaynağına dokunmak
değil, kapıyı gevşetmek değil. **Uygulama işi.**
📌 Aynı ailede 4 kontrol daha var (canlı DURUMA dayanan): `knee_angle` ·
`feet_off_ground`×2 · `http`. ⚠️ `G-999` sentinel kontrolü **istisna
olabilir** (prob kasten kalıcı) — **ölç, varsayma.**

**② Gezilebilirlik sözleşmesi (a)–(e) METNE karşı ölçülmedi.**
**NEREDE:** `ventures/motion-core/workspace/GEZILEBILIRLIK-SOZLESMESI.md`
**hiç açılmadı.** Kendi uygulamamın ne yaptığını biliyorum (envanter tek
evde · denklem kapılar arasında · kanonik sayı tek yerde · elle küme yok)
ama metnin bunları böyle tarif ettiğini **bilmiyorum**.
*Uygulamanın doğru olması, sözleşmeye uygun olduğunu ölçmez.*
**SIRADAKİ ADIM:** dosyayı oku ve **(e)'yi metne karşı** ölç — elle küme
silinmedi mi · rütbesi **türetimin pozitif kontrolüne** düşürüldü mü · ve
**iki zorunlu şerh** var mı (*"ALT SINIR, tam envanter DEĞİL"* · *"ekleme =
kontrolün TABANINI yükseltmek"*). Sonra (a)–(d)'yi de metne karşı ölç.
⚠️ Durumum diğer hatlardan **farklı**: onlarınki *yanlış ölçülmüş*,
benimki ***hiç ölçülmemiş.***

### Bugün ne kapanmadı ve sebebi ölçüldü mü
Kapanmayan iki kalem **yukarıda**, ikisinin de sebebi **ölçülü**: ①'in
panzehri **tasarım kararı gerektiriyordu** (verildi, uygulanmadı) · ②
**kapasite** bitti ve bu **adıyla** bildirildi — *bir hattın kalan
kapasitesini önceden bildirmesi, sevk kararının girdisidir.*

## 2026-08-17 — 🔒 OTURUM MÜHRÜ (H-86 kayıt zinciri): tur-2 kapanışı (G-240…G-258)

**Kapanış anı:** SHA `a403af8` · `origin/main` ile eşit (push edildi) · ağaç temiz ·
app **222/222** · engine **175/175** · python **20/20**.

**2026-08-12 mührünün İKİ açık kalemi bu aralıkta kapandı** (bu turdan önce, tur içinde):
① `metric_support` fixture kusuru — `G-201` (2026-08-13), `M-F-598` hükmü uygulandı,
ayrıştırma saf katmana çıktı, öz-test artık ürünün ilerlemesini cezalandırmıyor.
② Gezilebilirlik sözleşmesi (a)–(e) — `G-200`/`G-202`, metne karşı ölçüldü, `A7` **5/5**;
③ BAŞLANGIÇ'ın `B5` bağımlılığı da sonraki bir turda kapandı (`content_repository.dart`,
"B5 blokajının kökü kapatıldı").

**Bu turda (tur-2, H-82/H-80/H-85) kapanan:**
- **Yayın provası GERÇEK** (`gravita.ipa`, imzalı, `G-247`) + `PAKET.md`/`device_day_preflight.py`
  v2 (profil-gölgeleme düzeltmesi, `G-253`).
- **Gerekçeli-API kapısı v1→v3 aile katmanına taşındı** (`motion-core/workspace/tools/`, `G-250…252`).
- **H-82 kapandı:** Apple'ın resmi required-reason listesindeki 30 sembolün 30'u tarandı
  (önceki tur 4/30) — çift-kategori riski (`getattrlist` ailesi) hiçbir yüzeyde sıfır bulundu.
  Rapor: `motion-core/workspace/GEREKCELI-API-CAPRAZ-DOGRULAMA-2026-08-17.md` (`G-256`).
- **H-80 kapandı:** `playStore/title` kopyası kaldırıldı (`G-256`).
- **H-85 kapandı:** ASC'deki canlı ad (`"Gravita: Skills & Strength"`) + `supportUrl` +
  `privacyPolicyUrl` orkestratör tarafından yazıldı; `description`ın açılış/kapanış cümleleri
  yeni adla hizalandı, ürün GENİŞLETİLMEDİ — `HONEST ABOUT WHAT'S READY` paragrafı (31/2/29,
  `validate_store_listing.py` gate'i) birebir korundu (`G-258`).
- **Kanal onarıldı:** orkestratörle çift yönlü mesajlaşma (`mcp__ccd_session_mgmt__send_message`,
  `session_id: local_b6da7c10-…`) doğrulanıp kullanıldı — önceki turun raporu hiç ulaşmamıştı (`G-257`).

**🔴 AÇIK KALEMLER — hepsi kurucu kalemi, kod tarafında engel yok:**
- `supportUrl`/`privacyPolicyUrl` deploy'u (`yulalab-com`, aile-dışı depo) — kurucu onayında.
- Gerekçe kodu seçimi (`C617.1` vb.) — tek-sayfa envanter hazır, seçim kurucuda.
- Cihaz günü — gerçek cihaz şu an "Devices Offline" (bağlı değil), kurucu tetiklemesi bekleniyor;
  kamera köprüsü canlılığı hâlâ hiç ölçülmedi (aile geneli, `H-82`'nin JabLab'a verdiği görev).
- Kütüphane doluluk gerçeği (dürüstlük payı, `H-86`'nın kendi notu): 31 hareketten **2**'si canlı,
  29'u `coming_soon` — mağaza yüzeyi 5/5 kapandı ama **ürün** için "yayına hazır" cümlesi yanlış
  olur (`M-F-759`).

**Bu oturum H-86 (kurucu talimatı: tüm hatları kayıt zincirine sok) uyarınca kapatılıyor** —
yeni iş başlatılmadı, elde açık kalem YOK, vault devir notu + commit/push bu mühürle birlikte.
