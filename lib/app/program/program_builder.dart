import '../library_model.dart';
import 'program_model.dart';

/// Sekiz haftalık program üreticisi — DETERMİNİSTİK, saf fonksiyon (GRA-P1-003
/// Step 1/2).
///
/// ## Hareket SEÇİMİ nasıl çalışır
///
/// 1. Katalog `equipment ⊆ girdi.availableEquipment` VE `level ∈ girdi.
///    experience.acceptedCatalogLevels` süzgecinden geçer.
/// 2. Kalanlar `LibraryCatalogue.familyOrder`a göre gruplanır (kütüphane
///    ekranının AYNI sırası — iki ayrı sıralama icat edilmedi).
/// 3. Her ailenin İÇİNDE aday sıralaması: CANLI (kamera geri bildirimli)
///    olanlar ÖNCE, sonra `id` alfabetik — programın "elimizden geleni
///    öner" ilkesi: mümkünse gerçekten koçlayabildiğimiz hareketi seç.
/// 4. Her seans (`exercisesPerDay` kadar), o günün İNDEKSİNE göre
///    DÖNDÜRÜLMÜŞ bir aile sırasından ilk uygun adayları alır — program
///    ilerledikçe TÜM aileler dönüşümlü olarak öne çıkar, ilk N aile hep
///    aynı kalmaz.
///
/// ## Periyotlama nasıl çalışır
///
/// Doz, o haftaya kadar geçen DELOAD-OLMAYAN hafta sayısına göre artar
/// (`_progressionIndex`) — deload haftaları sayacı İLERLETMEZ, yalnız KENDİ
/// sabit (düşürülmüş) dozunu kullanır. Bu, ardışık deload'suz haftalarda
/// tekrar/tutuş süresinin YALNIZ artabileceğini (asla azalamayacağını,
/// tavana çarpana kadar) ve deload'un TEK planlı düşüş olduğunu garanti
/// eder — roadmap Step 5'in "unsafe progression sıfır" şartı.
final class ProgramBuilder {
  const ProgramBuilder({required this.config, required this.catalog});

  final ProgramConfig config;
  final List<ProgramCatalogEntry> catalog;

  WorkoutProgram build(ProgramInputs inputs) {
    final List<ProgramCatalogEntry> eligible = catalog
        .where((ProgramCatalogEntry e) =>
            e.equipment.every(inputs.availableEquipment.contains) &&
            inputs.experience.acceptedCatalogLevels.contains(e.level))
        .toList();

    final Map<String, List<ProgramCatalogEntry>> byFamily =
        <String, List<ProgramCatalogEntry>>{};
    for (final ProgramCatalogEntry e in eligible) {
      (byFamily[e.family] ??= <ProgramCatalogEntry>[]).add(e);
    }
    for (final List<ProgramCatalogEntry> list in byFamily.values) {
      list.sort((ProgramCatalogEntry a, ProgramCatalogEntry b) {
        if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
        return a.id.compareTo(b.id);
      });
    }
    final List<String> families = <String>[
      for (final String f in LibraryCatalogue.familyOrder)
        if (byFamily.containsKey(f)) f,
    ];

    final int totalSessions = config.totalWeeks * inputs.daysPerWeek;
    final List<ProgramDay> days = <ProgramDay>[];
    for (int session = 0; session < totalSessions; session++) {
      final int weekNumber = session ~/ inputs.daysPerWeek + 1;
      final int dayNumber = session % inputs.daysPerWeek + 1;
      final bool isDeload = config.deloadWeeks.contains(weekNumber);
      final int progressionIndex =
          _progressionIndex(weekNumber, config.deloadWeeks);

      final List<PrescribedExercise> exercises = <PrescribedExercise>[];
      final Set<String> usedToday = <String>{};
      if (families.isNotEmpty) {
        for (int slot = 0; slot < config.exercisesPerDay; slot++) {
          final String family =
              families[(session + slot) % families.length];
          final ProgramCatalogEntry pick = byFamily[family]!
              .firstWhere((ProgramCatalogEntry e) => !usedToday.contains(e.id),
                  orElse: () => byFamily[family]!.first);
          // ⚠️ Aynı hareket bir günde İKİ KEZ seçilmesin — aile havuzu
          // `exercisesPerDay`den küçükse (ör. tek carry hareketi varken 5
          // slot doldurulmaya çalışılırsa) `orElse` en iyi tekrar adayı
          // döner ama `usedToday` onu FİLTRELER, tekrar EKLENMEZ.
          if (usedToday.contains(pick.id)) continue;
          usedToday.add(pick.id);
          exercises.add(_prescribe(pick, isDeload, progressionIndex));
        }
      }

      days.add(ProgramDay(
        weekNumber: weekNumber,
        dayNumber: dayNumber,
        isDeload: isDeload,
        exercises: exercises,
      ));
    }

    return WorkoutProgram(programId: 'foundation.v1', days: days);
  }

