import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gravita/app/program/program_inputs_io.dart';
import 'package:gravita/app/program/program_model.dart';

// Actual production IO/codec with synthetic files and an injected serial queue.
// This does not execute Flutter CourseProgressLease/epoch wiring, Setup's two
// files, native disk-full, process death, power loss or backup/restore.
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

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

void _sameInputs(ProgramInputs? actual, ProgramInputs expected) {
  if (actual == null) throw StateError('Expected persisted inputs');
  _expect(actual.daysPerWeek == expected.daysPerWeek, 'Frequency changed');
  _expect(actual.experience == expected.experience, 'Experience changed');
  _expect(
    actual.availableEquipment.length == expected.availableEquipment.length &&
        actual.availableEquipment.containsAll(expected.availableEquipment),
    'Equipment changed',
  );
}

Future<void> _failure<T>(
  Future<T> Function() action,
  ProgramInputsFailure failure,
) async {
  try {
    await action();
  } on ProgramInputsException catch (error) {
    _expect(
      error.failure == failure,
      'Expected $failure, got ${error.failure}',
    );
    return;
  }
  throw StateError('Expected ProgramInputsException($failure)');
}

Future<void> _argumentFailure<T>(Future<T> Function() action) async {
  try {
    await action();
  } on ArgumentError {
    return;
  }
  throw StateError('Expected ArgumentError');
}

Future<void> _ownerFailure<T>(Future<T> Function() action) async {
  try {
    await action();
  } on StateError {
    return;
  }
  throw StateError('Expected retired-owner StateError');
}

ProgramInputs _inputs({int days = 4}) => ProgramInputs(
  availableEquipment: <String>{'pull_up_bar', 'dumbbell'},
  daysPerWeek: days,
  experience: ExperienceLevel.intermediate,
);

Map<String, dynamic> _json() => <String, dynamic>{
  'schemaVersion': 1,
  'availableEquipment': <String>['pull_up_bar', 'dumbbell'],
  'daysPerWeek': 4,
  'experience': 'intermediate',
};

