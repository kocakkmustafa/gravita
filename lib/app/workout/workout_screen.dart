import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../app_locale.dart';
import '../camera_release_policy.dart';
import '../content_repository.dart';
import '../library_strings.dart';
import '../program/program_builder.dart';
import '../program/program_model.dart';
import '../program/program_schedule_store.dart';
import '../program/program_signature.dart';
import '../program/program_setup_screen.dart';
import '../program/program_store.dart';
import '../surface_widgets.dart';
import '../theme.dart';

/// Programın genel bakışı + gün durumu (GRA-P1-003 Step 1/2/3/4 UI'ı).
///
/// ## Kapsam BİLEREK DAR
///
/// Bu sürüm sekiz haftalık planı OKUNUR biçimde gösterir, RPE toplar (Step 3)
/// ve kaçırılan bir günü CEZASIZ yeniden sıralar (Step 4). TAŞIMADIĞI şeyler
/// adıyla: hangi hareketin GERÇEKTE nasıl gittiğinin motor-ölçümlü kaydı
/// (`gravita_engine`e HİÇ bağımlı değil — RPE saf kullanıcı beyanı, roadmap
/// Step 3'ün "camera sonucu değildir" şartı), kalıcı bir "geçmiş" ekranı,
/// dışa aktarım/silme (bunlar GRA-P1-004'ün storage katmanının işi — orada
/// `session_projector.dart`/Drift DB gelecek; BU dosya yalnız yerel, küçük
/// bir JSON dosyasına yazıyor, `program_schedule_store.dart`).
class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({required this.content, this.accountUserId, super.key})
    : _now = null;

  @visibleForTesting
  const WorkoutScreen.withClock({
    required this.content,
    required DateTime Function() now,
    this.accountUserId,
    super.key,
  }) : _now = now;

  static const Key emptyKey = Key('workout.empty');
  static const Key disclaimerKey = Key('workout.disclaimer');
  static const Key unavailableKey = Key('workout.unavailable');
  static const Key retryKey = Key('workout.retry');

  final ContentRepository content;
  final String? accountUserId;
  final DateTime Function()? _now;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

typedef _Loaded = ({
  ProgramInputs? inputs,
  WorkoutProgram? program,
  ProgramSchedule? schedule,
  DateTime today,
  bool blocked,
});

