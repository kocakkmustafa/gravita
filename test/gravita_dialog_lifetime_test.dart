import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_action_ticket.dart';
import 'package:gravita/app/account_store_epoch.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/gravita_account_page.dart';
import 'package:motion_account/motion_account.dart';

import 'account_action_ticket_test.dart'
    show AccountHttpFixture, ticketAlice;

/// Staged only: root runs this against the explicitly selected disposable
/// package_config. The imported fixture uses real Core/Supabase clients with
/// synthetic HTTP. No native/provider acceptance or test execution is claimed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AccountHttpFixture fixture;
  late AccountStoreEpoch epoch;

  setUp(() async {
    await AccountStoreEpochRegistry.resetForTest();
    await AccountStoreEpochRegistry.enableManagedAdmission();
    epoch = AccountStoreEpochRegistry.activate(ticketAlice);
    fixture = AccountHttpFixture();
    await fixture.session(ticketAlice);
  });

  tearDown(() async {
    await fixture.dispose();
    await AccountStoreEpochRegistry.resetForTest();
  });

  testWidgets(
    'refresh remounts dialog owner then retained dialog locale rebuild is safe and stale confirmation dispatches nothing',
    (tester) async {
      final harness = _DialogHarness(fixture);
      try {
        await tester.pumpWidget(harness.widget);
        await tester.pump();
        final wrapper = tester.state<State<GravitaAccountPage>>(
          find.byType(GravitaAccountPage),
        );
        final owner = tester.state<State<MotionAccountPage>>(
          find.byType(MotionAccountPage),
        );
        final before = tester.widget<MotionAccountPage>(
          find.byType(MotionAccountPage),
        );
        expect(wrapper.mounted, isTrue);
        expect(owner.mounted, isTrue);
        expect(_ticket(before).epoch, same(epoch));
        final navigator = harness.navigator.currentState!;
        final route = await _openDeletionDialog(tester);
        expect(route.navigator, same(navigator));
        expect(route.isCurrent, isTrue);

        await tester.runAsync(() => fixture.client.auth.refreshSession());
        await _until(
          tester,
          () => !owner.mounted,
          'refresh must actually unmount the old Core dialog owner',
        );
        final after = tester.widget<MotionAccountPage>(
          find.byType(MotionAccountPage),
        );
        final freshOwner = tester.state<State<MotionAccountPage>>(
          find.byType(MotionAccountPage),
        );
        expect(after.key, isNot(before.key));
        expect(freshOwner, isNot(same(owner)));
        expect(freshOwner.mounted, isTrue);
        expect(
          wrapper.mounted,
          isTrue,
          reason: 'the wrapper remains; its Core account child remounts',
        );
        expect(
          tester.state<State<GravitaAccountPage>>(
            find.byType(GravitaAccountPage),
          ),
          same(wrapper),
        );
        expect(_ticket(after).epoch, same(epoch));
        _expectAuthAndEpoch(fixture, epoch, 'synthetic-A-refreshed');
        _expectRetainedDialog(tester, harness, navigator, route);
        expect(
          tester.takeException(),
          isNull,
          reason: 'refresh itself must not produce a framework error',
        );

        harness.locale.value = const Locale('tr');
        await _finishFrame(tester);
        expect(
          tester.takeException(),
          isNull,
          reason: 'retained dialog rebuild must not read disposed page context',
        );
        _expectRetainedDialog(tester, harness, navigator, route);
        expect(
          Localizations.localeOf(tester.element(find.byType(AlertDialog)))
              .languageCode,
          'tr',
          reason: 'the retained dialog actually received the changed locale',
        );
        await _attemptStaleConfirmThenClose(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(fixture.deletions, isEmpty);
        expect(harness.cleanedIds, isEmpty);
        expect(fixture.logoutCalls, 0);
        _expectAuthAndEpoch(fixture, epoch, 'synthetic-A-refreshed');
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _turn(tester);
        harness.dispose();
        // Consume only through a failing assertion; never suppress framework
        // failures in teardown or replace FlutterError.onError.
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'removed account page leaves a retained dialog whose locale rebuild and close preserve Auth without RPC or cleanup',
    (tester) async {
      final harness = _DialogHarness(fixture);
      try {
        await tester.pumpWidget(harness.widget);
        await tester.pump();
        final wrapper = tester.state<State<GravitaAccountPage>>(
          find.byType(GravitaAccountPage),
        );
        final owner = tester.state<State<MotionAccountPage>>(
          find.byType(MotionAccountPage),
        );
        final navigator = harness.navigator.currentState!;
        final route = await _openDeletionDialog(tester);
        expect(wrapper.mounted, isTrue);
        expect(owner.mounted, isTrue);
        harness.showPage.value = false;
        await tester.pump();
        expect(wrapper.mounted, isFalse);
        expect(owner.mounted, isFalse);
        expect(find.byType(GravitaAccountPage), findsNothing);
        expect(find.byType(MotionAccountPage), findsNothing);
        expect(find.byKey(const Key('account-page-removed')), findsOneWidget);
        _expectRetainedDialog(tester, harness, navigator, route);
        expect(tester.takeException(), isNull);

        harness.locale.value = const Locale('tr');
        await _finishFrame(tester);
        expect(
          tester.takeException(),
          isNull,
          reason: 'dialog locale rebuild must survive real parent disposal',
        );
        _expectRetainedDialog(tester, harness, navigator, route);
        expect(
          Localizations.localeOf(tester.element(find.byType(AlertDialog)))
              .languageCode,
          'tr',
        );
        // First scenario attempts stale confirmation; this scenario exercises
        // the close action after both real owner States have been disposed.
        await tester.tap(_dialogCancel());
        await _finishFrame(tester);
        await _turn(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(fixture.deletions, isEmpty);
        expect(harness.cleanedIds, isEmpty);
        expect(fixture.logoutCalls, 0);
        _expectAuthAndEpoch(fixture, epoch, 'synthetic-A-old');
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _turn(tester);
        harness.dispose();
        expect(tester.takeException(), isNull);
      }
    },
  );
}

final class _DialogHarness {
  _DialogHarness(this.fixture);

  final AccountHttpFixture fixture;
  final navigator = GlobalKey<NavigatorState>();
  final locale = ValueNotifier<Locale>(const Locale('en'));
  final showPage = ValueNotifier<bool>(true);
  final cleanedIds = <String>[];
  final pageKey = GlobalKey();

  Widget get widget => ValueListenableBuilder<Locale>(
    valueListenable: locale,
    builder: (context, value, child) => MaterialApp(
      navigatorKey: navigator,
      locale: value,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      home: ValueListenableBuilder<bool>(
        valueListenable: showPage,
        builder: (context, visible, child) => visible
            ? GravitaAccountPage(
                key: pageKey,
                client: fixture.account,
                clearLocalData: (id) async => cleanedIds.add(id),
              )
            : const Scaffold(
                key: Key('account-page-removed'),
                body: Text('Account page removed'),
              ),
      ),
    ),
  );

  void dispose() {
    locale.dispose();
    showPage.dispose();
  }
}

AccountActionTicket _ticket(MotionAccountPage page) =>
    (page.account as EpochBoundMotionAccountClient).ticket!;

void _expectAuthAndEpoch(
  AccountHttpFixture fixture,
  AccountStoreEpoch epoch,
  String token,
) {
  expect(fixture.client.auth.currentUser?.id, ticketAlice);
  expect(fixture.client.auth.currentSession?.accessToken, token);
  expect(AccountStoreEpochRegistry.capture(ticketAlice), same(epoch));
  expect(epoch.isActive, isTrue);
  expect(epoch.writeLease.isActive, isTrue);
  epoch.checkCurrent();
}

Future<Route<dynamic>> _openDeletionDialog(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Delete Motion account'));
  await tester.tap(find.text('Delete Motion account'));
  await _finishFrame(tester);
  expect(find.byType(AlertDialog), findsOneWidget);
  expect(find.text('Delete account'), findsOneWidget);
  final context = tester.element(find.byType(AlertDialog));
  expect(Localizations.localeOf(context).languageCode, 'en');
  return ModalRoute.of(context)!;
}

void _expectRetainedDialog(
  WidgetTester tester,
  _DialogHarness harness,
  NavigatorState navigator,
  Route<dynamic> route,
) {
  expect(harness.navigator.currentState, same(navigator));
  expect(navigator.mounted, isTrue);
  expect(find.byType(AlertDialog), findsOneWidget);
  expect(ModalRoute.of(tester.element(find.byType(AlertDialog))), same(route));
  expect(route.navigator, same(navigator));
  expect(route.isCurrent, isTrue);
}

Finder _dialogCancel() => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(TextButton),
);

Future<void> _attemptStaleConfirmThenClose(WidgetTester tester) async {
  final confirm = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(FilledButton),
  );
  expect(confirm, findsOneWidget);
  final enabled = tester.widget<FilledButton>(confirm).onPressed != null;
  // The frozen v3 Core labels are Delete account/Hesabı sil, and its confirm
  // is enabled. A future narrow fix may safely disable stale confirmation;
  // tapping that button must still dispatch nothing, then Cancel can close it.
  await tester.tap(confirm);
  await _finishFrame(tester);
  await _turn(tester);
  if (!enabled) {
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(_dialogCancel());
    await _finishFrame(tester);
    await _turn(tester);
  }
}

Future<void> _finishFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

Future<void> _turn(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 5)),
  );
  await tester.pump();
}

Future<void> _until(
  WidgetTester tester,
  bool Function() condition,
  String reason,
) async {
  await tester.pump();
  for (int turn = 0; turn < 40 && !condition(); turn++) {
    await _turn(tester);
  }
  expect(condition(), isTrue, reason: '$reason (40 bounded event turns)');
}
