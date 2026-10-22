// Authored for the coordinated qualification lane. Not run in the authoring task.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_content/motion_content.dart';
import 'package:gravita/app/account_data_directory.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/calisthenics_course.dart';
import 'package:gravita/app/calisthenics_course_screen.dart';
import 'package:gravita/app/calisthenics_progress.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/dbkb_course_entry.dart';
import 'package:gravita/app/home_screen.dart';
import 'package:gravita/app/library_screen.dart';
import 'package:gravita/app/theme.dart';
import 'support/locale_asset_harness.dart' show warmActualLocaleAssets, pumpActualLocaleReady;

const asset = 'content/courses/dbkb-written.v1.json';
const manifest = 'content/motion_content/dbkb-written.manifest.json';
const accountA = '11111111-1111-4111-8111-111111111111';
const accountB = '22222222-2222-4222-8222-222222222222';

class AlteredBundle extends CachingAssetBundle {
  AlteredBundle({this.missing = false});
  final bool missing;
  @override
  Future<ByteData> load(String key) async {
    if (key == manifest && missing) throw StateError('missing DB/KB manifest');
    final value = await rootBundle.load(key);
    if (key != asset || missing) return value;
    final bytes = Uint8List.fromList(Uint8List.sublistView(value));
    // Same length, still valid JSON, wrong immutable asset hash.
    bytes[bytes.length - 1] = 32;
    return ByteData.sublistView(bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(warmActualLocaleAssets);
  final source = File(asset).readAsStringSync();
  final course = CalisthenicsCourse.parse(source);
  late Directory support;
  setUp(() async {
    support = await Directory.systemTemp.createTemp('gravita-dbkb-written-');
  });
  tearDown(() async {
    if (await support.exists()) await support.delete(recursive: true);
  });
  Widget host(Widget child, String language) => MaterialApp(
    theme: GravitaTheme.light,
    locale: Locale(language),
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    home: child,
  );

  test('packaged course retains legacy content and has bounded written tasks', () async {
    final content = await ContentRepository.load(rootBundle);
    expect(await rootBundle.loadString(asset), source);
    expect(content.dbkbCourse.id, 'dbkb-written-foundations');
    expect(content.calisthenicsCourse.lessons, hasLength(56));
    expect(content.calisthenicsCourse.version, '1.0.0');
    expect(course.lessons.where((l) => !l.learningOnly).map((l) => l.id),
      ['dbkb-04', 'dbkb-05', 'dbkb-08', 'dbkb-10', 'dbkb-11']);
    for (final lesson in course.lessons) {
      expect(lesson.recall, isNotNull);
      expect(lesson.correction, isNotNull);
      expect(lesson.answer, isNotNull);
    }
    expect(course.lessons[5].learningOnly, isTrue);
    expect(course.lessons[6].learningOnly, isTrue);
    expect(course.lessons[8].learningOnly, isTrue);
  });

  test('tampered or missing DB/KB integrity asset blocks repository load', () async {
    for (final bundle in [AlteredBundle(), AlteredBundle(missing: true)]) {
      await expectLater(ContentRepository.load(bundle), throwsA(isA<ContentException>()));
    }
  });

  test('missing recall and promoted loaded task are rejected', () {
    final raw = jsonDecode(source) as Map<String, dynamic>;
    final first = ((raw['modules'] as List).first['lessons'] as List).first as Map;
    first.remove('recall');
    expect(() => CalisthenicsCourse.parse(jsonEncode(raw)), throwsFormatException);
    final changed = jsonDecode(source) as Map<String, dynamic>;
    ((changed['modules'] as List)[1]['lessons'] as List)[2]['practiceType'] = 'physical';
    expect(() => CalisthenicsCourse.parse(jsonEncode(changed)), throwsFormatException);
  });

  test('course/account/guest journals are separate and retain legacy filename', () async {
    final dbA = calisthenicsProgressStoreFor(support, accountA, courseId: course.id);
    final dbB = calisthenicsProgressStoreFor(support, accountB, courseId: course.id);
    final guest = calisthenicsProgressStoreFor(support, null, courseId: course.id);
    final legacy = calisthenicsProgressStoreFor(support, accountA);
    expect(legacy.file.path, endsWith('/calisthenics-course-progress.v1.json'));
    expect(dbA.file.path, endsWith('/dbkb-written-course-progress.v1.json'));
    await dbA.markPractised(course, course.lessons.first);
    await dbA.markCompleted(course, course.lessons.first, selfChecksConfirmed: true);
    expect((await dbA.load()).completedCount(course), 1);
    expect((await dbB.load()).records, isEmpty);
    expect((await guest.load()).records, isEmpty);
    expect((await legacy.load()).records, isEmpty);
    await expectLater(legacy.markSeen(course, course.lessons.first), throwsArgumentError);
    // Deletion uses the existing account-directory boundary for both courses.
    await deleteAccountData(support, accountA);
    expect(await dbA.file.exists(), isFalse);
    expect((await dbB.load()).records, isEmpty);
  });

  for (final language in ['en', 'tr']) {
    testWidgets('real home/library entry and preparation reuse in $language', (tester) async {
      final content = (await tester.runAsync(() => ContentRepository.load(rootBundle)))!;
      for (final page in <Widget>[
        HomeScreen(content: content, onBrowseLibrary: () {}),
        LibraryScreen(content: content),
      ]) {
        await tester.pumpWidget(host(page, language));
        await pumpActualLocaleReady(tester);
        await tester.pumpAndSettle();
        expect(find.byType(DbkbEntryCard), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('dbkb.entry')));
        await tester.tap(find.byKey(const Key('dbkb.entry')));
        await tester.pumpAndSettle();
        expect(find.text(content.dbkbCourse.title.inLanguage(language)), findsOneWidget);
        // Reading remains accessible even when default storage is unavailable.
        await tester.pumpWidget(const SizedBox.shrink());
      }
      await tester.pumpWidget(host(Scaffold(body: SingleChildScrollView(
        child: DbkbEntryCard(content: content))), language));
      await pumpActualLocaleReady(tester);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('dbkb.preparation.cal-09')));
      await tester.tap(find.byKey(const Key('dbkb.preparation.cal-09')));
      await tester.pumpAndSettle();
      expect(find.text(content.calisthenicsCourse.lessons
        .singleWhere((l) => l.id == 'cal-09').title.inLanguage(language)), findsOneWidget);
    });

    testWidgets('answer starts hidden and physical preparation is retained in $language', (tester) async {
      final store = calisthenicsProgressStoreFor(support, null, courseId: course.id);
      final lesson = course.lessons.first;
      await tester.pumpWidget(host(CalisthenicsLessonScreen(
        course: course, lesson: lesson, storeLoader: (_) async => store), language));
      await pumpActualLocaleReady(tester);
      await tester.pumpAndSettle();
      expect(find.text(lesson.answer!.inLanguage(language)), findsNothing);
      final toggle = find.byKey(const Key('dbkb.answer.toggle'));
      await tester.scrollUntilVisible(toggle, 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(lesson.answer!.inLanguage(language)), 100, scrollable: find.byType(Scrollable).first);
      expect(find.text(lesson.answer!.inLanguage(language)), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(host(CalisthenicsLessonScreen(
        course: course, lesson: course.lessons[3], storeLoader: (_) async => store), language));
      await pumpActualLocaleReady(tester);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const Key('calisthenics.prepared')), 200, scrollable: find.byType(Scrollable).first);
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('calisthenics.prepared'))).value, isFalse);
      expect(find.byKey(const Key('calisthenics.lesson.media')), findsNothing);
    });
  }
}
