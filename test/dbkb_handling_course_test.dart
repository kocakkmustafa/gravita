// Authored source-review tests; not executed in this lane.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_content/motion_content.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/calisthenics_course.dart';
import 'package:gravita/app/calisthenics_course_screen.dart';
import 'package:gravita/app/calisthenics_progress.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/dbkb_course_entry.dart';

const asset = 'content/courses/dbkb-handling.v1.json';
const integrity = 'content/motion_content/dbkb-handling.manifest.json';
class BrokenHandlingBundle extends CachingAssetBundle {
  BrokenHandlingBundle({required this.missing});
  final bool missing;
  @override
  Future<ByteData> load(String key) async {
    if (key == integrity && missing) throw StateError('missing handling manifest');
    final data = await rootBundle.load(key);
    if (key != asset || missing) return data;
    final bytes = Uint8List.fromList(Uint8List.sublistView(data));
    bytes[bytes.length - 1] = 32;
    return ByteData.sublistView(bytes);
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final raw = File(asset).readAsStringSync();
  final course = CalisthenicsCourse.parse(raw);
  test('separate bounded course cannot become physical or a camera guide', () {
    expect(course.id, 'dbkb-controlled-handling');
    expect(course.lessons.every((l) => l.learningOnly), isTrue);
    for (final change in ['physical', 'guide', 'missing correction', 'wrong sequence']) {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      final first = value['modules'][0]['lessons'][0] as Map;
      if (change == 'physical') {
        first['practiceType'] = 'physical';
      }
      if (change == 'guide') {
        value['catalogueGuides'] = [
          {'movementId': 'db-curl', 'kind': 'readingOnly', 'lessonIds': [first['id']]}
        ];
      }
      if (change == 'missing correction') {
        first.remove('correction');
      }
      if (change == 'wrong sequence') {
        first['id'] = 'dbkbh-goblet';
      }
      expect(() => CalisthenicsCourse.parse(jsonEncode(value)), throwsFormatException);
    }
  });
  test('packaging integrity and original courses survive composition', () async {
    final content = await ContentRepository.load(rootBundle);
    expect(content.dbkbHandlingCourse.id, course.id);
    expect(content.dbkbCourse.id, 'dbkb-written-foundations');
    expect(content.calisthenicsCourse.lessons, hasLength(56));
    expect(content.dbkbCourse.lessons, hasLength(12));
    final manifest = jsonDecode(await rootBundle.loadString(integrity)) as Map<String, dynamic>;
    expect(manifest['catalogDigest'], computeCatalogDigest(manifest));
    for (final missing in [true, false]) {
      await expectLater(ContentRepository.load(BrokenHandlingBundle(missing: missing)),
        throwsA(isA<ContentException>()));
    }
  });
  test('written completion remains isolated from prep and observed performance', () async {
    final dir = await Directory.systemTemp.createTemp('gravita-handling-review-');
    try {
      final handling = calisthenicsProgressStoreFor(dir, null, courseId: course.id);
      final prep = calisthenicsProgressStoreFor(dir, null, courseId: 'dbkb-written-foundations');
      final bodyweight = calisthenicsProgressStoreFor(dir, null);
      expect(handling.file.path, endsWith('/dbkb-handling-course-progress.v1.json'));
      await handling.markPractised(course, course.lessons.first);
      await handling.markCompleted(course, course.lessons.first, selfChecksConfirmed: true);
      expect((await handling.load()).completedCount(course), 1);
      expect((await prep.load()).records, isEmpty);
      expect((await bodyweight.load()).records, isEmpty);
      await expectLater(prep.markSeen(course, course.lessons.first), throwsArgumentError);
    } finally { await dir.delete(recursive: true); }
  });
  for (final language in ['en', 'tr']) {
    testWidgets('handling route is distinct and shows limits in $language', (tester) async {
      final content = (await tester.runAsync(() => ContentRepository.load(rootBundle)))!;
      await tester.pumpWidget(MaterialApp(
        locale: Locale(language), supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: Scaffold(body: SingleChildScrollView(child: DbkbEntryCard(content: content)))));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dbkb.entry')), findsOneWidget);
      final entry = find.byKey(const Key('dbkb.handling.entry'));
      await tester.ensureVisible(entry); await tester.tap(entry); await tester.pumpAndSettle();
      expect(find.byType(CalisthenicsCourseScreen), findsOneWidget);
      expect(find.text(course.title.inLanguage(language)), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