class _WorkoutScreenState extends State<WorkoutScreen>
    with WidgetsBindingObserver {
  late Future<_Loaded> _future = _load();
  late DateTime _viewNow = _now();
  Timer? _dayTimer;

  DateTime _now() => widget._now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _armNextDay();
  }

  void _armNextDay() {
    _dayTimer?.cancel();
    final now = _now();
    final next = now.isUtc
        ? DateTime.utc(now.year, now.month, now.day + 1)
        : DateTime(now.year, now.month, now.day + 1);
    _dayTimer = Timer(next.difference(now), _refreshToday);
  }

  void _refreshToday() {
    if (!mounted) return;
    final now = _now();
    if (now.year != _viewNow.year ||
        now.month != _viewNow.month ||
        now.day != _viewNow.day ||
        now.timeZoneOffset != _viewNow.timeZoneOffset) {
      setState(() => _viewNow = now);
    }
    _armNextDay();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshToday();
  }

  @override
  void didUpdateWidget(covariant WorkoutScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountUserId != widget.accountUserId ||
        oldWidget.content != widget.content) {
      _future = _load();
    }
    if (oldWidget._now != widget._now) {
      _viewNow = _now();
      _armNextDay();
    }
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<_Loaded> _load() async {
    // The view clock never rewrites persisted dates. The builder remains pure;
    // midnight/resume updates only which scheduled days appear overdue.
    final DateTime now = _now();
    try {
      final ProgramInputs? inputs = await (await ProgramStore.open(
        accountUserId: widget.accountUserId,
      )).read();
      final scheduleStore = await ProgramScheduleStore.open(
        accountUserId: widget.accountUserId,
      );
      final schedule = await scheduleStore.read();
      if (inputs == null && schedule == null) {
        return (
          inputs: null,
          program: null,
          schedule: null,
          today: now,
          blocked: false,
        );
      }
      if (inputs == null || schedule == null) {
        throw StateError('Saved program is incomplete; preserve its files');
      }
      final ProgramConfig config = await ContentRepository.loadProgramConfig(
        rootBundle,
      );
      final List<ProgramCatalogEntry> entries = await widget.content
          .programCatalogEntries();
      final WorkoutProgram program = ProgramBuilder(
        config: config,
        catalog: entries,
      ).build(inputs);

      // Loading is read-only. A legacy/unmatched schedule cannot establish
      // which prescription its old indices and RPE belong to. Never invent
      // that binding, reset its history, or apply the new calendar to it.
      if (schedule.programSignature != programSignature(inputs, program) ||
          schedule.dates.length != program.days.length) {
        throw StateError('Saved history has no matching prescription binding');
      }
      return (
        inputs: inputs,
        program: program,
        schedule: schedule,
        today: now,
        blocked: false,
      );
    } on Object {
      return (
        inputs: null,
        program: null,
        schedule: null,
        today: now,
        blocked: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        localized(
          context,
          LibraryStrings.programOverviewTitle,
          'Sekiz haftalık programın',
        ),
      ),
    ),
    body: FutureBuilder<_Loaded>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<_Loaded> snap) {
        final _Loaded? data = snap.data;
        if (data == null ||
            snap.connectionState != ConnectionState.done && !data.blocked) {
          return const Center(child: CircularProgressIndicator());
        }
        if (data.blocked) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                NoteCard(
                  key: WorkoutScreen.unavailableKey,
                  icon: Icons.info_outline,
                  text: localized(
                    context,
                    'Your saved program could not be safely loaded. Its dates and '
                        'progress have been kept. It has not been replaced with a '
                        'new plan. Reopen the app or contact support before changing it.',
                    'Kayıtlı programın güvenle açılamadı. Tarihlerin ve ilerlemen '
                        'korundu; yerine yeni bir plan yazılmadı. Değişiklik '
                        'yapmadan önce uygulamayı yeniden aç veya desteğe ulaş.',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: WorkoutScreen.retryKey,
                  onPressed: snap.connectionState != ConnectionState.done
                      ? null
                      : () => setState(() => _future = _load()),
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    localized(context, 'Retry loading', 'Yeniden okumayı dene'),
                  ),
                ),
              ],
            ),
          );
        }
        if (data.program == null || data.schedule == null) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                NoteCard(
                  key: WorkoutScreen.emptyKey,
                  icon: Icons.calendar_month_outlined,
                  text: localized(
                    context,
                    LibraryStrings.programNoInputs,
                    'Henüz bir program kurmadın. Birkaç soruyu yanıtla; '
                    'kütüphanedeki hareketlerden sekiz haftalık bir plan oluşturalım.',
                  ),
                ),
                const SizedBox(height: 18),
                // ⚠️ InkWell-sarmalı KART — düz `FilledButton` DEĞİL.
                // Gerekçe ölçüldü (G-271 devamı): `test/reachability_
                // test.dart`ın `tappables()`i yalnız `InkWell`/
                // `FloatingActionButton`/`NavigationDestination` tanır;
                // bu ekrandaki TEK ProgramSetupScreen tetiği bu kart —
                // düz buton olsaydı o ekran "ulaşılamıyor ama var"a
                // düşerdi (skill-trees kartlarıyla AYNI desen).
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    focusColor: GravitaColors.of(
                      context,
                    ).onAccent.withValues(alpha: 0.2),
                    hoverColor: GravitaColors.of(
                      context,
                    ).onAccent.withValues(alpha: 0.12),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => ProgramSetupScreen(
                          content: widget.content,
                          accountUserId: widget.accountUserId,
                        ),
                      ),
                    ),
                    child: Ink(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: GravitaColors.of(context).accent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        localized(
                          context,
                          LibraryStrings.programNoInputsAction,
                          'Programını oluştur',
                        ),
                        textAlign: TextAlign.center,
                        style: GravitaType.body(
                          context: context,
                          size: 15,
                          weight: FontWeight.w600,
                          color: GravitaColors.of(context).onAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return _ProgramOverview(
          key: ValueKey<String>(
            '${widget.accountUserId ?? 'guest'}:${data.schedule!.programSignature}',
          ),
          content: widget.content,
          program: data.program!,
          initialSchedule: data.schedule!,
          today: _viewNow,
          daysPerWeek: data.inputs!.daysPerWeek,
          accountUserId: widget.accountUserId,
          signature: data.schedule!.programSignature!,
        );
      },
    ),
  );
}

/// Takvimi KENDİ yerel durumu olarak taşır — `WorkoutScreen`in `_future`ı
/// ilk yükleme ve açık yeniden denemeyi sürer; "mark done"/"reschedule" etkileşimleri
/// TÜM zinciri (asset+katalog+program üretimi) yeniden ÇALIŞTIRMAZ, yalnız
/// takvimi günceller.
class _ProgramOverview extends StatefulWidget {
  const _ProgramOverview({
    required this.content,
    required this.program,
    required this.initialSchedule,
    required this.today,
    required this.daysPerWeek,
    this.accountUserId,
    required this.signature,
    super.key,
  });

  final ContentRepository content;
  final WorkoutProgram program;
  final ProgramSchedule initialSchedule;
  final DateTime today;
  final int daysPerWeek;
  final String? accountUserId;
  final String signature;

  @override
  State<_ProgramOverview> createState() => _ProgramOverviewState();
}

