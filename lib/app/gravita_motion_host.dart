import 'package:flutter/material.dart';
import 'package:motion_account/motion_account.dart';

import 'app_locale.dart';
import 'language_preferences.dart';
import 'theme.dart';
import 'theme_preferences.dart';

/// App presentation only. The caller owns the runtime, controllers and child.
/// Locale/theme changes do not retire account tickets or replace the child key.
class GravitaMotionHost extends StatefulWidget {
  const GravitaMotionHost({
    required this.runtime,
    required this.themePreferences,
    required this.languagePreferences,
    required this.child,
    super.key,
  });

  final MotionAccountRuntime runtime;
  final ThemePreferencesController themePreferences;
  final LanguagePreferencesController languagePreferences;
  final Widget child;

  @override
  State<GravitaMotionHost> createState() => _GravitaMotionHostState();
}

class _GravitaMotionHostState extends State<GravitaMotionHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.themePreferences.addListener(_presentationChanged);
    widget.languagePreferences.addListener(_presentationChanged);
  }

  void _presentationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeLocales(List<Locale>? locales) => _presentationChanged();

  @override
  void didChangePlatformBrightness() => _presentationChanged();

  @override
  void didUpdateWidget(covariant GravitaMotionHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.themePreferences, widget.themePreferences)) {
      oldWidget.themePreferences.removeListener(_presentationChanged);
      widget.themePreferences.addListener(_presentationChanged);
    }
    if (!identical(oldWidget.languagePreferences, widget.languagePreferences)) {
      oldWidget.languagePreferences.removeListener(_presentationChanged);
      widget.languagePreferences.addListener(_presentationChanged);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.themePreferences.removeListener(_presentationChanged);
    widget.languagePreferences.removeListener(_presentationChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale =
        widget.languagePreferences.locale ??
        resolveAppLocales(
          WidgetsBinding.instance.platformDispatcher.locales,
          appSupportedLocales,
        );
    return MotionIdentityGate(
      runtime: widget.runtime,
      theme: GravitaTheme.light,
      darkTheme: GravitaTheme.dark,
      themeMode: widget.themePreferences.themeMode,
      locale: locale,
      child: widget.child,
    );
  }
}
