import 'dart:async';
import 'dart:io';

import 'language_preferences_codec.dart';

/// IO only. This store never opens account, programme or history files.
class FileLanguagePreferencesStore implements LanguagePreferencesStore {
  FileLanguagePreferencesStore(
    this.file, {
    Future<void> Function(File source, String destination)? replaceFile,
    Future<void> Function(File backup, List<int> bytes)? writeBackup,
  }) : _replaceFile = replaceFile ?? _rename,
       _writeBackup = writeBackup ?? _writeBackupFlushed;

  factory FileLanguagePreferencesStore.inDirectory(Directory directory) =>
      FileLanguagePreferencesStore(
        File('${directory.path}/gravita.language-preferences.v1.json'),
      );

  final File file;
  // A narrow replacement seam makes failure/preservation testable without
  // changing file permissions or relying on a platform-specific rename error.
  final Future<void> Function(File source, String destination) _replaceFile;
  // Production completes the bounded backup write and flush before replacement.
  final Future<void> Function(File backup, List<int> bytes) _writeBackup;
  Future<void> _writes = Future<void>.value();
  static int _temporarySequence = 0;

  @override
  Future<LanguagePreferencesLoadResult> load() async {
    try {
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        return const LanguagePreferencesLoadResult();
      }
      if (type != FileSystemEntityType.file) {
        return const LanguagePreferencesLoadResult(
          issue: LanguagePreferencesLoadIssue.unavailable,
        );
      }
      return LanguagePreferencesLoadResult(
        selectedTag: LanguagePreferencesCodec.decode(await _readBounded(file)),
      );
    } on FormatException {
      return const LanguagePreferencesLoadResult(
        issue: LanguagePreferencesLoadIssue.invalid,
      );
    } on Object {
      return const LanguagePreferencesLoadResult(
        issue: LanguagePreferencesLoadIssue.unavailable,
      );
    }
  }

  static Future<List<int>> _readBounded(File source) async {
    final handle = await source.open();
    try {
      if (await handle.length() > LanguagePreferencesCodec.maximumBytes) {
        throw const FormatException('Language document is too large.');
      }
      final bytes = await handle.read(
        LanguagePreferencesCodec.maximumBytes + 1,
      );
      if (bytes.length > LanguagePreferencesCodec.maximumBytes) {
        throw const FormatException('Language document is too large.');
      }
      return bytes;
    } finally {
      await handle.close();
    }
  }

  @override
  Future<void> save(String? selectedTag) {
    // Validate before touching the target or preserving a damaged document.
    final bytes = LanguagePreferencesCodec.encode(selectedTag);
    final write = _writes.then((_) => _replace(bytes));
    // A failed replacement must not block later explicit attempts.
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return write;
  }

  Future<void> _replace(List<int> bytes) async {
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
      await temporary.writeAsBytes(bytes, flush: true);
      // Same-parent replacement never deletes the previous target first.
      // Platforms that cannot replace atomically leave the old document intact.
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
      throw FileSystemException('Language target is not a regular file.');
    }
    // Oversized and unreadable input cannot trigger an unbounded backup.
    final bytes = await _readBounded(file);
    try {
      LanguagePreferencesCodec.decode(bytes);
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
          throw FileSystemException('An earlier language backup is preserved.');
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
