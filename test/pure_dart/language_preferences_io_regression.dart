import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gravita/app/language_preferences_codec.dart';
import 'package:gravita/app/language_preferences_io.dart';
import 'package:gravita/app/localization/locale_catalog.dart'
    show supportedLocaleTags;

// Standalone pure Dart contracts, intended for the existing Dart runner.
// This file does not import Flutter or claim a widget/native acceptance.
Future<void> main() async {
  final expectedIoCases = Platform.isWindows ? 14 : 15;
  final expectedChecks = Platform.isWindows ? 190 : 194;
  var checks = 0;
  var ioCases = 0;
  void check(bool condition, String label) {
    if (!condition) throw StateError(label);
    checks++;
  }

  void rejectsFormat(void Function() action, String label) {
    var rejected = false;
    try {
      action();
    } on FormatException {
      rejected = true;
    }
    check(rejected, label);
  }

  Future<void> rejects(FutureOr<void> Function() action, String label) async {
    var rejected = false;
    try {
      await action();
    } on Object {
      rejected = true;
    }
    check(rejected, label);
  }

  bool sameBytes(List<int> left, List<int> right) =>
      left.length == right.length &&
      List<int>.generate(
        left.length,
        (index) => index,
      ).every((index) => left[index] == right[index]);
  Future<void> scenario(
    Future<void> Function(Directory directory, File file) run,
  ) async {
    final directory = await Directory.systemTemp.createTemp(
      'gravita-language-test-',
    );
    try {
      await run(directory, File('${directory.path}/language.json'));
      ioCases++;
    } finally {
      await directory.delete(recursive: true);
    }
  }

  for (final tag in <String?>[null, ...supportedLocaleTags]) {
    final bytes = LanguagePreferencesCodec.encode(tag);
    check(
      bytes.length <= LanguagePreferencesCodec.maximumBytes,
      'Bounded encoding $tag',
    );
    check(
      LanguagePreferencesCodec.decode(bytes) == tag,
      'Exact selection roundtrip $tag',
    );
    final document = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    check(
      document.length == 2 &&
          document['schemaVersion'] == 1 &&
          document.containsKey('localeTag') &&
          document['localeTag'] == tag,
      'Only version and display locale are persisted $tag',
    );
  }
  for (final source in <String>[
    '',
    'null',
    '[]',
    '{}',
    '{',
    '{"schemaVersion":2,"localeTag":"en"}',
    '{"schemaVersion":1.0,"localeTag":"en"}',
    '{"schemaVersion":1,"localeTag":false}',
    '{"schemaVersion":1,"localeTag":[]}',
    '{"schemaVersion":1,"unknown":null}',
    '{"schemaVersion":1,"localeTag":"en","account":"synthetic"}',
    '{"schemaVersion":1,"localeTag":"system"}',
    '{"schemaVersion":1,"localeTag":"EN"}',
    '{"schemaVersion":1,"localeTag":"en-US"}',
    '{"schemaVersion":1,"localeTag":"es"}',
    '{"schemaVersion":1,"localeTag":"pt_BR"}',
    '{"schemaVersion":1,"localeTag":"zh-Hant"}',
    '{"schemaVersion":1,"localeTag":"unsupported"}',
  ]) {
    rejectsFormat(
      () => LanguagePreferencesCodec.decode(utf8.encode(source)),
      source,
    );
  }
  rejectsFormat(
    () => LanguagePreferencesCodec.decode(<int>[0xff]),
    'Invalid UTF-8',
  );
  rejectsFormat(
    () => LanguagePreferencesCodec.decode(
      List<int>.filled(LanguagePreferencesCodec.maximumBytes + 1, 32),
    ),
    'Oversized document',
  );
  for (final alias in <String>['EN', 'en-US', 'es', 'pt_BR', 'zh-Hant', '']) {
    rejectsFormat(
      () => LanguagePreferencesCodec.encode(alias),
      'Encode rejects $alias',
    );
  }

  await scenario((directory, file) async {
    final result = await FileLanguagePreferencesStore(file).load();
    check(
      result.selectedTag == null && result.issue == null,
      'Missing uses system',
    );
    check(
      (await directory.list().toList()).isEmpty,
      'Loading does not create files',
    );
  });
  await scenario((directory, file) async {
    final store = FileLanguagePreferencesStore(file);
    for (final tag in <String?>[...supportedLocaleTags, null]) {
      await store.save(tag);
      final result = await FileLanguagePreferencesStore(file).load();
      check(
        result.selectedTag == tag && result.issue == null,
        'Fresh store reload $tag',
      );
    }
    check(
      (await directory.list().toList()).length == 1,
      'System clears preference without extra files',
    );
  });
  for (final original in <List<int>>[
    utf8.encode('{"unfinished":'),
    <int>[0xff],
  ]) {
    await scenario((directory, file) async {
      await file.writeAsBytes(original);
      final store = FileLanguagePreferencesStore(file);
      final loaded = await store.load();
      check(
        loaded.selectedTag == null &&
            loaded.issue == LanguagePreferencesLoadIssue.invalid,
        'Corrupt input falls back',
      );
      check(
        sameBytes(await file.readAsBytes(), original),
        'Corrupt load preserves bytes',
      );
      final backup = File('${file.path}.invalid');
      check(!await backup.exists(), 'Read never creates a backup');
      await store.save('tr');
      check(
        sameBytes(await backup.readAsBytes(), original),
        'Explicit recovery keeps original backup',
      );
      await store.save('ja');
      check(
        (await store.load()).selectedTag == 'ja',
        'Later valid choice persists',
      );
      check(
        sameBytes(await backup.readAsBytes(), original),
        'Backup is never overwritten',
      );
      check(
        (await directory.list().toList()).length == 2,
        'One backup with no leaked temps',
      );
    });
  }
  final backupFailureOriginal = utf8.encode('{"unfinished":');
  for (final writtenBytes in <int>[0, 4, backupFailureOriginal.length]) {
    await scenario((directory, file) async {
      final original = backupFailureOriginal;
      await file.writeAsBytes(original);
      final backup = File('${file.path}.invalid');
      final unrelated = await File(
        '${file.path}.invalid.tmp.someone-else',
      ).writeAsString('keep');
      var fail = true;
      var writes = 0;
      final store = FileLanguagePreferencesStore(
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
        () => store.save('tr'),
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
      await store.save('ja');
      final saved = await FileLanguagePreferencesStore(file).load();
      check(
        saved.selectedTag == 'ja' && saved.issue == null,
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
  await scenario((directory, file) async {
    final original = utf8.encode('{"unfinished":');
    await file.writeAsBytes(original);
    final backup = File('${file.path}.invalid');
    final unrelated = await File(
      '${file.path}.invalid.tmp.someone-else',
    ).writeAsString('keep');
    var fail = true;
    var replacements = 0;
    final store = FileLanguagePreferencesStore(
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
      () => store.save('tr'),
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
    await store.save('ja');
    final saved = await FileLanguagePreferencesStore(file).load();
    check(
      saved.selectedTag == 'ja' && saved.issue == null,
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
    check(replacements == 2, 'Failed and healthy final replacements both ran');
  });
  await scenario((directory, file) async {
    await file.writeAsString('current invalid');
    final backup = await File(
      '${file.path}.invalid',
    ).writeAsString('older invalid');
    var backupWrites = 0;
    final store = FileLanguagePreferencesStore(
      file,
      writeBackup: (target, bytes) async {
        backupWrites++;
        throw StateError('Existing backup must never enter the writer');
      },
    );
    await rejects(
      () => store.save('en'),
      'Different backup blocks destructive recovery',
    );
    await rejects(
      () => store.save('tr'),
      'Different backup still blocks retry',
    );
    check(backupWrites == 0, 'Earlier backup never becomes owned');
    check(
      await file.readAsString() == 'current invalid',
      'Invalid target remains after failed recovery',
    );
    check(
      await backup.readAsString() == 'older invalid',
      'Earlier backup remains',
    );
  });
  await scenario((directory, file) async {
    final original = List<int>.filled(
      LanguagePreferencesCodec.maximumBytes + 1,
      65,
    );
    await file.writeAsBytes(original);
    final store = FileLanguagePreferencesStore(file);
    check(
      (await store.load()).issue == LanguagePreferencesLoadIssue.invalid,
      'Oversized input falls back',
    );
    await rejects(
      () => store.save('en'),
      'Oversized input cannot trigger backup',
    );
    check(
      sameBytes(await file.readAsBytes(), original),
      'Oversized original retained',
    );
    check(
      (await directory.list().toList()).length == 1,
      'No oversized backup or temp',
    );
  });
  await scenario((directory, file) async {
    await Directory(file.path).create();
    final sentinel = await File('${file.path}/keep').writeAsString('keep');
    final store = FileLanguagePreferencesStore(file);
    check(
      (await store.load()).issue == LanguagePreferencesLoadIssue.unavailable,
      'Directory is unavailable',
    );
    await rejects(() => store.save('en'), 'Directory cannot be replaced');
    check(
      await sentinel.readAsString() == 'keep',
      'Directory content retained',
    );
    await Directory(file.path).delete(recursive: true);
    await store.save('fr');
    check(
      (await store.load()).selectedTag == 'fr',
      'Write failure does not poison queue',
    );
  });
  await scenario((directory, file) async {
    final bytes = LanguagePreferencesCodec.encode('de');
    await file.writeAsBytes(bytes);
    final store = FileLanguagePreferencesStore(_UnreadableFile(file.path));
    final loaded = await store.load();
    check(
      loaded.selectedTag == null &&
          loaded.issue == LanguagePreferencesLoadIssue.unavailable,
      'Read exception becomes sanitized fallback',
    );
    await rejects(
      () => store.save('tr'),
      'Unreadable source cannot be replaced',
    );
    check(
      sameBytes(await file.readAsBytes(), bytes),
      'Read-failed target retained',
    );
  });
  if (!Platform.isWindows) {
    await scenario((directory, file) async {
      final destination = await File(
        '${directory.path}/untouched.json',
      ).writeAsBytes(LanguagePreferencesCodec.encode('en'));
      await Link(file.path).create(destination.path);
      final store = FileLanguagePreferencesStore(file);
      check(
        (await store.load()).issue == LanguagePreferencesLoadIssue.unavailable,
        'Symlink is unavailable',
      );
      await rejects(() => store.save('ar'), 'Symlink cannot be replaced');
      check(
        await FileSystemEntity.type(file.path, followLinks: false) ==
            FileSystemEntityType.link,
        'Symlink retained',
      );
      check(
        LanguagePreferencesCodec.decode(await destination.readAsBytes()) ==
            'en',
        'Symlink destination retained',
      );
    });
  }
  await scenario((directory, file) async {
    final original = LanguagePreferencesCodec.encode('en');
    await file.writeAsBytes(original);
    final unrelated = await File(
      '${file.path}.tmp.someone-else',
    ).writeAsString('keep');
    var fail = true;
    final store = FileLanguagePreferencesStore(
      file,
      replaceFile: (source, destination) async {
        check(
          source.parent.path == file.parent.path && destination == file.path,
          'Replacement uses same parent and exact target',
        );
        if (fail) throw FileSystemException('synthetic replacement failure');
        await source.rename(destination);
      },
    );
    await rejects(() => store.save('de'), 'Replacement failure is surfaced');
    check(
      sameBytes(await file.readAsBytes(), original),
      'Failed replace preserves previous target',
    );
    check(
      await unrelated.readAsString() == 'keep',
      'Failure cleanup preserves unrelated temp',
    );
    check(
      (await directory.list().toList()).length == 2,
      'Only owned failed temp is removed',
    );
    fail = false;
    await Future.wait(<Future<void>>[
      store.save('ar'),
      store.save(null),
      store.save('ja'),
      store.save('zh-Hans'),
    ]);
    check(
      (await store.load()).selectedTag == 'zh-Hans',
      'Rapid choices settle in invocation order',
    );
    check(
      (await directory.list().toList()).length == 2,
      'Successful queue leaks no temps',
    );
    check(
      await unrelated.readAsString() == 'keep',
      'Success preserves unrelated temp',
    );
  });
  await scenario((directory, file) async {
    final original = LanguagePreferencesCodec.encode('en');
    await file.writeAsBytes(original);
    await rejects(
      () => FileLanguagePreferencesStore(file).save('en-US'),
      'Alias rejected before IO',
    );
    check(
      sameBytes(await file.readAsBytes(), original),
      'Invalid choice leaves valid target unchanged',
    );
    check(
      (await directory.list().toList()).length == 1,
      'Invalid choice creates no temp or backup',
    );
  });
  check(ioCases == expectedIoCases, 'IO scenario count drift');
  check(checks == expectedChecks - 1, 'Assertion count drift');
  print(
    jsonEncode(<String, Object>{
      'checks': checks,
      'ioCases': ioCases,
      'result': 'PASS',
    }),
  );
}

class _UnreadableFile implements File {
  _UnreadableFile(this.path);
  @override
  final String path;
  @override
  Directory get parent => File(path).parent;
  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async =>
      throw FileSystemException('synthetic unreadable preference');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
