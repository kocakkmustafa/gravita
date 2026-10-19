import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gravita/app/program/program_schedule_io.dart';
import 'package:gravita/app/program/program_builder.dart';
import 'package:gravita/app/program/program_model.dart';
import 'package:gravita/app/program/program_signature.dart';

// Standalone tests of the actual production IO/codec/transaction helper.
// This injected queue is only a scheduling harness. It does not exercise the
// Flutter CourseProgressLease, account epoch wiring, UI, native disk-full or
// abrupt process/power loss; those require their own acceptance evidence.
final class _Queue {
  Future<void>? _tail;

  Future<T> run<T>(Future<T> Function() operation) {
    final previous = _tail;
    final result = previous == null
        ? Future<T>.sync(operation)
        : previous.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> _failure<T>(
  Future<T> Function() action,
  ProgramScheduleFailure failure,
) async {
  try {
    await action();
  } on ProgramScheduleException catch (error) {
    _expect(
      error.failure == failure,
      'Expected $failure, got ${error.failure}',
    );
    return;
  }
  throw StateError('Expected ProgramScheduleException($failure)');
}

Future<void> _argumentFailure<T>(Future<T> Function() action) async {
  try {
    await action();
  } on ArgumentError {
    return;
  }
  throw StateError('Expected ArgumentError');
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

ProgramSchedule _schedule({String? signature = 'program-a'}) => ProgramSchedule(
  dates: <DateTime>[DateTime(2026, 10, 19), DateTime(2026, 10, 21)],
  rpeByDayIndex: <int, int>{},
  programSignature: signature,
);

Map<String, dynamic> _json({String? signature = 'program-a'}) =>
    <String, dynamic>{
      'schemaVersion': 1,
      'dates': <String>['2026-10-19T00:00:00.000', '2026-10-21T00:00:00.000'],
      'rpeByDayIndex': <String, dynamic>{'0': 7},
      if (signature != null) 'programSignature': signature,
    };

Future<void> main() async {
  final directory = await Directory.systemTemp.createTemp(
    'gravita-schedule-io-regression-',
  );
  var passed = 0;
  Future<void> test(String name, Future<void> Function(File file) body) async {
    final caseDirectory = await Directory('${directory.path}/$passed').create();
    await body(File('${caseDirectory.path}/program_schedule.json'));
    passed++;
    stdout.writeln('PASS $name');
  }

  try {
    await test('missing creates once and reopens signed data', (file) async {
      final queue = _Queue();
      final io = ProgramScheduleIo(file, serialize: queue.run);
      _expect(await io.read() == null, 'Only missing data should be null');
      var factoryCalls = 0;
      final created = await io.createIfMissing(() {
        factoryCalls++;
        return _schedule().withRpe(0, 7);
      });
      final firstBytes = await file.readAsBytes();
      final existing = await io.createIfMissing(() {
        factoryCalls++;
        return _schedule(signature: 'different-program');
      });
      final reopened = await ProgramScheduleIo(
        file,
        serialize: queue.run,
      ).read();
      _expect(factoryCalls == 1, 'Existing data must not invoke factory');
      _expect(created.programSignature == 'program-a', 'New binding missing');
      _expect(existing.rpeByDayIndex[0] == 7, 'Create replaced existing RPE');
      _expect(reopened?.rpeByDayIndex[0] == 7, 'RPE did not survive reopen');
      _expect(
        _sameBytes(firstBytes, await file.readAsBytes()),
        'Existing bytes changed',
      );
    });

    await test('legacy unversioned duplicate dates stay readable and unbound', (
      file,
    ) async {
      final queue = _Queue();
      final io = ProgramScheduleIo(file, serialize: queue.run);
      final legacy = _json(signature: null)..remove('schemaVersion');
      legacy['dates'] = <String>[
        '2026-10-19T08:30:00+03:00',
        '2026-10-19T08:30:00+03:00',
      ];
      final bytes = utf8.encode(jsonEncode(legacy));
      await file.writeAsBytes(bytes);
      final read = await io.read();
      _expect(read?.programSignature == null, 'Legacy data was auto-bound');
      _expect(
        read?.dates.length == 2 && read!.dates[0] == read.dates[1],
        'Legacy dates changed',
      );
      var factoryCalls = 0;
      await io.createIfMissing(() {
        factoryCalls++;
        return _schedule();
      });
      _expect(factoryCalls == 0, 'Legacy data was treated as missing');
      await _failure(
        () => io.update(
          expectedSignature: 'program-a',
          transform: (s) => s.withRpe(1, 6),
        ),
        ProgramScheduleFailure.signatureMismatch,
      );
      _expect(
        _sameBytes(bytes, await file.readAsBytes()),
        'Legacy bytes rewritten',
      );
      _expect(
        read!.withRpe(1, 6).programSignature == null,
        'Legacy copy auto-bound',
      );
    });

    final corrupt = <String, List<int>>{
      'truncated JSON': utf8.encode('{"dates":['),
      'invalid UTF-8': <int>[0xff, 0xfe],
      'unknown schema': utf8.encode(jsonEncode(_json()..['schemaVersion'] = 2)),
      'noninteger schema': utf8.encode(
        jsonEncode(_json()..['schemaVersion'] = 1.0),
      ),
      'unknown fields': utf8.encode(
        jsonEncode(_json()..['futureHistory'] = <int>[7, 8]),
      ),
      'string RPE': utf8.encode(
        jsonEncode(_json()..['rpeByDayIndex'] = <String, dynamic>{'0': '7'}),
      ),
      'fractional RPE': utf8.encode(
        jsonEncode(_json()..['rpeByDayIndex'] = <String, dynamic>{'0': 7.0}),
      ),
      'RPE outside range': utf8.encode(
        jsonEncode(_json()..['rpeByDayIndex'] = <String, dynamic>{'0': 11}),
      ),
      'day outside dates': utf8.encode(
        jsonEncode(_json()..['rpeByDayIndex'] = <String, dynamic>{'2': 7}),
      ),
      'negative day key': utf8.encode(
        jsonEncode(_json()..['rpeByDayIndex'] = <String, dynamic>{'-1': 7}),
      ),
      'noncanonical day key': utf8.encode(
        jsonEncode(_json()..['rpeByDayIndex'] = <String, dynamic>{'00': 7}),
      ),
      'normalized invalid date': utf8.encode(
        jsonEncode(_json()..['dates'] = <String>['2026-02-30T00:00:00.000']),
      ),
      'out of range date': utf8.encode(
        jsonEncode(
          _json()..['dates'] = <String>['+999999-01-01T00:00:00.000Z'],
        ),
      ),
      'invalid offset': utf8.encode(
        jsonEncode(_json()..['dates'] = <String>['2026-10-19T00:00:00+24:00']),
      ),
      'empty dates': utf8.encode(jsonEncode(_json()..['dates'] = <String>[])),
      'too many dates': utf8.encode(
        jsonEncode(
          _json()
            ..['dates'] = List<String>.filled(1001, '2026-10-19T00:00:00.000'),
        ),
      ),
      'oversized file': List<int>.filled(ProgramScheduleCodec.maxBytes + 1, 32),
      'nonstring signature': utf8.encode(
        jsonEncode(_json()..['programSignature'] = 1),
      ),
    };
    for (final entry in corrupt.entries) {
      await test('${entry.key} throws without erasing data', (file) async {
        final queue = _Queue();
        final io = ProgramScheduleIo(file, serialize: queue.run);
        await file.writeAsBytes(entry.value);
        await _failure(() => io.read(), ProgramScheduleFailure.corrupt);
        var factoryCalls = 0;
        await _failure(
          () => io.createIfMissing(() {
            factoryCalls++;
            return _schedule();
          }),
          ProgramScheduleFailure.corrupt,
        );
        await _failure(
          () => io.update(
            expectedSignature: 'program-a',
            transform: (s) => s.withRpe(1, 6),
          ),
          ProgramScheduleFailure.corrupt,
        );
        _expect(factoryCalls == 0, 'Corrupt data invoked create factory');
        _expect(
          _sameBytes(entry.value, await file.readAsBytes()),
          'Corrupt bytes changed',
        );
      });
    }

    await test('directory path is unavailable rather than missing', (
      file,
    ) async {
      await Directory(file.path).create();
      final queue = _Queue();
      final io = ProgramScheduleIo(file, serialize: queue.run);
      await _failure(() => io.read(), ProgramScheduleFailure.unavailable);
      var factoryCalls = 0;
      await _failure(
        () => io.createIfMissing(() {
          factoryCalls++;
          return _schedule();
        }),
        ProgramScheduleFailure.unavailable,
      );
      _expect(factoryCalls == 0, 'Unavailable data invoked create factory');
      _expect(await Directory(file.path).exists(), 'Unavailable path changed');
    });

    await test('update missing never creates data', (file) async {
      final queue = _Queue();
      final io = ProgramScheduleIo(file, serialize: queue.run);
      await _failure(
        () => io.update(
          expectedSignature: 'program-a',
          transform: (s) => s.withRpe(0, 7),
        ),
        ProgramScheduleFailure.missing,
      );
      _expect(!await file.exists(), 'Update created an absent schedule');
    });

    await test('binding mismatch and invalid transforms preserve prior bytes', (
      file,
    ) async {
      final queue = _Queue();
      final io = ProgramScheduleIo(file, serialize: queue.run);
      await io.write(_schedule().withRpe(0, 7));
      final bytes = await file.readAsBytes();
      var transformCalls = 0;
      await _failure(
        () => io.update(
          expectedSignature: 'program-b',
          transform: (s) {
            transformCalls++;
            return s.withRpe(1, 6);
          },
        ),
        ProgramScheduleFailure.signatureMismatch,
      );
      _expect(transformCalls == 0, 'Mismatched program invoked transform');
      await _failure(
        () => io.update(
          expectedSignature: 'program-a',
          transform: (s) => _schedule(signature: 'program-b'),
        ),
        ProgramScheduleFailure.signatureMismatch,
      );
      await _argumentFailure(
        () => io.update(
          expectedSignature: 'program-a',
          transform: (s) => s.withRpe(1, 0),
        ),
      );
      _expect(
        _sameBytes(bytes, await file.readAsBytes()),
        'Rejected update changed bytes',
      );
    });

    await test('two queued production updates retain both RPE values', (
      file,
    ) async {
      final queue = _Queue();
      final first = ProgramScheduleIo(file, serialize: queue.run);
      final second = ProgramScheduleIo(file, serialize: queue.run);
      await first.createIfMissing(_schedule);
      final entered = Completer<void>();
      final release = Completer<void>();
      final barrier = queue.run(() async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final firstUpdate = first.update(
        expectedSignature: 'program-a',
        transform: (s) => s.withRpe(0, 7),
      );
      final secondUpdate = second.update(
        expectedSignature: 'program-a',
        transform: (s) => s.withRpe(1, 6),
      );
      release.complete();
      await barrier;
      await Future.wait(<Future<ProgramSchedule>>[firstUpdate, secondUpdate]);
      final reopened = await first.read();
      _expect(reopened?.rpeByDayIndex.length == 2, 'A queued update was lost');
      _expect(reopened?.rpeByDayIndex[0] == 7, 'First RPE was lost');
      _expect(reopened?.rpeByDayIndex[1] == 6, 'Second RPE was lost');
    });

    await test('queued reschedule and RPE each use current persisted state', (
      file,
    ) async {
      final queue = _Queue();
      final io = ProgramScheduleIo(file, serialize: queue.run);
      await io.createIfMissing(_schedule);
      final changedDates = <DateTime>[
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 3),
      ];
      final move = io.update(
        expectedSignature: 'program-a',
        transform: (s) => s.withDates(changedDates),
      );
      final complete = io.update(
        expectedSignature: 'program-a',
        transform: (s) => s.withRpe(1, 6),
      );
      await Future.wait(<Future<ProgramSchedule>>[move, complete]);
      final reopened = await io.read();
      _expect(reopened?.dates[0] == changedDates[0], 'RPE overwrote new dates');
      _expect(reopened?.rpeByDayIndex[1] == 6, 'Reschedule overwrote RPE');
      _expect(reopened?.programSignature == 'program-a', 'Copy lost binding');
    });

    await test('partial temporary write failure preserves original data', (
      file,
    ) async {
      final queue = _Queue();
      await ProgramScheduleIo(
        file,
        serialize: queue.run,
      ).write(_schedule().withRpe(0, 7));
      final bytes = await file.readAsBytes();
      final io = ProgramScheduleIo(
        file,
        serialize: queue.run,
        writeTemporary: (temporary, next) async {
          await temporary.writeAsBytes(next.take(5).toList(), flush: true);
          throw const FileSystemException('Injected temporary write failure');
        },
      );
      await _failure(
        () => io.update(
          expectedSignature: 'program-a',
          transform: (s) => s.withRpe(1, 6),
        ),
        ProgramScheduleFailure.unavailable,
      );
      _expect(
        _sameBytes(bytes, await file.readAsBytes()),
        'Failed write truncated original',
      );
      _expect(
        (await file.parent.list().toList()).length == 1,
        'Owned temporary directory leaked',
      );
    });

    await test('failure before rename preserves original data', (file) async {
      final queue = _Queue();
      await ProgramScheduleIo(
        file,
        serialize: queue.run,
      ).write(_schedule().withRpe(0, 7));
      final bytes = await file.readAsBytes();
      final io = ProgramScheduleIo(
        file,
        serialize: queue.run,
        commit: (temporary, target) async {
          _expect(
            await temporary.exists(),
            'Commit did not receive temporary file',
          );
          throw const FileSystemException('Injected pre-rename failure');
        },
      );
      await _failure(
        () => io.update(
          expectedSignature: 'program-a',
          transform: (s) => s.withRpe(1, 6),
        ),
        ProgramScheduleFailure.unavailable,
      );
      _expect(
        _sameBytes(bytes, await file.readAsBytes()),
        'Failed rename erased original',
      );
      _expect(
        (await file.parent.list().toList()).length == 1,
        'Failed attempt temporary directory leaked',
      );
    });

    await test('owner check blocks commit after temporary write', (file) async {
      final queue = _Queue();
      await ProgramScheduleIo(
        file,
        serialize: queue.run,
      ).write(_schedule().withRpe(0, 7));
      final bytes = await file.readAsBytes();
      var current = true;
      var commitCalls = 0;
      final io = ProgramScheduleIo(
        file,
        serialize: queue.run,
        checkCurrent: () {
          if (!current) throw StateError('Injected retired owner');
        },
        writeTemporary: (temporary, next) async {
          await temporary.writeAsBytes(next, flush: true);
          current = false;
        },
        commit: (temporary, target) async {
          commitCalls++;
          await temporary.rename(target.path);
        },
      );
      var retired = false;
      try {
        await io.update(
          expectedSignature: 'program-a',
          transform: (s) => s.withRpe(1, 6),
        );
      } on StateError {
        retired = true;
      }
      _expect(retired, 'Retired owner was swallowed');
      _expect(commitCalls == 0, 'Retired owner dispatched rename');
      _expect(
        _sameBytes(bytes, await file.readAsBytes()),
        'Retired owner changed original',
      );
      _expect(
        (await file.parent.list().toList()).length == 1,
        'Retired owner temporary directory leaked',
      );
    });

    await test(
      'new schedule needs binding and large canonical binding is supported',
      (file) async {
        final queue = _Queue();
        final io = ProgramScheduleIo(file, serialize: queue.run);
        await _argumentFailure(
          () => io.createIfMissing(() => _schedule(signature: null)),
        );
        _expect(!await file.exists(), 'Unbound create wrote data');
        final signature = jsonEncode(<String, Object>{
          'recipe': List<int>.filled(5000, 1),
        });
        await io.createIfMissing(() => _schedule(signature: signature));
        final reopened = await io.read();
        _expect(
          reopened?.programSignature == signature,
          'Canonical binding was shortened',
        );
        _expect(
          reopened!.withRpe(1, 6).programSignature == signature,
          'RPE copy lost binding',
        );
        _expect(
          reopened.withDates(reopened.dates).programSignature == signature,
          'Date copy lost binding',
        );
      },
    );

    await test(
      'maximum current 48-session program and full production binding fit byte budget',
      (file) async {
        final configJson =
            (jsonDecode(
                      await File(
                        'content/programs/foundation.v1.json',
                      ).readAsString(),
                    )
                    as Map)
                .cast<String, dynamic>();
        final config = ProgramConfig.fromJson(configJson);
        // Synthetic five-family input, actual production builder and signature.
        // The fixture claims storage compatibility, not exercise/medical validity.
        final catalog = <ProgramCatalogEntry>[
          for (final family in <String>[
            'push',
            'pull',
            'legs',
            'core',
            'shoulders',
          ])
            ProgramCatalogEntry(
              id: 'fixture_$family',
              family: family,
              level: 'beginner',
              equipment: <String>{},
              isHold: family == 'core',
              isLive: false,
            ),
        ];
        final inputs = ProgramInputs(
          availableEquipment: <String>{},
          daysPerWeek: config.maxDaysPerWeek,
          experience: ExperienceLevel.beginner,
        );
        final program = ProgramBuilder(
          config: config,
          catalog: catalog,
        ).build(inputs);
        _expect(
          program.totalSessions == 48,
          'Current maximum fixture changed; review byte budget',
        );
        final signature = programSignature(inputs, program);
        final schedule = ProgramSchedule(
          dates: List<DateTime>.generate(
            program.totalSessions,
            (index) => DateTime(2026, 10, 19 + index),
          ),
          rpeByDayIndex: <int, int>{
            for (var i = 0; i < program.totalSessions; i++) i: 7,
          },
          programSignature: signature,
        );
        final queue = _Queue();
        final io = ProgramScheduleIo(file, serialize: queue.run);
        await io.createIfMissing(() => schedule);
        final bytes = await file.readAsBytes();
        _expect(
          bytes.length < ProgramScheduleCodec.maxBytes,
          'Current full binding exceeds byte budget',
        );
        final reopened = await io.read();
        _expect(reopened?.dates.length == 48, 'Full schedule did not reopen');
        _expect(
          reopened?.rpeByDayIndex.length == 48,
          'Full history did not reopen',
        );
        _expect(
          reopened?.programSignature == signature,
          'Production binding did not reopen exactly',
        );
        stdout.writeln(
          jsonEncode(<String, Object>{
            'storageCompatibilityBytes': bytes.length,
            'sessions': 48,
          }),
        );
      },
    );

    stdout.writeln(
      jsonEncode(<String, Object>{
        'suite': 'actual ProgramScheduleIo pure Dart regression',
        'passed': passed,
        'scope':
            'synthetic files; injected transaction queue and precommit faults',
        'nativeOrFlutterExecuted': false,
      }),
    );
  } finally {
    await directory.delete(recursive: true);
  }
}
