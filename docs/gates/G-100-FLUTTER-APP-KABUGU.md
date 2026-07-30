# G-100 — Flutter app kabuğu: iki platformda DERLENDİ ve simülatörde KOŞTU

**Koordinatör hükmü M-F-188/2 (karar 1, "(a)-genişletilmiş"):** salt
`gravita_ui` değil, M-F-160 mimarisinin Gravita uygulaması — JabLab/Choreia
yerleşim aynası · `motion_core` TAG-pinli · replay-ilk-günden · içinde İNCE
yapı-widget'ı + M-F-168 sınır beyanı.

## 1. Kurulan yapı

```
app/
  pubspec.yaml            flutter · gravita_engine(path) · path_provider
  lib/main.dart           runApp(GravitaApp())
  lib/app/gravita_app.dart        MaterialApp + ProgressScreen (yükle/hata/veri)
  lib/app/content_repository.dart KABLOLAMA: asset bundle + path_provider
  lib/app/progress_strings.dart   kullanıcı metni (EN, V1) — motorda DEĞİL
  lib/app/progress_view.dart      İNCE yapı-widget'ı (yalnız ProgressSummary)
  android/ ios/                   com.yulalab.gravita (rezerve ID, CLAUDE.md)
  test/  progress_view(10) · shell_contract(6) · shell_end_to_end(2)
```

Motor/kabuk ayrımı korundu: `ProgressSummary`, `SessionRecord`,
`JsonlSessionStore`, `LessonSurface.deriveAll` **motorda** (saf Dart, Flutter
YOK); kabuk yalnız *nereden okunur* sorusunu cevaplıyor. Kabuk `ProgressSummary`
tarafında **hiçbir şey yeniden yazmadı** — G-099'da öngörüldüğü gibi.

**`path_provider` KABLOLAMADA:** `JsonlSessionStore` bir `File` alıyor, uygulama
dizinini bulan çağrı `ContentRepository.openSessionStore()` içinde. Terfi
arayüzünün 1. şartının somut karşılığı — ve bedava değil, **ölçülebilir faydası
var**: uçtan uca test platform kanalına hiç dokunmadan koşuyor.

## 2. Tek türetme evi (G-099'un devamı)

`LessonSurface.deriveAll(library:, catalogFor:)` **motora** taşındı; hem üretim
kabuğu hem içerik-kablolama testi AYNI fonksiyonu çağırıyor. Test kendi
türetmesini yazsa, biri `status: locked` okumayı unuttuğunda kilitli ders
üretimde AÇIK görünürdü — **test YEŞİL kalarak.** G-079'un ("aynı ölçümün iki
evi tutarsızlaşır") yüzey tarafındaki tekrarı önlendi.

Katalog adresi hareketin kendi `wave` alanından kuruluyor — `w1` sabitlemek
G-099'un dalga-körlüğünü tekrarlamak olurdu.

## 3. Uçtan uca: SAHTE HİÇBİR ŞEY YOK

`test/shell_end_to_end_test.dart` — GERÇEK `library.json` + GERÇEK katalog (asset
bundle) → GERÇEK `JsonlSessionStore` (geçici dosya, 2 satır JSONL) → GERÇEK
`ProgressView`. Zincir birlikte koşuyor: `15 reps` · `3 min 45 s worked` ·
`2 sessions` · ölçülemeyen 1 tekrarın gerekçesi · kilitli dersin
`library.json`dan gelen gerekçesi.

⚠️ **İlk yazışım 10 dakika ASILDI** — hata vermedi, ASILDI. `testWidgets` gövdesi
SAHTE saatli (FakeAsync) bir bölge; dosya/asset G/Ç'si gerçek saate bağlı olduğu
için future asla tamamlanmıyordu. Panzehir `tester.runAsync`. Arıza yönü
öğretici: **sahte-async bölgede gerçek iş yapmak kırmızı test değil ÖLÜ test
üretir** — G-095'in ("sınanamayan yolu sınanmış saymak") komşusu.

İkinci vaka: bozuk asset bundle verildiğinde kabuk **BOŞ ilerleme değil HATA**
gösteriyor. Yükleme hatasının en kötü görünümü "hiç çalışmadın" diyen boş bir
ekrandır.

## 4. Paketleme + pin nöbetleri (`shell_contract_test.dart`, 6)

- Bildirilen her asset diskte VAR (eksik asset `flutter build`i kırar).
- `library.json`daki her hareketin katalog dosyası PAKETLENİYOR — dalga
  dizini unutulursa test düşer, kullanıcı değil.
