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
    _checkCalendarFrequency(inputs.daysPerWeek);
    if (inputs.daysPerWeek < config.minDaysPerWeek ||
        inputs.daysPerWeek > config.maxDaysPerWeek) {
      throw ArgumentError.value(
        inputs.daysPerWeek,
        'daysPerWeek',
        'Expected ${config.minDaysPerWeek}..${config.maxDaysPerWeek}',
      );
    }
    final List<ProgramCatalogEntry> eligible = catalog
        .where(
          (ProgramCatalogEntry e) =>
              e.equipment.every(inputs.availableEquipment.contains) &&
              inputs.experience.acceptedCatalogLevels.contains(e.level),
        )
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
      final int progressionIndex = _progressionIndex(
        weekNumber,
        config.deloadWeeks,
      );

      final List<PrescribedExercise> exercises = <PrescribedExercise>[];
      final Set<String> usedToday = <String>{};
      if (families.isNotEmpty) {
        for (int slot = 0; slot < config.exercisesPerDay; slot++) {
          final String family = families[(session + slot) % families.length];
          final ProgramCatalogEntry pick = byFamily[family]!.firstWhere(
            (ProgramCatalogEntry e) => !usedToday.contains(e.id),
            orElse: () => byFamily[family]!.first,
          );
          // ⚠️ Aynı hareket bir günde İKİ KEZ seçilmesin — aile havuzu
          // `exercisesPerDay`den küçükse (ör. tek carry hareketi varken 5
          // slot doldurulmaya çalışılırsa) `orElse` en iyi tekrar adayı
          // döner ama `usedToday` onu FİLTRELER, tekrar EKLENMEZ.
          if (usedToday.contains(pick.id)) continue;
          usedToday.add(pick.id);
          exercises.add(_prescribe(pick, isDeload, progressionIndex));
        }
      }

      days.add(
        ProgramDay(
          weekNumber: weekNumber,
          dayNumber: dayNumber,
          isDeload: isDeload,
          exercises: exercises,
        ),
      );
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
    ProgramCatalogEntry e,
    bool isDeload,
    int progressionIndex,
  ) {
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
/// **Kural:** [missedIndex]'ten İTİBAREN her tarih [slotSpacing] içindeki
/// pozitif tam TAKVİM GÜNÜ kadar ÖTELENİR — içerik (hangi hareket, kaç
/// set/tekrar) HİÇ değişmez, hiçbir
/// seans SİLİNMEZ ya da TEKRARLANMAZ, yalnız TARİHİ kayar. `DateTime.now()`
/// çağrılmaz — çağıran taraf hem mevcut takvimi hem kaçırılan indeksi verir
/// (saf fonksiyon, simulated-clock testiyle sınanabilir).
/// Eski takvim yeniden üretilmez; düzensiz aralıkları ve önceki tarihler korunur.
/// Yerel gün 23/25 saat sürebilir. Olmayan bir yerel saat platform DateTime
/// constructor'ının normalleştirmesine uyar; UTC girdi UTC olarak kalır.
List<DateTime> rescheduleAfterMiss({
  required List<DateTime> schedule,
  required int missedIndex,
  required Duration slotSpacing,
}) {
  final int calendarDays = slotSpacing.inDays;
  if (calendarDays <= 0 || slotSpacing != Duration(days: calendarDays)) {
    throw ArgumentError.value(
      slotSpacing,
      'slotSpacing',
      'Expected positive whole calendar days',
    );
  }
  if (missedIndex < 0 || missedIndex >= schedule.length) return schedule;
  return <DateTime>[
    for (int i = 0; i < schedule.length; i++)
      i < missedIndex
          ? schedule[i]
          : _addCalendarDays(schedule[i], calendarDays),
  ];
}

/// Eski çağıranların tek öteleme adımı için kullandığı alt aralık.
/// Yeni takvim eşit Duration aralıklarıyla üretilmez; bu değer haftalık
/// seans sayısını tek başına temsil etmez. Çağıran kaçırma politikasını seçer.
int scheduleGapDays(int daysPerWeek) {
  _checkCalendarFrequency(daysPerWeek);
  return 7 ~/ daysPerWeek;
}

void _checkCalendarFrequency(int daysPerWeek) {
  if (daysPerWeek < 1 || daysPerWeek > 7) {
    throw ArgumentError.value(daysPerWeek, 'daysPerWeek', 'Expected 1..7');
  }
}

DateTime _addCalendarDays(DateTime date, int days) {
  if (days == 0) return date;
  if (date.isUtc) {
    return DateTime.utc(
      date.year,
      date.month,
      date.day + days,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }
  return DateTime(
    date.year,
    date.month,
    date.day + days,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}

/// [WorkoutProgram.days] için İLK takvim: her yedi takvim günü bloğuna tam
/// [daysPerWeek] seans yayılır. Hafta etiketleri böylece gerçek blokla eşleşir.
/// Saf; `startDate` ÇAĞIRANDAN gelir. Mevcut takvimleri yeniden kurmaz.
List<DateTime> scheduleProgram({
  required WorkoutProgram program,
  required DateTime startDate,
  required int daysPerWeek,
}) {
  _checkCalendarFrequency(daysPerWeek);
  return <DateTime>[
    for (int i = 0; i < program.days.length; i++)
      _addCalendarDays(
        startDate,
        (i ~/ daysPerWeek) * 7 + ((i % daysPerWeek) * 7 ~/ daysPerWeek),
      ),
  ];
}
