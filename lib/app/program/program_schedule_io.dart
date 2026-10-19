import 'dart:convert';
import 'dart:io';

/// A program's persisted dates and self-reported completion. A missing
/// signature identifies a readable legacy schedule; it is never auto-bound.
final class ProgramSchedule {
  const ProgramSchedule({
    required this.dates,
    required this.rpeByDayIndex,
    this.programSignature,
  });

  final List<DateTime> dates;
  final Map<int, int> rpeByDayIndex;
  final String? programSignature;

  ProgramSchedule withRpe(int dayIndex, int rpe) => ProgramSchedule(
    dates: dates,
    rpeByDayIndex: <int, int>{...rpeByDayIndex, dayIndex: rpe},
    programSignature: programSignature,
  );

  ProgramSchedule withDates(List<DateTime> newDates) => ProgramSchedule(
    dates: newDates,
    rpeByDayIndex: rpeByDayIndex,
    programSignature: programSignature,
  );
}

enum ProgramScheduleFailure { corrupt, unavailable, missing, signatureMismatch }

final class ProgramScheduleException implements Exception {
  const ProgramScheduleException(this.failure, this.message);

  final ProgramScheduleFailure failure;
  final String message;

  @override
  String toString() => 'ProgramScheduleException(${failure.name}): $message';
}

/// Limits bound parsing and temporary writes. They exceed the current 16–48
/// sessions; they are storage limits, not a claim of supported program size.
final class ProgramScheduleCodec {
  static const int maxBytes = 128 * 1024;
  static const int maxDates = 1000;
  static const int maxRpeEntries = 1000;

  static ProgramSchedule decode(List<int> bytes) {
    if (bytes.length > maxBytes) {
      throw const FormatException('Schedule exceeds its byte limit');
    }
    final Object? raw = jsonDecode(utf8.decode(bytes));
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Expected a schedule object');
    }
    const fields = <String>{
      'schemaVersion',
      'dates',
      'rpeByDayIndex',
      'programSignature',
    };
    if (raw.keys.any((key) => !fields.contains(key))) {
      // Preserve unknown data rather than dropping it in a later encode.
      throw const FormatException('Unsupported schedule fields');
    }
    // The original writer used schema 1; older fixtures may omit this field.
    // Unknown versions are preserved on disk and rejected rather than rewritten.
    if (raw.containsKey('schemaVersion') &&
        (raw['schemaVersion'] is! int || raw['schemaVersion'] != 1)) {
      throw const FormatException('Unsupported schedule schema');
    }
    final dates = raw['dates'];
    final rpe = raw['rpeByDayIndex'];
    final signature = raw['programSignature'];
    if (dates is! List<dynamic> ||
        dates.isEmpty ||
        dates.length > maxDates ||
        rpe is! Map<String, dynamic> ||
        rpe.length > maxRpeEntries ||
        (signature != null && (signature is! String || signature.isEmpty))) {
      throw const FormatException('Invalid schedule fields');
    }
    final parsedDates = <DateTime>[];
    for (final value in dates) {
      if (value is! String) {
        throw const FormatException('Invalid schedule date');
      }
      parsedDates.add(_parseDate(value));
    }
    final parsedRpe = <int, int>{};
    for (final entry in rpe.entries) {
      // Canonical keys avoid 0 and 00 silently collapsing to the same day.
      if (!RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(entry.key)) {
        throw const FormatException('Invalid schedule day index');
      }
      final index = int.tryParse(entry.key);
      final value = entry.value;
      if (index == null ||
          index >= parsedDates.length ||
          value is! int ||
          value < 1 ||
          value > 10) {
        throw const FormatException('Invalid schedule RPE');
      }
      parsedRpe[index] = value;
    }
    return ProgramSchedule(
      dates: List<DateTime>.unmodifiable(parsedDates),
      rpeByDayIndex: Map<int, int>.unmodifiable(parsedRpe),
      programSignature: signature as String?,
    );
  }

  static List<int> encode(ProgramSchedule schedule) {
    if (schedule.dates.isEmpty ||
        schedule.dates.length > maxDates ||
        schedule.rpeByDayIndex.length > maxRpeEntries ||
        schedule.programSignature == '') {
      throw ArgumentError('Invalid schedule fields');
    }
    for (final entry in schedule.rpeByDayIndex.entries) {
      if (entry.key < 0 ||
          entry.key >= schedule.dates.length ||
          entry.value < 1 ||
          entry.value > 10) {
        throw ArgumentError('Invalid schedule RPE');
      }
    }
    final bytes = utf8.encode(
      jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'dates': schedule.dates.map((d) => d.toIso8601String()).toList(),
        'rpeByDayIndex': schedule.rpeByDayIndex.map(
          (index, value) => MapEntry<String, int>(index.toString(), value),
        ),
        if (schedule.programSignature != null)
          'programSignature': schedule.programSignature,
      }),
    );
    if (bytes.length > maxBytes) {
      throw ArgumentError('Schedule exceeds its byte limit');
    }
    // Match reader validation before touching the target or any temporary file.
    decode(bytes);
    return bytes;
  }

  static DateTime _parseDate(String text) {
    final match = RegExp(
      r'^([+-]?[0-9]{4,6})-([0-9]{2})-([0-9]{2})'
      r'(?:[Tt ]([0-9]{2}):([0-9]{2}):([0-9]{2})'
      r'(?:\.([0-9]{1,6}))?([Zz]|[+-][0-9]{2}:?[0-9]{2})?)?$',
    ).firstMatch(text);
    if (match == null) throw const FormatException('Invalid schedule date');
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final hour = int.parse(match[4] ?? '0');
    final minute = int.parse(match[5] ?? '0');
    final second = int.parse(match[6] ?? '0');
    final DateTime civil;
    try {
      civil = DateTime.utc(year, month, day, hour, minute, second);
    } on ArgumentError {
      throw const FormatException('Invalid schedule date components');
    }
    // DateTime.parse normalizes e.g. February 30; that must remain corrupt
    // rather than silently changing a user's existing calendar.
    if (civil.year != year ||
        civil.month != month ||
        civil.day != day ||
        civil.hour != hour ||
        civil.minute != minute ||
        civil.second != second) {
      throw const FormatException('Invalid schedule date components');
    }
    final zone = match[8];
    if (zone != null && zone.length > 1) {
      final offset = zone.substring(1).replaceAll(':', '');
      if (int.parse(offset.substring(0, 2)) > 23 ||
          int.parse(offset.substring(2)) > 59) {
        throw const FormatException('Invalid schedule time-zone offset');
      }
    }
    final parsed = DateTime.tryParse(text);
    if (parsed == null) throw const FormatException('Invalid schedule date');
    // No sorting, deduplication, day conversion or legacy rewrite occurs here.
    return parsed;
  }
}

