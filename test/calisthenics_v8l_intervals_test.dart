import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/calisthenics_course.dart';
import 'package:gravita/app/gravita_source_projection_pin.dart';
import 'package:motion_content/motion_content.dart';

// GRV-07 (a): v8l binds watched NHS intervals to three lessons as evidence
// only. The course bytes stay pinned by the ops v2k contract, the v2l
// projection and the media source pins, so v8l must not change them.
void main() {
  final courseBytes = File(
    'content/courses/calisthenics.v1.json',
  ).readAsBytesSync();
  final layer =
      jsonDecode(
            File(
              'content/courses/calisthenics.v8l-overlay.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>;

  test('v8l is pinned to the unchanged course and the v8k parent', () {
    expect(layer['editorialLayer'], 'v8l');
    expect(layer['courseBytesChanged'], isFalse);
    expect(
      computeSha256Hex(courseBytes),
      GravitaSourceProjectionPin.courseSha256,
    );
    expect(layer['courseSha256'], GravitaSourceProjectionPin.courseSha256);
    expect(
      layer['parentOverlaySha256'],
      computeSha256Hex(
        File('content/courses/calisthenics.v8k-overlay.json').readAsBytesSync(),
      ),
    );
  });

  test('v8l binds sampled NHS intervals to existing physical lessons', () {
    final course = CalisthenicsCourse.parse(utf8.decode(courseBytes));
    final lessons = {for (final l in course.lessons) l.id: l};
    final bindings = layer['lessonIntervalBindings']! as Map<String, Object?>;
    expect(bindings.keys, ['cal-04', 'cal-08', 'cal-15']);
    for (final MapEntry(key: id, value: items) in bindings.entries) {
      expect(lessons[id]?.practiceType, 'physical', reason: id);
      for (final item in (items! as List).cast<Map<String, Object?>>()) {
        final times = (item['sampledSeconds']! as List).cast<num>();
        expect(times.length, greaterThanOrEqualTo(2), reason: id);
        expect(times.first, greaterThanOrEqualTo(0), reason: id);
        expect(times.last, lessThanOrEqualTo(item['durationSeconds']! as num));
        for (final scope in ['supports', 'doesNotSupport']) {
          final text = item[scope]! as Map<String, Object?>;
          expect(text.keys.toSet(), {'en', 'tr'}, reason: '$id $scope');
        }
      }
    }
    final record = layer['reviewRecord']! as Map<String, Object?>;
    expect(record['method'], contains('not continuous'));
  });
}
