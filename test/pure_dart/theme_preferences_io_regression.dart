import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gravita/app/theme_preferences_codec.dart';
import 'package:gravita/app/theme_preferences_io.dart';

// Standalone production codec/IO regression. No Flutter or package:test.
// POSIX /tmp and symlinks are required; cases are never silently skipped.
Future<void> main() async {
  const expectedIoCases = 39;
  const expectedChecks = 244;
  var checks = 0;
  var ioCases = 0;
  void check(bool condition, String label) {
    if (!condition) throw StateError(label);
    checks++;
  }

  bool sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void rejectsFormat(List<int> bytes, String label) {
    var rejected = false;
    try {
      ThemePreferencesCodec.decode(bytes);
    } on FormatException {
      rejected = true;
    }
    check(rejected, label);
  }

  Future<void> rejects(Future<void> Function() action, String label) async {
    Object? error;
    try {
      await action();
    } on Object catch (caught) {
      error = caught;
    }
    check(
      error is FileSystemException || error is FormatException,
      '$label: expected filesystem/format failure, got ${error.runtimeType}',
    );
  }

  final invalid = <String, List<int>>{
    'empty': utf8.encode(''),
    'truncated': utf8.encode('{'),
    'null root': utf8.encode('null'),
    'array root': utf8.encode('[]'),
    'missing fields': utf8.encode('{}'),
    'future schema': utf8.encode('{"schemaVersion":2,"themeMode":"dark"}'),
    'double schema': utf8.encode('{"schemaVersion":1.0,"themeMode":"dark"}'),
    'string schema': utf8.encode('{"schemaVersion":"1","themeMode":"dark"}'),
    'null mode': utf8.encode('{"schemaVersion":1,"themeMode":null}'),
    'bool mode': utf8.encode('{"schemaVersion":1,"themeMode":false}'),
    'array mode': utf8.encode('{"schemaVersion":1,"themeMode":[]}'),
    'object mode': utf8.encode('{"schemaVersion":1,"themeMode":{}}'),
    'unknown mode': utf8.encode('{"schemaVersion":1,"themeMode":"unknown"}'),
    'case-sensitive mode': utf8.encode(
      '{"schemaVersion":1,"themeMode":"Dark"}',
    ),
    'unknown field': utf8.encode(
      '{"schemaVersion":1,"themeMode":"dark","account":"synthetic"}',
    ),
    'substituted field': utf8.encode('{"schemaVersion":1,"extra":"dark"}'),
    'invalid UTF-8': <int>[0xff],
  };
  final encodedDark = ThemePreferencesCodec.encode(GravitaThemeMode.dark);
  final boundary = <int>[
    ...encodedDark,
    ...List<int>.filled(
      ThemePreferencesCodec.maximumBytes - encodedDark.length,
      32,
    ),
  ];
  final oversized = <int>[...boundary, 32];
  final root = await Directory(
    '/tmp',
  ).createTemp('gravita-theme-io-regression-');
  Future<void> scenario(
    String name,
    Future<void> Function(Directory directory, File file) body,
  ) async {
    final directory = await Directory('${root.path}/$ioCases').create();
    try {
      await body(directory, File('${directory.path}/theme.json'));
      ioCases++;
      stdout.writeln('PASS $name');
    } finally {
      await directory.delete(recursive: true);
    }
  }

  try {
    for (final mode in GravitaThemeMode.values) {
      final bytes = ThemePreferencesCodec.encode(mode);
      check(
        bytes.length <= ThemePreferencesCodec.maximumBytes,
        'Bounded $mode',
      );
      check(
        ThemePreferencesCodec.decode(bytes) == mode,
        'Codec roundtrip $mode',
      );
      final document = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      check(
        document.length == 2 &&
            document['schemaVersion'] == 1 &&
            document['themeMode'] == mode.name,
        'Only schema and appearance persisted $mode',
      );
    }
    for (final entry in invalid.entries) {
      rejectsFormat(entry.value, 'Codec rejects ${entry.key}');
    }
    check(
      boundary.length == ThemePreferencesCodec.maximumBytes &&
          ThemePreferencesCodec.decode(boundary) == GravitaThemeMode.dark,
      'Exactly maximumBytes valid document is accepted',
    );
    rejectsFormat(oversized, 'maximumBytes + 1 is rejected');

    await scenario('missing is read-only system fallback', (
      directory,
      file,
    ) async {
      final nested = File('${directory.path}/absent/theme.json');
      final result = await FileThemePreferencesStore(nested).load();
      check(
        result.mode == GravitaThemeMode.system && result.issue == null,
        'Missing',
      );
      check(!await nested.parent.exists(), 'Load did not create parent');
      check(
        (await directory.list().toList()).isEmpty,
        'Missing load created nothing',
      );
    });
    await scenario('factory and all modes survive fresh stores', (
      directory,
      _,
    ) async {
      final store = FileThemePreferencesStore.inDirectory(directory);
      check(
        store.file.path ==
            '${directory.path}/gravita.theme-preferences.v1.json',
        'Factory uses dedicated appearance filename',
      );
      for (final mode in GravitaThemeMode.values) {
        await store.save(mode);
        final result = await FileThemePreferencesStore.inDirectory(
          directory,
        ).load();
        check(
          result.mode == mode && result.issue == null,
          'Disk roundtrip $mode',
        );
        check(
          sameBytes(
            await store.file.readAsBytes(),
            ThemePreferencesCodec.encode(mode),
          ),
          'Exact persisted document $mode',
        );
        check(
          (await directory.list().toList()).length == 1,
          'No roundtrip artifacts',
        );
      }
    });
    for (final entry in invalid.entries) {
      await scenario('invalid ${entry.key} preserves original', (
        directory,
        file,
      ) async {
        await file.writeAsBytes(entry.value);
        final result = await FileThemePreferencesStore(file).load();
        check(
          result.mode == GravitaThemeMode.system &&
              result.issue == ThemePreferencesLoadIssue.invalid,
          'Invalid fallback ${entry.key}',
        );
        check(
          sameBytes(await file.readAsBytes(), entry.value),
          'Invalid bytes retained',
        );
        check(
          (await directory.list().toList()).length == 1,
          'Read creates no backup/temp',
        );
      });
    }
    for (final original in <List<int>>[
      List<int>.filled(ThemePreferencesCodec.maximumBytes, 123),
      <int>[0xff],
    ]) {
      await scenario('bounded corrupt recovery ${original.length}', (
        directory,
        file,
      ) async {
        await file.writeAsBytes(original);
        final store = FileThemePreferencesStore(file);
        final loaded = await store.load();
        check(
          loaded.mode == GravitaThemeMode.system &&
              loaded.issue == ThemePreferencesLoadIssue.invalid,
          'Corrupt fallback',
        );
        check(
          sameBytes(await file.readAsBytes(), original),
          'Read preserves corruption',
        );
        final backup = File('${file.path}.invalid');
        check(!await backup.exists(), 'Read makes no backup');
        await store.save(GravitaThemeMode.light);
        final saved = await FileThemePreferencesStore(file).load();
        check(
          sameBytes(await backup.readAsBytes(), original) &&
              await backup.length() <= ThemePreferencesCodec.maximumBytes,
          'Exact bounded backup preserves original',
        );
        check(
          saved.mode == GravitaThemeMode.light && saved.issue == null,
          'Recovery saved',
        );
        await store.save(GravitaThemeMode.dark);
        check(
          sameBytes(await backup.readAsBytes(), original),
          'Backup never overwritten',
        );
        final later = await FileThemePreferencesStore(file).load();
        check(
          later.mode == GravitaThemeMode.dark && later.issue == null,
          'Later save works',
        );
        check(
          (await directory.list().toList()).length == 2,
          'Only target and one backup',
        );
      });
    }
    await scenario('identical existing backup permits explicit recovery', (
      directory,
      file,
    ) async {
      final original = utf8.encode('same invalid');
      await file.writeAsBytes(original);
      final backup = await File('${file.path}.invalid').writeAsBytes(original);
      await FileThemePreferencesStore(file).save(GravitaThemeMode.light);
      check(
        sameBytes(await backup.readAsBytes(), original),
        'Matching backup retained',
      );
      check(
        (await FileThemePreferencesStore(file).load()).mode ==
            GravitaThemeMode.light,
        'Recovered',
      );
      check(
        (await directory.list().toList()).length == 2,
        'No extra backup or temp',
      );
    });
    final backupFailureOriginal = utf8.encode('{"unfinished":');
    for (final writtenBytes in <int>[0, 4, backupFailureOriginal.length]) {
      await scenario('backup failure after $writtenBytes bytes allows retry', (
        directory,
        file,
      ) async {
        final original = backupFailureOriginal;
        await file.writeAsBytes(original);
        final backup = File('${file.path}.invalid');
        final unrelated = await File(
          '${file.path}.invalid.tmp.someone-else',
        ).writeAsString('keep');
        var fail = true;
        var writes = 0;
        final store = FileThemePreferencesStore(
          file,
          writeBackup: (target, bytes) async {
            writes++;
            check(
              target.path == backup.path && sameBytes(bytes, original),
              'Backup writer receives exact path and original bytes',
            );
            check(
              await target.exists() && await target.length() == 0,
              'Backup writer receives a newly created empty reservation',
            );
            if (fail) {
              await target.writeAsBytes(
                bytes.sublist(0, writtenBytes),
                flush: true,
              );
              throw FileSystemException('synthetic backup write/flush failure');
            }
            await target.writeAsBytes(bytes, flush: true);
          },
        );
        await rejects(
          () => store.save(GravitaThemeMode.light),
          'Backup failure after $writtenBytes bytes is surfaced',
        );
        check(
          sameBytes(await file.readAsBytes(), original),
          'Failed backup preserves the original target',
        );
        check(!await backup.exists(), 'Owned incomplete backup is removed');
        check(
          await unrelated.readAsString() == 'keep',
          'Backup cleanup preserves an unrelated temporary',
        );
        check(
          (await directory.list().toList()).length == 2,
          'Failed backup leaks no owned artifact',
        );
        fail = false;
        await store.save(GravitaThemeMode.dark);
        final saved = await FileThemePreferencesStore(file).load();
        check(
          saved.mode == GravitaThemeMode.dark && saved.issue == null,
          'Healthy retry persists the new selection',
        );
        check(
          sameBytes(await backup.readAsBytes(), original),
          'Healthy retry preserves a complete original backup',
        );
        check(
          (await directory.list().toList()).length == 3,
          'Healthy retry leaves one backup and no owned temporary',
        );
        check(
          await unrelated.readAsString() == 'keep',
          'Healthy retry preserves an unrelated temporary',
        );
        check(writes == 2, 'Failed and healthy backup attempts both ran');
      });
    }
    await scenario('replacement failure retains completed invalid backup', (
      directory,
      file,
    ) async {
      final original = utf8.encode('{"unfinished":');
      await file.writeAsBytes(original);
      final backup = File('${file.path}.invalid');
      final unrelated = await File(
        '${file.path}.invalid.tmp.someone-else',
      ).writeAsString('keep');
      var fail = true;
      var replacements = 0;
      final store = FileThemePreferencesStore(
        file,
        replaceFile: (source, destination) async {
          replacements++;
          check(
            source.parent.path == file.parent.path &&
                destination == file.path &&
                sameBytes(await backup.readAsBytes(), original),
            'Complete original backup precedes final replacement',
          );
          if (fail) {
            throw FileSystemException('synthetic final replacement failure');
          }
          await source.rename(destination);
        },
      );
      await rejects(
        () => store.save(GravitaThemeMode.light),
        'Final replacement failure is surfaced after backup',
      );
      check(
        sameBytes(await file.readAsBytes(), original),
        'Final replacement failure preserves invalid original target',
      );
      check(
        sameBytes(await backup.readAsBytes(), original),
        'Final replacement failure retains the completed backup',
      );
      check(
        (await directory.list().toList()).length == 3,
        'Only the owned replacement temporary is removed',
      );
      check(
        await unrelated.readAsString() == 'keep',
        'Final failure preserves unrelated temporary',
      );
      fail = false;
      await store.save(GravitaThemeMode.dark);
      final saved = await FileThemePreferencesStore(file).load();
      check(
        saved.mode == GravitaThemeMode.dark && saved.issue == null,
        'Matching completed backup permits healthy final retry',
      );
      check(
        sameBytes(await backup.readAsBytes(), original),
        'Healthy final retry keeps the same complete backup',
      );
      check(
        (await directory.list().toList()).length == 3,
        'Healthy final retry leaks no replacement temporary',
      );
      check(
        await unrelated.readAsString() == 'keep',
        'Healthy final retry preserves unrelated temporary',
      );
      check(
        replacements == 2,
        'Failed and healthy final replacements both ran',
      );
    });
    await scenario('different existing backup blocks replacement', (
      directory,
      file,
    ) async {
      await file.writeAsString('current invalid');
      final backup = await File(
        '${file.path}.invalid',
      ).writeAsString('older invalid');
      var backupWrites = 0;
      final store = FileThemePreferencesStore(
        file,
        writeBackup: (target, bytes) async {
          backupWrites++;
          throw StateError('Existing backup must never enter the writer');
        },
      );
      await rejects(() => store.save(GravitaThemeMode.dark), 'Conflict');
      await rejects(() => store.save(GravitaThemeMode.light), 'Conflict retry');
      check(backupWrites == 0, 'Earlier backup never becomes owned');
      check(
        await file.readAsString() == 'current invalid',
        'Current invalid retained',
      );
      check(
        await backup.readAsString() == 'older invalid',
        'Earlier backup retained',
      );
      check(
        (await directory.list().toList()).length == 2,
        'Conflict creates no artifacts',
      );
    });
    await scenario('oversized target is not backed up or replaced', (
      directory,
      file,
    ) async {
      await file.writeAsBytes(oversized);
      final store = FileThemePreferencesStore(file);
      final loaded = await store.load();
      check(
        loaded.mode == GravitaThemeMode.system &&
            loaded.issue == ThemePreferencesLoadIssue.invalid,
        'Oversize fallback',
      );
      await rejects(
        () => store.save(GravitaThemeMode.light),
        'Oversize write refusal',
      );
      check(
        sameBytes(await file.readAsBytes(), oversized),
        'Oversize original retained',
      );
      check(
        !await File('${file.path}.invalid').exists(),
        'No unbounded backup',
      );
      check(
        (await directory.list().toList()).length == 1,
        'No oversized artifacts',
      );
    });
    await scenario('oversized earlier backup blocks replacement', (
      directory,
      file,
    ) async {
      await file.writeAsString('current invalid');
      final backup = await File('${file.path}.invalid').writeAsBytes(oversized);
      await rejects(
        () => FileThemePreferencesStore(file).save(GravitaThemeMode.light),
        'Backup bound',
      );
      check(
        await file.readAsString() == 'current invalid',
        'Invalid original retained',
      );
      check(
        sameBytes(await backup.readAsBytes(), oversized),
        'Large earlier backup untouched',
      );
      check(
        (await directory.list().toList()).length == 2,
        'No recovery growth',
      );
    });
    await scenario('backup directory is never replaced', (
      directory,
      file,
    ) async {
      await file.writeAsString('invalid');
      final backup = await Directory('${file.path}.invalid').create();
      final sentinel = await File('${backup.path}/keep').writeAsString('keep');
      await rejects(
        () => FileThemePreferencesStore(file).save(GravitaThemeMode.light),
        'Backup directory',
      );
      check(
        await file.readAsString() == 'invalid',
        'Original before directory retained',
      );
      check(
        await FileSystemEntity.type(backup.path, followLinks: false) ==
            FileSystemEntityType.directory,
        'Backup directory retained',
      );
      check(await sentinel.readAsString() == 'keep', 'Backup child retained');
      check(
        (await directory.list().toList()).length == 2,
        'No directory backup artifacts',
      );
    });
    await scenario('backup symlink is never followed or replaced', (
      directory,
      file,
    ) async {
      await file.writeAsString('invalid');
      final destination = await File(
        '${directory.path}/keep',
      ).writeAsString('keep');
      final backup = await Link(
        '${file.path}.invalid',
      ).create(destination.path);
      await rejects(
        () => FileThemePreferencesStore(file).save(GravitaThemeMode.light),
        'Backup link',
      );
      check(
        await file.readAsString() == 'invalid',
        'Original before link retained',
      );
      check(
        await FileSystemEntity.type(backup.path, followLinks: false) ==
            FileSystemEntityType.link,
        'Backup link retained',
      );
      check(
        await destination.readAsString() == 'keep',
        'Backup link destination retained',
      );
      check(
        (await directory.list().toList()).length == 3,
        'No link backup artifacts',
      );
    });
    await scenario('directory unavailable, queue recovers after removal', (
      directory,
      file,
    ) async {
      final target = await Directory(file.path).create();
      final sentinel = await File('${target.path}/keep').writeAsString('keep');
      final store = FileThemePreferencesStore(file);
      final loaded = await store.load();
      check(
        loaded.mode == GravitaThemeMode.system &&
            loaded.issue == ThemePreferencesLoadIssue.unavailable,
        'Directory unavailable',
      );
      await rejects(
        () => store.save(GravitaThemeMode.light),
        'Directory write refusal',
      );
      check(await sentinel.readAsString() == 'keep', 'Target child retained');
      check(
        await FileSystemEntity.type(file.path, followLinks: false) ==
            FileSystemEntityType.directory,
        'Target stays directory',
      );
      check(
        (await directory.list().toList()).length == 1,
        'Directory refusal has no artifacts',
      );
      await target.delete(recursive: true);
      await store.save(GravitaThemeMode.dark);
      final saved = await store.load();
      check(
        saved.mode == GravitaThemeMode.dark && saved.issue == null,
        'Failure did not poison queue',
      );
      check(
        (await directory.list().toList()).length == 1,
        'Recovery leaves only target',
      );
    });
    await scenario('target symlink is unavailable and preserved', (
      directory,
      file,
    ) async {
      final original = ThemePreferencesCodec.encode(GravitaThemeMode.light);
      final destination = await File(
        '${directory.path}/destination',
      ).writeAsBytes(original);
      await Link(file.path).create(destination.path);
      final store = FileThemePreferencesStore(file);
      final loaded = await store.load();
      check(
        loaded.mode == GravitaThemeMode.system &&
            loaded.issue == ThemePreferencesLoadIssue.unavailable,
        'Link unavailable',
      );
      await rejects(
        () => store.save(GravitaThemeMode.dark),
        'Target link refusal',
      );
      check(
        await FileSystemEntity.type(file.path, followLinks: false) ==
            FileSystemEntityType.link,
        'Target link retained',
      );
      check(
        sameBytes(await destination.readAsBytes(), original),
        'Destination bytes retained',
      );
      check(
        (await directory.list().toList()).length == 2,
        'No target link artifacts',
      );
    });
    await scenario('dangling link is unavailable, never materialized', (
      directory,
      file,
    ) async {
      final destination = File('${directory.path}/absent');
      await Link(file.path).create(destination.path);
      final store = FileThemePreferencesStore(file);
      final loaded = await store.load();
      check(
        loaded.mode == GravitaThemeMode.system &&
            loaded.issue == ThemePreferencesLoadIssue.unavailable,
        'Dangling link unavailable',
      );
      await rejects(
        () => store.save(GravitaThemeMode.dark),
        'Dangling refusal',
      );
      check(
        await FileSystemEntity.type(file.path, followLinks: false) ==
            FileSystemEntityType.link,
        'Dangling link retained',
      );
      check(!await destination.exists(), 'Missing destination not created');
      check(
        (await directory.list().toList()).length == 1,
        'No dangling artifacts',
      );
    });
    await scenario('injected read denial sanitizes load and blocks save', (
      directory,
      file,
    ) async {
      final original = ThemePreferencesCodec.encode(GravitaThemeMode.dark);
      await file.writeAsBytes(original);
      final store = FileThemePreferencesStore(_UnreadableFile(file.path));
      final loaded = await store.load();
      check(
        loaded.mode == GravitaThemeMode.system &&
            loaded.issue == ThemePreferencesLoadIssue.unavailable,
        'Read denial unavailable',
      );
      await rejects(
        () => store.save(GravitaThemeMode.light),
        'Unreadable source refusal',
      );
      check(
        sameBytes(await file.readAsBytes(), original),
        'Unreadable target retained',
      );
      check(
        (await directory.list().toList()).length == 1,
        'Read denial creates nothing',
      );
    });
    await scenario('real parent filesystem failure preserves blocker', (
      directory,
      file,
    ) async {
      await file.writeAsString('parent blocker');
      final child = File('${file.path}/theme.json');
      await rejects(
        () => FileThemePreferencesStore(child).save(GravitaThemeMode.light),
        'Non-directory parent',
      );
      check(
        await file.readAsString() == 'parent blocker',
        'Parent file retained',
      );
      check(!await child.exists(), 'Impossible child not created');
      check(
        (await directory.list().toList()).length == 1,
        'Parent failure creates no temp',
      );
    });
    await scenario('valid boundary is read then safely replaced', (
      directory,
      file,
    ) async {
      await file.writeAsBytes(boundary);
      final store = FileThemePreferencesStore(file);
      final loaded = await store.load();
      check(
        loaded.mode == GravitaThemeMode.dark && loaded.issue == null,
        '512-byte load',
      );
      check(
        sameBytes(await file.readAsBytes(), boundary),
        'Boundary read is unchanged',
      );
      await store.save(GravitaThemeMode.light);
      final saved = await FileThemePreferencesStore(file).load();
      check(
        saved.mode == GravitaThemeMode.light && saved.issue == null,
        'Boundary replacement',
      );
      check(
        (await directory.list().toList()).length == 1,
        'Valid boundary needs no backup',
      );
    });
    await scenario('failed replacement preserves target and cleans owned temp', (
      directory,
      file,
    ) async {
      final original = ThemePreferencesCodec.encode(GravitaThemeMode.system);
      await file.writeAsBytes(original);
      final unrelated = await File(
        '${file.path}.tmp.someone-else',
      ).writeAsString('keep');
      var fail = true;
      var calls = 0;
      final store = FileThemePreferencesStore(
        file,
        replaceFile: (source, destination) async {
          calls++;
          final next = ThemePreferencesCodec.decode(await source.readAsBytes());
          check(
            source.parent.path == file.parent.path &&
                destination == file.path &&
                source.path != file.path &&
                next ==
                    (calls == 1
                        ? GravitaThemeMode.light
                        : GravitaThemeMode.dark),
            'Replacement receives complete same-parent temporary and exact target',
          );
          if (fail) throw FileSystemException('synthetic replacement failure');
          await source.rename(destination);
        },
      );
      await rejects(
        () => store.save(GravitaThemeMode.light),
        'Injected replacement failure',
      );
      check(
        sameBytes(await file.readAsBytes(), original),
        'Previous target never deleted',
      );
      final loaded = await FileThemePreferencesStore(file).load();
      check(
        loaded.mode == GravitaThemeMode.system && loaded.issue == null,
        'Old target remains usable',
      );
      check(
        await unrelated.readAsString() == 'keep',
        'Unrelated temp preserved on failure',
      );
      check(
        (await directory.list().toList()).length == 2,
        'Owned failed temp cleaned',
      );
      fail = false;
      await store.save(GravitaThemeMode.dark);
      final saved = await FileThemePreferencesStore(file).load();
      check(
        saved.mode == GravitaThemeMode.dark && saved.issue == null,
        'Save recovers after failure',
      );
      check(
        (await directory.list().toList()).length == 2,
        'Successful temp also cleaned',
      );
      check(
        await unrelated.readAsString() == 'keep',
        'Unrelated temp preserved on success',
      );
      check(
        calls == 2,
        'Exactly failed and successful replacements reached seam',
      );
    });
    await scenario('rapid in-flight saves replace in invocation order', (
      directory,
      file,
    ) async {
      await file.writeAsBytes(
        ThemePreferencesCodec.encode(GravitaThemeMode.system),
      );
      final entered = Completer<void>();
      final release = Completer<void>();
      final received = <GravitaThemeMode>[];
      final priorTargets = <GravitaThemeMode>[];
      var active = 0;
      var maximumActive = 0;
      final store = FileThemePreferencesStore(
        file,
        replaceFile: (source, destination) async {
          active++;
          if (active > maximumActive) maximumActive = active;
          try {
            received.add(
              ThemePreferencesCodec.decode(await source.readAsBytes()),
            );
            priorTargets.add(
              ThemePreferencesCodec.decode(await file.readAsBytes()),
            );
            if (!entered.isCompleted) entered.complete();
            check(
              source.parent.path == file.parent.path &&
                  destination == file.path,
              'Queued replacement boundary',
            );
            if (received.length == 1) await release.future;
            await source.rename(destination);
          } finally {
            active--;
          }
        },
      );
      final completion = Future.wait<void>(<Future<void>>[
        store.save(GravitaThemeMode.light),
        store.save(GravitaThemeMode.dark),
        store.save(GravitaThemeMode.system),
        store.save(GravitaThemeMode.dark),
      ]);
      try {
        await entered.future.timeout(const Duration(seconds: 10));
        check(
          received.length == 1 && active == 1,
          'Later saves wait for first rename',
        );
        check(
          ThemePreferencesCodec.decode(await file.readAsBytes()) ==
              GravitaThemeMode.system,
          'Pending rename leaves old document',
        );
      } finally {
        release.complete();
        await completion;
      }
      check(maximumActive == 1, 'Replacement callbacks never overlap');
      check(
        received.map((mode) => mode.name).join(',') == 'light,dark,system,dark',
        'Source documents follow invocation order',
      );
      check(
        priorTargets.map((mode) => mode.name).join(',') ==
            'system,light,dark,system',
        'Each rename sees previously committed target',
      );
      final saved = await FileThemePreferencesStore(file).load();
      check(
        saved.mode == GravitaThemeMode.dark && saved.issue == null,
        'Final rapid choice persists',
      );
      check(
        (await directory.list().toList()).length == 1,
        'Rapid saves leak no temps',
      );
    });
  } finally {
    await root.delete(recursive: true);
  }
  check(!await root.exists(), 'Own temporary root removed');
  check(ioCases == expectedIoCases, 'IO scenario count drift');
  check(checks == expectedChecks - 1, 'Assertion count drift');
  stdout.writeln(
    jsonEncode(<String, Object>{
      'result': 'PASS',
      'ioCases': ioCases,
      'checks': checks,
    }),
  );
}

// Fault injection only at File.open; the path still names a real fixture file.
// Actual entity inspection, replacement guards and preservation remain production IO.
class _UnreadableFile implements File {
  _UnreadableFile(this.path);
  @override
  final String path;
  @override
  Directory get parent => File(path).parent;
  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async =>
      throw FileSystemException('synthetic fixture read denial');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