- **`content/harvest/` dizin olarak YOK.** 18 dosyanın 16'sı derleme defteri
  (`decisions.bodyweight_squat.json` HÜKÜM kaydı, `queue.*.json`, sonda
  çıktıları). Referans artefaktları da eklenmedi: **bu kabukta onları OKUYAN kod
  yok.** Gecenin dersinin ("beyan var, okuyanı yok") paketleme tarafındaki hâli.
- `content/catalog/exclusions.json` paketlenmiyor (derleme defteri).
- `motion_core` ref'i **SÜRÜM TAG'i** olmak zorunda (`motion_core-v0.8.8`) —
  dal adı da yetmez, dal ilerler.
- Kabuk `motion_core`/`motion_camera` bildirmiyor; bildirdiği gün **TAM-40-SHA
  zeyli + pin EŞİTLİĞİ** testi şart (JabLab J-071). Nöbet o mesajı taşıyor.

## 5. ⚠️ Simülatörde koşturmak İKİ kusur buldu — 18 test yeşilken

Kabuk **iPhone 17 Pro Max simülatöründe gerçekten koştu**
(`docs/gates/g100-kabuk-simulator.png`). Ve ilk ekran görüntüsü iki gerçek kusur
gösterdi:

| kusur | neden testler yakalamadı |
|---|---|
| Ders adı yerine **`push_foundations.reps_and_tempo`** yazıyordu (`displayName` veri katmanında hiç YOKTU) | Testlerimi **`lessonId` üzerinden** yazmıştım — yani kullanıcıya GÖSTERİLMEMESİ gereken şeyi iddia ediyordum. Test, kimliğin sızmasını KUTSAMIŞTI. |
| Altta **sahipsiz boş "Notes" başlığı** | Hiçbir test bölümün BOŞ olmadığını iddia etmiyordu; başlık bir söz verir, altı boşsa söz tutulmaz. |

İkisi de düzeltildi **ve ikisi için de nöbet eklendi** (kod düzeltmesi tek başına
yetmez — nöbetçisi olmayan düzeltme geri gelir):
- hiçbir metin noktalı-snake_case kimlik desenine uymaz;
- söylenecek not yoksa `notesSectionKey` hiç çizilmez.

**Aile dersi önerim:** *"testler yeşil ≠ kullanıcı doğru şeyi görüyor."* G-095
"testler yeşil ≠ kod koşuyor" demişti; bu onun bir adım ötesi — kod koşuyordu,
testler koşuyordu, **iddia edilen şey yanlıştı.** Yüzey testi, yüzeyin
göstermesi GEREKENİ iddia etmeli.

Not: `ProgressView`in doküman yorumu "bu oturumda cihaz/emülatör yok" diyordu;
artık YANLIŞ olduğu için düzeltildi (bayat beyan, K9 ailesi).

## 6. Kapılar — İKİ PLATFORM

| kapı | sonuç |
|---|---|
| `flutter analyze` | temiz |
| `flutter test` (app) | **18/18** |
| `dart test` (motor) | **121/121** |
| `flutter build ios --simulator` | ✓ `Runner.app` |
| `flutter build apk --debug` | ✓ `app-debug.apk` |
| simülatörde çalıştırma | ✓ ekran görüntüsü |
| `validate_library` / `--self-test` | TEMİZ / **15/15** |
| `validate_catalog` · replay | 0 hata · 8 ateşlenen, **0 ÖLÜ** |

⚠️ **iCloud tuzağı iki kez ısırdı, ikisi de kayıtlı gotcha'ydı:** `codesign`
"detritus" hatası (macOS 26 sarmalayıcısı zaten kuruluydu ama yetmedi) →
panzehir **`build/` dizinini iCloud DIŞINA symlink** (`~/gravita_buildout`,
LifeOS kaydının aynısı). Sonra bir de bayat `native_assets` dizini →
`flutter clean`. `build/` symlink'i olmadan iOS derlemesi bu ağaçta ÇALIŞMIYOR.

## 7. Kapsam sınırı — dürüstçe

- **Kamera yolu YOK.** Seans ekranı da yok: kamerasız bir "seans" düğmesi ölü
  düğme olurdu (aile kuralı). Yüzey, arkasında ÇALIŞAN ölçüm olan kadar açık.
- **Görünüm kanıtlanmadı.** Ekran biçimlendirilmemiş düz metin, tema Material
  varsayılanı. Kanıtlanan: yapı (test) + kabuğun GERÇEKTEN koştuğu (ekran
  görüntüsü). *Güzel göründüğü* hiçbir testin iddiası değil — tasarım turu
  BİÇİMİ değiştirir, YAPIYI devralır.
- Store/imza işi kapsam dışı; Android debug APK imzasız, iOS `--no-codesign`.
