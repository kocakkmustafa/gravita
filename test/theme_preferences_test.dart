import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/theme_preferences.dart';
import 'package:gravita/app/theme_preferences_io.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('bounded appearance codec', () {
    test('all three modes round trip without account or history fields', () {
      for (final mode in GravitaThemeMode.values) {
        final bytes = ThemePreferencesCodec.encode(mode);
        expect(bytes.length, lessThan(ThemePreferencesCodec.maximumBytes));
        expect(ThemePreferencesCodec.decode(bytes), mode);
        expect(jsonDecode(utf8.decode(bytes)), <String, Object>{
          'schemaVersion': 1,
          'themeMode': mode.name,
        });
      }
    });

    test(
      'invalid types, unknown versions/modes and invalid UTF-8 are rejected',
      () {
        for (final source in <String>[
          '',
          'null',
          '[]',
          '{}',
          '{',
          '{"schemaVersion":2,"themeMode":"dark"}',
          '{"schemaVersion":1.0,"themeMode":"dark"}',
          '{"schemaVersion":1,"themeMode":"Dark"}',
          '{"schemaVersion":1,"themeMode":false}',
          '{"schemaVersion":1,"themeMode":"dark","account":"synthetic"}',
        ]) {
          expect(
            () => ThemePreferencesCodec.decode(utf8.encode(source)),
            throwsFormatException,
            reason: source,
          );
        }
        expect(
          () => ThemePreferencesCodec.decode(<int>[0xff]),
          throwsFormatException,
        );
        expect(
          () => ThemePreferencesCodec.decode(
            List<int>.filled(ThemePreferencesCodec.maximumBytes + 1, 32),
          ),
          throwsFormatException,
        );
      },
    );
  });

  group('appearance file IO', () {
    late Directory directory;
    late File file;
    late FileThemePreferencesStore store;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('gravita-theme-test-');
      file = File('${directory.path}/appearance.json');
      store = FileThemePreferencesStore(file);
    });
    tearDown(() async => directory.delete(recursive: true));

    test('missing file uses system without creating any file', () async {
      final result = await store.load();
      expect(result.mode, GravitaThemeMode.system);
      expect(result.issue, isNull);
      expect(await directory.list().toList(), isEmpty);
    });

    test('saved choice is loaded by a fresh store', () async {
      await store.save(GravitaThemeMode.dark);
      final result = await FileThemePreferencesStore(file).load();
      expect(result.mode, GravitaThemeMode.dark);
      expect(result.issue, isNull);
    });

    test(
      'production loader resolves the app directory before exposing a saved mode',
      () async {
        final originalProvider = PathProviderPlatform.instance;
        addTearDown(() => PathProviderPlatform.instance = originalProvider);
        PathProviderPlatform.instance = _SupportDirectory(directory.path);
        final deviceFile = FileThemePreferencesStore.inDirectory(directory);
        await deviceFile.save(GravitaThemeMode.dark);
        final controller = await loadDeviceThemePreferences();
        addTearDown(controller.dispose);
        expect(controller.themeMode, ThemeMode.dark);
        await controller.setMode(GravitaThemeMode.light);
        expect((await deviceFile.load()).mode, GravitaThemeMode.light);
        expect(await Directory('${directory.path}/accounts').exists(), isFalse);
      },
    );

    test(
      'corrupt load preserves original bytes; explicit save keeps one backup',
      () async {
        final original = utf8.encode('{"unfinished":');
        await file.writeAsBytes(original);
        final result = await store.load();
        expect(result.mode, GravitaThemeMode.system);
        expect(result.issue, ThemePreferencesLoadIssue.invalid);
        expect(await file.readAsBytes(), original);
        expect(await File('${file.path}.invalid').exists(), isFalse);
        await store.save(GravitaThemeMode.light);
        expect(await File('${file.path}.invalid').readAsBytes(), original);
        expect((await store.load()).mode, GravitaThemeMode.light);
        await store.save(GravitaThemeMode.dark);
        expect(await File('${file.path}.invalid').readAsBytes(), original);
        expect((await directory.list().toList()).length, 2);
      },
    );

    test('a different existing backup is never overwritten', () async {
      await file.writeAsString('new invalid');
      final backup = File('${file.path}.invalid');
      await backup.writeAsString('older invalid');
      await expectLater(
        store.save(GravitaThemeMode.dark),
        throwsA(isA<FileSystemException>()),
      );
      expect(await file.readAsString(), 'new invalid');
      expect(await backup.readAsString(), 'older invalid');
    });

    test(
      'oversized input is neither read into memory nor copied on save',
      () async {
        final original = List<int>.filled(
          ThemePreferencesCodec.maximumBytes + 1,
          65,
        );
        await file.writeAsBytes(original);
        expect((await store.load()).issue, ThemePreferencesLoadIssue.invalid);
        await expectLater(
          store.save(GravitaThemeMode.dark),
          throwsFormatException,
        );
        expect(await file.readAsBytes(), original);
        expect((await directory.list().toList()).length, 1);
      },
    );

    test(
      'unavailable target falls back and failed write does not poison queue',
      () async {
        final targetDirectory = await Directory(file.path).create();
        final sentinel = await File(
          '${targetDirectory.path}/keep',
        ).writeAsString('keep');
        final result = await store.load();
        expect(result.mode, GravitaThemeMode.system);
        expect(result.issue, ThemePreferencesLoadIssue.unavailable);
        await expectLater(
          store.save(GravitaThemeMode.dark),
          throwsA(isA<FileSystemException>()),
        );
        expect(await sentinel.readAsString(), 'keep');
        await targetDirectory.delete(recursive: true);
        await store.save(GravitaThemeMode.light);
        expect((await store.load()).mode, GravitaThemeMode.light);
      },
    );

    test('symbolic target and its destination are preserved', () async {
      final real = File('${directory.path}/untouched.json');
      await real.writeAsBytes(
        ThemePreferencesCodec.encode(GravitaThemeMode.light),
      );
      await Link(file.path).create(real.path);
      expect((await store.load()).issue, ThemePreferencesLoadIssue.unavailable);
      await expectLater(
        store.save(GravitaThemeMode.dark),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        await FileSystemEntity.type(file.path, followLinks: false),
        FileSystemEntityType.link,
      );
      expect(
        ThemePreferencesCodec.decode(await real.readAsBytes()),
        GravitaThemeMode.light,
      );
    }, skip: Platform.isWindows);

    test(
      'rapid writes settle in invocation order and never clean unrelated temp files',
      () async {
        final unrelated = File('${file.path}.tmp.someone-else');
        await unrelated.writeAsString('keep');
        await Future.wait(<Future<void>>[
          store.save(GravitaThemeMode.light),
          store.save(GravitaThemeMode.system),
          store.save(GravitaThemeMode.dark),
        ]);
        expect((await store.load()).mode, GravitaThemeMode.dark);
        expect(await unrelated.readAsString(), 'keep');
        expect(
          (await directory.list().toList()).map((entry) => entry.path).toSet(),
          <String>{file.path, unrelated.path},
        );
      },
    );
  });

  group('appearance controller', () {
    test(
      'loaded mode is available synchronously before any widget is built',
      () {
        final controller = ThemePreferencesController(
          store: _ControlledStore(),
          initial: const ThemePreferencesLoadResult(
            mode: GravitaThemeMode.dark,
          ),
        );
        addTearDown(controller.dispose);
        expect(controller.mode, GravitaThemeMode.dark);
        expect(controller.themeMode, ThemeMode.dark);
        expect(controller.saving, isFalse);
      },
    );

    test(
      'pending choices apply immediately and stale failure cannot replace latest success',
      () async {
        final store = _ControlledStore();
        final controller = ThemePreferencesController(
          store: store,
          initial: const ThemePreferencesLoadResult(),
        );
        addTearDown(controller.dispose);
        final first = controller.setMode(GravitaThemeMode.dark);
        final last = controller.setMode(GravitaThemeMode.light);
        expect(controller.themeMode, ThemeMode.light);
        expect(controller.saving, isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(store.calls, <GravitaThemeMode>[GravitaThemeMode.dark]);
        store.pending
            .removeAt(0)
            .completeError(StateError('synthetic failure'));
        await first;
        await Future<void>.delayed(Duration.zero);
        expect(controller.saveFailed, isFalse);
        expect(controller.saving, isTrue);
        expect(store.calls.last, GravitaThemeMode.light);
        store.pending.removeAt(0).complete();
        await last;
        expect(controller.saving, isFalse);
        expect(controller.saveFailed, isFalse);
        expect(controller.themeMode, ThemeMode.light);
      },
    );

    test('failure stays visible and retry saves the selected mode', () async {
      final store = _ControlledStore();
      final controller = ThemePreferencesController(
        store: store,
        initial: const ThemePreferencesLoadResult(),
      );
      addTearDown(controller.dispose);
      final first = controller.setMode(GravitaThemeMode.dark);
      await Future<void>.delayed(Duration.zero);
      store.pending.removeAt(0).completeError(StateError('synthetic'));
      await first;
      expect(controller.saveFailed, isTrue);
      expect(controller.themeMode, ThemeMode.dark);
      final retry = controller.retrySave();
      await Future<void>.delayed(Duration.zero);
      store.pending.removeAt(0).complete();
      await retry;
      expect(store.calls, <GravitaThemeMode>[
        GravitaThemeMode.dark,
        GravitaThemeMode.dark,
      ]);
      expect(controller.saveFailed, isFalse);
    });

    test(
      'selecting system can recover a load error even though mode is unchanged',
      () async {
        final store = _ControlledStore();
        final controller = ThemePreferencesController(
          store: store,
          initial: const ThemePreferencesLoadResult(
            issue: ThemePreferencesLoadIssue.invalid,
          ),
        );
        addTearDown(controller.dispose);
        final write = controller.setMode(GravitaThemeMode.system);
        await Future<void>.delayed(Duration.zero);
        expect(store.calls.single, GravitaThemeMode.system);
        store.pending.removeAt(0).complete();
        await write;
        expect(controller.loadIssue, isNull);
      },
    );

    test(
      'disposing while saving lets IO settle without notifying dead listeners',
      () async {
        final store = _ControlledStore();
        final controller = ThemePreferencesController(
          store: store,
          initial: const ThemePreferencesLoadResult(),
        );
        final write = controller.setMode(GravitaThemeMode.dark);
        await Future<void>.delayed(Duration.zero);
        controller.dispose();
        store.pending.removeAt(0).complete();
        await write;
      },
    );
  });
}

class _ControlledStore implements ThemePreferencesStore {
  final calls = <GravitaThemeMode>[];
  final pending = <Completer<void>>[];

  @override
  Future<ThemePreferencesLoadResult> load() async =>
      const ThemePreferencesLoadResult();

  @override
  Future<void> save(GravitaThemeMode mode) {
    calls.add(mode);
    final hold = Completer<void>();
    pending.add(hold);
    return hold.future;
  }
}

class _SupportDirectory extends PathProviderPlatform {
  _SupportDirectory(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}
