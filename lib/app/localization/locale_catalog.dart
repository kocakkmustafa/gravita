import 'dart:convert';

import 'package:intl/intl.dart';

/// App display language only. Stored identities, units, dates and course
/// versions never change when this catalogue is selected.
const supportedLocaleTags = <String>[
  'tr',
  'en',
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
];

String? supportedLocaleAlias(String tag) {
  final normalized = tag.trim().replaceAll('_', '-').toLowerCase();
  final exact = switch (normalized) {
    'tr' || 'tr-tr' => 'tr',
    'en' || 'en-us' || 'en-gb' || 'en-au' || 'en-ca' => 'en',
    'es' || 'es-419' => 'es-419',
    'pt' || 'pt-br' => 'pt-BR',
    'de' || 'de-de' || 'de-at' || 'de-ch' => 'de',
    'fr' || 'fr-fr' || 'fr-ca' => 'fr',
    'ja' || 'ja-jp' => 'ja',
    'ar' || 'ar-sa' || 'ar-eg' => 'ar',
    'it' || 'it-it' || 'it-ch' => 'it',
    'ko' || 'ko-kr' => 'ko',
    'id' || 'id-id' || 'in' || 'in-id' => 'id',
    'pl' || 'pl-pl' => 'pl',
    'hi' || 'hi-in' => 'hi',
    // Traditional Chinese is deliberately not aliased to Simplified Chinese.
    'zh' ||
    'zh-cn' ||
    'zh-sg' ||
    'zh-hans' ||
    'zh-hans-cn' ||
    'zh-hans-sg' => 'zh-Hans',
    _ => null,
  };
  if (exact != null) return exact;
  // Match ordinary platform regional/script variants for reviewed language
  // dictionaries. Portuguese retains its stricter region rule; Chinese
  // requires a reviewed region or an explicit Simplified script.
  if (!RegExp(
    r'^[a-z]{2}(?:-[a-z]{4})?(?:-[a-z]{2}|-[0-9]{3})?$',
  ).hasMatch(normalized)) {
    return null;
  }
  // An explicit script is more precise than a regional default. A user may
  // choose Simplified Chinese while their device region is Taiwan or Hong
  // Kong; a bare zh-TW/zh-HK or any Hant request remains unsupported.
  if (normalized.startsWith('zh-hans-')) return 'zh-Hans';
  return switch (normalized.split('-').first) {
    'en' => 'en',
    'tr' => 'tr',
    'es' => 'es-419',
    'de' => 'de',
    'fr' => 'fr',
    'ja' => 'ja',
    'ar' => 'ar',
    'it' => 'it',
    'ko' => 'ko',
    'id' || 'in' => 'id',
    'pl' => 'pl',
    'hi' => 'hi',
    _ => null,
  };
}

String canonicalLocaleTag(String tag) => supportedLocaleAlias(tag) ?? 'en';

bool isSupportedLocaleTag(String tag) => supportedLocaleAlias(tag) != null;

/// intl bundles Simplified Chinese date symbols under zh_CN.
String localeFormattingName(String tag) => switch (canonicalLocaleTag(tag)) {
  'zh-Hans' => 'zh_CN',
  final canonical => canonical.replaceAll('-', '_'),
};

/// Explicit numeric formatting avoids silently rounding a measurement using
/// a formatter's default precision. Values are display-only, never parsed back.
final class LocaleNumber {
  const LocaleNumber(this.value, {this.fractionDigits = 0});
  final num value;
  final int fractionDigits;
}

enum LocaleDateStyle { date, shortDate, time }

/// The caller chooses date versus time. Formatting keeps the supplied civil
/// components; it does not infer a time zone or call toLocal/toUtc.
final class LocaleDate {
  const LocaleDate(this.value, {this.style = LocaleDateStyle.date});
  final DateTime value;
  final LocaleDateStyle style;
}

