import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motion_content/motion_content.dart';
import 'package:video_player/video_player.dart';

import 'calisthenics_course.dart';
import 'flutter_bundle_content_asset_reader.dart';
import 'gravita_source_projection_pin.dart';

const String _courseAssetPath = GravitaSourceProjectionPin.coursePath;
const String _productionIndexSha256 =
    GravitaSourceProjectionPin.sourceManifestSha256;
const String _courseSourceSha256 = GravitaSourceProjectionPin.courseSha256;
const String _sourceCatalogSha256 =
    GravitaSourceProjectionPin.sourceCatalogSha256;
const String _sourceProofSha256 =
    'dec615e14881b86b7676e1157f63b8bf6269026d856e59f2ee3a65d7f97e512a';
// This QA allowlist is kept out of pubspec assets. Production uses an empty
// catalog; synthetic tests inject exact bytes through their AssetBundle.
const String _qaSourcePinsPath =
    'content/courses/calisthenics.media-source-pins.v2k.v1.json';
const String _qaSourcePinsSha256 =
    '55a616756f126d0c95fc5127df1b76725c975111014571fcc7ebfd2c0a759843';
const int _maxVideoBytes = 64 * 1024 * 1024;
const int _maxCaptionBytes = 1024 * 1024;
const int _maxMediaBytes = 512 * 1024 * 1024;
const Duration _nativeRetireDeadline = Duration(seconds: 2);
bool _nativePlaybackUnconfirmed = false;
Completer<void>? _nativeSlotOwner;

Future<bool> _takeNativeSlot() async {
  while (!_nativePlaybackUnconfirmed) {
    final owner = _nativeSlotOwner;
    if (owner == null) {
      _nativeSlotOwner = Completer<void>();
      return true;
    }
    await owner.future;
  }
  return false;
}

void _releaseNativeSlot() {
  final owner = _nativeSlotOwner;
  _nativeSlotOwner = null;
  owner?.complete();
}

/// Models a fresh OS process between independent widget-test scenarios.
/// The production app never calls this test seam after an uncertain close.
@visibleForTesting
void resetLessonMediaNativeProcessForTesting() {
  if (_nativeSlotOwner != null) {
    throw StateError('Cannot reset an occupied native media slot');
  }
  _nativePlaybackUnconfirmed = false;
}

final RegExp _sha = RegExp(r'^[0-9a-f]{64}$');
final RegExp _cueTime = RegExp(
  r'^(\d{2,}):([0-5]\d):([0-5]\d)\.(\d{3}) --> (\d{2,}):([0-5]\d):([0-5]\d)\.(\d{3})$',
);

/// Describes one future, packaged MP4 and its bilingual WebVTT sidecars.
/// This is byte metadata, not an educator, rights, or release acceptance.
@immutable
final class LessonMediaFile {
  const LessonMediaFile({
    required this.path,
    required this.bytes,
    required this.sha256,
  });

  final String path;
  final int bytes;
  final String sha256;
}

@immutable
final class LessonMediaCandidate {
  LessonMediaCandidate({
    required this.app,
    required this.lessonId,
    required this.lessonCanonicalSha256,
    required this.assetId,
    required this.courseVersion,
    required this.courseSourceSha256,
    required this.productionIndexSha256,
    required this.sceneId,
    required this.variantStem,
    required this.productionSpecSha256,
    required this.sourceCueSha256,
    required this.idempotencyKey,
    required this.productionState,
    required this.sourcePinSha256,
    required this.durationMs,
    required this.video,
    required Map<String, LessonMediaFile> captions,
  }) : captions = Map<String, LessonMediaFile>.unmodifiable(captions);

  final String app;
  final String lessonId;
  final String lessonCanonicalSha256;
  final String assetId;
  final String courseVersion;
  final String courseSourceSha256;
  final String productionIndexSha256;
  final String sceneId;
  final String variantStem;
  final String productionSpecSha256;
  final String sourceCueSha256;
  final String idempotencyKey;
  final String productionState;
  final String sourcePinSha256;
  final int durationMs;
  final LessonMediaFile video;
  final Map<String, LessonMediaFile> captions;
}

@immutable
final class InspectedLessonMedia {
  const InspectedLessonMedia(this.candidate, this.captionText);