typedef ProgramScheduleSerialize =
    Future<T> Function<T>(Future<T> Function() operation);
typedef ProgramScheduleTemporaryWrite =
    Future<void> Function(File temporary, List<int> bytes);
typedef ProgramScheduleCommit =
    Future<void> Function(File temporary, File target);

/// The production persistence pipeline. The host injects its existing owner
/// lease/queue, rather than introducing a second lock or a copied test model.
/// Optional file-operation hooks allow faults before atomic replacement to be
/// characterized in pure Dart; production uses real flushed files and rename.
final class ProgramScheduleIo {
  ProgramScheduleIo(
    this.file, {
    required ProgramScheduleSerialize serialize,
    void Function()? checkCurrent,
    ProgramScheduleTemporaryWrite? writeTemporary,
    ProgramScheduleCommit? commit,
  }) : _serialize = serialize,
       _checkCurrent = checkCurrent ?? _noCheck,
       _writeTemporary = writeTemporary ?? _writeFlushed,
       _commit = commit ?? _rename;

  final File file;
  final ProgramScheduleSerialize _serialize;
  final void Function() _checkCurrent;
  final ProgramScheduleTemporaryWrite _writeTemporary;
  final ProgramScheduleCommit _commit;

  static void _noCheck() {}
  static Future<void> _writeFlushed(File file, List<int> bytes) async {
    await file.writeAsBytes(bytes, flush: true);
  }

  static Future<void> _rename(File temporary, File target) async {
    await temporary.rename(target.path);
  }

  Future<ProgramSchedule?> read() => _serialize(_readCurrent);

  /// Explicit full replacement retained for callers such as fixtures. Product
  /// create/update paths below never silently replace an existing legacy plan.
  Future<void> write(ProgramSchedule schedule) =>
      _serialize(() => _writeCurrent(schedule));

