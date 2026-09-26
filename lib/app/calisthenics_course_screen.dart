import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'account_connection.dart';
import 'app_locale.dart';
import 'calisthenics_course.dart';
import 'calisthenics_progress.dart';
import 'content_repository.dart';
import 'theme.dart';

typedef CalisthenicsStoreLoader =
    Future<CalisthenicsProgressStore> Function(String? userId);
Future<CalisthenicsProgressStore> _defaultLoader(String? userId) =>
    ContentRepository.openCalisthenicsProgressStore(accountUserId: userId);
String _text(BuildContext context, CourseText value) =>
    value.inLanguage(Localizations.localeOf(context).languageCode);
String _stateLabel(BuildContext context, CalisthenicsLessonProgress? record) =>
    switch (record?.state) {
      null => localized(context, 'Not opened', 'Açılmadı'),
      CalisthenicsLessonState.seen => localized(context, 'Seen', 'Görüldü'),
      CalisthenicsLessonState.practised => localized(
        context,
        'Task practised · self-report',
        'Görev çalışıldı · öz bildirim',
      ),
      CalisthenicsLessonState.selfReportedComplete => localized(
        context,
        'Learning completed · self-report',
        'Öğrenme tamamlandı · öz bildirim',
      ),
    };

class CalisthenicsEntryCard extends StatelessWidget {
  const CalisthenicsEntryCard({required this.content, super.key});
  final ContentRepository content;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      key: const Key('calisthenics.entry'),
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              CalisthenicsCourseScreen(course: content.calisthenicsCourse),
        ),
      ),
      child: GravitaCard(
        child: Row(
          children: <Widget>[
            const Icon(Icons.menu_book_outlined, color: GravitaColors.ink),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _text(context, content.calisthenicsCourse.title),
                    style: GravitaType.display(size: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localized(
                      context,
                      '56 lessons · 10 modules · your own pace',
                      '56 ders · 10 modül · kendi hızında',
                    ),
                    style: GravitaType.body(size: 13),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    localized(
                      context,
                      'Learn, practise, record your progress',
                      'Öğren, çalış, ilerlemeni kaydet',
                    ),
                    style: GravitaType.body(
                      size: 13,
                      color: GravitaColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: GravitaColors.inkMuted),
          ],
        ),
      ),
    ),
  );
}

/// Both routes reload on identity changes. An epoch also guards awaited
/// results when a save/read completes after navigation, switch or deletion.
mixin _CourseIdentity<T extends StatefulWidget> on State<T> {
  String? userId;
  Object? storageError;
  CalisthenicsProgressStore? store;
  CalisthenicsProgress progress = const CalisthenicsProgress({});
  int epoch = 0;
  AccountConnection? connection;
  bool initialized = false;
  CalisthenicsStoreLoader get loader;
  Future<CalisthenicsProgress> readStore(CalisthenicsProgressStore value);
  void identityReset() {}

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AccountScope.maybeOf(context);
    final next = scope?.connection;
    if (next != connection) {
      connection?.userId.removeListener(_changed);
      connection = next;
      connection?.userId.addListener(_changed);
    }
    final id = connection?.userId.value ?? scope?.currentUserId;
    if (!initialized || id != userId) {
      initialized = true;
      userId = id;
      reload(reset: true);
    }
  }

  void _changed() {
    userId = connection?.userId.value;
    reload(reset: true);
  }

  Future<void> reload({bool reset = false}) async {
    final turn = ++epoch;
    if (reset) {
      identityReset();
      store = null;
      progress = const CalisthenicsProgress({});
    }
    storageError = null;
    if (mounted) setState(() {});
    try {
      final opened = await loader(userId);
      final result = await readStore(opened);
      if (!mounted || turn != epoch) return;
      setState(() {
        store = opened;
        progress = result;
      });
    } on Object catch (error) {
      if (!mounted || turn != epoch) return;
      setState(() {
        storageError = error;
        store = null;
      });
    }
  }

  @override
  void dispose() {
    epoch++;
    connection?.userId.removeListener(_changed);
    super.dispose();
  }

  Widget? storageNotice() => storageError == null
      ? null
      : GravitaCard(
          sealed: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                localized(
                  context,
                  'Progress could not be read or saved. Your reading stays available.',
                  'İlerleme okunamadı veya kaydedilemedi. Dersleri okumaya devam edebilirsin.',
                ),
                style: GravitaType.body(size: 14),
              ),
              TextButton(
                onPressed: reload,
                child: Text(
                  localized(context, 'Retry storage', 'Kaydı yeniden dene'),
                ),
              ),
            ],
          ),
        );
}