  final LessonMediaCandidate candidate;
  final String captionText;

  /// Inspection can never promote a staging candidate to a release asset.
  bool get releaseEligible => false;
  int get progressEffect => 0;
}

/// The production catalog is deliberately empty. Only widget tests can inject
/// candidates; a future release must generate its catalog from an independently
/// signed acceptance root and the complete packaged-asset inventory.
final class LessonMediaCatalog {
  const LessonMediaCatalog.empty()
    : _candidates = const <LessonMediaCandidate>[];

  @visibleForTesting
  LessonMediaCatalog.syntheticForTesting(List<LessonMediaCandidate> candidates)
    : _candidates = List<LessonMediaCandidate>.unmodifiable(candidates);

  final List<LessonMediaCandidate> _candidates;

  bool get isEmpty => _candidates.isEmpty;

  Future<InspectedLessonMedia?> inspect({
    required AssetBundle bundle,
    required CalisthenicsCourse course,
    required String lessonId,
    required String sceneId,
    required String variantStem,
    required String locale,
  }) async {
    if (kReleaseMode ||
        _candidates.isEmpty ||
        (locale != 'tr' && locale != 'en')) {
      return null;
    }
    final matches = _candidates.where(
      (c) =>
          c.lessonId == lessonId &&
          c.sceneId == sceneId &&
          c.variantStem == variantStem,
    );
    if (matches.length != 1 || !_catalogBudgetIsSafe()) return null;
    final c = matches.single;
    if (course.id != 'calisthenics-foundations' ||
        !course.lessons.any((lesson) => lesson.id == lessonId) ||
        c.app != 'gravita' ||
        c.courseVersion != course.version ||
        c.productionIndexSha256 != _productionIndexSha256 ||
        c.courseSourceSha256 != _courseSourceSha256 ||
        !_sha.hasMatch(c.lessonCanonicalSha256) ||
        !_sha.hasMatch(c.productionSpecSha256) ||
        !_sha.hasMatch(c.sourceCueSha256) ||
        !_sha.hasMatch(c.sourcePinSha256) ||
        c.idempotencyKey != 'motion-media-v1:${c.productionSpecSha256}' ||
        c.assetId.isEmpty ||
        !c.sceneId.startsWith('gravita:$lessonId:') ||
        c.sceneId.split(':').length != 3 ||
        c.sceneId.split(':').last.isEmpty ||
        c.variantStem.isEmpty ||
        c.durationMs <= 0 ||
        c.captions.keys.toSet().difference(const <String>{
          'tr',
          'en',
        }).isNotEmpty ||
        c.captions.length != 2 ||
        !_fileShape(
          c.video,
          'content/media/${c.variantStem}.mp4',
          _maxVideoBytes,
        )) {
      return null;
    }
    for (final entry in c.captions.entries) {
      if (!_fileShape(
        entry.value,
        'content/media/${c.variantStem}.${entry.key}.vtt',
        _maxCaptionBytes,
      )) {
        return null;
      }
    }
    try {
      final reader = FlutterBundleContentAssetReader(bundle: bundle);
      final sourcePinBytes = await reader.read(_qaSourcePinsPath);
      if (!_qaSourcePinMatches(c, sourcePinBytes)) return null;
      final courseBytes = await reader.read(_courseAssetPath);
      if (computeSha256Hex(courseBytes) != c.courseSourceSha256) return null;
      final videoBytes = await reader.read(c.video.path);
      if (!_bytesMatch(videoBytes, c.video) ||
          videoBytes.length < 12 ||
          String.fromCharCodes(videoBytes.sublist(4, 8)) != 'ftyp') {
        return null;
      }
      String? selectedCaption;
      for (final entry in c.captions.entries) {
        final captionBytes = await reader.read(entry.value.path);
        if (!_bytesMatch(captionBytes, entry.value)) return null;
        final text = utf8.decode(captionBytes, allowMalformed: false);
        if (!text.startsWith('WEBVTT - Motion locale=${entry.key}\n') ||
            !text.contains(' --> ') ||
            !_captionTrackFitsDuration(text, entry.key, c.durationMs)) {
          return null;
        }
        if (entry.key == locale) selectedCaption = text;
      }
      if (selectedCaption == null) return null;
      return InspectedLessonMedia(c, selectedCaption);
    } on Object {
      // Missing or altered packaged bytes leave the written lesson available.
      return null;
    }
  }

