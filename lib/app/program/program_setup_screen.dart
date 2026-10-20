import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../content_repository.dart';
import '../app_locale.dart';
import '../library_model.dart';
import '../library_strings.dart';
import '../theme.dart';
import '../workout/workout_screen.dart';
import 'program_model.dart';
import 'program_builder.dart';
import 'program_schedule_store.dart';
import 'program_signature.dart';
import 'program_store.dart';

/// Programın TEK girdi toplama yüzeyi (GRA-P1-003).
///
/// ## Neden yalnız ÜÇ soru — G-127'nin AYNI kuralı
///
/// `onboarding_strings.dart`ın O3 (Profile) adımını BİLEREK atlama gerekçesi
/// ("yaş/boy/kilo/hedef-beceri/ağrı alanlarını OKUYAN hiçbir kod yok, toplamak
/// 'beyan var okuyanı yok'un veri-toplama sınıfı olur") burada TERSİNE
/// işliyor: [ProgramBuilder] YALNIZ [ProgramInputs]'un üç alanını okur
/// (deneyim, ekipman, haftalık gün) — bu ekran TAM O ÜÇÜNÜ toplar, ne
/// eksik ne fazla. Yaş/boy/kilo/hedef-beceri hâlâ HİÇBİR ürün kodunda
/// okunmuyor; buraya da EKLENMEDİ.
class ProgramSetupScreen extends StatefulWidget {
  const ProgramSetupScreen({
    required this.content,
    this.accountUserId,
    super.key,
  });

  static const Key experienceKey = Key('programSetup.experience');
  static const Key equipmentKey = Key('programSetup.equipment');
  static const Key daysPerWeekKey = Key('programSetup.daysPerWeek');
  static const Key buildButtonKey = Key('programSetup.build');

  final ContentRepository content;
  final String? accountUserId;

  @override
  State<ProgramSetupScreen> createState() => _ProgramSetupScreenState();
}

class _ProgramSetupScreenState extends State<ProgramSetupScreen> {
  ExperienceLevel _experience = ExperienceLevel.beginner;
  final Set<String> _equipment = <String>{};
  int _daysPerWeek = 3;
  bool _saving = false;

  /// Ekipman listesi HARDCODE değil, katalogdan TÜRETİLİR — yeni bir
  /// hareket yeni bir ekipman türü getirdiğinde bu ekran KENDİLİĞİNDEN
  /// güncellenir (`familyOrder`ı kütüphaneden ALAN aynı disiplin).
  Set<String> _allEquipment() => <String>{
    for (final MovementEntry m in widget.content.catalogue.movements)
      ...m.equipment,
  };

