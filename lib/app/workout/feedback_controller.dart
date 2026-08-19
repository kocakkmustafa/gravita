import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart'
    show FeedbackCandidate, FeedbackDecision, FeedbackPrioritizer, FeedbackSeverity;

/// [RepEngine]in tek-rep düzeltmesini motion_core'un PAYLAŞILAN
/// `FeedbackPrioritizer`ına adapte eder (GRA-P1-004 Step 1/2).
///
/// ## Neden bu dosya var — motor zaten "tek düzeltme" seçiyor, o zaman?
///
/// `RepEngine.topCorrection()` TEK bir repin metriklerinden EN İYİ
/// [FormError]ı seçer — ama HİÇ hafızası yok: aynı hatayı her tekrarda
/// yeniden söyler, art arda iki farklı hata gelirse ikisini de HEMEN söyler.
/// `FeedbackPrioritizer` (motion_core, PAYLAŞILAN, salt-okunur) tam bunun
/// için var: cooldown, "aynı anda en fazla bir şey söylenir", "çözüldü"
/// onayı. Bu dosya YALNIZ köprü — motor mantığı BURAYA kopyalanmıyor,
/// motion_core'un KENDİSİ de değiştirilmiyor (SERT KURAL: salt-okunur).
///
/// ## Sınıf B hiçbir zaman form hükmü ÜRETMEZ — İKİ katmanlı garanti
///
/// (1) İçerik: class-B hareketlerin `formErrors`i BOŞ yazılır (ölçüldü,
/// `content/catalog/w2/floor_press.json`) — `topCorrection` zaten hiçbir
/// şey bulamaz. (2) KOD: bu denetleyici `config.claimsFormVerdict` FALSE
/// ise motoru HİÇ SORMAZ — içerik yanlışlıkla bir formError eklese BİLE
/// blueprint'in "B sınıfı form hükmü VERMEZ" (`movement_config.dart:531-533`)
/// sözü koddan kırılamaz. `test/single_cue_test.dart`ın negatif testi TAM
/// bunu ölçer: gerçek `bodyweight_squat` içeriği (ATEŞLENDİĞİ KANITLI
/// metriklerle) sınıfı zorla B'ye çevrilip BİLE veriliyor — "içerik zaten
/// boş bırakıyordu" tesadüfüyle KARIŞTIRILMASIN diye.
///
/// Sınıf C katalogda YOK (`content/schema/movement-classes.json`:
/// `inCatalog: false`) — [MovementClass] enum'ında bile temsili yok, ÜÇÜNCÜ
/// katman: tip sistemi seviyesinde üretilmesi imkânsız.
///
/// ## Kapsam BİLEREK DAR — burada YOK olan
///
/// Bu dosya `live_session_screen.dart`a KABLOLANMADI. O ekran kendi dosya
/// başı yorumunda "cihazda DOĞRULANMADI" diyor (MediaPipe/kamera bu makinede
/// yok, tekrarlanan EXTERNAL_GATE bulgusu). Ses/görsel TESLİMİ (roadmap'in
/// "bundled audio"su) gerçek cihaz + kayıtlı ses içeriği ister — İKİSİ de bu
/// oturumun kapsamı DIŞINDA. Burada TEST EDİLEN tek iddia: hangi düzeltmenin
/// SEÇİLDİĞİ ve NE ZAMAN sessiz kalınması gerektiği — kamera olmadan da
/// TAM doğrulanabilir tek katman.
final class LiveFeedbackController {
  LiveFeedbackController({FeedbackPrioritizer? prioritizer})
      : _prioritizer = prioritizer ?? FeedbackPrioritizer();

  final FeedbackPrioritizer _prioritizer;

  /// Bir tekrar bittiğinde çağrılır. [metrics] `RepEngine.repMetrics(rep)`in
  /// çıktısıyla AYNI şekli taşır — `topCorrection`ın kendi test edilebilir
  /// imzasıyla TUTARLI (bkz. `rep_engine_test.dart`), tam bir [Rep] nesnesi
  /// kurmaya gerek KALMADAN sınanabilir.
  FeedbackDecision evaluate({
    required RepEngine engine,
    required Map<String, double> metrics,
    required int tUs,
  }) {
    if (!engine.config.claimsFormVerdict) {
      return const FeedbackDecision.silent(
          'movement class does not claim form verdict');
    }
    final FormError? error = engine.topCorrection(metrics);
    if (error == null) {
      return const FeedbackDecision.silent('no correction firing');
    }
    return _prioritizer.consider(
      <FeedbackCandidate>[
        FeedbackCandidate(
          code: error.id,
          severity: _severityFor(error.priority),
          tUs: tUs,
        ),
      ],
      tUs,
    );
  }

  /// `FormError.priority` (motor sözlüğü: safety/blocking/balance/
  /// major_alignment/minor_form/optimization, `movement_config.dart`'ın
  /// `rank` sırası) → `FeedbackSeverity` (motion_core sözlüğü). İkisi AYNI
  /// isimler DEĞİL — elle eşleniyor, göreli sıra KORUNARAK (safety önce,
  /// optimization/minor_form en son). Bilinmeyen bir öncelik string'i
  /// `validate_catalog`ın kendi şema denetiminde zaten yakalanır (içerik
  /// bu dosyaya ulaşmadan önce) — buradaki `minor` varsayılanı savunma
  /// katmanıdır, sessiz veri kaybı DEĞİL.
  static FeedbackSeverity _severityFor(String priority) => switch (priority) {
        'safety' => FeedbackSeverity.safety,
        'blocking' => FeedbackSeverity.critical,
        'balance' || 'major_alignment' => FeedbackSeverity.major,
        'minor_form' || 'optimization' => FeedbackSeverity.minor,
        _ => FeedbackSeverity.minor,
      };

  /// Yeni bir seans başlarken cooldown/tekrar geçmişini temizler.
  void reset() => _prioritizer.reset();
}
