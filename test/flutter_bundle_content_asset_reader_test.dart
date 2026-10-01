import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/calisthenics_course.dart';
import 'package:gravita/app/flutter_bundle_content_asset_reader.dart';
import 'package:motion_content/motion_content.dart';

const String _manifestPath = 'content/motion_content/manifest.json';
const String _coursePath = 'content/courses/calisthenics.v1.json';

final class _ManifestOverlayBundle extends CachingAssetBundle {
  _ManifestOverlayBundle(this.manifestBytes);

  final Uint8List manifestBytes;
  final List<String> requestedPaths = <String>[];

  @override
  Future<ByteData> load(String key) {
    requestedPaths.add(key);
    if (key == _manifestPath) {
      return Future<ByteData>.value(
        ByteData.view(
          manifestBytes.buffer,
          manifestBytes.offsetInBytes,
          manifestBytes.lengthInBytes,
        ),
      );
    }
    return rootBundle.load(key);
  }
}

Future<Uint8List> _manifestBytes({
  String? assetPath,
  String? assetSha256,
}) async {
  final ByteData data = await rootBundle.load(_manifestPath);
  final Uint8List bytes = Uint8List.fromList(Uint8List.sublistView(data));
  if (assetPath == null && assetSha256 == null) return bytes;

  final Map<String, dynamic> manifest = (jsonDecode(utf8.decode(bytes)) as Map)
      .cast<String, dynamic>();
  final Map<String, dynamic> asset =
      ((manifest['assets'] as List).single as Map).cast<String, dynamic>();
  if (assetPath != null) asset['path'] = assetPath;
  if (assetSha256 != null) asset['sha256'] = assetSha256;
  manifest['catalogDigest'] = computeCatalogDigest(manifest);
  return Uint8List.fromList(utf8.encode(jsonEncode(manifest)));
}

ContentBundleLoader _loader(_ManifestOverlayBundle bundle) =>
    ContentBundleLoader(
      reader: FlutterBundleContentAssetReader(bundle: bundle),
      expectedAppId: 'com.yulalab.gravita',
      currentCoreContract: currentMotionContentContract,
      manifestPath: _manifestPath,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reads pinned Calisthenics bytes and parses the active course',
    () async {
      final _ManifestOverlayBundle bundle = _ManifestOverlayBundle(
        await _manifestBytes(),
      );
      final ContentLoadResult result = await _loader(bundle).load();

      expect(result, isA<ContentReady>());
      final ContentReady ready = result as ContentReady;
      expect(ready.catalog.manifest.assets.single.path, _coursePath);
      expect(ready.catalog.manifest.courses, isEmpty);
      expect(ready.catalog.manifest.lessons, isEmpty);
      expect(ready.catalog.manifest.models, isEmpty);
      expect(bundle.requestedPaths, <String>[_manifestPath, _coursePath]);

      final Uint8List bytes = await ready.assets.read(_coursePath);
      expect(bytes.length, ready.catalog.manifest.assets.single.byteLength);
      expect(
        computeSha256Hex(bytes),
        ready.catalog.manifest.assets.single.sha256,
      );
      final CalisthenicsCourse course = CalisthenicsCourse.parse(
        utf8.decode(bytes),
      );
      expect(course.id, 'calisthenics-foundations');
      expect(course.modules, hasLength(10));
      expect(course.lessons, hasLength(56));
      expect(bundle.requestedPaths.last, _coursePath);
    },
  );

  test('wrong pinned hash blocks course before exposure', () async {
    final _ManifestOverlayBundle bundle = _ManifestOverlayBundle(
      await _manifestBytes(assetSha256: List<String>.filled(64, '0').join()),
    );
    final ContentLoadResult result = await _loader(bundle).load();

    expect(result, isA<ContentBlocked>());
    expect(
      (result as ContentBlocked).error.code,
      ContentErrorCode.hashMismatch,
    );
  });

  test('unsafe manifest path blocks without a course bundle read', () async {
    final _ManifestOverlayBundle bundle = _ManifestOverlayBundle(
      await _manifestBytes(assetPath: 'content/../private.json'),
    );
    final ContentLoadResult result = await _loader(bundle).load();

    expect(result, isA<ContentBlocked>());
    expect((result as ContentBlocked).error.code, ContentErrorCode.unsafePath);
    expect(bundle.requestedPaths, <String>[_manifestPath]);
  });

  test('direct reader rejects unsafe path before Flutter lookup', () async {
    final _ManifestOverlayBundle bundle = _ManifestOverlayBundle(
      await _manifestBytes(),
    );
    final FlutterBundleContentAssetReader reader =
        FlutterBundleContentAssetReader(bundle: bundle);

    await expectLater(
      reader.read('../private.json'),
      throwsA(
        isA<ContentException>().having(
          (ContentException error) => error.error.code,
          'code',
          ContentErrorCode.unsafePath,
        ),
      ),
    );
    expect(bundle.requestedPaths, isEmpty);
  });
}
