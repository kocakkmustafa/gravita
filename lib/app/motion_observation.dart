import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:motion_camera/motion_camera.dart';
import 'package:motion_content/motion_content.dart';
import 'package:motion_core/motion_core.dart' show SessionRecord;

import 'pose_model.dart';

const observationContract = 'gravita.observation.v1';

enum ObservationStatus {
  unsupported,
  calibrationRequired,
  missingData,
  lowConfidence,
  incompatible,
  interrupted,
  providerError,
  observed,
}

enum ObservationOrigin { device, synthetic }

/// App-owned package contract. A JSON assertion is never physical acceptance.
final class MotionModelManifest {
  MotionModelManifest._(
    this.digest,
    this.poseSha256,
    this.providerId,
    this.calibrationSha256,
    this.tasks,
  );

  factory MotionModelManifest.parse(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final sha = RegExp(r'^[a-f0-9]{64}$');
    final pose = json['poseSha256'];
    final calibration = json['calibrationSha256'];
    final provider = json['providerId'];
    if (json['schemaVersion'] != 1 ||
        json['appId'] != 'com.yulalab.gravita' ||
        json['contract'] != observationContract ||
        json['version'] != '1.0.0' ||
        pose is! String ||
        !sha.hasMatch(pose) ||
        provider is! String ||
        provider.isEmpty ||
        (calibration != null &&
            (calibration is! String || !sha.hasMatch(calibration))) ||
        !['pending', 'candidate'].contains(json['calibrationStatus']) ||
        (json['calibrationStatus'] == 'pending' && calibration != null) ||
        (json['calibrationStatus'] == 'candidate' && calibration == null)) {
      throw const FormatException('Incompatible Gravita observation manifest');
    }
    final tasks = <String, ObservationTask>{};
    for (final raw in json['tasks'] as List) {
      final value = raw as Map<String, dynamic>;
      final id = value['id'] as String;
      final task = ObservationTask(
        id: id,
        inverted: value['inverted'] as bool,
        orientationAware: value['orientationAware'] as bool,
        phases: List<String>.unmodifiable(
          (value['phases'] as List).cast<String>(),
        ),
        referenceSha256: value['referenceSha256'] as String?,
        minimumConfidence: (value['minimumConfidence'] as num?)?.toDouble(),
      );
      if (!id.startsWith('gravita:') ||
          tasks.containsKey(id) ||
          task.phases.length < 2 ||
          task.phases.toSet().length != task.phases.length ||
          task.phases.any((p) => p.isEmpty) ||
          task.referenceSha256 != null &&
              !sha.hasMatch(task.referenceSha256!) ||
          task.minimumConfidence != null &&
              (!task.minimumConfidence!.isFinite ||
                  task.minimumConfidence! <= 0 ||
                  task.minimumConfidence! > 1) ||
          task.inverted && !task.orientationAware) {
        throw const FormatException('Invalid observation task');
      }
      tasks[id] = task;
    }
    if (tasks.isEmpty) {
      throw const FormatException('Empty observation manifest');
    }
    return MotionModelManifest._(
      computeSha256Hex(utf8.encode(source)),
      pose,
      provider,
      calibration as String?,
      Map.unmodifiable(tasks),
    );
  }

  ({bool repetitions, bool phases, bool reference}) capabilitiesFor(
    String taskId, {
    Set<String> acceptedDigests = const {},
  }) {
    final enabled =
        readinessFor(taskId, acceptedDigests: acceptedDigests) ==
        ObservationStatus.observed;
    return (repetitions: enabled, phases: enabled, reference: enabled);
  }

  final String digest, poseSha256, providerId;
  final String? calibrationSha256;
  final Map<String, ObservationTask> tasks;

  /// Bundled pending tasks remain closed. An accepted future package must bind
  /// the whole manifest, including task, confidence, reference and S2 flags.
  ObservationStatus readinessFor(
    String taskId, {
    Set<String> acceptedDigests = const {},
  }) {
    final task = tasks[taskId];
    if (task == null) return ObservationStatus.unsupported;
    if (calibrationSha256 == null ||
        task.referenceSha256 == null ||
        task.minimumConfidence == null ||
        !acceptedDigests.contains(digest)) {
      return ObservationStatus.calibrationRequired;
    }
    return ObservationStatus.observed;
  }
}

