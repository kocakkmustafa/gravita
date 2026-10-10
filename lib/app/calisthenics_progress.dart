import 'dart:convert';
import 'dart:io';

import 'account_data_directory.dart';
import 'course_progress_io.dart';
import 'account_store_epoch.dart';
import 'calisthenics_course.dart';

enum CalisthenicsLessonState { seen, practised, selfReportedComplete }

final class CalisthenicsLessonProgress {
  const CalisthenicsLessonProgress({
    required this.contentVersion,
    required this.state,
    required this.seenAt,
    this.lastPractisedAt,
    this.completedAt,
    this.practiceCount = 0,
  });

  factory CalisthenicsLessonProgress.fromJson(Map<String, dynamic> json) {
    final String stateName = json['state'] as String;
    final CalisthenicsLessonState state = CalisthenicsLessonState.values
        .singleWhere(
          (CalisthenicsLessonState candidate) => candidate.name == stateName,
          orElse: () =>
              throw FormatException('Unknown lesson state $stateName'),
        );
    return CalisthenicsLessonProgress(
      contentVersion: json['contentVersion'] as String,
      state: state,
      seenAt: DateTime.parse(json['seenAt'] as String).toUtc(),
      lastPractisedAt: json['lastPractisedAt'] == null
          ? null
          : DateTime.parse(json['lastPractisedAt'] as String).toUtc(),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String).toUtc(),
      practiceCount: json['practiceCount'] as int,
    );
  }

  final String contentVersion;
  final CalisthenicsLessonState state;
  final DateTime seenAt;
  final DateTime? lastPractisedAt;
  final DateTime? completedAt;
  final int practiceCount;

  Map<String, Object?> toJson() => <String, Object?>{
    'contentVersion': contentVersion,
    'state': state.name,
    'seenAt': seenAt.toIso8601String(),
    'lastPractisedAt': lastPractisedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'practiceCount': practiceCount,
  };
}

final class CalisthenicsProgress {
  const CalisthenicsProgress(this.records);

  final Map<String, CalisthenicsLessonProgress> records;

  CalisthenicsLessonProgress? forLesson(
    CalisthenicsLesson lesson,
    String contentVersion,
  ) {
    final CalisthenicsLessonProgress? record = records[lesson.id];
    return record?.contentVersion == contentVersion ? record : null;
  }

  int completedCount(CalisthenicsCourse course) => course.lessons
      .where(
        (CalisthenicsLesson lesson) =>
            forLesson(lesson, course.version)?.state ==
            CalisthenicsLessonState.selfReportedComplete,
      )
      .length;

  CalisthenicsLesson? nextLesson(CalisthenicsCourse course) {
    for (final CalisthenicsLesson lesson in course.lessons) {
      if (forLesson(lesson, course.version)?.state !=
          CalisthenicsLessonState.selfReportedComplete) {
        return lesson;
      }
    }
    return null;
  }
}

/// Local, account-scoped self-report journal. It never imports session counts
/// or promotes a camera observation into course completion.
final class CalisthenicsProgressStore {
  CalisthenicsProgressStore(this.file, {
    AccountStoreEpoch? epoch,
    this.courseId = 'calisthenics-foundations',
  })
    : _lease = CourseProgressLease(file, epoch: epoch);

  final File file;
  final String courseId;
  final CourseProgressLease _lease;

  Future<CalisthenicsProgress> load() => _lease.mutate(_loadUnlocked);

  Future<CalisthenicsProgress> _loadUnlocked() async {
    _lease.checkCurrent();
    final exists = await file.exists();
    _lease.checkCurrent();
    if (!exists) {
      return const CalisthenicsProgress({});
    }
    final contents = await file.readAsString();
    _lease.checkCurrent();
    final Map<String, dynamic> root = (jsonDecode(contents) as Map)
        .cast<String, dynamic>();
    if (root['schemaVersion'] != 1 ||
        root['courseId'] != courseId) {
      throw const FormatException('Unsupported calisthenics progress file');
    }
    final Map<String, dynamic> values = (root['lessons'] as Map)
        .cast<String, dynamic>();
    final Map<String, CalisthenicsLessonProgress> records =
        <String, CalisthenicsLessonProgress>{};
    for (final MapEntry<String, dynamic> entry in values.entries) {
      final CalisthenicsLessonProgress progress =
          CalisthenicsLessonProgress.fromJson(
            (entry.value as Map).cast<String, dynamic>(),
          );
      if (progress.practiceCount < 0 ||
          (progress.state != CalisthenicsLessonState.seen &&
              (progress.practiceCount == 0 ||
                  progress.lastPractisedAt == null)) ||
          (progress.state == CalisthenicsLessonState.selfReportedComplete &&
              progress.completedAt == null)) {
        throw FormatException('Invalid progress for ${entry.key}');
      }
      records[entry.key] = progress;
    }
    _lease.checkCurrent();
    return CalisthenicsProgress(
      Map<String, CalisthenicsLessonProgress>.unmodifiable(records),
    );
  }

