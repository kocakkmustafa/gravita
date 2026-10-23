import 'package:flutter/material.dart';

import 'app_locale.dart';
import 'calisthenics_course.dart';
import 'calisthenics_course_screen.dart';
import 'content_repository.dart';
import 'paywall_policy.dart';

import 'study_review_content.dart';

String _text(BuildContext context, String en, String tr) =>
    localized(context, en, tr);

/// Written recall only. Responses never enter a course, sensor or account store.
class StudyReviewEntry extends StatelessWidget {
  const StudyReviewEntry({this.content, super.key});
  final ContentRepository? content;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: OutlinedButton.icon(
      key: const Key('study-review-entry'),
      icon: const Icon(Icons.menu_book_outlined),
      label: Text(
        _text(
          context,
          'Written recall and review',
          'Yazılı hatırlama ve değerlendirme',
        ),
      ),
      onPressed: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => StudyReviewPage(content: content),
        ),
      ),
    ),
  );
}

class StudyReviewPage extends StatelessWidget {
  const StudyReviewPage({this.content, super.key});
  final ContentRepository? content;

  /// Only existing reading-only lessons. A future physical lesson with a
  /// reused ID must not silently inherit an advanced-skill shortcut.
  List<CalisthenicsLesson> _relatedReading(String areaId) {
    final ids = switch (areaId) {
      'rings' => const ['cal-22', 'cal-48', 'cal-49'],
      'hands' => const ['cal-46', 'cal-47'],
      _ => const <String>[],
    };
    return content?.calisthenicsCourse.lessons
            .where((lesson) => ids.contains(lesson.id) && lesson.learningOnly)
            .toList(growable: false) ??
        const [];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_text(context, 'Written recall', 'Yazılı hatırlama')),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Text(
          _text(
            context,
            'Study the idea, explain it in your own words, then compare. No movement or equipment is needed. These reading activities do not complete a full course or approve physical technique.',
            'Fikri çalış, kendi sözlerinle açıkla, sonra karşılaştır. Hareket veya ekipman gerekmez. Bu okuma çalışmaları tam bir kursu bitirmez ve fiziksel tekniği onaylamaz.',
          ),
        ),
        for (final StudyArea area in studyAreas)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  area.title.inContext(context),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(area.boundary.inContext(context)),
                if (content?.courseForArea(area.id) != null)
                  TextButton.icon(
                    key: Key('study-course-${area.id}'),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: Text(
                      _text(
                        context,
                        'Open existing written course',
                        'Mevcut yazılı kursu aç',
                      ),
                    ),
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => CalisthenicsCourseScreen(
                          course: content!.courseForArea(area.id)!,
                          modelManifest: content!.observationManifest,
                          preparationCourse: content!.calisthenicsCourse,
                        ),
                      ),
                    ),
                  ),
                for (final RecallLesson lesson in area.lessons)
                  ListTile(
                    key: Key('study-lesson-${lesson.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(lesson.title.inContext(context)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            RecallLessonPage(area: area, lesson: lesson),
                      ),
                    ),
                  ),
                if (_relatedReading(area.id).isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    _text(
                      context,
                      'Related existing reading lessons. These do not form a full practical course. Opening a lesson uses that course’s separate progress record.',
                      'İlgili mevcut okuma dersleri. Bunlar tam uygulamalı kurs oluşturmaz. Dersi açmak, ilgili kursun ayrı ilerleme kaydını kullanır.',
                    ),
                  ),
                  for (final lesson in _relatedReading(area.id))
                    ListTile(
                      key: Key('study-related-${lesson.id}'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.menu_book_outlined),
                      title: Text(
                        lesson.title.inLanguage(
                          Localizations.localeOf(context).toLanguageTag(),
                        ),
                      ),
                      onTap: () async {
                        final course = content!.calisthenicsCourse;
                        if (!await ensureLessonAccess(
                          context,
                          course,
                          lesson,
                        )) {
                          return;
                        }
                        if (!context.mounted) return;
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => CalisthenicsLessonScreen(
                              course: course,
                              lesson: lesson,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
      ],
    ),
  );
}

extension on StudyText {
  String inContext(BuildContext context) =>
      inLanguage(Localizations.localeOf(context).toLanguageTag());
}

enum RecallObservation { notAttempted, uncertain, difference, stopped }

class RecallLessonPage extends StatefulWidget {
  const RecallLessonPage({required this.area, required this.lesson, super.key});
  final StudyArea area;
  final RecallLesson lesson;

  @override
  State<RecallLessonPage> createState() => _RecallLessonPageState();
}

class _RecallLessonPageState extends State<RecallLessonPage> {
  final TextEditingController _answer = TextEditingController();
  final TextEditingController _next = TextEditingController();
  bool _revealed = false;
  RecallObservation? _observation;

  @override
  void dispose() {
    _answer.dispose();
    _next.dispose();
    super.dispose();
  }