String formatLocaleNumber(
  num value,
  String localeTag, {
  int fractionDigits = 0,
}) {
  if (!value.isFinite || fractionDigits < 0 || fractionDigits > 12) {
    throw ArgumentError('Invalid number or explicit display precision');
  }
  final formatter = NumberFormat.decimalPattern(localeFormattingName(localeTag))
    ..minimumFractionDigits = fractionDigits
    ..maximumFractionDigits = fractionDigits;
  return formatter.format(value);
}

String formatLocaleDate(
  DateTime value,
  String localeTag, {
  LocaleDateStyle style = LocaleDateStyle.date,
}) {
  final locale = localeFormattingName(localeTag);
  final formatter = switch (style) {
    LocaleDateStyle.date => DateFormat.yMMMd(locale),
    LocaleDateStyle.shortDate => DateFormat.yMd(locale),
    LocaleDateStyle.time => DateFormat.Hm(locale),
  };
  return formatter.format(value);
}

final _messageId = RegExp(r'^g_[a-f0-9]{12}$');
final _placeholder = RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)\}');

Set<String> placeholderNames(String template) =>
    _placeholder.allMatches(template).map((m) => m[1]!).toSet();

Map<String, int> placeholderOccurrences(String template) {
  final result = <String, int>{};
  for (final match in _placeholder.allMatches(template)) {
    result.update(match[1]!, (count) => count + 1, ifAbsent: () => 1);
  }
  return result;
}

bool _samePlaceholders(String source, String target) {
  final expected = placeholderOccurrences(source);
  final actual = placeholderOccurrences(target);
  return expected.length == actual.length &&
      expected.entries.every((entry) => actual[entry.key] == entry.value);
}

/// The catalogue carries text, not executable interpolation or ICU code.
/// Named tokens are substituted once; values containing braces remain data.
String renderLocaleTemplate(
  String template,
  String localeTag,
  Map<String, Object> values,
) {
  final names = placeholderNames(template);
  if (names.length != values.length || !names.containsAll(values.keys)) {
    throw ArgumentError(
      'Template values must exactly match named placeholders',
    );
  }
  String display(Object value) => switch (value) {
    String text => text,
    int number => formatLocaleNumber(number, localeTag),
    LocaleNumber number => formatLocaleNumber(
      number.value,
      localeTag,
      fractionDigits: number.fractionDigits,
    ),
    LocaleDate date => formatLocaleDate(
      date.value,
      localeTag,
      style: date.style,
    ),
    _ => throw ArgumentError(
      'Use String, int, LocaleNumber or LocaleDate for a named value',
    ),
  };
  return template.replaceAllMapped(_placeholder, (match) {
    final text = display(values[match[1]]!);
    // Isolate an inserted name/email/number in an Arabic sentence. This affects
    // display order only; no user data or persisted value is rewritten.
    return canonicalLocaleTag(localeTag) == 'ar' ? '\u2068$text\u2069' : text;
  });
}

final class LocaleCatalog {
  LocaleCatalog._(this.localeTag, Map<String, String> messages)
    : messages = Map<String, String>.unmodifiable(messages);

  factory LocaleCatalog.parse(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 3 ||
        decoded['schemaVersion'] is! int ||
        decoded['schemaVersion'] != 1 ||
        decoded['localeTag'] is! String ||
        decoded['messages'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid locale catalogue schema');
    }
    final tag = decoded['localeTag'] as String;
    if (!supportedLocaleTags.contains(tag)) {
      throw const FormatException('Catalogue requires an exact supported tag');
    }
    final messages = <String, String>{};
    for (final entry in (decoded['messages'] as Map<String, dynamic>).entries) {
      final value = entry.value;
      if (!_messageId.hasMatch(entry.key) ||
          value is! String ||
          value.trim().isEmpty) {
        throw const FormatException('Invalid locale message ID or value');
      }
      messages[entry.key] = value;
    }
    return LocaleCatalog._(tag, messages);
  }

