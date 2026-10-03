import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_camera/motion_camera.dart';

import 'camera_release_latch.dart';
import 'package:motion_core/motion_core.dart' show FrameSize;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'content_repository.dart';
import 'account_connection.dart';
import 'account_store_epoch.dart';
import 'app_locale.dart';
import 'live_session.dart';
import 'live_strings.dart';
import 'pose_model.dart';
import 'theme.dart';

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
///
/// ## Giydirme turu (M-F-282, 2026-08-06) — bilerek YAPMADIKLARI
///
/// Tasarım panelinin `session` ekranı 5 fazlı (prep/hold/silence/unread/done,
/// tutuş-semantiğinde) bir durum makinesi çiziyor; bu ekranın GERÇEK hâli
/// dört tanedir ([LiveIdle]/[LiveStarting]/[LiveFailed]/[LiveRunning], REP
/// semantiğinde) ve YAPISAL olarak farklıdır. Koordinatör hükmü: dört gerçek
/// hâli tasarımın GÖRSEL diliyle giydir, 5-faz modelini UYGULAMA — o inşadır
/// (bkz. `docs/design/DESIGN-AHEAD-OF-CODE.md`, tasarım>kod).
///
/// Kamera önizlemesi de bilerek YOK — ama bu KALICI bir sınır DEĞİL
/// (koordinatör düzeltmesi, 2026-08-06): `70-KAMERA-KOPRUSU-SOZLESMESI.md`
/// §preview, `Texture`-tabanlı önizlemeyi ("kullanıcı kendini görmeli")
/// **bilinçli ERTELİYOR**, yasaklamıyor — erteleme koşulu ("zarf hattı
/// canlanmadan") artık karşılanmış olabilir. Preview'ı açmak bir ÇEKİRDEK
/// yetenek kararı ve koordinatörün kuyruğunda; bu ekranın kapsamı değil.
/// Bugün YOK olduğu için koyu zemin sahte bir kamera akışı İDDİA ETMİYOR.
///
/// 🔧 DÜZELTME (2026-08-07, 5-faz ölçümü sırasında): bu yorumun eski hâli
/// *"motor confidence ÖLÇMÜYOR"* diyordu. **FAZLA GENİŞ ve YANLIŞ.** Ölçüldü:
/// çekirdeğin `ConfidenceGate`'i ÜÇ motorun da (`rep_engine` · `hold_engine` ·
/// `multiphase_engine`) ilk kapısı ve `judgeable` üretiyor; hüküm veremeyen
/// kareler `skippedFrames`e sayılıyor. Yani ölçüm VAR — **kabuğa TAŞINMIYOR.**
/// Doğru sınır: bu ekran güveni GÖSTERMİYOR çünkü `LiveRunning` onu taşımıyor;
/// "ölçülemiyor" DEĞİL, "yüzeye çıkarılmamış". Kamera-önizlemesi iddiasıyla
/// aynı sınıf hata (bir sınırı geniş yazmak, dar yazmak kadar pahalı — ders 5).
class LiveSessionScreen extends StatefulWidget {
  const LiveSessionScreen({
    required this.config,
    this.accountUserId,
    this.controller,
    this.onSessionEnd,
    super.key,
  });

  final MovementConfig config;
  final String? accountUserId;

  /// Testlerin/harness'ın kendi denetleyicisini vermesi için. Üretimde null.
  final MotionCameraController? controller;

  /// Biten seansı yazan işlev — üretimde SERBEST kovaya
  /// (`ContentRepository.openFreeSessionStore`). Enjekte edilebilir olması
  /// testin `path_provider` olmadan yazılan KAYDIN İÇERİĞİNİ okuyabilmesi
  /// için: "yazma denendi mi" ile "doğru şey mi yazıldı" farklı sorular.
  final Future<void> Function(SessionRecord record)? onSessionEnd;

  static const Key startButtonKey = Key('live.start');
  static const Key openSettingsKey = Key('live.openSettings');
  static const Key stopButtonKey = Key('live.stop');
  static const Key failureKey = Key('live.failure');
  static const Key noPersonKey = Key('live.noPerson');
  static const Key repCountKey = Key('live.repCount');

