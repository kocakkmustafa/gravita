import 'dart:convert';

import 'package:gravita/app/gravita_source_projection_pin.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_content/motion_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('app bundle contains both exact v2l source-only assets', () async {
    final courseBytes = await rootBundle.load(
      GravitaSourceProjectionPin.coursePath,
    );
    final sliceBytes = await rootBundle.load(
      GravitaSourceProjectionPin.slicePath,
    );
    final projectionBytes = await rootBundle.load(
      GravitaSourceProjectionPin.projectionPath,
    );
    expect(
      computeSha256Hex(
        courseBytes.buffer.asUint8List(
          courseBytes.offsetInBytes,
          courseBytes.lengthInBytes,
        ),
      ),
      GravitaSourceProjectionPin.courseSha256,
    );
    expect(
      computeSha256Hex(
        sliceBytes.buffer.asUint8List(
          sliceBytes.offsetInBytes,
          sliceBytes.lengthInBytes,
        ),
      ),
      GravitaSourceProjectionPin.sliceSha256,
    );
    expect(
      computeSha256Hex(
        projectionBytes.buffer.asUint8List(
          projectionBytes.offsetInBytes,
          projectionBytes.lengthInBytes,
        ),
      ),
      GravitaSourceProjectionPin.projectionSha256,
    );
    expect(sliceBytes.lengthInBytes, 256998);
    expect(projectionBytes.lengthInBytes, 221935);

    final slice =
        jsonDecode(
              utf8.decode(
                sliceBytes.buffer.asUint8List(
                  sliceBytes.offsetInBytes,
                  sliceBytes.lengthInBytes,
                ),
              ),
            )
            as Map;
    final projection =
        jsonDecode(
              utf8.decode(
                projectionBytes.buffer.asUint8List(
                  projectionBytes.offsetInBytes,
                  projectionBytes.lengthInBytes,
                ),
              ),
            )
            as Map;
    expect(slice['appId'], GravitaSourceProjectionPin.appId);
    expect(projection['appId'], GravitaSourceProjectionPin.appId);
    expect(
      projection['courseSourceSHA256'],
      GravitaSourceProjectionPin.courseSha256,
    );
    expect(
      projection['sourceCatalogSHA256'],
      GravitaSourceProjectionPin.sourceCatalogSha256,
    );
    expect(
      projection['sourceManifestSHA256'],
      GravitaSourceProjectionPin.sourceManifestSha256,
    );
    expect(
      (slice['lessons'] as List).length,
      GravitaSourceProjectionPin.lessonCount,
    );
    expect(
      (projection['rows'] as List).length,
      GravitaSourceProjectionPin.variantCount,
    );
    expect((slice['holds'] as List).single, <String, Object>{
      'app': 'gravita',
      'lessonId': 'cal-01',
      'sceneId': 'gravita:cal-01:full_sequence-03',
      'status': 'HOLD_VERIFIED_EQUIPMENT',
    });
    expect(
      (projection['rows'] as List).where((row) => (row as List)[10] == true),
      hasLength(GravitaSourceProjectionPin.heldCount),
    );
  });
}
