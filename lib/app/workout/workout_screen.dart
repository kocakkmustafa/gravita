import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../content_repository.dart';
import '../library_strings.dart';
import '../program/program_builder.dart';
import '../program/program_model.dart';
import '../program/program_setup_screen.dart';
import '../program/program_store.dart';
import '../surface_widgets.dart';
import '../theme.dart';

/// Programın genel bakışı (GRA-P1-003 Step 1/2 UI'ı).
///
/// ## Kapsam BİLEREK DAR
///
/// Bu sürüm SEKİZ HAFTALIK planı OKUNUR biçimde gösterir — hangi hafta
/// hangi hareketleri, kaç set/tekrar ile önerir. TAŞIMADIĞI şeyler adıyla:
/// hangi günün "bugün" olduğu takibi, RPE toplama (Step 3), kaçırılan
/// seansı BURADAN yeniden sıralama EYLEMİ (Step 4'ün motoru `lib/app/
/// program/program_builder.dart`ta hazır — `rescheduleAfterMiss` — bu
/// ekran henüz ÇAĞIRMIYOR). Bunlar SIRADAKİ bir turun işi; roadmap'in
/// Step 1/2 (deterministik plan + set/rest/deload) burada TAM, Step 3/4'ün
/// UI YARISI değil.
class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({required this.content, super.key});

  static const Key emptyKey = Key('workout.empty');
  static const Key disclaimerKey = Key('workout.disclaimer');

  final ContentRepository content;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  late final Future<
      ({
        ProgramInputs? inputs,
        WorkoutProgram? program,
      })> _future = _load();

  Future<({ProgramInputs? inputs, WorkoutProgram? program})> _load() async {
    // ⚠️ TÜMÜ try/catch İÇİNDE — `ProgramStore.open()`ın KENDİSİ (platform
    // kanalı, `getApplicationSupportDirectory()`) fırlatabilir ve bu,
    // `ProgramStore.read()`in kendi fail-open try/catch'inin DIŞINDA kalır.
    // Yakalanmazsa bu Future HATA ile tamamlanır, `FutureBuilder`ın
    // `snapshot.data`si yine `null` olur ve aşağıki `data == null` dalı
    // "yükleniyor" ile "arızalandı"yı AYIRT EDEMEZ — sonsuz yükleyici (ölçüldü:
    // `test/reachability_test.dart`ta sahte path-provider'sız ortamda
    // `ProgramSetupScreen` bu yüzden ULAŞILAMAZ çıktı). Panzehir
    // `OnboardingStore`un AYNI kuralı: depolama/asset arızası kullanıcıyı
    // kilitlemez, yalnız "henüz kurulmamış" durumuna düşürür.
    try {
      final ProgramInputs? inputs = await (await ProgramStore.open()).read();
      if (inputs == null) return (inputs: null, program: null);
      final ProgramConfig config =
          await ContentRepository.loadProgramConfig(rootBundle);
      final List<ProgramCatalogEntry> entries =
          await widget.content.programCatalogEntries();
      final WorkoutProgram program =
          ProgramBuilder(config: config, catalog: entries).build(inputs);
      return (inputs: inputs, program: program);
    } on Object {
      return (inputs: null, program: null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text(LibraryStrings.programOverviewTitle)),
        body: FutureBuilder<({ProgramInputs? inputs, WorkoutProgram? program})>(
          future: _future,
          builder: (BuildContext context,
              AsyncSnapshot<({ProgramInputs? inputs, WorkoutProgram? program})>
                  snap) {
            final ({ProgramInputs? inputs, WorkoutProgram? program})? data =
                snap.data;
            if (data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (data.program == null) {
              return Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    NoteCard(
                      key: WorkoutScreen.emptyKey,
                      icon: Icons.calendar_month_outlined,
                      text: LibraryStrings.programNoInputs,
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
                          builder: (_) =>
                              ProgramSetupScreen(content: widget.content),
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
                          LibraryStrings.programNoInputsAction,
                          textAlign: TextAlign.center,
                          style: GravitaType.body(
                              size: 15,
                              weight: FontWeight.w600,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return _ProgramOverview(
                content: widget.content, program: data.program!);
          },
        ),
      );
}

class _ProgramOverview extends StatelessWidget {
  const _ProgramOverview({required this.content, required this.program});

  final ContentRepository content;
  final WorkoutProgram program;

  @override
  Widget build(BuildContext context) {
    // Haftaya göre grupla — [WorkoutProgram.days] DÜZ sıralı bir listedir.
    final Map<int, List<ProgramDay>> byWeek = <int, List<ProgramDay>>{};
    for (final ProgramDay d in program.days) {
      (byWeek[d.weekNumber] ??= <ProgramDay>[]).add(d);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 48),
      children: <Widget>[
        NoteCard(
          key: WorkoutScreen.disclaimerKey,
          sealed: true,
          icon: Icons.info_outline,
          text: LibraryStrings.programOverviewDisclaimer,
        ),
        const SizedBox(height: 24),
        for (final int week in byWeek.keys.toList()..sort())
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: SurfaceSection(
              title: LibraryStrings
                  .programWeekLabel(week, byWeek[week]!.first.isDeload)
                  .toUpperCase(),
              children: <Widget>[
                for (final ProgramDay d in byWeek[week]!) _DayCard(day: d, content: content),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.content});

  final ProgramDay day;
  final ContentRepository content;

  @override
  Widget build(BuildContext context) => GravitaCard(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(LibraryStrings.programDayLabel(day.dayNumber),
                style: GravitaType.display(size: 14.5, weight: FontWeight.w500)),
            const SizedBox(height: 10),
            for (final PrescribedExercise e in day.exercises)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        // HAM id YOK — displayName katalogdan, bulunamazsa
                        // (yapısal olarak olmamalı, ama uydurma yerine
                        // dürüst düşer) id'nin kendisi yerine boş geçilmez.
                        content.catalogue.byId(e.movementId)?.displayName ??
                            e.movementId,
                        style: GravitaType.body(size: 13.5),
                      ),
                    ),
                    Text(
                      e.isHold
                          ? LibraryStrings.programSetsHold(
                              e.sets, e.targetHoldSeconds!)
                          : LibraryStrings.programSetsReps(
                              e.sets, e.targetReps!),
                      style: GravitaType.mono(
                          size: 12, color: GravitaColors.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    GravitaPill(
                      label: e.isLiveMeasured
                          ? LibraryStrings.programLiveBadge
                          : LibraryStrings.programManualLogBadge,
                      tone: e.isLiveMeasured
                          ? GravitaColors.accent
                          : GravitaColors.textSecondary,
                      filled: e.isLiveMeasured,
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}
