import 'package:flutter/widgets.dart';
import 'package:gravita/app/account_connection.dart';

/// Suites that exercise lessons or practice behaviour (not the paywall
/// itself) run as a subscriber. `paywall_policy_test.dart` covers the gate:
/// free part, refusal, grant and the fail-closed path without a connection.
Future<bool> grantPaidAccess(BuildContext _) async => true;

/// Wraps [child] in an account scope whose paid-access check grants.
Widget asSubscriber(Widget child) => AccountScope(
  connection: AccountConnection(
    userId: ValueNotifier<String?>(null),
    pageBuilder: (_) => const SizedBox.shrink(),
    requirePaidAccess: grantPaidAccess,
  ),
  currentUserId: null,
  child: child,
);