  final String localeTag;
  final Map<String, String> messages;

  void validateAgainst(LocaleCatalog english) {
    if (english.localeTag != 'en') {
      throw ArgumentError('The source index must be English');
    }
    for (final entry in messages.entries) {
      final source = english.messages[entry.key];
      if (source == null) {
        throw const FormatException('A translation has no canonical source ID');
      }
      if (!_samePlaceholders(source, entry.value)) {
        throw const FormatException('Translation named placeholders differ');
      }
    }
  }

  Set<String> missingIds(LocaleCatalog english) =>
      english.messages.keys.toSet().difference(messages.keys.toSet());
}

/// Separate, declarative count forms. No ICU parser or executable expressions.
final class LocalePluralEntry {
  LocalePluralEntry._(this.countArgument, Map<String, String> forms)
    : forms = Map<String, String>.unmodifiable(forms);

  final String countArgument;
  final Map<String, String> forms;

  String resolve(String localeTag, Map<String, Object> values) {
    final count = values[countArgument];
    if (count is! int || count < 0) {
      throw ArgumentError('A plural count must be a nonnegative integer');
    }
    // Disable explicit-number shortcuts: 2 is not CLDR "two" in Polish.
    final category = Intl.pluralLogic<String>(
      count,
      zero: 'zero',
      one: 'one',
      two: 'two',
      few: 'few',
      many: 'many',
      other: 'other',
      locale: localeFormattingName(localeTag),
      useExplicitNumberCases: false,
    );
    return forms[category] ?? forms['other']!;
  }
}

final class LocalePluralCatalog {
  LocalePluralCatalog._(this.localeTag, Map<String, LocalePluralEntry> entries)
    : entries = Map<String, LocalePluralEntry>.unmodifiable(entries);

  factory LocalePluralCatalog.parse(String source) {
    if (utf8.encode(source).length > 256 * 1024) {
      throw const FormatException('Plural catalogue is too large');
    }
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 3 ||
        decoded['schemaVersion'] is! int ||
        decoded['schemaVersion'] != 1 ||
        decoded['localeTag'] is! String ||
        !supportedLocaleTags.contains(decoded['localeTag']) ||
        decoded['entries'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid plural catalogue schema');
    }
    const categories = <String>{'zero', 'one', 'two', 'few', 'many', 'other'};
    final entries = <String, LocalePluralEntry>{};
    for (final entry in (decoded['entries'] as Map<String, dynamic>).entries) {
      final value = entry.value;
      if (!_messageId.hasMatch(entry.key) ||
          value is! Map<String, dynamic> ||
          value.length != 2 ||
          value['count'] is! String ||
          !RegExp(
            r'^[A-Za-z_][A-Za-z0-9_]*$',
          ).hasMatch(value['count'] as String) ||
          value['forms'] is! Map<String, dynamic>) {
        throw const FormatException('Invalid plural entry');
      }
      final forms = <String, String>{};
      for (final form in (value['forms'] as Map<String, dynamic>).entries) {
        if (!categories.contains(form.key) ||
            form.value is! String ||
            (form.value as String).trim().isEmpty) {
          throw const FormatException('Invalid plural category or form');
        }
        forms[form.key] = form.value as String;
      }
      if (!forms.containsKey('other')) {
        throw const FormatException('A plural entry requires other');
      }
      entries[entry.key] = LocalePluralEntry._(value['count'] as String, forms);
    }
    return LocalePluralCatalog._(decoded['localeTag'] as String, entries);
  }

  final String localeTag;
  final Map<String, LocalePluralEntry> entries;

  void validateAgainst(LocaleCatalog english) {
    if (english.localeTag != 'en') {
      throw ArgumentError('The plural source must be English');
    }
    for (final entry in entries.entries) {
      final source = english.messages[entry.key];
      if (source == null ||
          !placeholderNames(source).contains(entry.value.countArgument)) {
        throw const FormatException('Plural has no canonical count source');
      }
      for (final form in entry.value.forms.values) {
        if (!_samePlaceholders(source, form)) {
          throw const FormatException('Plural named placeholders differ');
        }
      }
    }
  }
}

