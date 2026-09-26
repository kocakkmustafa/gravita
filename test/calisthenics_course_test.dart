import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_data_directory.dart';
import 'package:gravita/app/calisthenics_course.dart';
import 'package:gravita/app/calisthenics_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final text = File('content/courses/calisthenics.v1.json').readAsStringSync();
  final course = CalisthenicsCourse.parse(text);
  const a = '11111111-1111-4111-8111-111111111111';
  const b = '22222222-2222-4222-8222-222222222222';
  late Directory support;
  setUp(
    () async =>
        support = await Directory.systemTemp.createTemp('gravita-course-'),
  );
  tearDown(() async {
    if (await support.exists()) await support.delete(recursive: true);
  });
  test('complete original bilingual course and advanced literacy boundary', () {
    expect(course.lessons.length, 56);
    expect(course.modules.map((m) => m.lessons.length), [
      6,
      8,
      7,
      7,
      8,
      4,
      5,
      4,
      3,
      4,
    ]);
    expect(
      course.modules
          .singleWhere((m) => m.id == 'literacy')
          .lessons
          .every((l) => l.learningOnly),
      isTrue,
    );
    expect(course.lessons[0].learningOnly, isTrue);
    expect(course.lessons[35].steps[1].en, contains('one foot firmly'));
    expect(course.lessons[42].steps.last.en, contains('lower both knees'));
    final manifest =
        jsonDecode(
              File(
                'content/courses/calisthenics.media-briefs.v1.json',
              ).readAsStringSync(),
            )
            as Map;
    expect(manifest['trainingData'], false);
    expect((manifest['lessons'] as List).length, course.lessons.length);
    for (var i = 0; i < course.lessons.length; i++) {
      expect(
        (manifest['lessons'] as List)[i]['mediaBrief']['tr'],
        course.lessons[i].mediaBrief.tr,
      );
    }
  });
  test('real packaged asset equals authoring artifact', () async {
    expect(
      await rootBundle.loadString('content/courses/calisthenics.v1.json'),
      text,
    );
  });
  test(
    'validator rejects missing translation, invalid source and prerequisites',
    () {
      for (final change in <void Function(Map<String, dynamic>)>[
        (j) => j['modules'][0]['lessons'][0]['title']['tr'] = '',
        (j) => j['modules'][0]['lessons'][0]['sourceIds'] = ['unbound'],
        (j) => j['modules'][0]['lessons'][1]['prerequisites'] = ['cal-56'],
        (j) => j['modules'][7]['lessons'][0]['practiceType'] = 'physical',
        (j) => j['catalogueGuides'][0]['lessonIds'] = ['missing-lesson'],
        (j) => j['catalogueGuides'][0]['kind'] = 'readingOnly',
        (j) => j['catalogueGuides'][1]['movementId'] = 'bodyweight_squat',
        (j) => j['catalogueGuides'][0]['lessonIds'] = ['cal-08', 'cal-08'],
      ]) {
        final j = (jsonDecode(text) as Map).cast<String, dynamic>();
        change(j);
        expect(
          () => CalisthenicsCourse.parse(jsonEncode(j)),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'seen, task practice, completion are separate and reread from file',
    () async {
      final store = calisthenicsProgressStoreFor(support, a);
      final lesson = course.lessons.first;
      await store.markSeen(course, lesson);
      expect(
        (await CalisthenicsProgressStore(
          store.file,
        ).load()).forLesson(lesson, course.version)?.state,
        CalisthenicsLessonState.seen,
      );
      await expectLater(
        store.markCompleted(course, lesson, selfChecksConfirmed: true),
        throwsStateError,
      );
      expect(
        () => store.markCompleted(course, lesson, selfChecksConfirmed: false),
        throwsStateError,
      );
      await store.markPractised(course, lesson);
      final complete = await store.markCompleted(
        course,
        lesson,
        selfChecksConfirmed: true,
      );
      expect(complete.completedCount(course), 1);
      final reloaded = await CalisthenicsProgressStore(
        File(store.file.path),
      ).load();
      final record = reloaded.forLesson(lesson, course.version)!;
      expect(record.practiceCount, 1);
      expect(record.seenAt.isUtc, isTrue);
      expect(record.lastPractisedAt, isNotNull);
      expect(record.completedAt, isNotNull);
      expect(reloaded.nextLesson(course)?.id, 'cal-02');
      expect(await File('${store.file.path}.tmp').exists(), false);
    },
  );
  test('guest and two accounts stay isolated', () async {
    final guest = calisthenicsProgressStoreFor(support, null);
    final one = calisthenicsProgressStoreFor(support, a);
    final two = calisthenicsProgressStoreFor(support, b);
    await guest.markPractised(course, course.lessons.first);
    await one.markSeen(course, course.lessons[1]);
    expect((await two.load()).records, isEmpty);
    expect((await one.load()).records.keys, ['cal-02']);
    expect((await guest.load()).records.keys, ['cal-01']);
    expect(await localAccountIds(support), [a]);
  });
  test('serial writes from two stores preserve every report', () async {
    final one = calisthenicsProgressStoreFor(support, a);
    final two = calisthenicsProgressStoreFor(support, a);
    await Future.wait(
      List.generate(
        8,
        (i) =>
            (i.isEven ? one : two).markPractised(course, course.lessons.first),
      ),
    );
    expect(
      (await one.load())
          .forLesson(course.lessons.first, course.version)
          ?.practiceCount,
      8,
    );
  });
  test(
    'old content version excluded and replaced by fresh learning state',
    () async {
      final store = calisthenicsProgressStoreFor(support, a);
      await store.markPractised(course, course.lessons.first);
      await store.markCompleted(
        course,
        course.lessons.first,
        selfChecksConfirmed: true,
      );
      final j = (jsonDecode(await store.file.readAsString()) as Map)
          .cast<String, dynamic>();
      j['lessons']['cal-01']['contentVersion'] = '0.9.0';
      await store.file.writeAsString(jsonEncode(j));
      expect((await store.load()).completedCount(course), 0);
      final next = await store.markSeen(course, course.lessons.first);
      expect(
        next.forLesson(course.lessons.first, course.version)?.state,
        CalisthenicsLessonState.seen,
      );
      expect(
        next.forLesson(course.lessons.first, course.version)?.practiceCount,
        0,
      );
    },
  );
  test(
    'account deletion drains writes and blocks old/new stores without touching guest',
    () async {
      final guest = calisthenicsProgressStoreFor(support, null);
      final store = calisthenicsProgressStoreFor(support, a);
      await guest.markPractised(course, course.lessons.first);
      await store.markSeen(course, course.lessons.first);
      final pending = store
          .markPractised(course, course.lessons.first)
          .then<Object?>((v) => v, onError: (Object e) => e);
      await deleteAccountData(support, a);
      await pending;
      expect(await accountDataDirectory(support, a).exists(), false);
      await expectLater(
        store.markPractised(course, course.lessons.first),
        throwsStateError,
      );
      expect(() => calisthenicsProgressStoreFor(support, a), throwsStateError);
      expect((await guest.load()).records, isNotEmpty);
    },
  );
  test('malformed file does not silently overwrite data', () async {
    final store = calisthenicsProgressStoreFor(support, a);
    await store.file.parent.create(recursive: true);
    await store.file.writeAsString('broken');
    await expectLater(
      store.markSeen(course, course.lessons.first),
      throwsFormatException,
    );
    expect(await store.file.readAsString(), 'broken');
  });
}
