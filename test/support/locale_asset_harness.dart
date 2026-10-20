import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/localization/locale_delegate.dart';

/// Load the real production resources before a testWidgets fake clock starts.
///
/// Call from setUpAll, not after an asset load has already started in a widget
/// test. Large rootBundle strings use a compute isolate; caching their pending
/// futures in FakeAsync can leave later runAsync calls waiting on that zone.
/// This keeps the production delegates and all parsing/error checks intact.
/// It does not establish native fonts, device rendering or translation meaning.
Future<void> warmActualLocaleAssets() async {
  for (final locale in appSupportedLocales) {
    for (final delegate in appLocalizationsDelegates) {
      if (delegate.isSupported(locale)) await delegate.load(locale);
    }
  }
}

/// Paint the content frame scheduled by the actual asynchronous delegates.
///
/// This is one additional frame, not an unbounded settle or a longer timeout.
/// A missing resource still fails explicitly rather than hiding a blank tree.
Future<void> pumpActualLocaleReady(WidgetTester tester) async {
  await tester.pump();
  final navigator = find.byType(Navigator);
  expect(navigator, findsWidgets);
  expect(
    Localizations.of<GravitaLocalizations>(
      tester.element(navigator.first),
      GravitaLocalizations,
    ),
    isNotNull,
  );
}
