import 'package:flutter/material.dart';
import 'package:gravita_engine/gravita_engine.dart';

import 'app_locale.dart';
import 'camera_release_policy.dart';
import 'progress_strings.dart';

/// App-only display copy. Stored IDs, units and measurement contracts do not
/// change with language. Unrecognised source text stays visible for review.
final class ProgressCopy {
  ProgressCopy(this.context);
  final BuildContext context;
  bool get _tr => Localizations.localeOf(context).languageCode == 'tr';
  String _text(String en, String tr) => localized(context, en, tr);

  String get measuredSection =>
      _text(ProgressStrings.measuredSection, 'Ölçülenler');
  String get measuredSubtitle =>
      _text(ProgressStrings.measuredSubtitle, 'Saydıklarımız. Puan değildir.');
  String get lockedSection => _text(ProgressStrings.lockedSection, 'Kilitli');
  String get lockedSubtitle => _text(
    ProgressStrings.lockedSubtitle,
    'Neye puan veremiyoruz ve neden? Bunlar ölçümümüzün sınırlarıdır; senin değil.',
  );
  String get lockedBadge => _text('LOCKED', 'KİLİTLİ');
  String get notesSection => _text(ProgressStrings.notesSection, 'Notlar');
  String get freeSection =>
      _text(ProgressStrings.freeSection, 'Ders dışındaki oturumlar');
  String get freeSubtitle => _text(
    ProgressStrings.freeSubtitle,
    'Bu oturumları ders içinden değil, oturum düğmesinden başlattın. Ayrı saklanırlar '
    've yukarıdaki derslere sayılmazlar; her ders belirli bir şeyi ölçer ve bu '
    'oturumlar o ölçüme göre değerlendirilmedi.',
  );
  String get emptyHistory =>
      _text(ProgressStrings.emptyHistory, 'Kayıtlı oturum yok.');
  String get notStarted => _text(ProgressStrings.notStarted, 'Başlanmadı');
  String get releaseBoundary => _text(
    'Live camera sessions are unavailable in this release. Your own course '
        'reports appear on the course pages; they are separate from camera measurements.',
    'Bu sürümde canlı kamera oturumları kullanılamıyor. Derslerdeki kendi '
        'bildirimlerin kurs sayfalarında görünür; kamera ölçümlerinden ayrı tutulur.',
  );
  String get historyUnavailable => _text(
    ProgressStrings.historyUnavailable,
    'Bu cihazdaki çalışma geçmişini okuyamadık. Derslerin çalışmaya devam eder, '
    'ancak ne yaptığını tahmin etmeyeceğiz; aşağıdakiler çalışmanın sayımı değildir. '
    'Uygulamayı yeniden açmayı deneyebilirsin. Yerel geçmişi korumak için uygulamayı yüklü tut.',
  );
  String get historyUnderLock => _text(
    ProgressStrings.historyUnderLock,
    'Aşağıdaki bazı oturumlar yeniden kilitlenen bir derse ait. Çalışmanı sakladık; ölçümü geri çektik.',
  );

