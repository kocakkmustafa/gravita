/// Sekiz haftalık program — tipler (GRA-P1-003).
///
/// ## Neden `lib/app/` içinde, `gravita_engine`de DEĞİL
///
/// Roadmap §6: "Program ve skill graph app content katmanında." Motor ölçüm
/// katmanıdır (poz/tekrar/tutuş); program PERİYOTLAMA katmanıdır ve hiçbir
/// ölçüm üretmez — yalnız hangi hareketin ne zaman, kaç set/tekrar ile
/// ÖNERİLDİĞİNİ taşır. Motor bunu hiç bilmez, önerilen hareketi NORMAL bir
/// serbest seans gibi ölçer.
///
/// ## "Deterministik" ne anlama gelir (roadmap Step 1)
///
/// Aynı [ProgramInputs] + aynı [ProgramConfig] + aynı katalog → HER ZAMAN
/// aynı [WorkoutProgram]. Hiçbir yerde `DateTime.now()`/rastgelelik
/// ÇAĞRILMAZ — takvim tarihleri çağıran tarafından PARAMETRE olarak
/// verilir (`live_session.dart`nın `buildFreeSessionRecord`ıyla AYNI
/// disiplin: saf mantık gerçek-zamanı bilmez, yalnız kabloluyan taraf bilir).
library;

/// Kullanıcının deneyim seviyesi — katalog `level` alanına eşlenir.
///
/// ⚠️ AŞAMALI genişleme: `intermediate` yalnız intermediate hareketleri
/// DEĞİL, beginner+intermediate ikisini birden görür (bir orta-seviye
/// kullanıcı temel hareketleri de yapabilir). `advanced`/`elite` katalogda
/// VAR (2+1 hareket) ama V1 program üretimi bunlara GİRMİYOR — ikisi de
/// beceri-ağacı aspirasyonel düğümleri (`tuck_planche`/`wall_handstand`
/// vb.), sekiz haftalık temel programın kapsamı DIŞINDA (roadmap'in kendi
/// ayrımı: "paid foundation" ile "full vision" ayrı fazlar, §12).
enum ExperienceLevel {
  beginner,
  intermediate;

  Set<String> get acceptedCatalogLevels => switch (this) {
        ExperienceLevel.beginner => const <String>{'beginner'},
        ExperienceLevel.intermediate => const <String>{
            'beginner',
            'intermediate',
          },
      };
}

/// Sekiz haftalık planın TEK girdisi.
final class ProgramInputs {
  const ProgramInputs({
    required this.availableEquipment,
    required this.daysPerWeek,
    required this.experience,
  });

  /// Boş küme = yalnız vücut ağırlığı. Katalogdaki `equipment` listesinin
  /// HER öğesi bu kümede olmalı ki hareket seçilebilsin.
  final Set<String> availableEquipment;

  final int daysPerWeek;
  final ExperienceLevel experience;
}

/// Bir günün TEK reçetesi. `isHold` ayırt eder: `true` ise
/// [targetHoldSeconds] geçerli ve [targetReps] `null`, `false` ise tersi —
/// ikisi AYNI ANDA dolu OLAMAZ (motor da aynı ayrımı taşır, `engine.type`).
final class PrescribedExercise {
  const PrescribedExercise({
    required this.movementId,
    required this.sets,
    required this.isHold,
    required this.restSeconds,
    required this.isLiveMeasured,
    this.targetReps,
    this.targetHoldSeconds,
  }) : assert(isHold ? targetHoldSeconds != null && targetReps == null
            : targetReps != null && targetHoldSeconds == null);

  final String movementId;
  final int sets;
  final bool isHold;
  final int? targetReps;
  final int? targetHoldSeconds;
  final int restSeconds;

  /// Katalogdaki `status=="live"` — kamera geri bildirimi VAR mı, yoksa bu
  /// bir MANUEL LOG kalemi mi. Ekran ikisini aynı cümleyle sunamaz
  /// (`library.json`ın kendi `coming_soon` ayrımıyla TUTARLI kalmak için).
  final bool isLiveMeasured;
}

