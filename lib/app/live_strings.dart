import 'package:motion_camera/motion_camera.dart';

/// Canlı seans yüzeyinin kullanıcı metinleri.
///
/// Metin MOTORDA değil burada (G-100 dersi): motor kullanıcı cümlesi üretmez.
/// Her cümle ne olduğunu söyler ve ne yapılacağını *önerir* — emir kipi yok.
abstract final class LiveStrings {
  // ⛔ SABİT BAŞLIK KALDIRILDI (G-205) — buraya yeni bir tane EKLEME.
  //
  // Burada `static const String title = 'Push-ups';` vardı. Ürünün canlı
  // seansa TEK girişi `ContentRepository.liveConfig`tir ve o **İLK** uygun
  // hareketi döndürür; `library.json` sırası `[0] bodyweight_squat` olduğu
  // için açılan seans **squat**tır. ⇒ Her canlı seans, yapılmayan hareketin
  // adıyla başlıklanıyordu.
  //
  // İki kat beter: başlıkta yazan `push_up` tam da BAŞLATILAMAYAN hareket
  // (`startable_reach_test.dart`: `bilinenUlasilamaz = {'push_up'}`) — yani
  // sabit başlık, ürünün ulaşılamayan yarısını ulaşılabilir yarısının
  // üstüne yazıyordu.
  //
  // Başlık bir METİN SABİTİ DEĞİL, İÇERİKTİR: `MovementConfig.name`
  // (`content/catalog/w1/*.json` → `"name"`). Ekran onu doğrudan çizer.
  // Kapısı `live_screen_test.dart` → *"seans başlığı İÇERİKTEN gelir"*:
  // aynı ekran iki ayrı config'le pump edilir ve İKİ AYRI başlık beklenir,
  // yani herhangi bir sabit başlık o süiti tanım gereği kırar.

  /// Başlamadan önce. Kadraj talimatı katalogdan gelen çekim kurulumuyla
  /// tutarlı (`camera.setup: side45`, `framing: full_body`).
  static const String idle =
      'Set your phone down so it sees you from head to heels, roughly side-on. '
      'We count reps and time your tempo — nothing is scored.';

  static const String starting = 'Opening the camera…';

  static const String start = 'Start';
  static const String stop = 'Stop';

  /// ⚠️ Kamera çalışıyor ama kimse görünmüyor. Bu bir ARIZA DEĞİL ve öyle
  /// yazılmaz — kullanıcı yalnızca kadrajın dışında.
  static const String noPerson =
      "We can't see anyone. Step into frame, head to heels.";

  static String reps(int n) => n == 1 ? '1 rep' : '$n reps';

  /// Sayım devam ederken taban beyanı: bu bir skor değil.
  static const String countingNote = 'Counted, not scored.';

  /// Tekrar henüz yokken — "0" yazmak yerine ne beklediğimizi söylüyoruz.
  static const String noRepsYet = 'No full rep counted.';

  /// İzin **kalıcı olarak** engelliyken (`permanentlyDenied`/`restricted`).
  ///
  /// Neden ayrı metin: geçici rette sistem diyaloğu bir daha çıkar, kalıcı
  /// rette ÇIKMAZ. Aynı cümleyi kullanmak, kullanıcıya tekrar denemesini
  /// söyleyip her denemede aynı duvara çarptırırdı (G-185 ölçümü).
  static const String permissionBlockedTitle = 'Camera access is blocked';

  /// ⚠️ HANGİ sebep olduğu İDDİA EDİLMİYOR. İki ayrı durum aynı yere düşer:
  /// kullanıcı izni kalıcı reddetmiş olabilir, ya da cihaz yönetilen
  /// (MDM/ebeveyn denetimi) olduğu için izin diyaloğu HİÇ çıkmıyordur.
  /// İkisini ayırt edecek bir ölçüm elimizde yok; metin de ayırmıyor.
  static const String permissionBlockedBody =
      'Asking again will not bring up the system prompt — this device will '
      'not offer it. Camera access has to be turned on in Settings. Nothing '
      'is recorded or uploaded; video stays on this device and never leaves '
      'it. Your history and lessons are unaffected.';

  /// Kalıcı engelde çizilen TEK eylem.
  static const String openSettings = 'Open Settings';

  /// Arıza başlıkları — her ret ADIYLA anlatılır, ham kod gösterilmez.
  static String failureTitle(CameraFailure? f) => switch (f) {
        CameraFailure.permissionDenied => 'Camera access is off',
        CameraFailure.modelLoadFailed => "We couldn't load our pose model",
        CameraFailure.alreadyRunning => 'A session is already running',
        CameraFailure.notRunning => 'No session is running',
        CameraFailure.noSuchCamera => "We couldn't find that camera",
        null => "The camera stopped for a reason we don't recognise",
      };

