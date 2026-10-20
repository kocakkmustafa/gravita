import 'dart:convert';
import 'dart:io';

import 'package:gravita/app/localization/locale_catalog.dart';
import 'package:intl/date_symbol_data_local.dart';

int checks = 0;
void check(bool condition, String label) {
  checks++;
  if (!condition) throw StateError(label);
}

void rejects(void Function() action, String label) {
  var failed = false;
  try {
    action();
  } on FormatException {
    failed = true;
  }
  check(failed, label);
}

const id = 'g_0123456789ab';
LocaleCatalog catalogue(String tag, String text) => LocaleCatalog.parse(
  jsonEncode({
    'schemaVersion': 1,
    'localeTag': tag,
    'messages': {id: text},
  }),
);
LocalePluralCatalog plural(String tag, Map<String, String> forms) =>
    LocalePluralCatalog.parse(
      jsonEncode({
        'schemaVersion': 1,
        'localeTag': tag,
        'entries': {
          id: {'count': 'count', 'forms': forms},
        },
      }),
    );

Future<void> main() async {
  final english = catalogue('en', '{count} sessions');
  for (final tag in supportedLocaleTags) {
    check(canonicalLocaleTag(tag) == tag, 'exact $tag');
    check(isSupportedLocaleTag(tag), 'supported $tag');
    await initializeDateFormatting(localeFormattingName(tag));
    check(
      formatLocaleDate(DateTime(2026, 10, 20), tag).isNotEmpty,
      'date $tag',
    );
    check(formatLocaleNumber(12345, tag).isNotEmpty, 'number $tag');
  }
  for (final alias in [
    'zh',
    'zh-CN',
    'zh_SG',
    'zh-Hans',
    'zh-Hans-CN',
    'zh-Hans-TW',
    'zh-Hans-HK',
    'zh-Hans-US',
    'zh-Hans-419',
  ]) {
    check(canonicalLocaleTag(alias) == 'zh-Hans', 'Simplified $alias');
  }
  for (final unsupported in [
    'zh-Hant',
    'zh-TW',
    'zh-HK',
    'zh-MO',
    'zh-Hant-CN',
    'zh-Hant-SG',
    'zh-Latn-CN',
    'zh-Hans-invalid',
    'pt-PT',
    'nl',
  ]) {
    check(!isSupportedLocaleTag(unsupported), 'unsupported $unsupported');
    check(canonicalLocaleTag(unsupported) == 'en', 'fallback $unsupported');
  }
  check(canonicalLocaleTag('in_ID') == 'id', 'legacy Indonesian');
  check(canonicalLocaleTag('ko-KR') == 'ko', 'Korean region');
  check(canonicalLocaleTag('hi-IN') == 'hi', 'Hindi region');
  check(localeFormattingName('zh-Hans') == 'zh_CN', 'intl Chinese symbol key');

  final polish = plural('pl', {
    'one': '{count} sesja',
    'few': '{count} sesje',
    'many': '{count} sesji',
    'other': '{count} sesji',
  });
  LocaleCatalogRegistry.register(
    english,
    catalogue('pl', '{count} sesji'),
    plurals: polish,
  );
  for (final entry in <int, String>{
    0: 'sesji',
    1: 'sesja',
    2: 'sesje',
    3: 'sesje',
    4: 'sesje',
    5: 'sesji',
    11: 'sesji',
    12: 'sesji',
    14: 'sesji',
    21: 'sesji',
    22: 'sesje',
    24: 'sesje',
    25: 'sesji',
    101: 'sesji',
    102: 'sesje',
    112: 'sesji',
  }.entries) {
    check(
      resolveLocalized(
            'pl',
            '{count} sessions',
            values: {'count': entry.key},
          ) ==
          '${formatLocaleNumber(entry.key, 'pl')} ${entry.value}',
      'Polish ${entry.key}',
    );
  }
  final arabic = plural('ar', {
    'zero': '{count} zero',
    'one': '{count} one',
    'two': '{count} two',
    'few': '{count} few',
    'many': '{count} many',
    'other': '{count} other',
  });
  LocaleCatalogRegistry.register(
    english,
    catalogue('ar', '{count} other'),
    plurals: arabic,
  );
  for (final entry in <int, String>{
    0: 'zero',
    1: 'one',
    2: 'two',
    3: 'few',
    10: 'few',
    11: 'many',
    99: 'many',
    100: 'other',
    101: 'other',
    102: 'other',
    103: 'few',
  }.entries) {
    check(
      resolveLocalized(
            'ar',
            '{count} sessions',
            values: {'count': entry.key},
          ) ==
          '\u2068${formatLocaleNumber(entry.key, 'ar')}\u2069 ${entry.value}',
      'Arabic CLDR/isolation ${entry.key}',
    );
  }
  // Hindi zero and one both use one. Explicit number cases in intl would
  // otherwise select the wrong branch for zero in some plural wrappers.
  LocaleCatalogRegistry.register(
    english,
    catalogue('hi', '{count} other'),
    plurals: plural('hi', {'one': '{count} one', 'other': '{count} other'}),
  );
  for (final entry in <int, String>{
    0: 'one',
    1: 'one',
    2: 'other',
    11: 'other',
    100: 'other',
  }.entries) {
    check(
      resolveLocalized(
            'hi',
            '{count} sessions',
            values: {'count': entry.key},
          ) ==
          '${formatLocaleNumber(entry.key, 'hi')} ${entry.value}',
      'Hindi CLDR ${entry.key}',
    );
  }
  LocaleCatalogRegistry.register(
    english,
    catalogue('ar', '{count} other'),
    plurals: arabic,
  );
  for (final invalid in [
    {
      'schemaVersion': 1,
      'localeTag': 'pl',
      'entries': {
        id: {
          'count': 'count',
          'forms': {'one': '{count} x'},
        },
      },
    },
    {
      'schemaVersion': 1,
      'localeTag': 'pl',
      'entries': {
        id: {
          'count': 'count',
          'forms': {'other': '{count} x', 'bogus': 'x'},
        },
      },
    },
    {'schemaVersion': true, 'localeTag': 'pl', 'entries': {}},
    {'schemaVersion': 1, 'localeTag': 'zh-Hant', 'entries': {}},
  ]) {
    rejects(
      () => LocalePluralCatalog.parse(jsonEncode(invalid)),
      'malformed sidecar',
    );
  }
  rejects(
    () => plural('pl', {'other': '{count} {count}'}).validateAgainst(english),
    'repeated occurrence rejected',
  );
  rejects(
    () => plural('pl', {'other': 'missing'}).validateAgainst(english),
    'lost token',
  );
  rejects(
    () => catalogue('pl', '{count} {count}').validateAgainst(english),
    'catalogue repeated occurrence rejected',
  );
  var countRejected = false;
  try {
    resolveLocalized('ar', '{count} sessions', values: {'count': -1});
  } on ArgumentError {
    countRejected = true;
  }
  check(countRejected, 'negative count rejected');
  LocaleCatalogRegistry.register(english, catalogue('pl', '{count} plain'));
  check(
    resolveLocalized('pl', '{count} sessions', values: {'count': 2}) ==
        '2 plain',
    'register without sidecar clears old override',
  );
  final revised = catalogue('en', '{count} new source');
  LocaleCatalogRegistry.register(
    revised,
    catalogue('en', '{count} new source'),
  );
  check(
    resolveLocalized('ar', '{count} new source', values: {'count': 2}) ==
        '\u2068${formatLocaleNumber(2, 'ar')}\u2069 new source',
    'source reset clears old plurals',
  );
  LocaleCatalogRegistry.clearForTesting();
  final bundledEnglish = LocaleCatalog.parse(
    File('content/locales/en.json').readAsStringSync(),
  );
  final englishDisplay = LocaleCatalog.parse(
    File('content/locales/display-overrides/en.json').readAsStringSync(),
  );
  englishDisplay.validateAgainst(bundledEnglish);
  check(
    englishDisplay.messages.length == 5,
    'five reviewed English display corrections',
  );
  final grammarGolden = <String, String>{
    'g_053d7c4896da':
        'Stop for elbow or shoulder pain, or if you cannot lower smoothly.',
    'g_056926ff7cf6':
        'Stop if you have sharp pain, tingling or symptoms that persist after unloading.',
    'g_05a4e4ffb450': 'Stop if you feel shoulder pinching or neck strain.',
    'g_466c477d6020':
        'Its {count} error rule has never been run against real footage. There is no replay fixture for this movement, so we have no evidence that it fires when it should — or stays quiet when it should.',
    'g_f7090ef702c1':
        "Still counted, not graded: {sessions}. We opened grading later, and we don't grade sessions we didn't measure at the time.",
  };
  for (final tag in ['en', 'de']) {
    final requested = LocaleCatalog.parse(
      jsonEncode({
        'schemaVersion': 1,
        'localeTag': tag,
        'messages': <String, String>{},
      }),
    );
    LocaleCatalogRegistry.register(
      bundledEnglish,
      requested,
      englishDisplayOverrides: englishDisplay,
    );
    for (final entry in grammarGolden.entries) {
      check(
        englishDisplay.messages[entry.key] == entry.value,
        'reviewed English text ${entry.key}',
      );
      final args = entry.key == 'g_f7090ef702c1'
          ? <String, Object>{'sessions': '1 session'}
          : placeholderNames(entry.value).isEmpty
          ? <String, Object>{}
          : <String, Object>{'count': 1};
      check(
        resolveLocalized(
              'en',
              bundledEnglish.messages[entry.key]!,
              values: args,
            ) ==
            entry.value
                .replaceAll('{count}', '1')
                .replaceAll('{sessions}', '1 session'),
        'English override across $tag registration',
      );
      check(
        bundledEnglish.messages[entry.key] != entry.value,
        'canonical English source remains distinct',
      );
    }
    check(
      LocaleCatalogRegistry.translatedSource(
            'Unregistered regression source only.',
            'en',
          ) ==
          null,
      'unknown source remains guarded',
    );
    final untouched = bundledEnglish.messages.entries.firstWhere(
      (e) => !grammarGolden.containsKey(e.key),
    );
    check(
      LocaleCatalogRegistry.translatedSource(untouched.value, 'en') ==
          untouched.value,
      'partial English overrides retain canonical lookup',
    );
  }
  final emptyEnglish = LocaleCatalog.parse(
    jsonEncode({
      'schemaVersion': 1,
      'localeTag': 'en',
      'messages': <String, String>{},
    }),
  );
  final wrongDisplay = LocaleCatalog.parse(
    jsonEncode({
      'schemaVersion': 1,
      'localeTag': 'de',
      'messages': <String, String>{},
    }),
  );
  rejects(
    () => LocaleCatalogRegistry.register(
      bundledEnglish,
      emptyEnglish,
      englishDisplayOverrides: wrongDisplay,
    ),
    'English override locale rejects',
  );
  final actualEntryCounts = <String, int>{};
  final composedCases = <String, int>{};
  final composedOutputs = <String, String>{};
  for (final tag in supportedLocaleTags) {
    final actual = LocalePluralCatalog.parse(
      File('content/locales/plurals/$tag.json').readAsStringSync(),
    );
    check(actual.localeTag == tag, 'actual sidecar tag $tag');
    check(actual.entries.length == 15, 'complete basic counters $tag');
    actual.validateAgainst(bundledEnglish);
    checks++;
    actualEntryCounts[tag] = actual.entries.length;
    final emptyRequested = LocaleCatalog.parse(
      jsonEncode({
        'schemaVersion': 1,
        'localeTag': tag,
        'messages': <String, String>{},
      }),
    );
    LocaleCatalogRegistry.register(
      bundledEnglish,
      emptyRequested,
      plurals: actual,
    );
    for (final entry in actual.entries.entries) {
      for (final n in [0, 1, 2, 3, 5, 11, 12, 21, 22, 99, 100, 101, 102]) {
        final rendered = resolveLocalized(
          tag,
          bundledEnglish.messages[entry.key]!,
          values: {entry.value.countArgument: n},
        );
        check(
          rendered.isNotEmpty && !rendered.contains('{count}'),
          'bundled plural render $tag/${entry.key}/$n',
        );
      }
    }
    final requested = LocaleCatalog.parse(
      File('content/locales/$tag.json').readAsStringSync(),
    );
    LocaleCatalogRegistry.register(
      bundledEnglish,
      requested,
      plurals: actual,
      englishDisplayOverrides: englishDisplay,
    );
    composedCases[tag] = 0;
    // These are the four String-valued bindings in ProgressCopy. Exercise
    // the production registry with complete localized phrases, never by
    // parsing a localized String back into an integer. This is not a widget
    // or a runtime invocation of the Flutter-dependent ProgressCopy class.
    for (final n in [0, 1, 2, 5]) {
      String count(String singular, String plural) => resolveLocalized(
        tag,
        n == 1 ? singular : plural,
        values: {'count': n},
      );
      final sessions = count('{count} session', '{count} sessions');
      final reps = count('{count} rep', '{count} reps');
      final seconds = count('{count} second', '{count} seconds');
      final arguments = <String, Map<String, Object>>{
        'g_42e701b4c637': {'sessions': sessions},
        'g_f7090ef702c1': {'sessions': sessions},
        'g_b1d663704e9b': {'sessions': sessions, 'totals': '$reps · $seconds'},
        'g_b40f81212373': {
          'amount': n == 5 ? '${formatLocaleNumber(n, tag)} future_unit' : reps,
          'reasons': n.isEven ? ' (framing)' : '',
        },
      };
      for (final binding in arguments.entries) {
        final rendered = resolveLocalized(
          tag,
          bundledEnglish.messages[binding.key]!,
          values: binding.value,
        );
        check(rendered.isNotEmpty, 'composed $tag/$n/${binding.key}');
        check(
          !RegExp(r'\{[A-Za-z][A-Za-z0-9_]*\}').hasMatch(rendered),
          'no unexpanded composed token $tag/$n/${binding.key}',
        );
        for (final value in binding.value.values) {
          check(
            rendered.contains(value as String),
            'complete unit phrase retained $tag/$n/${binding.key}',
          );
        }
        if (tag == 'ko') {
          check(!rendered.contains('회회'), 'Korean classifier is not repeated');
        }
        composedCases[tag] = composedCases[tag]! + 1;
        composedOutputs['$tag/$n/${binding.key}'] = rendered.replaceAll(
          RegExp('[\u2068\u2069]'),
          '',
        );
      }
    }
  }
  final composedGoldens = <String, String>{
    'en/1/g_f7090ef702c1':
        "Still counted, not graded: 1 session. We opened grading later, and we don't grade sessions we didn't measure at the time.",
    'de/1/g_f7090ef702c1':
        'Als gezählt und unbewertet beibehalten: 1 Einheit. Wir haben die Bewertung später freigeschaltet; wir bewerten keine Einheiten, die wir damals nicht gemessen haben.',
    'es-419/1/g_42e701b4c637': 'Conteo registrado, sin calificación: 1 sesión.',
    'fr/1/g_42e701b4c637': 'Comptage sans notation : 1 séance.',
    'pt-BR/1/g_42e701b4c637': 'Contagem sem avaliação: 1 sessão.',
    'ko/1/g_42e701b4c637': '세션 1회 집계, 채점 없음.',
    // intl 0.20.3's generic ar symbols use ZERO_DIGIT '0'. The fixture
    // checks the dual phrase; it must not silently mandate a numeral set.
    'ar/2/g_42e701b4c637': 'احتساب دون تقييم: جلستان (2).',
    'pl/1/g_f7090ef702c1':
        'Zachowujemy zliczenie bez oceny: 1 sesja. Funkcję oceniania udostępniliśmy później; nie oceniamy sesji, których wtedy nie mierzyliśmy.',
  };
  for (final golden in composedGoldens.entries) {
    check(
      composedOutputs[golden.key] == golden.value,
      'reviewed composed regression ${golden.key}: '
      'expected ${golden.value}, got ${composedOutputs[golden.key]}',
    );
  }
  LocaleCatalogRegistry.clearForTesting();
  print(
    jsonEncode({
      'status': 'PASS',
      'checks': checks,
      'actualPluralEntriesByLocale': actualEntryCounts,
      'composedMessageExpansionsByLocale': composedCases,
      'scope':
          'CLDR/alias/structural and bundled sidecar rendering; not independent linguistic or native font acceptance',
    }),
  );
}
