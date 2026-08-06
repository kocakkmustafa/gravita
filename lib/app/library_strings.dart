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
      'coach right now, and the honest state of everything else.';

  static const String homeOpenNowTitle = 'Open right now';
  static const String homeQueueTitle = 'In the measurement queue';

  /// Kuyruğun cümlesi — sayılar VERİDEN gelir, elle yazılmaz.
  static String homeQueueBody(int queued, int total) =>
      '$queued of our $total catalogued movements are not open. That is not a '
      'gap we forgot about — each one names the measurement it is waiting on, '
      'on its own page.';

  static String homeOpenBody(int live) => live == 1
      ? 'One movement has everything it needs to be coached: an identity '
          'check derived from measurement, rules proven against real footage, '
          'and a real instructor reference.'
      : '$live movements have everything they need to be coached.';

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

  static const String openBadge = 'OPEN';
  static const String queuedBadge = 'MEASURING';

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
  static const String honestyNotMeasuredLabel = 'Not measured';

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

  static const String formErrorsTitle = 'What the rules watch for';
  static String formErrorsBody(int n) => n == 1
      ? 'One rule is written for this movement. It does not run.'
      : '$n rules are written for this movement. They do not run.';
  static String formErrorsBodyLive(int n) =>
      n == 1 ? 'One rule runs during a session.' : '$n rules run during a session.';

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
  static String skillTreeNode(String node) =>
      'This movement is node "$node" in a drafted progression tree.';

  static String classBadgeExplainer(String cls) => switch (cls) {
        'B' => 'Class B — the camera looks down this movement\'s path, so we '
            'count and time it but never judge its shape.',
        'D' => 'Class D — we coach your body; the equipment itself is not '
            'detected.',
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

  static String metaLine(MovementEntry m) => <String>[
        LibraryCatalogue.labelFor(m.family),
        _titleCase(m.level),
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
