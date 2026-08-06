# DESIGN-AHEAD-OF-CODE — Gravita giydirme turu (M-F-282, 2026-08-06)

> Kaynak: `claude.ai/design` projesi `6ccaab1e-6d13-4cb5-a0c9-6038e7c1170d`
> (`Gravita States.dc.html` · `GravitaScreen.dc.html` · `Gravita.dc.html`) vs
> bu turda giydirilen kod (`lib/app/theme.dart`, `progress_view.dart`,
> `live_session_screen.dart`, `content_failure_screen.dart`).
>
> Koordinatör hükmü (bu turun kapsamı): **yalnız var olan 3 yüzey giydirildi**
> (Progress/ilerleme, Live session, Content failure). 8 eksik yüzey + nav
> shell + 5 fazlı seans modeli **İNŞA EDİLMEDİ** — bunlar aşağıdaki
> "tasarım > kod" listesinde, gelecek bir turun kapsamı olarak duruyor.

---

## 1. Tasarım > Kod (tasarımda VAR, kodda YOK)

### 1.1 Bu turda bilerek inşa edilmeyenler (design panelinin kapsadığı, koddan eksik 8 yüzey)

| Ekran | Design'daki `screen` prop'u | Not |
|---|---|---|
| Home (Today) | `home` | Kodda AYRI yok — `ProgressView` tek yüzeyde "bugünkü plan"ı da kapsamıyor |
| Library | `library` | 9 hareket ailesi + "why isn't X here" sayfası — kodda hiç yok |
| Movement page | `push` / `squat` | 9-bloklu sayfa (referans, dürüstlük kutusu, dersler, "attempts" istatistiği) — kodda yok |
| Course page | `course` | Adım listesi + güvenlik kapısı — kodda yok |
| Skill tree | `tree` | Grafik-tabanlı progresyon görselleştirmesi — kodun `ProgressView` içindeki "locked" listesi BENZER veriyi taşıyor ama liste, ağaç DEĞİL |
| Attempt summary | `attempt` | 7-bileşen deneme özeti — kodda hiçbir karşılığı yok (seans bitince özet ekranı yok) |
| Profile | `profile` | Kamera/veri ayarları, "what this app won't do" — kodda yok |
| 4-tab nav shell | `showTabs` (Today·Library·Progress·Profile + orta seans düğmesi) | Kodun tek girişi `MaterialApp(home: ProgressScreen())`, gezinme yok |

### 1.2 Live session'ın 5 fazı (bilerek uygulanmadı — koordinatör hükmü)

Design `session` ekranı **prep → hold → silence → unread → done** fazlarını, **tutuş/süre** semantiğinde (`holdText`, "HOLD 6.4s") çiziyor. Kodun gerçek hâli dört tanedir — `LiveIdle` · `LiveStarting` · `LiveFailed` · `LiveRunning` — ve **REP** semantiğindedir (`push_up` tek canlı hareket, sayaç tutar). İki model YAPISAL olarak farklı; bu turda yalnız GÖRSEL dil (koyu zemin, alt-sayfa kartı, tipografi) dört gerçek hâle taşındı, 5-faz durum makinesi UYGULANMADI.

### 1.3 Onboarding / Kalibrasyon / İlk-değerlendirme — tasarım projesinde de YOK

UI-BRIEF §3.1–3.3'ün 3 grubu (7 alt-ekran: O1-O5, kalibrasyon sihirbazı, ilk değerlendirme) **bu design panelinde hiç üretilmedi** — `GravitaScreen.dc.html`'in kendi `screen` enum'u (`home·library·push·squat·course·tree·session·attempt·progress·profile`, 10 değer) bunları içermiyor; ne "States" galerisi ne "Gravita.dc.html" interaktif prototipi bu üç grubu gösteriyor. Bu, kod eksikliği DEĞİL — bir sonraki design-panel turunun kapsamı.

---

## 2. Kod > Tasarım (kodda VAR, tasarımda YOK) — sinsi yön

