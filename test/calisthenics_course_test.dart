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
  test('v8g warm-up and row cues preserve a prior progress record', () async {
    expect(course.version, '1.0.0');
    final warmup = course.lessons.singleWhere((item) => item.id == 'cal-04');
    final row = course.lessons.singleWhere((item) => item.id == 'cal-24');
    expect(warmup.practice.en, contains('not the complete warm-up'));
    expect(warmup.mediaBrief.tr, contains('2–4 dakikayı herkes için yeterli'));
    expect(row.steps[1].en, contains('at a low bar'));
    expect(row.steps[1].en, contains('in suspension'));
    expect(row.steps[1].en, isNot(contains('farther out')));
    expect(
      row.practice.en,
      contains(
        'compare 2 controlled repetitions at the familiar option with 2',
      ),
    );
    expect(row.mediaBrief.en, contains('not a universal foot direction'));

    final store = calisthenicsProgressStoreFor(support, a);
    await store.file.parent.create(recursive: true);
    await store.file.writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'courseId': course.id,
        'lessons': {
          'cal-04': {
            'contentVersion': '1.0.0',
            'state': 'selfReportedComplete',
            'seenAt': '2026-09-20T10:00:00Z',
            'lastPractisedAt': '2026-09-22T10:00:00Z',
            'completedAt': '2026-09-22T10:01:00Z',
            'practiceCount': 2,
          },
        },
      }),
    );
    final previous = await store.load();
    expect(previous.forLesson(warmup, course.version)?.practiceCount, 2);
    expect(previous.completedCount(course), 1);
    expect(previous.nextLesson(course)?.id, 'cal-01');
  });
  test('v8h scopes warm-up and fixed-bar sources to their lessons', () {
    final warmup = course.lessons.singleWhere((item) => item.id == 'cal-04');
    final row = course.lessons.singleWhere((item) => item.id == 'cal-24');
    const warmupSources = <String>{
      'ace_wrist_shoulder_options',
      'nhs_seated_leg_march',
    };
    const fixedBarSources = <String>{
      'tjc_fixed_bar_row',
      'barbend_fixed_bar_row',
    };
    expect(course.version, '1.0.0');
    expect(warmup.sourceIds.toSet(), containsAll(warmupSources));
    expect(row.sourceIds.toSet(), containsAll(fixedBarSources));
    expect(
      row.sourceIds.toSet(),
      containsAll(<String>{'ace_trx_angle', 'trx_low_row'}),
    );
    expect(
      course.lessons.where(
        (lesson) =>
            lesson.id != 'cal-04' &&
            lesson.sourceIds.any(warmupSources.contains),
      ),
      isEmpty,
    );
    expect(
      course.lessons.where(
        (lesson) =>
            lesson.id != 'cal-24' &&
            lesson.sourceIds.any(fixedBarSources.contains),
      ),
      isEmpty,
    );
    final sourcesById = <String, CalisthenicsSource>{
      for (final source in course.sources) source.id: source,
    };
    expect(sourcesById['tjc_fixed_bar_row']!.title, contains('Fixed-bar'));
    expect(sourcesById['barbend_fixed_bar_row']!.title, contains('Fixed-bar'));
    expect(
      sourcesById['nhs_seated_leg_march']!.url,
      contains('kingstonandrichmond.nhs.uk'),
    );
  });
  test('v8i keeps five teaching citations on their exact variants', () {
    const sourceByLesson = <String, String>{
      'cal-14': 'psv_level_ground_calf_raise',
      'cal-21': 'mckenzie_standing_bar_dip_proposal',
      'cal-26': 'henderson_supported_scapular_pull',
      'cal-30': 'torbay_nhs_heel_slide',
      'cal-39': 'cleveland_step_supported_burpee',
    };
    final sourcesById = <String, CalisthenicsSource>{
      for (final source in course.sources) source.id: source,
    };
    final attribution =
        jsonDecode(
              File(
                'tool/calisthenics_source_attribution.v1.json',
              ).readAsStringSync(),
            )
            as Map;
    final claims = attribution['sources'] as Map;
    expect(course.version, '1.0.0');
    expect(course.lessons, hasLength(56));
    expect(claims.keys.toSet(), sourceByLesson.values.toSet());
    expect(attribution['generatedMediaCount'], 0);
    expect(attribution['acceptedExpertLabelCount'], 0);
    expect(attribution['qualifiedModelCount'], 0);
    for (final lesson in course.lessons) {
      final expected = sourceByLesson[lesson.id];
      final bound = lesson.sourceIds.where(
        sourceByLesson.values.toSet().contains,
      );
      expect(
        bound,
        expected == null ? isEmpty : contains(expected),
        reason: lesson.id,
      );
      if (expected != null) {
        expect(bound, hasLength(1), reason: lesson.id);
        final source = sourcesById[expected]!;
        final claim = claims[expected] as Map;
        expect(claim['lessonId'], lesson.id);
        expect(claim['url'], source.url);
        expect(claim['supports']['en'], source.supports!.en);
        expect(claim['doesNotSupport']['tr'], source.doesNotSupport!.tr);
        expect((claim['locator'] as String).isNotEmpty, isTrue);
        expect(claim['modelTrainingRightsVerified'], false);
        expect(claim['automaticFormVerdictSupported'], false);
      }
    }
    expect(
      sourcesById['mckenzie_standing_bar_dip_proposal']!.title,
      contains('not trialled'),
    );
    expect(
      sourcesById['mckenzie_standing_bar_dip_proposal']!.url,
      'https://pmc.ncbi.nlm.nih.gov/articles/PMC9603242/',
    );
    expect(
      sourcesById['torbay_nhs_heel_slide']!.title,
      contains('postpartum leaflet'),
    );
    expect(
      sourcesById['cleveland_step_supported_burpee']!.title,
      contains('transcript'),
    );
    expect(
      course.lessons.singleWhere((l) => l.id == 'cal-28').sourceIds,
      isNot(contains('orange_beach_negative_pull_up')),
    );
  });
  test('v8j articles keep their scope and Harvard is reused for the wall station', () {
    const sourceByLesson = <String, String>{
      'cal-09': 'strongfirst_wall_hinge',
      'cal-15': 'harvard_wall_kneeling_pushups',
      'cal-17': 'harvard_wall_kneeling_pushups',
      'cal-32': 'harvard_forearm_plank_options',
      'cal-40': 'harvard_wall_kneeling_pushups',
    };
    final sourcesById = <String, CalisthenicsSource>{
      for (final source in course.sources) source.id: source,
    };
    final attribution =
        jsonDecode(
              File(
                'tool/calisthenics_source_attribution.v2.json',
              ).readAsStringSync(),
            )
            as Map;
    final claims = attribution['sources'] as Map;
    expect(course.version, '1.0.0');
    expect(course.lessons, hasLength(56));
    expect(claims.keys.toSet(), sourceByLesson.values.toSet());
    expect(attribution['generatedMediaCount'], 0);
    expect(attribution['acceptedExpertLabelCount'], 0);
    expect(attribution['qualifiedModelCount'], 0);
    for (final lesson in course.lessons) {
      final expected = sourceByLesson[lesson.id];
      final bound = lesson.sourceIds.where(
        sourceByLesson.values.toSet().contains,
      );
      expect(
        bound,
        expected == null ? isEmpty : contains(expected),
        reason: lesson.id,
      );
      if (expected != null) {
        expect(bound, hasLength(1), reason: lesson.id);
        final source = sourcesById[expected]!;
        final claim = claims[expected] as Map;
        expect(claim['url'], source.url);
        expect(claim['supports']['en'], source.supports!.en);
        expect(claim['doesNotSupport']['tr'], source.doesNotSupport!.tr);
        expect(claim['modelTrainingRightsVerified'], false);
        expect(claim['automaticFormVerdictSupported'], false);
      }
    }
    expect(
      (claims['harvard_wall_kneeling_pushups'] as Map)['lessonIds'],
      <String>['cal-15', 'cal-17'],
    );
    expect(
      course.lessons.singleWhere((l) => l.id == 'cal-35').sourceIds,
      isNot(contains('ace_supine_hollowing_one_leg')),
    );
  });
  test(
    'validator rejects missing translation, invalid source and prerequisites',
    () {
      for (final change in <void Function(Map<String, dynamic>)>[
        (j) => j['modules'][0]['lessons'][0]['title']['tr'] = '',
        (j) => j['modules'][0]['lessons'][0]['sourceIds'] = ['unbound'],
        (j) => (j['sources'].last as Map).remove('doesNotSupport'),
        (j) => j['sources'].last['supports']['tr'] = '',
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
  test('physical learning completion needs two practice reports', () async {
    final store = calisthenicsProgressStoreFor(support, a);
    final lesson = course.lessons.singleWhere((item) => item.id == 'cal-04');
    expect(lesson.learningOnly, isFalse);
    await store.markPractised(course, lesson);
    await expectLater(
      store.markCompleted(course, lesson, selfChecksConfirmed: true),
      throwsStateError,
    );
    await store.markPractised(course, lesson);
    final progress = await store.markCompleted(
      course,
      lesson,
      selfChecksConfirmed: true,
    );
    final record = progress.forLesson(lesson, course.version)!;
    expect(record.practiceCount, 2);
    expect(record.state, CalisthenicsLessonState.selfReportedComplete);
  });
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