  Future<CalisthenicsProgress> markSeen(
    CalisthenicsCourse course,
    CalisthenicsLesson lesson,
  ) => _update(course, lesson, CalisthenicsLessonState.seen);

  Future<CalisthenicsProgress> markPractised(
    CalisthenicsCourse course,
    CalisthenicsLesson lesson,
  ) => _update(course, lesson, CalisthenicsLessonState.practised);

  Future<CalisthenicsProgress> markCompleted(
    CalisthenicsCourse course,
    CalisthenicsLesson lesson, {
    required bool selfChecksConfirmed,
  }) {
    if (!selfChecksConfirmed) {
      throw StateError('Self-check must be confirmed before completion');
    }
    return _update(
      course,
      lesson,
      CalisthenicsLessonState.selfReportedComplete,
    );
  }

  Future<CalisthenicsProgress> _update(
    CalisthenicsCourse course,
    CalisthenicsLesson lesson,
    CalisthenicsLessonState requested,
  ) => _lease.mutate(() => _updateUnlocked(course, lesson, requested));

  Future<CalisthenicsProgress> _updateUnlocked(
    CalisthenicsCourse course,
    CalisthenicsLesson lesson,
    CalisthenicsLessonState requested,
  ) async {
    if (course.id != courseId ||
        !course.lessons.any(
          (CalisthenicsLesson item) => item.id == lesson.id,
        )) {
      throw ArgumentError.value(lesson.id, 'lesson', 'Not in this course');
    }
    final CalisthenicsProgress current = await _loadUnlocked();
    final CalisthenicsLessonProgress? old = current.forLesson(
      lesson,
      course.version,
    );
    if (requested == CalisthenicsLessonState.selfReportedComplete &&
        (old == null ||
            old.state.index < CalisthenicsLessonState.practised.index)) {
      throw StateError('Practice must be self-reported before completion');
    }
    if (requested == CalisthenicsLessonState.selfReportedComplete &&
        !lesson.learningOnly &&
        (old?.practiceCount ?? 0) < 2) {
      throw StateError(
        'Two practice reports are required for a physical lesson',
      );
    }
    final DateTime now = DateTime.now().toUtc();
    final CalisthenicsLessonState nextState =
        old != null && old.state.index > requested.index
        ? old.state
        : requested;
    final int practiceCount =
        (old?.practiceCount ?? 0) +
        (requested == CalisthenicsLessonState.practised ? 1 : 0);
    final CalisthenicsLessonProgress next = CalisthenicsLessonProgress(
      contentVersion: course.version,
      state: nextState,
      seenAt: old?.seenAt ?? now,
      lastPractisedAt: requested == CalisthenicsLessonState.practised
          ? now
          : old?.lastPractisedAt,
      completedAt: requested == CalisthenicsLessonState.selfReportedComplete
          ? old?.completedAt ?? now
          : old?.completedAt,
      practiceCount: practiceCount,
    );
    final Map<String, CalisthenicsLessonProgress> records =
        Map<String, CalisthenicsLessonProgress>.from(current.records);
    records[lesson.id] = next;
    await file.parent.create(recursive: true);
    final File temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode(<String, Object>{
        'schemaVersion': 1,
        'courseId': course.id,
        'lessons': <String, Object?>{
          for (final MapEntry<String, CalisthenicsLessonProgress> entry
              in records.entries)
            entry.key: entry.value.toJson(),
        },
      }),
      flush: true,
    );
    _lease.checkCurrent();
    await temp.rename(file.path);
    _lease.checkCurrent();
    return CalisthenicsProgress(
      Map<String, CalisthenicsLessonProgress>.unmodifiable(records),
    );
  }
}

CalisthenicsProgressStore calisthenicsProgressStoreFor(
  Directory support,
  String? accountUserId, {
  AccountStoreEpoch? epoch,
  String courseId = 'calisthenics-foundations',
}) {
  if (!<String>['calisthenics-foundations', 'dbkb-written-foundations', 'dbkb-controlled-handling', 'dbkb-supported-transitions'].contains(courseId)) {
    throw ArgumentError.value(courseId, 'courseId');
  }
  final name = courseId == 'calisthenics-foundations'
      ? 'calisthenics-course-progress.v1.json'
      : courseId == 'dbkb-written-foundations'
          ? 'dbkb-written-course-progress.v1.json'
          : courseId == 'dbkb-controlled-handling'
              ? 'dbkb-handling-course-progress.v1.json'
              : 'dbkb-transitions-course-progress.v1.json';
  return CalisthenicsProgressStore(
    File('${accountDataDirectory(support, accountUserId).path}/$name'),
    epoch: epoch,
    courseId: courseId,
  );
}
