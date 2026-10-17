import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_camera/motion_camera.dart';
import 'package:motion_core/motion_core.dart';
import 'package:gravita/app/motion_observation.dart';

// Synthetic source exists only in test/. No production fake inference provider.
class FixtureProvider implements MovementObservationProvider {
  FixtureProvider({this.origin = ObservationOrigin.synthetic});
  @override
  final ObservationOrigin origin;
  @override
  String id = 'gravita.pose-phase.v1';
  @override
  String contract = observationContract;
  @override
  String poseSha256 =
      '5134a3aad27a58b93da0088d431f366da362b44e3ccfbe3462b3827a839011b1';
  @override
  String calibrationSha256 = 'a' * 64;
  @override
  bool orientationAware = true;
  int calls = 0, resets = 0, disposed = 0;
  String phase = 'entry', task = 'gravita:barbell-03', reference = 'b' * 64;
  bool visible = true, throws = false;
  double confidence = .9;
  Completer<ProviderObservation>? pending;
  @override
  Future<ProviderObservation> observe(
    CameraFrameEnvelope frame,
    String taskId,
  ) async {
    calls++;
    if (throws) throw StateError('fixture failure');
    if (pending != null) return pending!.future;
    return ProviderObservation(
      taskId: task,
      tUs: frame.tUs,
      confidence: confidence,
      phase: phase,
      visible: visible,
      referenceSha256: reference,
    );
  }

  @override
  Future<void> reset() async {
    resets++;
  }

  @override
  Future<void> dispose() async {
    disposed++;
  }
}

