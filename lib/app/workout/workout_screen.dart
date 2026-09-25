import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../app_locale.dart';
import '../content_repository.dart';
import '../library_strings.dart';
import '../program/program_builder.dart';
import '../program/program_model.dart';
import '../program/program_schedule_store.dart';
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
  const WorkoutScreen({required this.content, this.accountUserId, super.key});

  static const Key emptyKey = Key('workout.empty');
  static const Key disclaimerKey = Key('workout.disclaimer');

  final ContentRepository content;
  final String? accountUserId;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

typedef _Loaded = ({
  ProgramInputs? inputs,
  WorkoutProgram? program,
  ProgramSchedule? schedule,
  DateTime today,
});

class _WorkoutScreenState extends State<WorkoutScreen> {
  late final Future<_Loaded> _future = _load();

  Future<_Loaded> _load() async {
    // ⚠️ `DateTime.now()` YALNIZ BURADA, imperative kablo katmanında —
    // `program_builder.dart`nın kendi disiplini: saf mantık gerçek-zamanı
    // hiç bilmez, çağıran taraf TEK bir "şimdi" yakalayıp aşağı taşır.
    final DateTime now = DateTime.now();
    try {
      final ProgramInputs? inputs = await (await ProgramStore.open(
        accountUserId: widget.accountUserId,
      )).read();
      if (inputs == null) {
        return (inputs: null, program: null, schedule: null, today: now);
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

      final ProgramScheduleStore scheduleStore =
          await ProgramScheduleStore.open(accountUserId: widget.accountUserId);
      ProgramSchedule? schedule = await scheduleStore.read();
      // Takvim yok YA DA program yeniden üretilince gün sayısı artık
      // uyuşmuyor (ör. kullanıcı `daysPerWeek`i değiştirdi) — İKİ durumda da
      // eski indeksler artık FARKLI günlere karşılık gelir, bu yüzden takvim
      // + tamamlanma durumu BİLEREK sıfırdan kurulur (sessiz yanlış-eşleme
      // yerine dürüst bir sıfırlama).
      if (schedule == null || schedule.dates.length != program.days.length) {
        schedule = ProgramSchedule(
          dates: scheduleProgram(
            program: program,
            startDate: now,
            daysPerWeek: inputs.daysPerWeek,
          ),
          rpeByDayIndex: const <int, int>{},
        );
        await scheduleStore.write(schedule);
      }
      return (inputs: inputs, program: program, schedule: schedule, today: now);
    } on Object {
      return (inputs: null, program: null, schedule: null, today: now);
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
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (data.program == null || data.schedule == null) {
          return Padding(
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
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => ProgramSetupScreen(
                        content: widget.content,
                        accountUserId: widget.accountUserId,
                      ),
                    ),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: GravitaColors.accent,
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
                        size: 15,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return _ProgramOverview(
          content: widget.content,
          program: data.program!,
          initialSchedule: data.schedule!,
          today: data.today,
          daysPerWeek: data.inputs!.daysPerWeek,
          accountUserId: widget.accountUserId,
        );
      },
    ),
  );
}

/// Takvimi KENDİ yerel durumu olarak taşır — `WorkoutScreen`in `_future`ı
/// yalnız İLK yüklemeyi sürer; sonraki "mark done"/"reschedule" etkileşimleri
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
  });

  final ContentRepository content;
  final WorkoutProgram program;
  final ProgramSchedule initialSchedule;
  final DateTime today;
  final int daysPerWeek;
  final String? accountUserId;

  @override
  State<_ProgramOverview> createState() => _ProgramOverviewState();
}

class _ProgramOverviewState extends State<_ProgramOverview> {
  late ProgramSchedule _schedule = widget.initialSchedule;

  Future<void> _markDone(int dayIndex, int rpe) async {
    final ProgramSchedule updated = _schedule.withRpe(dayIndex, rpe);
    await (await ProgramScheduleStore.open(
      accountUserId: widget.accountUserId,
    )).write(updated);
    if (!mounted) return;
    setState(() => _schedule = updated);
  }