  /// New schedules are created once. Existing/partial/legacy files cannot be
  /// replaced here: the app does not have an accepted history migration yet.
  Future<void> _build() async {
    if (_saving) return;
    setState(() => _saving = true);
    final ProgramInputs inputs = ProgramInputs(
      availableEquipment: Set<String>.of(_equipment),
      daysPerWeek: _daysPerWeek,
      experience: _experience,
    );
    try {
      final inputStore = await ProgramStore.open(
        accountUserId: widget.accountUserId,
      );
      final scheduleStore = await ProgramScheduleStore.open(
        accountUserId: widget.accountUserId,
      );
      final savedInputs = await inputStore.read();
      final savedSchedule = await scheduleStore.read();
      final config = await ContentRepository.loadProgramConfig(rootBundle);
      final entries = await widget.content.programCatalogEntries();
      final builder = ProgramBuilder(config: config, catalog: entries);
      final program = builder.build(inputs);
      final signature = programSignature(inputs, program);
      if (savedInputs != null || savedSchedule != null) {
        if (savedInputs == null ||
            savedSchedule == null ||
            savedSchedule.programSignature != signature ||
            savedSchedule.dates.length != program.days.length ||
            programSignature(savedInputs, builder.build(savedInputs)) !=
                signature) {
          throw StateError(
            'Keep existing program files; replacement is not supported',
          );
        }
        // Identical existing plan: navigate without writing dates, inputs or RPE.
      } else {
        final created = await scheduleStore.createIfMissing(
          () => ProgramSchedule(
            dates: scheduleProgram(
              program: program,
              startDate: DateTime.now(),
              daysPerWeek: inputs.daysPerWeek,
            ),
            rpeByDayIndex: const <int, int>{},
            programSignature: signature,
          ),
        );
        if (created.programSignature != signature) {
          throw StateError('Another saved program must not be replaced');
        }
        await inputStore.write(inputs);
      }
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localized(
              context,
              'The program could not be saved. Existing dates and progress were '
                  'kept; a saved program cannot be replaced here.',
              'Program kaydedilemedi. Mevcut tarihler ve ilerleme korundu; '
                  'kayıtlı program bu ekranda değiştirilemez.',
            ),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutScreen(
          content: widget.content,
          accountUserId: widget.accountUserId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> equipmentOptions = _allEquipment().toList()..sort();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          localized(
            context,
            LibraryStrings.programSetupTitle,
            'Programını oluştur',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 48),
        children: <Widget>[
          Text(
            localized(
              context,
              'A few choices create your eight-week plan. Existing saved '
                  'programs and their progress are kept unchanged.',
              'Birkaç yanıt sekiz haftalık planını belirler. Kayıtlı '
                  'programlar ve ilerlemeleri değiştirilmeden korunur.',
            ),
            style: GravitaType.body(
              context: context,
              size: 13.5,
              color: GravitaColors.of(context).textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            localizedUpper(
              context,
              LibraryStrings.programExperienceLabel,
              'DENEYİM',
            ),
            style: GravitaType.mono(
              context: context,
              size: 11,
              color: GravitaColors.of(context).textSecondary,
              weight: FontWeight.w600,
              letterSpacingEm: 0.12,
            ),
          ),
          const SizedBox(height: 10),
          Column(
            key: ProgramSetupScreen.experienceKey,
            children: <Widget>[
              for (final ExperienceLevel level in ExperienceLevel.values)
                RadioListTile<ExperienceLevel>(
                  contentPadding: EdgeInsets.zero,
                  title: Text(switch (level) {
                    ExperienceLevel.beginner => localized(
                      context,
                      LibraryStrings.programExperienceBeginner,
                      'Başlangıç',
                    ),
                    ExperienceLevel.intermediate => localized(
                      context,
                      LibraryStrings.programExperienceIntermediate,
                      'Orta',
                    ),
                  }),
                  value: level,
                  // ignore: deprecated_member_use
                  groupValue: _experience,
                  // ignore: deprecated_member_use
                  onChanged: _saving
                      ? null
                      : (ExperienceLevel? v) =>
                            setState(() => _experience = v ?? _experience),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            localizedUpper(
              context,
              LibraryStrings.programEquipmentLabel,
              'EKİPMANLARIN — YALNIZ VÜCUT AĞIRLIĞI İÇİN HEPSİNİ BOŞ BIRAK',
            ),
            style: GravitaType.mono(
              context: context,
              size: 11,
              color: GravitaColors.of(context).textSecondary,
              weight: FontWeight.w600,
              letterSpacingEm: 0.12,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            key: ProgramSetupScreen.equipmentKey,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String eq in equipmentOptions)
                FilterChip(
                  label: Text(equipmentDisplayName(context, eq)),
                  selected: _equipment.contains(eq),
                  onSelected: _saving
                      ? null
                      : (bool sel) => setState(() {
                          if (sel) {
                            _equipment.add(eq);
                          } else {
                            _equipment.remove(eq);
                          }
                        }),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            localizedUpper(
              context,
              LibraryStrings.programDaysPerWeekLabel,
              'HAFTALIK GÜN SAYISI',
            ),
            style: GravitaType.mono(
              context: context,
              size: 11,
              color: GravitaColors.of(context).textSecondary,
              weight: FontWeight.w600,
              letterSpacingEm: 0.12,
            ),
          ),
          Row(
            key: ProgramSetupScreen.daysPerWeekKey,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: localized(
                  context,
                  'Fewer days per week',
                  'Haftalık gün sayısını azalt',
                ),
                onPressed: !_saving && _daysPerWeek > 2
                    ? () => setState(() => _daysPerWeek--)
                    : null,
              ),
              Text(
                formatLocaleNumber(
                  _daysPerWeek,
                  Localizations.localeOf(context).toLanguageTag(),
                ),
                style: GravitaType.display(
                  context: context,
                  size: 20,
                  weight: FontWeight.w500,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: localized(
                  context,
                  'More days per week',
                  'Haftalık gün sayısını artır',
                ),
                onPressed: !_saving && _daysPerWeek < 6
                    ? () => setState(() => _daysPerWeek++)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: ProgramSetupScreen.buildButtonKey,
              onPressed: _saving ? null : _build,
              style: FilledButton.styleFrom(
                backgroundColor: GravitaColors.of(context).accent,
                foregroundColor: GravitaColors.of(context).onAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                localized(
                  context,
                  LibraryStrings.programBuildButton,
                  'Programımı oluştur',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