void main() {
  final source = File(
    'content/models/gravita-observation.v1.json',
  ).readAsStringSync();
  MotionModelManifest candidate({bool inverted = false}) {
    final value = jsonDecode(source) as Map<String, dynamic>;
    value['calibrationStatus'] = 'candidate';
    value['calibrationSha256'] = 'a' * 64;
    value['tasks'] = [
      {
        'id': 'gravita:barbell-03',
        'inverted': inverted,
        'orientationAware': true,
        'phases': ['entry', 'task', 'exit'],
        'referenceSha256': 'b' * 64,
        'minimumConfidence': .8,
      },
    ];
    return MotionModelManifest.parse(jsonEncode(value));
  }

  CameraFrameEnvelope frame(int time) => CameraFrameEnvelope(
    tUs: time,
    size: const FrameSize(900, 900),
    modelVersion: 'pose_landmarker_full/float16/1',
    clockDomain: ClockDomain.monotonic,
    inferenceUs: 1000,
    dropped: 0,
    passes: const <BodyOrientation, PoseFrame?>{BodyOrientation.upright: null},
  );
  test('pending manifest cannot call provider or fabricate counts', () async {
    final manifest = MotionModelManifest.parse(source),
        provider = FixtureProvider();
    final session = MovementObservationSession.forTesting(
      manifest: manifest,
      provider: provider,
      acceptedDigests: {},
    );
    final result = await session.consume(frame(0), 'gravita:barbell-03');
    expect(result.status, ObservationStatus.calibrationRequired);
    expect(result.repetitions, isNull);
    expect(
      (await session.consume(frame(1), 'missing')).status,
      ObservationStatus.unsupported,
    );
    expect(manifest.capabilitiesFor('gravita:barbell-03').repetitions, isFalse);
    expect(provider.calls, 0);
    expect(
      session.buildRecord(startedAt: DateTime(2026), endedAt: DateTime(2026)),
      isNull,
    );
    await session.dispose();
  });
  test('production rejects declared hashes when loaded bytes differ', () {
    final manifest = candidate();
    expect(
      () => MovementObservationSession(
        manifest: manifest,
        provider: FixtureProvider(origin: ObservationOrigin.device),
        acceptedDigests: {manifest.digest},
        loadedArtifacts: LoadedObservationArtifacts(
          model: Uint8List.fromList([1]),
          calibration: Uint8List.fromList([2]),
        ),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'reason',
          contains('Loaded model/calibration'),
        ),
      ),
    );
  });
  test('artifact receipt hashes actual bytes rather than manifest strings', () {
    final actual = LoadedObservationArtifacts(
      model: Uint8List.fromList([1, 2]),
      calibration: Uint8List.fromList([3, 4]),
    );
    expect(
      actual.modelSha256,
      'a12871fee210fb8619291eaea194581cbd2531e4b23759d225f6806923f63222',
    );
    expect(actual.calibrationSha256, isNot(actual.modelSha256));
  });
  test(
    'production refuses synthetic provider and no silent fallback to pending',
    () {
      final manifest = candidate();
      expect(
        () => MovementObservationSession(
          manifest: manifest,
          provider: FixtureProvider(),
          loadedArtifacts: LoadedObservationArtifacts(
            model: Uint8List.fromList([1]),
            calibration: Uint8List.fromList([2]),
          ),
          acceptedDigests: {manifest.digest},
        ),
        throwsArgumentError,
      );
      expect(
        selectCompatibleModel(
          candidate: manifest,
          acceptedDigests: {},
          installedPoseSha256: manifest.poseSha256,
          installedCalibrationSha256: manifest.calibrationSha256!,
        ),
        isNull,
      );
      final pending = MotionModelManifest.parse(source);
      expect(
        selectCompatibleModel(
          candidate: pending,
          previous: manifest,
          acceptedDigests: {manifest.digest},
          installedPoseSha256: manifest.poseSha256,
          installedCalibrationSha256: manifest.calibrationSha256!,
        ),
        same(manifest),
      );
      expect(
        selectCompatibleModel(
          candidate: pending,
          previous: manifest,
          acceptedDigests: {manifest.digest},
          installedPoseSha256: 'c' * 64,
          installedCalibrationSha256: manifest.calibrationSha256!,
        ),
        isNull,
      );
    },
  );
  test(
    'parser rejects unsupported contract, fake hashes, unbounded confidence and S1 inversions',
    () {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (v) => v['schemaVersion'] = 2,
        (v) => v['version'] = '2.0.0',
        (v) => v['contract'] = 'other',
        (v) => v['poseSha256'] = 'bad',
        (v) => v['calibrationStatus'] = 'accepted',
        (v) => v['tasks'][0]['minimumConfidence'] = 2,
        (v) {
          v['tasks'][0]['inverted'] = true;
          v['tasks'][0]['orientationAware'] = false;
        },
      ]) {
        final v = jsonDecode(source) as Map<String, dynamic>;
        mutate(v);
        expect(
          () => MotionModelManifest.parse(jsonEncode(v)),
          throwsA(anything),
        );
      }
    },
  );
  test(
    'phase order, confidence, missing/reference/task errors abstain without completing',
    () async {
      final manifest = candidate(), provider = FixtureProvider();
      final session = MovementObservationSession.forTesting(
        manifest: manifest,
        provider: provider,
        acceptedDigests: {manifest.digest},
      );
      expect((await session.consume(frame(0), provider.task)).repetitions, 0);
      provider.phase = 'exit';
      expect(
        (await session.consume(frame(10), provider.task)).status,
        ObservationStatus.missingData,
      );
      provider.phase = 'entry';
      await session.consume(frame(20), provider.task);
      provider.phase = 'task';
      provider.confidence = .2;
      expect(
        (await session.consume(frame(30), provider.task)).status,
        ObservationStatus.lowConfidence,
      );
      provider.confidence = .9;
      provider.phase = 'exit';
      expect(
        (await session.consume(frame(40), provider.task)).status,
        ObservationStatus.missingData,
      );
      provider.phase = 'entry';
      provider.visible = false;
      expect(
        (await session.consume(frame(50), provider.task)).status,
        ObservationStatus.missingData,
      );
      provider.visible = true;
      provider.reference = 'c' * 64;
      expect(
        (await session.consume(frame(60), provider.task)).status,
        ObservationStatus.incompatible,
      );
      provider.reference = 'b' * 64;
      provider.task = 'gravita:rings-03';
      expect(
        (await session.consume(frame(70), 'gravita:barbell-03')).status,
        ObservationStatus.incompatible,
      );
      await session.dispose();
    },
  );
  test(
    'ordered synthetic sequence records only a synthetic observation identity',
    () async {
      final manifest = candidate(), provider = FixtureProvider();
      final session = MovementObservationSession.forTesting(
        manifest: manifest,
        provider: provider,
        acceptedDigests: {manifest.digest},
      );
      int time = 0;
      for (final phase in ['entry', 'task', 'exit']) {
        provider.phase = phase;
        final value = await session.consume(frame(time), provider.task);
        expect(value.status, ObservationStatus.observed);
        time += 10000;
      }
      final record = session.buildRecord(
        startedAt: DateTime(2026),
        endedAt: DateTime(2026, 1, 1, 0, 0, 1),
      )!;
      expect(record.unitsCompleted, 1);
      expect(record.lessonClass, 'syntheticObservation');
      expect(record.lessonId, startsWith('observation:gravita:barbell-03:'));
      await session.dispose();
      await session.dispose();
      expect(provider.disposed, 1);
    },
  );
  test('clock gap and provider failure reset partial phase', () async {
    final manifest = candidate(), provider = FixtureProvider();
    final session = MovementObservationSession.forTesting(
      manifest: manifest,
      provider: provider,
      acceptedDigests: {manifest.digest},
    );
    await session.consume(frame(100), provider.task);
    provider.phase = 'task';
    expect(
      (await session.consume(frame(100), provider.task)).status,
      ObservationStatus.missingData,
    );
    expect(
      (await session.consume(frame(1000000), provider.task)).status,
      ObservationStatus.missingData,
    );
    provider.throws = true;
    expect(
      (await session.consume(frame(1010000), provider.task)).status,
      ObservationStatus.providerError,
    );
    await session.dispose();
  });
  test(
    'background invalidates an in-flight result; disposed session cannot infer',
    () async {
      final manifest = candidate(),
          provider = FixtureProvider()
            ..pending = Completer<ProviderObservation>();
      final session = MovementObservationSession.forTesting(
        manifest: manifest,
        provider: provider,
        acceptedDigests: {manifest.digest},
      );
      final pending = session.consume(frame(1), provider.task);
      await session.interrupt();
      provider.pending!.complete(
        ProviderObservation(
          taskId: provider.task,
          tUs: 1,
          confidence: .9,
          phase: 'entry',
          visible: true,
          referenceSha256: 'b' * 64,
        ),
      );
      expect((await pending).status, ObservationStatus.interrupted);
      expect(provider.resets, 1);
      expect(
        (await session.consume(frame(2), provider.task)).status,
        ObservationStatus.interrupted,
      );
      await session.dispose();
      expect(
        (await session.consume(frame(3), provider.task)).status,
        ObservationStatus.interrupted,
      );
    },
  );
  test(
    'incompatible provider hash and inversion S2 contract block inference',
    () async {
      for (final inverted in [false, true]) {
        final manifest = candidate(inverted: inverted),
            provider = FixtureProvider();
        if (inverted) {
          provider.orientationAware = false;
        } else {
          provider.poseSha256 = 'c' * 64;
        }
        final session = MovementObservationSession.forTesting(
          manifest: manifest,
          provider: provider,
          acceptedDigests: {manifest.digest},
        );
        expect(
          (await session.consume(frame(1), provider.task)).status,
          ObservationStatus.incompatible,
        );
        expect(provider.calls, 0);
        await session.dispose();
      }
    },
  );
}