  String _label(RecallObservation value) => switch (value) {
    RecallObservation.notAttempted => _text(
      context,
      'Not attempted',
      'Denenmedi',
    ),
    RecallObservation.uncertain => _text(context, 'Uncertain', 'Belirsiz'),
    RecallObservation.difference => _text(
      context,
      'One difference found',
      'Tek fark bulundu',
    ),
    RecallObservation.stopped => _text(context, 'Stopped', 'Durdum'),
  };

  String _feedback(RecallObservation value) => switch (value) {
    RecallObservation.notAttempted => _text(
      context,
      'Leave this unattempted. Read the example before another written recall; elapsed time does not establish learning.',
      'Denenmedi olarak bırak. Yeni yazılı hatırlamadan önce örneği oku; geçen süre öğrenmeyi kanıtlamaz.',
    ),
    RecallObservation.uncertain => _text(
      context,
      'Keep the uncertainty visible. Name the term or transition you cannot explain; reread that part or prepare a question for a suitable teacher. Do not turn an unknown into a technique correction.',
      'Belirsizliği görünür tut. Açıklayamadığın terimi veya geçişi adlandır; o kısmı yeniden oku ya da uygun eğitmene soru hazırla. Bilinmeyeni teknik düzeltmeye dönüştürme.',
    ),
    RecallObservation.difference => _text(
      context,
      'Name one difference between your written answer and the reference. Revise just that point, hide the reference and explain it again in the same example. This compares written answers, not physical ability.',
      'Yazılı cevabınla kaynak arasında tek farkı adlandır. Yalnız o noktayı düzelt, kaynağı gizle ve aynı örneği yeniden açıkla. Bu, yazılı cevapları karşılaştırır; fiziksel beceriyi ölçmez.',
    ),
    RecallObservation.stopped => _text(
      context,
      'End this activity. Do not retry a movement or equipment task to produce a better record. If discomfort or an unsafe setup caused the stop, a written answer cannot resolve it; appropriate human guidance remains necessary.',
      'Bu çalışmayı bitir. Daha iyi kayıt üretmek için hareketi veya ekipman görevini tekrarlama. Durma nedeni rahatsızlık ya da güvensiz kurulumsa yazılı cevap bunu çözmez; uygun insan rehberliği gerekir.',
    ),
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.lesson.title.inContext(context))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Text(
          widget.area.boundary.inContext(context),
          key: const Key('study-boundary'),
        ),
        const SizedBox(height: 16),
        Text(widget.lesson.teaching.inContext(context)),
        const SizedBox(height: 16),
        Text(widget.lesson.question.inContext(context)),
        const SizedBox(height: 8),
        TextField(
          key: const Key('study-answer'),
          controller: _answer,
          minLines: 2,
          maxLines: 5,
          maxLength: 1000,
          decoration: InputDecoration(
            labelText: _text(context, 'Your written answer', 'Yazılı cevabın'),
          ),
        ),
        Text(
          _text(
            context,
            'Optional notes stay on this page and are discarded when you leave. No recording, score, progress update or mastery approval is created.',
            'İsteğe bağlı notlar bu sayfada kalır ve çıkınca silinir. Kayıt, puan, ilerleme güncellemesi veya ustalık onayı oluşturulmaz.',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('study-reference-toggle'),
          onPressed: () => setState(() => _revealed = !_revealed),
          child: Text(
            _text(
              context,
              _revealed ? 'Hide reference' : 'Compare with reference',
              _revealed ? 'Kaynağı gizle' : 'Kaynakla karşılaştır',
            ),
          ),
        ),
        if (_revealed) ...<Widget>[
          Text(
            widget.lesson.answer.inContext(context),
            key: const Key('study-reference'),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        Text(_text(context, 'What can you report?', 'Neyi bildirebilirsin?')),
        for (final RecallObservation value in RecallObservation.values)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              key: Key('study-state-${value.name}'),
              onPressed: () => setState(() => _observation = value),
              child: Row(
                children: <Widget>[
                  Icon(
                    _observation == value
                        ? Icons.check_circle_outline
                        : Icons.circle_outlined,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_label(value))),
                ],
              ),
            ),
          ),
        if (_observation case final RecallObservation observation) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            _feedback(observation),
            key: const Key('study-feedback'),
            semanticsLabel: localized(
              context,
              '{state}: {feedback}',
              '{state}: {feedback}',
              values: <String, Object>{
                'state': _label(observation),
                'feedback': _feedback(observation),
              },
            ),
          ),
          if (observation != RecallObservation.stopped)
            TextField(
              key: const Key('study-next'),
              controller: _next,
              minLines: 2,
              maxLines: 4,
              maxLength: 600,
              decoration: InputDecoration(
                labelText: _text(
                  context,
                  'One point to revisit or ask about',
                  'Dönülecek veya sorulacak tek nokta',
                ),
              ),
            ),
        ],
      ],
    ),
  );
}