  /// G-207 — biten seansın özeti.
  static const Key finishedKey = Key('live.finished');
  static const Key finishedRepCountKey = Key('live.finished.repCount');
  static const Key goAgainKey = Key('live.goAgain');

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen>
    with WidgetsBindingObserver {
  // Keep uncertainty across route/account rebuilds. A new controller must
  // never silently clear the native closure quarantine.
  static final MotionCameraController _defaultController =
      MotionCameraController();
  late final MotionCameraController _camera =
      widget.controller ?? _defaultController;

  LiveState _state = const LiveIdle();
  StreamSubscription<CameraFrameEnvelope>? _sub;
  bool _starting = false;
  bool _running = false;
  bool _stopping = false;
  bool _foreground = true;
  CameraCaptureLease? _capture;
  bool _closeUncertain = false;
  int _generation = 0;
  Future<CameraReleaseResult>? _releaseFuture;
  Future<void>? _finishFuture;
  SessionRecord? _pendingRecord;
  Future<void> Function(SessionRecord)? _pendingRecordSink;
  String? _pendingRecordUserId;
  AccountStoreEpoch? _captureStoreEpoch;
  AccountStoreEpoch? _pendingRecordEpoch;
  AccountConnection? _accountConnection;
  StreamSubscription<void>? _ownerSessionSubscription;
  String? _captureUserId;
  bool _accountRetired = false;
  bool _settingsRequested = false;
  int _permissionRefreshGeneration = 0;

  /// İzin **kalıcı olarak** engelli mi (`permanentlyDenied` ya da
  /// `restricted`). `LiveFailed` bunu taşıyamıyor: `CameraFailure` PİNLİ
  /// çekirdekte (`motion_camera`) ve pin 40-SHA kilitli — enum'a değer
  /// eklemek çekirdek turu kararıdır, bu ekranın kapsamı değil. Ayrım bu
  /// yüzden YEREL; yüzeyde ne değiştiği `LiveStrings`te yazılı.
  bool _permissionBlocked = false;

  /// Seansın GERÇEKTEN başladığı an — çalışılan süre buradan ölçülür.
  /// `LiveRunning` bunu taşımıyor; taşısaydı her karede kopyalanırdı.
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    if (CameraReleaseLatch.requiresRecovery) {
      _closeUncertain = true;
      _state = const LiveFailed(CameraFailure.closeUncertain);
    }
    WidgetsBinding.instance.addObserver(this);
    AccountStoreEpochRegistry.admissionChanges.addListener(
      _accountAdmissionChanged,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final connection = AccountScope.maybeOf(context)?.connection;
    if (!identical(connection, _accountConnection)) {
      if (_capture != null) _retireAccountCapture();
      _removeAccountListeners();
      _accountConnection = connection;
      _ownerSessionSubscription = connection?.ownerSessionChanges?.listen(
        (_) => _retireAccountCapture(),
        onError: (Object _, StackTrace __) => _retireAccountCapture(),
      );
      connection?.userId.addListener(_accountAdmissionChanged);
      connection?.passwordRecovery?.addListener(_accountAdmissionChanged);
      connection?.currentIdentityChanges?.addListener(_freshIdentityChanged);
      connection?.identityAdmissionChanges?.addListener(
        _accountAdmissionChanged,
      );
    }
    _accountAdmissionChanged();
  }

  void _removeAccountListeners() {
    unawaited(_ownerSessionSubscription?.cancel());
    _ownerSessionSubscription = null;
    _accountConnection?.userId.removeListener(_accountAdmissionChanged);
    _accountConnection?.passwordRecovery?.removeListener(
      _accountAdmissionChanged,
    );
    _accountConnection?.currentIdentityChanges?.removeListener(_freshIdentityChanged);
    _accountConnection?.identityAdmissionChanges?.removeListener(
      _accountAdmissionChanged,
    );
  }

  bool get _accountAdmissionOpen =>
      !_accountRetired &&
      (_capture != null || (_accountConnection?.isCurrentIdentityVerified?.call() ?? true)) &&
      _accountConnection?.passwordRecovery?.value != true &&
      (_accountConnection?.isIdentityAdmitted?.call() ?? true) &&
      !AccountStoreEpochRegistry.isAccountErasureBlocked(
        _captureUserId ??
            _accountConnection?.userId.value ??
            widget.accountUserId,
      );

  bool get _freshIdentityVerified =>
      _accountConnection?.isCurrentIdentityVerified?.call() ?? true;

  void _freshIdentityChanged() {
    // Proof loss only cancels a pending new native admission. A live owner
    // continues through ordinary refresh until an owner boundary retires it.
    if (!_starting || _freshIdentityVerified) {
      if (mounted) setState(() {});
      return;
    }
    _invalidateAttempt();
    if (mounted) setState(() => _state = const LiveIdle());
    unawaited(_releaseCamera().then<void>((result) {
      if (!result.released && mounted) {
        setState(() => _state = _failureFor(result.error!));
      }
    }));
  }

  void _accountAdmissionChanged() {
    if (_capture != null &&
        (!_accountAdmissionOpen ||
            (_accountConnection != null &&
                _accountConnection!.userId.value != _captureUserId))) {
      _retireAccountCapture();
    }
  }

  void _retireAccountCapture() {
    // Runtime signals are synchronous: fence native work before shell/UI pump.
    _capture?.retire();
    _accountRetired = true;
    _invalidateAttempt();
    _permissionRefreshGeneration++;
    if (mounted) setState(() => _state = const LiveIdle());
    unawaited(
      _releaseCamera().then<void>((result) {
        if (!result.released && mounted) {
          setState(() => _state = _failureFor(result.error!));
        }
      }),
    );
  }

  @override
  void didUpdateWidget(covariant LiveSessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountUserId != widget.accountUserId ||
        oldWidget.config.id != widget.config.id ||
        oldWidget.controller != widget.controller) {
      _capture?.retire();
      _invalidateAttempt();
      _permissionRefreshGeneration++;
      _state = const LiveIdle();
      // Account/route replacement releases only; it is not a completed set.
      unawaited(
        _releaseCamera().then<void>((result) {
          if (!result.released && mounted) {
            setState(() => _state = _failureFor(result.error!));
          }
        }),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Idle/failed ekranı inactive sırasında disabled Start çizmiş olabilir.
      // Foreground değişimi de UI durumudur; native kamera otomatik açılmaz.
      if (mounted && !_foreground) {
        setState(() => _foreground = true);
      } else {
        _foreground = true;
      }
      if (_permissionBlocked && _settingsRequested) {
        unawaited(_refreshPermission());
      }
      return;
    }
    final activeAttempt =
        _starting || (_capture != null && !_capture!.isRetired);
    _capture?.retire();
    _foreground = false;
    _permissionRefreshGeneration++;
    if (_stopping || _finishFuture != null) return;
    if (_running) {
      unawaited(_stop());
      return;
    }
    // Permission/model work has an owner before its first await. Returning
    // from inactive never revives that retired attempt; Start is explicit.
    if (activeAttempt) {
      _invalidateAttempt();
      final int generation = _generation;
      if (mounted) setState(() => _state = const LiveIdle());
      unawaited(
        _releaseCamera().then<void>((result) {
          if (!result.released && mounted && generation == _generation) {
            setState(() => _state = _failureFor(result.error!));
          }
        }),
      );
    }
  }

  @override
  void dispose() {
    _capture?.retire();
    _removeAccountListeners();
    AccountStoreEpochRegistry.admissionChanges.removeListener(
      _accountAdmissionChanged,
    );
    WidgetsBinding.instance.removeObserver(this);
    _foreground = false;
    _permissionRefreshGeneration++;
    _invalidateAttempt();
    // Owned close settles admitted start + native cancel + fresh readback.
    // Disposal and manual/background stop share this same safe result.
    unawaited(_releaseCamera().then<void>((_) {}));
    super.dispose();
  }

  bool _isCurrent(int generation) =>
      mounted && _foreground && generation == _generation &&
      (!_starting || _freshIdentityVerified);

  void _abandonUnadoptedStart(int generation) {
    if (mounted && generation == _generation) {
      setState(() => _state = const LiveIdle());
    }
  }

  void _invalidateAttempt() {
    _capture?.retire();
    _generation++;
    _starting = false;
    _running = false;
  }

  LiveFailed _failureFor(Object error) => error is CameraException
      ? LiveFailed(error.failure, detail: error.detail)
      : LiveFailed(null, detail: error.toString());

  Future<void> _cancelFrames(
    StreamSubscription<CameraFrameEnvelope>? subscription,
  ) async {
    try {
      await subscription?.cancel();
    } on Object catch (_) {
      // This is the lease's local app bus. Its late/paused cancellation must
      // neither delay native close nor reach a successor's raw channel.
    }
  }

  Future<CameraReleaseResult> _releaseCamera() {
    final CameraCaptureLease? capture = _capture;
    capture?.retire();
    final Future<CameraReleaseResult>? existing = _releaseFuture;
    if (existing != null) return existing;
    _stopping = true;
    final subscription = _sub;
    _sub = null;
    unawaited(_cancelFrames(subscription));
    // Only owned close controls replacement admission. Core drains its one
    // raw subscription and exact ACK/readback; app subscription is separate.
    final Future<CameraReleaseResult> closing = capture != null
        ? CameraReleaseLatch.hold(capture.close())
        : Future<CameraReleaseResult>.value(
            const CameraReleaseResult.success(),
          );
    final result = closing.then<CameraReleaseResult>((result) {
      if (identical(capture, _capture)) {
        void completeRelease() {
          _closeUncertain = !result.released;
          _stopping = false;
          if (!result.released) _state = _failureFor(result.error!);
        }

        if (mounted) {
          setState(completeRelease);
        } else {
          completeRelease();
        }
      }
      return result;
    });
    _releaseFuture = result;
    return result;
  }

  Future<void> _openSettings() async {
    _settingsRequested = true;
    try {
      if (!await openAppSettings()) _settingsRequested = false;
    } on Object catch (_) {
      // Kullanılabilir Settings eylemi kalır; izin verildi varsayılmaz.
    }
  }

  Future<void> _refreshPermission() async {
    final int refreshGeneration = ++_permissionRefreshGeneration;
    final int generation = _generation;
    try {
      final PermissionStatus permission = await Permission.camera.status;
      if (!_isCurrent(generation) ||
          refreshGeneration != _permissionRefreshGeneration ||
          !_permissionBlocked ||
          _starting ||
          _running) {
        return;
      }
      setState(() {
        _permissionBlocked =
            permission.isPermanentlyDenied || permission.isRestricted;
        if (permission.isGranted) {
          _settingsRequested = false;
          _state = const LiveIdle();
        } else {
          _state = LiveFailed(
            CameraFailure.permissionDenied,
            detail: 'permission_handler: ${permission.name}',
          );
        }
      });
    } on Object catch (_) {
      // Okuma başarısızsa eski engel korunur; native kamera otomatik açılmaz.
    }
  }

  /// Asset'i dosyaya yazar — plugin bundle değil YOL istiyor.
  Future<String> _modelPath() async {
    final Directory dir = await getApplicationSupportDirectory();
    final File f = File(
      '${dir.path}/${PoseModelPin.assetPath.split('/').last}',
    );
    if (!await f.exists()) {
      final ByteData data = await rootBundle.load(PoseModelPin.assetPath);
      await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return f.path;
  }

  Future<void> _start() async {
    // Buton henüz yeniden çizilmeden ikinci callback gelebilir. Nöbet ilk
    // await'ten önce alınır; UI'nın spinner çizmesine güvenilmez.
    if (!mounted ||
        !_foreground ||
        _starting ||
        _running ||
        _stopping ||
        _closeUncertain ||
        !_accountAdmissionOpen ||
        !_freshIdentityVerified ||
        CameraReleaseLatch.requiresRecovery ||
        _finishFuture != null) {
      return;
    }
    _starting = true;
    final int generation = ++_generation;
    // The actual Core lease exists before permission/model/latch awaits.
    // Retirement therefore fences every delayed pre-native continuation.
    final CameraCaptureLease capture = _camera.createCaptureLease();
    _capture = capture;
    _captureUserId = _accountConnection == null
        ? widget.accountUserId
        : _accountConnection!.userId.value;
    _releaseFuture = null;
    // Çalışılan süre BURADAN ölçülür: kullanıcı başlat'a bastığı andan
    // durdurduğu ana. Kamera açılış gecikmesi de dahil — "çalıştığın süre"
    // iddiası ancak ölçülebilir bir çıpaya dayanırsa dürüsttür.
    _startedAt = DateTime.now();
    setState(() => _state = const LiveStarting());
    try {
      // Capture this account lifetime before permission/model/native awaits.
      // A late manual close must not acquire a fresh same-UUID store epoch.
      _captureStoreEpoch = AccountStoreEpochRegistry.capture(_captureUserId);
      // İzin ÖNCE ve AÇIKÇA: reddedilirse adı olan bir hâl doğar, boş bir
      // ekran değil.
      final PermissionStatus perm = await Permission.camera.request();
      if (!_isCurrent(generation)) {
        _abandonUnadoptedStart(generation);
        return;
      }
      if (!perm.isGranted) {
        capture.retire();
        unawaited(_releaseCamera().then<void>((_) {}));
        if (!mounted) return;
        // ⭐ KALICI RET, GEÇİCİ RETTEN AYRILIYOR (G-185) — kural İCAT
        // EDİLMEDİ, Ostinato'nun ölçülmüş referansı: `isPermanentlyDenied ||
        // isRestricted`. `isRestricted` kritik ve sezgiyle bulunamaz:
        // MDM/ebeveyn denetimli cihazda izin diyaloğu HİÇ ÇIKMAZ, yani
        // "ikinci ret = kalıcı" sezgisi o vakayı İLKECE göremez.
        //
        // Neden gerekti (ölçüldü): üç hâl de `!isGranted` kovasına düşüyordu;
        // ekran "Settings'ten açabilirsin" yazıp SETTINGS'E GÖTÜREN HİÇBİR
        // kontrol sunmuyordu ve tek düğme `Start` idi — kalıcı rette o düğme
        // sonsuza dek AYNI hatayı üretirdi. Ölü son değil ama ÖLÜ DÖNGÜ.
        setState(() {
          _permissionBlocked = perm.isPermanentlyDenied || perm.isRestricted;
          // ⚠️ `detail` eskiden SABİT 'denied' dizgesiydi — gerçek durum
          // `permanentlyDenied` olsa bile "denied" diyordu. Artık OKUNAN
          // değerden geliyor: küçük ama gerçek bir yanlış beyan kapandı.
          _state = LiveFailed(
            CameraFailure.permissionDenied,
            detail: 'permission_handler: ${perm.name}',
          );
        });
        return;
      }
      _permissionBlocked = false;

      // ⚠️ ÖNCE uçmakta olan kapanışı bekle. Bu satır olmadan ikinci seans,
      // birincinin kapanışıyla yarışır ve `already-running` alır.
      final CameraReleaseResult release =
          await CameraReleaseLatch.awaitRelease();
      if (!_isCurrent(generation)) {
        _abandonUnadoptedStart(generation);
        return;
      }
      if (!release.released) {
        _closeUncertain = true;
        capture.retire();
        setState(() => _state = _failureFor(release.error!));
        return;
      }
      final String modelPath = await _modelPath();
      if (!_isCurrent(generation)) {
        _abandonUnadoptedStart(generation);
        return;
      }

      final CameraSessionInfo info = await capture.start(
        modelPath: modelPath,
        modelId: PoseModelPin.modelId,
        lens: CameraLens.back,
        initialPlan: PassPlan.uprightOnly,
      );
      if (!_isCurrent(generation)) {
        capture.retire();
        return;
      }
      final LiveSessionRunner runner = LiveSessionRunner(
        config: widget.config,
        // Kare boyutu OTURUMDAN gelir, sabit yazılmaz: izotropik düzeltme
        // buna bağlı ve yanlış boyut açıları sessizce kaydırır (J-028).
        frameSize: FrameSize(info.width, info.height),
      );
      final subscription = capture.frames().listen((CameraFrameEnvelope e) {
        if (!_isCurrent(generation)) return;
        try {
          runner.consume(e);
          if (_isCurrent(generation)) {
            setState(() => _state = runner.state);
          }
        } on Object catch (error) {
          _failCamera(error, generation);
        }
      }, onError: (Object error) => _failCamera(error, generation));
      if (!_isCurrent(generation)) {
        unawaited(_cancelFrames(subscription));
        return;
      }
      _sub = subscription;
      setState(() {
        _running = true;
        _state = runner.state;
      });
    } on Object catch (error) {
      if (_isCurrent(generation)) {
        _failCamera(error, generation);
      } else {
        _abandonUnadoptedStart(generation);
      }
    } finally {
      // Eski continuation yeni bir Start'ın nöbetini indiremez.
      if (generation == _generation) _starting = false;
    }
  }

  void _failCamera(Object error, int generation) {
    if (!_isCurrent(generation)) return;
    _invalidateAttempt();
    setState(() => _state = _failureFor(error));
    // Akış arızası Stop'u gizleyip kamerayı canlı bırakamaz. Kapanış sonucu
    // bu arıza yüzeyini silmez; tekrar yalnız açık bir Start ile mümkündür.
    unawaited(_releaseCamera().then<void>((_) {}));
  }

  Future<void> _stop() {
    final Future<void>? existing = _finishFuture;
    if (existing != null) return existing;
    if (!_running) return Future<void>.value();
    // Başarı/arıza UI'si ve geç kareler bu ölçümü değiştiremez. G-132/G-207:
    // gerçek kareli seans bir kez kaydedilir, sıfır kareli kayıt üretilmez.
    final LiveState current = _state;
    final LiveState snapshot = current is LiveRunning
        ? LiveRunning(
            reps: List<Rep>.unmodifiable(current.reps),
            personVisible: current.personVisible,
            framesSeen: current.framesSeen,
          )
        : current;
    final DateTime endedAt = DateTime.now();
    final DateTime startedAt = _startedAt ?? endedAt;
    _pendingRecord = buildFreeSessionRecord(
      movementId: widget.config.id,
      state: snapshot,
      startedAt: startedAt,
      endedAt: endedAt,
    );
    _pendingRecordSink = widget.onSessionEnd;
    _pendingRecordUserId = _captureUserId;
    _pendingRecordEpoch = _captureStoreEpoch;
    final LiveState finished = buildFinishedState(
      state: snapshot,
      startedAt: startedAt,
      endedAt: endedAt,
    );
    _invalidateAttempt();
    final int generation = _generation;
    final release = _releaseCamera();
    late final Future<void> finishing;
    finishing = _finishStoppedSession(release, finished, generation)
        .whenComplete(() {
          if (identical(_finishFuture, finishing)) _finishFuture = null;
        });
    _finishFuture = finishing;
    return finishing;
  }

  Future<void> _finishStoppedSession(
    Future<CameraReleaseResult> release,
    LiveState finished,
    int generation,
  ) async {
    final CameraReleaseResult result = await release;
    // Eski Stop semantiği korunur: kapanış hatası gerçek ölçüm kaydını
    // düşürmez. Kaydın varlığı kamera bırakıldı iddiası değildir.
    await _persistPendingRecord();
    _startedAt = null;
    if (mounted && generation == _generation) {
      setState(
        () => _state = result.released ? finished : _failureFor(result.error!),
      );
    }
  }

  /// Biten seansı SERBEST kovaya yazar (koordinatör hükmü G-132 + dar-kapsam).
  ///
  /// **Ne zaman YAZILMAZ:** kamera hiç kare vermediyse. O bir seans değil,
  /// başlatılamamış bir denemedir; sıfır-kareli kayıt geçmişi gürültüyle
  /// doldurur ve "bir şey yaptım" izlenimi verir.
  ///
  /// **Sıfır TEKRAR ama kare VARSA yazılır:** kamera çalıştı, kişi göründü,
  /// hiç tam tekrar sayılmadı — bu GERÇEK bir sonuçtur ve saklanması,
  /// silinmesinden dürüsttür.
  Future<void> _persistPendingRecord() async {
    final SessionRecord? record = _pendingRecord;
    final sink = _pendingRecordSink;
    final accountUserId = _pendingRecordUserId;
    final epoch = _pendingRecordEpoch;
    // Sink beklenmeden alınır: dispose/tekrar Stop aynı kaydı ikinci kez yazamaz.
    _pendingRecord = null;
    _pendingRecordSink = null;
    _pendingRecordUserId = null;
    _pendingRecordEpoch = null;
    if (record == null || _accountRetired) return;
    try {
      epoch?.checkCurrent();
      if (sink != null) {
        await sink(record);
      } else {
        final SessionStore store = await ContentRepository.openFreeSessionStore(
          accountUserId: accountUserId,
        );
        epoch?.checkCurrent();
        await store.append(record);
      }
    } on Object catch (_) {
      // Yazma başarısızlığı seansı BLOKLAMAZ ve sessizce "kaydedildi" de
      // demez: kullanıcı zaten sayacı gördü. Kalıcılık arızasının kendi
      // yüzeyi `HistoryStatus`ta (okuma tarafında) zaten var.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GravitaColors.sessionStage,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: GravitaColors.sessionInkOnDark,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        // ⭐ G-205: başlık İÇERİKTEN gelir, sabitten değil. Sabit `'Push-ups'`
        // iken açılan seans squat'tı (tek giriş `liveConfig` → `library.json`
        // sırasındaki İLK uygun hareket) — ekran yapılmayan hareketin adını
        // taşıyordu. Gerekçe ve kapı: `live_strings.dart` başındaki not.
        title: Text(
          catalogName(context, widget.config.id, widget.config.name),
          style: GravitaType.display(
            size: 18,
            color: GravitaColors.sessionInkOnDark,
          ),
        ),
      ),
      // Kamera-alanı görsel bir DOLGU — gerçek görüntü YOK (dosya doc
      // yorumu). Sahte bir "canlı" iddiası taşımasın diye etiketsiz.
      body: DecoratedBox(
        decoration: const BoxDecoration(color: GravitaColors.sessionCamera),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[_body()],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _body() => switch (_state) {
    LiveIdle() => _sheet(
      children: <Widget>[
        _sheetHeadline(
          localized(
            context,
            LiveStrings.idle,
            'Telefonu baştan topuğa görüneceğin şekilde, yaklaşık yandan bakacak biçimde yerleştir. Tekrarları sayar ve tempoyu ölçeriz; puan vermeyiz.',
          ),
        ),
        const SizedBox(height: 10),
        // ⭐ G-205: kapı cümlesi HAREKETE ÖZEL, içerikten. Özel cümlesi
        // olmayan hareket başka bir hareketin kapısını göstermektense
        // hiçbir kapı adı göstermez (yedek genel ve her zaman doğru).
        _sheetNote(_gateNote()),
        const SizedBox(height: 22),
        FilledButton(
          key: LiveSessionScreen.startButtonKey,
          onPressed:
              _starting ||
                  _stopping ||
                  !_foreground ||
                  _closeUncertain ||
                  CameraReleaseLatch.requiresRecovery ||
                  !_accountAdmissionOpen ||
                  !_freshIdentityVerified
              ? null
              : _start,
          child: Text(localized(context, LiveStrings.start, 'Başlat')),
        ),
      ],
    ),
    LiveStarting() => _sheet(
      children: <Widget>[
        const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: GravitaColors.accent,
          ),
        ),
        const SizedBox(height: 14),
        _sheetHeadline(
          localized(context, LiveStrings.starting, 'Kamera açılıyor…'),
        ),
      ],
    ),
    LiveFailed(:final CameraFailure? failure) => _sheet(
      key: LiveSessionScreen.failureKey,
      sealed: true,
      children: <Widget>[
        _sheetHeadline(
          _permissionBlocked
              ? localized(
                  context,
                  LiveStrings.permissionBlockedTitle,
                  'Kamera erişimi engellendi',
                )
              : localized(
                  context,
                  LiveStrings.failureTitle(failure),
                  _failureTitleTr(failure),
                ),
          color: GravitaColors.honestyText,
        ),
        const SizedBox(height: 10),
        _sheetNote(
          _permissionBlocked
              ? localized(
                  context,
                  LiveStrings.permissionBlockedBody,
                  'Sistem izin penceresini tekrar açmayacak. Kamera erişimini Ayarlar’dan açman gerekiyor. Hiçbir şey kaydedilmez veya yüklenmez; video bu cihazda kalır. Derslerin ve geçmişin etkilenmez.',
                )
              : localized(
                  context,
                  LiveStrings.failureBody(failure),
                  _failureBodyTr(failure),
                ),
          color: GravitaColors.honestyText,
        ),
        const SizedBox(height: 22),
        // Kalıcı engelde `Start` ÇİZİLMEZ: basılabilir ama ASLA
        // başarılı olamayacak bir kontrol, ölü butondan farksızdır
        // (ürünün kendi kuralı: "arkasında bir şey olmayan giriş
        // çizme"). Yerine gerçekten işe yarayan TEK eylem konuyor.
        if (_permissionBlocked)
          FilledButton(
            key: LiveSessionScreen.openSettingsKey,
            onPressed: _stopping ? null : _openSettings,
            child: Text(
              localized(context, LiveStrings.openSettings, 'Ayarları aç'),
            ),
          )
        else
          FilledButton(
            key: LiveSessionScreen.startButtonKey,
            onPressed:
                _starting ||
                    _stopping ||
                    !_foreground ||
                    _closeUncertain ||
                    CameraReleaseLatch.requiresRecovery ||
                    !_accountAdmissionOpen ||
                  !_freshIdentityVerified
                ? null
                : _start,
            child: Text(localized(context, LiveStrings.start, 'Başlat')),
          ),
      ],
    ),
    LiveRunning(
      :final int framesSeen,
      :final bool personVisible,
      :final List<Rep> reps,
    ) =>
      _sheet(
        children: <Widget>[
          if (!personVisible)
            _sheetHeadline(
              localized(
                context,
                LiveStrings.noPerson,
                'Kadrajda kimse görünmüyor. Başından topuğuna kadar kadraja gir.',
              ),
              key: LiveSessionScreen.noPersonKey,
            ),
          if (personVisible || reps.isNotEmpty) ...<Widget>[
            Text(
              reps.isEmpty
                  ? localized(
                      context,
                      LiveStrings.noRepsYet,
                      'Tam tekrar sayılmadı.',
                    )
                  : localized(
                      context,
                      LiveStrings.reps(reps.length),
                      '${reps.length} tekrar',
                    ),
              key: LiveSessionScreen.repCountKey,
              style: GravitaType.display(size: 40, color: GravitaColors.ink),
            ),
            const SizedBox(height: 6),
            _sheetNote(
              localized(
                context,
                LiveStrings.countingNote,
                'Sayılır, puanlanmaz.',
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Güven DEĞERİ burada UYDURULMUYOR — ama "ölçülmüyor" da değil:
          // motor `ConfidenceGate` ile hüküm veremediği kareleri
          // `skippedFrames`e sayıyor. O sayacı yüzeye taşımak bir ÜRÜN
          // kararı (koordinatör kuyruğunda, 5-faz ölçümüyle birlikte);
          // bugün görünen tek ek bilgi zaten var olan kare sayacı.
          Text(
            localized(context, '$framesSeen frames', '$framesSeen kare'),
            style: GravitaType.mono(
              size: 10.5,
              color: GravitaColors.sessionInkMutedOnDark,
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            key: LiveSessionScreen.stopButtonKey,
            onPressed: _stopping || _finishFuture != null ? null : _stop,
            child: Text(localized(context, LiveStrings.stop, 'Durdur')),
          ),
        ],
      ),
    // ⭐ G-207 — SONUÇ. Yeni bir görsel dil YOK: aynı `_sheet`, aynı
    // tipografi. Değişen tek şey, ölçülen sayıların bitişte ekranda
    // KALMASI.
    LiveFinished(
      :final int repCount,
      :final bool sawFrames,
      :final Duration elapsed,
    ) =>
      _sheet(
        key: LiveSessionScreen.finishedKey,
        children: <Widget>[
          // "Hiç kare gelmedi" ile "izledik, tam tekrar çıkmadı" AYRI
          // cümleler: biri ölçüm yokluğu, öteki gerçek bir ölçüm sonucu.
          if (!sawFrames) ...<Widget>[
            _sheetHeadline(
              localized(
                context,
                LiveStrings.finishedNoFrames,
                'Hiçbir şey kaydedilmedi.',
              ),
            ),
            const SizedBox(height: 10),
            _sheetNote(
              localized(
                context,
                LiveStrings.finishedNoFramesNote,
                'Kameradan hiç kare gelmedi. Gösterilecek bir sonuç yok ve geçmişine bir şey eklenmedi.',
              ),
            ),
          ] else ...<Widget>[
            _sheetHeadline(
              localized(context, LiveStrings.finishedTitle, 'Set bitti'),
            ),
            const SizedBox(height: 14),
            Text(
              repCount == 0
                  ? localized(
                      context,
                      LiveStrings.finishedNoReps,
                      'Tam tekrar sayılmadı.',
                    )
                  : localized(
                      context,
                      LiveStrings.reps(repCount),
                      '$repCount tekrar',
                    ),
              key: LiveSessionScreen.finishedRepCountKey,
              style: GravitaType.display(size: 40, color: GravitaColors.ink),
            ),
            const SizedBox(height: 8),
            if (repCount == 0)
              _sheetNote(
                localized(
                  context,
                  LiveStrings.finishedNoRepsNote,
                  'Kamera çalıştı ancak tam bir tekrar görülmedi. Yarım ve doğrulanamayan tekrarlar tahmin edilerek sayılmaz.',
                ),
              )
            else ...<Widget>[
              _sheetNote(
                localized(
                  context,
                  LiveStrings.finishedDuration(elapsed),
                  '${elapsed.inMinutes} dk ${elapsed.inSeconds % 60} sn',
                ),
              ),
              // Tempo YALNIZ tekrar varken çizilir: sıfır tekrarda
              // gösterilecek bir iniş/çıkış süresi yoktur ve "0,0s"
              // basmak ölçülmemiş bir şeyi ölçülmüş gibi gösterirdi.
              if (_tempoText() case final String t) _sheetNote(t),
            ],
            const SizedBox(height: 10),
            _sheetNote(
              localized(
                context,
                LiveStrings.finishedNote,
                'Sayılır, puanlanmaz.',
              ),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton(
            key: LiveSessionScreen.goAgainKey,
            onPressed: () => setState(() => _state = const LiveIdle()),
            child: Text(
              localized(context, LiveStrings.goAgain, 'Yeniden başlat'),
            ),
          ),
        ],
      ),
  };

  /// Tempo satırı — ölçüm yoksa `null` ve satır HİÇ çizilmez.
  String? _tempoText() {
    final LiveState s = _state;
    if (s is! LiveFinished) return null;
    final ({Duration ascent, Duration descent})? t = s.tempo;
    if (t == null) return null;
    final String english = LiveStrings.finishedTempo(t.descent, t.ascent);
    final String down = (t.descent.inMilliseconds / 1000).toStringAsFixed(1);
    final String up = (t.ascent.inMilliseconds / 1000).toStringAsFixed(1);
    return localized(
      context,
      english,
      '$down sn iniş · $up sn çıkış (ortanca)',
    );
  }

  String _gateNote() {
    final String english =
        widget.config.contract.gateNote ?? LiveStrings.gateNoteFallback;
    final String turkish = switch (widget.config.id) {
      'bodyweight_squat' =>
        'Tekrarı yalnızca kalça ve diz birlikte hareket ettiğinde sayarız. Bu, gerçek bir squat hareketini yalnızca diz bükmekten ayırır. Doğrulanamayan tekrarlar tahmin edilerek sayılmaz.',
      'push_up' =>
        'Tekrarı yalnızca gövdenin yatay olduğunu görebildiğimizde sayarız. Bu, gerçek bir şınavı yalnızca dirsek bükmekten ayırır. Doğrulanamayan tekrarlar tahmin edilerek sayılmaz.',
      _ =>
        'Yalnızca doğrulayabildiğimiz tekrarları sayarız. Doğrulanamayanları tahmin ederek eklemeyiz.',
    };
    return localized(context, english, turkish);
  }

  String _failureTitleTr(CameraFailure? failure) => switch (failure) {
    CameraFailure.permissionDenied => 'Kamera erişimi kapalı',
    CameraFailure.modelLoadFailed => 'Poz modeli yüklenemedi',
    CameraFailure.alreadyRunning => 'Bir seans zaten çalışıyor',
    CameraFailure.notRunning => 'Çalışan seans yok',
    CameraFailure.lifecycleUnavailable => 'Kamera henüz hazır değil',
    CameraFailure.sessionInterrupted => 'Kamera seansı kesildi',
    CameraFailure.ownedProtocolUnavailable =>
      'Kamera köprüsü güncelleme istiyor',
    CameraFailure.closeUncertain => 'Kamera kapanışı doğrulanamadı',
    CameraFailure.noSuchCamera => 'Kamera başlatılamadı',
    null => 'Kamera bilinmeyen bir nedenle durdu',
  };

  String _failureBodyTr(CameraFailure? failure) => switch (failure) {
    CameraFailure.permissionDenied =>
      'Gravita tekrarları saymak için kameraya ihtiyaç duyar. Erişimi Ayarlar’dan açabilirsin. Video kaydedilmez, yüklenmez ve bu cihazdan çıkmaz.',
    CameraFailure.modelLoadFailed =>
      'Uygulamayla gelen poz modeli açılamadı. Yeniden yüklemek genellikle sorunu çözer. Derslerin ve geçmişin etkilenmez.',
    CameraFailure.alreadyRunning =>
      'Aynı anda yalnızca bir kamera seansı çalışır. Diğerini durdurduğunda yeniden deneyebilirsin.',
    CameraFailure.notRunning =>
      'Durdurmayı denediğimizde seans zaten durmuştu. Veri kaybı olmadı.',
    CameraFailure.lifecycleUnavailable =>
      'Kamera bu ekranda henüz başlatılamıyor. Uygulamaya dönüp yeniden deneyebilirsin.',
    CameraFailure.sessionInterrupted =>
      'Kamera seansı hazır olmadan kesildi. Bu ekranı yeniden açıp deneyebilirsin.',
    CameraFailure.ownedProtocolUnavailable =>
      'Bu sürüm kamera sahipliğini doğrulayamıyor. Kamera kapalı kalır; güncel bir sürüm gerekir. Derslerin ve geçmişin etkilenmez.',
    CameraFailure.closeUncertain =>
      'Kamera ve poz modelinin kapandığı doğrulanamadı. Yeni kamera seansı açılmayacak. Derslerin ve geçmişin etkilenmez.',
    CameraFailure.noSuchCamera =>
      'Kamera bu cihazda açılamadı. Yeniden deneyebilirsin; bu denemede seans kaydedilmedi. Derslerin ve geçmişin etkilenmez.',
    null =>
      'Kamera beklenmedik biçimde durdu. Yeniden deneyebilirsin. Derslerin ve geçmişin etkilenmez.',
  };

  // Sheet zemini AÇIK (design: `rgba(255,253,252,…)` üstte), yalnız kamera
  // arkaplanı koyu — o yüzden buradaki varsayılan renkler ink/secondary'dir,
  // sessionInkOnDark DEĞİL (o yalnız AppBar'ın dosdoğru koyu zemin üstündeki
  // metni için; sheet'in kendisi zaten AÇIK bir yüzey).
  Widget _sheetHeadline(String text, {Color? color, Key? key}) => Text(
    text,
    key: key,
    style: GravitaType.display(size: 22, color: color ?? GravitaColors.ink),
  );

  Widget _sheetNote(String text, {Color? color}) => Text(
    text,
    style: GravitaType.body(
      size: 13.5,
      color: color ?? GravitaColors.textSecondary,
      height: 1.55,
    ),
  );

  /// Tasarımın "bottom sheet" kartı — koyu zemin üstünde tek istisna
  /// olduğu için [GravitaCard]'a değil, doğrudan bu ekrana ait yerel bir
  /// kabuğa taşınıyor (paylaşılan bir birincil olmayı hak edecek ikinci bir
  /// kullanım yok, M-F-282 aşırı-soyutlama kaçınması).
  Widget _sheet({
    required List<Widget> children,
    bool sealed = false,
    Key? key,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        color: sealed
            ? GravitaColors.sessionSheetSealed
            : GravitaColors.surfaceTop,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: sealed
            ? const Border(
                top: BorderSide(color: GravitaColors.honestySeal, width: 2),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
