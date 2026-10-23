import 'package:flutter/material.dart';

import 'account_connection.dart';
import 'app_locale.dart';
import 'calisthenics_course.dart';

/// Shared Motion paywall "A" (user decision, 23 Oct 2026), Gravita side.
///
/// Each course opens its module-aligned first third for free: whole modules
/// from the start until at least ceil(n/3) lessons are covered, or the first
/// ceil(n/3) lessons of a single-module course. The other lessons and the
/// independent practice stage (creating the eight-week program and logging
/// new sessions in it) are included with a Gravita or Motion+ subscription.
/// Progress records, saved programs and history always stay readable.
///
/// Sales are separate from the camera gate: `motionPaidFeaturesAvailable`
/// keeps live camera sessions closed. While sales are unavailable nothing is
/// locked, because a lock without a way to subscribe would strand people.
const bool gravitaSubscriptionSalesAvailable = true;

/// Number of free lessons at the start of [course] under paywall "A".
int freeLessonCount(CalisthenicsCourse course) {
  final int total = course.lessons.length;
  final int third = (total + 2) ~/ 3;
  if (course.modules.length <= 1) return third;
  var covered = 0;
  for (final module in course.modules) {
    if (covered >= third) break;
    covered += module.lessons.length;
  }
  return covered;
}

/// Whether [lesson] of [course] is in the free part. Lessons outside the
/// course are treated as paid (fail-closed).
bool isFreeLesson(CalisthenicsCourse course, CalisthenicsLesson lesson) {
  final int index = course.lessons.indexWhere((l) => l.id == lesson.id);
  return index >= 0 && index < freeLessonCount(course);
}

/// Whether [lesson] shows the subscription lock in course lists.
bool isLockedLesson(CalisthenicsCourse course, CalisthenicsLesson lesson) =>
    gravitaSubscriptionSalesAvailable && !isFreeLesson(course, lesson);

/// Checks subscription access at the moment paid content or practice starts.
/// Free content and a closed sale never ask. Without an account connection
/// the paid part stays closed.
Future<bool> ensureSubscriptionAccess(BuildContext context) async {
  if (!gravitaSubscriptionSalesAvailable) return true;
  final guard = AccountScope.maybeOf(context)?.connection?.requirePaidAccess;
  if (guard == null) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          localized(
            context,
            PaywallStrings.unavailable,
            'Abonelik erişimi şu anda kullanılamıyor. Ücretsiz dersler açık kalır.',
          ),
        ),
      ),
    );
    return false;
  }
  return guard(context);
}

/// Lesson entry point: free lessons open directly.
Future<bool> ensureLessonAccess(
  BuildContext context,
  CalisthenicsCourse course,
  CalisthenicsLesson lesson,
) async {
  if (!isLockedLesson(course, lesson)) return true;
  return ensureSubscriptionAccess(context);
}

/// Canonical English sources (catalogued in all 14 locales).
abstract final class PaywallStrings {
  static const String lockedLesson = 'Included with subscription';
  static const String coursePreview =
      'Free preview: {count} of {total} lessons. The rest are included with a '
      'Gravita or Motion+ subscription; your progress always stays readable.';
  static const String practiceNote =
      'Creating a program and logging new sessions are included with a '
      'subscription. Your saved program and history stay readable.';
  static const String unavailable =
      'Subscription access is not available right now. Free lessons stay open.';
}
