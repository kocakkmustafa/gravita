import 'library_model.dart';

/// Kütüphane · Home · Hareket sayfası · Profil metinleri (V1 yalnız `en`).
///
/// **Neden ayrı dosya:** `progress_strings.dart` ile aynı gerekçe — kopya
/// motora sızmasın, tasarım/çeviri turu tek dosya açsın.
///
/// **Değişemeyen YAPI (sözcükler değişebilir):**
/// - Sayı asla birimsiz/bağlamsız çıkmaz.
/// - VAAT dili YOK (M-F-186 · koordinatör hükmü 2026-08-07): "coming soon",
///   "yakında" ve **"yet"**. Bir şey yoksa NEDEN yok olduğu söylenir; ne zaman
///   geleceği söylenmez. *"not open yet"* bir SÖZ verir, *"closed"* bir DURUM
///   bildirir — cümlenin geri kalanı (kaç ölçüm eksik, adları) dürüstlüğü
///   zaten taşıyor, "yet" hiçbir bilgi eklemiyordu.
/// - Türetimli hiçbir liste burada YAZILMAZ; buradaki fonksiyonlar yalnız
///   veriden gelen parçaları CÜMLEYE dizer.
abstract final class LibraryStrings {
  // ── Kabuk ──────────────────────────────────────────────────────────────
  static const String tabToday = 'Today';
  static const String tabLibrary = 'Library';
  static const String tabProgress = 'Progress';
  static const String tabProfile = 'Profile';
  static const String startSession = 'Start';

  // ── Home / Today ───────────────────────────────────────────────────────
  static const String homeTitle = 'Today';

  /// ⚠️ Home'un boş hâli SAHTE PLAN üretmez. Tasarımın "bugünkü plan" bloku
  /// bir PLANLAYICI varsayıyor; öyle bir motor YOK. Uydurulmuş bir "bugünün
  /// antrenmanı" placeholder veri olurdu (aile kuralı: sahte veri YASAK).
  static const String homeNoPlanTitle = 'We don\'t plan your day';
  static const String homeNoPlanBody =
      'Gravita has no training planner, so there is nothing here pretending to '
      'be today\'s workout. What we do have is below: the movements we can '
      'measure right now, and the honest state of everything else.';

  static const String homeOpenNowTitle = 'Open right now';
  /// ⚠️ *"In the measurement queue"* DEĞİL — ve bu bir YAPISAL VAAT
  /// düzeltmesidir (J-150 sınıfı).
  ///
  /// Vaat her zaman bir SÖZCÜKTE olmuyor: *"kuyruk"* bir **sıra** ve
  /// **işlenecekleri** ima eder — *"sıranız gelecek"*. Hiçbir hareketin
  /// işleneceği garanti değil; 30'u da hasat kararına bağlı.
  ///
  /// Dil nöbetim `yet`/`coming soon`/`will be` arıyor ve bu sınıfa
  /// **tanımı gereği kör**: metafor bir kelime listesine yakalanmaz.
  /// Rozetle aynı sözcüğe geçildi (`CLOSED`) — durum bildirir, sıra kurmaz.
  static const String homeQueueTitle = 'Closed movements';

  /// Kuyruğun cümlesi — sayılar VERİDEN gelir, elle yazılmaz.
  static String homeQueueBody(int queued, int total) =>
      '$queued of our $total catalogued movements are not open. That is not a '
      'gap we forgot about — each one names the measurement it is waiting on, '
      'on its own page.';

  /// ⚠️ *"to be coached"* iddiası KALDIRILDI (yayın envanteri, J-124 sınıfı).
  ///
  /// Bu satır *"koçlanmak için gereken her şeye sahip"* diyordu; aynı
  /// hareketin sayfası ise *"canlı seansta hiçbir ipucu ekranda görünmüyor,
  /// yani hiçbir şey sana söylemiyor"* diyor. **İki yüzey birbiriyle
  /// çelişiyordu ve daha görünür olanı yanlıştı** — J-113'ün aynı şekli.
  ///
  /// Yeni cümle yalnız KABUĞUN TESLİM ETTİĞİNİ anlatıyor: sayma, ve saymanın
  /// dayandığı kimlik kapısı.
  static String homeOpenBody(int live) => live == 1
      ? 'One movement is open: we count your reps during a live session, and '
          'the engine refuses to count unless it can see you are actually in '
          'position. We do not grade your form — not here, not anywhere.'
      : '$live movements are open for live rep counting.';