  /// O haftadan ÖNCEKİ deload-olmayan hafta SAYISI — deload haftaları
  /// saymaz, kendi haftası da dahil edilmez (hafta 1'in progression'ı 0).
  int _progressionIndex(int weekNumber, Set<int> deloadWeeks) {
    int n = 0;
    for (int w = 1; w < weekNumber; w++) {
      if (!deloadWeeks.contains(w)) n++;
    }
    return n;
  }

  PrescribedExercise _prescribe(
      ProgramCatalogEntry e, bool isDeload, int progressionIndex) {
    if (e.isHold) {
      final int seconds = isDeload
          ? config.deloadHoldSeconds
          : (config.baseHoldSeconds +
                  progressionIndex * config.weeklyHoldIncrementSeconds)
              .clamp(0, config.holdCapSeconds);
      return PrescribedExercise(
        movementId: e.id,
        sets: isDeload ? config.deloadSets : config.baseSets,
        isHold: true,
        targetHoldSeconds: seconds,
        restSeconds: config.restSecondsHold,
        isLiveMeasured: e.isLive,
      );
    }
    final int reps = isDeload
        ? config.deloadReps
        : (config.baseReps + progressionIndex * config.weeklyRepIncrement)
            .clamp(0, config.repCap);
    return PrescribedExercise(
      movementId: e.id,
      sets: isDeload ? config.deloadSets : config.baseSets,
      isHold: false,
      targetReps: reps,
      restSeconds: config.restSecondsRep,
      isLiveMeasured: e.isLive,
    );
  }
}

/// Kaçırılan bir seansı CEZASIZ yeniden sıralar (roadmap Step 4).
///
/// **Kural:** [missedIndex]'ten İTİBAREN her tarih bir [slotSpacing] kadar
/// ÖTELENİR — içerik (hangi hareket, kaç set/tekrar) HİÇ değişmez, hiçbir
/// seans SİLİNMEZ ya da TEKRARLANMAZ, yalnız TARİHİ kayar. `DateTime.now()`
/// çağrılmaz — çağıran taraf hem mevcut takvimi hem kaçırılan indeksi verir
/// (saf fonksiyon, simulated-clock testiyle sınanabilir).
List<DateTime> rescheduleAfterMiss({
  required List<DateTime> schedule,
  required int missedIndex,
  required Duration slotSpacing,
}) {
  if (missedIndex < 0 || missedIndex >= schedule.length) return schedule;
  return <DateTime>[
    for (int i = 0; i < schedule.length; i++)
      i < missedIndex ? schedule[i] : schedule[i].add(slotSpacing),
  ];
}

/// Haftada [daysPerWeek] seans için gün-arası boşluk — [scheduleProgram]
/// (ilk takvim) VE [rescheduleAfterMiss]in çağıranı (kaçırılan seansı KAÇ
/// gün öteleyeceğini bilmesi gerekir) AYNI formülü kullanır. Tek yerde
/// tutulmazsa iki çağrı SESSİZCE ayrışabilir (ör. biri güncellenip diğeri
/// unutulursa) — bu yüzden paylaşılan, saf bir fonksiyon.
int scheduleGapDays(int daysPerWeek) => (7 / daysPerWeek).floor().clamp(1, 7);

/// [WorkoutProgram.days] için düz, eşit-aralıklı bir İLK takvim —
/// `daysPerWeek`e göre haftaya yayılır. Saf; `startDate` ÇAĞIRANDAN gelir.
List<DateTime> scheduleProgram({
  required WorkoutProgram program,
  required DateTime startDate,
  required int daysPerWeek,
}) {
  final int gapDays = scheduleGapDays(daysPerWeek);
  return <DateTime>[
    for (int i = 0; i < program.days.length; i++)
      startDate.add(Duration(days: i * gapDays)),
  ];
}
