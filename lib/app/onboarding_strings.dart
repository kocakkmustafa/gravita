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
  static const String valueWhatWeDo =
      'Your phone camera watches your form and counts your reps, on-device. '
      'When a rule fires, we tell you what to change.';
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
  static const String cameraRationale =
      'Gravita needs your camera to count reps and check your form. '
      'Nothing is recorded or uploaded — video stays on this device and '
      'never leaves it.';
  static const String cameraAllow = 'Allow camera access';
  static const String cameraDeniedTitle = 'Camera access is off';
  static const String cameraDeniedBody =
      'You can turn it on later in Settings. You can still browse the '
      'library and lessons without it.';
  static const String cameraContinueWithout = 'Continue without camera';
}