  // ── Library ────────────────────────────────────────────────────────────
  static const String libraryTitle = 'Library';

  /// Başlık altı sayacı. İki sayı da GÖSTERİLİR: yalnız toplamı göstermek
  /// 31'i vitrin gibi sunardı, yalnız canlıyı göstermek kapsamı saklardı.
  static String libraryCount(int total, int live) =>
      '$total movements · $live open · ${total - live} waiting on a measurement';

  static const String searchHint = 'Search movements';
  static const String searchClear = 'Clear search';

  static String searchMovementHeading(int n) =>
      n == 1 ? '1 movement' : '$n movements';

  /// ⭐ W0 §4: kapsam-dışı terim BOŞ SONUÇ döndürmez.
  static const String searchExclusionHeading = 'Not in Gravita — and why';

  /// GERÇEK boşluk (ne hareket ne kapsam-dışı gerekçe). Bu da bir cümledir.
  static String searchNothing(String query) =>
      'Nothing in our catalogue matches "$query", and it is not one of the '
      'things we have deliberately left out either. It may simply be a '
      'movement we have not written up.';

  static const String whyNotLink = "Why isn't a movement here?";

  /// Sınır sınıfının kullanıcı cümlesi (J-153). Rozet DEĞİL cümle: tek
  /// sözcüklük bir etiket ("AUTHORITY") kullanıcıya hiçbir şey söylemez.
  /// `null` → BOŞ. Sınıfı bilinmeyen bir sınır hakkında *"kamera göremiyor"*
  /// demek, üç sınıftan **vaat taşıyanını** varsaymak olurdu (G-163).
  static String limitClassLine(String? limitClass) => switch (limitClass) {
        null => '',
        'authority' =>
          'This is a line we drew, not a limit we hit. Better technology '
              'would not change it.',
        'equipment' =>
          'This needs hardware we do not ask you to own.',
        _ => 'A single phone camera cannot see what this would need.',
      };

  static const String openBadge = 'OPEN';

  /// ⚠️ `MEASURING` DEĞİL. Ölçüldü (yayın envanteri, J-124 sınıfı): o sözcük
  /// *"uygulama seni ölçüyor"* diye okunuyordu — oysa gerçek TAM TERSİ:
  /// ölçülmemiş olan ÜRÜNÜN kendisi, kullanıcı değil. Rozet doğru sonucu
  /// (girilemez) YANLIŞ gerekçeyle söylüyordu; ve doğru sonucu yanlış
  /// gerekçeyle söylemek en zor yakalanan hatadır.
  ///
  /// `CLOSED` bir DURUM bildirir ve üretilmiş blurb ile aynı sözcüğü kullanır
  /// (*"is in our catalogue and closed"*). Gerekçe zaten kartın alt
  /// satırında: *"3 measurements missing"*.
  static const String queuedBadge = 'CLOSED';

  /// Hareket kartının alt satırı — bloker SAYISI, ham anahtar DEĞİL.
  static String blockerCount(int n) =>
      n == 1 ? '1 measurement missing' : '$n measurements missing';

  // ── Beceri ağaçları ────────────────────────────────────────────────────
  static const String skillTreesTitle = 'Skill trees';