/// Receipt hashes actual loaded bytes. It does not review an acceptance file
/// or establish trust: acceptedDigests still belongs to the reviewed app build.
final class LoadedObservationArtifacts {
  LoadedObservationArtifacts({
    required Uint8List model,
    required Uint8List calibration,
  }) : modelSha256 = computeSha256Hex(model),
       calibrationSha256 = computeSha256Hex(calibration);
  final String modelSha256, calibrationSha256;
}

final class ObservationTask {
  const ObservationTask({
    required this.id,
    required this.inverted,
    required this.orientationAware,
    required this.phases,
    this.referenceSha256,
    this.minimumConfidence,
  });
  final String id;
  final bool inverted, orientationAware;
  final List<String> phases;
  final String? referenceSha256;
  final double? minimumConfidence;
}

/// Real providers receive camera envelopes, never invented model answers.
/// Implementations belong to Gravita; shared Core stays unchanged.
abstract interface class MovementObservationProvider {
  String get id;
  String get contract;
  String get poseSha256;
  String get calibrationSha256;
  bool get orientationAware;
  ObservationOrigin get origin;
  Future<ProviderObservation> observe(CameraFrameEnvelope frame, String taskId);
  Future<void> reset();
  Future<void> dispose();
}

final class ProviderObservation {
  const ProviderObservation({
    required this.taskId,
    required this.tUs,
    required this.confidence,
    required this.phase,
    required this.visible,
    required this.referenceSha256,
  });
  final String taskId, phase, referenceSha256;
  final int tUs;
  final double confidence;
  final bool visible;
}

final class MovementObservation {
  const MovementObservation(this.status, {this.phase, this.repetitions});
  final ObservationStatus status;
  final String? phase;
  final int? repetitions;
}

/// No silent model fallback. A rejected replacement keeps the last accepted
/// object; without one, callers retain explicit calibration/unsupported states.
MotionModelManifest? selectCompatibleModel({
  required MotionModelManifest candidate,
  required Set<String> acceptedDigests,
  required String installedPoseSha256,
  required String installedCalibrationSha256,
  MotionModelManifest? previous,
}) {
  bool compatible(MotionModelManifest value) =>
      acceptedDigests.contains(value.digest) &&
      value.poseSha256 == installedPoseSha256 &&
      value.calibrationSha256 != null &&
      value.calibrationSha256 == installedCalibrationSha256;
  if (compatible(candidate)) return candidate;
  return previous != null && compatible(previous) ? previous : null;
}

final class MovementObservationSession {
  MovementObservationSession({
    required this.manifest,
    required this.provider,
    required Set<String> acceptedDigests,
    required LoadedObservationArtifacts loadedArtifacts,
  }) : _accepted = Set.unmodifiable(acceptedDigests),
       _testing = false {
    if (provider.origin != ObservationOrigin.device) {
      throw ArgumentError(
        'Synthetic providers cannot enter production sessions',
      );
    }
    if (loadedArtifacts.modelSha256 != manifest.poseSha256 ||
        loadedArtifacts.calibrationSha256 != manifest.calibrationSha256) {
      throw ArgumentError(
        'Loaded model/calibration bytes do not match manifest',
      );
    }
  }

  @visibleForTesting
  MovementObservationSession.forTesting({
    required this.manifest,
    required this.provider,
    required Set<String> acceptedDigests,
  }) : _accepted = Set.unmodifiable(acceptedDigests),
       _testing = true {
    if (kReleaseMode) {
      throw StateError('Test observation sessions excluded from release');
    }
  }

  final MotionModelManifest manifest;
  final MovementObservationProvider provider;
  final Set<String> _accepted;
  final bool _testing;
  bool _closed = false, _active = true, _busy = false;
  int _epoch = 0, _reps = 0, _phase = -1, _observed = 0;
  int? _lastTime;
  String? _task;

