import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_connection.dart';
import 'package:gravita/app/account_store_epoch.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/gravita_account_page.dart';
import 'package:gravita/app/profile_screen.dart';

import 'account_action_ticket_test.dart' show AccountHttpFixture, ticketAlice;
import 'support/locale_asset_harness.dart'
    show warmActualLocaleAssets, pumpActualLocaleReady;

/// GRV-10: store subscription management and the Profile membership entry.
/// Both use Core's own 14-language strings; Gravita adds no new keys.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(warmActualLocaleAssets);

  test('store subscription settings point at the right store', () {
    expect(
      gravitaStoreSubscriptionsUri(TargetPlatform.android).toString(),
      'https://play.google.com/store/account/subscriptions?package=com.yulalab.gravita',
    );
    expect(
      gravitaStoreSubscriptionsUri(TargetPlatform.iOS).toString(),
      'https://apps.apple.com/account/subscriptions',
    );
  });

  group('profile membership entry', () {
    late ContentRepository content;
    setUpAll(() async => content = await ContentRepository.load(rootBundle));

    Future<void> show(
      WidgetTester tester, {
      required String? currentUserId,
      required bool sales,
    }) async {
      final userId = ValueNotifier<String?>(currentUserId);
      addTearDown(userId.dispose);
      await tester.pumpWidget(
        AccountScope(
          connection: AccountConnection(
            userId: userId,
            pageBuilder: (_) => const Scaffold(body: Text('ACCOUNT_PAGE_TEST')),
            membershipPageBuilder: sales
                ? (_) => const Scaffold(body: Text('MEMBERSHIP_PAGE_TEST'))
                : null,
          ),
          currentUserId: currentUserId,
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            home: ProfileScreen(content: content),
          ),
        ),
      );
      await pumpActualLocaleReady(tester);
      await tester.pump();
    }

    testWidgets('signed in with sales open: opens the membership page', (
      tester,
    ) async {
      await show(tester, currentUserId: ticketAlice, sales: true);
      expect(find.byKey(ProfileScreen.membershipKey), findsOneWidget);
      expect(find.text('Membership options'), findsOneWidget);
      await tester.tap(find.byKey(ProfileScreen.membershipKey));
      await tester.pumpAndSettle();
      expect(find.text('MEMBERSHIP_PAGE_TEST'), findsOneWidget);
    });

    testWidgets('guest does not see it; Account stays the way in', (
      tester,
    ) async {
      await show(tester, currentUserId: null, sales: true);
      expect(find.byKey(ProfileScreen.membershipKey), findsNothing);
      expect(find.text('Account'), findsOneWidget);
    });

    testWidgets('closed sales hide it', (tester) async {
      await show(tester, currentUserId: ticketAlice, sales: false);
      expect(find.byKey(ProfileScreen.membershipKey), findsNothing);
    });
  });

  group('account page manage subscription', () {
    late AccountHttpFixture fixture;
    setUp(() async {
      await AccountStoreEpochRegistry.resetForTest();
      await AccountStoreEpochRegistry.enableManagedAdmission();
      AccountStoreEpochRegistry.activate(ticketAlice);
      fixture = AccountHttpFixture();
      await fixture.session(ticketAlice);
    });
    tearDown(() async {
      await fixture.dispose();
      await AccountStoreEpochRegistry.resetForTest();
    });

    Future<void> show(
      WidgetTester tester, {
      required bool sales,
      required Future<bool> Function(Uri) open,
      TargetPlatform platform = TargetPlatform.android,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          locale: const Locale('en'),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: GravitaAccountPage(
            client: fixture.account,
            membershipAvailable: sales,
            openStoreUrl: open,
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump();
      }
    }

    // The page starts a membership read with sales on; its 10 s client
    // deadline outlives the fake-async test (Core R1: swallowed when late).
    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 11));
    }

    testWidgets('opens the Play subscriptions filtered to Gravita', (
      tester,
    ) async {
      final opened = <Uri>[];
      await show(
        tester,
        sales: true,
        open: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      final button = find.text('Manage store subscription');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(opened, [gravitaStoreSubscriptionsUri(TargetPlatform.android)]);
      expect(find.byType(SnackBar), findsNothing);
      await finish(tester);
    });

    testWidgets('iOS opens App Store subscriptions; failure is reported', (
      tester,
    ) async {
      final opened = <Uri>[];
      await show(
        tester,
        sales: true,
        platform: TargetPlatform.iOS,
        open: (uri) async {
          opened.add(uri);
          throw StateError('no store app');
        },
      );
      final button = find.text('Manage store subscription');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(opened, [gravitaStoreSubscriptionsUri(TargetPlatform.iOS)]);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finish(tester);
    });

    testWidgets('closed sales hide the store link', (tester) async {
      await show(tester, sales: false, open: (_) async => true);
      expect(find.text('Manage store subscription'), findsNothing);
      expect(find.text('Sign out'), findsOneWidget);
      await finish(tester);
    });
  });
}