  Future<ProgramSchedule> createIfMissing(ProgramSchedule Function() factory) =>
      _serialize(() async {
        final existing = await _readCurrent();
        if (existing != null) return existing;
        final created = factory();
        if (created.programSignature == null ||
            created.programSignature!.isEmpty) {
          throw ArgumentError('New schedules require a program signature');
        }
        await _writeCurrent(created);
        return created;
      });

  Future<ProgramSchedule> update({
    required String expectedSignature,
    required ProgramSchedule Function(ProgramSchedule current) transform,
  }) => _serialize(() async {
    if (expectedSignature.isEmpty) {
      throw ArgumentError('Expected program signature must not be empty');
    }
    final current = await _readCurrent();
    if (current == null) {
      throw const ProgramScheduleException(
        ProgramScheduleFailure.missing,
        'No schedule exists to update',
      );
    }
    if (current.programSignature == null ||
        current.programSignature != expectedSignature) {
      throw const ProgramScheduleException(
        ProgramScheduleFailure.signatureMismatch,
        'Existing schedule is not bound to this program',
      );
    }
    final updated = transform(current);
    if (updated.programSignature != expectedSignature) {
      throw const ProgramScheduleException(
        ProgramScheduleFailure.signatureMismatch,
        'An update cannot change its program binding',
      );
    }
    await _writeCurrent(updated);
    return updated;
  });

  Future<ProgramSchedule?> _readCurrent() async {
    _checkCurrent();
    try {
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      _checkCurrent();
      if (type != FileSystemEntityType.file &&
          type != FileSystemEntityType.notFound) {
        throw const ProgramScheduleException(
          ProgramScheduleFailure.unavailable,
          'Schedule path is not a regular file',
        );
      }
      // Attempt even when type() reports notFound: an actual open distinguishes
      // ENOENT from a denied/unavailable path instead of guessing "missing".
      final bytes = <int>[];
      await for (final chunk in file.openRead(
        0,
        ProgramScheduleCodec.maxBytes + 1,
      )) {
        _checkCurrent();
        bytes.addAll(chunk);
      }
      _checkCurrent();
      try {
        return ProgramScheduleCodec.decode(bytes);
      } on FormatException {
        throw const ProgramScheduleException(
          ProgramScheduleFailure.corrupt,
          'Schedule contents cannot be read safely',
        );
      }
    } on FileSystemException catch (error) {
      _checkCurrent();
      if (error.osError?.errorCode == 2 ||
          (Platform.isWindows && error.osError?.errorCode == 3)) {
        return null;
      }
      throw const ProgramScheduleException(
        ProgramScheduleFailure.unavailable,
        'Schedule could not be read',
      );
    }
  }

  Future<void> _writeCurrent(ProgramSchedule schedule) async {
    // Encode/validate completely before creating anything or touching target.
    final bytes = ProgramScheduleCodec.encode(schedule);
    _checkCurrent();
    Directory? temporaryDirectory;
    try {
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      _checkCurrent();
      if (type != FileSystemEntityType.file &&
          type != FileSystemEntityType.notFound) {
        throw const ProgramScheduleException(
          ProgramScheduleFailure.unavailable,
          'Schedule path is not a regular file',
        );
      }
      await file.parent.create(recursive: true);
      _checkCurrent();
      // Same parent/filesystem; a unique attempt cannot truncate a prior temp.
      temporaryDirectory = await file.parent.createTemp('.program-schedule-');
      _checkCurrent();
      final temporary = File('${temporaryDirectory.path}/next.json');
      _checkCurrent();
      await _writeTemporary(temporary, bytes);
      // Owner retirement during IO prevents dispatching the atomic commit.
      _checkCurrent();
      await _commit(temporary, file);
      _checkCurrent();
    } on FileSystemException {
      throw const ProgramScheduleException(
        ProgramScheduleFailure.unavailable,
        'Schedule could not be saved',
      );
    } finally {
      // Only this attempt's temporary directory is removed. A crash may leave
      // an orphan; never delete or "repair" the user's target during cleanup.
      if (temporaryDirectory != null) {
        try {
          await temporaryDirectory.delete(recursive: true);
        } on FileSystemException {
          // Cleanup failure must not replace the save/owner error.
        }
      }
    }
  }
}