  bool _catalogBudgetIsSafe() {
    var total = 0;
    final paths = <String>{};
    final keys = <String>{};
    for (final c in _candidates) {
      if (!keys.add('${c.lessonId}\u0000${c.sceneId}\u0000${c.variantStem}')) {
        return false;
      }
      if (!_fileShape(
            c.video,
            'content/media/${c.variantStem}.mp4',
            _maxVideoBytes,
          ) ||
          c.captions.length != 2 ||
          !c.captions.keys.toSet().containsAll(const <String>{'tr', 'en'})) {
        return false;
      }
      for (final caption in c.captions.entries) {
        if (!_fileShape(
          caption.value,
          'content/media/${c.variantStem}.${caption.key}.vtt',
          _maxCaptionBytes,
        )) {
          return false;
        }
      }
      for (final file in <LessonMediaFile>[c.video, ...c.captions.values]) {
        if (!paths.add(file.path) ||
            file.bytes <= 0 ||
            file.bytes > _maxMediaBytes - total) {
          return false;
        }
        total += file.bytes;
      }
    }
    return true;
  }
}

Map<String, dynamic>? _uniquePinRow(Object? rows, String key, String value) {
  if (rows is! List) return null;
  final matches = rows
      .whereType<Map<String, dynamic>>()
      .where((row) => row[key] == value)
      .toList(growable: false);
  return matches.length == 1 ? matches.single : null;
}

bool _qaSourcePinMatches(LessonMediaCandidate c, Uint8List bytes) {
  if (computeSha256Hex(bytes) != _qaSourcePinsSha256) return false;
  try {
    final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
    if (decoded is! Map<String, dynamic> ||
        decoded['schemaVersion'] != 1 ||
        decoded['kind'] != 'GRAVITA_V2K_QA_SOURCE_PINS_V1' ||
        decoded['state'] != 'QA_SOURCE_MEMBERSHIP_ONLY_NO_MEDIA' ||
        decoded['sourceCatalogSHA256'] != _sourceCatalogSha256 ||
        decoded['manifestSHA256'] != _productionIndexSha256 ||
        decoded['sourceProofSHA256'] != _sourceProofSha256 ||
        decoded['courseSourceSHA256'] != _courseSourceSha256 ||
        decoded['visible'] != false ||
        decoded['releaseEligible'] != false ||
        decoded['progressEffect'] != 0) {
      return false;
    }
    final counts = decoded['counts'];
    final holds = decoded['holds'];
    if (counts is! Map ||
        counts['lessons'] != 56 ||
        counts['scenes'] != 392 ||
        counts['variants'] != 392 ||
        counts['heldScenes'] != 1 ||
        counts['mediaAccepted'] != 0 ||
        holds is! List ||
        holds.length != 1 ||
        holds.single is! Map ||
        (holds.single as Map)['sceneId'] != 'gravita:cal-01:full_sequence-03' ||
        (holds.single as Map)['status'] != 'HOLD_VERIFIED_EQUIPMENT') {
      return false;
    }
    final lesson = _uniquePinRow(decoded['lessons'], 'lessonId', c.lessonId);
    if (lesson == null ||
        lesson['app'] != c.app ||
        lesson['courseSourceSHA256'] != c.courseSourceSha256 ||
        lesson['lessonCanonicalSHA256'] != c.lessonCanonicalSha256 ||
        lesson['assetId'] != c.assetId ||
        lesson['membershipStatus'] != 'SOURCE_PINNED_TEST_ONLY') {
      return false;
    }
    final scene = _uniquePinRow(lesson['scenes'], 'sceneId', c.sceneId);
    if (scene == null ||
        scene['productionSpecSHA256'] != c.productionSpecSha256 ||
        scene['sourceCueSHA256'] != c.sourceCueSha256 ||
        scene['idempotencyKey'] != c.idempotencyKey ||
        scene['productionState'] != c.productionState ||
        scene['productionState'] != 'PREPRODUCTION_UNGENERATED') {
      return false;
    }
    final variant = _uniquePinRow(scene['variants'], 'stem', c.variantStem);
    return variant != null && variant['sourcePinSHA256'] == c.sourcePinSha256;
  } on Object {
    return false;
  }
}