/// Programın DÜZ, sıralı TEK seansı — hafta/gün içi bir GRUPLAMA değil,
/// program-içi konumun kaydı (`weekNumber`/`dayNumber` yalnız GÖSTERİM için,
/// sıralama [WorkoutProgram.days]'ın kendi index'inden gelir).
final class ProgramDay {
  const ProgramDay({
    required this.weekNumber,
    required this.dayNumber,
    required this.isDeload,
    required this.exercises,
  });

  final int weekNumber;
  final int dayNumber;
  final bool isDeload;
  final List<PrescribedExercise> exercises;
}

final class WorkoutProgram {
  const WorkoutProgram({required this.programId, required this.days});

  final String programId;

  /// DÜZ sıralı seans listesi — takvime bu sırayla eşlenir.
  final List<ProgramDay> days;

  int get totalSessions => days.length;
}

/// `content/programs/foundation.v1.json`ın tipli karşılığı — hareket SEÇMEZ,
/// yalnız periyotlama PARAMETRELERİNİ taşır (bkz. dosyanın kendi `$comment`ı).
final class ProgramConfig {
  const ProgramConfig({
    required this.totalWeeks,
    required this.deloadWeeks,
    required this.baseSets,
    required this.baseReps,
    required this.weeklyRepIncrement,
    required this.repCap,
    required this.deloadSets,
    required this.deloadReps,
    required this.baseHoldSeconds,
    required this.weeklyHoldIncrementSeconds,
    required this.holdCapSeconds,
    required this.deloadHoldSeconds,
    required this.restSecondsRep,
    required this.restSecondsHold,
    required this.exercisesPerDay,
    required this.minDaysPerWeek,
    required this.maxDaysPerWeek,
  });

  factory ProgramConfig.fromJson(Map<String, dynamic> j) => ProgramConfig(
        totalWeeks: j['totalWeeks'] as int,
        deloadWeeks:
            (j['deloadWeeks'] as List<dynamic>).map((dynamic e) => e as int).toSet(),
        baseSets: j['baseSets'] as int,
        baseReps: j['baseReps'] as int,
        weeklyRepIncrement: j['weeklyRepIncrement'] as int,
        repCap: j['repCap'] as int,
        deloadSets: j['deloadSets'] as int,
        deloadReps: j['deloadReps'] as int,
        baseHoldSeconds: j['baseHoldSeconds'] as int,
        weeklyHoldIncrementSeconds: j['weeklyHoldIncrementSeconds'] as int,
        holdCapSeconds: j['holdCapSeconds'] as int,
        deloadHoldSeconds: j['deloadHoldSeconds'] as int,
        restSecondsRep: j['restSecondsRep'] as int,
        restSecondsHold: j['restSecondsHold'] as int,
        exercisesPerDay: j['exercisesPerDay'] as int,
        minDaysPerWeek: j['minDaysPerWeek'] as int,
        maxDaysPerWeek: j['maxDaysPerWeek'] as int,
      );

  final int totalWeeks;
  final Set<int> deloadWeeks;
  final int baseSets;
  final int baseReps;
  final int weeklyRepIncrement;
  final int repCap;
  final int deloadSets;
  final int deloadReps;
  final int baseHoldSeconds;
  final int weeklyHoldIncrementSeconds;
  final int holdCapSeconds;
  final int deloadHoldSeconds;
  final int restSecondsRep;
  final int restSecondsHold;
  final int exercisesPerDay;
  final int minDaysPerWeek;
  final int maxDaysPerWeek;
}

/// Katalogdan [ProgramBuilder]in ihtiyaç duyduğu ALT KÜME — `gravita_engine`
/// tipine (`MovementConfig`) bağımlı olmadan saf veriyle çalışır, üretici
/// tarafı (`content_repository.dart`) `library.json` + `engine.type`ten
/// türetir.
final class ProgramCatalogEntry {
  const ProgramCatalogEntry({
    required this.id,
    required this.family,
    required this.level,
    required this.equipment,
    required this.isHold,
    required this.isLive,
  });

  final String id;
  final String family;
  final String level;
  final Set<String> equipment;
  final bool isHold;
  final bool isLive;
}
