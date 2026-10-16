import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/movement_page.dart';
import 'package:gravita/app/theme.dart';

class _LifecycleLog extends WidgetsBindingObserver {
  final states = <AppLifecycleState>[];
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => states.add(state);
}

/// The host must foreground iOS Settings after READY, then this running app.
/// No lifecycle events are injected. This is synthetic catalogue UI acceptance,
/// separate from production main, auth, camera, purchase and physical technique.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native Turkish320px/2x catalogue survives real OS return', (
    tester,
  ) async {
    final content = await ContentRepository.load(rootBundle);
    await content.catalogFor('bird_dog');
    final lifecycle = _LifecycleLog();
    WidgetsBinding.instance.addObserver(lifecycle);
    addTearDown(() => WidgetsBinding.instance.removeObserver(lifecycle));
    await tester.pumpWidget(
      MaterialApp(
        theme: GravitaTheme.light,
        locale: const Locale('tr'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        builder: (context, child) => Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            key: const Key('native.catalogue.width'),
            width: 320,
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
          ),
        ),
        home: MovementPage(
          content: content,
          movement: content.catalogue.byId('bird_dog')!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('native.catalogue.width'))).width,
      320,
    );
    for (final key in [
      MovementPage.honestyKey,
      MovementPage.queueKey,
      MovementPage.formErrorsKey,
    ]) {
      await tester.scrollUntilVisible(
        find.byKey(key),
        300,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 200,
      );
      await tester.ensureVisible(find.byKey(key));
      await tester.pumpAndSettle();
      if (key == MovementPage.queueKey) {
        expect(
          find.text(
            'Bu açıklamalar ölçüm kataloğuna aittir. Canlı kamera oturumları ve kamera geri bildirimi bu sürümde kullanılamıyor.',
          ),
          findsOneWidget,
        );
      }
    }
    final cue = find.text('Reach long, not high — keep your back flat.');
    expect(cue, findsNothing);
    const translatedCue = 'Yükseğe değil, uzağa uzan — sırtını düz tut.';
    // The reviewed fixture is the exact expected on-screen cue.
    expect(find.text(translatedCue), findsOneWidget);
    final element = tester.element(find.byType(MovementPage));
    final route = ModalRoute.of(element);
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    expect(find.byKey(MovementPage.startSessionKey), findsNothing);
    expect(tester.takeException(), isNull);
    debugPrint('GRAVITA_OS_BACKGROUND_READY');
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (!(lifecycle.states.contains(AppLifecycleState.paused) &&
            lifecycle.states.last == AppLifecycleState.resumed) &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
    expect(lifecycle.states, contains(AppLifecycleState.paused));
    expect(lifecycle.states.last, AppLifecycleState.resumed);
    expect(
      identical(tester.element(find.byType(MovementPage)), element),
      isTrue,
    );
    expect(identical(ModalRoute.of(element), route), isTrue);
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      scroll,
    );
    expect(find.text(translatedCue), findsOneWidget);
    expect(find.byKey(MovementPage.startSessionKey), findsNothing);
    expect(tester.takeException(), isNull);
    debugPrint(
      'GRAVITA_OS_RESUME_PASS states=${lifecycle.states.map((s) => s.name).join(",")} sameElement=true sameRoute=true sameScroll=true width=320 textScale=2',
    );
  });
}
