import 'package:flutter/material.dart';

import 'app_locale.dart';
import 'calisthenics_course_screen.dart';
import 'content_repository.dart';
import 'paywall_policy.dart';
import 'theme.dart';

/// Written curriculum entry, separate from camera movement availability.
class DbkbEntryCard extends StatelessWidget {
  const DbkbEntryCard({required this.content, super.key});
  final ContentRepository content;

  @override
  Widget build(BuildContext context) => GravitaCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          content.dbkbCourse.title.inLanguage(
            Localizations.localeOf(context).toLanguageTag(),
          ),
          style: GravitaType.display(context: context, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          localized(
            context,
            'Written learning and optional unloaded rehearsal. Loaded practice needs separate demonstration and coaching.',
            'Yazılı öğrenme ve isteğe bağlı yüksüz prova. Yüklü uygulama ayrı gösterim ve koçluk gerektirir.',
          ),
          style: GravitaType.body(context: context, size: 13),
        ),
        TextButton(
          key: const Key('dbkb.entry'),
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => CalisthenicsCourseScreen(
                course: content.dbkbCourse,
                preparationCourse: content.calisthenicsCourse,
              ),
            ),
          ),
          child: Text(
            localized(context, 'Open written course', 'Yazılı kursu aç'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content.dbkbHandlingCourse.title.inLanguage(
            Localizations.localeOf(context).toLanguageTag(),
          ),
          style: GravitaType.display(context: context, size: 18),
        ),
        Text(
          localized(
            context,
            'KB handling/hinge and rack-start DB curl/row. Goblet and floor-press transfers are excluded from this handling course; the separate lessons below cover supported-start KB goblet and single-KB floor press. Written learning; initial loaded practice needs equipment-specific demonstration and coaching.',
            'KB kullanım/menteşe ve raf başlangıçlı DB curl/row. Goblet ve yerde press geçişleri bu kullanım kursunun dışındadır; aşağıdaki ayrı dersler destekten başlayan KB goblet ve tek KB yerde press içindir. Yazılı öğrenme; ilk yüklü uygulama ekipmana özgü gösterim ve koçluk ister.',
          ),
          style: GravitaType.body(context: context, size: 13),
        ),
        TextButton(
          key: const Key('dbkb.handling.entry'),
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => CalisthenicsCourseScreen(
                course: content.dbkbHandlingCourse,
                preparationCourse: content.calisthenicsCourse,
              ),
            ),
          ),
          child: Text(
            localized(
              context,
              'Open handling lessons',
              'Kullanım derslerini aç',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content.dbkbTransitionsCourse.title.inLanguage(
            Localizations.localeOf(context).toLanguageTag(),
          ),
          style: GravitaType.display(context: context, size: 18),
        ),
        Text(
          localized(
            context,
            'Supported-start KB goblet and single-KB floor press only. Written learning; initial loaded practice requires equipment-specific demonstration and coaching. Floor-to-chest goblet, two-DB transfer and unsupervised practice remain open.',
            'Yalnız destekten başlayan KB goblet ve tek KB yerde press. Yazılı öğrenme; ilk yüklü uygulama ekipmana özgü gösterim ve koçluk ister. Yerden göğse goblet, iki DB geçişi ve gözetimsiz uygulama açık kalır.',
          ),
          style: GravitaType.body(context: context, size: 13),
        ),
        TextButton(
          key: const Key('dbkb.transitions.entry'),
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => CalisthenicsCourseScreen(
                course: content.dbkbTransitionsCourse,
                preparationCourse: content.calisthenicsCourse,
              ),
            ),
          ),
          child: Text(
            localized(
              context,
              'Open specified transition lessons',
              'Belirtilen geçiş derslerini aç',
            ),
          ),
        ),
        TextButton(
          key: const Key('dbkb.handling.preparation'),
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => CalisthenicsCourseScreen(
                course: content.dbkbCourse,
                preparationCourse: content.calisthenicsCourse,
              ),
            ),
          ),
          child: Text(
            localized(
              context,
              'Review equipment preparation first',
              'Önce ekipman hazırlığını gözden geçir',
            ),
          ),
        ),
        Text(
          localized(
            context,
            'Reuse your existing preparation:',
            'Mevcut hazırlığını tekrar kullan:',
          ),
          style: GravitaType.body(context: context, size: 13),
        ),
        for (final id in <String>['cal-03', 'cal-04', 'cal-08', 'cal-09'])
          TextButton(
            key: Key('dbkb.preparation.$id'),
            onPressed: () async {
              final course = content.calisthenicsCourse;
              final lesson = course.lessons.singleWhere((l) => l.id == id);
              if (!await ensureLessonAccess(context, course, lesson)) return;
              if (!context.mounted) return;
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      CalisthenicsLessonScreen(course: course, lesson: lesson),
                ),
              );
            },
            child: Text(
              content.calisthenicsCourse.lessons
                  .singleWhere((l) => l.id == id)
                  .title
                  .inLanguage(Localizations.localeOf(context).toLanguageTag()),
            ),
          ),
      ],
    ),
  );
}
