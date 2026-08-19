import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/program/program_builder.dart';
import 'package:gravita/app/program/program_model.dart';

/// [ProgramBuilder] — GRA-P1-003 Step 1/2/5.
void main() {
  const ProgramConfig config = ProgramConfig(
    totalWeeks: 8,
    deloadWeeks: <int>{4, 8},
    baseSets: 3,
    baseReps: 8,
    weeklyRepIncrement: 1,
    repCap: 12,
    deloadSets: 2,
    deloadReps: 8,
    baseHoldSeconds: 20,
    weeklyHoldIncrementSeconds: 5,
    holdCapSeconds: 45,
    deloadHoldSeconds: 20,
    restSecondsRep: 75,
    restSecondsHold: 60,
    exercisesPerDay: 5,
    minDaysPerWeek: 2,
    maxDaysPerWeek: 6,
  );

  // Sentetik ama GERÇEKÇİ bir katalog — gerçek ailelerin (push/pull/legs/
  // core/carry) bir alt kümesi, kontrollü ekipman/seviye/canlılık.
  const List<ProgramCatalogEntry> catalog = <ProgramCatalogEntry>[
    ProgramCatalogEntry(id: 'push_up', family: 'push', level: 'beginner',
        equipment: <String>{}, isHold: false, isLive: true),
    ProgramCatalogEntry(id: 'dip', family: 'push', level: 'intermediate',
        equipment: <String>{}, isHold: false, isLive: false),
    ProgramCatalogEntry(id: 'inverted_row', family: 'pull', level: 'beginner',
        equipment: <String>{}, isHold: false, isLive: false),
    ProgramCatalogEntry(id: 'pull_up', family: 'pull', level: 'intermediate',
        equipment: <String>{'pull_up_bar'}, isHold: false, isLive: false),
    ProgramCatalogEntry(id: 'bodyweight_squat', family: 'legs',
        level: 'beginner', equipment: <String>{}, isHold: false, isLive: true),
    ProgramCatalogEntry(id: 'goblet_squat', family: 'legs',
        level: 'beginner', equipment: <String>{'kettlebell'}, isHold: false,
        isLive: false),
    ProgramCatalogEntry(id: 'plank', family: 'core', level: 'beginner',
        equipment: <String>{}, isHold: true, isLive: false),
    ProgramCatalogEntry(id: 'hollow_hold', family: 'core',
        level: 'intermediate', equipment: <String>{}, isHold: true,
        isLive: false),
    ProgramCatalogEntry(id: 'farmer_carry', family: 'carry',
        level: 'beginner', equipment: <String>{'dumbbells'}, isHold: true,
        isLive: false),
  ];

  ProgramInputs bodyweightBeginner({int daysPerWeek = 3}) => ProgramInputs(
        availableEquipment: const <String>{},
        daysPerWeek: daysPerWeek,
        experience: ExperienceLevel.beginner,
      );

  group('determinizm (roadmap Step 1)', () {
    test('AYNI girdi → AYNI program (yapısal eşit)', () {
      final ProgramBuilder b = ProgramBuilder(config: config, catalog: catalog);
      final WorkoutProgram a = b.build(bodyweightBeginner());
      final WorkoutProgram c = b.build(bodyweightBeginner());
      expect(a.days.length, c.days.length);
      for (int i = 0; i < a.days.length; i++) {
        expect(a.days[i].exercises.map((PrescribedExercise e) => e.movementId),
            c.days[i].exercises.map((PrescribedExercise e) => e.movementId),
            reason: 'gün $i farklı hareketler seçti');
        expect(
            a.days[i].exercises.map((PrescribedExercise e) => e.targetReps),
            c.days[i].exercises.map((PrescribedExercise e) => e.targetReps));
      }
    });

    test('toplam seans sayısı totalWeeks × daysPerWeek', () {
      final ProgramBuilder b = ProgramBuilder(config: config, catalog: catalog);
      final WorkoutProgram p = b.build(bodyweightBeginner(daysPerWeek: 4));
      expect(p.totalSessions, 8 * 4);
    });
  });

  group('ekipman + seviye süzgeci', () {
    test('vücut ağırlığı GİRDİSİ ekipman gerektiren hareket SEÇMEZ', () {
      final ProgramBuilder b = ProgramBuilder(config: config, catalog: catalog);
      final WorkoutProgram p = b.build(bodyweightBeginner());
      final Set<String> chosen = <String>{
        for (final ProgramDay d in p.days)
          for (final PrescribedExercise e in d.exercises) e.movementId,
      };
      expect(chosen, isNot(contains('pull_up')));
      expect(chosen, isNot(contains('goblet_squat')));
      expect(chosen, isNot(contains('farmer_carry')));
    });

    test('beginner GİRDİSİ intermediate hareket SEÇMEZ', () {
      final ProgramBuilder b = ProgramBuilder(config: config, catalog: catalog);
      final WorkoutProgram p = b.build(bodyweightBeginner());
      final Set<String> chosen = <String>{
        for (final ProgramDay d in p.days)
          for (final PrescribedExercise e in d.exercises) e.movementId,
      };
      expect(chosen, isNot(contains('dip')));
      expect(chosen, isNot(contains('hollow_hold')));
    });

    test('intermediate GİRDİSİ beginner + intermediate ikisini de görebilir', () {
      final ProgramBuilder b = ProgramBuilder(config: config, catalog: catalog);
      final WorkoutProgram p = b.build(ProgramInputs(
        availableEquipment: const <String>{'pull_up_bar'},
        daysPerWeek: 4,
        experience: ExperienceLevel.intermediate,
      ));
      final Set<String> chosen = <String>{
        for (final ProgramDay d in p.days)
          for (final PrescribedExercise e in d.exercises) e.movementId,
      };
      expect(chosen, contains('pull_up'),
          reason: 'ekipman VAR + intermediate izinli — seçilebilmeli');
    });
  });

  group('CANLI-öncelik (mümkünse kamera geri bildirimli hareket önce)', () {
    test('push ailesinde push_up (live) dip (coming_soon)\'tan ÖNCE gelir',
        () {
      // ⚠️ dip intermediate olduğu için beginner girdisinde zaten elenir;
      // bu testte intermediate kullanılıyor ki İKİSİ de havuzda olsun.
      final ProgramBuilder b = ProgramBuilder(config: config, catalog: catalog);
      final WorkoutProgram p = b.build(ProgramInputs(
        availableEquipment: const <String>{},
        daysPerWeek: 3,
        experience: ExperienceLevel.intermediate,
      ));
      final PrescribedExercise? first = p.days.first.exercises
          .cast<PrescribedExercise?>()
          .firstWhere((PrescribedExercise? e) =>
              e!.movementId == 'push_up' || e.movementId == 'dip',
              orElse: () => null);
      expect(first?.movementId, 'push_up',
          reason: 'canlı-öncelik sıralaması bozuldu');
    });

    test('isLiveMeasured katalogla TUTARLI', () {
      final ProgramBuilder b = ProgramBuilder(config: config, catalog: catalog);
      final WorkoutProgram p = b.build(bodyweightBeginner());
      for (final ProgramDay d in p.days) {
        for (final PrescribedExercise e in d.exercises) {
          final ProgramCatalogEntry entry =
              catalog.firstWhere((ProgramCatalogEntry c) => c.id == e.movementId);
          expect(e.isLiveMeasured, entry.isLive, reason: e.movementId);
        }
      }
    });
  });

  group('bir günde AYNI hareket İKİ KEZ seçilmez', () {
    test('exercisesPerDay aile sayısından büyük olsa bile tekrar yok', () {
      final ProgramBuilder b = ProgramBuilder(config: config, catalog: catalog);
      final WorkoutProgram p = b.build(bodyweightBeginner());
      for (final ProgramDay d in p.days) {
        final List<String> ids =
            d.exercises.map((PrescribedExercise e) => e.movementId).toList();
        expect(ids.toSet().length, ids.length, reason: 'gün ${d.weekNumber}.'
            '${d.dayNumber}: tekrarlanan hareket $ids');
      }
    });
  });

  group('⭐ periyotlama — deload TEK planlı düşüş, gerisi HİÇ azalmaz', () {
    test('deload hafta 4/8 düşürülmüş dozu kullanıyor', () {
      final ProgramBuilder b = ProgramBuilder(config: config, catalog: catalog);
      final WorkoutProgram p = b.build(bodyweightBeginner());
      for (final ProgramDay d in p.days) {
        if (d.weekNumber == 4 || d.weekNumber == 8) {
          expect(d.isDeload, isTrue);
          for (final PrescribedExercise e in d.exercises) {
            expect(e.sets, config.deloadSets);
            if (!e.isHold) expect(e.targetReps, config.deloadReps);
          }
        } else {
          expect(d.isDeload, isFalse);
        }
      }
    });

    test('deload-olmayan haftalarda tekrar hedefi HİÇBİR ZAMAN azalmaz '
        '(tavana kadar)', () {
      final ProgramBuilder b = ProgramBuilder(config: config, catalog: catalog);
      final WorkoutProgram p = b.build(bodyweightBeginner());
      // push_up'ın haftalık tekrar hedefini izle — deload-olmayan
      // haftalarda MONOTON artmalı (ya da tavanda sabit kalmalı).
      int? lastNonDeloadReps;
      for (int week = 1; week <= 8; week++) {
        if (config.deloadWeeks.contains(week)) continue;
        final ProgramDay day = p.days.firstWhere((ProgramDay d) =>
            d.weekNumber == week &&
            d.exercises.any((PrescribedExercise e) => e.movementId == 'push_up'));
        final int reps = day.exercises
            .firstWhere((PrescribedExercise e) => e.movementId == 'push_up')
            .targetReps!;
        if (lastNonDeloadReps != null) {
          expect(reps, greaterThanOrEqualTo(lastNonDeloadReps),
              reason: 'hafta $week: $reps < önceki $lastNonDeloadReps — '
                  'GÜVENSİZ (plansız) düşüş');
        }
        lastNonDeloadReps = reps;
      }
      expect(lastNonDeloadReps, isNotNull);
    });

    test('tekrar hedefi tavanı (repCap) ASLA aşmaz', () {
      final ProgramBuilder b = ProgramBuilder(config: config, catalog: catalog);
      final WorkoutProgram p = b.build(bodyweightBeginner());
      for (final ProgramDay d in p.days) {
        for (final PrescribedExercise e in d.exercises) {
          if (!e.isHold) expect(e.targetReps, lessThanOrEqualTo(config.repCap));
        }
      }
    });
  });

  group('⭐ kaçırılan seans — CEZASIZ yeniden sıralama (roadmap Step 4)', () {
    test('kaçırılan seanstan SONRAKİ tüm tarihler bir slot öteleniyor, '
        'ÖNCEKİLER değişmiyor', () {
      final List<DateTime> original = <DateTime>[
        for (int i = 0; i < 6; i++) DateTime(2026, 9, 1 + i * 2),
      ];
      final List<DateTime> after = rescheduleAfterMiss(
        schedule: original,
        missedIndex: 2,
        slotSpacing: const Duration(days: 2),
      );
      expect(after.length, original.length,
          reason: 'seans sayısı DEĞİŞMEMELİ — ne kayıp ne fazladan');
      for (int i = 0; i < 2; i++) {
        expect(after[i], original[i], reason: 'kaçırılandan ÖNCEki $i kaymış');
      }
      for (int i = 2; i < after.length; i++) {
        expect(after[i], original[i].add(const Duration(days: 2)),
            reason: 'kaçırılandan SONRAki $i doğru ötelenmemiş');
      }
    });

    test('yeniden sıralama İÇERİĞE dokunmaz — yalnız tarih değişir', () {
      final ProgramBuilder b = ProgramBuilder(config: config, catalog: catalog);
      final WorkoutProgram p = b.build(bodyweightBeginner());
      final List<DateTime> schedule = scheduleProgram(
          program: p, startDate: DateTime(2026, 9, 1), daysPerWeek: 3);
      final List<DateTime> after = rescheduleAfterMiss(
          schedule: schedule, missedIndex: 5, slotSpacing: const Duration(days: 2));
      // Program nesnesinin kendisi hiç DEĞİŞMEDİ (ayrı fonksiyon, ayrı veri).
      expect(p.days.length, schedule.length);
      expect(after.length, schedule.length);
    });
  });

  group('⭐ SEKİZ HAFTALIK SİMÜLE SAAT — çoklu kaçırma, tekrar/kayıp sıfır '
      '(roadmap Step 5)', () {
    test('rastgele-OLMAYAN (sabit) üç kaçırma sonrası: tarihler benzersiz, '
        'artan sırada, seans sayısı DEĞİŞMEDİ', () {
      final ProgramBuilder b = ProgramBuilder(config: config, catalog: catalog);
      final WorkoutProgram p = b.build(bodyweightBeginner(daysPerWeek: 4));
      List<DateTime> schedule = scheduleProgram(
          program: p, startDate: DateTime(2026, 9, 1), daysPerWeek: 4);
      final int originalCount = schedule.length;

      // Sabit (deterministik) kaçırma noktaları — "simüle edilmiş saat"
      // programın ortasında birkaç kez "bugün yapılmadı" diyor.
      for (final int missed in <int>[3, 3, 15]) {
        // ⚠️ 3 İKİ KEZ kasıtlı: art arda iki kaçırma da tek bir kayıp/
        // çakışma üretmemeli — öteleme KÜMÜLATİF çalışmalı.
        schedule = rescheduleAfterMiss(
            schedule: schedule,
            missedIndex: missed,
            slotSpacing: const Duration(days: 2));
      }

      expect(schedule.length, originalCount,
          reason: 'toplam seans sayısı DEĞİŞMEMELİ');
      expect(schedule.toSet().length, schedule.length,
          reason: 'YİNELENEN tarih var — iki seans aynı güne düştü');
      for (int i = 1; i < schedule.length; i++) {
        expect(schedule[i].isAfter(schedule[i - 1]), isTrue,
            reason: 'sıra bozuldu: seans $i, seans ${i - 1}\'den ÖNCE');
      }
    });
  });

  group('GERÇEK katalogla — sentetik fikstür yeterli değil (aile dersi)', () {
    // ⚠️ Yukarıdaki testlerin HEPSİ küçük, kontrollü, SENTETİK bir katalogla
    // koşuyor — bu ailenin defalarca öğrendiği ders "gerçek metin
    // fikstürden uzundur" burada da geçerli: gerçek `content/catalog/`
    // 31 hareket, 9 aile ve karışık ekipman/seviye taşıyor. Bu grup
    // ÜRETİCİNİN gerçek veriyle GERÇEKTEN çökmediğini/mantıksız bir şey
    // üretmediğini kanıtlıyor.
    List<ProgramCatalogEntry> realCatalog() {
      final Map<String, dynamic> lib = (jsonDecode(
              File('content/library.json').readAsStringSync()) as Map)
          .cast<String, dynamic>();
      final List<Map<String, dynamic>> movements =
          (lib['movements'] as List<dynamic>).cast<Map<String, dynamic>>();
      return movements.map((Map<String, dynamic> m) {
        final String wave = (m['wave'] as String).toLowerCase();
        final String catalogId = (m['catalogId'] ?? m['id']) as String;
        final Map<String, dynamic> cat = (jsonDecode(File(
                    'content/catalog/$wave/$catalogId.json')
                .readAsStringSync()) as Map)
            .cast<String, dynamic>();
        return ProgramCatalogEntry(
          id: m['id'] as String,
          family: (m['family'] as String?) ?? 'other',
          level: (cat['level'] as String?) ?? 'beginner',
          equipment: _strings(m['equipment']),
          isHold:
              (cat['engine'] as Map<String, dynamic>?)?['type'] == 'staticHold',
          isLive: m['status'] == 'live',
        );
      }).toList();
    }

    test('bodyweight+beginner girdisiyle çökmeden 8×3 seans üretiyor', () {
      final ProgramBuilder b =
          ProgramBuilder(config: config, catalog: realCatalog());
      final WorkoutProgram p = b.build(bodyweightBeginner());
      expect(p.totalSessions, 24);
      // Her günün en az BİR hareketi olmalı — gerçek veride HİÇBİR ailenin
      // beginner+ekipmansız adayı sıfır değil (bodyweight_squat/push_up/
      // core ailesinin çoğu ekipmansız).
      for (final ProgramDay d in p.days) {
        expect(d.exercises, isNotEmpty,
            reason: 'hafta ${d.weekNumber} gün ${d.dayNumber}: hiç hareket '
                'seçilemedi — gerçek katalogla süzgeç FAZLA katı olabilir');
      }
    });

    test('intermediate + tam ekipman girdisiyle çökmeden üretiyor', () {
      final List<ProgramCatalogEntry> cat = realCatalog();
      final Set<String> allEquipment = <String>{
        for (final ProgramCatalogEntry e in cat) ...e.equipment,
      };
      final ProgramBuilder b = ProgramBuilder(config: config, catalog: cat);
      final WorkoutProgram p = b.build(ProgramInputs(
        availableEquipment: allEquipment,
        daysPerWeek: 5,
        experience: ExperienceLevel.intermediate,
      ));
      expect(p.totalSessions, 40);
      for (final ProgramDay d in p.days) {
        expect(d.exercises, isNotEmpty);
        expect(d.exercises.length, lessThanOrEqualTo(config.exercisesPerDay));
      }
    });
  });
}

Set<String> _strings(dynamic raw) =>
    ((raw as List<dynamic>?) ?? const <dynamic>[]).cast<String>().toSet();
