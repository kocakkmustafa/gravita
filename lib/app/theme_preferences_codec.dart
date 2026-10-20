import 'dart:convert';

/// Device appearance is independent of account identity and training history.
enum GravitaThemeMode { system, light, dark }

enum ThemePreferencesLoadIssue { invalid, unavailable }

class ThemePreferencesLoadResult {
  const ThemePreferencesLoadResult({
    this.mode = GravitaThemeMode.system,
    this.issue,
  });

  final GravitaThemeMode mode;
  final ThemePreferencesLoadIssue? issue;
}

abstract interface class ThemePreferencesStore {
  Future<ThemePreferencesLoadResult> load();
  Future<void> save(GravitaThemeMode mode);
}

/// A tiny versioned document. Unknown fields/versions fail to system mode.
abstract final class ThemePreferencesCodec {
  static const int maximumBytes = 512;

  static List<int> encode(GravitaThemeMode mode) => utf8.encode(
    '${jsonEncode(<String, Object>{'schemaVersion': 1, 'themeMode': mode.name})}\n',
  );

  static GravitaThemeMode decode(List<int> bytes) {
    if (bytes.length > maximumBytes) {
      throw const FormatException('Appearance document is too large.');
    }
    final Object? value = jsonDecode(utf8.decode(bytes));
    if (value is! Map<String, dynamic> ||
        value.length != 2 ||
        value['schemaVersion'] is! int ||
        value['schemaVersion'] != 1 ||
        value['themeMode'] is! String) {
      throw const FormatException('Unsupported appearance document.');
    }
    return switch (value['themeMode']) {
      'system' => GravitaThemeMode.system,
      'light' => GravitaThemeMode.light,
      'dark' => GravitaThemeMode.dark,
      _ => throw const FormatException('Unknown appearance mode.'),
    };
  }
}
