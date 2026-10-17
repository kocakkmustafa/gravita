import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'account_connection.dart';
import 'app_locale.dart';
import 'calisthenics_course.dart';
import 'calisthenics_progress.dart';
import 'calisthenics_knowledge_diagrams.dart';
import 'content_repository.dart';
import 'motion_observation.dart';
import 'lesson_media.dart';
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
  StreamSubscription<void>? ownerSubscription;
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
      ownerSubscription?.cancel();
      connection = next;
      ownerSubscription = next?.ownerSessionChanges?.listen((_) {
        if (mounted && identical(connection, next)) {
          userId = connection?.userId.value;
          reload(reset: true);
        }
      });
      connection?.userId.addListener(_changed);
    }
    final id = connection != null
        ? connection!.userId.value
        : scope?.currentUserId;
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
      if (!mounted || turn != epoch) return;
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
    ownerSubscription?.cancel();
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
    this.preparationCourse,
    this.modelManifest,
    this.storeLoader,
    super.key,
  });
  final CalisthenicsCourse course;
  final CalisthenicsCourse? preparationCourse;
  final MotionModelManifest? modelManifest;
  final CalisthenicsStoreLoader? storeLoader;
  @override
  State<CalisthenicsCourseScreen> createState() =>
      _CalisthenicsCourseScreenState();
}

class _CalisthenicsCourseScreenState extends State<CalisthenicsCourseScreen>
    with _CourseIdentity<CalisthenicsCourseScreen> {
  @override
  CalisthenicsStoreLoader get loader =>
      widget.storeLoader ??
      (widget.course.id == 'calisthenics-foundations'
          ? _defaultLoader
          : (String? userId) => ContentRepository.openCalisthenicsProgressStore(
              accountUserId: userId,
              courseId: widget.course.id,
            ));
  @override
  Future<CalisthenicsProgress> readStore(CalisthenicsProgressStore value) =>
      value.load();
  Future<void> open(CalisthenicsLesson lesson) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CalisthenicsLessonScreen(
          course: widget.course,
          lesson: lesson,
          preparationCourse: widget.preparationCourse,
          modelManifest: widget.modelManifest,
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
          if (course.scope != null) ...[
            Text(_text(context, course.scope!)),
            Text(_text(context, course.equipment!)),
            Text(_text(context, course.entryCriteria!)),
            Text(_text(context, course.exitCriteria!)),
            const SizedBox(height: 18),
          ],
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
    this.preparationCourse,
    this.modelManifest,
    this.storeLoader,
    this.now,
    super.key,
  });
  final CalisthenicsCourse course;
  final CalisthenicsLesson lesson;
  final CalisthenicsCourse? preparationCourse;
  final MotionModelManifest? modelManifest;
  final CalisthenicsStoreLoader? storeLoader;
  final DateTime Function()? now;
  @override
  State<CalisthenicsLessonScreen> createState() =>
      _CalisthenicsLessonScreenState();
}

