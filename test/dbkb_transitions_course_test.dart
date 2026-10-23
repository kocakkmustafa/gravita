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
import 'package:gravita/app/library_screen.dart';
import 'support/locale_asset_harness.dart' show warmActualLocaleAssets, pumpActualLocaleReady;
import 'support/paywall_harness.dart' show asSubscriber;

const asset = 'content/courses/dbkb-transitions.v1.json';
const integrity = 'content/motion_content/dbkb-transitions.manifest.json';
class BrokenTransitionsBundle extends CachingAssetBundle {
  BrokenTransitionsBundle({required this.missing});
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
Future<void> reveal(WidgetTester tester, Finder target) async {
  final scroll = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(target, 200, scrollable: scroll, maxScrolls: 150);
  for (var i = 0; target.hitTestable().evaluate().isEmpty && i < 100; i++) {
    final center = tester.getCenter(target);
    final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    await tester.drag(scroll, Offset(0, center.dy > height / 2 ? -160 : 160));
    await tester.pump();
  }
  expect(target.hitTestable(), findsOneWidget,
    reason: 'A built child inside the long entry card must actually be tappable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(warmActualLocaleAssets);
  final raw = File(asset).readAsStringSync();
  final course = CalisthenicsCourse.parse(raw);
  test('separate bounded course cannot become physical or a camera guide', () {
    expect(course.id, 'dbkb-supported-transitions');
    expect(course.lessons.every((l) => l.learningOnly), isTrue);
    expect(course.lessons, hasLength(2));
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
        first['id'] = 'dbkbt-wrong-variant';
      }
      expect(() => CalisthenicsCourse.parse(jsonEncode(value)), throwsFormatException);
    }
  });

  test('strict transitions parser rejects altered boundaries and broken links', () {
    final mutations = <String, void Function(Map<String, dynamic>)>{
      'unsupported version': (v) => v['version'] = '2.0.0',
      'not self report': (v) => v['evidenceMode'] = 'camera',
      'extra lesson': (v) => (v['modules'][0]['lessons'] as List).add(v['modules'][0]['lessons'][0]),
      'reversed lesson order': (v) => v['modules'][0]['lessons'] = (v['modules'][0]['lessons'] as List).reversed.toList(),
      'missing prerequisite': (v) => v['modules'][0]['lessons'][1]['prerequisites'] = [],
      'wrong prerequisite': (v) => v['modules'][0]['lessons'][1]['prerequisites'] = ['dbkbh-i'],
      'unknown source': (v) => v['modules'][0]['lessons'][0]['sourceIds'] = ['missing'],
      'empty Turkish equipment block': (v) => v['modules'][0]['lessons'][0]['steps'][0]['tr'] = '',
      'missing protocol block': (v) => (v['modules'][0]['lessons'][1]['steps'] as List).removeLast(),
      'missing demonstration limit': (v) => v['modules'][0]['lessons'][0].remove('mediaBrief'),
      'missing answer': (v) => v['modules'][0]['lessons'][0].remove('answer'),
    };
    for (final entry in mutations.entries) {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      entry.value(value);
      expect(() => CalisthenicsCourse.parse(jsonEncode(value)),
        throwsFormatException, reason: entry.key);
    }
  });
  test('packaging integrity and original courses survive composition', () async {
    final content = await ContentRepository.load(rootBundle);
    expect(content.dbkbTransitionsCourse.id, course.id);
    expect(content.dbkbCourse.id, 'dbkb-written-foundations');
    expect(content.calisthenicsCourse.lessons, hasLength(56));
    expect(content.dbkbCourse.lessons, hasLength(12));
    expect(content.dbkbHandlingCourse.lessons, hasLength(11));
    final manifest = jsonDecode(await rootBundle.loadString(integrity)) as Map<String, dynamic>;
    expect(manifest['catalogDigest'], computeCatalogDigest(manifest));
    for (final missing in [true, false]) {
      await expectLater(ContentRepository.load(BrokenTransitionsBundle(missing: missing)),
        throwsA(isA<ContentException>()));
    }
  });
  test('written completion remains isolated from prep and observed performance', () async {
    final dir = await Directory.systemTemp.createTemp('gravita-handling-review-');
    try {
      final handling = calisthenicsProgressStoreFor(dir, null, courseId: course.id);
      final prep = calisthenicsProgressStoreFor(dir, null, courseId: 'dbkb-written-foundations');
      final bodyweight = calisthenicsProgressStoreFor(dir, null);
      expect(handling.file.path, endsWith('/dbkb-transitions-course-progress.v1.json'));
      await handling.markPractised(course, course.lessons.first);
      await handling.markCompleted(course, course.lessons.first, selfChecksConfirmed: true);
      expect((await handling.load()).completedCount(course), 1);
      expect((await prep.load()).records, isEmpty);
      expect((await bodyweight.load()).records, isEmpty);
      final oldHandling = calisthenicsProgressStoreFor(dir, null, courseId: 'dbkb-controlled-handling');
      expect((await oldHandling.load()).records, isEmpty);
      await expectLater(prep.markSeen(course, course.lessons.first), throwsArgumentError);
    } finally { await dir.delete(recursive: true); }
  });
  for (final language in ['en', 'tr']) {
    testWidgets('handling route is distinct and shows limits in $language', (tester) async {
      final content = (await tester.runAsync(() => ContentRepository.load(rootBundle)))!;
      await tester.pumpWidget(asSubscriber(MaterialApp(
        locale: Locale(language), supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: LibraryScreen(content: content))));
      await pumpActualLocaleReady(tester);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const Key('dbkb.entry')), 200,
        scrollable: find.byType(Scrollable).first, maxScrolls: 100);
      expect(find.byKey(const Key('dbkb.entry')), findsOneWidget);
      final entry = find.byKey(const Key('dbkb.transitions.entry'));
      await tester.scrollUntilVisible(entry, 200,
        scrollable: find.byType(Scrollable).first, maxScrolls: 100);
      await reveal(tester, entry);
      await tester.ensureVisible(entry); await tester.tap(entry); await tester.pumpAndSettle();
      expect(find.byType(CalisthenicsCourseScreen), findsOneWidget);
      expect(find.text(course.title.inLanguage(language)), findsOneWidget);
      expect(course.lessons.map((l) => l.id), orderedEquals([
        'dbkbt-supported-goblet', 'dbkbt-single-kb-floor-press']));
      expect(course.lessons.first.prerequisites, isEmpty);
      expect(course.lessons.last.prerequisites, ['dbkbt-supported-goblet']);
      for (final lesson in course.lessons) {
        final tile = find.byKey(Key('calisthenics.lesson.${lesson.id}'));
        await tester.scrollUntilVisible(tile, 200,
          scrollable: find.byType(Scrollable).first, maxScrolls: 150);
        await reveal(tester, tile);
        await tester.ensureVisible(tile);
        await tester.tap(tile); await tester.pumpAndSettle();
        expect(find.byType(CalisthenicsLessonScreen), findsOneWidget);
        expect(find.text(lesson.title.inLanguage(language)), findsOneWidget);
        expect(find.byKey(const Key('calisthenics.prepared')), findsNothing);
        await tester.tap(find.byType(BackButton)); await tester.pumpAndSettle();
        for (var flush = 0; flush < 8; flush++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
          await tester.pump();
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
