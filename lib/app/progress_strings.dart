/// İlerleme yüzeyinin kullanıcıya görünen metinleri (V1 yalnız `en`, PRD §7).
///
/// **Neden ayrı dosya ve neden KABUKTA:** `ProgressSummary` motorda yaşıyor ve
/// motor kullanıcı metni ÜRETMEZ — bir ölçüm katmanının içine yerleşen kopya,
/// yarın çeviri/tasarım turunda motoru açmayı gerektirirdi. Kilit gerekçeleri
/// ise buraya da girmez: onlar `library.json`dan AYNEN taşınır (K5: kilit
/// gerekçesi eşik değeri değil, EKSİK ÖLÇÜMÜN adıdır).
///
/// **Sınır:** sözcük seçimi tasarım/cila turunda DEĞİŞEBİLİR. Değişemeyen şey
/// YAPI: sayı asla birimsiz çıkmaz. Bu yüzden `'$n'` biçiminde çıplak sayı
/// döndüren bir yardımcı YOKTUR — çağıran taraf birimsiz sayı yazamasın.
abstract final class ProgressStrings {
  static const String measuredSection = 'Measured';
  static const String measuredSubtitle = 'What we counted. Not a score.';

  static const String lockedSection = 'Locked';
  static const String lockedSubtitle =
      "What we can't grade, and why. These are limits in our measurement, "
      'not in you.';

  static const String notesSection = 'Notes';

  static const String emptyHistory = 'No sessions recorded.';

  /// Kısmi okuma (çekirdek 0.10.0 `unreadableRecords`). Sayı GÖSTERİLİR ama
  /// tabanın tam olmadığı söylenir. `unavailable` metninden AYRI durur: uç
  /// değer kısmi dalı susturamaz, ikisi farklı olguyu anlatır.
  static String historyPartial(int unreadable) {
    final String what =
        unreadable == 1 ? '1 saved session' : '$unreadable saved sessions';
    return 'Numbers below are a floor, not a full count: $what could not be '
        'read back, so your real totals are at least this high.';
  }

  static const String notStarted = 'Not started';

  /// Sayı + birim TEK PARÇA. `unitLabel` katalogdan gelir (`rep` · `second`),
  /// yani plank dersi "45 seconds", şınav dersi "5 reps" der — aynı ekranda.
  static String units(int n, String unitLabel) {
    final String noun = switch (unitLabel) {
      'rep' => n == 1 ? 'rep' : 'reps',
      'second' => n == 1 ? 'second' : 'seconds',
      // Bilinmeyen birim SESSİZCE "reps" olmaz: etiket olduğu gibi gösterilir,
      // yanlış birim göstermekten iyidir.
      _ => unitLabel,
    };
    return '$n $noun';
  }

  static String sessions(int n) => n == 1 ? '1 session' : '$n sessions';

  static String worked(int seconds) {
    if (seconds < 60) return '$seconds s worked';
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return s == 0 ? '$m min worked' : '$m min $s s worked';
  }

  /// PRD §3.4'ün sözü: *"İlerleme düşmez."* Ölçülemeyen iş SAKLANMAZ.
  static String unmeasured(int n, String unitLabel, List<String> reasons) {
    final String why = reasons.isEmpty ? '' : ' (${reasons.join(', ')})';
    return "${units(n, unitLabel)} we couldn't measure$why. "
        "Your progress doesn't drop.";
  }

  /// Ders o gün ölçülüyordu ama NOTLANMIYORDU. `—` değil AÇIK cümle: boşluk
  /// "eksik değer" gibi okunur, oysa söylenecek şey hükmün YOKLUĞUdur.
  ///
  /// Ad `unscored`: çekirdek 0.9.0'dan beri sınıf açık sözlük ve `'scored'`
  /// dışındaki HER sözcük (app'in `measurementOnly`'si, Choreia'nın
  /// `demoOnly`'si, boş, bilinmeyen) buraya düşer.
  static String unscored(int n) => '${sessions(n)} counted, not graded.';

  /// Retroaktif kredi yasağının kullanıcıya dönük hâli (M-F-168 kural 3).
  static String retroactiveWithheld(int n) =>
      '${sessions(n)} stay counted-not-graded. We opened grading later, and we '
      "don't grade sessions we didn't measure at the time.";

  /// Ders açıkken çalışıldı, sonra ölçüm geri çekildi (G-070 sınıfı geri adım).
  static const String historyUnderLock =
      'Some sessions below are for a lesson that is locked again. We kept your '
      'work; we pulled back the measurement.';

  /// ⭐ GRAVITA DELTASI: geçmiş okunamadı. **"Not started" DEMEK YASAK** —
  /// o cümle "hiç çalışmadın" demektir ve okunamayan bir geçmişte bunu
  /// bilmiyoruz. Sayı da gösterilmez: bilmediğimiz sayıyı sıfır yazmak,
  /// gecenin bütün dersinin tersi olurdu.
  static const String historyUnavailable =
      "We could not read your training history on this device. Your lessons "
      "still work, but we won't guess what you have done — nothing below is a "
      "count of your work. If this keeps happening, reinstalling should fix it.";

  /// Yüzeyde karşılığı olmayan kayıtlar. Sayı SÖYLENİR — sessizlik yalandır.
  static String orphanRecords(int n) =>
      'We also have $n lesson(s) of history that no current lesson matches. '
      'Kept, not shown here.';
}
