import 'dart:convert';
import 'dart:io';

import 'package:gravita/app/library_model.dart';

// Actual production parser/search over the checked-in catalogue. Display
// strings below are inputs to the pure API, not a second translation source.
// Flutter locale helper/LibraryScreen wiring is outside this standalone test.
void main() {
  final source =
      (jsonDecode(File('content/library.json').readAsStringSync()) as Map)
          .cast<String, dynamic>();
  final catalogue = LibraryCatalogue(
    movements: (source['movements'] as List<dynamic>)
        .map(
          (dynamic value) =>
              MovementEntry.fromJson((value as Map).cast<String, dynamic>()),
        )
        .toList(growable: false),
    exclusions: ExclusionsPage.parse(
      File('content/exclusions.page.json').readAsStringSync(),
    ),
    skillTrees: SkillTreeIndex.parse(
      File('content/skill-trees.index.json').readAsStringSync(),
    ),
  );
  var checks = 0;
  void check(bool condition, String label) {
    if (!condition) throw StateError(label);
    checks++;
  }

  final displayTerms = <String, List<String>>{
    'push_up': <String>['Şınav', 'İtiş', 'Ekipmansız'],
    'hanging_leg_raise': <String>[
      'Asılı bacak kaldırma',
      'Gövde',
      'Barfiks barı',
    ],
    'floor_press': <String>[
      'Yerde press',
      'Ağırlık',
      'Dambıl ve kettlebell',
      'Dambıl',
    ],
    'farmer_carry': <String>['Çiftçi yürüyüşü', 'Taşıma', 'Dambıl'],
  };
  for (final id in displayTerms.keys) {
    check(catalogue.byId(id) != null, 'Expected actual content movement $id');
  }
  Iterable<String> localizedTerms(MovementEntry movement) =>
      displayTerms[movement.id] ?? <String>[movement.displayName];
  Set<String> ids(String query, {bool localized = true}) => catalogue
      .search(query, additionalMovementTerms: localized ? localizedTerms : null)
      .movements
      .map((movement) => movement.id)
      .toSet();

  check(
    !ids('Şınav', localized: false).contains('push_up'),
    'Control: raw EN source should not already contain the supplied TR name',
  );
  for (final query in <String>[
    'Şınav',
    'ŞINAV',
    'ŞİNAV',
    'şinav',
    'şi\u0307nav',
  ]) {
    check(
      ids(query).contains('push_up'),
      'TR movement name missing for $query',
    );
  }
  for (final query in <String>[
    'İtiş',
    'ITIŞ',
    'itiş',
    'ıtış',
    'I\u0307TI\u0307Ş',
  ]) {
    check(ids(query).contains('push_up'), 'TR family missing for $query');
  }
  for (final query in <String>['asılı', 'ASILI', 'ASİLİ', 'asili']) {
    check(
      ids(query).contains('hanging_leg_raise'),
      'Dotless-I name missing for $query',
    );
  }
  for (final query in <String>['Dambıl', 'DAMBIL', 'DAMBİL', 'dambil']) {
    final found = ids(query);
    check(
      found.contains('floor_press') && found.contains('farmer_carry'),
      'Localized equipment missing for $query',
    );
  }
  check(
    ids('GÖVDE').contains('hanging_leg_raise'),
    'Localized family not searched',
  );
  check(
    ids('Ekipmansız').contains('push_up'),
    'Visible no-equipment label not searched',
  );
  check(
    ids(' \tASILI \n BACAK\u00a0 KALDIRMA  ').contains('hanging_leg_raise'),
    'Whitespace variants should match the same visible phrase',
  );
  check(
    ids(' \tAIR\n SQUAT ').contains('bodyweight_squat'),
    'English source aliases must retain whitespace/case matching',
  );
  check(
    ids('push up').contains('push_up') || ids('push-up').contains('push_up'),
    'English source term must remain available with TR display terms',
  );

  for (final movement in catalogue.movements) {
    check(
      ids(movement.displayName).contains(movement.id),
      'English name fallback lost for ${movement.id}',
    );
  }
  final untranslated = catalogue.movements.firstWhere(
    (movement) => !displayTerms.containsKey(movement.id),
  );
  check(
    ids(untranslated.displayName).contains(untranslated.id),
    'An untranslated display name must keep its English fallback',
  );
  check(
    ids('Çiftçi').contains('farmer_carry'),
    'Other Turkish accents must survive',
  );
  check(
    !ids('Ciftci').contains('farmer_carry'),
    'I folding must not invent general accent transliteration',
  );

  final isolated = catalogue.search(
    'only-this-movement',
    additionalMovementTerms: (movement) => movement.id == 'farmer_carry'
        ? <String>['only-this-movement']
        : const <String>[],
  );
  check(
    isolated.movements.length == 1 &&
        isolated.movements.single.id == 'farmer_carry',
    'Additional terms leaked between movements',
  );

  var additionalCalls = 0;
  final browse = catalogue.search(
    ' \t\n\u00a0 ',
    additionalMovementTerms: (movement) {
      additionalCalls++;
      return <String>[movement.displayName];
    },
  );
  check(
    !browse.hasQuery && identical(browse.movements, catalogue.movements),
    'Whitespace-only query must keep browse behavior',
  );
  check(
    browse.exclusions.isEmpty && additionalCalls == 0,
    'Empty query must not add exclusion results or resolve display terms',
  );

  final excluded = catalogue.search(
    ' \tLEG\n PRESS ',
    additionalMovementTerms: localizedTerms,
  );
  check(excluded.exclusions.isNotEmpty, 'Out-of-scope search lost its reason');
  final nonsense = catalogue.search(
    'zzzqqq',
    additionalMovementTerms: localizedTerms,
  );
  check(
    nonsense.isEmpty && nonsense.hasQuery,
    'Nonsense query must remain truly empty',
  );
  final mixed = catalogue.search(
    'squat',
    additionalMovementTerms: localizedTerms,
  );
  check(
    mixed.movements.isNotEmpty && mixed.exclusions.isNotEmpty,
    'Movement and exclusion matches must remain visible together',
  );

  stdout.writeln(
    jsonEncode(<String, Object>{
      'checks': checks,
      'result': 'PASS',
      'scope':
          'actual pure catalogue model and checked-in content; supplied localized terms',
      'flutterOrNativeExecuted': false,
    }),
  );
}