### 2.1 ContentFailureScreen — tam karşılıksız

Design'ın hiçbir ekranında `integrity`/`unreadable` ayrımı, retry-yalnız-retryable kuralı ya da katlanmış teknik-detay deseni yok. Bu turda koordinatör hükmüyle **panele gönderilmedi, kendi dürüstlük dilimle tasarlandı** — [GravitaCard]/[GravitaType] giydirmesi, davranış (üç karar: retry-sınıfı, "yine de devam et" yok, ayrıntı ikincil) AYNEN korunarak. `test/content_failure_test.dart` bu dosyaya tek satır dokunmadan geçti.

### 2.2 HistoryStatus üç-hâli — kısmen karşılıksız

Design'ın `progress` ekranı yalnız TEK bir "1 attempt missing, not estimated" notu gösteriyor (≈ `HistoryPartial`). `HistoryUnavailable` (geçmişin TAMAMI okunamıyor — izin/`path_provider`/dosya hatası) design'da hiç yok. Bu turda `ProgressView._historyUnavailableCard()` olarak kendi dürüstlük dilimle "sealed" kart hâline getirildi (davranış korunur: sayı GÖSTERMEZ, "Not started" DEMEZ).

### 2.3 Üç ayrı "notes" içeriği — design'da tek kalıba sığıyor

`withheldRetroactiveCredit` (retroaktif kredi reddi) · `hasHistoryUnderLock` (kilit altında geçmiş) · `orphanRecordLessonIds` (yetim kayıt) — kodda üç AYRI olgu, design'ın "eksik veri" notunda tek örnek var. Design bunları sadeleştirdiyse bu bir İÇERİK kaybı olabilir; şimdilik kodun üç ayrı beyanı AYNEN korundu (`_noteCard` ile giydirildi, birleştirilmedi).

### 2.4 push_up REP-seansı — design'da örneği yok (isimli boşluk, icat edilmedi)

Design'ın TEK canlı-seans örneği tutuş/handstand dilinde. `push_up`'ın rep-sayan UI'ı (`LiveStrings.reps(n)`, `noRepsYet`, `noPerson`, `framesSeen`) design'da hiçbir karşılığı olmayan bir kalıp. Koordinatör hükmü: görsel dili uygula (tipografi/kart/renk), tutuş-şablonunu ZORLAMA. Bu turda `framesSeen` sayacı ve "confidence" YOKLUĞU bilerek korundu — motor confidence ÖLÇMÜYOR, ekran da UYDURMADI.

---

## 3. Ayrıca ölçülenler (delta değil, ama bağlayıcı)

### 3.1 🔴 Kardeş-ayrışması çelişkisi — kurucu kararı bekliyor

