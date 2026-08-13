import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_camera/motion_camera.dart';

import 'camera_release_latch.dart';
import 'package:motion_core/motion_core.dart' show FrameSize;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'content_repository.dart';
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
    this.controller,
    this.onSessionEnd,
    super.key,
  });

  final MovementConfig config;

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

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {

  late final MotionCameraController _camera =
      widget.controller ?? MotionCameraController();

  LiveState _state = const LiveIdle();
  StreamSubscription<CameraFrameEnvelope>? _sub;
  bool _running = false;

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
  void dispose() {
    unawaited(_sub?.cancel());
    // ⭐ C-195: kapanış nöbeti BURADA kuruluyor — senkron, çünkü `dispose`
    // senkron ve kilit bir sonraki `start`tan ÖNCE görünür olmalı.
    if (_running) CameraReleaseLatch.hold(_camera.stop());
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
    // Çalışılan süre BURADAN ölçülür: kullanıcı başlat'a bastığı andan
    // durdurduğu ana. Kamera açılış gecikmesi de dahil — "çalıştığın süre"
    // iddiası ancak ölçülebilir bir çıpaya dayanırsa dürüsttür.
    _startedAt = DateTime.now();
    setState(() => _state = const LiveStarting());
    try {
      // İzin ÖNCE ve AÇIKÇA: reddedilirse adı olan bir hâl doğar, boş bir
      // ekran değil.
      final PermissionStatus perm = await Permission.camera.request();
      if (!perm.isGranted) {
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
          _state = LiveFailed(CameraFailure.permissionDenied,
              detail: 'permission_handler: ${perm.name}');
        });
        return;
      }
      _permissionBlocked = false;

      // ⚠️ ÖNCE uçmakta olan kapanışı bekle. Bu satır olmadan ikinci seans,
      // birincinin kapanışıyla yarışır ve `already-running` alır.
      await CameraReleaseLatch.awaitRelease();

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
    // ⭐ G-132: seans KAYDEDİLİR. Bu satırlardan önce `_stop()` aboneliği
    // iptal edip `LiveIdle`a dönüyordu ve o seansın tekrarları ATILIYORDU —
    // yani Progress ekranı hiçbir zaman gerçek bir seans göremezdi ve
    // `HistoryStatus` makinesinin tamamı hiçbir şeyin yazmadığı bir dosyayı
    // okuyordu.
    await _persist();
    if (!mounted) return;
    setState(() {
      _running = false;
      _state = const LiveIdle();
      _startedAt = null;
    });
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
  Future<void> _persist() async {
    final SessionRecord? record = buildFreeSessionRecord(
      movementId: widget.config.id,
      state: _state,
      startedAt: _startedAt ?? DateTime.now(),
      endedAt: DateTime.now(),
    );
    if (record == null) return;
    try {
      final Future<void> Function(SessionRecord)? sink = widget.onSessionEnd;
      if (sink != null) {
        await sink(record);
      } else {
        final SessionStore store =
            await ContentRepository.openFreeSessionStore();
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
        // ⭐ G-205: başlık İÇERİKTEN gelir, sabitten değil. Sabit `'Push-ups'`
        // iken açılan seans squat'tı (tek giriş `liveConfig` → `library.json`
        // sırasındaki İLK uygun hareket) — ekran yapılmayan hareketin adını
        // taşıyordu. Gerekçe ve kapı: `live_strings.dart` başındaki not.
        title: Text(widget.config.name,
            style:
                GravitaType.display(size: 18, color: GravitaColors.sessionInkOnDark)),
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
              _sheetHeadline(LiveStrings.idle),
              const SizedBox(height: 10),
              // ⭐ G-205: kapı cümlesi HAREKETE ÖZEL, içerikten. Özel cümlesi
              // olmayan hareket başka bir hareketin kapısını göstermektense
              // hiçbir kapı adı göstermez (yedek genel ve her zaman doğru).
              _sheetNote(widget.config.contract.gateNote ??
                  LiveStrings.gateNoteFallback),
              const SizedBox(height: 22),
              FilledButton(
                key: LiveSessionScreen.startButtonKey,
                onPressed: _start,
                child: const Text(LiveStrings.start),
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
              _sheetHeadline(LiveStrings.starting),
            ],
          ),
        LiveFailed(:final CameraFailure? failure, :final String? detail) => _sheet(
            key: LiveSessionScreen.failureKey,
            sealed: true,
            children: <Widget>[
              _sheetHeadline(
                  _permissionBlocked
                      ? LiveStrings.permissionBlockedTitle
                      : LiveStrings.failureTitle(failure),
                  color: GravitaColors.honestyText),
              const SizedBox(height: 10),
              _sheetNote(
                  _permissionBlocked
                      ? LiveStrings.permissionBlockedBody
                      : LiveStrings.failureBody(failure),
                  color: GravitaColors.honestyText),
              if (detail != null) ...<Widget>[
                const SizedBox(height: 16),
                // Ayrıntı GİZLENMEZ, İKİNCİLLEŞTİRİLİR (G-102).
                Text(LiveStrings.detailLabel,
                    style: GravitaType.mono(
                        size: 10, color: GravitaColors.honestyText)),
                const SizedBox(height: 4),
                Text(detail,
                    style: GravitaType.mono(
                        size: 11, color: GravitaColors.honestyText)),
              ],
              const SizedBox(height: 22),
              // Kalıcı engelde `Start` ÇİZİLMEZ: basılabilir ama ASLA
              // başarılı olamayacak bir kontrol, ölü butondan farksızdır
              // (ürünün kendi kuralı: "arkasında bir şey olmayan giriş
              // çizme"). Yerine gerçekten işe yarayan TEK eylem konuyor.
              if (_permissionBlocked)
                FilledButton(
                  key: LiveSessionScreen.openSettingsKey,
                  onPressed: openAppSettings,
                  child: const Text(LiveStrings.openSettings),
                )
              else
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
          _sheet(
            children: <Widget>[
              if (!personVisible)
                _sheetHeadline(LiveStrings.noPerson,
                    key: LiveSessionScreen.noPersonKey),
              if (personVisible || reps.isNotEmpty) ...<Widget>[
                Text(
                  reps.isEmpty ? LiveStrings.noRepsYet : LiveStrings.reps(reps.length),
                  key: LiveSessionScreen.repCountKey,
                  style: GravitaType.display(size: 40, color: GravitaColors.ink),
                ),
                const SizedBox(height: 6),
                _sheetNote(LiveStrings.countingNote),
              ],
              const SizedBox(height: 10),
              // Güven DEĞERİ burada UYDURULMUYOR — ama "ölçülmüyor" da değil:
              // motor `ConfidenceGate` ile hüküm veremediği kareleri
              // `skippedFrames`e sayıyor. O sayacı yüzeye taşımak bir ÜRÜN
              // kararı (koordinatör kuyruğunda, 5-faz ölçümüyle birlikte);
              // bugün görünen tek ek bilgi zaten var olan kare sayacı.
              Text('$framesSeen frames',
                  style: GravitaType.mono(
                      size: 10.5, color: GravitaColors.sessionInkMutedOnDark)),
              const SizedBox(height: 22),
              FilledButton(
                key: LiveSessionScreen.stopButtonKey,
                onPressed: _stop,
                child: const Text(LiveStrings.stop),
              ),
            ],
          ),
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
            size: 13.5, color: color ?? GravitaColors.textSecondary, height: 1.55),
      );

  /// Tasarımın "bottom sheet" kartı — koyu zemin üstünde tek istisna
  /// olduğu için [GravitaCard]'a değil, doğrudan bu ekrana ait yerel bir
  /// kabuğa taşınıyor (paylaşılan bir birincil olmayı hak edecek ikinci bir
  /// kullanım yok, M-F-282 aşırı-soyutlama kaçınması).
  Widget _sheet({required List<Widget> children, bool sealed = false, Key? key}) {
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
                top: BorderSide(color: GravitaColors.honestySeal, width: 2))
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
