import 'dart:convert';

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
  String inLanguage(String language) => language == 'tr' ? tr : en;
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

final class CalisthenicsLesson {
  CalisthenicsLesson(Map<String, dynamic> json)
    : id = json['id'] as String,
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
      mediaBrief = CourseText.parse(json['mediaBrief']) {
    if (id.isEmpty ||
        steps.length != 3 ||
        selfCheck.length < 2 ||
        minutes <= 0 ||
        sourceIds.isEmpty ||
        json['evidenceMode'] != 'self_report' ||
        !<String>['physical', 'learning_only'].contains(practiceType)) {
      throw FormatException('Invalid lesson $id');
    }
  }
  final String id;
  final CourseText title, objective, practice, adaptation, stop, mediaBrief;
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
    : id = json['id'] as String,
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
        id != 'calisthenics-foundations' ||
        version != '1.0.0' ||
        json['evidenceMode'] != 'self_report' ||
        modules.length != 10 ||
        lessons.length != 56) {
      throw const FormatException('Unsupported calisthenics course');
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
    if (modules
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