  /// ⚠️ Bu metin bir EKSİKLİK BEYANIDIR ve bilerek burada duruyor.
  /// `content/skill-graph/` iki paket taşıyor (handstand, planche) ve İKİSİ
  /// de `status: DRAFT` — eşikleri henüz bir hareket-bilimi geçişinden
  /// geçmemiş. Kilit kriterlerini ekranda GÖSTERMEK, doğrulanmamış eşiği
  /// ölçülmüş kapı gibi sunmak olurdu. O yüzden ağaç ÇİZİLMİYOR ve sebebi
  /// söyleniyor.
  ///
  /// Sayı da adlar da `content/skill-trees.index.json`'dan gelir
  /// (`tools/build_skill_tree_index.py`). İlk yazışımda ekran ağaç adını
  /// düğüm kimliklerinden TAHMİN ediyordu — uydurulmuş bir eşleştirme;
  /// düzeltildi.
  static String skillTreesBody(int drafted, String names) =>
      '${drafted == 1 ? 'One progression tree is' : '$drafted progression '
          'trees are'} drafted ($names), but their unlock criteria have not '
      'been through a movement-science review. We are not drawing a tree '
      'whose gates would be numbers we picked ourselves. The movements inside '
      'those progressions are in the library like everything else.';

  // ── Hareket sayfası ────────────────────────────────────────────────────
  static const String honestyTitle = 'What we measure — and what we do not';
  static const String honestyMeasuredLabel = 'Measured';
  /// KALICI sınırlar başlığı — "henüz" değil, HİÇ.
  static const String honestyNotMeasuredLabel =
      'A single camera cannot see this';

  /// KUYRUK başlığı — bir gün kapanabilir olanlar.
  ///
  /// ⚠️ Vaat DEĞİL: *"waiting on"* bir DURUM bildirir, *"coming"* bir söz
  /// verirdi. Her maddenin altında neyin beklendiği İSİMLİ duruyor.
  static const String honestyWaitingLabel = 'Waiting on a measurement';

  /// Bugünün BASKIN hâli (31'in 30'u). Onurlu bir cümle, hata hâli değil.
  static const String honestyMeasuresNothing =
      'Nothing. Everything this movement would measure is listed below as '
      'still missing, with the reason.';

  static const String howToTitle = 'How it is done';

  /// ⚠️ Referans YOK hâli. **Sahte iskelet-avatar YOK** — çizecek gerçek bir
  /// referans dizisi olmadığında bir insan figürü uydurmak, kullanıcıya
  /// "işte doğru form" diyen bir yalan olurdu.
  static const String howToNoReference =
      'We have no recorded instructor reference for this movement, so there is '
      'no demonstration to show you. We would rather show you nothing than '
      'draw a figure we made up.';

  /// Referans VAR ama gösterilebilir bir gösterim YOK — AYRI cümle.
  ///
  /// ⚠️ İkisini tek cümlede toplamak `push_up`ta sayfanın kendisiyle
  /// çelişmesine yol açıyordu. Eğitmen çekimi ile ÇİZİLEBİLİR gösterim
  /// farklı artefaktlar; kullanıcı ikisini aynı sanıyor, o yüzden fark
  /// AÇIKÇA söyleniyor.
  static String howToReferenceNotDrawable(int instructors) =>
      'We have footage from $instructors instructors for this movement, but we '
      'have not built a demonstration you can watch from it — what we derived '
      'was measurement, not a sequence to play back. We would rather show you '
      'nothing than draw a figure we made up.';

  static const String formErrorsTitle = 'What the rules watch for';
  static String formErrorsBody(int n) => n == 1
      ? 'One rule is written for this movement. It does not run.'
      : '$n rules are written for this movement. They do not run.';
  /// ⛔ **BU CÜMLE BİR KEZ YALAN SÖYLEDİ — G-212.** Eski hâli:
  /// *"$n rules run during a session."*
  ///
  /// Ölçüldü: kuralları değerlendiren API (`RepEngine.correctionFor` /
  /// `topCorrection` / `repMetrics`) **üründe HİÇ ÇAĞRILMIYOR** — tek çağıran
  /// `tool/replay_gate.dart`, yani KAYITLI görüntü üzerinde koşan çevrimdışı
  /// kapı. Canlı seansta hiçbir kural değerlendirilmiyor.
  ///
  /// Kusurun kaynağı bir VEKİLDİ: `m.isLive` *"kurallar koşuyor"* sanıldı;
  /// oysa `isLive` yalnız *"tekrar sayımı açık"* demek. İki ayrı olgu.
  /// > ***BİR HAREKETİN ÖLÇÜLÜYOR OLMASI, KURALLARININ KOŞTUĞU ANLAMINA
  /// > GELMEZ.***
  ///
  /// Ve aynı sayfa zaten `comingSoonInThisMovement`te *"during a live session
  /// no cue appears on screen"* diyordu ⇒ **tek ekranda iki cümle birbirini
  /// çürütüyordu** (koordinatör `H-10`, Lissom'un ikinci kusuruyla aynı sınıf).
  static String formErrorsBodyLive(int n) => n == 1
      ? 'One rule is written for this movement. It fires on recorded footage, '
          'but nothing checks it while you are training — you are not told '
          'mid-set.'
      : '$n rules are written for this movement. They fire on recorded '
          'footage, but nothing checks them while you are training — you are '
          'not told mid-set.';

  static const String safetyTitle = 'Before you start';
  static const String coursesTitle = 'Courses';
  static const String coursesNone =
      'No course is open for this movement. A course would be a list of '
      'lessons you could actually do; there is nothing behind one here, '
      'so we are not listing an empty shell.';
  static String coursesCount(int courses, int lessons) =>
      '$courses ${courses == 1 ? 'course' : 'courses'} · '
      '$lessons ${lessons == 1 ? 'lesson' : 'lessons'}';

  static const String trendTitle = 'Your history with this movement';

  /// ⚠️ İKİ AYRI CÜMLE, çünkü iki AYRI olgu.
  ///
  /// Dersi olmayan bir harekette "hiç seansın yok" demek KANITLANAMAZ bir
  /// iddiadır (eski bir ders silinmiş ve yetim kayıt kalmış olabilir —
  /// `ProgressSummary.orphanRecordLessonIds` tam olarak bu olguyu sayıyor).
  /// Kanıtlanabilir olan şey içerikten okunur: burada kaydedilecek bir ders
  /// YOK. Söylenebilecek en güçlü doğru cümle odur.
  static const String trendNoLesson =
      'There is no lesson here, so there is nothing a session could have '
      'been recorded against. No chart, because there is nothing to chart — we '
      'do not draw an empty axis to fill the space.';

  static const String trendNoSessions =
      'No sessions recorded for this movement.';

  /// Geçmiş OKUNAMADI. "Hiç seansın yok" demek yasak — bilmediğimizi sıfır
  /// yazmak, bu ürünün tam olarak reddettiği şey (`ProgressStrings`
  /// `historyUnavailable` ile aynı kural, hareket ölçeğinde).
  static const String trendUnreadable =
      'We could not read your training history on this device, so we will not '
      'tell you how much you have done with this movement. Nothing here is a '
      'count of your work.';

  static String trendSummary(int sessions, int units, String unitLabel) =>
      '$sessions ${sessions == 1 ? 'session' : 'sessions'} · '
      '$units ${units == 1 ? unitLabel : '${unitLabel}s'}';

  static const String queueTitle = 'What is missing';
  static const String skillTreeLinkTitle = 'Part of a progression';
  /// ⚠️ HAM DÜĞÜM KİMLİĞİ GÖSTERİLMİYOR — ve bu bir düzeltmenin ürünü.
  ///
  /// Eski hâli *'This movement is node "hollow_body" in a drafted
  /// progression tree.'* diyordu: `hollow_body` bir İÇ ANAHTAR ve
  /// `Parallel_bars` bulgusunun **farklı biçimdeki** hâli. Üstelik ağaç
  /// zaten ÇİZİLMİYOR — kullanıcıya göremeyeceği bir ağacın düğüm adı
  /// veriliyordu.
  ///
  /// Şimdi ait olduğu PROGRESYON adlandırılıyor (indeksten türetilir) ve
  /// taslak olduğu aynı cümlede söyleniyor — kütüphanedeki beceri-ağacı
  /// bölümüyle tutarlı.
  static String skillTreeIn(String treeName) =>
      'This movement is one step in our drafted $treeName progression. We are '
      'not drawing that progression: its unlock criteria have not been '
      'through a movement-science review.';

  /// Ağaç bulunamadıysa — indeks ile katalog ayrışmışsa.
  static const String skillTreeUnknown =
      'This movement is marked as part of a progression, but we could not '
      'find which one. We are not guessing.';

  /// `null` → BOŞ. Sınıfı bilinmeyen bir harekette kamera-görünürlüğü
  /// hakkında cümle kurmak, ölçülmemiş bir iddiadır.
  static String classBadgeExplainer(String? cls) => switch (cls) {
        null => '',
        'B' => 'Class B — the camera looks down this movement\'s path, so we '
            'count and time it but never judge its shape.',
        // ⛔ *"we **coach** your body"* İDİ (G-213 süpürmesi). Ürün hiçbir
        // harekette koçluk ETMİYOR: kural değerlendirmesi üründe hiç
        // çağrılmıyor (`G-212`) ⇒ kimseye bir şey söylenmiyor. Sınıf ayrımının
        // anlattığı şey zaten koçluk değil **ÖLÇÜMÜN KONUSU**: beden mi,
        // ekipman mı. Doğru sözcük o.
        'D' => 'Class D — our measurements are about your body; the equipment '
            'itself is not detected.',
        _ => 'Class A — everything the camera needs is visible from the side.',
      };

  /// ⚠️ Alt çizgi TEMİZLENİR. Simülatörde ölçüldü: hareket sayfası ve
  /// kütüphane kartı kullanıcıya **"Parallel_bars"** yazıyordu — ham katalog
  /// anahtarının ta kendisi. 78 test yeşildi ve hiçbiri yakalamadı, çünkü
  /// hepsi metnin VARLIĞINI sınıyordu, BİÇİMİNİ değil. Aynı sınıf altı ham
  /// değer var (`low_bar`, `pull_up_bar`, `parallel_bars`…), o yüzden
  /// düzeltme tek tek değil DESENE yazıldı.
  static String equipmentLine(List<String> equipment) => equipment.isEmpty
      ? 'No equipment'
      : equipment.map((String e) => _titleCase(e.replaceAll('_', ' '))).join(' · ');

  /// Eksik alan SATIRDAN DÜŞER, uydurulmuş bir değerle doldurulmaz.
  static String metaLine(MovementEntry m) => <String>[
        LibraryCatalogue.labelFor(m.family),
        if (m.level != null) _titleCase(m.level!),
        equipmentLine(m.equipment),
      ].join(' · ');

  // ── Profil ─────────────────────────────────────────────────────────────
  static const String profileTitle = 'Profile';

  /// Tasarımın Profil ekranında kamera/veri AYARLARI var. Ayar YOK — bir
  /// ayar düğmesi arkasında değiştirilecek bir şey olmadan çizilirse ölü
  /// butondur. Bu ekran bugün yalnız DOĞRU olan şeyleri söylüyor.
  static const String profileNoSettings = 'Nothing to configure';
  static const String profileNoSettingsBody =
      'There are no settings on this screen because there is nothing here you '
      'can change. A settings screen with nothing behind it would be a screen '
      'that lies about what you control.';

  static const String profileDataTitle = 'Your data';
  static const String profileDataBody =
      'Your session history is stored on this device only, in the app\'s own '
      'folder. It is not uploaded anywhere. Deleting the app deletes it.';

  static const String profileWontTitle = 'What this app will not do';
  static const String profileWontBody =
      'We do not diagnose injuries, prescribe rehab, measure force or strength, '
      'or score you against a number we could not justify. The full list of '
      'what we left out of the catalogue, with reasons, is below.';

  static String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