/// Each lookup receives a language explicitly. Loading another locale never
/// switches existing widgets, account data or stored course progress.
abstract final class LocaleCatalogRegistry {
  static LocaleCatalog? _english;
  static Map<String, String> _sourceIds = <String, String>{};
  static final Map<String, LocaleCatalog> _catalogs = <String, LocaleCatalog>{};
  static final Map<String, LocalePluralCatalog> _plurals =
      <String, LocalePluralCatalog>{};

  static void register(
    LocaleCatalog english,
    LocaleCatalog requested, {
    LocalePluralCatalog? plurals,
    LocaleCatalog? englishDisplayOverrides,
  }) {
    if (english.localeTag != 'en') {
      throw ArgumentError('Expected English source catalogue');
    }
    requested.validateAgainst(english);
    if (englishDisplayOverrides != null) {
      if (englishDisplayOverrides.localeTag != 'en') {
        throw const FormatException('English display overrides require en');
      }
      englishDisplayOverrides.validateAgainst(english);
    }
    if (plurals != null) {
      if (plurals.localeTag != requested.localeTag) {
        throw const FormatException('Plural locale does not match catalogue');
      }
      plurals.validateAgainst(english);
    }
    final sourceIds = <String, String>{};
    for (final entry in english.messages.entries) {
      if (sourceIds.containsKey(entry.value)) {
        throw const FormatException('Canonical English source is ambiguous');
      }
      sourceIds[entry.value] = entry.key;
    }
    final old = _english?.messages;
    if (old == null ||
        old.length != english.messages.length ||
        english.messages.entries.any((e) => old[e.key] != e.value)) {
      _catalogs.clear();
      _plurals.clear();
    }
    _english = english;
    _sourceIds = sourceIds;
    _catalogs['en'] = englishDisplayOverrides ?? english;
    if (requested.localeTag != 'en' || englishDisplayOverrides == null) {
      _catalogs[requested.localeTag] = requested;
    }
    if (plurals == null) {
      _plurals.remove(requested.localeTag);
    } else {
      _plurals[requested.localeTag] = plurals;
    }
  }

  static String? translatedSource(String english, String localeTag) {
    final id = _sourceIds[english];
    if (id == null) return null;
    final tag = canonicalLocaleTag(localeTag);
    return _catalogs[tag]?.messages[id] ??
        (tag == 'en' ? _english?.messages[id] : null);
  }

  static String resolve(
    String localeTag,
    String english, {
    String? turkish,
    Map<String, Object> values = const <String, Object>{},
  }) {
    final tag = canonicalLocaleTag(localeTag);
    // Original TR copy remains a deliberate fallback for existing EN/TR
    // callers. Other locales use canonical English if their entry is missing.
    final fallback = tag == 'tr' ? turkish ?? english : english;
    final id = _sourceIds[english];
    final plural = id == null ? null : _plurals[tag]?.entries[id];
    final template =
        plural?.resolve(tag, values) ??
        translatedSource(english, tag) ??
        fallback;
    if (!_samePlaceholders(english, template)) {
      throw const FormatException('Fallback named placeholders differ');
    }
    return renderLocaleTemplate(template, tag, values);
  }

  /// Test isolation only; no preferences or disk state are changed.
  static void clearForTesting() {
    _english = null;
    _sourceIds = <String, String>{};
    _catalogs.clear();
    _plurals.clear();
  }
}

String resolveLocalized(
  String localeTag,
  String english, {
  String? turkish,
  Map<String, Object> values = const <String, Object>{},
}) => LocaleCatalogRegistry.resolve(
  localeTag,
  english,
  turkish: turkish,
  values: values,
);
