import 'dart:convert';

import 'localization/locale_catalog.dart' show supportedLocaleTags;

enum LanguagePreferencesLoadIssue { invalid, unavailable }

class LanguagePreferencesLoadResult {
  const LanguagePreferencesLoadResult({this.selectedTag, this.issue});

  /// Null follows the device. Persisted choices always use an exact app tag.
  final String? selectedTag;
  final LanguagePreferencesLoadIssue? issue;
}

abstract interface class LanguagePreferencesStore {
  Future<LanguagePreferencesLoadResult> load();
  Future<void> save(String? selectedTag);
}

/// A device-wide display preference with no account or training identifiers.
/// Aliases are resolved at the OS locale boundary, never in stored preferences.
abstract final class LanguagePreferencesCodec {
  static const int maximumBytes = 512;

  static bool isExactSelection(String? selectedTag) =>
      selectedTag == null || supportedLocaleTags.contains(selectedTag);

  static List<int> encode(String? selectedTag) {
    if (!isExactSelection(selectedTag)) {
      throw const FormatException('Language requires an exact supported tag.');
    }
    return utf8.encode(
      '${jsonEncode(<String, Object?>{'schemaVersion': 1, 'localeTag': selectedTag})}\n',
    );
  }

  static String? decode(List<int> bytes) {
    if (bytes.length > maximumBytes) {
      throw const FormatException('Language document is too large.');
    }
    final Object? document = jsonDecode(utf8.decode(bytes));
    if (document is! Map<String, dynamic> ||
        document.length != 2 ||
        document['schemaVersion'] is! int ||
        document['schemaVersion'] != 1 ||
        !document.containsKey('localeTag')) {
      throw const FormatException('Unsupported language document.');
    }
    final Object? selectedTag = document['localeTag'];
    if (selectedTag == null) return null;
    if (selectedTag is! String || !isExactSelection(selectedTag)) {
      throw const FormatException('Unknown language selection.');
    }
    return selectedTag;
  }
}
