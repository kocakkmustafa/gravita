import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:intl/date_symbol_data_local.dart';
import 'package:motion_content/motion_content.dart' show computeSha256Hex;

import 'package:gravita/app/localization/locale_catalog.dart';
import 'package:gravita/app/library_model.dart';

// Run from the app root after all fourteen locale resources are frozen.
// This checks actual asset/reader/lookup contracts. It does not assess human
// translation meaning, physical teaching, fonts, layout or native rendering.
// The public motion_content hashing API is pure Dart. LibraryStrings depends
// on the shared Flutter account policy, so its producers need widget tests.
const _expectedTags = <String>{
  'en',
  'tr',
  'es-419',
  'pt-BR',
  'de',
  'fr',
  'ja',
  'ar',
  'it',
  'ko',
  'id',
  'pl',
  'hi',
  'zh-Hans',
};
const _courseFiles = <String>[
  'content/courses/calisthenics.v1.json',
  'content/courses/barbell-foundations.v1.json',
  'content/courses/rings-foundations.v1.json',
  'content/courses/hands-foundations.v1.json',
  'content/courses/dbkb-written.v1.json',
  'content/courses/dbkb-transitions.v1.json',
  'content/courses/dbkb-handling.v1.json',
];
final _token = RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)\}');

String _sourceId(String english) =>
    'g_${computeSha256Hex(Uint8List.fromList(utf8.encode(english))).substring(0, 12)}';

Map<String, int> _tokenCounts(String template) {
  final result = <String, int>{};
  for (final match in _token.allMatches(template)) {
    result.update(match[1]!, (count) => count + 1, ifAbsent: () => 1);
  }
  return result;
}

bool _sameCounts(Map<String, int> left, Map<String, int> right) =>
    left.length == right.length &&
    left.entries.every((entry) => right[entry.key] == entry.value);

bool _sameKeys(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);

// Markers contain no template syntax, so sequential replacement is an
// independent expected result for the all-assets resolver traversal below.
String _markedTemplate(
  String template,
  String tag,
  Map<String, String> values,
) {
  var expected = template;
  for (final entry in values.entries) {
    final inserted = tag == 'ar' ? '\u2068${entry.value}\u2069' : entry.value;
    expected = expected.replaceAll('{${entry.key}}', inserted);
  }
  return expected;
}

String _pointerPart(Object part) =>
    part.toString().replaceAll('~', '~0').replaceAll('/', '~1');

void _visitCoursePairs(
  Object? value,
  String pointer,
  void Function(String english, String turkish, String pointer) visit,
) {
  if (value is Map<String, dynamic>) {
    final english = value['en'];
    final turkish = value['tr'];
    if (english is String && turkish is String) {
      visit(english, turkish, pointer.isEmpty ? '/' : pointer);
    }
    for (final entry in value.entries) {
      _visitCoursePairs(
        entry.value,
        '$pointer/${_pointerPart(entry.key)}',
        visit,
      );
    }
  } else if (value is List<dynamic>) {
    for (var index = 0; index < value.length; index++) {
      _visitCoursePairs(value[index], '$pointer/$index', visit);
    }
  }
}

