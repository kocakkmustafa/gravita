import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/account_connection.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/gravita_app.dart';
import 'package:gravita/app/live_session_screen.dart';
import 'package:gravita/app/movement_page.dart';
import 'package:gravita_engine/gravita_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Today Push-Up opens the Push-Up measurement contract', (
    WidgetTester tester,
  ) async {
    late ContentRepository content;
    await tester.runAsync(() async {
      content = await ContentRepository.load(rootBundle);
    });
    final MovementConfig? pushUp = content.startableConfigFor('push_up');
    expect(pushUp, isNotNull);
    expect(pushUp!.preconditionDerived, isTrue);
    expect(pushUp.engineType, EngineType.repFsm);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: GravitaShell(content: content),
      ),
    );
    await tester.pump();
    final Finder pushUpCard = find.text('Şınav');
    await tester.ensureVisible(pushUpCard);
    await tester.tap(pushUpCard);
    await tester.pumpAndSettle();

    expect(find.byType(MovementPage), findsOneWidget);
    expect(find.byKey(MovementPage.startSessionKey), findsOneWidget);
    await tester.tap(find.byKey(MovementPage.startSessionKey));
    await tester.pumpAndSettle();

    final LiveSessionScreen session = tester.widget<LiveSessionScreen>(
      find.byType(LiveSessionScreen),
    );
    expect(session.config.id, 'push_up');
    expect(identical(session.config, pushUp), isTrue);
    expect(find.byKey(LiveSessionScreen.startButtonKey), findsOneWidget);
  });

  testWidgets('paid access denied keeps the movement page open', (
    WidgetTester tester,
  ) async {
    late ContentRepository content;
    await tester.runAsync(() async {
      content = await ContentRepository.load(rootBundle);
    });
    final userId = ValueNotifier<String?>(null);
    addTearDown(userId.dispose);
    int guardCalls = 0;
    await tester.pumpWidget(
      AccountScope(
        connection: AccountConnection(
          userId: userId,
          pageBuilder: (_) => const SizedBox.shrink(),
          requirePaidAccess: (_) async {
            guardCalls++;
            return false;
          },
        ),
        currentUserId: null,
        child: MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: GravitaShell(content: content),
        ),
      ),
    );
    await tester.pump();
    final Finder pushUpCard = find.text('Şınav');
    await tester.ensureVisible(pushUpCard);
    await tester.tap(pushUpCard);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(MovementPage.startSessionKey));
    await tester.pumpAndSettle();
    expect(guardCalls, 1);
    expect(find.byType(MovementPage), findsOneWidget);
    expect(find.byType(LiveSessionScreen), findsNothing);
  });
}
