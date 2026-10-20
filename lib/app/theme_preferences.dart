import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'theme_preferences_codec.dart';
import 'theme_preferences_io.dart';

export 'theme_preferences_codec.dart';

/// Load before runApp so a saved mode is present on the first Flutter frame.
Future<ThemePreferencesController> loadDeviceThemePreferences() async {
  final store = _DeviceThemePreferencesStore();
  final initial = await store.load().timeout(
    const Duration(seconds: 3),
    onTimeout: () => const ThemePreferencesLoadResult(
      issue: ThemePreferencesLoadIssue.unavailable,
    ),
  );
  return ThemePreferencesController(store: store, initial: initial);
}

class _DeviceThemePreferencesStore implements ThemePreferencesStore {
  Future<FileThemePreferencesStore> _open() async =>
      FileThemePreferencesStore.inDirectory(
        await getApplicationSupportDirectory(),
      );

  @override
  Future<ThemePreferencesLoadResult> load() async {
    try {
      return await (await _open()).load();
    } on Object {
      return const ThemePreferencesLoadResult(
        issue: ThemePreferencesLoadIssue.unavailable,
      );
    }
  }

  @override
  Future<void> save(GravitaThemeMode mode) async => (await _open()).save(mode);
}

class ThemePreferencesController extends ChangeNotifier {
  ThemePreferencesController({
    required ThemePreferencesStore store,
    required ThemePreferencesLoadResult initial,
  }) : _store = store,
       _mode = initial.mode,
       _loadIssue = initial.issue;

  /// Keeps the established GravitaApp() test API free from platform IO.
  ThemePreferencesController.ephemeral({
    GravitaThemeMode mode = GravitaThemeMode.system,
  }) : _store = null,
       _mode = mode;

  final ThemePreferencesStore? _store;
  GravitaThemeMode _mode;
  ThemePreferencesLoadIssue? _loadIssue;
  int _revision = 0;
  int _pendingWrites = 0;
  bool _saveFailed = false;
  bool _disposed = false;
  Future<void> _writes = Future<void>.value();

  GravitaThemeMode get mode => _mode;
  ThemePreferencesLoadIssue? get loadIssue => _loadIssue;
  bool get saving => _pendingWrites > 0;
  bool get saveFailed => _saveFailed;
  ThemeMode get themeMode => switch (_mode) {
    GravitaThemeMode.system => ThemeMode.system,
    GravitaThemeMode.light => ThemeMode.light,
    GravitaThemeMode.dark => ThemeMode.dark,
  };

  Future<void> setMode(GravitaThemeMode mode) async {
    if (_disposed || (mode == _mode && !_saveFailed && _loadIssue == null)) {
      return;
    }
    _mode = mode;
    _saveFailed = false;
    _loadIssue = null;
    final revision = ++_revision;
    final store = _store;
    if (store == null) {
      notifyListeners();
      return;
    }
    _pendingWrites++;
    notifyListeners();
    final write = _writes.then((_) => store.save(mode));
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    try {
      await write;
      if (revision == _revision) _loadIssue = null;
    } on Object {
      if (revision == _revision) _saveFailed = true;
    } finally {
      _pendingWrites--;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> retrySave() => setMode(_mode);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class ThemePreferencesScope
    extends InheritedNotifier<ThemePreferencesController> {
  const ThemePreferencesScope({
    required ThemePreferencesController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static ThemePreferencesController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ThemePreferencesScope>();
    assert(scope != null, 'ThemePreferencesScope is required.');
    return scope!.notifier!;
  }

  static ThemePreferencesController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ThemePreferencesScope>()
      ?.notifier;
}
