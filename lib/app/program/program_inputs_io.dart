import 'dart:convert';
import 'dart:io';

import 'program_model.dart';

enum ProgramInputsFailure { corrupt, unavailable }

final class ProgramInputsException implements Exception {
  const ProgramInputsException(this.failure, this.message);

  final ProgramInputsFailure failure;
  final String message;

  @override
  String toString() => 'ProgramInputsException(${failure.name}): $message';
}

/// Storage bounds, not a new program/configuration or equipment catalogue.
/// Current UI/configuration limits remain the builder's responsibility.
final class ProgramInputsCodec {
  static const int maxBytes = 16 * 1024;
  static const int maxEquipment = 128;
  static const int maxEquipmentNameLength = 128;

  static ProgramInputs decode(List<int> bytes) {
    if (bytes.length > maxBytes) {
      throw const FormatException('Program inputs exceed their byte limit');
    }
    final Object? raw = jsonDecode(utf8.decode(bytes));
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Expected a program inputs object');
    }
    const fields = <String>{
      'schemaVersion',
      'availableEquipment',
      'daysPerWeek',
      'experience',
    };
    if (raw.keys.any((key) => !fields.contains(key))) {
      // Do not drop fields written by a future writer in a later encode.
      throw const FormatException('Unsupported program inputs fields');
    }
    // The original reader also accepted fixtures without a schema field.
    if (raw.containsKey('schemaVersion') &&
        (raw['schemaVersion'] is! int || raw['schemaVersion'] != 1)) {
      throw const FormatException('Unsupported program inputs schema');
    }
    final equipment = raw['availableEquipment'];
    final daysPerWeek = raw['daysPerWeek'];
    final experienceName = raw['experience'];
    if (equipment is! List<dynamic> ||
        equipment.length > maxEquipment ||
        equipment.any(
          (item) =>
              item is! String ||
              item.isEmpty ||
              item.length > maxEquipmentNameLength,
        ) ||
        daysPerWeek is! int ||
        daysPerWeek < 1 ||
        daysPerWeek > 7 ||
        experienceName is! String) {
      throw const FormatException('Invalid program inputs fields');
    }
    ExperienceLevel? experience;
    for (final level in ExperienceLevel.values) {
      if (level.name == experienceName) experience = level;
    }
    if (experience == null) {
      throw const FormatException('Invalid program experience');
    }
    return ProgramInputs(
      availableEquipment: Set<String>.unmodifiable(equipment.cast<String>()),
      daysPerWeek: daysPerWeek,
      experience: experience,
    );
  }

  static List<int> encode(ProgramInputs inputs) {
    final bytes = utf8.encode(
      jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'availableEquipment': inputs.availableEquipment.toList(),
        'daysPerWeek': inputs.daysPerWeek,
        'experience': inputs.experience.name,
      }),
    );
    // Complete validation before creating a directory or touching any file.
    try {
      decode(bytes);
    } on FormatException {
      throw ArgumentError('Invalid program inputs');
    }
    return bytes;
  }
}

typedef ProgramInputsSerialize =
    Future<T> Function<T>(Future<T> Function() operation);
typedef ProgramInputsTemporaryWrite =
    Future<void> Function(File temporary, List<int> bytes);
typedef ProgramInputsCommit =
    Future<void> Function(File temporary, File target);

/// Pure Dart production IO. The host supplies its existing per-file owner
/// lease/queue. This replaces only one input file; it does not make Setup's
/// separate schedule/input writes a transaction or recover partial histories.
final class ProgramInputsIo {
  ProgramInputsIo(
    this.file, {
    required ProgramInputsSerialize serialize,
    void Function()? checkCurrent,
    ProgramInputsTemporaryWrite? writeTemporary,
    ProgramInputsCommit? commit,
  }) : _serialize = serialize,
       _checkCurrent = checkCurrent ?? _noCheck,
       _writeTemporary = writeTemporary ?? _writeFlushed,
       _commit = commit ?? _rename;

  final File file;
  final ProgramInputsSerialize _serialize;
  final void Function() _checkCurrent;
  final ProgramInputsTemporaryWrite _writeTemporary;
  final ProgramInputsCommit _commit;

  static void _noCheck() {}

  static Future<void> _writeFlushed(File file, List<int> bytes) async {
    await file.writeAsBytes(bytes, flush: true);
  }

  static Future<void> _rename(File temporary, File target) async {
    await temporary.rename(target.path);
  }

  Future<ProgramInputs?> read() => _serialize(_readCurrent);

  /// Explicit replacement retains the host API. A failed read never invokes
  /// this method; the existing Setup/Workout HOLD policy remains with callers.
  Future<void> write(ProgramInputs inputs) =>
      _serialize(() => _writeCurrent(inputs));

  Future<ProgramInputs?> _readCurrent() async {
    _checkCurrent();
    try {
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      _checkCurrent();
      if (type != FileSystemEntityType.file &&
          type != FileSystemEntityType.notFound) {
        throw const ProgramInputsException(
          ProgramInputsFailure.unavailable,
          'Program inputs path is not a regular file',
        );
      }
      // An actual open distinguishes ENOENT from a denied/unavailable path.
      final bytes = <int>[];
      await for (final chunk in file.openRead(
        0,
        ProgramInputsCodec.maxBytes + 1,
      )) {
        _checkCurrent();
        bytes.addAll(chunk);
      }
      _checkCurrent();
      try {
        return ProgramInputsCodec.decode(bytes);
      } on FormatException {
        throw const ProgramInputsException(
          ProgramInputsFailure.corrupt,
          'Program inputs contents cannot be read safely',
        );
      }
    } on FileSystemException catch (error) {
      _checkCurrent();
      if (error.osError?.errorCode == 2 ||
          (Platform.isWindows && error.osError?.errorCode == 3)) {
        return null;
      }
      throw const ProgramInputsException(
        ProgramInputsFailure.unavailable,
        'Program inputs could not be read',
      );
    }
  }

  Future<void> _writeCurrent(ProgramInputs inputs) async {
    final bytes = ProgramInputsCodec.encode(inputs);
    _checkCurrent();
    Directory? temporaryDirectory;
    try {
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      _checkCurrent();
      if (type != FileSystemEntityType.file &&
          type != FileSystemEntityType.notFound) {
        throw const ProgramInputsException(
          ProgramInputsFailure.unavailable,
          'Program inputs path is not a regular file',
        );
      }
      await file.parent.create(recursive: true);
      _checkCurrent();
      temporaryDirectory = await file.parent.createTemp('.program-inputs-');
      _checkCurrent();
      final temporary = File('${temporaryDirectory.path}/next.json');
      await _writeTemporary(temporary, bytes);
      _checkCurrent();
      await _commit(temporary, file);
      _checkCurrent();
    } on FileSystemException {
      throw const ProgramInputsException(
        ProgramInputsFailure.unavailable,
        'Program inputs could not be saved',
      );
    } finally {
      // Remove only this attempt's temporary directory, never the target.
      if (temporaryDirectory != null) {
        try {
          await temporaryDirectory.delete(recursive: true);
        } on FileSystemException {
          // Cleanup must not hide the save/owner error. No repair is inferred.
        }
      }
    }
  }
}
