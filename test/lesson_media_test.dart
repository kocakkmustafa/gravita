import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_connection.dart';
import 'package:gravita/app/account_action_ticket.dart';
import 'package:gravita/app/account_store_epoch.dart';
import 'package:gravita/app/calisthenics_course.dart';
import 'package:gravita/app/lesson_media.dart';
import 'package:motion_content/motion_content.dart';
import 'package:video_player/video_player.dart';

import 'account_action_ticket_test.dart'
    show AccountHttpFixture, accountHttpResponse, ticketAlice;

final class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);

  final Map<String, Uint8List> files;
  int reads = 0;
  final List<String> loadedKeys = <String>[];
  Future<void> Function(String key)? beforeLoad;

  @override
  Future<ByteData> load(String key) async {
    reads++;
    loadedKeys.add(key);
    final hook = beforeLoad;
    if (hook != null) await hook(key);
    final bytes = files[key];
    if (bytes == null) throw FlutterError('Missing test asset $key');
    return ByteData.sublistView(bytes);
  }
}

final class _FakeController extends VideoPlayerController {
  _FakeController(super.dataSource) : super.asset();

  bool retired = false;
  bool failNativeMute = false;
  int muteCalls = 0;
  int playCalls = 0;
  int disposeCalls = 0;
  int initializeCalls = 0;
  Completer<void>? initializeGate;
  Completer<void>? prePlayMuteGate;
  Completer<void>? pauseGate;
  Completer<void>? playGate;
  VoidCallback? onPlay;
  VoidCallback? onDispose;

  bool get hasHostListener => hasListeners;

  @override
  Future<void> initialize() async {
    initializeCalls++;
    await initializeGate?.future;
    value = VideoPlayerValue(
      duration: Duration(milliseconds: 1000),
      size: Size(16, 9),
      isInitialized: true,
      volume: value.volume,
    );
  }

  @override
  Future<void> setVolume(double volume) async {
    muteCalls++;
    if (value.isInitialized && failNativeMute) {
      throw StateError('native mute failed');
    }
    if (muteCalls >= 3) await prePlayMuteGate?.future;
    value = value.copyWith(volume: volume);
  }

