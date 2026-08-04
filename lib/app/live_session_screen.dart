import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_camera/motion_camera.dart';
import 'package:motion_core/motion_core.dart' show FrameSize;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'live_session.dart';
import 'live_strings.dart';
import 'pose_model.dart';

/// CANLI seans ekranı — kamera → tekrar sayımı.
///
/// **Ekran mantık taşımaz:** zarf→motor zinciri [LiveSessionRunner]'da ve
/// kamerasız test edilebiliyor (`test/live_session_test.dart`). Burada olan
/// şey yalnızca: izin iste, kamerayı aç, akışı runner'a ver, hâli çiz.
///
/// ⚠️ **Bu ekran cihazda DOĞRULANMADI.** Simülatörde izin akışı ve dürüst
/// hâller görüldü; gerçek kamera + MediaPipe çıkarımı isimli bir
/// release-gate (M-F-263) ve o kapı geçilene kadar hiçbir beyan "cihazda
/// kanıtlı" demez.
class LiveSessionScreen extends StatefulWidget {
  const LiveSessionScreen({
    required this.config,
    this.controller,
    super.key,
  });

  final MovementConfig config;

  /// Testlerin/harness'ın kendi denetleyicisini vermesi için. Üretimde null.
  final MotionCameraController? controller;

  static const Key startButtonKey = Key('live.start');
  static const Key stopButtonKey = Key('live.stop');
  static const Key failureKey = Key('live.failure');
  static const Key noPersonKey = Key('live.noPerson');
  static const Key repCountKey = Key('live.repCount');

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  late final MotionCameraController _camera =
      widget.controller ?? MotionCameraController();

  LiveState _state = const LiveIdle();
  StreamSubscription<CameraFrameEnvelope>? _sub;
  bool _running = false;

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    if (_running) unawaited(_camera.stop().catchError((Object _) {}));
    super.dispose();
  }

  /// Asset'i dosyaya yazar — plugin bundle değil YOL istiyor.
  Future<String> _modelPath() async {
    final Directory dir = await getApplicationSupportDirectory();
    final File f = File('${dir.path}/${PoseModelPin.assetPath.split('/').last}');
    if (!await f.exists()) {
      final ByteData data = await rootBundle.load(PoseModelPin.assetPath);
      await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return f.path;
  }

  Future<void> _start() async {
    setState(() => _state = const LiveStarting());
    try {
      // İzin ÖNCE ve AÇIKÇA: reddedilirse adı olan bir hâl doğar, boş bir
      // ekran değil.
      final PermissionStatus perm = await Permission.camera.request();
      if (!perm.isGranted) {
        if (!mounted) return;
        setState(() => _state = const LiveFailed(
            CameraFailure.permissionDenied,
            detail: 'permission_handler: denied'));
        return;
      }

      final CameraSessionInfo info = await _camera.start(
        modelPath: await _modelPath(),
        modelId: PoseModelPin.modelId,
        lens: CameraLens.back,
        initialPlan: PassPlan.uprightOnly,
      );
      final LiveSessionRunner runner = LiveSessionRunner(
        config: widget.config,
        // Kare boyutu OTURUMDAN gelir, sabit yazılmaz: izotropik düzeltme
        // buna bağlı ve yanlış boyut açıları sessizce kaydırır (J-028).
        frameSize: FrameSize(info.width, info.height),
      );
      _sub = _camera.frames().listen(
        (CameraFrameEnvelope e) {
          runner.consume(e);
          if (mounted) setState(() => _state = runner.state);
        },
        onError: (Object err) {
          if (!mounted) return;
          setState(() => _state = err is CameraException
              ? LiveFailed(err.failure, detail: err.detail)
              : LiveFailed(null, detail: err.toString()));
        },
      );
      if (!mounted) return;
      setState(() {
        _running = true;
        _state = runner.state;
      });
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _state = LiveFailed(e.failure, detail: e.detail));
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _state = LiveFailed(null, detail: e.toString()));
      }
    }
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _camera.stop();
    } on Object catch (_) {
      // Durdurmada arıza kullanıcıyı ilgilendirmez: oturum zaten bitiyor.
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _state = const LiveIdle();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(LiveStrings.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(child: _body()),
      ),
    );
  }

  Widget _body() => switch (_state) {
        LiveIdle() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(LiveStrings.idle),
              const SizedBox(height: 8),
              const Text(LiveStrings.gateNote),
              const SizedBox(height: 16),
              FilledButton(
                key: LiveSessionScreen.startButtonKey,
                onPressed: _start,
                child: const Text(LiveStrings.start),
              ),
            ],
          ),
        LiveStarting() => const Text(LiveStrings.starting),
        LiveFailed(:final CameraFailure? failure, :final String? detail) =>
          Column(
            key: LiveSessionScreen.failureKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(LiveStrings.failureTitle(failure),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(LiveStrings.failureBody(failure)),
              if (detail != null) ...<Widget>[
                const SizedBox(height: 12),
                // Ayrıntı GİZLENMEZ, İKİNCİLLEŞTİRİLİR (G-102).
                Text(LiveStrings.detailLabel,
                    style: Theme.of(context).textTheme.labelSmall),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 16),
              FilledButton(
                key: LiveSessionScreen.startButtonKey,
                onPressed: _start,
                child: const Text(LiveStrings.start),
              ),
            ],
          ),
        LiveRunning(
          :final int framesSeen,
          :final bool personVisible,
          :final List<Rep> reps
        ) =>
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!personVisible)
                const Text(LiveStrings.noPerson,
                    key: LiveSessionScreen.noPersonKey),
              if (personVisible || reps.isNotEmpty) ...<Widget>[
                Text(
                  reps.isEmpty
                      ? LiveStrings.noRepsYet
                      : LiveStrings.reps(reps.length),
                  key: LiveSessionScreen.repCountKey,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Text(LiveStrings.countingNote),
              ],
              const SizedBox(height: 8),
              Text('$framesSeen frames',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              FilledButton(
                key: LiveSessionScreen.stopButtonKey,
                onPressed: _stop,
                child: const Text(LiveStrings.stop),
              ),
            ],
          ),
      };
}
