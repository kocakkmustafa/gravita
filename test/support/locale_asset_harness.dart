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

/// Wait for the actual asynchronous delegates and their resulting content frame.
///
/// Cached asset futures can retain their real async zone even after warmup.
/// Alternate real event-loop turns with fake frames, with a finite turn budget.
/// During a locale reload the old subtree remains visible, so require the scope
/// and actual resource to match the requested Localizations widget locale.
Future<void> pumpActualLocaleReady(WidgetTester tester) async {
  final localizedApps = find.byWidgetPredicate(
    (widget) =>
        widget is Localizations &&
        widget.isApplicationLevel &&
        widget.delegates.any(
          (delegate) => delegate is GravitaLocalizationsDelegate,
        ),
  );

  bool ready() {
    final navigators = find.byType(Navigator);
    if (localizedApps.evaluate().length != 1 || navigators.evaluate().isEmpty) {
      return false;
    }
    final requested = tester.widget<Localizations>(localizedApps.first).locale;
    final context = tester.element(navigators.first);
    final resource = Localizations.of<GravitaLocalizations>(
      context,
      GravitaLocalizations,
    );
    return Localizations.localeOf(context) == requested &&
        resource?.localeTag == canonicalLocaleTag(requested.toLanguageTag());
  }

  await tester.pump();
  var turns = 0;
  while (turns < 16 && !ready()) {
    await tester.runAsync<void>(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    turns++;
  }
  final requested = localizedApps.evaluate().isEmpty
      ? null
      : tester.widget<Localizations>(localizedApps.first).locale;
  final navigators = find.byType(Navigator);
  final context = navigators.evaluate().isEmpty
      ? null
      : tester.element(navigators.first);
  expect(
    ready(),
    isTrue,
    reason:
        'Actual locale readiness exhausted after $turns event-loop turns: '
        'applicationLocalizations=${localizedApps.evaluate().length}, '
        'requested=$requested, '
        'scope=${context == null ? null : Localizations.maybeLocaleOf(context)}, '
        'resource=${context == null ? null : Localizations.of<GravitaLocalizations>(context, GravitaLocalizations)?.localeTag}, '
        'navigators=${navigators.evaluate().length}, '
        'scheduledFrame=${tester.binding.hasScheduledFrame}',
  );
  expect(localizedApps, findsOneWidget);
  final navigator = find.byType(Navigator);
  expect(navigator, findsWidgets);
  expect(
    Localizations.of<GravitaLocalizations>(
      tester.element(navigator.first),
      GravitaLocalizations,
    ),
    isNotNull,
  );
  expect(Localizations.localeOf(tester.element(navigator.first)), requested);
  expect(
    Localizations.of<GravitaLocalizations>(
      tester.element(navigator.first),
      GravitaLocalizations,
    )?.localeTag,
    canonicalLocaleTag(requested!.toLanguageTag()),
  );
}