bool _captionTrackFitsDuration(String text, String locale, int durationMs) {
  if (text.contains('\r') ||
      text.contains('\ufeff') ||
      text.contains('\u0000')) {
    return false;
  }
  final header = 'WEBVTT - Motion locale=$locale\n\n';
  if (!text.startsWith(header)) return false;
  final body = text.substring(header.length).replaceFirst(RegExp(r'\n+$'), '');
  if (body.isEmpty) return false;
  var previousEnd = 0;
  var count = 0;
  for (final block in body.split('\n\n')) {
    final lines = block.split('\n');
    if (lines.length < 2 || lines.any((line) => line.trim().isEmpty)) {
      return false;
    }
    final match = _cueTime.firstMatch(lines.first);
    if (match == null) return false;
    int milliseconds(int at) =>
        ((int.parse(match.group(at)!) * 60 + int.parse(match.group(at + 1)!)) *
                    60 +
                int.parse(match.group(at + 2)!)) *
            1000 +
        int.parse(match.group(at + 3)!);
    final start = milliseconds(1);
    final end = milliseconds(5);
    if (start < previousEnd || end <= start || end > durationMs) return false;
    for (final line in lines.skip(1)) {
      if (line.contains('<') ||
          line.contains('>') ||
          line.runes.any((rune) => rune < 32 && rune != 9)) {
        return false;
      }
    }
    previousEnd = end;
    count++;
  }
  final captions = WebVTTCaptionFile(text).captions;
  return captions.length == count &&
      captions.every(
        (caption) =>
            caption.end <= Duration(milliseconds: durationMs) &&
            caption.text.trim().isNotEmpty,
      );
}

bool _fileShape(LessonMediaFile file, String expectedPath, int maxBytes) {
  if (file.bytes <= 0 ||
      file.bytes > maxBytes ||
      !_sha.hasMatch(file.sha256) ||
      file.path != expectedPath) {
    return false;
  }
  try {
    PathPolicy.validate(file.path);
  } on Object {
    return false;
  }
  return true;
}

bool _bytesMatch(Uint8List bytes, LessonMediaFile file) =>
    bytes.length == file.bytes && computeSha256Hex(bytes) == file.sha256;

typedef LessonVideoControllerFactory =
    VideoPlayerController Function(InspectedLessonMedia media);

VideoPlayerController _defaultController(InspectedLessonMedia media) =>
    VideoPlayerController.asset(
      media.candidate.video.path,
      closedCaptionFile: Future<ClosedCaptionFile>.value(
        WebVTTCaptionFile(media.captionText),
      ),
    );

/// The normal course uses [LessonMediaSlot.empty]. The injected constructor
/// exercises the real offline player path in tests, without publishing any
/// staging candidate or changing progress/mastery state.
class LessonMediaSlot extends StatefulWidget {
  LessonMediaSlot.empty({
    required this.course,
    required this.lessonId,
    required this.locale,
    this.accountUserId,
    super.key,
  }) : catalog = const LessonMediaCatalog.empty(),
       bundle = rootBundle,
       sceneId = null,
       variantStem = null,
       syntheticPlayback = false,
       controllerFactory = _defaultController,
       videoBuilder = null;

  @visibleForTesting
  const LessonMediaSlot.syntheticForTesting({
    required this.course,
    required this.lessonId,
    required this.sceneId,
    required this.variantStem,
    required this.locale,
    required this.catalog,
    required this.bundle,
    required this.controllerFactory,
    this.videoBuilder,
    this.accountUserId,
    super.key,
  }) : syntheticPlayback = true;

  final CalisthenicsCourse course;
  final String lessonId;
  final String? sceneId;
  final String? variantStem;
  final String locale;
  final LessonMediaCatalog catalog;
  final AssetBundle bundle;
  final bool syntheticPlayback;
  final LessonVideoControllerFactory controllerFactory;
  final Widget Function(VideoPlayerController)? videoBuilder;
  final ValueListenable<String?>? accountUserId;

  @override
  State<LessonMediaSlot> createState() => _LessonMediaSlotState();
}

