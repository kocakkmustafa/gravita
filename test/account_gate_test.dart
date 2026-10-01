import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_connection.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/gravita_app.dart';
import 'package:gravita/app/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const first = '11111111-1111-4111-8111-111111111111';
  const second = '22222222-2222-4222-8222-222222222222';
  late ContentRepository content;

  setUpAll(() async => content = await ContentRepository.load(rootBundle));

  testWidgets('guest can browse; account switch resets the shell', (
    tester,
  ) async {
    final userId = ValueNotifier<String?>(null);
    addTearDown(userId.dispose);
    await tester.pumpWidget(
      GravitaApp(
        accountConnection: AccountConnection(
          userId: userId,
          pageBuilder: (_) => const Scaffold(body: Text('ACCOUNT_PAGE_TEST')),
        ),
      ),
    );
    expect(find.text('ACCOUNT_PAGE_TEST'), findsNothing);
    expect(find.byType(GravitaRoot), findsOneWidget);

    userId.value = first;
    await tester.pump();
    expect(find.byType(GravitaRoot), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).key,
      const ValueKey<String>('gravita-account-$first'),
    );

    userId.value = second;
    await tester.pump();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).key,
      const ValueKey<String>('gravita-account-$second'),
    );

    userId.value = null;
    await tester.pump();
    expect(find.text('ACCOUNT_PAGE_TEST'), findsNothing);
    expect(find.byType(GravitaRoot), findsOneWidget);
  });

  testWidgets('profile opens the real account page entry', (tester) async {
    final userId = ValueNotifier<String?>(first);
    addTearDown(userId.dispose);
    await tester.pumpWidget(
      AccountScope(
        connection: AccountConnection(
          userId: userId,
          pageBuilder: (_) => const Scaffold(body: Text('ACCOUNT_PAGE_TEST')),
        ),
        currentUserId: first,
        child: MaterialApp(home: ProfileScreen(content: content)),
      ),
    );
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(find.text('ACCOUNT_PAGE_TEST'), findsOneWidget);
  });
}
