import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_camera/motion_camera.dart';
import 'package:motion_core/motion_core.dart';

/// Canlı seansın kullanıcıya görünen hâli — TİPLİ, metin değil.
///
/// Ham hata metni yüzeye SIZMAZ: her ret bir ada sahiptir ve o adın ne
/// anlama geldiğini yüzey söyler (`content_failure.dart` ve `HistoryStatus`
/// desenlerinin üçüncüsü).
sealed class LiveState {
  const LiveState();
}

/// Henüz başlamadı — kullanıcı başlatmadı ya da izin istenmedi.
final class LiveIdle extends LiveState {
  const LiveIdle();
}

/// Kamera açılıyor / model yükleniyor.
final class LiveStarting extends LiveState {
  const LiveStarting();
}

/// Oturum CANLI. [reps] ölçülmüş tekrarlar; [personVisible] kişi kadrajda mı.
///
/// ⚠️ `personVisible == false` bir HATA DEĞİL: kamera çalışıyor, kişi
/// çerçevede değil. İkisini aynı hâle koymak "kamera bozuk" ile "geri çekil"
/// arasındaki farkı siler.
final class LiveRunning extends LiveState {
  const LiveRunning({
    required this.reps,
    required this.personVisible,
    required this.framesSeen,
  });

  final List<Rep> reps;
  final bool personVisible;
  final int framesSeen;

  int get repCount => reps.length;
}

/// Oturum başlamadı ya da düştü — ADI olan bir sebeple.
final class LiveFailed extends LiveState {
  const LiveFailed(this.failure, {this.detail});

  /// `null` = tanınmayan bir arıza (plugin'in çevirmediği). Yüzey bunu
  /// "bilinmeyen" diye söyler, uydurmaz.
  final CameraFailure? failure;

  /// Geliştirici ayrıntısı. Yüzeyde BİRİNCİL gösterilmez (G-102 dersi:
  /// ayrıntı gizlenmez, İKİNCİLLEŞTİRİLİR).
  final String? detail;
}

/// Kameradan gelen zarfları motorun beklediği sırayla motora bağlayan dikiş.
///
/// **Neden ayrı sınıf:** bu mantık ekrandan bağımsız test edilebilir olmak
/// zorunda — cihaz doğrulaması İSİMLİ bir release-gate (M-F-263) ve o güne
/// kadar canlı yolun doğruluğu YALNIZ burada kanıtlanabilir. Ekran bu
/// sınıfı sürer, mantığı taşımaz.
///
/// Zincir: `frames()` (push) → [EnvelopeDriver.load] → [OrientationAwarePoseSource.next]
/// (pull) → [RepEngine.addFrame]. Push↔pull dikişi `EnvelopeDriver`in işidir;
/// yanlış zaman damgası sorulursa o FIRLATIR — `null` zaten "kimseyi görmedim"
/// demek, ona "yanlış soru" anlamını da yüklemek tesisat hatasını ölçüm
/// kılığına sokardı.
final class LiveSessionRunner {
  LiveSessionRunner({
    required this.config,
    required this.frameSize,
    EnvelopeDriver? driver,
    OrientationAwarePoseSource? source,
  })  : _driver = driver ?? EnvelopeDriver(),
        _engine = RepEngine(config) {
    _source = source ?? OrientationAwarePoseSource(_driver);
  }

  final MovementConfig config;
  final FrameSize frameSize;
  final EnvelopeDriver _driver;
  late final OrientationAwarePoseSource _source;
  final RepEngine _engine;

  int _framesSeen = 0;
  bool _personVisible = false;

  List<Rep> get reps => _engine.reps;
  int get framesSeen => _framesSeen;
  bool get personVisible => _personVisible;