Future<void> main() async {
  var checks = 0;
  var courseOccurrences = 0;
  final coursePairs = <String>{};
  final courseOccurrencesByFile = <String, int>{};
  final courseTurkishDisplayOverrides = <String, int>{};
  final taxonomySources = <String>{};
  final catalogs = <String, LocaleCatalog>{};
  void check(bool condition, String label) {
    if (!condition) throw StateError(label);
    checks++;
  }

  void rejectsArgument(void Function() action, String label) {
    var rejected = false;
    try {
      action();
    } on ArgumentError {
      rejected = true;
    }
    check(rejected, label);
  }

  LocaleCatalogRegistry.clearForTesting();
  try {
    check(
      supportedLocaleTags.length == _expectedTags.length &&
          _sameKeys(supportedLocaleTags.toSet(), _expectedTags),
      'The approved fourteen exact locale tags must match the production reader',
    );
    for (final tag in supportedLocaleTags) {
      final path = 'content/locales/$tag.json';
      final file = File(path);
      check(file.existsSync(), 'Missing locale asset $path');
      final catalog = LocaleCatalog.parse(file.readAsStringSync());
      check(catalog.localeTag == tag, 'Asset locale tag differs at $path');
      catalogs[tag] = catalog;
      await initializeDateFormatting(localeFormattingName(tag));
    }
    final english = catalogs['en']!;
    final turkish = catalogs['tr']!;
    check(english.messages.isNotEmpty, 'The canonical English asset is empty');
    final sourceIds = english.messages.keys.toSet();
    final englishValues = <String>{};
    for (final entry in english.messages.entries) {
      check(
        englishValues.add(entry.value),
        'Duplicate canonical English source at ${entry.key}',
      );
      check(
        entry.key == _sourceId(entry.value),
        'English UTF-8 SHA-256 source ID mismatch at ${entry.key}',
      );
    }

    // Negative control: a name-set check alone misses dropped repetitions.
    check(
      _sameKeys(placeholderNames('{a} {a} {b}'), placeholderNames('{b} {a}')) &&
          !_sameCounts(_tokenCounts('{a} {a} {b}'), _tokenCounts('{b} {a}')),
      'Occurrence QA must catch a lost token even with identical token names',
    );
    for (final tag in supportedLocaleTags) {
      final catalog = catalogs[tag]!;
      check(
        _sameKeys(catalog.messages.keys.toSet(), sourceIds),
        '$tag key parity differs: '
        '${sourceIds.difference(catalog.messages.keys.toSet()).length} missing, '
        '${catalog.messages.keys.toSet().difference(sourceIds).length} extra',
      );
      check(
        catalog.missingIds(english).isEmpty,
        '$tag reader reports missing IDs',
      );
      catalog.validateAgainst(english);
      checks++;
      for (final entry in english.messages.entries) {
        final translation = catalog.messages[entry.key]!;
        check(
          _sameKeys(
            placeholderNames(entry.value),
            placeholderNames(translation),
          ),
          '$tag placeholder names differ at ${entry.key}',
        );
        check(
          _sameCounts(_tokenCounts(entry.value), _tokenCounts(translation)),
          '$tag placeholder occurrence counts differ at ${entry.key}',
        );
      }
      LocaleCatalogRegistry.register(english, catalog);
    }

    // Check exact registered text before rendering so English fallback cannot
    // make an absent translation look like successful fourteen-language lookup.
    for (final entry in english.messages.entries) {
      final values = <String, String>{
        for (final name in placeholderNames(entry.value)) name: 'VALUE_$name',
      };
      for (final tag in supportedLocaleTags) {
        final target = catalogs[tag]!.messages[entry.key]!;
        check(
          LocaleCatalogRegistry.translatedSource(entry.value, tag) == target,
          '$tag lookup is absent or uses a different source for ${entry.key}',
        );
        check(
          resolveLocalized(
                tag,
                entry.value,
                turkish: turkish.messages[entry.key],
                values: <String, Object>{...values},
              ) ==
              _markedTemplate(target, tag, values),
          '$tag exact source does not resolve/render ${entry.key}',
        );
      }
    }

    for (final path in _courseFiles) {
      final file = File(path);
      check(file.existsSync(), 'Missing shipping course $path');
      var fileOccurrences = 0;
      _visitCoursePairs(jsonDecode(file.readAsStringSync()), '', (
        en,
        tr,
        pointer,
      ) {
        final label = '$path#$pointer';
        final id = _sourceId(en);
        check(
          english.messages[id] == en,
          'Course English absent/different: $label',
        );
        final canonicalTurkish = turkish.messages[id];
        check(
          canonicalTurkish != null && canonicalTurkish.trim().isNotEmpty,
          'Course ID has no canonical Turkish display entry: $label',
        );
        check(
          LocaleCatalogRegistry.translatedSource(en, 'tr') == canonicalTurkish,
          'Course Turkish dictionary lookup differs: $label',
        );
        // Course bytes retain their authored fallback. Reviewed display-only
        // overrides and shared-English canonical TR variants may differ;
        // identity/coverage is checked and the distinction is reported.
        if (canonicalTurkish != tr) {
          courseTurkishDisplayOverrides.update(
            id,
            (occurrences) => occurrences + 1,
            ifAbsent: () => 1,
          );
        }
        fileOccurrences++;
        courseOccurrences++;
        coursePairs.add(jsonEncode(<String>[en, tr]));
      });
      check(fileOccurrences > 0, 'No EN/TR course pairs traversed in $path');
      courseOccurrencesByFile[path] = fileOccurrences;
    }

    // Use the actual production catalogue and display producers. Set parity
    // alone cannot catch a missing runtime label with different source casing.
    final library =
        jsonDecode(File('content/library.json').readAsStringSync())
            as Map<String, dynamic>;
    final movements = (library['movements'] as List<dynamic>).map(
      (raw) => MovementEntry.fromJson(raw as Map<String, dynamic>),
    );
    taxonomySources.addAll(LibraryCatalogue.familyLabels.values);
    for (final movement in movements) {
      taxonomySources.add(movement.displayName);
      taxonomySources.add(LibraryCatalogue.labelFor(movement.family));
      if (movement.level != null) {
        taxonomySources.add(LibraryCatalogue.labelFor(movement.level!));
      }
      if (movement.classBadge != null) {
        taxonomySources.add(movement.classBadge!);
      }
      if (movement.equipment.isEmpty) taxonomySources.add('No equipment');
      for (final equipment in movement.equipment) {
        taxonomySources.add(equipment.replaceAll('_', ' '));
      }
    }
    final trees =
        jsonDecode(File('content/skill-trees.index.json').readAsStringSync())
            as Map<String, dynamic>;
    for (final tree in trees['trees'] as List<dynamic>) {
      taxonomySources.add(
        (tree as Map<String, dynamic>)['displayName'] as String,
      );
    }
    taxonomySources.remove('');
    final missingTaxonomy =
        taxonomySources
            .where((source) => english.messages[_sourceId(source)] != source)
            .toList()
          ..sort();
    check(
      missingTaxonomy.isEmpty,
      'Actual display producers lack exact English source keys: '
      '${jsonEncode(missingTaxonomy)}',
    );
    for (final source in taxonomySources) {
      for (final tag in supportedLocaleTags) {
        check(
          LocaleCatalogRegistry.translatedSource(source, tag) ==
              catalogs[tag]!.messages[_sourceId(source)],
          '$tag taxonomy source has no registered translation: $source',
        );
      }
    }

    // Fixed semantic examples exercise the public typed-value contract, not
    // values generated from the formatter under test. Precision is explicit.
    check(
      renderLocaleTemplate('{amount}', 'en', const <String, Object>{
            'amount': LocaleNumber(1234.5, fractionDigits: 2),
          }) ==
          '1,234.50',
      'English decimal grouping/precision through LocaleNumber',
    );
    check(
      renderLocaleTemplate('{amount} / {amount}', 'de', const <String, Object>{
            'amount': LocaleNumber(1234.5, fractionDigits: 2),
          }) ==
          '1.234,50 / 1.234,50',
      'German decimal and repeated LocaleNumber interpolation',
    );
    check(
      renderLocaleTemplate('{amount}', 'tr', const <String, Object>{
            'amount': LocaleNumber(1234.5, fractionDigits: 3),
          }) ==
          '1.234,500',
      'Turkish decimal separators preserve requested trailing zeros',
    );
    final civil = DateTime.utc(2026, 10, 19, 23, 47);
    final originalCivil = civil.toIso8601String();
    check(
      renderLocaleTemplate('{day} at {time}', 'de', <String, Object>{
            'day': LocaleDate(civil, style: LocaleDateStyle.shortDate),
            'time': LocaleDate(civil, style: LocaleDateStyle.time),
          }) ==
          '19.10.2026 at 23:47',
      'Typed date/time keeps supplied civil components and explicit styles',
    );
    check(
      renderLocaleTemplate('{day}', 'en', <String, Object>{
            'day': LocaleDate(civil),
          }) ==
          'Oct 19, 2026',
      'Default LocaleDate style uses the requested language',
    );
    check(
      civil.toIso8601String() == originalCivil && civil.isUtc,
      'Formatting must not mutate the original date or UTC identity',
    );
    for (final tag in supportedLocaleTags) {
      final number = formatLocaleNumber(1234.5, tag, fractionDigits: 2);
      final date = formatLocaleDate(
        civil,
        tag,
        style: LocaleDateStyle.shortDate,
      );
      final isolateStart = tag == 'ar' ? '\u2068' : '';
      final isolateEnd = tag == 'ar' ? '\u2069' : '';
      check(
        renderLocaleTemplate('{n}; {d}; {n}', tag, <String, Object>{
              'n': const LocaleNumber(1234.5, fractionDigits: 2),
              'd': LocaleDate(civil, style: LocaleDateStyle.shortDate),
            }) ==
            '$isolateStart$number$isolateEnd; $isolateStart$date$isolateEnd; '
                '$isolateStart$number$isolateEnd',
        '$tag routes both typed values and repeated tokens without global-locale leakage',
      );
    }
    check(
      renderLocaleTemplate('{value}', 'ar', const <String, Object>{
            'value': 'name {not_a_second_substitution}',
          }) ==
          '\u2068name {not_a_second_substitution}\u2069',
      'Arabic isolates inserted text and keeps braces as one-pass data',
    );
    rejectsArgument(
      () => renderLocaleTemplate('{amount}', 'en', const <String, Object>{
        'amount': 1.25,
      }),
      'A raw decimal cannot silently choose display precision',
    );
    rejectsArgument(
      () => renderLocaleTemplate('{amount}', 'en', const <String, Object>{
        'amount': LocaleNumber(double.nan, fractionDigits: 2),
      }),
      'A typed nonfinite number must be rejected',
    );
  } finally {
    LocaleCatalogRegistry.clearForTesting();
  }
  check(
    LocaleCatalogRegistry.translatedSource(
          catalogs['en']!.messages.values.first,
          'tr',
        ) ==
        null,
    'Registry cleanup must remove loaded asset state',
  );
  print(
    jsonEncode(<String, Object>{
      'result': 'PASS',
      'checks': checks,
      'localeTags': supportedLocaleTags,
      'englishMessages': catalogs['en']!.messages.length,
      'courseOccurrences': courseOccurrences,
      'courseUniquePairs': coursePairs.length,
      'courseOccurrencesByFile': courseOccurrencesByFile,
      'taxonomySources': taxonomySources.length,
      'courseTurkishDisplayOverridesById': courseTurkishDisplayOverrides,
      'scope':
          'Actual locale assets, production reader/registry and typed display values only; no translation-meaning or render acceptance.',
    }),
  );
}