  static String failureBody(CameraFailure? f) => switch (f) {
        CameraFailure.permissionDenied =>
          'Gravita needs the camera to count your reps. You can turn it on in '
              'Settings; nothing is recorded or uploaded — video stays on this '
              'device and never leaves it.',
        CameraFailure.modelLoadFailed =>
          'The pose model that ships with the app could not be opened. '
              'Reinstalling usually fixes it. Your lessons and history are '
              'unaffected.',
        CameraFailure.alreadyRunning =>
          'Only one camera session runs at a time. Stopping the other one '
              'frees it up.',
        CameraFailure.notRunning =>
          'The session had already stopped when we tried to stop it. Nothing '
              'was lost.',
        CameraFailure.noSuchCamera =>
          'This device did not offer the camera we asked for. If it has a '
              'front and a back camera, switching may help.',
        null =>
          'We would rather name the problem than guess at it. The technical '
              'detail is below; your lessons and history are unaffected.',
      };

  static const String detailLabel = 'Technical detail';

  /// ⚠️ Kalibrasyon kapısı beyanı (katalog `camera.calibrationGate: true`).
  /// K8 uyumu: kalibrasyon yokken SAYISAL SKOR yok — ama sayım ve tempo
  /// skor DEĞİL, ölçümdür ve kimlik kapısıyla korunur (G-043).
  ///
  /// ⛔ **HAREKETE ÖZEL CÜMLE BURADA DEĞİL — İÇERİKTE** (`G-205`).
  /// Burada şu SABİT duruyordu:
  /// *"We only count a rep when we can see your torso is actually
  /// horizontal."* O cümle **şınavın** kimlik kapısıdır
  /// (`torso_angle_from_vertical >= 60`). Ürünün tek ulaşılabilir seansı ise
  /// **squat**tır ve onun kapısı BAŞKADIR (kalça-diz Pearson >= 0,2, çevrim
  /// başına) ⇒ kullanıcıya **ölçülmeyen bir şey ölçülmüş gibi** sunuluyordu.
  /// Başlık kusuru (aynı tur) bir ADLANDIRMA hatasıydı; bu bir **ÖLÇÜM
  /// İDDİASI** hatasıdır ve daha ağırdır.
  ///
  /// Harekete özel cümle: `measurementContract.gateNote`.
  ///
  /// Aşağıdaki yedek **hareketten bağımsız DOĞRUDUR** ve hiçbir kapı iddia
  /// etmez — özel cümlesi olmayan bir hareket başka bir hareketin kapısını
  /// göstermektense hiçbir kapı adı göstermez. Canlı hareketlerin buraya
  /// düşmesi ayrı bir kapıyla yasak (`live_screen_test.dart`): yedek, eksik
  /// içeriği sessizce ÖRTMEK için değil, YALAN SÖYLEMEMEK için var.
  static const String gateNoteFallback =
      'We only count a rep we can actually verify. '
      'Reps we could not verify are left out rather than guessed.';

  // ── Seans BİTTİĞİNDE (G-207) ───────────────────────────────────────────
  //
  // ⛔ Bu blok "kaydedildi" DEMEZ ve SKOR vermez. Yazma başarısızlığı sessizce
  // yutuluyor (bkz. `_persist`), dolayısıyla buradan bir kayıt iddiası
  // üretmek ölçmediğimiz bir şeyi beyan etmek olurdu. Ölçtüğümüz: kaç tekrar,
  // ne kadar sürdü, hangi tempoda.

  static const String finishedTitle = 'Set finished';

  /// Kare GÖRÜLDÜ ama hiç tam tekrar sayılmadı. Bu bir ARIZA DEĞİL ve öyle
  /// yazılmaz — gerçek ve saklanmaya değer bir sonuçtur (`_persist` kuralı).
  static const String finishedNoReps = 'No full rep counted.';

  static const String finishedNoRepsNote =
      'The camera was running and we watched the whole time — nothing we saw '
      'closed a full rep. Half reps and reps we could not verify are left out '
      'rather than guessed.';

  /// Hiç kare gelmedi ⇒ ortada seans YOK. `finishedNoReps` ile aynı cümleyi
  /// kullanmak "izledik ama sayamadık" ile "hiç bakamadık"ı birbirine
  /// karıştırırdı — biri ölçüm, öteki ölçüm YOKLUĞU.
  static const String finishedNoFrames = 'Nothing was recorded.';

  static const String finishedNoFramesNote =
      'The camera never delivered a frame, so there is nothing to show and '
      'nothing was added to your history.';

  /// Süre — dakika:saniye, sıfır dolgusu SANİYEDE (dakikada değil).
  static String finishedDuration(Duration d) {
    final int dk = d.inMinutes;
    final int sn = d.inSeconds % 60;
    return dk > 0 ? '$dk min ${sn}s' : '${sn}s';
  }

  /// Tempo — ölçülen ORTANCA iniş/çıkış. `scoreDisplay` band olduğu için
  /// burada bir NOT yok, yalnız süre var.
  static String finishedTempo(Duration descent, Duration ascent) =>
      '${_sn(descent)}s down · ${_sn(ascent)}s up (median)';

  static String _sn(Duration d) => (d.inMilliseconds / 1000).toStringAsFixed(1);

  static const String finishedNote = 'Counted, not scored.';

  /// Tek eylem: yeniden başla. Ekrandan ÇIKIŞ zaten AppBar'ın geri okunda —
  /// aynı işi yapan ikinci bir düğme çizmiyoruz.
  static const String goAgain = 'Go again';
}
