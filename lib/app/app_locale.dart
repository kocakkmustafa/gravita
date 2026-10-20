import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:motion_account/motion_account.dart'
    show MotionAccountLocalizations;

import 'library_model.dart';
import 'library_strings.dart';
import 'localization/locale_catalog.dart';
import 'localization/locale_delegate.dart';

export 'localization/locale_catalog.dart';

/// Device-language foundation. Untranslated content stays in English until
/// its own reviewed translation is supplied.
const List<Locale> appSupportedLocales = <Locale>[
  Locale('en'),
  Locale('tr'),
  Locale('es', '419'),
  Locale('pt', 'BR'),
  Locale('de'),
  Locale('fr'),
  Locale('ja'),
  Locale('ar'),
  Locale('it'),
  Locale('ko'),
  Locale('id'),
  Locale('pl'),
  Locale('hi'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
];

Locale localeForAppTag(String tag) {
  final canonical = canonicalLocaleTag(tag);
  return appSupportedLocales.firstWhere(
    (locale) => locale.toLanguageTag() == canonical,
  );
}

/// Exact reviewed aliases, followed by the user's next supported preference.
/// Flutter's generic language-only match would map zh-Hant to zh-Hans.
Locale resolveAppLocales(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final locale in preferred ?? const <Locale>[]) {
    final tag = supportedLocaleAlias(locale.toLanguageTag());
    if (tag == null) continue;
    for (final candidate in supported) {
      if (candidate.toLanguageTag() == tag) return candidate;
    }
  }
  return supported.firstWhere(
    (locale) => locale.toLanguageTag() == 'en',
    orElse: () => supported.first,
  );
}

const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
      GravitaLocalizationsDelegate(),
      MotionAccountLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];

String localized(
  BuildContext context,
  String english,
  String turkish, {
  Map<String, Object> values = const <String, Object>{},
}) => resolveLocalized(
  Localizations.localeOf(context).toLanguageTag(),
  english,
  turkish: turkish,
  values: values,
);

/// Resolve the source before applying display casing. Turkish dotted and
/// dotless i need explicit handling; Dart's default uppercasing is neutral.
String localizedUpper(
  BuildContext context,
  String english,
  String turkish, {
  Map<String, Object> values = const <String, Object>{},
}) {
  final text = localized(context, english, turkish, values: values);
  final tag = canonicalLocaleTag(
    Localizations.localeOf(context).toLanguageTag(),
  );
  return (tag == 'tr' ? text.replaceAll('i', 'İ').replaceAll('ı', 'I') : text)
      .toUpperCase();
}

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
    localized(context, english, _turkishCatalogNames[id] ?? english);

String familyDisplayName(BuildContext context, String family, String english) =>
    localized(
      context,
      english,
      family == 'dbkb'
          ? 'Dambıl ve kettlebell'
          : _turkishFamilies[family] ?? english,
    );

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
  if (canonicalLocaleTag(Localizations.localeOf(context).toLanguageTag()) ==
      'en') {
    return LibraryStrings.metaLine(movement);
  }
  return <String>[
    familyDisplayName(
      context,
      movement.family,
      LibraryCatalogue.labelFor(movement.family),
    ),
    if (movement.level != null)
      localized(
        context,
        LibraryCatalogue.labelFor(movement.level!),
        _turkishLevels[movement.level] ?? movement.level!,
      ),
    if (movement.equipment.isEmpty)
      localized(context, 'No equipment', 'Ekipmansız')
    else
      movement.equipment
          .map(
            (String item) => localized(
              context,
              LibraryStrings.equipmentLine(<String>[item]),
              _turkishEquipment[item] ?? item,
            ),
          )
          .join(' · '),
  ].join(' · ');
}

String equipmentDisplayName(BuildContext context, String equipment) =>
    localized(
      context,
      equipment.replaceAll('_', ' '),
      _turkishEquipment[equipment] ?? equipment.replaceAll('_', ' '),
    );

String movementClassBadge(BuildContext context, String badge) {
  final turkish = switch (badge) {
    'Form coaching' => 'FORM SINIFI',
    'Form coaching · equipment not tracked' =>
      'FORM SINIFI · EKİPMAN TAKİP EDİLMEZ',
    'Reps & tempo' => 'TEKRAR VE TEMPO',
    _ => badge.toUpperCase(),
  };
  return localizedUpper(context, badge, turkish);
}

String movementClassExplanation(BuildContext context, String? movementClass) {
  final english = LibraryStrings.classBadgeExplainer(movementClass);
  final turkish = switch (movementClass) {
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
  return english.isEmpty ? english : localized(context, english, turkish);
}

String movementTrendSummary(
  BuildContext context,
  int sessions,
  int units,
  String unitLabel,
) {
  final sessionsText = localized(
    context,
    sessions == 1 ? '{count} session' : '{count} sessions',
    '{count} oturum',
    values: <String, Object>{'count': sessions},
  );
  final (source, turkish) = switch (unitLabel) {
    'rep' => (units == 1 ? '{count} rep' : '{count} reps', '{count} tekrar'),
    'second' => (
      units == 1 ? '{count} second' : '{count} seconds',
      '{count} saniye',
    ),
    _ => ('{count} {unit}', '{count} {unit}'),
  };
  final unitsText = localized(
    context,
    source,
    turkish,
    values: <String, Object>{
      'count': units,
      if (unitLabel != 'rep' && unitLabel != 'second') 'unit': unitLabel,
    },
  );
  return '$sessionsText · $unitsText';
}

/// The name and pack ID must both match; unknown/revised sources stay visible.
String skillTreeName(BuildContext context, SkillTree tree) =>
    switch ((tree.packId, tree.displayName)) {
      ('gravita.handstand', 'Handstand') => localized(
        context,
        tree.displayName,
        'Amut',
      ),
      ('gravita.planche', 'Planche') => localized(
        context,
        tree.displayName,
        'Planche',
      ),
      _ => tree.displayName,
    };

String draftedTreeNames(BuildContext context, SkillTreeIndex index) => index
    .drafted
    .map((tree) => skillTreeName(context, tree))
    .join(localized(context, ' and ', ' ve '));