Future<void> main() async {
  final directory = await Directory.systemTemp.createTemp(
    'gravita-inputs-io-regression-',
  );
  var passed = 0;
  Future<void> test(String name, Future<void> Function(File file) body) async {
    final caseDirectory = await Directory('${directory.path}/$passed').create();
    await body(File('${caseDirectory.path}/program_inputs.json'));
    passed++;
    stdout.writeln('PASS $name');
  }

  try {
    await test('missing reads null without creating parent or target', (
      file,
    ) async {
      final nested = File('${file.parent.path}/not-created/inputs.json');
      final queue = _Queue();
      final io = ProgramInputsIo(nested, serialize: queue.run);
      _expect(await io.read() == null, 'Actual ENOENT must be null');
      _expect(!await nested.parent.exists(), 'Read created a directory');
      _expect(!await nested.exists(), 'Read created inputs');
    });

    await test('production write reopens every current UI frequency', (
      file,
    ) async {
      final queue = _Queue();
      final io = ProgramInputsIo(file, serialize: queue.run);
      for (var days = 2; days <= 6; days++) {
        final expected = _inputs(days: days);
        await io.write(expected);
        _sameInputs(
          await ProgramInputsIo(file, serialize: queue.run).read(),
          expected,
        );
        final root = jsonDecode(await file.readAsString()) as Map;
        _expect(root['schemaVersion'] == 1, 'Writer omitted schema 1');
        _expect(
          (await file.parent.list().toList()).length == 1,
          'Successful write leaked a temporary directory',
        );
      }
      // Empty equipment is the existing bodyweight representation.
      const bodyweight = ProgramInputs(
        availableEquipment: <String>{},
        daysPerWeek: 3,
        experience: ExperienceLevel.beginner,
      );
      await io.write(bodyweight);
      _sameInputs(await io.read(), bodyweight);
    });

    await test('unversioned legacy read keeps exact bytes and set semantics', (
      file,
    ) async {
      final legacy = _json()..remove('schemaVersion');
      legacy['availableEquipment'] = <String>[
        'pull_up_bar',
        'dumbbell',
        'dumbbell',
      ];
      final bytes = utf8.encode(jsonEncode(legacy));
      await file.writeAsBytes(bytes);
      final queue = _Queue();
      _sameInputs(
        await ProgramInputsIo(file, serialize: queue.run).read(),
        _inputs(),
      );
      _expect(
        _sameBytes(bytes, await file.readAsBytes()),
        'Legacy read rewrote or migrated data',
      );
    });

    final corrupt = <String, List<int>>{
      'truncated JSON': utf8.encode('{"availableEquipment":['),
      'invalid UTF-8': <int>[0xff, 0xfe],
      'non-object root': utf8.encode('[]'),
      'unknown schema': utf8.encode(jsonEncode(_json()..['schemaVersion'] = 2)),
      'noninteger schema': utf8.encode(
        jsonEncode(_json()..['schemaVersion'] = 1.0),
      ),
      'explicit null schema': utf8.encode(
        jsonEncode(_json()..['schemaVersion'] = null),
      ),
      'unknown fields': utf8.encode(
        jsonEncode(_json()..['futureHistory'] = <int>[1, 2]),
      ),
      'missing equipment': utf8.encode(
        jsonEncode(_json()..remove('availableEquipment')),
      ),
      'equipment not list': utf8.encode(
        jsonEncode(_json()..['availableEquipment'] = 'dumbbell'),
      ),
      'nonstring equipment': utf8.encode(
        jsonEncode(_json()..['availableEquipment'] = <Object>['dumbbell', 7]),
      ),
      'empty equipment name': utf8.encode(
        jsonEncode(_json()..['availableEquipment'] = <String>['']),
      ),
      'too many equipment entries': utf8.encode(
        jsonEncode(
          _json()
            ..['availableEquipment'] = List<String>.generate(
              ProgramInputsCodec.maxEquipment + 1,
              (i) => 'equipment_$i',
            ),
        ),
      ),
      'equipment name too long': utf8.encode(
        jsonEncode(
          _json()
            ..['availableEquipment'] = <String>[
              List<String>.filled(
                ProgramInputsCodec.maxEquipmentNameLength + 1,
                'x',
              ).join(),
            ],
        ),
      ),
      'missing frequency': utf8.encode(
        jsonEncode(_json()..remove('daysPerWeek')),
      ),
      'noninteger frequency': utf8.encode(
        jsonEncode(_json()..['daysPerWeek'] = 4.0),
      ),
      'zero frequency': utf8.encode(jsonEncode(_json()..['daysPerWeek'] = 0)),
      'frequency beyond week': utf8.encode(
        jsonEncode(_json()..['daysPerWeek'] = 8),
      ),
      'missing experience': utf8.encode(
        jsonEncode(_json()..remove('experience')),
      ),
      'unknown experience': utf8.encode(
        jsonEncode(_json()..['experience'] = 'future-level'),
      ),
      'nonstring experience': utf8.encode(
        jsonEncode(_json()..['experience'] = 1),
      ),
      'oversized file': List<int>.filled(ProgramInputsCodec.maxBytes + 1, 32),
    };
    for (final entry in corrupt.entries) {
      await test('${entry.key} fails without changing bytes', (file) async {
        await file.writeAsBytes(entry.value);
        final queue = _Queue();
        final io = ProgramInputsIo(file, serialize: queue.run);
        await _failure(() => io.read(), ProgramInputsFailure.corrupt);
        await _failure(
          () => ProgramInputsIo(file, serialize: queue.run).read(),
          ProgramInputsFailure.corrupt,
        );
        _expect(
          _sameBytes(entry.value, await file.readAsBytes()),
          'Read failure erased or repaired existing bytes',
        );
        _expect(
          (await file.parent.list().toList()).length == 1,
          'Read failure created temporary/recovery files',
        );
      });
    }

    await test('directory target is unavailable and is never replaced', (
      file,
    ) async {
      await Directory(file.path).create();
      final marker = File('${file.path}/keep.txt');
      await marker.writeAsString('preserve directory');
      final queue = _Queue();
      final io = ProgramInputsIo(file, serialize: queue.run);
      await _failure(() => io.read(), ProgramInputsFailure.unavailable);
      await _failure(
        () => io.write(_inputs()),
        ProgramInputsFailure.unavailable,
      );
      _expect(
        await marker.readAsString() == 'preserve directory',
        'Path changed',
      );
    });

    await test('invalid write validates before parent or target mutation', (
      file,
    ) async {
      final queue = _Queue();
      final io = ProgramInputsIo(file, serialize: queue.run);
      await io.write(_inputs());
      final bytes = await file.readAsBytes();
      var hookCalls = 0;
      final rejected = ProgramInputsIo(
        file,
        serialize: queue.run,
        writeTemporary: (temporary, next) async {
          hookCalls++;
        },
        commit: (temporary, target) async {
          hookCalls++;
        },
      );
      await _argumentFailure(() => rejected.write(_inputs(days: 0)));
      await _argumentFailure(() => rejected.write(_inputs(days: 8)));
      await _argumentFailure(
        () => rejected.write(
          const ProgramInputs(
            availableEquipment: <String>{''},
            daysPerWeek: 4,
            experience: ExperienceLevel.beginner,
          ),
        ),
      );
      final nested = File('${file.parent.path}/not-created/inputs.json');
      await _argumentFailure(
        () => ProgramInputsIo(
          nested,
          serialize: queue.run,
        ).write(_inputs(days: 0)),
      );
      _expect(hookCalls == 0, 'Invalid inputs reached a file-operation hook');
      _expect(!await nested.parent.exists(), 'Invalid input created a parent');
      _expect(
        _sameBytes(bytes, await file.readAsBytes()),
        'Invalid write changed data',
      );
      _expect(
        (await file.parent.list().toList()).length == 1,
        'Invalid write left files',
      );
    });

    await test('partial temporary write failure preserves original on reopen', (
      file,
    ) async {
      final queue = _Queue();
      final original = ProgramInputsIo(file, serialize: queue.run);
      await original.write(_inputs());
      final bytes = await file.readAsBytes();
      final failing = ProgramInputsIo(
        file,
        serialize: queue.run,
        writeTemporary: (temporary, next) async {
          await temporary.writeAsBytes(next.take(5).toList(), flush: true);
          throw const FileSystemException('Injected temporary write failure');
        },
      );
      await _failure(
        () => failing.write(_inputs(days: 5)),
        ProgramInputsFailure.unavailable,
      );
      _expect(
        _sameBytes(bytes, await file.readAsBytes()),
        'Failed write truncated inputs',
      );
      _sameInputs(await original.read(), _inputs());
      _expect(
        (await file.parent.list().toList()).length == 1,
        'Temporary attempt leaked',
      );
    });

    await test('failed first write keeps target genuinely missing', (
      file,
    ) async {
      final queue = _Queue();
      final failing = ProgramInputsIo(
        file,
        serialize: queue.run,
        writeTemporary: (temporary, next) async {
          await temporary.writeAsBytes(next.take(3).toList(), flush: true);
          throw const FileSystemException('Injected first write failure');
        },
      );
      await _failure(
        () => failing.write(_inputs()),
        ProgramInputsFailure.unavailable,
      );
      _expect(
        !await file.exists(),
        'Failed first write created corrupt inputs',
      );
      _expect(await failing.read() == null, 'Failed first write is not ENOENT');
      _expect(
        (await file.parent.list().toList()).isEmpty,
        'Failed first attempt leaked',
      );
    });

    await test(
      'pre-rename failure uses unique same-parent temps and preserves siblings',
      (file) async {
        final queue = _Queue();
        final original = ProgramInputsIo(file, serialize: queue.run);
        await original.write(_inputs());
        final bytes = await file.readAsBytes();
        final sibling = await Directory(
          '${file.parent.path}/.program-inputs-unrelated',
        ).create();
        final marker = File('${sibling.path}/keep.txt');
        await marker.writeAsString('unrelated attempt');
        final attempts = <String>[];
        final failing = ProgramInputsIo(
          file,
          serialize: queue.run,
          commit: (temporary, target) async {
            _expect(
              await temporary.exists(),
              'Commit received no temporary file',
            );
            _expect(target.path == file.path, 'Commit target changed');
            _expect(
              temporary.parent.parent.absolute.path ==
                  file.parent.absolute.path,
              'Temporary attempt is not on the same parent/filesystem',
            );
            attempts.add(temporary.parent.path);
            throw const FileSystemException('Injected pre-rename failure');
          },
        );
        for (var i = 0; i < 2; i++) {
          await _failure(
            () => failing.write(_inputs(days: 5)),
            ProgramInputsFailure.unavailable,
          );
        }
        _expect(
          attempts.length == 2 && attempts[0] != attempts[1],
          'Temp attempt reused',
        );
        _expect(
          _sameBytes(bytes, await file.readAsBytes()),
          'Failed rename erased inputs',
        );
        _sameInputs(await original.read(), _inputs());
        _expect(
          await marker.readAsString() == 'unrelated attempt',
          'Sibling was cleaned',
        );
        _expect(
          (await file.parent.list().toList()).length == 2,
          'Own failed attempt leaked',
        );
      },
    );

    await test('retired owner before write cannot dispatch file operations', (
      file,
    ) async {
      final queue = _Queue();
      final original = ProgramInputsIo(file, serialize: queue.run);
      await original.write(_inputs());
      final bytes = await file.readAsBytes();
      var writes = 0;
      final retired = ProgramInputsIo(
        file,
        serialize: queue.run,
        checkCurrent: () => throw StateError('Injected retired owner'),
        writeTemporary: (temporary, next) async {
          writes++;
        },
      );
      await _ownerFailure(() => retired.write(_inputs(days: 5)));
      await _ownerFailure(() => retired.read());
      _expect(writes == 0, 'Retired owner dispatched write');
      _expect(
        _sameBytes(bytes, await file.readAsBytes()),
        'Retired owner changed inputs',
      );
    });

    await test('owner retirement after temporary write blocks commit', (
      file,
    ) async {
      final queue = _Queue();
      final original = ProgramInputsIo(file, serialize: queue.run);
      await original.write(_inputs());
      final bytes = await file.readAsBytes();
      var current = true;
      var commits = 0;
      final io = ProgramInputsIo(
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
          commits++;
          await temporary.rename(target.path);
        },
      );
      await _ownerFailure(() => io.write(_inputs(days: 5)));
      _expect(commits == 0, 'Retired owner dispatched rename');
      _expect(
        _sameBytes(bytes, await file.readAsBytes()),
        'Retired owner erased inputs',
      );
      _sameInputs(await original.read(), _inputs());
      _expect(
        (await file.parent.list().toList()).length == 1,
        'Retired attempt leaked',
      );
    });

    await test('post-commit owner failure is not falsely treated as rollback', (
      file,
    ) async {
      final queue = _Queue();
      final original = ProgramInputsIo(file, serialize: queue.run);
      await original.write(_inputs());
      var current = true;
      final io = ProgramInputsIo(
        file,
        serialize: queue.run,
        checkCurrent: () {
          if (!current) throw StateError('Injected post-commit owner change');
        },
        commit: (temporary, target) async {
          await temporary.rename(target.path);
          current = false;
        },
      );
      await _ownerFailure(() => io.write(_inputs(days: 5)));
      _sameInputs(await original.read(), _inputs(days: 5));
      _expect(
        (await file.parent.list().toList()).length == 1,
        'Committed attempt leaked',
      );
    });

    await test(
      'two queued explicit writers settle and reopen last complete inputs',
      (file) async {
        final queue = _Queue();
        final first = ProgramInputsIo(file, serialize: queue.run);
        final second = ProgramInputsIo(file, serialize: queue.run);
        final entered = Completer<void>();
        final release = Completer<void>();
        final barrier = queue.run(() async {
          entered.complete();
          await release.future;
        });
        await entered.future;
        final one = first.write(_inputs(days: 3));
        final two = second.write(_inputs(days: 5));
        release.complete();
        await barrier;
        await Future.wait<void>(<Future<void>>[one, two]);
        _sameInputs(await first.read(), _inputs(days: 5));
        _expect(
          (await file.parent.list().toList()).length == 1,
          'Queued writes leaked',
        );
      },
    );

    stdout.writeln(
      jsonEncode(<String, Object>{
        'suite': 'actual ProgramInputsIo pure Dart regression',
        'passed': passed,
        'scope':
            'synthetic files; injected serial queue and precommit/owner faults',
        'nativeOrFlutterExecuted': false,
        'setupTwoFileTransactionTested': false,
      }),
    );
  } finally {
    await directory.delete(recursive: true);
  }
}
