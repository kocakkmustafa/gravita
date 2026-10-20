import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app_locale.dart' show localeForAppTag;
import 'language_preferences_codec.dart';
import 'language_preferences_io.dart';

export 'language_preferences_codec.dart';

/// Load before runApp so the first Flutter frame uses the saved display locale.
Future<LanguagePreferencesController> loadDeviceLanguagePreferences({
  LanguagePreferencesStore? store,
}) async {
  final selectedStore = store ?? _DeviceLanguagePreferencesStore();
  // Startup must not wait indefinitely for the platform directory or disk.
  // A late readonly load result is ignored; saving has no timeout/retry here.
  LanguagePreferencesLoadResult initial;
  try {
    initial = await selectedStore.load().timeout(
      const Duration(seconds: 3),
      onTimeout: () => const LanguagePreferencesLoadResult(
        issue: LanguagePreferencesLoadIssue.unavailable,
      ),
    );
  } on Object {
    initial = const LanguagePreferencesLoadResult(
      issue: LanguagePreferencesLoadIssue.unavailable,
    );
  }
  return LanguagePreferencesController(store: selectedStore, initial: initial);
}

class _DeviceLanguagePreferencesStore implements LanguagePreferencesStore {
  FileLanguagePreferencesStore? _opened;

  Future<FileLanguagePreferencesStore> _open() async {
    if (_opened != null) return _opened!;
    final directory = await getApplicationSupportDirectory();
    return _opened ??= FileLanguagePreferencesStore.inDirectory(directory);
  }

  @override
  Future<LanguagePreferencesLoadResult> load() async {
    try {
      return await (await _open()).load();
    } on Object {
      return const LanguagePreferencesLoadResult(
        issue: LanguagePreferencesLoadIssue.unavailable,
      );
    }
  }

  @override
  Future<void> save(String? selectedTag) async =>
      (await _open()).save(selectedTag);
}

class LanguagePreferencesController extends ChangeNotifier {
  LanguagePreferencesController({
    required LanguagePreferencesStore store,
    required LanguagePreferencesLoadResult initial,
  }) : _store = store,
       _selectedTag =
           initial.issue == null &&
               LanguagePreferencesCodec.isExactSelection(initial.selectedTag)
           ? initial.selectedTag
           : null,
       _loadIssue =
           initial.issue ??
           (LanguagePreferencesCodec.isExactSelection(initial.selectedTag)
               ? null
               : LanguagePreferencesLoadIssue.invalid);

  LanguagePreferencesController.ephemeral({String? selectedTag})
    : _store = null,
      _selectedTag = _requireExactSelection(selectedTag);

  final LanguagePreferencesStore? _store;
  String? _selectedTag;
  LanguagePreferencesLoadIssue? _loadIssue;
  int _revision = 0;
  int _pendingWrites = 0;
  bool _saveFailed = false;
  bool _disposed = false;
  Future<void> _writes = Future<void>.value();

  String? get selectedTag => _selectedTag;
  Locale? get locale =>
      _selectedTag == null ? null : localeForAppTag(_selectedTag!);
  LanguagePreferencesLoadIssue? get loadIssue => _loadIssue;
  bool get saving => _pendingWrites > 0;
  bool get saveFailed => _saveFailed;

  static String? _requireExactSelection(String? selectedTag) {
    if (!LanguagePreferencesCodec.isExactSelection(selectedTag)) {
      throw ArgumentError.value(
        selectedTag,
        'selectedTag',
        'Unsupported app language',
      );
    }
    return selectedTag;
  }

  Future<void> setSelectedTag(String? selectedTag) async {
    if (_disposed) return;
    _requireExactSelection(selectedTag);
    if (selectedTag == _selectedTag && !_saveFailed && _loadIssue == null) {
      return;
    }
    _selectedTag = selectedTag;
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
    final write = _writes.then((_) => store.save(selectedTag));
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

  Future<void> retrySave() => setSelectedTag(_selectedTag);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class LanguagePreferencesScope
    extends InheritedNotifier<LanguagePreferencesController> {
  const LanguagePreferencesScope({
    required LanguagePreferencesController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static LanguagePreferencesController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<LanguagePreferencesScope>();
    assert(scope != null, 'LanguagePreferencesScope is required.');
    return scope!.notifier!;
  }

  static LanguagePreferencesController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LanguagePreferencesScope>()
      ?.notifier;
}