  @override
  Future<void> play() async {
    playCalls++;
    if (value.volume != 0) throw StateError('unmuted playback');
    onPlay?.call();
    await playGate?.future;
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    value = value.copyWith(isPlaying: false);
    await pauseGate?.future;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    retired = true;
    await super.dispose();
    onDispose?.call();
  }
}

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);
String _hex(String character) => List<String>.filled(64, character).join();
LessonMediaFile _file(String path, Uint8List bytes) => LessonMediaFile(
  path: path,
  bytes: bytes.length,
  sha256: computeSha256Hex(bytes),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final courseBytes = File(
    'content/courses/calisthenics.v1.json',
  ).readAsBytesSync();
  final sourcePinBytes = File(
    'content/courses/calisthenics.media-source-pins.v2k.v1.json',
  ).readAsBytesSync();
  final course = CalisthenicsCourse.parse(utf8.decode(courseBytes));
  const stem =
      'gravita/cal-01--7a1b5364/orientation--069fa01695db280cfbc9a7f2bb787355cc4aef3fb592e22e02dbfbe980231c92--master-format-pending';
  const videoPath = 'content/media/$stem.mp4';
  const trPath = 'content/media/$stem.tr.vtt';
  const enPath = 'content/media/$stem.en.vtt';
  final video = _bytes(<int>[
    0,
    0,
    0,
    16,
    102,
    116,
    121,
    112,
    105,
    115,
    111,
    109,
    0,
    0,
    0,
    0,
  ]);
  final tr = _bytes(
    utf8.encode(
      'WEBVTT - Motion locale=tr\n\n00:00:00.000 --> 00:00:01.000\nBaşla\n',
    ),
  );
  final en = _bytes(
    utf8.encode(
      'WEBVTT - Motion locale=en\n\n00:00:00.000 --> 00:00:01.000\nStart\n',
    ),
  );

  _Bundle bundle() => _Bundle(<String, Uint8List>{
    'content/courses/calisthenics.v1.json': _bytes(courseBytes),
    'content/courses/calisthenics.media-source-pins.v2k.v1.json': _bytes(
      sourcePinBytes,
    ),
    videoPath: video,
    trPath: tr,
    enPath: en,
  });

  LessonMediaCandidate candidate({
    String app = 'gravita',
    String lessonId = 'cal-01',
    String lessonCanonicalSha256 =
        '1484657de9f1d0ff7353db7084dc8066e3528ca8c9a502c92817cb657a737674',
    String assetId = 'gravita.cal-01.v8d.demo',
    String? sourceSha,
    String productionIndexSha256 =
        'd887683c9a9b9bdb8d4ab7c51cdc5a5b4b4de6a918079e4cfd9cf543e9751e60',
    String sceneId = 'gravita:cal-01:orientation',
    String variantStem = stem,
    String productionSpecSha256 =
        '069fa01695db280cfbc9a7f2bb787355cc4aef3fb592e22e02dbfbe980231c92',
    String sourceCueSha256 =
        'ad8b3138e5a6879e0697ebf8e89cb5f7c00ba27c079456d40e61f8c08ea7418d',
    String? idempotencyKey,
    String productionState = 'PREPRODUCTION_UNGENERATED',
    String sourcePinSha256 =
        '7a54ccf6d07b79ba91424162801c4a9228f5a1ffa328037c474d228fa8702188',
    String? mediaSha,
    LessonMediaFile? videoFile,
    Map<String, LessonMediaFile>? captionFiles,
    int durationMs = 1000,
  }) => LessonMediaCandidate(
    app: app,
    lessonId: lessonId,
    lessonCanonicalSha256: lessonCanonicalSha256,
    assetId: assetId,
    courseVersion: course.version,
    courseSourceSha256: sourceSha ?? computeSha256Hex(_bytes(courseBytes)),
    productionIndexSha256: productionIndexSha256,
    sceneId: sceneId,
    variantStem: variantStem,
    productionSpecSha256: productionSpecSha256,
    sourceCueSha256: sourceCueSha256,
    idempotencyKey: idempotencyKey ?? 'motion-media-v1:$productionSpecSha256',
    productionState: productionState,
    sourcePinSha256: sourcePinSha256,
    durationMs: durationMs,
    video:
        videoFile ??
        LessonMediaFile(
          path: 'content/media/$variantStem.mp4',
          bytes: video.length,
          sha256: mediaSha ?? computeSha256Hex(video),
        ),
    captions:
        captionFiles ??
        <String, LessonMediaFile>{
          'tr': _file('content/media/$variantStem.tr.vtt', tr),
          'en': _file('content/media/$variantStem.en.vtt', en),
        },
  );

  Future<void> rejectedBeforeVideo(LessonMediaCandidate claim) async {
    final assets = bundle();
    final result =
        await LessonMediaCatalog.syntheticForTesting(<LessonMediaCandidate>[
          claim,
        ]).inspect(
          bundle: assets,
          course: course,
          lessonId: claim.lessonId,
          sceneId: claim.sceneId,
          variantStem: claim.variantStem,
          locale: 'tr',
        );
    expect(result, isNull);
    expect(assets.loadedKeys, isNot(contains(claim.video.path)));
  }

  test(
    'shipping catalog stays empty and never reads packaged assets',
    () async {
      final assets = bundle();
      final result = await const LessonMediaCatalog.empty().inspect(
        bundle: assets,
        course: course,
        lessonId: 'cal-01',
        sceneId: 'gravita:cal-01:orientation',
        variantStem: stem,
        locale: 'tr',
      );
      expect(result, isNull);
      expect(assets.reads, 0);
    },
  );

  test(
    'synthetic media verifies course/video/both captions before playback',
    () async {
      final assets = bundle();
      final media =
          await LessonMediaCatalog.syntheticForTesting(<LessonMediaCandidate>[
            candidate(),
          ]).inspect(
            bundle: assets,
            course: course,
            lessonId: 'cal-01',
            sceneId: 'gravita:cal-01:orientation',
            variantStem: stem,
            locale: 'tr',
          );
      expect(media, isNotNull);
      expect(media!.captionText, contains('Başla'));
      expect(media.releaseEligible, isFalse);
      expect(media.progressEffect, 0);
    },
  );

  test('old v2d and v2g manifest claims fail before media bytes', () async {
    for (final oldSha in <String>[
      'deb767cc1060cb475bf5664e0c662b44b0a0ad8318288b4e65faa3c472cb6324',
      '21008cbf5a58d01c3ef4a12c879f1b6da4e8d8ea5111f8340d53d35f9ec02c8b',
      '5399b0fd21bd7148de9c845ecaf288e391fef4c6e2ae98503fd9134fd39e8628',
    ]) {
      await rejectedBeforeVideo(candidate(productionIndexSha256: oldSha));
    }
  });

  test('v2g scene relabelled as v2k fails exact source membership', () async {
    const oldSpec =
        'b19e7cf495ddb22db8c16ed8af2d558c6ee2a36ca72d69d92a76e569bb0a43b4';
    const oldStem =
        'gravita/cal-01--7a1b5364/orientation--b19e7cf495ddb22db8c16ed8af2d558c6ee2a36ca72d69d92a76e569bb0a43b4--master-format-pending';
    await rejectedBeforeVideo(
      candidate(
        productionSpecSha256: oldSpec,
        variantStem: oldStem,
        idempotencyKey: 'motion-media-v1:$oldSpec',
      ),
    );
  });

  test(
    'wrong lesson, scene, variant, cue and source pin fail closed',
    () async {
      final mutations = <LessonMediaCandidate>[
        candidate(app: 'ostinato'),
        candidate(sourceSha: _hex('0')),
        candidate(lessonId: 'cal-02', sceneId: 'gravita:cal-02:orientation'),
        candidate(lessonCanonicalSha256: _hex('0')),
        candidate(assetId: 'gravita.cal-01.renamed.demo'),
        candidate(sceneId: 'gravita:cal-01:wrong-scene'),
        candidate(variantStem: '$stem--wrong'),
        candidate(productionSpecSha256: _hex('a')),
        candidate(sourceCueSha256: _hex('b')),
        candidate(idempotencyKey: 'motion-media-v1:${_hex('c')}'),
        candidate(productionState: 'GENERATED'),
        candidate(sourcePinSha256: _hex('d')),
      ];
      for (final claim in mutations) {
        await rejectedBeforeVideo(claim);
      }
    },
  );

  test('exact held equipment scene cannot become QA media', () async {
    const heldSpec =
        '1119ba0651d73af704551cfd5ef9a671c774315ef78631affb95e5f78b102922';
    const heldStem =
        'gravita/cal-01--7a1b5364/full-sequence-03--1119ba0651d73af704551cfd5ef9a671c774315ef78631affb95e5f78b102922--master-format-pending';
    await rejectedBeforeVideo(
      candidate(
        sceneId: 'gravita:cal-01:full_sequence-03',
        variantStem: heldStem,
        productionSpecSha256: heldSpec,
        sourceCueSha256:
            '9ee0109fd7bb083900ac79b8a313982bed6fc847b1abccc82440eee219558110',
        idempotencyKey: 'motion-media-v1:$heldSpec',
        productionState: 'HOLD_VERIFIED_EQUIPMENT',
        sourcePinSha256:
            'f1e81c25e8a665efb2bef9fc73a26f91906c8a196e97ac4c2df231b150cf4d9f',
      ),
    );
  });

  test(
    'missing, old or altered QA pin file cannot authorize video read',
    () async {
      final missing = bundle()
        ..files.remove(
          'content/courses/calisthenics.media-source-pins.v2k.v1.json',
        );
      final old = bundle()
        ..files['content/courses/calisthenics.media-source-pins.v2k.v1.json'] =
            File(
              'content/courses/calisthenics.media-source-pins.v2h.v1.json',
            ).readAsBytesSync();
      final altered = bundle()
        ..files['content/courses/calisthenics.media-source-pins.v2k.v1.json'] =
            _bytes(<int>[...sourcePinBytes, 10]);
      for (final assets in <_Bundle>[missing, old, altered]) {
        final result =
            await LessonMediaCatalog.syntheticForTesting(<LessonMediaCandidate>[
              candidate(),
            ]).inspect(
              bundle: assets,
              course: course,
              lessonId: 'cal-01',
              sceneId: 'gravita:cal-01:orientation',
              variantStem: stem,
              locale: 'tr',
            );
        expect(result, isNull);
        expect(assets.loadedKeys, isNot(contains(videoPath)));
      }
    },
  );

  test(
    'stale source, wrong media bytes, missing locale and unsafe path fail closed',
    () async {
      final stale = LessonMediaCatalog.syntheticForTesting(
        <LessonMediaCandidate>[candidate(sourceSha: _hex('0'))],
      );
      expect(
        await stale.inspect(
          bundle: bundle(),
          course: course,
          lessonId: 'cal-01',
          sceneId: 'gravita:cal-01:orientation',
          variantStem: stem,
          locale: 'tr',
        ),
        isNull,
      );
      final altered = bundle()..files[videoPath] = _bytes(<int>[1, 2, 3]);
      final valid = LessonMediaCatalog.syntheticForTesting(
        <LessonMediaCandidate>[candidate()],
      );
      expect(
        await valid.inspect(
          bundle: altered,
          course: course,
          lessonId: 'cal-01',
          sceneId: 'gravita:cal-01:orientation',
          variantStem: stem,
          locale: 'tr',
        ),
        isNull,
      );
      expect(
        await valid.inspect(
          bundle: bundle(),
          course: course,
          lessonId: 'cal-01',
          sceneId: 'gravita:cal-01:orientation',
          variantStem: stem,
          locale: 'fr',
        ),
        isNull,
      );
      final badPath = candidate();
      final escaped =
          LessonMediaCatalog.syntheticForTesting(<LessonMediaCandidate>[
            LessonMediaCandidate(
              app: badPath.app,
              lessonId: badPath.lessonId,
              lessonCanonicalSha256: badPath.lessonCanonicalSha256,
              assetId: badPath.assetId,
              courseVersion: badPath.courseVersion,
              courseSourceSha256: badPath.courseSourceSha256,
              productionIndexSha256: badPath.productionIndexSha256,
              sceneId: badPath.sceneId,
              variantStem: badPath.variantStem,
              productionSpecSha256: badPath.productionSpecSha256,
              sourceCueSha256: badPath.sourceCueSha256,
              idempotencyKey: badPath.idempotencyKey,
              productionState: badPath.productionState,
              sourcePinSha256: badPath.sourcePinSha256,
              durationMs: badPath.durationMs,
              video: _file('../content/media/$stem.mp4', video),
              captions: badPath.captions,
            ),
          ]);
      expect(
        await escaped.inspect(
          bundle: bundle(),
          course: course,
          lessonId: 'cal-01',
          sceneId: 'gravita:cal-01:orientation',
          variantStem: stem,
          locale: 'tr',
        ),
        isNull,
      );
    },
  );

  test(
    'safe wrong media roots reject video and captions before bundle reads',
    () async {
      const otherVideoPath = 'other/$stem.mp4';
      const otherTrPath = 'other/$stem.tr.vtt';
      final claims = <LessonMediaCandidate>[
        candidate(videoFile: _file(otherVideoPath, video)),
        candidate(
          captionFiles: <String, LessonMediaFile>{
            'tr': _file(otherTrPath, tr),
            'en': _file(enPath, en),
          },
        ),
      ];
      for (final claim in claims) {
        final assets = bundle()
          ..files[otherVideoPath] = video
          ..files[otherTrPath] = tr;
        final media =
            await LessonMediaCatalog.syntheticForTesting(<LessonMediaCandidate>[
              claim,
            ]).inspect(
              bundle: assets,
              course: course,
              lessonId: claim.lessonId,
              sceneId: claim.sceneId,
              variantStem: claim.variantStem,
              locale: 'tr',
            );
        final rejectedPath = claim.video.path == videoPath
            ? claim.captions['tr']!.path
            : claim.video.path;
        expect(media, isNull, reason: rejectedPath);
        expect(assets.reads, 0, reason: rejectedPath);
      }
    },
  );

  test('caption metadata stays fixed while bundle reads are pending', () async {
    const otherTrPath = 'other/$stem.tr.vtt';
    final suppliedCaptions = <String, LessonMediaFile>{
      'tr': _file(trPath, tr),
      'en': _file(enPath, en),
    };
    final claim = candidate(captionFiles: suppliedCaptions);
    final assets = bundle()..files[otherTrPath] = tr;
    final sourceReadStarted = Completer<void>();
    final resumeSourceRead = Completer<void>();
    assets.beforeLoad = (key) async {
      if (key == 'content/courses/calisthenics.media-source-pins.v2k.v1.json') {
        sourceReadStarted.complete();
        await resumeSourceRead.future;
      }
    };
    final pending =
        LessonMediaCatalog.syntheticForTesting(<LessonMediaCandidate>[
          claim,
        ]).inspect(
          bundle: assets,
          course: course,
          lessonId: claim.lessonId,
          sceneId: claim.sceneId,
          variantStem: claim.variantStem,
          locale: 'tr',
        );

    await sourceReadStarted.future;
    // Path validation finished before this first asynchronous bundle read.
    suppliedCaptions['tr'] = _file(otherTrPath, tr);
    resumeSourceRead.complete();
    final media = await pending;
    expect(media, isNotNull);
    expect(claim.captions['tr']!.path, trPath);
    expect(assets.loadedKeys, contains(trPath));
    expect(assets.loadedKeys, isNot(contains(otherTrPath)));
    expect(
      () => claim.captions['tr'] = _file(otherTrPath, tr),
      throwsUnsupportedError,
    );
  });

  test('caption cues outside declared video duration fail closed', () async {
    final lateTr = _bytes(
      utf8.encode(
        'WEBVTT - Motion locale=tr\n\n00:00:02.000 --> 00:00:03.000\nGeç\n',
      ),
    );
    final assets = bundle()..files[trPath] = lateTr;
    final media =
        await LessonMediaCatalog.syntheticForTesting(<LessonMediaCandidate>[
          candidate(
            captionFiles: <String, LessonMediaFile>{
              'tr': _file(trPath, lateTr),
              'en': _file(enPath, en),
            },
          ),
        ]).inspect(
          bundle: assets,
          course: course,
          lessonId: 'cal-01',
          sceneId: 'gravita:cal-01:orientation',
          variantStem: stem,
          locale: 'en',
        );
    expect(media, isNull);
  });

  test('a malformed second caption cue cannot be silently dropped', () async {
    final assets = bundle();
    final malformed = _bytes(
      utf8.encode(
        'WEBVTT - Motion locale=tr\n\n'
        '00:00:00.000 --> 00:00:00.400\nBaşla\n\n'
        '00:00:00.BAD --> 00:00:00.800\nDevam et\n',
      ),
    );
    assets.files[trPath] = malformed;
    final selected = candidate(
      captionFiles: <String, LessonMediaFile>{
        'tr': _file(trPath, malformed),
        'en': _file(enPath, en),
      },
    );
    final media =
        await LessonMediaCatalog.syntheticForTesting(<LessonMediaCandidate>[
          selected,
        ]).inspect(
          bundle: assets,
          course: course,
          lessonId: 'cal-01',
          sceneId: 'gravita:cal-01:orientation',
          variantStem: stem,
          locale: 'tr',
        );
    expect(media, isNull);
  });

  test('an invalid unselected file cannot mask catalog budget', () async {
    final selected = candidate();
    const otherStem = 'gravita/cal-02/poison';
    final badVideos = <LessonMediaFile>[
      LessonMediaFile(
        path: 'content/media/$otherStem.mp4',
        bytes: -1,
        sha256: _hex('c'),
      ),
      _file('other/$otherStem.mp4', video),
    ];
    for (final badVideo in badVideos) {
      final invalid = LessonMediaCandidate(
        app: selected.app,
        lessonId: 'cal-02',
        lessonCanonicalSha256: selected.lessonCanonicalSha256,
        assetId: selected.assetId,
        courseVersion: selected.courseVersion,
        courseSourceSha256: selected.courseSourceSha256,
        productionIndexSha256: selected.productionIndexSha256,
        sceneId: 'gravita:cal-02:poison',
        variantStem: otherStem,
        productionSpecSha256: selected.productionSpecSha256,
        sourceCueSha256: selected.sourceCueSha256,
        idempotencyKey: selected.idempotencyKey,
        productionState: selected.productionState,
        sourcePinSha256: selected.sourcePinSha256,
        durationMs: selected.durationMs,
        video: badVideo,
        captions: <String, LessonMediaFile>{
          'tr': LessonMediaFile(
            path: 'content/media/$otherStem.tr.vtt',
            bytes: 1,
            sha256: _hex('d'),
          ),
          'en': LessonMediaFile(
            path: 'content/media/$otherStem.en.vtt',
            bytes: 1,
            sha256: _hex('e'),
          ),
        },
      );
      final assets = bundle()..files[badVideo.path] = video;
      final media =
          await LessonMediaCatalog.syntheticForTesting(<LessonMediaCandidate>[
            selected,
            invalid,
          ]).inspect(
            bundle: assets,
            course: course,
            lessonId: 'cal-01',
            sceneId: 'gravita:cal-01:orientation',
            variantStem: stem,
            locale: 'tr',
          );
      expect(media, isNull, reason: badVideo.path);
      expect(assets.reads, 0, reason: badVideo.path);
    }
  });

  testWidgets('synthetic player closes on account change', (tester) async {
    final identity = ValueNotifier<String?>(
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    );
    final fake = _FakeController(videoPath);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonMediaSlot.syntheticForTesting(
            course: course,
            lessonId: 'cal-01',
            sceneId: 'gravita:cal-01:orientation',
            variantStem: stem,
            locale: 'tr',
            catalog: LessonMediaCatalog.syntheticForTesting(
              <LessonMediaCandidate>[candidate()],
            ),
            bundle: bundle(),
            controllerFactory: (_) => fake,
            videoBuilder: (_) => const Text('synthetic player surface'),
            accountUserId: identity,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('synthetic player surface'), findsOneWidget);
    expect(fake.muteCalls, 2);
    expect(fake.value.volume, 0);
    expect(find.text('Oynat'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Paketli ders gösterimi',
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('calisthenics.lesson.media.playPause')),
    );
    await tester.pump();
    expect(fake.value.isPlaying, isTrue);
    expect(find.text('Duraklat'), findsOneWidget);
    identity.value = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    await tester.pumpAndSettle();
    expect(fake.retired, isTrue);
    expect(find.text('synthetic player surface'), findsNothing);
    identity.dispose();
  });

  testWidgets('failed native mute keeps synthetic player hidden', (
    tester,
  ) async {
    final fake = _FakeController(videoPath)..failNativeMute = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonMediaSlot.syntheticForTesting(
            course: course,
            lessonId: 'cal-01',
            sceneId: 'gravita:cal-01:orientation',
            variantStem: stem,
            locale: 'tr',
            catalog: LessonMediaCatalog.syntheticForTesting(
              <LessonMediaCandidate>[candidate()],
            ),
            bundle: bundle(),
            controllerFactory: (_) => fake,
            videoBuilder: (_) => const Text('synthetic player surface'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fake.muteCalls, 2);
    expect(fake.retired, isTrue);
    expect(find.text('synthetic player surface'), findsNothing);
  });

  testWidgets('play waits for a fresh native mute after volume changes', (
    tester,
  ) async {
    final fake = _FakeController(videoPath);
    final gate = Completer<void>();
    fake.prePlayMuteGate = gate;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonMediaSlot.syntheticForTesting(
            course: course,
            lessonId: 'cal-01',
            sceneId: 'gravita:cal-01:orientation',
            variantStem: stem,
            locale: 'tr',
            catalog: LessonMediaCatalog.syntheticForTesting(
              <LessonMediaCandidate>[candidate()],
            ),
            bundle: bundle(),
            controllerFactory: (_) => fake,
            videoBuilder: (_) => const Text('synthetic player surface'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    fake.value = fake.value.copyWith(volume: 1);
    await tester.tap(
      find.byKey(const Key('calisthenics.lesson.media.playPause')),
    );
    await tester.pump();
    expect(fake.muteCalls, 3);
    expect(fake.playCalls, 0);
    gate.complete();
    await tester.pumpAndSettle();
    expect(fake.playCalls, 1);
    expect(fake.value.volume, 0);
  });

  testWidgets('background return rechecks media and stays paused', (
    tester,
  ) async {
    final first = _FakeController(videoPath);
    final second = _FakeController(videoPath);
    var created = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonMediaSlot.syntheticForTesting(
            course: course,
            lessonId: 'cal-01',
            sceneId: 'gravita:cal-01:orientation',
            variantStem: stem,
            locale: 'tr',
            catalog: LessonMediaCatalog.syntheticForTesting(
              <LessonMediaCandidate>[candidate()],
            ),
            bundle: bundle(),
            controllerFactory: (_) => created++ == 0 ? first : second,
            videoBuilder: (_) => const Text('synthetic player surface'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final observer =
        tester.state(find.byType(LessonMediaSlot)) as WidgetsBindingObserver;
    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(first.retired, isTrue);
    expect(find.text('synthetic player surface'), findsNothing);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('synthetic player surface'), findsOneWidget);
    expect(created, 2);
    expect(second.value.isPlaying, isFalse);
  });

  testWidgets('new route waits for the prior native controller to retire', (
    tester,
  ) async {
    final first = _FakeController(videoPath);
    final second = _FakeController(videoPath);
    final gate = Completer<void>();
    first.pauseGate = gate;
    var created = 0;
    Widget route() => MaterialApp(
      home: Scaffold(
        body: LessonMediaSlot.syntheticForTesting(
          course: course,
          lessonId: 'cal-01',
          sceneId: 'gravita:cal-01:orientation',
          variantStem: stem,
          locale: 'tr',
          catalog: LessonMediaCatalog.syntheticForTesting(
            <LessonMediaCandidate>[candidate()],
          ),
          bundle: bundle(),
          controllerFactory: (_) => created++ == 0 ? first : second,
          videoBuilder: (_) => const Text('synthetic player surface'),
        ),
      ),
    );
    await tester.pumpWidget(route());
    await tester.pumpAndSettle();
    expect(created, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(route());
    await tester.pumpAndSettle();
    expect(created, 1);
    gate.complete();
    await tester.pumpAndSettle();
    expect(first.retired, isTrue);
    expect(created, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(second.retired, isTrue);
  });

  testWidgets('dispose during initialization retires the controller once', (
    tester,
  ) async {
    final gate = Completer<void>();
    final first = _FakeController(videoPath)..initializeGate = gate;
    final second = _FakeController(videoPath);
    var created = 0;
    Widget route() => MaterialApp(
      home: Scaffold(
        body: LessonMediaSlot.syntheticForTesting(
          course: course,
          lessonId: 'cal-01',
          sceneId: 'gravita:cal-01:orientation',
          variantStem: stem,
          locale: 'tr',
          catalog: LessonMediaCatalog.syntheticForTesting(
            <LessonMediaCandidate>[candidate()],
          ),
          bundle: bundle(),
          controllerFactory: (_) => created++ == 0 ? first : second,
          videoBuilder: (_) => const Text('synthetic player surface'),
        ),
      ),
    );
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    await tester.pumpWidget(route());
    await tester.pumpAndSettle();
    expect(created, 1);
    expect(first.initializeCalls, 1);
    expect(first.value.isInitialized, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(route());
    await tester.pumpAndSettle();
    expect(created, 1, reason: 'the previous native initialization is pending');
    gate.complete();
    await tester.pumpAndSettle();
    expect(first.disposeCalls, 1, reason: 'a stale result cannot retire twice');
    expect(created, 2);
    expect(find.text('synthetic player surface'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(second.disposeCalls, 1);
  });

  testWidgets('same UUID recovery retires pending video before route rebuild', (
    tester,
  ) async {
    final identity = ValueNotifier<String?>(
      '11111111-1111-4111-8111-111111111111',
    );
    final recovery = ValueNotifier<bool>(false);
    final first = _FakeController(videoPath);
    final gate = Completer<void>();
    first.playGate = gate;
    first.onPlay = () => recovery.value = true;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
      identity.dispose();
      recovery.dispose();
    });
    await tester.pumpWidget(
      AccountScope(
        connection: AccountConnection(
          userId: identity,
          passwordRecovery: recovery,
          pageBuilder: (_) => const SizedBox(),
        ),
        currentUserId: identity.value,
        child: MaterialApp(
          home: Scaffold(
            body: LessonMediaSlot.syntheticForTesting(
              course: course,
              lessonId: 'cal-01',
              sceneId: 'gravita:cal-01:orientation',
              variantStem: stem,
              locale: 'tr',
              catalog: LessonMediaCatalog.syntheticForTesting([candidate()]),
              bundle: bundle(),
              controllerFactory: (_) => first,
              videoBuilder: (_) => const Text('synthetic player surface'),
              accountUserId: identity,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('calisthenics.lesson.media.playPause')),
    );
    await tester.pump();
    expect(identity.value, '11111111-1111-4111-8111-111111111111');
    expect(find.text('synthetic player surface'), findsNothing);
    expect(first.retired, isFalse, reason: 'admitted native play must settle');
    gate.complete();
    await tester.pumpAndSettle();
    expect(first.retired, isTrue);
    expect(first.value.isPlaying, isFalse);
    expect(first.disposeCalls, 1);
    recovery.value = false;
    await tester.pumpAndSettle();
    expect(
      first.initializeCalls,
      1,
      reason: 'retired slot cannot reopen itself',
    );
  });

  testWidgets(
    'standalone video mount after account erasure cannot initialize',
    (tester) async {
      const uuid = '11111111-1111-4111-8111-111111111111';
      await AccountStoreEpochRegistry.resetForTest();
      await AccountStoreEpochRegistry.enableManagedAdmission();
      AccountStoreEpochRegistry.activate(uuid);
      await AccountStoreEpochRegistry.beginConfirmedAccountErasure(
        uuid,
        () async {},
      );
      final identity = ValueNotifier<String?>(uuid);
      addTearDown(identity.dispose);
      final first = _FakeController(videoPath);
      int created = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonMediaSlot.syntheticForTesting(
              course: course,
              lessonId: 'cal-01',
              sceneId: 'gravita:cal-01:orientation',
              variantStem: stem,
              locale: 'tr',
              catalog: LessonMediaCatalog.syntheticForTesting([candidate()]),
              bundle: bundle(),
              controllerFactory: (_) {
                created++;
                return first;
              },
              videoBuilder: (_) => const Text('synthetic player surface'),
              accountUserId: identity,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(created, 0);
      expect(first.initializeCalls, 0);
      expect(find.text('synthetic player surface'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await AccountStoreEpochRegistry.resetForTest();
      await first.dispose();
    },
  );

  testWidgets('fresh sign-in retires pending video before route rebuild', (
    tester,
  ) async {
    final identity = ValueNotifier<String?>(
      '11111111-1111-4111-8111-111111111111',
    );
    final owners = StreamController<void>.broadcast(sync: true);
    final cleanupGate = Completer<void>();
    Future<void>? cleanup;
    final first = _FakeController(videoPath);
    final gate = Completer<void>();
    first.playGate = gate;
    first.onPlay = () => owners.add(null);
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
      identity.dispose();
      if (!cleanupGate.isCompleted) cleanupGate.complete();
      unawaited(owners.close());
    });
    await tester.pumpWidget(
      AccountScope(
        connection: AccountConnection(
          userId: identity,
          ownerSessionChanges: owners.stream,
          pageBuilder: (_) => const SizedBox(),
        ),
        currentUserId: identity.value,
        child: MaterialApp(
          home: Scaffold(
            body: LessonMediaSlot.syntheticForTesting(
              course: course,
              lessonId: 'cal-01',
              sceneId: 'gravita:cal-01:orientation',
              variantStem: stem,
              locale: 'tr',
              catalog: LessonMediaCatalog.syntheticForTesting([candidate()]),
              bundle: bundle(),
              controllerFactory: (_) => first,
              videoBuilder: (_) => const Text('synthetic player surface'),
              accountUserId: identity,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('calisthenics.lesson.media.playPause')),
    );
    await tester.pump();
    expect(identity.value, '11111111-1111-4111-8111-111111111111');
    expect(find.text('synthetic player surface'), findsNothing);
    expect(first.retired, isFalse, reason: 'admitted native play must settle');
    gate.complete();
    await tester.pumpAndSettle();
    expect(first.retired, isTrue);
    expect(first.value.isPlaying, isFalse);
    expect(first.disposeCalls, 1);
    cleanupGate.complete();
    await cleanup;
    await tester.pumpAndSettle();
    expect(
      first.initializeCalls,
      1,
      reason: 'retired slot cannot reopen itself',
    );
    await tester.pumpWidget(const SizedBox());
    await AccountStoreEpochRegistry.resetForTest();
  });

  testWidgets('owner stream error retires pending video before route rebuild', (
    tester,
  ) async {
    final identity = ValueNotifier<String?>(
      '11111111-1111-4111-8111-111111111111',
    );
    final owners = StreamController<void>.broadcast(sync: true);
    final cleanupGate = Completer<void>();
    Future<void>? cleanup;
    final first = _FakeController(videoPath);
    final gate = Completer<void>();
    first.playGate = gate;
    first.onPlay = () => owners.addError(
      StateError('synthetic auth transport'),
      StackTrace.current,
    );
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
      identity.dispose();
      if (!cleanupGate.isCompleted) cleanupGate.complete();
      unawaited(owners.close());
    });
    await tester.pumpWidget(
      AccountScope(
        connection: AccountConnection(
          userId: identity,
          ownerSessionChanges: owners.stream,
          pageBuilder: (_) => const SizedBox(),
        ),
        currentUserId: identity.value,
        child: MaterialApp(
          home: Scaffold(
            body: LessonMediaSlot.syntheticForTesting(
              course: course,
              lessonId: 'cal-01',
              sceneId: 'gravita:cal-01:orientation',
              variantStem: stem,
              locale: 'tr',
              catalog: LessonMediaCatalog.syntheticForTesting([candidate()]),
              bundle: bundle(),
              controllerFactory: (_) => first,
              videoBuilder: (_) => const Text('synthetic player surface'),
              accountUserId: identity,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('calisthenics.lesson.media.playPause')),
    );
    await tester.pump();
    expect(identity.value, '11111111-1111-4111-8111-111111111111');
    expect(find.text('synthetic player surface'), findsNothing);
    expect(first.retired, isFalse, reason: 'admitted native play must settle');
    gate.complete();
    await tester.pumpAndSettle();
    expect(first.retired, isTrue);
    expect(first.value.isPlaying, isFalse);
    expect(first.disposeCalls, 1);
    cleanupGate.complete();
    await cleanup;
    await tester.pumpAndSettle();
    expect(
      first.initializeCalls,
      1,
      reason: 'retired slot cannot reopen itself',
    );
    await tester.pumpWidget(const SizedBox());
    await AccountStoreEpochRegistry.resetForTest();
  });

  group('confirmed deletion with refreshed credentials and live video', () {
    late AccountHttpFixture account;
    setUp(() async {
      await AccountStoreEpochRegistry.resetForTest();
      await AccountStoreEpochRegistry.enableManagedAdmission();
      AccountStoreEpochRegistry.activate(ticketAlice);
      account = AccountHttpFixture();
      await account.session(ticketAlice);
    });
    tearDown(() async {
      await account.dispose();
      await AccountStoreEpochRegistry.resetForTest();
    });

    testWidgets('normal refresh retains video until the verified UUID fence', (
      tester,
    ) async {
      final identity = ValueNotifier<String?>(ticketAlice);
      final first = _FakeController(videoPath);
      final playGate = Completer<void>();
      final cleanupGate = Zone.root.run(() => Completer<void>());
      final cleanupStarted = Zone.root.run(() => Completer<void>());
      final videoDisposed = Zone.root.run(() => Completer<void>());
      first.onDispose = videoDisposed.complete;
      final reply = account.delayDeletion();
      first.playGate = playGate;
      final ticket = AccountActionTicket.capture(account.account)!;
      final pinned = EpochBoundMotionAccountClient(
        original: account.account,
        ticket: ticket,
      );
      final connection = AccountConnection(
        userId: identity,
        // Same public auth-event selector as the production bootstrap.
        ownerSessionChanges: account.account.authChanges
            .where(
              (state) => const {
                'signedIn',
                'signedOut',
                'passwordRecovery',
              }.contains(state.event.name),
            )
            .map<void>((_) {}),
        pageBuilder: (_) => const SizedBox(),
      );
      Future<void>? deletion;
      final confirmedIds = <String>[];
      try {
        await tester.pumpWidget(
          AccountScope(
            connection: connection,
            currentUserId: identity.value,
            child: MaterialApp(
              home: Scaffold(
                body: LessonMediaSlot.syntheticForTesting(
                  course: course,
                  lessonId: 'cal-01',
                  sceneId: 'gravita:cal-01:orientation',
                  variantStem: stem,
                  locale: 'tr',
                  catalog: LessonMediaCatalog.syntheticForTesting([
                    candidate(),
                  ]),
                  bundle: bundle(),
                  controllerFactory: (_) => first,
                  videoBuilder: (_) => const Text('synthetic player surface'),
                  accountUserId: identity,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(first.hasHostListener, isTrue);
        deletion = Zone.root.run(
          () => pinned.deleteCommonAccount(
            afterRemoteDelete: (id) {
              confirmedIds.add(id);
              final cleanup =
                  AccountStoreEpochRegistry.beginConfirmedAccountErasure(
                    id,
                    () => cleanupGate.future,
                  );
              cleanupStarted.complete();
              return cleanup;
            },
          ),
        );
        // Observe the root-zone error immediately, retaining the original
        // Future for the assertion/await in the widget test's own zone.
        unawaited(
          deletion!.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
        );
        await tester.runAsync(() async {
          for (var turn = 0; turn < 40 && account.deletions.isEmpty; turn++) {
            await Future<void>.delayed(const Duration(milliseconds: 1));
          }
        });
        expect(account.deletions, hasLength(1));
        await tester.runAsync(() => account.client.auth.refreshSession());
        expect(
          identical(
            AccountStoreEpochRegistry.capture(ticketAlice),
            ticket.epoch,
          ),
          isTrue,
        );
        expect(ticket.epoch.isActive, isTrue);
        expect(first.retired, isFalse);
        expect(first.initializeCalls, 1);
        expect(first.hasHostListener, isTrue);
        await tester.tap(
          find.byKey(const Key('calisthenics.lesson.media.playPause')),
        );
        await tester.pump();
        expect(first.playCalls, 1);
        expect(find.text('synthetic player surface'), findsOneWidget);
        reply.complete(
          accountHttpResponse({'deleted': true, 'userId': ticketAlice}),
        );
        await tester.runAsync(
          () => cleanupStarted.future.timeout(const Duration(seconds: 2)),
        );
        expect(confirmedIds, [ticketAlice]);
        // Receipt closes admission and detaches the active player before pump.
        expect(ticket.epoch.checkCurrent, throwsStateError);
        expect(first.hasHostListener, isFalse);
        expect(
          first.retired,
          isFalse,
          reason: 'the admitted play command must settle',
        );
        await tester.pump();
        expect(find.text('synthetic player surface'), findsNothing);
        playGate.complete();
        await tester.runAsync(
          () => videoDisposed.future.timeout(const Duration(seconds: 2)),
        );
        await tester.pumpAndSettle();
        expect(first.retired, isTrue);
        expect(first.value.isPlaying, isFalse);
        expect(first.disposeCalls, 1);
        cleanupGate.complete();
        await tester.runAsync(
          () => deletion!.timeout(const Duration(seconds: 2)),
        );
        expect(account.client.auth.currentUser?.id, ticketAlice);
        expect(
          account.client.auth.currentSession?.accessToken,
          account.refreshToken,
        );
        expect(account.logoutCalls, 0);
        expect(first.initializeCalls, 1);
      } finally {
        if (!playGate.isCompleted) playGate.complete();
        if (!cleanupGate.isCompleted) cleanupGate.complete();
        account.releasePending();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        if (deletion != null) {
          await tester.runAsync(
            () => deletion!.timeout(const Duration(seconds: 2)),
          );
        }
        identity.dispose();
        expect(tester.takeException(), isNull);
      }
    });
  });

  testWidgets('account erasure retires pending video before route rebuild', (
    tester,
  ) async {
    final identity = ValueNotifier<String?>(
      '11111111-1111-4111-8111-111111111111',
    );
    final owners = StreamController<void>.broadcast(sync: true);
    final cleanupGate = Completer<void>();
    Future<void>? cleanup;
    final first = _FakeController(videoPath);
    final gate = Completer<void>();
    first.playGate = gate;
    await AccountStoreEpochRegistry.resetForTest();
    await AccountStoreEpochRegistry.enableManagedAdmission();
    AccountStoreEpochRegistry.activate(identity.value);
    first.onPlay = () {
      cleanup = AccountStoreEpochRegistry.beginConfirmedAccountErasure(
        identity.value!,
        () => cleanupGate.future,
      );
    };
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
      identity.dispose();
      if (!cleanupGate.isCompleted) cleanupGate.complete();
      unawaited(owners.close());
    });
    await tester.pumpWidget(
      AccountScope(
        connection: AccountConnection(
          userId: identity,
          ownerSessionChanges: owners.stream,
          pageBuilder: (_) => const SizedBox(),
        ),
        currentUserId: identity.value,
        child: MaterialApp(
          home: Scaffold(
            body: LessonMediaSlot.syntheticForTesting(
              course: course,
              lessonId: 'cal-01',
              sceneId: 'gravita:cal-01:orientation',
              variantStem: stem,
              locale: 'tr',
              catalog: LessonMediaCatalog.syntheticForTesting([candidate()]),
              bundle: bundle(),
              controllerFactory: (_) => first,
              videoBuilder: (_) => const Text('synthetic player surface'),
              accountUserId: identity,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('calisthenics.lesson.media.playPause')),
    );
    await tester.pump();
    expect(identity.value, '11111111-1111-4111-8111-111111111111');
    expect(find.text('synthetic player surface'), findsNothing);
    expect(first.retired, isFalse, reason: 'admitted native play must settle');
    gate.complete();
    await tester.pumpAndSettle();
    expect(first.retired, isTrue);
    expect(first.value.isPlaying, isFalse);
    expect(first.disposeCalls, 1);
    cleanupGate.complete();
    await cleanup;
    await tester.pumpAndSettle();
    expect(
      first.initializeCalls,
      1,
      reason: 'retired slot cannot reopen itself',
    );
    await tester.pumpWidget(const SizedBox());
    await AccountStoreEpochRegistry.resetForTest();
  });

  testWidgets('synchronous account revocation waits for pending play', (
    tester,
  ) async {
    final identity = ValueNotifier<String?>(
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    );
    final first = _FakeController(videoPath);
    final gate = Completer<void>();
    first.playGate = gate;
    first.onPlay = () =>
        identity.value = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
      identity.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonMediaSlot.syntheticForTesting(
            course: course,
            lessonId: 'cal-01',
            sceneId: 'gravita:cal-01:orientation',
            variantStem: stem,
            locale: 'tr',
            catalog: LessonMediaCatalog.syntheticForTesting(
              <LessonMediaCandidate>[candidate()],
            ),
            bundle: bundle(),
            controllerFactory: (_) => first,
            videoBuilder: (_) => const Text('synthetic player surface'),
            accountUserId: identity,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('calisthenics.lesson.media.playPause')),
    );
    await tester.pump();
    expect(first.retired, isFalse);
    gate.complete();
    await tester.pumpAndSettle();
    expect(first.retired, isTrue);
    expect(first.value.isPlaying, isFalse);
    expect(find.text('synthetic player surface'), findsNothing);
  });

  testWidgets('pending play cannot outlive retirement into a new route', (
    tester,
  ) async {
    final first = _FakeController(videoPath);
    final second = _FakeController(videoPath);
    final gate = Completer<void>();
    first.playGate = gate;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    var created = 0;
    Widget route() => MaterialApp(
      home: Scaffold(
        body: LessonMediaSlot.syntheticForTesting(
          course: course,
          lessonId: 'cal-01',
          sceneId: 'gravita:cal-01:orientation',
          variantStem: stem,
          locale: 'tr',
          catalog: LessonMediaCatalog.syntheticForTesting(
            <LessonMediaCandidate>[candidate()],
          ),
          bundle: bundle(),
          controllerFactory: (_) => created++ == 0 ? first : second,
          videoBuilder: (_) => const Text('synthetic player surface'),
        ),
      ),
    );
    await tester.pumpWidget(route());
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('calisthenics.lesson.media.playPause')),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(route());
    await tester.pump();
    expect(first.retired, isFalse);
    expect(created, 1);
    gate.complete();
    await tester.pumpAndSettle();
    expect(first.retired, isTrue);
    expect(first.value.isPlaying, isFalse);
    expect(created, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('hung play quarantines the process after bounded retirement', (
    tester,
  ) async {
    final first = _FakeController(videoPath);
    final second = _FakeController(videoPath);
    final gate = Completer<void>();
    first.playGate = gate;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    var created = 0;
    Widget route() => MaterialApp(
      home: Scaffold(
        body: LessonMediaSlot.syntheticForTesting(
          course: course,
          lessonId: 'cal-01',
          sceneId: 'gravita:cal-01:orientation',
          variantStem: stem,
          locale: 'tr',
          catalog: LessonMediaCatalog.syntheticForTesting(
            <LessonMediaCandidate>[candidate()],
          ),
          bundle: bundle(),
          controllerFactory: (_) => created++ == 0 ? first : second,
          videoBuilder: (_) => const Text('synthetic player surface'),
        ),
      ),
    );
    await tester.pumpWidget(route());
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('calisthenics.lesson.media.playPause')),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(route());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(first.retired, isTrue);
    expect(created, 1);
    gate.complete();
    await tester.pumpAndSettle();
    expect(created, 1);
    expect(find.text('synthetic player surface'), findsNothing);
  });

  testWidgets(
    'hung native pause still attempts disposal and blocks reopening',
    (tester) async {
      resetLessonMediaNativeProcessForTesting();
      final fake = _FakeController(videoPath);
      final gate = Completer<void>();
      fake.pauseGate = gate;
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      var created = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonMediaSlot.syntheticForTesting(
              course: course,
              lessonId: 'cal-01',
              sceneId: 'gravita:cal-01:orientation',
              variantStem: stem,
              locale: 'tr',
              catalog: LessonMediaCatalog.syntheticForTesting(
                <LessonMediaCandidate>[candidate()],
              ),
              bundle: bundle(),
              controllerFactory: (_) {
                created++;
                return fake;
              },
              videoBuilder: (_) => const Text('synthetic player surface'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final observer =
          tester.state(find.byType(LessonMediaSlot)) as WidgetsBindingObserver;
      observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await tester.pump();
      expect(fake.retired, isFalse);
      await tester.pump(const Duration(seconds: 3));
      expect(fake.retired, isTrue);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      gate.complete();
      await tester.pumpAndSettle();
      expect(created, 1);
      expect(find.text('synthetic player surface'), findsNothing);
    },
  );
}