class _CalisthenicsLessonScreenState extends State<CalisthenicsLessonScreen>
    with _CourseIdentity<CalisthenicsLessonScreen>, WidgetsBindingObserver {
  bool confirmed = false;
  bool prepared = false;
  bool reportedThisVisit = false;
  DateTime? preparedOn;
  bool saving = false;
  bool answerVisible = false;
  bool get requiresPreparation =>
      !widget.lesson.learningOnly && widget.lesson.id != 'cal-04';
  DateTime get today => widget.now?.call() ?? DateTime.now();
  bool get preparedThisSession {
    final recorded = preparedOn;
    final current = today;
    return prepared &&
        recorded != null &&
        recorded.year == current.year &&
        recorded.month == current.month &&
        recorded.day == current.day;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      setState(() {
        prepared = false;
        preparedOn = null;
        answerVisible = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  CalisthenicsStoreLoader get loader =>
      widget.storeLoader ??
      (widget.course.id == 'calisthenics-foundations'
          ? _defaultLoader
          : (String? userId) => ContentRepository.openCalisthenicsProgressStore(
              accountUserId: userId,
              courseId: widget.course.id,
            ));
  @override
  Future<CalisthenicsProgress> readStore(CalisthenicsProgressStore value) =>
      value.markSeen(widget.course, widget.lesson);
  @override
  void identityReset() {
    confirmed = false;
    prepared = false;
    reportedThisVisit = false;
    preparedOn = null;
    saving = false;
    answerVisible = false;
  }

  Future<void> save(bool complete) async {
    final active = store;
    if (active == null ||
        saving ||
        (requiresPreparation && !preparedThisSession)) {
      return;
    }
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
        if (!complete) reportedThisVisit = true;
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

  String preparationFocus() {
    final module = widget.course.modules.singleWhere(
      (item) => item.lessons.contains(widget.lesson),
    );
    return switch (module.id) {
      'dbkb-patterns' || 'dbkb-variants' || 'dbkb-independent' => localized(
        context,
        'Keep hands empty. Prepare comfortably and rehearse only the small unloaded option; keep breathing naturally without holding or forcing it to match the movement.',
        'Eller boş kalsın. Rahatça hazırlan ve yalnız küçük yüksüz seçeneği prova et; nefesi tutmadan veya hareketle zorla eşleştirmeden doğal nefesi sürdür.',
      ),
      'lower' => localized(
        context,
        'Rehearse an easy sit-to-stand, shallow squat or supported hinge before this lower-body task.',
        'Bu alt vücut görevinden önce kolay otur-kalk, sığ squat veya destekli kalça menteşesi dene.',
      ),
      'push' || 'support' => localized(
        context,
        'Move shoulders and wrists gently; rehearse the wall or lightly supported version first.',
        'Omuzları ve bilekleri rahatça hareket ettir; önce duvar veya hafif destekli seçeneği dene.',
      ),
      'pull' => localized(
        context,
        'Check the anchor and exit path; begin with a supported, short-range pull.',
        'Dayanağı ve güvenli çıkışı kontrol et; destekli, kısa hareket aralıklı çekişle başla.',
      ),
      'core' => localized(
        context,
        'Begin with an easy bird-dog or short-lever trunk rehearsal before increasing the hold.',
        'Tutuş süresini artırmadan önce kolay bird-dog veya kısa kaldıraçlı gövde provası yap.',
      ),
      'conditioning' => localized(
        context,
        'Start with a gentle march, then practise the first pattern slowly without a jump.',
        'Hafif yürüyüşle başla; sonra ilk hareketi sıçramadan yavaşça dene.',
      ),
      'integration' when widget.lesson.id == 'cal-53' => localized(
        context,
        'Choose easy lower-body and push versions first. Rehearse a supported sit-to-stand and a wall push before your review.',
        'Önce kolay alt beden ve itiş seçeneklerini seç. Değerlendirmeden önce destekli otur-kalk ve duvar itişini prova et.',
      ),
      'integration' when widget.lesson.id == 'cal-54' => localized(
        context,
        'Check the pull anchor and exit path. Rehearse a supported short row and an easy trunk option before combining them.',
        'Çekiş dayanağını ve güvenli çıkışı kontrol et. Birleştirmeden önce destekli kısa row ve kolay gövde seçeneğini prova et.',
      ),
      'integration' => localized(
        context,
        'Choose an easy version of each movement in your plan and rehearse them one at a time before the short session.',
        'Planındaki her hareketin kolay seçeneğini seç ve kısa seanstan önce tek tek prova et.',
      ),
      _ => localized(
        context,
        'Rehearse the easiest version of the movement you chose before increasing range or effort.',
        'Seçtiğin hareketin en kolay seçeneğini, aralığı veya eforu artırmadan önce dene.',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final record = progress.forLesson(lesson, widget.course.version);
    final practiceHeld = widget.course.practiceHeld(lesson);
    final practised = (record?.practiceCount ?? 0) > 0;
    final enoughPracticeReports =
        lesson.learningOnly || (record?.practiceCount ?? 0) >= 2;
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
          if (lesson.id == 'dbkb-03' && widget.preparationCourse != null)
            TextButton(
              key: const Key('dbkb.lesson.preparation.cal-04'),
              onPressed: () {
                final preparation = widget.preparationCourse!;
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => CalisthenicsLessonScreen(
                      course: preparation,
                      lesson: preparation.lessons.singleWhere(
                        (l) => l.id == 'cal-04',
                      ),
                    ),
                  ),
                );
              },
              child: Text(
                localized(
                  context,
                  'Open the existing preparation lesson',
                  'Mevcut hazırlık dersini aç',
                ),
              ),
            ),
          if (lesson.movementTaskId != null)
            section('Movement observation', 'Hareket gözlemi', <String>[
              widget.modelManifest?.readinessFor(lesson.movementTaskId!) ==
                      ObservationStatus.calibrationRequired
                  ? localized(
                      context,
                      'Calibration required. Repetition, phase and reference feedback are unavailable for this task. Training will be added in a later update; your reading progress stays separate.',
                      'Kalibrasyon gerekli. Bu görevde tekrar, faz ve referans geri bildirimi kullanılamıyor. Eğitim sonraki güncellemede eklenecek; okuma ilerlemen ayrı kalır.',
                    )
                  : localized(
                      context,
                      'Movement observation is unsupported for this lesson in this version.',
                      'Bu sürümde bu ders için hareket gözlemi desteklenmiyor.',
                    ),
            ], sealed: true),
          if (lesson.learningOnly)
            section('Learning task', 'Öğrenme görevi', <String>[
              localized(
                context,
                'No physical attempt is required. Work through the written or diagram task.',
                'Fiziksel deneme gerekli değil. Yazılı veya şema görevini çalış.',
              ),
            ], sealed: true),
          if (practiceHeld)
            section(
              'Physical practice awaiting review',
              'Fiziksel pratik inceleme bekliyor',
              <String>[
                _text(context, widget.course.healthNotice),
                localized(
                  context,
                  'Reading is available. No physical task report or completion can be saved yet.',
                  'Okuma açık. Henüz fiziksel görev bildirimi veya tamamlaması kaydedilemez.',
                ),
              ],
              sealed: true,
            ),
          if (requiresPreparation && !practiceHeld)
            GravitaCard(
              sealed: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    localized(
                      context,
                      'Prepare for this session',
                      'Bu oturuma hazırlan',
                    ),
                    style: GravitaType.display(size: 19),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    localized(
                      context,
                      'If this is a fresh session, walk or march gently, including seated marching if needed, until you feel lightly warm. Move the joints used today through a comfortable range, then rehearse at low effort. If you are still warm from the same session, review the rehearsal before continuing.',
                      'Yeni bir oturumsa hafifçe ısınana kadar yürü veya gerekirse oturarak yerinde adımla. Bugün kullanılacak eklemleri rahat aralıkta hareket ettir, sonra düşük eforla prova yap. Aynı oturumdan hâlâ ısınmışsan devam etmeden önce provayı gözden geçir.',
                    ),
                    style: GravitaType.body(size: 15),
                  ),
                  const SizedBox(height: 8),
                  Text(preparationFocus(), style: GravitaType.body(size: 15)),
                  CheckboxListTile(
                    key: const Key('calisthenics.prepared'),
                    contentPadding: EdgeInsets.zero,
                    value: preparedThisSession,
                    onChanged: saving
                        ? null
                        : (value) => setState(() {
                            prepared = value ?? false;
                            preparedOn = prepared ? today : null;
                          }),
                    title: Text(
                      localized(
                        context,
                        'I prepared for this session or am continuing while still warm · self-report',
                        'Bu oturuma hazırlandım veya hâlâ ısınmışken sürdürüyorum · öz bildirim',
                      ),
                      style: GravitaType.body(size: 13),
                    ),
                  ),
                  if (preparedThisSession)
                    TextButton(
                      key: const Key('calisthenics.newSession'),
                      onPressed: saving
                          ? null
                          : () => setState(() {
                              prepared = false;
                              preparedOn = null;
                            }),
                      child: Text(
                        localized(
                          context,
                          'Starting again after a break? Prepare again',
                          'Moladan sonra yeniden mi başlıyorsun? Yeniden hazırlan',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          section('Learn the movement', 'Hareketi öğren', <String>[
            for (var i = 0; i < lesson.steps.length; i++)
              '${i + 1}. ${_text(context, lesson.steps[i])}',
          ]),
          if (widget.course.id == 'calisthenics-foundations')
            LessonMediaSlot.empty(
              key: const Key('calisthenics.lesson.media'),
              course: widget.course,
              lessonId: lesson.id,
              locale: Localizations.localeOf(context).languageCode,
              accountUserId: AccountScope.maybeOf(context)?.connection?.userId,
            ),
          if (widget.course.reviewRequired ||
              widget.course.id == 'dbkb-written-foundations' ||
              widget.course.id == 'dbkb-controlled-handling' ||
              widget.course.id == 'dbkb-supported-transitions')
            section('Demonstration boundary', 'Gösterim sınırı', <String>[
              _text(context, lesson.mediaBrief),
            ], sealed: true),
          if (CalisthenicsKnowledgeDiagrams.supports(lesson.id))
            CalisthenicsKnowledgeDiagrams(lessonId: lesson.id),
          KeyedSubtree(
            key: const Key('calisthenics.practiceOptions'),
            child: section('Practice options', 'Pratik seçenekleri', <String>[
              requiresPreparation && !preparedThisSession
                  ? localized(
                      context,
                      'Read the learning steps now. Physical practice options open after you report this session preparation above.',
                      'Öğrenme adımlarını şimdi okuyabilirsin. Fiziksel pratik seçenekleri yukarıdaki oturum hazırlığını bildirdikten sonra açılır.',
                    )
                  : _text(context, lesson.practice),
            ]),
          ),
          section(
            'Self-check',
            'Öz denetim',
            lesson.selfCheck.map((c) => _text(context, c)).toList(),
          ),
          if (lesson.recall != null) ...<Widget>[
            section(
              'Recall before revealing the answer',
              'Yanıtı açmadan hatırla',
              <String>[_text(context, lesson.recall!)],
            ),
            section(
              'One correction and retest',
              'Tek düzeltme ve yeniden deneme',
              <String>[
                requiresPreparation && !preparedThisSession
                    ? localized(
                        context,
                        'Read and answer in words now. Physical correction/retest opens only after session preparation; keep every attempt unloaded.',
                        'Şimdi oku ve sözle yanıtla. Fiziksel düzeltme/yeniden deneme yalnız oturum hazırlığından sonra açılır; her deneme yüksüz kalsın.',
                      )
                    : _text(context, lesson.correction!),
              ],
            ),
            TextButton(
              key: const Key('dbkb.answer.toggle'),
              onPressed: requiresPreparation && !preparedThisSession
                  ? null
                  : () => setState(() => answerVisible = !answerVisible),
              child: Text(
                localized(
                  context,
                  answerVisible
                      ? 'Hide answer'
                      : 'I answered — compare reasoning',
                  answerVisible
                      ? 'Yanıtı gizle'
                      : 'Yanıtladım — gerekçeyi karşılaştır',
                ),
              ),
            ),
            if (answerVisible && (!requiresPreparation || preparedThisSession))
              KeyedSubtree(
                key: const Key('dbkb.answer.content'),
                child: section(
                  'Compare after your answer',
                  'Yanıtından sonra karşılaştır',
                  <String>[_text(context, lesson.answer!)],
                ),
              ),
          ],
          section('An easier path', 'Daha kolay yol', <String>[
            _text(context, lesson.adaptation),
          ]),
          if (lesson.progression != null) ...[
            section('Progression', 'İlerleme seçeneği', [
              _text(context, lesson.progression!),
            ]),
            section('Regression', 'Kolaylaştırma', [
              _text(context, lesson.regression!),
            ]),
            section('Rest and recovery', 'Dinlenme ve toparlanma', [
              _text(context, lesson.rest!),
            ]),
          ],
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
                  if (!lesson.learningOnly)
                    Text(
                      localized(
                        context,
                        'Physical lessons need two practice reports from separate visits before you can record learning completion. Reports do not assess form or skill.',
                        'Fiziksel derslerde öğrenme tamamlamasını kaydetmeden önce ayrı ziyaretlerde iki pratik bildirimi gerekir. Bildirimler formu veya beceriyi ölçmez.',
                      ),
                      style: GravitaType.body(size: 13),
                    ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    key: const Key('calisthenics.practised'),
                    onPressed:
                        store == null ||
                            saving ||
                            practiceHeld ||
                            reportedThisVisit ||
                            (requiresPreparation && !preparedThisSession)
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
                        store == null ||
                            saving ||
                            practiceHeld ||
                            !confirmed ||
                            !practised ||
                            !enoughPracticeReports ||
                            (requiresPreparation && !preparedThisSession)
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
                  if (source.supports case final support?)
                    Text(
                      '${localized(context, 'Supports only:', 'Yalnız destekler:')} ${localized(context, support.en, support.tr)}',
                      key: Key('calisthenics.sourceScope.${source.id}'),
                      style: GravitaType.body(size: 12),
                    ),
                  if (source.doesNotSupport case final limit?)
                    Text(
                      '${localized(context, 'Does not establish:', 'Kanıtlamaz:')} ${localized(context, limit.en, limit.tr)}',
                      key: Key('calisthenics.sourceLimit.${source.id}'),
                      style: GravitaType.body(size: 12),
                    ),
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
