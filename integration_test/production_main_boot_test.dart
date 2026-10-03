import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gravita/main.dart' as production;
import 'package:gravita/app/gravita_app.dart';
import 'package:gravita/app/onboarding_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('production main guest boot reaches usable gravita screen', (tester) async {
    await production.main();
    bool ready() => find.byType(OnboardingFlow).evaluate().isNotEmpty ||
        find.byType(GravitaShell).evaluate().isNotEmpty;
    for (var i = 0; i < 600 && !ready(); i++) {
      await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(GravitaApp), findsOneWidget);
    expect(ready(), isTrue,
        reason: 'Production main must reach interactive onboarding or content');
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    debugPrint('MOTION_MAIN_BOOT_READY_gravita');
    await Future<void>.delayed(const Duration(seconds: 3));
  });
}
