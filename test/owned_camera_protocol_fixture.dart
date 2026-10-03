import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_camera/motion_camera.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Real Core controller + real MethodChannel/EventChannel plumbing. Only the
/// native responses are synthetic: this fixture is not device/model evidence.
class OwnedCameraProtocolFixture {
  OwnedCameraProtocolFixture() {
    final serial = ++_serial;
    binaryMessenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    control = MethodChannel(
      'gravita/test/owned-control-$serial',
      codec,
      binaryMessenger,
    );
    frameName = 'gravita/test/owned-frames-$serial';
    controller = MotionCameraController(
      control: control,
      frames: EventChannel(frameName, codec, binaryMessenger),
    );
  }

  static int _serial = 0;
  final MethodCodec codec = const StandardMethodCodec();
  late final BinaryMessenger binaryMessenger;
  late final MethodChannel control;
  late final String frameName;
  late final MotionCameraController controller;
  final controlCalls = <MethodCall>[];
  final frameCalls = <MethodCall>[];
  final frameReplies = <MethodCall>[];
  final protocolTrace = <String>[];
  final generations = <String, int>{};
  final sequences = <String, int>{};
  final pendingStarts = <String, Completer<Object?>>{};
  final Queue<Future<void> Function()> _stops = Queue();
  final Queue<Completer<void>> _readbacks = Queue();
  final Queue<Completer<void>> _cancels = Queue();
  final _gates = <Completer<void>>[];
  Completer<Object?>? _nextStart;
  Completer<Object?>? nextBusyStart;
  bool protocolAvailable = true;
  bool wrongReadbackNonce = false;
  String? owner;
  int _sequence = 0;

  int get startCalls =>
      controlCalls.where((call) => call.method == 'startOwned').length;
  int get stopCalls =>
      controlCalls.where((call) => call.method == 'stopOwned').length;
  int get readbackCalls =>
      controlCalls.where((call) => call.method == 'readback').length;
  int get rawListens =>
      frameCalls.where((call) => call.method == 'listen').length;
  int get rawCancels =>
      frameCalls.where((call) => call.method == 'cancel').length;
  int get rawCancelReplies =>
      frameReplies.where((call) => call.method == 'cancel').length;
  bool get usedLegacy => controlCalls.any(
    (call) =>
        call.method == 'start' ||
        call.method == 'stop' ||
        call.method == 'setPassPlan',
  );

  static Map<Object?, Object?> args(MethodCall call) =>
      call.arguments! as Map<Object?, Object?>;

  Map<String, Object> running(String id) => {
    'protocol': 1,
    'ownerId': id,
    'generation': generations[id] ?? 1,
    'w': 480,
    'h': 640,
    'clock': 'monotonic',
    'library': 'synthetic-owned-channel; no-native-acceptance',
  };

  Map<String, Object> closed(String id, {int nonce = 0}) => {
    'protocol': 1,
    'ownerId': id,
    'generation': generations[id] ?? 0,
    'state': owner == id ? 'running' : 'closed',
    'captureClosed': owner != id,
    'modelsClosed': owner != id,
    'closeSequence': sequences[id] ?? 0,
    'nonce': nonce,
  };

