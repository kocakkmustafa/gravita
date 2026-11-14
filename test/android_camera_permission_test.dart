import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/camera_release_policy.dart';

void main() {
  test('camera flag off: Android manifests declare no CAMERA permission', () {
    expect(motionPaidCameraLaunchEnabled, isFalse,
        reason: 'Flag is on: restore the permission, update this test.');
    for (final String path in <String>[
      'android/app/src/main/AndroidManifest.xml',
      'android/app/src/debug/AndroidManifest.xml',
      'android/app/src/profile/AndroidManifest.xml',
    ]) {
      final File f = File(path);
      if (!f.existsSync()) {
        expect(path.contains('/main/'), isFalse, reason: '$path yok');
        continue;
      }
      final String xml = f.readAsStringSync();
      expect(xml.contains('android.permission.CAMERA'), isFalse, reason: path);
      expect(xml.contains('android.hardware.camera'), isFalse, reason: path);
    }
  });
}