class CalisthenicsCourseScreen extends StatefulWidget {
  const CalisthenicsCourseScreen({
    required this.course,
    this.storeLoader,
    super.key,
  });
  final CalisthenicsCourse course;
  final CalisthenicsStoreLoader? storeLoader;
  @override
  State<CalisthenicsCourseScreen> createState() =>
      _CalisthenicsCourseScreenState();
}

class _CalisthenicsCourseScreenState extends State<CalisthenicsCourseScreen>
    with _CourseIdentity<CalisthenicsCourseScreen> {
  @override
  CalisthenicsStoreLoader get loader => widget.storeLoader ?? _defaultLoader;
  @override
  Future<CalisthenicsProgress> readStore(CalisthenicsProgressStore value) =>
      value.load();
  Future<void> open(CalisthenicsLesson lesson) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CalisthenicsLessonScreen(
          course: widget.course,
          lesson: lesson,
          storeLoader: widget.storeLoader,
        ),
      ),
    );
    if (mounted) await reload();
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final completed = progress.completedCount(course);
    final next = progress.nextLesson(course);
    return Scaffold(
      backgroundColor: GravitaColors.page,
      appBar: AppBar(title: Text(localized(context, 'Your course', 'Kursun'))),
      body: ListView(
        key: const Key('calisthenics.course.body'),
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          Text(
            _text(context, course.title),
            style: GravitaType.display(size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            _text(context, course.description),
            style: GravitaType.body(size: 15),
          ),
          const SizedBox(height: 18),
          GravitaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$completed / ${course.lessons.length}',
                  key: const Key('calisthenics.total'),
                  style: GravitaType.mono(size: 20),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: completed / course.lessons.length,
                  color: GravitaColors.ink,
                  semanticsLabel: localized(
                    context,
                    'Self-reported learning progress',
                    'Öz bildirime göre öğrenme ilerlemesi',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  localized(
                    context,
                    'Reading, task practice and your completion statement are separate. This is not a camera assessment.',
                    'Okuma, görev pratiği ve tamamlama bildirimin ayrıdır. Bu bir kamera değerlendirmesi değildir.',
                  ),
                  style: GravitaType.body(size: 13),
                ),
                if (next != null)
                  TextButton(
                    key: const Key('calisthenics.next'),
                    onPressed: () => open(next),
                    child: Text(
                      '${localized(context, 'Suggested next', 'Önerilen sıradaki')}: ${_text(context, next.title)}',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (storageNotice() case final notice?) ...<Widget>[
            notice,
            const SizedBox(height: 16),
          ],
          GravitaCard(
            sealed: true,
            child: Text(
              _text(context, course.healthNotice),
              style: GravitaType.body(
                size: 13,
                color: GravitaColors.honestyText,
              ),
            ),
          ),
          const SizedBox(height: 20),
          for (final module in course.modules) ...<Widget>[
            GravitaCard(
              padding: const EdgeInsets.all(12),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        _text(context, module.title),
                        style: GravitaType.display(size: 20),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${module.lessons.where((l) => progress.forLesson(l, course.version)?.state == CalisthenicsLessonState.selfReportedComplete).length} / ${module.lessons.length}',
                        style: GravitaType.mono(size: 12),
                      ),
                    ),
                    for (final lesson in module.lessons)
                      ListTile(
                        key: Key('calisthenics.lesson.${lesson.id}'),
                        title: Text(
                          _text(context, lesson.title),
                          style: GravitaType.body(size: 15),
                        ),
                        subtitle: Text(
                          _stateLabel(
                            context,
                            progress.forLesson(lesson, course.version),
                          ),
                          style: GravitaType.body(
                            size: 12,
                            color: GravitaColors.textSecondary,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => open(lesson),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            '${localized(context, 'Content version', 'İçerik sürümü')} ${course.version} · ${localized(context, 'Local account progress', 'Hesaba ait yerel ilerleme')}',
            style: GravitaType.body(size: 12),
          ),
        ],
      ),
    );
  }
}

class CalisthenicsLessonScreen extends StatefulWidget {
  const CalisthenicsLessonScreen({
    required this.course,
    required this.lesson,
    this.storeLoader,
    super.key,
  });
  final CalisthenicsCourse course;
  final CalisthenicsLesson lesson;
  final CalisthenicsStoreLoader? storeLoader;
  @override
  State<CalisthenicsLessonScreen> createState() =>
      _CalisthenicsLessonScreenState();
}

class _CalisthenicsLessonScreenState extends State<CalisthenicsLessonScreen>
    with _CourseIdentity<CalisthenicsLessonScreen> {
  bool confirmed = false;
  bool saving = false;
  @override
  CalisthenicsStoreLoader get loader => widget.storeLoader ?? _defaultLoader;
  @override
  Future<CalisthenicsProgress> readStore(CalisthenicsProgressStore value) =>
      value.markSeen(widget.course, widget.lesson);
  @override
  void identityReset() {
    confirmed = false;
    saving = false;
  }

  Future<void> save(bool complete) async {
    final active = store;
    if (active == null || saving) return;
    final turn = epoch;
    setState(() => saving = true);
    try {
      final result = complete
          ? await active.markCompleted(
              widget.course,
              widget.lesson,
              selfChecksConfirmed: confirmed,
            )
          : await active.markPractised(widget.course, widget.lesson);
      if (!mounted || turn != epoch) return;
      setState(() {
        progress = result;
        saving = false;
        storageError = null;
      });
    } on Object catch (error) {
      if (!mounted || turn != epoch) return;
      setState(() {
        storageError = error;
        saving = false;
        store = null;
      });
    }
  }

  Widget section(
    String en,
    String tr,
    List<String> lines, {
    bool sealed = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: GravitaCard(
      sealed: sealed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            localized(context, en, tr),
            style: GravitaType.display(size: 19),
          ),
          const SizedBox(height: 10),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(line, style: GravitaType.body(size: 15)),
            ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final record = progress.forLesson(lesson, widget.course.version);
    final practised = (record?.practiceCount ?? 0) > 0;
    return Scaffold(
      backgroundColor: GravitaColors.page,
      appBar: AppBar(title: Text(localized(context, 'Lesson', 'Ders'))),
      body: ListView(
        key: const Key('calisthenics.lesson.body'),
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          Text(
            _text(context, lesson.title),
            style: GravitaType.display(size: 27),
          ),
          const SizedBox(height: 10),
          Text(
            _text(context, lesson.objective),
            style: GravitaType.body(size: 16),
          ),
          const SizedBox(height: 12),
          Text(
            _stateLabel(context, record),
            key: const Key('calisthenics.state'),
            style: GravitaType.body(size: 13),
          ),
          const SizedBox(height: 16),
          if (lesson.prerequisites.isNotEmpty)
            section('Recommended first', 'Önce önerilen', <String>[
              _text(
                context,
                widget.course.lessons
                    .singleWhere((l) => l.id == lesson.prerequisites.single)
                    .title,
              ),
              localized(
                context,
                'Reading stays open. Repeat an easier option whenever you need it.',
                'Okuma açık kalır. Gerektiğinde kolay seçeneği yinele.',
              ),
            ]),
          if (lesson.learningOnly)
            section('Learning task', 'Öğrenme görevi', <String>[
              localized(
                context,
                'No physical attempt is required. Work through the written or diagram task.',
                'Fiziksel deneme gerekli değil. Yazılı veya şema görevini çalış.',
              ),
            ], sealed: true),
          section('Learn the movement', 'Hareketi öğren', <String>[
            for (var i = 0; i < lesson.steps.length; i++)
              '${i + 1}. ${_text(context, lesson.steps[i])}',
          ]),
          section('Practice options', 'Pratik seçenekleri', <String>[
            _text(context, lesson.practice),
          ]),
          section(
            'Self-check',
            'Öz denetim',
            lesson.selfCheck.map((c) => _text(context, c)).toList(),
          ),
          section('An easier path', 'Daha kolay yol', <String>[
            _text(context, lesson.adaptation),
          ]),
          section('When to stop', 'Ne zaman durmalı', <String>[
            _text(context, lesson.stop),
          ], sealed: true),
          if (storageNotice() case final notice?) ...<Widget>[
            notice,
            const SizedBox(height: 16),
          ],
          GravitaCard(
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: <Widget>[
                  Text(
                    localized(
                      context,
                      'Save what you actually worked through. Completion is your statement of learning, including an appropriate easier path.',
                      'Gerçekte çalıştığın görevi kaydet. Tamamlama, uygun kolay yol dahil kendi öğrenme bildirimindir.',
                    ),
                    style: GravitaType.body(size: 13),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    key: const Key('calisthenics.practised'),
                    onPressed: store == null || saving
                        ? null
                        : () => save(false),
                    child: Text(
                      lesson.learningOnly
                          ? localized(
                              context,
                              'I reviewed the learning task',
                              'Öğrenme görevini çalıştım',
                            )
                          : localized(
                              context,
                              'I practised my chosen option',
                              'Seçtiğim seçeneği çalıştım',
                            ),
                    ),
                  ),
                  CheckboxListTile(
                    key: const Key('calisthenics.confirm'),
                    value: confirmed,
                    onChanged: store == null || saving
                        ? null
                        : (value) => setState(() => confirmed = value ?? false),
                    title: Text(
                      localized(
                        context,
                        'I reviewed the self-checks, easier path and stop signs.',
                        'Öz denetimi, kolay yolu ve durma işaretlerini gözden geçirdim.',
                      ),
                      style: GravitaType.body(size: 13),
                    ),
                  ),
                  FilledButton(
                    key: const Key('calisthenics.complete'),
                    onPressed:
                        store == null || saving || !confirmed || !practised
                        ? null
                        : () => save(true),
                    child: Text(
                      localized(
                        context,
                        'Record my learning completion',
                        'Öğrenme tamamlamamı kaydet',
                      ),
                    ),
                  ),
                  Text(
                    '${localized(context, 'Task reports', 'Görev bildirimleri')}: ${record?.practiceCount ?? 0}',
                    key: const Key('calisthenics.practiceCount'),
                    style: GravitaType.mono(size: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          section('Sources and scope', 'Kaynaklar ve kapsam', <String>[
            localized(
              context,
              'These sources inform general principles and technique; they do not validate this course or a camera verdict.',
              'Bu kaynaklar genel prensip ve tekniğe temel olur; bu kursu veya kamera kararını doğrulamaz.',
            ),
          ]),
          for (final source in widget.course.sources.where(
            (s) => lesson.sourceIds.contains(s.id),
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    source.title,
                    style: GravitaType.body(size: 13, weight: FontWeight.w600),
                  ),
                  SelectableText(source.url, style: GravitaType.body(size: 12)),
                  TextButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: source.url));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              localized(
                                context,
                                'Source link copied',
                                'Kaynak bağlantısı kopyalandı',
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    child: Text(
                      localized(
                        context,
                        'Copy source link',
                        'Kaynak bağlantısını kopyala',
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