  /// Tek zarfı işler. Ekran bunu `frames()` akışından çağırır; test aynı
  /// çağrıyı elle yapar — **aynı kod yolu**, taklit değil.
  void consume(CameraFrameEnvelope envelope) {
    _framesSeen++;
    _driver.load(envelope);
    // ⚠️ push_up gövdesi YATAYDIR ve çekirdeğin `observedOrientation`ı yatay
    // gövde için `null` döner ("yatan bir vücudun ileri süreceği dikey
    // yönelim yoktur" — belirsiz girdide hüküm yok kuralı). Bu yüzden
    // beklenti ÜRÜNDEN gelir: Gravita'nın bu hattında ters-duruş YOK, o
    // yüzden `exactly(upright)`. `ambiguous()` seçmek her kareye ÇİFT
    // çıkarım maliyeti bindirirdi (ADR-001 sonuç #2) ve karşılığında hiçbir
    // şey kazandırmazdı: burada ayırt edilecek iki yönelim yok.
    // Hareketin gerçekten yapılıp yapılmadığını yönelim değil KİMLİK KAPISI
    // söyler (torso ≥60°, G-043) ve o motorda, kare düzeyinde çalışıyor.
    final OrientationResolution res = _source.next(
      envelope.tUs,
      const OrientationExpectation.exactly(BodyOrientation.upright),
    );
    final PoseFrame? frame = res.frame;
    _personVisible = frame != null;
    if (frame == null) return;
    _engine.addFrame(frame, frameSize, expected: res.resolved);
  }

  /// O anki hâl — ekran bunu doğrudan çizer.
  LiveRunning get state => LiveRunning(
        reps: reps,
        personVisible: _personVisible,
        framesSeen: _framesSeen,
      );
}

/// Biten bir serbest seansın KAYDI — ya da `null` (kaydedilmeyecek).
///
/// **Neden ekrandan ayrı:** "ne yazılır ve ne zaman HİÇ yazılmaz" bir ÜRÜN
/// kararıdır, bir çizim değil. Ekranın içinde kalsaydı yalnız widget testiyle
/// ve sahte kamerayla sınanabilirdi; burada saf Dart olarak sınanıyor. Bu,
/// `LiveSessionRunner`ın ayrı sınıf olma gerekçesinin aynısı.
///
/// **Kaydedilmeme kuralı — kare YOKSA seans YOKTUR.** Kamera hiç kare
/// vermediyse ortada bir seans değil, başlatılamamış bir deneme vardır;
/// sıfır-kareli kayıt geçmişi gürültüyle doldurur ve kullanıcıya "bir şey
/// yaptım" izlenimi verir.
///
/// **Sıfır TEKRAR ama kare VARSA kaydedilir:** kamera çalıştı, hiç tam tekrar
/// sayılmadı — bu GERÇEK bir sonuçtur. Silmek, ölçümü beğenmediğimiz için
/// saklamak olurdu.
SessionRecord? buildFreeSessionRecord({
  required String movementId,
  required LiveState state,
  required DateTime startedAt,
  required DateTime endedAt,
}) {
  if (state is! LiveRunning || state.framesSeen == 0) return null;
  final int worked = endedAt.difference(startedAt).inSeconds;
  return SessionRecord(
    // Ders DEĞİL hareket anahtarı — bu kayıt ders trendine karışamaz.
    lessonId: freeSessionKeyFor(movementId),
    completedAt: endedAt,
    // Negatif süre YAZILMAZ: saat geri alınmışsa 0 yazmak, eksi bir "çalışma"
    // yazmaktan dürüst.
    workedSeconds: worked < 0 ? 0 : worked,
    unitsCompleted: state.repCount,
    // Serbest seansın PLANI yoktur. 0, "hedefini tutturamadın" değil
    // "hedef konmadı" demektir.
    plannedUnits: 0,
    unitLabel: 'rep',
    // Sayıyoruz, NOT VERMİYORUZ — bugünkü gerçek bu.
    lessonClass: 'measurementOnly',
  );
}

/// Serbest seans kaydının hareket anahtarı — TEK ev.
String freeSessionKeyFor(String movementId) => 'movement:$movementId';
