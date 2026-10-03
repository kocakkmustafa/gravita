import 'dart:async';

/// Kapanışın bitmesi ile kameranın bırakılması ayrı sonuçlardır.
final class CameraReleaseResult {
  const CameraReleaseResult.success() : error = null, stackTrace = null;
  const CameraReleaseResult.failure(
    Object this.error,
    StackTrace this.stackTrace,
  );

  final Object? error;
  final StackTrace? stackTrace;
  bool get released => error == null;
}

/// Tek fiziksel kamera için süreç-geneli kapanış ve kurtarma sırası.
///
/// `dispose` bekleyemez: [hold] kapanışı senkron yayınlar. Sonuç Future'ı
/// hata fırlatmaz; başarısız Stop ise başarılı bırakma gibi silinmez. Yeni
/// Start, [awaitRelease] sonucunu kontrol eder ve gerekirse idempotent Stop
/// ile bir kurtarma denemesi yapar. Pending Start bu nöbete dahil edilmez.
class CameraReleaseLatch {
  CameraReleaseLatch._();

  static final Set<Future<CameraReleaseResult>> _pending =
      <Future<CameraReleaseResult>>{};
  static CameraReleaseResult? _failure;
  static Future<CameraReleaseResult>? _recovery;
  static int _generation = 0;
  static int _failureVersion = 0;

  /// Tüm uçmakta olan kapanışları tutar; ikinci kapanış ilkini örtmez.
  static Future<CameraReleaseResult> hold(Future<void> closing) {
    final int generation = _generation;
    final completer = Completer<CameraReleaseResult>();
    final Future<CameraReleaseResult> tracked = completer.future;
    _pending.add(tracked);
    unawaited(
      closing.then<void>(
        (_) {
          if (generation == _generation) _pending.remove(tracked);
          completer.complete(const CameraReleaseResult.success());
        },
        onError: (Object error, StackTrace stackTrace) {
          final result = CameraReleaseResult.failure(error, stackTrace);
          if (generation == _generation) {
            _pending.remove(tracked);
            _failure = result;
            _failureVersion++;
          }
          completer.complete(result);
        },
      ),
    );
    return tracked;
  }

  static Future<void> _waitForPending() async {
    while (_pending.isNotEmpty) {
      // Beklerken eklenen kapanışlar bir sonraki turda görülür.
      await Future.wait(_pending.toList());
    }
  }

  /// Başarısız bırakma varsa çağıranın verdiği Stop bir kez denenir.
  /// Eşzamanlı çağıranlar aynı kurtarma Future'ını paylaşır; hata sonucunda
  /// otomatik sonsuz retry yoktur, bir sonraki açık Start yeniden deneyebilir.
  static Future<CameraReleaseResult> awaitRelease({
    Future<void> Function()? recover,
  }) async {
    if (_pending.isEmpty && _recovery == null && _failure == null) {
      return const CameraReleaseResult.success();
    }
    final Future<CameraReleaseResult>? observedRecovery = _recovery;
    if (_pending.isNotEmpty) await _waitForPending();
    final Future<CameraReleaseResult>? activeRecovery =
        observedRecovery ?? _recovery;
    if (activeRecovery != null) {
      final result = await activeRecovery;
      await _waitForPending();
      return _failure ?? result;
    }
    final CameraReleaseResult? failure = _failure;
    if (failure == null) return const CameraReleaseResult.success();
    if (recover == null) return failure;

    final result = await _recover(recover);
    await _waitForPending();
    return _failure ?? result;
  }

  static Future<CameraReleaseResult> _recover(Future<void> Function() recover) {
    final Future<CameraReleaseResult>? existing = _recovery;
    if (existing != null) return existing;
    final int generation = _generation;
    final int failureVersion = _failureVersion;
    final completer = Completer<CameraReleaseResult>();
    final Future<CameraReleaseResult> shared = completer.future;
    _recovery = shared;
    final closing = hold(Future<void>.sync(recover));
    unawaited(
      closing.then<void>((result) {
        if (generation == _generation) {
          if (result.released && failureVersion == _failureVersion) {
            _failure = null;
          }
          if (identical(_recovery, shared)) _recovery = null;
        }
        completer.complete(result);
      }),
    );
    return shared;
  }

  static bool get isHolding => _pending.isNotEmpty || _recovery != null;
  static bool get requiresRecovery => _failure != null;

  /// Eski testin geç tamamlanan Future'ı yeni testin nöbetini değiştiremez.
  static void resetForTest() {
    _generation++;
    _pending.clear();
    _failure = null;
    _recovery = null;
    _failureVersion = 0;
  }
}
