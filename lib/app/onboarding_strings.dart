/// İlk-açılış (onboarding) metinleri — `docs/PRD.md` §3.1 + `docs/design/
/// UI-BRIEF.md` §3.1 (O1/O2/O5)'ten TÜRETİLDİ, icat edilmedi.
///
/// **Kapsam DAR (bilerek):** PRD §3.1'in beş adımından yalnız ÜÇÜ burada —
/// O1 (Value) · O2 (Safety consent) · O5 (Camera permission). O3 (Profile)
/// ve O4 (Pain branch) BİLEREK atlandı: `profile_screen.dart`ın kendi
/// gerekçesiyle AYNI kural — "bir ayar satırı, arkasında DEĞİŞTİRİLECEK bir
/// şey olmadan çizilirse ölü butondur". Bugün yaş/boy/kilo/deneyim/hedef-
/// beceri/sıklık/ağrı alanlarını OKUYAN hiçbir ürün kodu yok (skill-graph
/// başlangıç-düğümü seçimi, ağrı-dalı kilitleme — hiçbiri henüz yazılı
/// değil). Bu alanları toplayıp hiçbir şeyde kullanmamak "beyan var, okuyanı
/// yok"un veri-toplama sınıfı olurdu. O3/O4 ayrı bir karar: ya bu alanları
/// TÜKETEN kod önce gelir, ya da alanlar buraya gelmeden önce YOKLUĞU
/// kayda geçer (koordinatöre iletildi, adı G-127).
abstract final class OnboardingStrings {
  // ── O1 — Value ──────────────────────────────────────────────────────
  static const String valueTitle = 'What Gravita is — and isn\'t';
  /// ⛔ **HER YENİ KULLANICININ GÖRDÜĞÜ İLK CÜMLE — ve bir kez YALAN
  /// SÖYLEDİ (G-213).** Eski hâli:
  /// *"Your phone camera watches your form and counts your reps, on-device.
  /// **When a rule fires, we tell you what to change.**"*
  ///
  /// `G-212`de ölçüldü: kuralları değerlendiren API
  /// (`RepEngine.correctionFor` / `topCorrection`) **üründe HİÇ
  /// ÇAĞRILMIYOR** — tek çağıran çevrimdışı `tool/replay_gate.dart`.
  /// Canlı seansta hiçbir kural ateşlenmiyor ve **kimseye bir şey
  /// söylenmiyor.** Ürünün kendi içeriği de bunu zaten yazıyordu
  /// (*"during a live session no cue appears on screen"*).
  ///
  /// > ***BİR ÜRÜNÜN İLK CÜMLESİ, EN ÇOK OKUNAN CÜMLESİDİR — ORADAKİ BİR
  /// > VAAT, EN PAHALI VAATTİR.***
  ///
  /// ⚠️ Sınıf farkı kayda geçiyor: `G-210`/`G-212` **bayat YOKLUK**
  /// cümleleriydi (*"yok"* derken var olmuştu). Bu ise **yanlış VARLIK**
  /// cümlesi (*"var"* derken hiç olmamış). Yokluk beyanı arayan bir süpürge
  /// bunu **tanımı gereği** bulamaz — nitekim benimki bulmadı; bunu
  /// uygulamayı AÇMAK buldu.
  static const String valueWhatWeDo =
      'Your phone camera counts your reps, on-device, and only counts one '
      'when it can see you are really doing the movement. It does not grade '
      'your form, and nothing corrects you while you train.';
  // UI-BRIEF §3.1 O1 — birebir.
  static const String valueWhatWeDont =
      'Not medical. Not a substitute for a coach. We cannot stop you from '
      'falling.';
  static const String valueContinue = 'Continue';

  // ── O2 — Safety consent ────────────────────────────────────────────
  static const String safetyTitle = 'Before you start';
  // content/skill-graph/handstand.v1.json → safetyCopy.generalDisclaimer,
  // BİREBİR (elle yazılmadı, kaynaktan kopyalandı).
  static const String safetyDisclaimer =
      'Gravita is a movement-practice tool, not a medical service and not a '
      'substitute for an in-person coach. It cannot prevent a fall.';
  static const String safetySpaceRule =
      'Clear a space before you begin: a flat, non-slip floor with nothing '
      'within arm\'s reach, and — for any movement that uses one — a wall '
      'you can see fully in frame.';
  static const String safetyConsent = 'I understand and agree';

  // ── O5 — Camera permission ─────────────────────────────────────────
  static const String cameraTitle = 'Camera access';
  // İkinci cümle live_strings.dart → failureBody(permissionDenied) ile
  // BİREBİR aynı ("nothing is recorded or uploaded..."): iki yerde iki
  // farklı gerekçe olmaz.
  /// ⛔ *"and check your form"* KALDIRILDI (G-213). Ürün formu kontrol
  /// ETMİYOR (`G-212`: kural değerlendirmesi hiç çağrılmıyor) — ve bu bir
  /// **kamera izni gerekçesiydi**, yani kullanıcıya *"kameranı şunun için
  /// istiyorum"* denen yer. Orada yapılmayan bir işi saymak, iznin kendisini
  /// yanlış gerekçeyle almaktır.
  ///
  /// 🪞 Üstelik ürün **kendi içinde çelişiyordu**: aynı iznin öteki gerekçesi
  /// (`live_strings.failureBody(permissionDenied)`) zaten yalnız
  /// *"count your reps"* diyordu. Yukarıdaki yorumun *"iki yerde iki farklı
  /// gerekçe olmaz"* kuralı **yazılmıştı ama tutmuyordu** — ikinci cümleler
  /// birebirdi, BİRİNCİ cümleler ayrışmıştı. Nöbetçisi:
  /// `test/onboarding_claims_test.dart`.
  static const String cameraRationale =
      'Gravita needs your camera to count your reps. '
      'Nothing is recorded or uploaded — video stays on this device and '
      'never leaves it.';
  static const String cameraAllow = 'Allow camera access';
  static const String cameraDeniedTitle = 'Camera access is off';
  static const String cameraDeniedBody =
      'You can turn it on later in Settings. You can still browse the '
      'library and lessons without it.';
  static const String cameraContinueWithout = 'Continue without camera';
}
