import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'library_model.dart';
import 'library_strings.dart';

/// Device-language foundation. Untranslated content stays in English until
/// its own reviewed translation is supplied.
const List<Locale> appSupportedLocales = <Locale>[Locale('en'), Locale('tr')];

const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];

String localized(BuildContext context, String english, String turkish) =>
    Localizations.localeOf(context).languageCode == 'tr' ? turkish : english;

/// Display-only labels: capability and movement IDs remain unchanged.
const Map<String, String> _turkishCatalogNames = <String, String>{
  'bodyweight_squat': 'Vücut ağırlığıyla squat',
  'push_up': 'Şınav',
  'farmer_carry': 'Çiftçi yürüyüşü',
  'bird_dog': 'Bird dog',
  'dead_bug': 'Dead bug',
  'hanging_leg_raise': 'Asılı bacak kaldırma',
  'hollow_hold': 'Hollow tutuşu',
  'mountain_climber': 'Dağ tırmanışı',
  'plank': 'Plank',
  'side_plank': 'Yan plank',
  'superman_hold': 'Superman tutuşu',
  'toes_to_bar': 'Bara ayak kaldırma',
  'floor_press': 'Yerde press',
  'kb_swing': 'Kettlebell swing',
  'romanian_deadlift': 'Rumen deadlift',
  'glute_bridge': 'Kalça köprüsü',
  'goblet_squat': 'Goblet squat',
  'lunge': 'Lunge',
  'calf_raise': 'Ayakta baldır kaldırma',
  'step_up': 'Basamağa çıkış',
  'wall_sit': 'Duvar oturuşu',
  'burpee': 'Burpee',
  'db_curl': 'Dambıl curl',
  'db_row': 'Dambıl row',
  'inverted_row': 'Ters row',
  'pull_up': 'Barfiks',
  'dip': 'Dip',
  'db_shoulder_press': 'Dambıl omuz press',
  'lateral_raise': 'Yana açış',
  'wall_handstand': 'Duvara dönük amut',
  'tuck_planche': 'Tuck planche',
  'leg_foundations': 'Squat temelleri',
  'push_foundations': 'Şınav temelleri',
};

String catalogName(BuildContext context, String id, String english) =>
    Localizations.localeOf(context).languageCode == 'tr'
    ? _turkishCatalogNames[id] ?? english
    : english;

String familyDisplayName(BuildContext context, String family, String english) =>
    Localizations.localeOf(context).languageCode == 'tr'
        ? family == 'dbkb'
            ? 'Dambıl ve kettlebell'
            : _turkishFamilies[family] ?? english
        : english;

const Map<String, String> _turkishFamilies = <String, String>{
  'carry': 'Taşıma',
  'core': 'Gövde',
  'dbkb': 'Ağırlık',
  'legs': 'Bacak',
  'plyo': 'Pliometrik',
  'pull': 'Çekiş',
  'push': 'İtiş',
  'shoulders': 'Omuz',
  'skill': 'Beceri',
};

const Map<String, String> _turkishLevels = <String, String>{
  'beginner': 'Başlangıç',
  'intermediate': 'Orta',
  'advanced': 'İleri',
  'elite': 'Elit',
};

const Map<String, String> _turkishEquipment = <String, String>{
  'box': 'Yükselti',
  'dumbbells': 'Dambıl',
  'kettlebell': 'Kettlebell',
  'low_bar': 'Alçak bar',
  'parallel_bars': 'Paralel bar',
  'pull_up_bar': 'Barfiks barı',
};

String movementMetaLine(BuildContext context, MovementEntry movement) {
  if (Localizations.localeOf(context).languageCode != 'tr') {
    return LibraryStrings.metaLine(movement);
  }
  return <String>[
    _turkishFamilies[movement.family] ??
        LibraryCatalogue.labelFor(movement.family),
    if (movement.level != null)
      _turkishLevels[movement.level] ?? movement.level!,
    if (movement.equipment.isEmpty)
      'Ekipmansız'
    else
      movement.equipment
          .map((String item) => _turkishEquipment[item] ?? item)
          .join(' · '),
  ].join(' · ');
}

String equipmentDisplayName(BuildContext context, String equipment) =>
    Localizations.localeOf(context).languageCode == 'tr'
    ? _turkishEquipment[equipment] ?? equipment.replaceAll('_', ' ')
    : equipment.replaceAll('_', ' ');

String movementClassBadge(BuildContext context, String badge) {
  if (Localizations.localeOf(context).languageCode != 'tr') {
    return badge.toUpperCase();
  }
  return switch (badge) {
    'Form coaching' => 'FORM SINIFI',
    'Form coaching · equipment not tracked' =>
      'FORM SINIFI · EKİPMAN TAKİP EDİLMEZ',
    'Reps & tempo' => 'TEKRAR VE TEMPO',
    _ => badge.toUpperCase(),
  };
}

String movementClassExplanation(BuildContext context, String? movementClass) {
  if (Localizations.localeOf(context).languageCode != 'tr') {
    return LibraryStrings.classBadgeExplainer(movementClass);
  }
  return switch (movementClass) {
    null => '',
    'B' =>
      'Sınıf B — kamera harekete doğrultulur; tekrar ve süre sayılır, '
          'hareket biçimi değerlendirilmez.',
    'D' =>
      'Sınıf D — ölçümler bedeninle ilgilidir; ekipmanın kendisi '
          'algılanmaz.',
    'A' => 'Sınıf A — kameranın ihtiyaç duyduğu her şey yandan görünür.',
    _ => LibraryStrings.classBadgeExplainer(movementClass),
  };
}

String movementTrendSummary(
  BuildContext context,
  int sessions,
  int units,
  String unitLabel,
) {
  if (Localizations.localeOf(context).languageCode != 'tr') {
    return LibraryStrings.trendSummary(sessions, units, unitLabel);
  }
  final String unit = switch (unitLabel) {
    'rep' => 'tekrar',
    'second' => 'saniye',
    _ => unitLabel,
  };
  return '$sessions oturum · $units $unit';
}
