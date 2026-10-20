import 'dart:convert';
import 'localization/locale_catalog.dart';

final class CourseText {
  const CourseText(this.en, this.tr);
  factory CourseText.parse(dynamic value) {
    if (value is! Map ||
        value['en'] is! String ||
        value['tr'] is! String ||
        (value['en'] as String).trim().isEmpty ||
        (value['tr'] as String).trim().isEmpty) {
      throw const FormatException('Course requires non-empty EN/TR text');
    }
    return CourseText(value['en'] as String, value['tr'] as String);
  }
  final String en;
  final String tr;
  String inLanguage(String language) =>
      resolveLocalized(language, en, turkish: tr);
}

final class CalisthenicsSource {
  CalisthenicsSource(Map<String, dynamic> json)
    : id = json['id'] as String,
      title = json['title'] as String,
      url = json['url'] as String,
      supports = json['supports'] == null
          ? null
          : CourseText.parse(json['supports']),
      doesNotSupport = json['doesNotSupport'] == null
          ? null
          : CourseText.parse(json['doesNotSupport']) {
    if (id.isEmpty ||
        title.isEmpty ||
        Uri.tryParse(url)?.scheme != 'https' ||
        (supports == null) != (doesNotSupport == null)) {
      throw const FormatException('Invalid course source');
    }
  }
  final String id;
  final String title;
  final String url;
  final CourseText? supports, doesNotSupport;
}

const foundationCourseIds = <String>{
  'barbell-foundations',
  'rings-foundations',
  'hand-support-foundations',
};

final class CalisthenicsLesson {
  CalisthenicsLesson(Map<String, dynamic> json)
    : progression = json['progression'] == null
          ? null
          : CourseText.parse(json['progression']),
      regression = json['regression'] == null
          ? null
          : CourseText.parse(json['regression']),
      rest = json['rest'] == null ? null : CourseText.parse(json['rest']),
      movementTaskId = json['movementTaskId'] as String?,
      candidatePracticeAccess = json['candidatePracticeAccess'] as String?,
      id = json['id'] as String,
      title = CourseText.parse(json['title']),
      objective = CourseText.parse(json['objective']),
      steps = (json['steps'] as List)
          .map(CourseText.parse)
          .toList(growable: false),
      practice = CourseText.parse(json['practice']),
      selfCheck = (json['selfCheck'] as List)
          .map(CourseText.parse)
          .toList(growable: false),
      adaptation = CourseText.parse(json['adaptation']),
      stop = CourseText.parse(json['stop']),
      sourceIds = (json['sourceIds'] as List).cast<String>(),
      prerequisites = (json['prerequisites'] as List).cast<String>(),
      minutes = json['minutes'] as int,
      practiceType = json['practiceType'] as String,
      mediaBrief = CourseText.parse(json['mediaBrief']),
      recall = json['recall'] == null ? null : CourseText.parse(json['recall']),
      correction = json['correction'] == null
          ? null
          : CourseText.parse(json['correction']),
      answer = json['answer'] == null
          ? null
          : CourseText.parse(json['answer']) {
    if (id.isEmpty ||
        (id.startsWith('dbkbh-')
            ? steps.length < 3
            : id.startsWith('barbell-') ||
                  id.startsWith('rings-') ||
                  id.startsWith('hands-')
            ? steps.length < 3 || steps.length > 5
            : steps.length != 3) ||
        selfCheck.length < 2 ||
        minutes <= 0 ||
        sourceIds.isEmpty ||
        json['evidenceMode'] != 'self_report' ||
        ((recall == null) != (correction == null)) ||
        ((recall == null) != (answer == null)) ||
        !<String>['physical', 'learning_only'].contains(practiceType)) {
      throw FormatException('Invalid lesson $id');
    }
  }
  final CourseText? progression, regression, rest;
  final String? movementTaskId;
  final String? candidatePracticeAccess;
  final String id;
  final CourseText title, objective, practice, adaptation, stop, mediaBrief;
  final CourseText? recall, correction, answer;
  final List<CourseText> steps, selfCheck;
  final List<String> sourceIds, prerequisites;
  final int minutes;
  final String practiceType;
  bool get learningOnly => practiceType == 'learning_only';
}

final class CalisthenicsModule {
  CalisthenicsModule(Map<String, dynamic> json)
    : id = json['id'] as String,
      title = CourseText.parse(json['title']),
      lessons = (json['lessons'] as List)
          .map(
            (dynamic item) =>
                CalisthenicsLesson((item as Map).cast<String, dynamic>()),
          )
          .toList(growable: false);
  final String id;
  final CourseText title;
  final List<CalisthenicsLesson> lessons;
}