  void install() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(control, (call) async {
      controlCalls.add(call);
      protocolTrace.add('dispatch-${call.method}');
      if (!protocolAvailable) {
        throw MissingPluginException('synthetic old plugin');
      }
      final id = args(call)['ownerId']! as String;
      switch (call.method) {
        case 'startOwned':
          if (owner != null) {
            final pending = nextBusyStart;
            nextBusyStart = null;
            if (pending != null) {
              pendingStarts[id] = pending;
              return pending.future;
            }
            throw PlatformException(
              code: 'already-running',
              message: 'synthetic foreign owner',
            );
          }
          owner = id;
          generations[id] = 1;
          final gate = _nextStart;
          _nextStart = null;
          if (gate != null) {
            pendingStarts[id] = gate;
            return gate.future;
          }
          return running(id);
        case 'stopOwned':
          if (_stops.isNotEmpty) await _stops.removeFirst()();
          if (owner == id) {
            owner = null;
            final pending = pendingStarts[id];
            if (pending != null && !pending.isCompleted) {
              pending.completeError(
                PlatformException(code: 'session-interrupted'),
              );
            }
          }
          sequences[id] = ++_sequence;
          protocolTrace.add('reply-stopOwned');
          return closed(id);
        case 'readback':
          if (_readbacks.isNotEmpty) await _readbacks.removeFirst().future;
          return closed(
            id,
            nonce: wrongReadbackNonce ? 0 : args(call)['nonce']! as int,
          );
        case 'setPassPlanOwned':
          return {...closed(id), 'state': 'running'};
        default:
          throw StateError('Legacy/unexpected control method: ${call.method}');
      }
    });
    messenger.setMockMethodCallHandler(
      MethodChannel(frameName, codec, binaryMessenger),
      (call) async {
        frameCalls.add(call);
        protocolTrace.add('dispatch-frame-${call.method}');
        final id = (call.arguments as Map<Object?, Object?>?)?['ownerId'];
        if (call.method == 'listen') {
          if (id != owner) throw PlatformException(code: 'session-interrupted');
        } else if (call.method == 'cancel') {
          if (_cancels.isNotEmpty) await _cancels.removeFirst().future;
          // Explicit negative control: nil/global cancel could tear down B.
          if (id == null || id == owner) owner = null;
        } else {
          throw StateError('Unexpected raw frame method: ${call.method}');
        }
        frameReplies.add(call);
        protocolTrace.add('reply-frame-${call.method}');
        return null;
      },
    );
  }

  Completer<Object?> delayNextStart() => _nextStart = Completer<Object?>();

  Completer<void> _gate() {
    final gate = Completer<void>();
    _gates.add(gate);
    return gate;
  }

  Completer<void> delayNextStop() {
    final gate = _gate();
    _stops.add(() => gate.future);
    return gate;
  }

  void failNextStop() => _stops.add(
    () => Future<void>.error(PlatformException(code: 'synthetic-stop-failed')),
  );

  Completer<void> delayNextReadback() {
    final gate = _gate();
    _readbacks.add(gate);
    return gate;
  }

  Completer<void> delayNextRawCancel() {
    final gate = _gate();
    _cancels.add(gate);
    return gate;
  }

  Future<void> emit(int sequence, {String? ownerId, int? generation}) async {
    final id = ownerId ?? owner;
    if (id == null) {
      throw StateError('An explicit synthetic frame owner is required');
    }
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          frameName,
          codec.encodeSuccessEnvelope({
            'ownerId': id,
            'generation': generation ?? generations[id] ?? 1,
            't': sequence * 10000,
            'w': 480,
            'h': 640,
            'model': 'synthetic-owned-channel; no-native-inference',
            'clock': 'monotonic',
            'infUs': 0,
            'dropped': 0,
            'up': null,
          }),
          (_) {},
        );
  }

  Future<void> emitError() => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .handlePlatformMessage(
        frameName,
        codec.encodeErrorEnvelope(
          code: 'synthetic-frame-error',
          message: 'Synthetic malformed event',
          details: null,
        ),
        (_) {},
      );

  void releasePending() {
    for (final gate in _gates) {
      if (!gate.isCompleted) gate.complete();
    }
    for (final gate in pendingStarts.values) {
      if (!gate.isCompleted) {
        gate.completeError(PlatformException(code: 'session-interrupted'));
      }
    }
  }

  void uninstall() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(control, null);
    messenger.setMockMethodCallHandler(
      MethodChannel(frameName, codec, binaryMessenger),
      null,
    );
  }
}

class OwnedPermissionFixture {
  static const channel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  int status = 1;
  int requests = 0;
  int settingsOpens = 0;
  Completer<int>? nextReply;
  final _pending = <Completer<int>>[];

  void install() => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'requestPermissions':
            requests++;
            final pending = nextReply;
            nextReply = null;
            if (pending != null) _pending.add(pending);
            final value = pending == null ? status : await pending.future;
            return <int, int>{
              for (final id in call.arguments as List<dynamic>)
                id as int: value,
            };
          case 'checkPermissionStatus':
            return status;
          case 'openAppSettings':
            settingsOpens++;
            return true;
          default:
            throw StateError('Unexpected permission method: ${call.method}');
        }
      });

  void uninstall() => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
  void releasePending() {
    for (final pending in _pending) {
      if (!pending.isCompleted) pending.complete(status);
    }
  }
}

class OwnedSupportDirectory extends PathProviderPlatform {
  OwnedSupportDirectory(this.path);
  final String path;
  int requests = 0;
  Completer<String?>? nextReply;
  final _pending = <Completer<String?>>[];
  @override
  Future<String?> getApplicationSupportPath() async {
    requests++;
    final pending = nextReply;
    nextReply = null;
    if (pending != null) _pending.add(pending);
    return pending == null ? path : await pending.future;
  }

  void releasePending() {
    for (final pending in _pending) {
      if (!pending.isCompleted) pending.complete(path);
    }
  }
}