class _LessonMediaSlotState extends State<LessonMediaSlot>
    with WidgetsBindingObserver {
  int _epoch = 0;
  bool _closed = false;
  bool _accountRevoked = false;
  bool _backgrounded = false;
  VideoPlayerController? _controller;
  Future<void> _retiring = Future<void>.value();
  Future<void>? _nativeCommand;
  bool _commandPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.accountUserId?.addListener(_onAccount);
    _open();
  }

  @override
  void didUpdateWidget(covariant LessonMediaSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountUserId != widget.accountUserId) {
      oldWidget.accountUserId?.removeListener(_onAccount);
      widget.accountUserId?.addListener(_onAccount);
      _accountRevoked = true;
      _close();
    }
    if (oldWidget.lessonId != widget.lessonId ||
        oldWidget.course != widget.course ||
        oldWidget.sceneId != widget.sceneId ||
        oldWidget.variantStem != widget.variantStem ||
        oldWidget.locale != widget.locale ||
        oldWidget.catalog != widget.catalog ||
        oldWidget.bundle != widget.bundle) {
      _close();
      if (!_accountRevoked && !_backgrounded && !_nativePlaybackUnconfirmed) {
        _closed = false;
        _open();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _backgrounded = state != AppLifecycleState.resumed;
    if (_backgrounded) {
      _close();
    } else if (_closed && !_accountRevoked && !_nativePlaybackUnconfirmed) {
      _closed = false;
      _open();
    }
  }

  void _onAccount() {
    _accountRevoked = true;
    _close();
  }

  Future<void> _open() async {
    final sceneId = widget.sceneId;
    final variantStem = widget.variantStem;
    if (!widget.syntheticPlayback ||
        widget.catalog.isEmpty ||
        _closed ||
        _backgrounded ||
        _accountRevoked ||
        _nativePlaybackUnconfirmed ||
        sceneId == null ||
        variantStem == null) {
      return;
    }
    final turn = ++_epoch;
    await _retiring;
    if (!mounted ||
        _closed ||
        _backgrounded ||
        _nativePlaybackUnconfirmed ||
        turn != _epoch) {
      return;
    }
    final media = await widget.catalog.inspect(
      bundle: widget.bundle,
      course: widget.course,
      lessonId: widget.lessonId,
      sceneId: sceneId,
      variantStem: variantStem,
      locale: widget.locale,
    );
    if (media == null ||
        !mounted ||
        _closed ||
        _nativePlaybackUnconfirmed ||
        turn != _epoch) {
      return;
    }
    if (!await _takeNativeSlot()) return;
    if (!mounted || _closed || _nativePlaybackUnconfirmed || turn != _epoch) {
      _releaseNativeSlot();
      return;
    }
    VideoPlayerController? controller;
    try {
      controller = widget.controllerFactory(media);
      _controller = controller;
      // video_player keeps a pre-initialization volume and reapplies it as
      // soon as native metadata arrives. Start the player muted as well.
      final initialMute = controller.setVolume(0);
      _nativeCommand = initialMute;
      try {
        await initialMute;
      } finally {
        if (identical(_nativeCommand, initialMute)) _nativeCommand = null;
      }
      if (!mounted || _closed || _nativePlaybackUnconfirmed || turn != _epoch) {
        if (_controller == controller) {
          _controller = null;
          _queueRetire(controller);
        }
        return;
      }
      final initialize = controller.initialize();
      _nativeCommand = initialize;
      try {
        await initialize;
      } finally {
        if (identical(_nativeCommand, initialize)) _nativeCommand = null;
      }
      if (!mounted ||
          _closed ||
          _nativePlaybackUnconfirmed ||
          turn != _epoch ||
          controller.value.duration.inMilliseconds !=
              media.candidate.durationMs) {
        if (_controller == controller) {
          _controller = null;
          _queueRetire(controller);
        }
        return;
      }
      // Await the native mute before exposing controls or allowing play.
      final verifiedMute = controller.setVolume(0);
      _nativeCommand = verifiedMute;
      try {
        await verifiedMute;
      } finally {
        if (identical(_nativeCommand, verifiedMute)) _nativeCommand = null;
      }
      if (!mounted ||
          _closed ||
          _nativePlaybackUnconfirmed ||
          turn != _epoch ||
          controller.value.volume != 0) {
        if (_controller == controller) {
          _controller = null;
          _queueRetire(controller);
        }
        return;
      }
      controller.addListener(_rebuild);
      setState(() {});
    } on Object {
      if (controller != null && _controller == controller) {
        _controller = null;
        _queueRetire(controller);
      } else if (controller == null) {
        _releaseNativeSlot();
      }
    }
  }

  void _rebuild() {
    if (mounted && !_closed) setState(() {});
  }

  Future<void> _retire(VideoPlayerController controller) async {
    var unconfirmed = false;
    final pending = _nativeCommand;
    if (pending != null) {
      try {
        await pending.timeout(_nativeRetireDeadline);
      } on Object {
        // A late initialize/play/pause can otherwise run after the next route
        // receives the native player slot. Keep the process quarantined.
        unconfirmed = true;
      }
    }
    try {
      await controller.pause().timeout(_nativeRetireDeadline);
    } on Object {
      unconfirmed = true;
    }
    try {
      await controller.dispose().timeout(_nativeRetireDeadline);
    } on Object {
      unconfirmed = true;
    }
    // A timeout does not cancel the native operation. Keep this process closed
    // to another demo session until a fresh process can establish ownership.
    if (unconfirmed) _nativePlaybackUnconfirmed = true;
  }

  void _close() {
    _epoch++;
    _closed = true;
    final old = _controller;
    _controller = null;
    if (old != null) {
      old.removeListener(_rebuild);
      _queueRetire(old);
    }
    if (mounted) setState(() {});
  }

  void _queueRetire(VideoPlayerController controller) {
    _retiring = _retiring.then((_) async {
      try {
        await _retire(controller);
      } on Object {
        _nativePlaybackUnconfirmed = true;
      } finally {
        _releaseNativeSlot();
      }
    });
    unawaited(_retiring);
  }

  @override
  void dispose() {
    _epoch++;
    widget.accountUserId?.removeListener(_onAccount);
    WidgetsBinding.instance.removeObserver(this);
    final old = _controller;
    if (old != null) {
      old.removeListener(_rebuild);
      _queueRetire(old);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _closed ||
        _nativePlaybackUnconfirmed) {
      return const SizedBox.shrink();
    }
    final isTurkish = widget.locale == 'tr';
    return Semantics(
      label: isTurkish
          ? 'Paketli ders gösterimi'
          : 'Packaged lesson demonstration',
      child: Column(
        children: <Widget>[
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                widget.videoBuilder?.call(controller) ??
                    VideoPlayer(controller),
                ClosedCaption(text: controller.value.caption.text),
              ],
            ),
          ),
          TextButton.icon(
            key: const Key('calisthenics.lesson.media.playPause'),
            onPressed: _commandPending
                ? null
                : () async {
                    if (_closed ||
                        _nativePlaybackUnconfirmed ||
                        !identical(_controller, controller)) {
                      return;
                    }
                    _commandPending = true;
                    setState(() {});
                    Future<void>? command;
                    try {
                      if (!controller.value.isPlaying) {
                        command = controller.setVolume(0);
                        _nativeCommand = command;
                        await command;
                        if (_closed ||
                            _nativePlaybackUnconfirmed ||
                            !identical(_controller, controller)) {
                          return;
                        }
                        if (controller.value.volume != 0) {
                          throw StateError(
                            'Native media mute was not confirmed',
                          );
                        }
                      }
                      command = controller.value.isPlaying
                          ? controller.pause()
                          : controller.play();
                      _nativeCommand = command;
                      await command;
                    } on Object {
                      _nativePlaybackUnconfirmed = true;
                      _close();
                    } finally {
                      if (identical(_nativeCommand, command)) {
                        _nativeCommand = null;
                      }
                      _commandPending = false;
                      if (mounted && !_closed) {
                        setState(() {});
                      }
                    }
                  },
            icon: Icon(
              controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            ),
            label: Text(
              isTurkish
                  ? (controller.value.isPlaying ? 'Duraklat' : 'Oynat')
                  : (controller.value.isPlaying ? 'Pause' : 'Play'),
            ),
          ),
        ],
      ),
    );
  }
}
