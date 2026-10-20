import 'dart:async';
import 'dart:io';

import 'theme_preferences_codec.dart';

/// IO only; no Flutter, account registry, or history directory dependency.
class FileThemePreferencesStore implements ThemePreferencesStore {
  FileThemePreferencesStore(
    this.file, {
    Future<void> Function(File source, String destination)? replaceFile,
    Future<void> Function(File backup, List<int> bytes)? writeBackup,
  }) : _replaceFile = replaceFile ?? _rename,
       _writeBackup = writeBackup ?? _writeBackupFlushed;

  factory FileThemePreferencesStore.inDirectory(Directory directory) =>
      FileThemePreferencesStore(
        File('${directory.path}/gravita.theme-preferences.v1.json'),
      );

  final File file;
  // Test the failure boundary without changing filesystem permissions or
  // depending on platform-specific rename errors. Production uses rename.
  final Future<void> Function(File source, String destination) _replaceFile;
  // Production completes the bounded backup write and flush before replacement.
  final Future<void> Function(File backup, List<int> bytes) _writeBackup;
  Future<void> _writes = Future<void>.value();
  static int _temporarySequence = 0;

  @override
  Future<ThemePreferencesLoadResult> load() async {
    try {
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        return const ThemePreferencesLoadResult();
      }
      if (type != FileSystemEntityType.file) {
        return const ThemePreferencesLoadResult(
          issue: ThemePreferencesLoadIssue.unavailable,
        );
      }
      return ThemePreferencesLoadResult(
        mode: ThemePreferencesCodec.decode(await _readBounded(file)),
      );
    } on FormatException {
      return const ThemePreferencesLoadResult(
        issue: ThemePreferencesLoadIssue.invalid,
      );
    } on Object {
      return const ThemePreferencesLoadResult(
        issue: ThemePreferencesLoadIssue.unavailable,
      );
    }
  }

  static Future<List<int>> _readBounded(File source) async {
    final handle = await source.open();
    try {
      if (await handle.length() > ThemePreferencesCodec.maximumBytes) {
        throw const FormatException('Appearance document is too large.');
      }
      final bytes = await handle.read(ThemePreferencesCodec.maximumBytes + 1);
      if (bytes.length > ThemePreferencesCodec.maximumBytes) {
        throw const FormatException('Appearance document is too large.');
      }
      return bytes;
    } finally {
      await handle.close();
    }
  }

  @override
  Future<void> save(GravitaThemeMode mode) {
    // A failure does not poison the queue. Invocation order determines the
    // final file even when a user changes selection while a write is pending.
    final write = _writes.then((_) => _replace(mode));
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return write;
  }

  Future<void> _replace(GravitaThemeMode mode) async {
    await file.parent.create(recursive: true);
    await _preserveInvalidDocument();
    final temporary = File(
      '${file.path}.tmp.$pid.${DateTime.now().microsecondsSinceEpoch}.'
      '${_temporarySequence++}',
    );
    var ownsTemporary = false;
    try {
      await temporary.create(exclusive: true);
      ownsTemporary = true;
      await temporary.writeAsBytes(
        ThemePreferencesCodec.encode(mode),
        flush: true,
      );
      // Same-parent rename replaces the complete document; never delete the
      // previous target first. Unsupported replacement leaves the old file.
      await _replaceFile(temporary, file.path);
      ownsTemporary = false;
    } finally {
      if (ownsTemporary) {
        try {
          await temporary.delete();
        } on Object {
          // Only this operation's exact temporary path is eligible for cleanup.
        }
      }
    }
  }

  static Future<void> _rename(File source, String destination) async {
    await source.rename(destination);
  }

  static Future<void> _writeBackupFlushed(File backup, List<int> bytes) async {
    await backup.writeAsBytes(bytes, flush: true);
  }

  Future<void> _preserveInvalidDocument() async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.file) {
      throw FileSystemException('Appearance target is not a regular file.');
    }
    // An unreadable or oversized document is never replaced. Recovery cannot
    // cause an unbounded read/copy or grow a sequence of backup files.
    final bytes = await _readBounded(file);
    try {
      ThemePreferencesCodec.decode(bytes);
      return;
    } on FormatException {
      final backup = File('${file.path}.invalid');
      final backupType = await FileSystemEntity.type(
        backup.path,
        followLinks: false,
      );
      if (backupType != FileSystemEntityType.notFound) {
        if (backupType != FileSystemEntityType.file ||
            !_sameBytes(bytes, await _readBounded(backup))) {
          throw FileSystemException(
            'An earlier appearance backup is preserved.',
          );
        }
        return;
      }
      // Ownership starts only after exclusive create succeeds. A failed write
      // or flush must not leave our incomplete backup blocking a healthy retry.
      // Existing backups never enter this cleanup path.
      var ownsIncompleteBackup = false;
      try {
        await backup.create(exclusive: true);
        ownsIncompleteBackup = true;
        await _writeBackup(backup, bytes);
        ownsIncompleteBackup = false;
      } finally {
        if (ownsIncompleteBackup) {
          try {
            await backup.delete();
          } on Object {
            // Cleanup can also fail; retain the original target in that case.
          }
        }
      }
    }
  }

  static bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