  Future<void> _reschedule(int dayIndex) async {
    final int gapDays = scheduleGapDays(widget.daysPerWeek);
    final List<DateTime> updatedDates = rescheduleAfterMiss(
      schedule: _schedule.dates,
      missedIndex: dayIndex,
      slotSpacing: Duration(days: gapDays),
    );
    final ProgramSchedule updated = _schedule.withDates(updatedDates);
    await (await ProgramScheduleStore.open(
      accountUserId: widget.accountUserId,
    )).write(updated);
    if (!mounted) return;
    setState(() => _schedule = updated);
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
              title: localized(
                context,
                LibraryStrings.programWeekLabel(
                  week,
                  widget.program.days[byWeek[week]!.first].isDeload,
                ).toUpperCase(),
                widget.program.days[byWeek[week]!.first].isDeload
                    ? '$week. HAFTA — HAFİFLETME'
                    : '$week. HAFTA',
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
  final ValueChanged<int> onMarkDone;
  final VoidCallback onReschedule;

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  bool _pickingRpe = false;
  int _selectedRpe = 5;

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
            LibraryStrings.programDayLabel(widget.day.dayNumber),
            '${widget.day.dayNumber}. gün',
          ),
          style: GravitaType.display(size: 14.5, weight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        for (final PrescribedExercise e in widget.day.exercises)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    // HAM id YOK — displayName katalogdan, bulunamazsa
                    // (yapısal olarak olmamalı, ama uydurma yerine
                    // dürüst düşer) id'nin kendisi yerine boş geçilmez.
                    catalogName(
                      context,
                      e.movementId,
                      widget.content.catalogue
                              .byId(e.movementId)
                              ?.displayName ??
                          e.movementId,
                    ),
                    style: GravitaType.body(size: 13.5),
                  ),
                ),
                Text(
                  e.isHold
                      ? localized(
                          context,
                          LibraryStrings.programSetsHold(
                            e.sets,
                            e.targetHoldSeconds!,
                          ),
                          '${e.sets} × ${e.targetHoldSeconds} sn tutuş',
                        )
                      : LibraryStrings.programSetsReps(e.sets, e.targetReps!),
                  style: GravitaType.mono(
                    size: 12,
                    color: GravitaColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                GravitaPill(
                  label: e.isLiveMeasured
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
                  tone: e.isLiveMeasured
                      ? GravitaColors.accent
                      : GravitaColors.textSecondary,
                  filled: e.isLiveMeasured,
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
          LibraryStrings.programDayDoneLabel(widget.rpe!),
          'Tamamlandı · RPE ${widget.rpe}',
        ),
        tone: GravitaColors.textSecondary,
        filled: false,
      );
    }
    if (_isMissed) {
      return Row(
        children: <Widget>[
          GravitaPill(
            label: localized(
              context,
              LibraryStrings.programDayMissedLabel,
              'Kaçırıldı',
            ),
            tone: GravitaColors.textSecondary,
            filled: false,
          ),
          const Spacer(),
          InkWell(
            key: ValueKey<String>(
              'workout.reschedule.${widget.day.weekNumber}.${widget.day.dayNumber}',
            ),
            onTap: widget.onReschedule,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Text(
                localized(
                  context,
                  LibraryStrings.programRescheduleAction,
                  'Yeniden planla',
                ),
                style: GravitaType.mono(
                  size: 11,
                  color: GravitaColors.accent,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Text(
            localized(
              context,
              LibraryStrings.programMarkDoneAction,
              'Tamamlandı olarak işaretle',
            ),
            style: GravitaType.mono(
              size: 11,
              color: GravitaColors.accent,
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
            size: 12.5,
            color: GravitaColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (int rpe = 1; rpe <= 10; rpe++)
              ChoiceChip(
                label: Text('$rpe'),
                selected: _selectedRpe == rpe,
                onSelected: (bool sel) => setState(() => _selectedRpe = rpe),
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
            onPressed: () {
              widget.onMarkDone(_selectedRpe);
              setState(() => _pickingRpe = false);
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