class _ProgramOverviewState extends State<_ProgramOverview> {
  late ProgramSchedule _schedule = widget.initialSchedule;

  void _saveFailed() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          localized(
            context,
            'The save could not be confirmed. Reopen the app and check your progress.',
            'Kayıt doğrulanamadı. Uygulamayı yeniden açıp ilerlemeni kontrol et.',
          ),
        ),
      ),
    );
  }

  Future<bool> _markDone(int dayIndex, int rpe) async {
    try {
      final updated =
          await (await ProgramScheduleStore.open(
            accountUserId: widget.accountUserId,
          )).update(
            expectedSignature: widget.signature,
            transform: (current) => current.withRpe(dayIndex, rpe),
          );
      if (mounted) setState(() => _schedule = updated);
      return true;
    } on Object {
      _saveFailed();
      return false;
    }
  }

  Future<bool> _reschedule(int dayIndex) async {
    try {
      final updated =
          await (await ProgramScheduleStore.open(
            accountUserId: widget.accountUserId,
          )).update(
            expectedSignature: widget.signature,
            transform: (current) => current.withDates(
              rescheduleAfterMiss(
                schedule: current.dates,
                missedIndex: dayIndex,
                slotSpacing: Duration(
                  days: scheduleGapDays(widget.daysPerWeek),
                ),
              ),
            ),
          );
      if (mounted) setState(() => _schedule = updated);
      return true;
    } on Object {
      _saveFailed();
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Haftaya göre grupla — İNDEKS taşınır (`_schedule.dates`/
    // `rpeByDayIndex`in anahtarı [WorkoutProgram.days]ın DÜZ indeksidir).
    final Map<int, List<int>> byWeek = <int, List<int>>{};
    for (int i = 0; i < widget.program.days.length; i++) {
      (byWeek[widget.program.days[i].weekNumber] ??= <int>[]).add(i);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 48),
      children: <Widget>[
        NoteCard(
          key: WorkoutScreen.disclaimerKey,
          sealed: true,
          icon: Icons.info_outline,
          text: localized(
            context,
            LibraryStrings.programOverviewDisclaimer,
            'Bu genel bir çalışma rehberidir; koçluk veya tıbbi öneri '
            'değildir. İlerleme düzeni hareket bilimi incelemesinden geçmedi.',
          ),
        ),
        const SizedBox(height: 24),
        for (final int week in byWeek.keys.toList()..sort())
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: SurfaceSection(
              title: localizedUpper(
                context,
                widget.program.days[byWeek[week]!.first].isDeload
                    ? 'Week {week} — deload'
                    : 'Week {week}',
                widget.program.days[byWeek[week]!.first].isDeload
                    ? '{week}. HAFTA — HAFİFLETME'
                    : '{week}. HAFTA',
                values: <String, Object>{'week': week},
              ),
              children: <Widget>[
                for (final int dayIndex in byWeek[week]!)
                  _DayCard(
                    day: widget.program.days[dayIndex],
                    content: widget.content,
                    scheduledDate: _schedule.dates[dayIndex],
                    rpe: _schedule.rpeByDayIndex[dayIndex],
                    today: widget.today,
                    onMarkDone: (int rpe) => _markDone(dayIndex, rpe),
                    onReschedule: () => _reschedule(dayIndex),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCard extends StatefulWidget {
  const _DayCard({
    required this.day,
    required this.content,
    required this.scheduledDate,
    required this.rpe,
    required this.today,
    required this.onMarkDone,
    required this.onReschedule,
  });

  final ProgramDay day;
  final ContentRepository content;
  final DateTime scheduledDate;

  /// `null` = gün henüz tamamlanmadı; dolu = RPE'siyle birlikte bitti.
  final int? rpe;
  final DateTime today;
  final Future<bool> Function(int) onMarkDone;
  final Future<bool> Function() onReschedule;

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  bool _pickingRpe = false;
  int _selectedRpe = 5;
  bool _saving = false;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get _isDone => widget.rpe != null;

  /// Tarihi geçmiş VE bitmemiş — "kaçırıldı" tam bunu ifade eder, saat
  /// farkı DEĞİL (gün-bazlı karşılaştırma, `_dateOnly`).
  bool get _isMissed =>
      !_isDone &&
      _dateOnly(widget.scheduledDate).isBefore(_dateOnly(widget.today));

  @override
  Widget build(BuildContext context) => GravitaCard(
    radius: 18,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          localized(
            context,
            'Day {day}',
            '{day}. gün',
            values: <String, Object>{'day': widget.day.dayNumber},
          ),
          style: GravitaType.display(
            context: context,
            size: 14.5,
            weight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          localized(
            context,
            'Scheduled: {date}',
            'Planlanan tarih: {date}',
            values: <String, Object>{'date': LocaleDate(widget.scheduledDate)},
          ),
          style: GravitaType.body(
            context: context,
            size: 12,
            color: GravitaColors.of(context).textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        for (final PrescribedExercise e in widget.day.exercises)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  // HAM id YOK — displayName katalogdan, bulunamazsa
                  // (yapısal olarak olmamalı, ama uydurma yerine
                  // dürüst düşer) id'nin kendisi yerine boş geçilmez.
                  catalogName(
                    context,
                    e.movementId,
                    widget.content.catalogue.byId(e.movementId)?.displayName ??
                        e.movementId,
                  ),
                  style: GravitaType.body(context: context, size: 13.5),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      e.isHold
                          ? localized(
                              context,
                              '{sets} × {seconds}s hold',
                              '{sets} × {seconds} sn tutuş',
                              values: <String, Object>{
                                'sets': e.sets,
                                'seconds': e.targetHoldSeconds!,
                              },
                            )
                          : localized(
                              context,
                              '{sets} × {reps}',
                              '{sets} × {reps}',
                              values: <String, Object>{
                                'sets': e.sets,
                                'reps': e.targetReps!,
                              },
                            ),
                      style: GravitaType.mono(
                        context: context,
                        size: 12,
                        color: GravitaColors.of(context).textSecondary,
                      ),
                    ),
                    GravitaPill(
                      label: motionPaidCameraLaunchEnabled && e.isLiveMeasured
                          ? localized(
                              context,
                              LibraryStrings.programLiveBadge,
                              'Canlı tekrar sayımı',
                            )
                          : localized(
                              context,
                              LibraryStrings.programManualLogBadge,
                              'Elle kayıt',
                            ),
                      tone: motionPaidCameraLaunchEnabled && e.isLiveMeasured
                          ? GravitaColors.of(context).accent
                          : GravitaColors.of(context).textSecondary,
                      filled: motionPaidCameraLaunchEnabled && e.isLiveMeasured,
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        _statusRow(),
      ],
    ),
  );

  Widget _statusRow() {
    if (_isDone) {
      return GravitaPill(
        label: localized(
          context,
          'Done · RPE {rpe}',
          'Tamamlandı · RPE {rpe}',
          values: <String, Object>{'rpe': widget.rpe!},
        ),
        tone: GravitaColors.of(context).textSecondary,
        filled: false,
      );
    }
    if (_isMissed && !_pickingRpe) {
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          GravitaPill(
            label: localized(
              context,
              LibraryStrings.programDayMissedLabel,
              'Kaçırıldı',
            ),
            tone: GravitaColors.of(context).textSecondary,
            filled: false,
          ),
          InkWell(
            key: ValueKey<String>(
              'workout.reschedule.${widget.day.weekNumber}.${widget.day.dayNumber}',
            ),
            onTap: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await widget.onReschedule();
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
            child: Container(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              alignment: AlignmentDirectional.centerStart,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Text(
                localized(
                  context,
                  LibraryStrings.programRescheduleAction,
                  'Yeniden planla',
                ),
                style: GravitaType.mono(
                  context: context,
                  size: 11,
                  color: GravitaColors.of(context).accent,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (!_pickingRpe) {
      return InkWell(
        key: ValueKey<String>(
          'workout.markDone.${widget.day.weekNumber}.${widget.day.dayNumber}',
        ),
        onTap: () => setState(() => _pickingRpe = true),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          alignment: AlignmentDirectional.centerStart,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            localized(
              context,
              LibraryStrings.programMarkDoneAction,
              'Tamamlandı olarak işaretle',
            ),
            style: GravitaType.mono(
              context: context,
              size: 11,
              color: GravitaColors.of(context).accent,
              weight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          localized(
            context,
            LibraryStrings.programRpeDialogBody,
            'Çabanı 1 (çok kolay) ile 10 (en yoğun) arasında değerlendir. '
            'Bu senin beyanındır; kamera bunu ölçmez.',
          ),
          style: GravitaType.body(
            context: context,
            size: 12.5,
            color: GravitaColors.of(context).textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (int rpe = 1; rpe <= 10; rpe++)
              ChoiceChip(
                label: Text(
                  formatLocaleNumber(
                    rpe,
                    Localizations.localeOf(context).toLanguageTag(),
                  ),
                ),
                selected: _selectedRpe == rpe,
                onSelected: _saving
                    ? null
                    : (bool sel) => setState(() => _selectedRpe = rpe),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: ValueKey<String>(
              'workout.saveRpe.${widget.day.weekNumber}.${widget.day.dayNumber}',
            ),
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      final saved = await widget.onMarkDone(_selectedRpe);
                      if (saved && mounted) setState(() => _pickingRpe = false);
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
            child: Text(
              localized(context, LibraryStrings.programRpeSaveButton, 'Kaydet'),
            ),
          ),
        ),
      ],
    );
  }
}
