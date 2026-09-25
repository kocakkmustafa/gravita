import 'package:flutter/material.dart';

import '../content_repository.dart';
import '../app_locale.dart';
import '../library_model.dart';
import '../library_strings.dart';
import '../theme.dart';
import '../workout/workout_screen.dart';
import 'program_model.dart';
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

  /// ⚠️ Yazma denemesi try/catch İÇİNDE — `onboarding_screen.dart`ın
  /// `_completeOnboarding`iyle AYNI gerekçe: depolama arızası (platform
  /// kanalı ya da disk) kullanıcıyı burada KİLİTLEMEZ. Hata yutulsa bile
  /// yine `WorkoutScreen`e geçilir — [ProgramStore.read] dosya yoksa `null`
  /// döner, o ekran KENDİ boş-durumuna (yeniden kurulum CTA'sı) düşer;
  /// "arızalı depoda bit yazılmaz, sonraki açılış tekrar sorar" ile AYNI
  /// dürüst sonuç, sessiz sahte-başarı DEĞİL.
  Future<void> _build() async {
    setState(() => _saving = true);
    final ProgramInputs inputs = ProgramInputs(
      availableEquipment: Set<String>.of(_equipment),
      daysPerWeek: _daysPerWeek,
      experience: _experience,
    );
    try {
      await (await ProgramStore.open(
        accountUserId: widget.accountUserId,
      )).write(inputs);
    } on Object {
      // Aşağıdaki geçiş yine de olur — WorkoutScreen kendi boş-durumuna düşer.
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
              LibraryStrings.programSetupIntro,
              'Birkaç yanıt sekiz haftalık planını belirler. Yanıtlarını '
              'değiştirip planı istediğin zaman yeniden oluşturabilirsin.',
            ),
            style: GravitaType.body(
              size: 13.5,
              color: GravitaColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            localized(
              context,
              LibraryStrings.programExperienceLabel.toUpperCase(),
              'DENEYİM',
            ),
            style: GravitaType.mono(
              size: 11,
              color: GravitaColors.textSecondary,
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
                  onChanged: (ExperienceLevel? v) =>
                      setState(() => _experience = v ?? _experience),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            localized(
              context,
              LibraryStrings.programEquipmentLabel.toUpperCase(),
              'EKİPMANLARIN — YALNIZ VÜCUT AĞIRLIĞI İÇİN HEPSİNİ BOŞ BIRAK',
            ),
            style: GravitaType.mono(
              size: 11,
              color: GravitaColors.textSecondary,
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
                  onSelected: (bool sel) => setState(() {
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
            localized(
              context,
              LibraryStrings.programDaysPerWeekLabel.toUpperCase(),
              'HAFTALIK GÜN SAYISI',
            ),
            style: GravitaType.mono(
              size: 11,
              color: GravitaColors.textSecondary,
              weight: FontWeight.w600,
              letterSpacingEm: 0.12,
            ),
          ),
          Row(
            key: ProgramSetupScreen.daysPerWeekKey,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _daysPerWeek > 2
                    ? () => setState(() => _daysPerWeek--)
                    : null,
              ),
              Text(
                '$_daysPerWeek',
                style: GravitaType.display(size: 20, weight: FontWeight.w500),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _daysPerWeek < 6
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
                backgroundColor: GravitaColors.accent,
                foregroundColor: Colors.white,
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
