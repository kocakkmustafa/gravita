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

  testWidgets(
    'Today Push-Up keeps configured contract but release camera is closed',
    (WidgetTester tester) async {
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
      await tester.pump();
      expect(pushUpCard.hitTestable(), findsOneWidget);
      await tester.tap(pushUpCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(MovementPage), findsOneWidget);
      expect(find.byKey(MovementPage.startSessionKey), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(MovementPage.startSessionKey))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(MovementPage.startSessionKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(LiveSessionScreen), findsNothing);
      expect(content.startableConfigFor('push_up'), same(pushUp));
    },
  );

  testWidgets('release policy prevents reaching account guard or camera page', (
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
    await tester.pump();
    expect(pushUpCard.hitTestable(), findsOneWidget);
    await tester.tap(pushUpCard);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.byKey(MovementPage.startSessionKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(guardCalls, 0);
    expect(find.byType(MovementPage), findsOneWidget);
    expect(find.byType(LiveSessionScreen), findsNothing);
  });
}
