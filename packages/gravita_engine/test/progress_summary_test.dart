import 'package:gravita_engine/gravita_engine.dart';
import 'package:test/test.dart';

/// İlerleme yüzeyi VERİ katmanı testleri (M-F-168 orta yol, kalem 3).
///
/// Bu testlerin çoğu "hesap doğru mu"yu değil **yüzeyin yalan söylememesini**
/// sabitliyor: kilitli ders düşmüyor mu · ölçülemeyen iş görünüyor mu ·
/// geçmişe not verilmiyor mu · iki farklı birim tek sayıda toplanmıyor mu.
void main() {
  SessionRecord rec({
    String lessonId = 'push_foundations.reps_and_tempo',
    int worked = 120,
    int done = 5,
    int planned = 5,
    String unit = 'rep',
    String lessonClass = 'measurementOnly',
    int unmeasured = 0,
    String? reason,
    DateTime? at,
  }) =>
      SessionRecord(
        lessonId: lessonId,
        completedAt: at ?? DateTime.utc(2026, 7, 30, 12),
        workedSeconds: worked,
        unitsCompleted: done,
        plannedUnits: planned,
        unitLabel: unit,
        lessonClass: lessonClass,
        unmeasuredUnits: unmeasured,
        unmeasuredReason: reason,
      );

  const LessonSurface reps = LessonSurface(
    id: 'push_foundations.reps_and_tempo',
    displayName: 'Reps that count',
    unitLabel: 'rep',
    gradedToday: false,
  );
  const LessonSurface formLocked = LessonSurface(
    id: 'push_foundations.form_check',
    displayName: 'Body-line check',
    unitLabel: 'rep',
    gradedToday: false,
    lockedReason: 'Nine joint tolerances still sit at our default floor.',
  );
  const LessonSurface plank = LessonSurface(
    id: 'hold_foundations.plank',
    displayName: 'Plank',
    unitLabel: 'second',
    gradedToday: false,
  );

  group('yüzey sözleşmesi — ÖLÇÜMLER, NOT DEĞİL', () {
    // Bu iki test kural 1'in TEK canlı bekçisi. Yorum olarak yazılmış
    // "skor koymayacağız" sözü ilk aceleci commit'te ölür; anahtar kümesini
    // çivilemek onu yapısal kılar. Yeni alan eklemek MEŞRU olabilir — ama
    // ancak bu listeyi bilerek güncelleyerek, yani bir karar vererek.
    test('özet anahtar kümesi çivili — skor/derece/seri/seviye alanı YOK', () {
      final ProgressSummary s = ProgressSummary.build(
        lessonSurfaces: const <LessonSurface>[reps],
        records: <SessionRecord>[rec()],
      );
      expect(
        s.toJson().keys.toSet(),
        <String>{
          'totalWorkedSeconds',
          'unitTotals',
          'orphanRecordLessonIds',
          'lessons',
        },
        reason: 'Yüzeye yeni alan eklendi. Bir SKOR/DERECE/SERİ alanı mı? '
            'Gravita ölçtüğünü gösterir, not vermez (M-F-168).',
      );
    });

    test('ders anahtar kümesi çivili', () {
      final ProgressSummary s = ProgressSummary.build(
        lessonSurfaces: const <LessonSurface>[reps],
        records: <SessionRecord>[rec()],
      );
      final Map<String, dynamic> lesson =
          (s.toJson()['lessons'] as List<dynamic>).first as Map<String, dynamic>;
      expect(
        lesson.keys.toSet(),
        <String>{
          'lessonId',
          'displayName',
          'state',
          'unitLabel',
          'sessionCount',
          'workedSeconds',
          'unitsMeasured',
          'unitsUnmeasured',
          'unmeasuredReasons',
          'scoredSessions',
          'unscoredSessions',
          'withheldRetroactiveCredit',
          'hasRecordsWhileLocked',
        },
        reason: 'Ders düzeyinde yeni alan. Skor/derece/yüzde mi?',
      );
    });
  });

  group('geçilemez kapı BEYAN EDİLİR', () {
    test('ilk açılış: kayıt yok — çökmez, dersler notStarted olarak GÖRÜNÜR', () {
      // JabLab'ın `const []` kusurunun yüzey tarafındaki kardeşi: boş geçmiş
      // bir arıza değil, İLK KULLANIM.
      final ProgressSummary s = ProgressSummary.build(
        lessonSurfaces: const <LessonSurface>[reps, formLocked],
        records: const <SessionRecord>[],
      );
      expect(s.lessons.length, 2);
      expect(s.lessons.first.state, LessonProgressState.notStarted);
      expect(s.totalWorkedSeconds, 0);
      expect(s.unitTotals, isEmpty);
    });

    test('kilitli ders listeden DÜŞMEZ ve gerekçesini taşır', () {
      final ProgressSummary s = ProgressSummary.build(
        lessonSurfaces: const <LessonSurface>[reps, formLocked],
        records: <SessionRecord>[rec()],
      );
      final LessonProgress locked = s.lessons
          .firstWhere((LessonProgress l) => l.lessonId.endsWith('form_check'));
      expect(locked.state, LessonProgressState.locked);
      expect(locked.lockedReason, isNotNull);
      expect(locked.toJson().containsKey('lockedReason'), isTrue);
    });

    test('kilitli ders notlanıyor SAYILAMAZ (K9 lockClass:measurement)', () {
      expect(
        () => LessonSurface(
          id: 'x',
          displayName: 'X',
          unitLabel: 'rep',
          gradedToday: true,
          lockedReason: 'ölçüm yok',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('ders kilitliyken geçmiş varsa GİZLENMEZ, işaretlenir', () {
      // G-070 sınıfı geri adım: ders açıkken çalışıldı, sonra ölçüm geri
      // çekildi. Kullanıcının yaptığı iş silinmiş sayılmaz.
      final ProgressSummary s = ProgressSummary.build(
        lessonSurfaces: const <LessonSurface>[formLocked],
        records: <SessionRecord>[rec(lessonId: formLocked.id)],
      );
      expect(s.hasHistoryUnderLock, isTrue);
      expect(s.lessons.single.sessionCount, 1);
      expect(s.lessons.single.workedSeconds, 120);
    });
  });

  group('retroaktif kredi YOK', () {
    test('ders bugün not veriyor ama eski seanslar ölçüm-olarak yapılmıştı', () {
      const LessonSurface promoted = LessonSurface(
        id: 'push_foundations.form_check',
        displayName: 'Body-line check',
        unitLabel: 'rep',
        gradedToday: true,
      );
      final ProgressSummary s = ProgressSummary.build(
        lessonSurfaces: const <LessonSurface>[promoted],
        records: <SessionRecord>[
          rec(lessonId: promoted.id), // measurementOnly (dün)
          rec(lessonId: promoted.id, lessonClass: 'scored'), // bugün
        ],
      );
      final LessonProgress lp = s.lessons.single;
      expect(lp.scoredSessions, 1);
      expect(lp.unscoredSessions, 1);
      expect(lp.withheldRetroactiveCredit, 1,
          reason: 'Dün ölçülen seans, form notu bugün açıldı diye '
              'geçmişte notlanmış hâle gelmez.');
      expect(s.withheldRetroactiveCredit, 1);
    });

    test('ders not vermiyorsa withheld anlamsızdır — 0', () {
      final ProgressSummary s = ProgressSummary.build(
        lessonSurfaces: const <LessonSurface>[reps],
        records: <SessionRecord>[rec(), rec()],
      );
      expect(s.lessons.single.unscoredSessions, 2);
      expect(s.lessons.single.withheldRetroactiveCredit, 0);
    });
  });

  group('ölçülemeyen iş SAKLANMAZ (PRD §3.4)', () {
    test('unitsUnmeasured ve gerekçeleri yüzeye çıkar; attempted toplamı taşır',
        () {
      final ProgressSummary s = ProgressSummary.build(
        lessonSurfaces: const <LessonSurface>[reps],
        records: <SessionRecord>[
          rec(done: 3, unmeasured: 1, reason: 'framing'),
          rec(done: 4, unmeasured: 2, reason: 'low light'),
          rec(done: 5, unmeasured: 1, reason: 'framing'),
        ],
      );
      final LessonProgress lp = s.lessons.single;
      expect(lp.unitsMeasured, 12);
      expect(lp.unitsUnmeasured, 4);
      expect(lp.unitsAttempted, 16,
          reason: 'Kullanıcının yaptığı iş ölçülen + ölçülemeyendir.');
      expect(lp.unmeasuredReasons, <String>['framing', 'low light']);
    });

    test('ölçülemeyen birim TOPLAMLARA karışmaz — unitTotals yalnız ölçüleni sayar',
        () {
      final ProgressSummary s = ProgressSummary.build(
        lessonSurfaces: const <LessonSurface>[reps],
        records: <SessionRecord>[rec(done: 3, unmeasured: 7)],
      );
      expect(s.unitTotals, <String, int>{'rep': 3});
    });
  });

  group('iki birim TEK SAYIDA toplanmaz (delta 1)', () {
    test('rep ve second ayrı toplanır; saniye toplamı ortaktır', () {
      final ProgressSummary s = ProgressSummary.build(
        lessonSurfaces: const <LessonSurface>[reps, plank],
        records: <SessionRecord>[
          rec(worked: 100, done: 8),
          rec(lessonId: plank.id, unit: 'second', worked: 45, done: 45),
        ],
      );
      expect(s.unitTotals, <String, int>{'rep': 8, 'second': 45});
      expect(s.totalWorkedSeconds, 145,
          reason: 'Saniye her derste aynı birimdir — bu skaler meşru.');
    });

    test('staticHold dejenerasyonu BAYRAKLIDIR: birim == çalışılan saniye', () {
      final ProgressSummary s = ProgressSummary.build(
        lessonSurfaces: const <LessonSurface>[plank],
        records: <SessionRecord>[
          rec(lessonId: plank.id, unit: 'second', worked: 45, done: 45),
        ],
      );
      final LessonProgress lp = s.lessons.single;
      expect(lp.unitsDuplicateWorkedSeconds, isTrue);
      expect(lp.unitsMeasured, lp.workedSeconds,
          reason: 'Delta §2 açık sorusu: yüzey bu ikisini bağımsız iki olgu '
              'gibi göstermemeli. Karar gelene kadar bayrak yüzeyin uyarısı.');
      expect(
        ProgressSummary.build(
          lessonSurfaces: const <LessonSurface>[reps],
          records: <SessionRecord>[rec()],
        ).lessons.single.unitsDuplicateWorkedSeconds,
        isFalse,
      );
    });
  });

  test('yüzeyde karşılığı olmayan kayıt SESSİZCE düşmez — adıyla raporlanır', () {
    // Ders yeniden adlandırıldı ya da içerikten kaldırıldı. Toplamlara katılmaz
    // (yüzeyde gösterilecek yeri yok) ama VARLIĞI görünür kalır.
    final ProgressSummary s = ProgressSummary.build(
      lessonSurfaces: const <LessonSurface>[reps],
      records: <SessionRecord>[
        rec(),
        rec(lessonId: 'old_course.removed_lesson', worked: 999),
      ],
    );
    expect(s.orphanRecordLessonIds, <String>['old_course.removed_lesson']);
    expect(s.totalWorkedSeconds, 120, reason: 'Yetim saniyeler toplama girmez.');
    expect(s.lessons.length, 1);
  });
}
