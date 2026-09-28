import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/content_failure.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:motion_content/motion_content.dart';

const String _manifestPath = 'content/motion_content/manifest.json';
const String _coursePath = 'content/courses/calisthenics.v1.json';

final class _AssetOverlayBundle extends CachingAssetBundle {
  _AssetOverlayBundle({
    this.courseBytes,
    this.missingManifest = false,
    this.missingCourse = false,
  });

  final Uint8List? courseBytes;
  final bool missingManifest;
  final bool missingCourse;
  final List<String> requestedPaths = <String>[];

  @override
  Future<ByteData> load(String key) {
    requestedPaths.add(key);
    if ((key == _manifestPath && missingManifest) ||
        (key == _coursePath && missingCourse)) {
      throw StateError('asset unavailable: $key');
    }
    if (key == _coursePath && courseBytes != null) {
      final Uint8List bytes = courseBytes!;
      return Future<ByteData>.value(
        ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes),
      );
    }
    return rootBundle.load(key);
  }
}

Future<ContentException> _rejection(_AssetOverlayBundle bundle) async {
  try {
    await ContentRepository.load(bundle);
  } on ContentException catch (error) {
    return error;
  }
  throw StateError('Expected the course integrity gate to reject the bundle');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real packaged manifest verifies the 56-lesson startup course',
    () async {
      final _AssetOverlayBundle bundle = _AssetOverlayBundle();
      final ContentRepository content = await ContentRepository.load(bundle);

      expect(content.calisthenicsCourse.modules, hasLength(10));
      expect(content.calisthenicsCourse.lessons, hasLength(56));
      expect(bundle.requestedPaths, contains(_manifestPath));
      expect(
        bundle.requestedPaths.where((path) => path == _coursePath),
        hasLength(2),
      );
    },
  );

  test(
    'same-length, parseable course tamper is blocked as integrity',
    () async {
      final ByteData originalData = await rootBundle.load(_coursePath);
      final Uint8List original = Uint8List.sublistView(originalData);
      final Uint8List changed = Uint8List.fromList(original);
      changed[changed.length - 1] = original.last == 10 ? 32 : 10;
      expect(changed.length, original.length);
      expect(() => jsonDecode(utf8.decode(changed)), returnsNormally);
      final _AssetOverlayBundle bundle = _AssetOverlayBundle(
        courseBytes: changed,
      );

      final ContentException error = await _rejection(bundle);
      expect(error.error.code, ContentErrorCode.hashMismatch);
      expect(ContentFailure.from(error).kind, ContentFailureKind.integrity);
      expect(bundle.requestedPaths, contains(_manifestPath));
      expect(bundle.requestedPaths, contains(_coursePath));
    },
  );

  test('missing packaged manifest stays a retryable read failure', () async {
    final _AssetOverlayBundle bundle = _AssetOverlayBundle(
      missingManifest: true,
    );
    final ContentException error = await _rejection(bundle);
    expect(error.error.code, ContentErrorCode.missingAsset);
    expect(ContentFailure.from(error).kind, ContentFailureKind.unreadable);
    expect(bundle.requestedPaths, contains(_manifestPath));
    expect(bundle.requestedPaths, isNot(contains(_coursePath)));
  });

  test('missing packaged course stays a retryable read failure', () async {
    final _AssetOverlayBundle bundle = _AssetOverlayBundle(missingCourse: true);
    final ContentException error = await _rejection(bundle);
    expect(error.error.code, ContentErrorCode.missingAsset);
    expect(ContentFailure.from(error).kind, ContentFailureKind.unreadable);
    expect(bundle.requestedPaths, contains(_coursePath));
  });
}
