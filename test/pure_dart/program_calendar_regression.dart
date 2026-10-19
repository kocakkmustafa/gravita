// Direct pure-Dart regression over production functions and shipping content.
// Root runs separate TZ=UTC/Europe/Istanbul/Europe/Berlin/America/New_York
// processes. No Flutter, account, network, native build or product writes.
import 'dart:convert';
import 'dart:io';

import 'package:gravita/app/library_model.dart';
import 'package:gravita/app/program/program_builder.dart';
import 'package:gravita/app/program/program_model.dart';
// This existing config model is pure Dart; the public barrel also exports
// Flutter-backed motion_core symbols, outside this standalone test's scope.
import 'package:gravita_engine/src/movement_config.dart';

int checks = 0;
int calendarCases = 0;
int rescheduleCases = 0;
int repeatSteps = 0;
int deloadChecks = 0;
int guardCases = 0;

void check(bool condition, String message) {
  checks++;
  if (!condition) throw StateError(message);
}

void rejects(void Function() action, String label) {
  bool rejected = false;
  try {
    action();
  } on ArgumentError {
    rejected = true;
  }
  guardCases++;
  check(rejected, '$label must throw ArgumentError');
}

int civilOrdinal(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

String civil(DateTime date) => '${date.year}-${date.month}-${date.day}';

ProgramInputs inputs(int n) => ProgramInputs(
  availableEquipment: const {},
  daysPerWeek: n,
  experience: ExperienceLevel.beginner,
);

Map<String, Object> describe(DateTime date) => {
  'iso': date.toIso8601String(),
  'utc': date.toUtc().toIso8601String(),
  'zone': date.timeZoneName,
  'offsetMinutes': date.timeZoneOffset.inMinutes,
};

void main() {
  final root = Directory.fromUri(Platform.script.resolve('../../'));
  Map<String, dynamic> readJson(String path) =>
      (jsonDecode(File('${root.path}/$path').readAsStringSync()) as Map)
          .cast<String, dynamic>();
  final config = ProgramConfig.fromJson(
    readJson('content/programs/foundation.v1.json'),
  );
  final rawRows = readJson('content/library.json')['movements'] as List;
  final catalog = <ProgramCatalogEntry>[];
  for (final raw in rawRows) {
    final row = (raw as Map).cast<String, dynamic>();
    final movement = MovementEntry.fromJson(row);
    final wave = (row['wave'] as String).toLowerCase();
    final detail = MovementConfig.parse(
      File(
        '${root.path}/content/catalog/$wave/${movement.catalogId}.json',
      ).readAsStringSync(),
    );
    check(detail.id == movement.id, 'catalog identity ${movement.id}');
    catalog.add(
      ProgramCatalogEntry(
        id: movement.id,
        family: movement.family,
        level: movement.level ?? 'intermediate',
        equipment: movement.equipment.toSet(),
        isHold: detail.engineType == EngineType.staticHold,
        isLive: movement.isLive,
      ),
    );
  }
  check(catalog.length == 31, 'shipping catalog31; stop on unrelated drift');
  check(config.totalWeeks == 8, 'foundation8 weeks');
  final builder = ProgramBuilder(config: config, catalog: catalog);
  final starts = <String, DateTime>{
    'baselineNoon': DateTime(2026, 10, 19, 12, 15, 1, 2, 3),
    'monthBoundary': DateTime(2026, 1, 29, 12),
    'leapDay': DateTime(2028, 2, 27, 12),
    'yearBoundary': DateTime(2026, 12, 29, 12),
    'berlinSpringMidnight': DateTime(2026, 3, 28),
    'berlinSpringLate': DateTime(2026, 3, 28, 23, 30),
    'berlinFallMidnight': DateTime(2026, 10, 24),
    'berlinFallNoon': DateTime(2026, 10, 24, 12),
    'newYorkSpringMidnight': DateTime(2026, 3, 7),
    'newYorkSpringLate': DateTime(2026, 3, 7, 23, 30),
    'newYorkFallMidnight': DateTime(2026, 10, 31),
    'newYorkFallNoon': DateTime(2026, 10, 31, 12),
  };
  final examples = <Map<String, Object>>[];
  for (final n in <int>[2, 3, 4, 5, 6]) {
    final program = builder.build(inputs(n));
    check(program.totalSessions == config.totalWeeks * n, 'N$n count');
    for (final entry in starts.entries) {
      final start = entry.value;
      final dates = scheduleProgram(
        program: program,
        startDate: start,
        daysPerWeek: n,
      );
      calendarCases++;
      final label = 'N$n/${entry.key}';
      final offsets = dates
          .map((d) => civilOrdinal(d) - civilOrdinal(start))
          .toList();
      final counts = <int>[
        for (int week = 0; week < config.totalWeeks; week++)
          offsets.where((d) => d >= week * 7 && d < (week + 1) * 7).length,
      ];
      check(counts.every((count) => count == n), '$label weekly N: $counts');
      check(
        dates.map(civil).toSet().length == dates.length,
        '$label no repeated civil day',
      );
      check(identical(dates.first, start), '$label first start unchanged');
      for (int i = 0; i < dates.length; i++) {
        final date = dates[i];
        final day = program.days[i];
        check(
          offsets[i] ~/ 7 + 1 == day.weekNumber,
          '$label calendar matches prescription week at$i',
        );
        check(date.isUtc == start.isUtc, '$label clock domain$i');
        check(
          date.hour == start.hour &&
              date.minute == start.minute &&
              date.second == start.second &&
              date.millisecond == start.millisecond &&
              date.microsecond == start.microsecond,
          '$label local clock$i',
        );
        if (i > 0) check(date.isAfter(dates[i - 1]), '$label instant order$i');
        if (day.isDeload) {
          check(
            config.deloadWeeks.contains(day.weekNumber),
            '$label deload week',
          );
          for (final exercise in day.exercises) {
            deloadChecks++;
            check(
              exercise.sets == config.deloadSets &&
                  (exercise.isHold
                      ? exercise.targetHoldSeconds == config.deloadHoldSeconds
                      : exercise.targetReps == config.deloadReps),
              '$label deload dose',
            );
          }
        }
      }
      final sourceInstants = dates
          .map((d) => d.microsecondsSinceEpoch)
          .toList();
      for (final index in <int>{
        -1,
        0,
        n - 1,
        n,
        dates.length - 1,
        dates.length,
      }) {
        for (final shiftDays in <int>{1, scheduleGapDays(n)}) {
          final after = rescheduleAfterMiss(
            schedule: dates,
            missedIndex: index,
            slotSpacing: Duration(days: shiftDays),
          );
          rescheduleCases++;
          final valid = index >= 0 && index < dates.length;
          check(after.length == dates.length, '$label reschedule count');
          if (!valid) {
            check(identical(after, dates), '$label invalid index no-op');
          }
          for (int i = 0; i < dates.length; i++) {
            check(
              dates[i].microsecondsSinceEpoch == sourceInstants[i],
              '$label original unchanged',
            );
            if (!valid || i < index) {
              check(identical(after[i], dates[i]), '$label prefix unchanged$i');
            } else {
              check(
                civilOrdinal(after[i]) - civilOrdinal(dates[i]) == shiftDays,
                '$label suffix civil shift$i',
              );
              check(
                after[i].hour == dates[i].hour &&
                    after[i].minute == dates[i].minute,
                '$label suffix local time$i',
              );
            }
          }
          check(
            after.map(civil).toSet().length == after.length,
            '$label shifted civil dates unique',
          );
        }
      }
      var repeated = dates;
      for (final index in <int>[0, n, 3 * n, n - 1, dates.length - 1, 0]) {
        final before = repeated;
        repeated = rescheduleAfterMiss(
          schedule: before,
          missedIndex: index,
          slotSpacing: Duration(days: scheduleGapDays(n)),
        );
        repeatSteps++;
        check(repeated.length == dates.length, '$label repeated count');
        check(
          repeated.map(civil).toSet().length == repeated.length,
          '$label repeated civil uniqueness',
        );
        for (int i = 0; i < repeated.length; i++) {
          if (i < index) {
            check(identical(repeated[i], before[i]), '$label repeated prefix');
          } else {
            check(
              civilOrdinal(repeated[i]) - civilOrdinal(before[i]) ==
                  scheduleGapDays(n),
              '$label repeated civil suffix',
            );
          }
          if (i > 0) {
            check(
              repeated[i].isAfter(repeated[i - 1]),
              '$label repeated instant order',
            );
          }
        }
      }
      if (n == 4) {
        examples.add({
          'case': label,
          'weeklyCounts': counts,
          'firstFive': dates.take(5).map(describe).toList(),
        });
      }
    }
  }

  // Old irregular dates are not rebuilt from a new program or start date.
  final legacy = <DateTime>[
    DateTime(2026, 10, 20, 9),
    DateTime(2026, 10, 24, 23, 30),
    DateTime(2026, 10, 25, 23, 30),
    DateTime(2026, 11, 3, 23, 30),
  ];
  final legacyEpochs = legacy.map((d) => d.microsecondsSinceEpoch).toList();
  final shifted = rescheduleAfterMiss(
    schedule: legacy,
    missedIndex: 2,
    slotSpacing: const Duration(days: 2),
  );
  check(
    identical(shifted[0], legacy[0]) && identical(shifted[1], legacy[1]),
    'legacy prefix objects preserved',
  );
  check(
    civil(shifted[2]) == '2026-10-27' && civil(shifted[3]) == '2026-11-5',
    'legacy irregular suffix shifted exactly2civil days',
  );
  check(
    legacy.asMap().entries.every(
      (e) => e.value.microsecondsSinceEpoch == legacyEpochs[e.key],
    ),
    'legacy no mutation',
  );

  final utcStart = DateTime.utc(2028, 2, 27, 23, 30, 1, 2, 3);
  final utc = scheduleProgram(
    program: builder.build(inputs(4)),
    startDate: utcStart,
    daysPerWeek: 4,
  );
  check(utc.every((d) => d.isUtc), 'UTC domain stays UTC');
  check(
    utc[1] == DateTime.utc(2028, 2, 28, 23, 30, 1, 2, 3),
    'UTC leap previous',
  );
  check(
    utc[2] == DateTime.utc(2028, 3, 1, 23, 30, 1, 2, 3),
    'UTC leap crossing',
  );
  final utcShift = rescheduleAfterMiss(
    schedule: utc,
    missedIndex: 1,
    slotSpacing: const Duration(days: 1),
  );
  check(
    identical(utcShift.first, utc.first) && utcShift.every((d) => d.isUtc),
    'UTC reschedule prefix/domain',
  );
  check(
    utcShift[1] == DateTime.utc(2028, 2, 29, 23, 30, 1, 2, 3),
    'UTC leap shift',
  );

  // Missing local hour uses Dart constructor normalization, while the civil
  // target date remains the next day. It is not a fixed24-hour promise.
  final gapSource = DateTime(2026, 3, 28, 2, 30);
  final gapShift = rescheduleAfterMiss(
    schedule: [gapSource],
    missedIndex: 0,
    slotSpacing: const Duration(days: 1),
  ).single;
  check(
    civilOrdinal(gapShift) - civilOrdinal(gapSource) == 1,
    'spring nonexistent-hour normalization keeps target civil day',
  );

  for (final n in <int>[-1, 0, 1, 7, 8]) {
    rejects(() => builder.build(inputs(n)), 'builder N$n');
  }
  for (final n in <int>[-1, 0, 8]) {
    rejects(
      () => scheduleProgram(
        program: const WorkoutProgram(programId: 'empty', days: []),
        startDate: utcStart,
        daysPerWeek: n,
      ),
      'schedule N$n',
    );
    rejects(() => scheduleGapDays(n), 'gap N$n');
  }
  for (final spacing in <Duration>[
    Duration.zero,
    const Duration(days: -1),
    const Duration(hours: 23),
    const Duration(hours: 25),
  ]) {
    rejects(
      () => rescheduleAfterMiss(
        schedule: [utcStart],
        missedIndex: 0,
        slotSpacing: spacing,
      ),
      'nonpositive/nonwhole spacing$spacing',
    );
  }
  stdout.writeln(
    jsonEncode({
      'result': 'PASS',
      'purpose': 'CALENDAR_REGRESSION',
      'tzRequested': Platform.environment['TZ'],
      'actualZone': describe(starts['baselineNoon']!),
      'dartVersion': Platform.version,
      'checks': checks,
      'calendarCases': calendarCases,
      'rescheduleCases': rescheduleCases,
      'repeatSteps': repeatSteps,
      'deloadDoseChecks': deloadChecks,
      'argumentGuards': guardCases,
      'shippingCatalogEntries': catalog.length,
      'examples': examples,
      'scope':
          'Real builder/schedule/reschedule; local/UTC dates and shipping content',
      'notValidated': [
        'Flutter UI',
        'RPE persistence',
        'old-file migration',
        'native device',
        'clinical prescription',
        'model',
        'account/provider',
      ],
    }),
  );
}
