import 'package:motion_camera/motion_camera.dart';

/// Canlı seans yüzeyinin kullanıcı metinleri.
///
/// Metin MOTORDA değil burada (G-100 dersi): motor kullanıcı cümlesi üretmez.
/// Her cümle ne olduğunu söyler ve ne yapılacağını *önerir* — emir kipi yok.
abstract final class LiveStrings {
  static const String title = 'Push-ups';

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
      "We can't see anyone yet. Step into frame, head to heels.";

  static String reps(int n) => n == 1 ? '1 rep' : '$n reps';

  /// Sayım devam ederken taban beyanı: bu bir skor değil.
  static const String countingNote = 'Counted, not scored.';

  /// Tekrar henüz yokken — "0" yazmak yerine ne beklediğimizi söylüyoruz.
  static const String noRepsYet = 'No full rep yet.';

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
  static const String gateNote =
      'We only count a rep when we can see your torso is actually horizontal. '
      'Reps we could not verify are left out rather than guessed.';
}