enum MovementGuideKind { practice, preparation, readingOnly }

final class MovementLearningGuide {
  MovementLearningGuide(Map<String, dynamic> json)
    : movementId = json['movementId'] as String,
      kind = MovementGuideKind.values.byName(json['kind'] as String),
      lessonIds = (json['lessonIds'] as List).cast<String>() {
    if (movementId.isEmpty ||
        lessonIds.isEmpty ||
        lessonIds.toSet().length != lessonIds.length) {
      throw const FormatException('Invalid movement learning guide');
    }
  }
  final String movementId;
  final MovementGuideKind kind;
  final List<String> lessonIds;
}

final class CalisthenicsCourse {
  CalisthenicsCourse._(Map<String, dynamic> json)
    : isFoundationCourse = foundationCourseIds.contains(json['id']),
      reviewRequired =
          foundationCourseIds.contains(json['id']) &&
          json['reviewStatus'] == 'expert_review_required',
      scope = json['scope'] == null ? null : CourseText.parse(json['scope']),
      equipment = json['equipment'] == null
          ? null
          : CourseText.parse(json['equipment']),
      entryCriteria = json['entryCriteria'] == null
          ? null
          : CourseText.parse(json['entryCriteria']),
      exitCriteria = json['exitCriteria'] == null
          ? null
          : CourseText.parse(json['exitCriteria']),
      id = json['id'] as String,
      version = json['version'] as String,
      title = CourseText.parse(json['title']),
      description = CourseText.parse(json['description']),
      healthNotice = CourseText.parse(json['healthNotice']),
      sources = (json['sources'] as List)
          .map(
            (dynamic item) =>
                CalisthenicsSource((item as Map).cast<String, dynamic>()),
          )
          .toList(growable: false),
      modules = (json['modules'] as List)
          .map(
            (dynamic item) =>
                CalisthenicsModule((item as Map).cast<String, dynamic>()),
          )
          .toList(growable: false),
      catalogueGuides = (json['catalogueGuides'] as List)
          .map(
            (dynamic item) =>
                MovementLearningGuide((item as Map).cast<String, dynamic>()),
          )
          .toList(growable: false) {
    if (json['schemaVersion'] != 1 ||
        !(<String>{
          'calisthenics-foundations',
          'dbkb-written-foundations',
          'dbkb-controlled-handling',
          'dbkb-supported-transitions',
          ...foundationCourseIds,
        }).contains(id) ||
        (version != '1.0.0' && !(isFoundationCourse && version == '1.1.0')) ||
        json['evidenceMode'] != 'self_report' ||
        (isFoundationCourse
            ? modules.length != 3 || lessons.length != 12
            : id == 'calisthenics-foundations'
            ? modules.length != 10 || lessons.length != 56
            : id == 'dbkb-written-foundations'
            ? modules.length != 4 || lessons.length != 12
            : id == 'dbkb-controlled-handling'
            ? modules.length != 1 || lessons.length != 11
            : modules.length != 1 || lessons.length != 2)) {
      throw const FormatException('Unsupported calisthenics course');
    }
    if (isFoundationCourse) {
      final prefix = switch (id) {
        'barbell-foundations' => 'barbell',
        'rings-foundations' => 'rings',
        _ => 'hands',
      };
      if ((version == '1.0.0'
              ? json['reviewStatus'] != 'expert_review_required'
              : json['reviewStatus'] != 'first_release_draft') ||
          (version == '1.1.0' &&
              lessons.any(
                (lesson) =>
                    lesson.candidatePracticeAccess == null ||
                    !(<String>{
                      'learning_only',
                      'available_supported_beginner',
                      'available_unloaded_beginner',
                    }).contains(lesson.candidatePracticeAccess) ||
                    lesson.learningOnly !=
                        (lesson.candidatePracticeAccess == 'learning_only'),
              )) ||
          scope == null ||
          equipment == null ||
          entryCriteria == null ||
          exitCriteria == null ||
          catalogueGuides.isNotEmpty ||
          lessons.asMap().entries.any(
            (entry) =>
                entry.value.id !=
                    '$prefix-${(entry.key + 1).toString().padLeft(2, '0')}' ||
                entry.value.movementTaskId != 'gravita:${entry.value.id}' ||
                entry.value.progression == null ||
                entry.value.regression == null ||
                entry.value.rest == null ||
                entry.value.learningOnly != !(entry.key >= 2 && entry.key < 10),
          )) {
        throw const FormatException('Invalid draft foundation boundary');
      }
    }
    final Set<String> sourceKeys = sources.map((s) => s.id).toSet();
    final Set<String> moduleKeys = modules.map((m) => m.id).toSet();
    if (sourceKeys.length != sources.length ||
        moduleKeys.length != modules.length ||
        modules.any((m) => m.id.isEmpty || m.lessons.isEmpty)) {
      throw const FormatException('Duplicate or empty course groups');
    }
    String? previous;
    final Set<String> seen = <String>{};
    for (final lesson in lessons) {
      if (!seen.add(lesson.id) ||
          lesson.sourceIds.any((id) => !sourceKeys.contains(id)) ||
          (previous == null
              ? lesson.prerequisites.isNotEmpty
              : lesson.prerequisites.length != 1 ||
                    lesson.prerequisites.single != previous)) {
        throw FormatException('Invalid binding or prerequisite: ${lesson.id}');
      }
      previous = lesson.id;
    }
    if (id == 'dbkb-written-foundations' &&
        (catalogueGuides.isNotEmpty ||
            lessons.any(
              (lesson) =>
                  !lesson.id.startsWith('dbkb-') ||
                  lesson.recall == null ||
                  lesson.correction == null ||
                  lesson.answer == null,
            ) ||
            lessons
                    .where((lesson) => !lesson.learningOnly)
                    .map((lesson) => lesson.id)
                    .join(',') !=
                'dbkb-04,dbkb-05,dbkb-08,dbkb-10,dbkb-11')) {
      throw const FormatException('Invalid DB/KB written course boundary');
    }
    if (id == 'dbkb-controlled-handling' &&
        (catalogueGuides.isNotEmpty ||
            lessons.map((l) => l.id).join(',') !=
                'dbkbh-scope,dbkbh-a,dbkbh-bkb,dbkbh-bdb,dbkbh-c,dbkbh-d,dbkbh-e,dbkbh-f,dbkbh-g,dbkbh-h,dbkbh-i' ||
            lessons.any(
              (l) =>
                  !l.learningOnly ||
                  l.recall == null ||
                  l.correction == null ||
                  l.answer == null,
            ))) {
      throw const FormatException('Invalid DB/KB handling learning boundary');
    }
    if (id == 'dbkb-supported-transitions' &&
        (catalogueGuides.isNotEmpty ||
            lessons.map((l) => l.id).join(',') !=
                'dbkbt-supported-goblet,dbkbt-single-kb-floor-press' ||
            lessons.any(
              (l) =>
                  !l.learningOnly ||
                  l.recall == null ||
                  l.correction == null ||
                  l.answer == null,
            ))) {
      throw const FormatException(
        'Invalid DB/KB transitions learning boundary',
      );
    }
    if (id == 'calisthenics-foundations' &&
        modules
            .singleWhere((m) => m.id == 'literacy')
            .lessons
            .any((l) => !l.learningOnly)) {
      throw const FormatException(
        'Advanced skill literacy must not require physical practice',
      );
    }
    final guidedIds = <String>{};
    for (final guide in catalogueGuides) {
      if (!guidedIds.add(guide.movementId) ||
          guide.lessonIds.any((id) => !seen.contains(id)) ||
          guide.lessonIds.any(
            (id) =>
                lessons.singleWhere((lesson) => lesson.id == id).learningOnly !=
                (guide.kind == MovementGuideKind.readingOnly),
          )) {
        throw FormatException('Invalid teaching link: ${guide.movementId}');
      }
    }
  }
  factory CalisthenicsCourse.parse(String text) =>
      CalisthenicsCourse._((jsonDecode(text) as Map).cast<String, dynamic>());
  final bool isFoundationCourse, reviewRequired;
  final CourseText? scope, equipment, entryCriteria, exitCriteria;
  bool practiceHeld(CalisthenicsLesson lesson) =>
      reviewRequired &&
      !lessons.singleWhere((item) => item.id == lesson.id).learningOnly;
  final String id, version;
  final CourseText title, description, healthNotice;
  final List<CalisthenicsSource> sources;
  final List<CalisthenicsModule> modules;
  final List<MovementLearningGuide> catalogueGuides;
  MovementLearningGuide? guideFor(String movementId) {
    for (final guide in catalogueGuides) {
      if (guide.movementId == movementId) return guide;
    }
    return null;
  }

  List<CalisthenicsLesson> get lessons =>
      modules.expand((m) => m.lessons).toList(growable: false);
}