`DESIGN-PANEL-PROMPT.md` §1 bağlayıcı: *"rafine düz kart, cam DEĞİL"* (JabLab'dan ayrışma ekseni). Delivered `GravitaScreen.dc.html` bunu ihlal ediyor: nerdeyse her kart `backdrop-filter: blur(26px) saturate(165%)` kullanıyor (frosted glass). Bu turda **tasarım OLDUĞU GİBİ uygulandı** (glass kalır) ama malzeme TEK bir token'da izole edildi: `lib/app/theme.dart` → `GravitaMaterial.cardBlur` / `.cardSaturation`. Kurucu düzleştirme kararı verirse bu **iki sabiti** `0`/`1.0` yapmak TÜM kartları tek seferde düzleştirir — 40+ kart taraması gerekmez.

**Ek gözlem (screen kanıtından):** Gravita'nın zemini neredeyse düz/tek-renkli (`#F2EFEE` civarı) olduğu için, arkada bulanıklaşacak DOKULU bir içerik yok — glass-vs-flat farkı bu app'te GÖZLE neredeyse FARK EDİLMİYOR (JabLab'ın koyu+canlı arka planının aksine). Yani bu kararın Gravita'daki görsel bedeli düşük; token izolasyonu yine de doğru çünkü Movement/Library gibi gelecekteki yüzeyler (fotoğraf/video referans küçük resimleri arkada) farkı görünür kılabilir.

### 3.2 İçerik ölçeği — design'ın "31 hareket" iddiası hiçbir veriyle tam örtüşmüyor

- **`library.json`** (kullanıcıya açık, `validate_library.py` ile denetlenen TEK kaynak): **2 hareket** (`push_up` live, `bodyweight_squat` coming_soon).
- **`content/catalog/{w1,w2}/`** (motor-seviyesi kural tanımı, `validate_catalog.py`/`replay_gate.dart` ile denetlenen): **28 hareket** rule-set'i var, çoğu `provenance: hasat bekliyor` uyarısı taşıyor ve `library.json`'a henüz TERFİ ETMEMİŞ.
- Design'ın Library ekranı "31 MOVEMENTS", "9 hareket ailesi" diyor — bu sayı ne 2 ile ne 28 ile örtüşüyor. Library ekranı inşa edilirken bu üçünü (design-iddiası · library.json · catalog) uzlaştırmak ayrı bir ölçüm gerektirecek.

### 3.3 Rozetsiz-aspirasyonel düğüm — doğrulanamadı (BELİRSİZ sınıfı, İHLAL DEĞİL)

`tree` ekranında yalnız Handstand ağacı gösteriliyor (4 düğüm: wrist-load → hold → toe-pull-gate → free-handstand), aspirasyonel bir uç düğüm (one-arm handstand/Manna/human flag) örneği YOK. Diğer 4 ağaç (Planche/Lever/Pistol/L-sit) hiç çizilmemiş. Bu kısıt "yüzey yok" sınıfında — ne uygulandı ne ihlal edildi.

---

## 4. Bu turda kod-inceleme + koşum sırasında yakalanan 3 hata (kayıt için)

1. **Kontrast hatası (kod-okumayla yakalandı, koşum ÖNCESİ):** İlk taslakta `LiveSessionScreen`'in alt-sayfası AÇIK zeminliyken metin rengi varsayılanı `sessionInkOnDark` (neredeyse beyaz) kalmıştı — beyaz-üstü-beyaz. Design'ın gerçek CSS'i yeniden okunarak düzeltildi (`sessionInkOnDark` yalnız AppBar'ın dosdoğru koyu zemin üstündeki metni için kullanılır).
2. **Flutter render kısıtı (test koşumuyla yakalandı):** `GravitaCard(sealed: true)` başta üstte kalın/kenarlarda soluk FARKLI renkte `Border` + `borderRadius` birlikte kullanıyordu — Flutter'ın kendi kısıtı ("a borderRadius can only be given on borders with uniform colors") 10 widget testini `RenderDecoratedBox` istisnasıyla düşürdü. Düzeltme: kalın üst-vurgu artık ayrı, düz bir dikdörtgen (`Container(height: 2.5, color: …)`), `Border` tek-renkli.
3. **Gölge kırpılıyordu (kod-okumayla yakalandı):** `boxShadow` başta `ClipRRect`'in İÇİNDEydi — kırpma alanı dışına taşan gölgeyi görünmez kılıyordu. Gölge artık dış, kırpılmamış bir `DecoratedBox`'ta.

Üçü de bu belgeye yazıldı çünkü **aynı kalıp** (`GravitaCard` benzeri bir birincil) ailenin başka bir uygulamasında tekrarlanırsa aynı iki Flutter kısıtına (uniform-border+radius, shadow-in-clip) tekrar çarpabilir.

---

## 5. Kaynaklar

`docs/design/DESIGN-PANEL-PROMPT.md` (panel brief'i) · `docs/design/UI-BRIEF.md` (11-grup envanteri) · `lib/app/theme.dart` (token'lar + gerekçe yorumları) · claude.ai/design projesi `6ccaab1e-6d13-4cb5-a0c9-6038e7c1170d`.
