import 'dart:convert';

import 'package:intl/date_symbol_data_local.dart';

import 'package:gravita/app/localization/locale_catalog.dart';
import 'package:gravita/app/progress_strings.dart';

// Standalone display catalogue contract. No Flutter, disk/account mutation,
// network, device, font or human translation acceptance is claimed here.
Future<void> main() async {
  var checks = 0;
  void check(bool condition, String label) {
    if (!condition) throw StateError(label);
    checks++;
  }

  void rejects(void Function() action, String label) {
    var rejected = false;
    try {
      action();
    } on Object {
      rejected = true;
    }
    check(rejected, label);
  }

  LocaleCatalog catalog(String tag, Map<String, Object> messages) =>
      LocaleCatalog.parse(
        jsonEncode(<String, Object>{
          'schemaVersion': 1,
          'localeTag': tag,
          'messages': messages,
        }),
      );
  const title = 'g_000000000001';
  const count = 'g_000000000002';
  const legal = 'g_000000000003';
  final english = catalog('en', <String, Object>{
    title: 'Written course',
    count: '{count} sessions',
    legal: 'Not a medical assessment.',
  });
  final german = catalog('de', <String, Object>{
    title: 'Schriftlicher Kurs',
    count: '{count} Einheiten',
  });
  final turkish = catalog('tr', <String, Object>{title: 'Yazılı kurs'});
  final arabic = catalog('ar', <String, Object>{count: '{count} جلسات'});

  for (final tag in supportedLocaleTags) {
    check(canonicalLocaleTag(tag) == tag, 'Exact locale $tag');
    check(isSupportedLocaleTag(tag), 'Supported exact tag $tag');
    await initializeDateFormatting(localeFormattingName(tag));
  }
  check(canonicalLocaleTag('es') == 'es-419', 'Spanish canonical alias');
  check(canonicalLocaleTag('pt') == 'pt-BR', 'Portuguese canonical alias');
  check(canonicalLocaleTag('PT_br') == 'pt-BR', 'Locale separator/case');
  check(canonicalLocaleTag('zh') == 'zh-Hans', 'Simplified language alias');
  check(canonicalLocaleTag('pt-PT') == 'en', 'Unsupported region is explicit');
  check(!isSupportedLocaleTag('zh-Hant'), 'Traditional Chinese not accepted');
  check(
    !isSupportedLocaleTag('pt-PT'),
    'Unsupported exact region not accepted',
  );
  rejects(() => catalog('es', <String, Object>{}), 'Assets require exact tags');
  rejects(() => LocaleCatalog.parse('[]'), 'Object schema');
  rejects(() => LocaleCatalog.parse('{'), 'Malformed JSON');
  rejects(
    () => LocaleCatalog.parse(
      jsonEncode(<String, Object>{
        'schemaVersion': 2,
        'localeTag': 'en',
        'messages': <String, Object>{},
      }),
    ),
    'Schema version',
  );
  rejects(
    () => LocaleCatalog.parse(
      jsonEncode(<String, Object>{
        'schemaVersion': 1,
        'localeTag': 'en',
        'messages': <String, Object>{},
        'unexpected': true,
      }),
    ),
    'Unknown schema fields',
  );
  rejects(() => catalog('en', <String, Object>{'invalid': 'text'}), 'ID shape');
  rejects(
    () => catalog('en', <String, Object>{title: 2}),
    'String values only',
  );
  rejects(
    () => catalog('en', <String, Object>{title: '  '}),
    'Nonempty values',
  );
  rejects(() => english.messages[title] = 'mutated', 'Immutable messages');
  check(
    german.missingIds(english).contains(legal),
    'Missing-entry QA inventory',
  );
  german.validateAgainst(english);
  checks++;
  rejects(
    () => catalog('de', <String, Object>{
      'g_000000000004': 'Unknown',
    }).validateAgainst(english),
    'Unknown canonical source ID',
  );
  rejects(
    () => catalog('de', <String, Object>{
      count: '{total} Einheiten',
    }).validateAgainst(english),
    'Translated placeholder mismatch',
  );
  rejects(() => german.validateAgainst(german), 'English source required');

  LocaleCatalogRegistry.clearForTesting();
  check(
    resolveLocalized('tr', 'Written course', turkish: 'Eski Türkçe') ==
        'Eski Türkçe',
    'Explicit TR fallback before catalogue load',
  );
  check(
    resolveLocalized('ja', 'Written course', turkish: 'Eski Türkçe') ==
        'Written course',
    'Six-language English fallback',
  );
  LocaleCatalogRegistry.register(english, german);
  LocaleCatalogRegistry.register(english, turkish);
  LocaleCatalogRegistry.register(english, arabic);
  check(
    resolveLocalized('de', 'Written course') == 'Schriftlicher Kurs',
    'Exact source resolves',
  );
  check(
    resolveLocalized('de', 'Written course ') == 'Written course ',
    'Changed source remains visible',
  );
  check(
    resolveLocalized('de', 'Not a medical assessment.') ==
        'Not a medical assessment.',
    'Missing legal copy stays canonical English',
  );
  check(
    resolveLocalized('tr', 'Written course', turkish: 'Eski Türkçe') ==
        'Yazılı kurs',
    'Registered TR overrides explicit fallback',
  );
  check(
    resolveLocalized(
          'tr',
          'Not a medical assessment.',
          turkish: 'Tıbbi değerlendirme değildir.',
        ) ==
        'Tıbbi değerlendirme değildir.',
    'TR missing source retains reviewed fallback',
  );
  check(
    resolveLocalized('en', 'Written course') == 'Written course',
    'No global language leakage',
  );
  check(
    resolveLocalized('unsupported', 'Written course') == 'Written course',
    'Unknown locale English fallback after another locale load',
  );
  check(
    resolveLocalized(
          'de',
          '{count} sessions',
          values: const <String, Object>{'count': 2},
        ) ==
        '2 Einheiten',
    'Named integer in translated sentence',
  );
  for (final n in <int>[0, 1, 2, 3, 11, 100]) {
    check(
      resolveLocalized(
            'en',
            n == 1 ? '{count} session' : '{count} sessions',
            values: <String, Object>{'count': n},
          ) ==
          ProgressStrings.sessions(n),
      'English active session singular/other at $n',
    );
    check(
      resolveLocalized(
            'en',
            n == 1 ? '{count} rep' : '{count} reps',
            values: <String, Object>{'count': n},
          ) ==
          ProgressStrings.units(n, 'rep'),
      'English active repetition singular/other at $n',
    );
    check(
      resolveLocalized(
            'en',
            n == 1 ? '{count} second' : '{count} seconds',
            values: <String, Object>{'count': n},
          ) ==
          ProgressStrings.units(n, 'second'),
      'English active duration singular/other at $n',
    );
  }
  check(
    resolveLocalized(
          'ar',
          '{count} sessions',
          values: const <String, Object>{'count': 2},
        ) ==
        '\u2068${formatLocaleNumber(2, 'ar')}\u2069 جلسات',
    'Arabic inserted value is direction-isolated',
  );
  check(
    renderLocaleTemplate('{first} + {second}', 'en', const <String, Object>{
          'second': 'B',
          'first': 'A',
        }) ==
        'A + B',
    'Named values can be reordered',
  );
  check(
    renderLocaleTemplate('{value} / {value}', 'en', const <String, Object>{
          'value': 'A',
        }) ==
        'A / A',
    'Repeated tokens',
  );
  check(
    renderLocaleTemplate('{value}', 'en', const <String, Object>{
          'value': '{count}',
        }) ==
        '{count}',
    'Substitution is one pass, not executable interpolation',
  );
  rejects(
    () => renderLocaleTemplate('{count}', 'en', const <String, Object>{}),
    'Missing named value',
  );
  rejects(
    () =>
        renderLocaleTemplate('Count', 'en', const <String, Object>{'count': 2}),
    'Extra named value',
  );
  rejects(
    () => renderLocaleTemplate('{value}', 'en', const <String, Object>{
      'value': 2.5,
    }),
    'Raw decimal precision rejected',
  );
  rejects(
    () => renderLocaleTemplate('{value}', 'en', const <String, Object>{
      'value': true,
    }),
    'Unsupported value type',
  );
  rejects(
    () => resolveLocalized(
      'tr',
      '{count} things',
      turkish: '{other} şey',
      values: const <String, Object>{'count': 2},
    ),
    'Fallback token parity',
  );
  check(
    renderLocaleTemplate('{value}', 'de', const <String, Object>{
          'value': LocaleNumber(1234.5, fractionDigits: 1),
        }) ==
        '1.234,5',
    'Explicit decimal precision and separators',
  );
  rejects(() => formatLocaleNumber(double.nan, 'en'), 'Nonfinite number');
  rejects(
    () => formatLocaleNumber(2, 'en', fractionDigits: -1),
    'Bad precision',
  );
  final civil = DateTime(2026, 10, 19, 23, 47);
  check(
    formatLocaleDate(civil, 'en', style: LocaleDateStyle.time) == '23:47',
    'Explicit time keeps supplied civil components',
  );
  check(
    formatLocaleDate(civil, 'de', style: LocaleDateStyle.shortDate) ==
        '19.10.2026',
    'Date uses requested locale',
  );
  check(
    renderLocaleTemplate('{date}', 'de', <String, Object>{
          'date': LocaleDate(civil, style: LocaleDateStyle.shortDate),
        }) ==
        '19.10.2026',
    'Typed date value',
  );
  check(
    civil.year == 2026 &&
        civil.month == 10 &&
        civil.day == 19 &&
        civil.hour == 23 &&
        civil.minute == 47,
    'Formatting never mutates dates',
  );

  final revised = catalog('en', <String, Object>{title: 'Revised course'});
  LocaleCatalogRegistry.register(revised, revised);
  check(
    resolveLocalized('de', 'Revised course') == 'Revised course',
    'Source index change invalidates stale locale cache',
  );
  check(
    resolveLocalized('de', 'Written course') == 'Written course',
    'Old source is no longer indexed',
  );
  rejects(
    () => LocaleCatalogRegistry.register(
      catalog('en', <String, Object>{title: 'Same', count: 'Same'}),
      catalog('de', <String, Object>{}),
    ),
    'Ambiguous canonical English source',
  );
  check(
    resolveLocalized('en', 'Revised course') == 'Revised course',
    'Rejected registration does not damage prior registry',
  );
  LocaleCatalogRegistry.clearForTesting();
  print(jsonEncode(<String, Object>{'checks': checks, 'result': 'PASS'}));
}