  String units(int n, String label) => _tr
      ? '$n ${switch (label) {
          'rep' => 'tekrar',
          'second' => 'saniye',
          _ => label,
        }}'
      : ProgressStrings.units(n, label);
  String sessions(int n) => _tr ? '$n oturum' : ProgressStrings.sessions(n);
  String worked(int seconds) {
    if (!_tr) return ProgressStrings.worked(seconds);
    if (seconds < 60) return '$seconds sn çalışma';
    final minutes = seconds ~/ 60, remainder = seconds % 60;
    return remainder == 0
        ? '$minutes dk çalışma'
        : '$minutes dk $remainder sn çalışma';
  }

  String historyPartial(int n) => _tr
      ? 'Aşağıdaki sayılar tam toplam değil, alt sınırdır: $n kayıtlı oturum okunamadı. Gerçek toplamların en az burada gösterilen kadardır.'
      : ProgressStrings.historyPartial(n);
  String unmeasured(int n, String label, List<String> reasons) {
    if (!_tr) return ProgressStrings.unmeasured(n, label, reasons);
    final why = reasons.isEmpty
        ? ''
        : ' (${reasons.map((r) => r == 'framing' ? 'kadraj' : r).join(', ')})';
    return '${units(n, label)} ölçülemedi$why. İlerlemen azalmaz.';
  }

  String unscored(int n) => _tr
      ? '${sessions(n)} sayıldı, puanlanmadı.'
      : ProgressStrings.unscored(n);
  String retroactiveWithheld(int n) => _tr
      ? '${sessions(n)} sayılmış, puanlanmamış olarak kalır. Puanlamayı daha sonra açtık; o sırada ölçmediğimiz oturumları geriye dönük puanlamayız.'
      : ProgressStrings.retroactiveWithheld(n);
  String orphanRecords(int n) => _tr
      ? 'Ayrıca mevcut derslerle eşleşmeyen $n derse ait geçmiş var. Saklandı; burada gösterilmiyor.'
      : ProgressStrings.orphanRecords(n);

  /// Each stored unit keeps its own total. A second must never become a rep.
  String freeSessions(List<SessionRecord> records) {
    final totals = <String, int>{};
    for (final r in records) {
      totals.update(
        r.unitLabel,
        (n) => n + r.unitsCompleted,
        ifAbsent: () => r.unitsCompleted,
      );
    }
    final values = totals.entries.map((e) => units(e.value, e.key)).join(' · ');
    return '${sessions(records.length)} · $values ${_tr ? 'sayıldı' : 'counted'}';
  }

  String lessonName(LessonProgress lesson) {
    if (!_tr) return lesson.displayName;
    return switch ((lesson.lessonId, lesson.displayName)) {
      (
        'leg_foundations.reps_and_depth' || 'push_foundations.reps_and_tempo',
        'Reps that count',
      ) =>
        'Sayılan tekrarlar',
      ('leg_foundations.depth_and_lean_check', 'Depth & lean check') =>
        'Derinlik ve eğim kontrolü',
      ('push_foundations.form_check', 'Body-line check') =>
        'Gövde çizgisi kontrolü',
      _ => lesson.displayName,
    };
  }

  String movementName(LessonProgress lesson) {
    if (!_tr) return lesson.movementName;
    return switch ((lesson.lessonId.split('.').first, lesson.movementName)) {
      ('leg_foundations', 'Bodyweight Squat') => 'Vücut ağırlığıyla squat',
      ('push_foundations', 'Push-Up') => 'Şınav',
      _ => lesson.movementName,
    };
  }

  String lockedReason(LessonProgress lesson) {
    final source = lesson.lockedReason ?? '';
    final copy = _lockedReasons[lesson.lessonId];
    if (copy == null || source != copy.source) return source;
    // Historical catalogue availability is distinct from release access.
    final body = _tr ? copy.turkish : copy.source;
    if (motionPaidCameraLaunchEnabled) return body;
    final ending = _tr ? copy.turkishEnding : copy.sourceEnding;
    return body.substring(0, body.length - ending.length) +
        _text(
          'This describes the measurement contract; live camera sessions are unavailable in this release.',
          'Bu açıklama ölçüm sözleşmesini anlatır; bu sürümde canlı kamera oturumları kullanılamıyor.',
        );
  }
}

typedef _LockedCopy = ({
  String source,
  String sourceEnding,
  String turkish,
  String turkishEnding,
});

const Map<String, _LockedCopy> _lockedReasons = {
  'leg_foundations.depth_and_lean_check': (
    source:
        "We can see your depth and lean, but we can't grade them. Our instructor reference is attested (5 instructors, 25 takes) — hip and thigh tolerances come from their measured spread, but knee, shin and torso still sit at our default floor. A depth or lean judgement would come from that default, not from real instructors, so we won't score you against it. Rep counting is unaffected and stays open.",
    sourceEnding: 'Rep counting is unaffected and stays open.',
    turkish:
        'Derinliği ve eğimi görebiliriz, ancak bunlara puan veremeyiz. Eğitmen referansımızın kaynağı doğrulanmış olsa da (5 eğitmen, 25 çekim), yalnız kalça ve uyluk toleransları ölçülen dağılımdan geliyor; diz, kaval ve gövde toleransları hâlâ varsayılan alt sınırımızda. Derinlik veya eğim hükmü gerçek eğitmenlerden değil, bu varsayımdan geleceği için buna göre puan vermeyiz. Tekrar sayımı etkilenmez ve açık kalır.',
    turkishEnding: 'Tekrar sayımı etkilenmez ve açık kalır.',
  ),
  'push_foundations.form_check': (
    source:
        "We can see your body line, but we can't grade it. Our instructor reference is attested (5 instructors, 36 takes) — but not one of the nine joint tolerances came out of the instructors' measured disagreement; every one still sits at our default floor. A 'good line' number would come from that default, not from real instructors, so we won't score you against it. Rep counting and depth are unaffected and stay open.",
    sourceEnding: 'Rep counting and depth are unaffected and stay open.',
    turkish:
        'Gövde çizgisini görebiliriz, ancak buna puan veremeyiz. Eğitmen referansımızın kaynağı doğrulanmış olsa da (5 eğitmen, 36 çekim), dokuz eklem toleransının hiçbiri eğitmenler arasındaki ölçülmüş farktan türetilmedi; hepsi hâlâ varsayılan alt sınırımızda. İyi bir gövde çizgisi puanı gerçek eğitmenlerden değil, bu varsayımdan geleceği için buna göre puan vermeyiz. Tekrar sayımı ve derinlik etkilenmez ve açık kalır.',
    turkishEnding: 'Tekrar sayımı ve derinlik etkilenmez ve açık kalır.',
  ),
};