  Future<MovementObservation> consume(
    CameraFrameEnvelope frame,
    String taskId,
  ) async {
    if (_closed || !_active) {
      return const MovementObservation(ObservationStatus.interrupted);
    }
    if (_busy) return const MovementObservation(ObservationStatus.missingData);
    final ready = manifest.readinessFor(taskId, acceptedDigests: _accepted);
    if (ready != ObservationStatus.observed) return MovementObservation(ready);
    final task = manifest.tasks[taskId]!;
    if (provider.id != manifest.providerId ||
        provider.contract != observationContract ||
        provider.poseSha256 != manifest.poseSha256 ||
        provider.calibrationSha256 != manifest.calibrationSha256 ||
        task.inverted && !provider.orientationAware) {
      return const MovementObservation(ObservationStatus.incompatible);
    }
    if (_task != null && _task != taskId) {
      return const MovementObservation(ObservationStatus.unsupported);
    }
    _task = taskId;
    if (frame.clockDomain != ClockDomain.monotonic ||
        frame.modelVersion != PoseModelPin.modelId ||
        frame.tUs < 0 ||
        _lastTime != null && frame.tUs <= _lastTime!) {
      _phase = -1;
      return const MovementObservation(ObservationStatus.missingData);
    }
    if (_lastTime != null && frame.tUs - _lastTime! > 500000) _phase = -1;
    _lastTime = frame.tUs;
    final epoch = _epoch;
    _busy = true;
    try {
      final sample = await provider.observe(frame, taskId);
      if (_closed || !_active || epoch != _epoch) {
        return const MovementObservation(ObservationStatus.interrupted);
      }
      if (sample.taskId != taskId ||
          sample.tUs != frame.tUs ||
          sample.referenceSha256 != task.referenceSha256 ||
          !sample.confidence.isFinite ||
          sample.confidence < 0 ||
          sample.confidence > 1 ||
          !task.phases.contains(sample.phase)) {
        _phase = -1;
        return const MovementObservation(ObservationStatus.incompatible);
      }
      if (!sample.visible) {
        _phase = -1;
        return const MovementObservation(ObservationStatus.missingData);
      }
      if (sample.confidence < task.minimumConfidence!) {
        _phase = -1;
        return const MovementObservation(ObservationStatus.lowConfidence);
      }
      final next = task.phases.indexOf(sample.phase);
      if (next == 0) {
        _phase = 0;
      } else if (next == _phase + 1) {
        _phase = next;
        if (next == task.phases.length - 1) {
          _reps++;
          _phase = -1;
        }
      } else if (next != _phase) {
        _phase = -1;
        return const MovementObservation(ObservationStatus.missingData);
      }
      _observed++;
      return MovementObservation(
        ObservationStatus.observed,
        phase: sample.phase,
        repetitions: _reps,
      );
    } on Object {
      _phase = -1;
      return const MovementObservation(ObservationStatus.providerError);
    } finally {
      _busy = false;
    }
  }

  /// Lifecycle/owner changes invalidate pending async results and phase state.
  /// Resume requires an explicit new session object; no pre-background rep leaks.
  Future<void> interrupt() async {
    _active = false;
    _epoch++;
    _phase = -1;
    await provider.reset();
  }

  SessionRecord? buildRecord({
    required DateTime startedAt,
    required DateTime endedAt,
  }) {
    if (_observed == 0 || _task == null || endedAt.isBefore(startedAt)) {
      return null;
    }
    return SessionRecord(
      lessonId: 'observation:$_task:${manifest.digest}',
      completedAt: endedAt,
      workedSeconds: endedAt.difference(startedAt).inSeconds,
      unitsCompleted: _reps,
      plannedUnits: 0,
      unitLabel: 'rep',
      lessonClass: _testing ? 'syntheticObservation' : 'measurementOnly',
    );
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    _active = false;
    _epoch++;
    _phase = -1;
    await provider.dispose();
  }
}
