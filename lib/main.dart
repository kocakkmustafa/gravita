import 'package:flutter/widgets.dart';
import 'package:motion_account/motion_account.dart';

import 'app/gravita_app.dart';
import 'app/language_preferences.dart';
import 'app/motion_account_bootstrap.dart';
import 'app/theme_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themePreferences = await loadDeviceThemePreferences();
  final languagePreferences = await loadDeviceLanguagePreferences();
  try {
    final (runtime, accountConnection) = await initializeMotionAccount();
    runApp(
      MotionIdentityGate(
        runtime: runtime,
        child: GravitaApp(
          accountConnection: accountConnection,
          themePreferences: themePreferences,
          languagePreferences: languagePreferences,
        ),
      ),
    );
  } on Object {
    runApp(
      AccountStartupFailure(
        themePreferences: themePreferences,
        languagePreferences: languagePreferences,
      ),
    );
  }
}
