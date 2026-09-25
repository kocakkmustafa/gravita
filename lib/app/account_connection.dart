import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Package-independent seam for the shared Motion account screen. The host
/// provides real auth state and a real account page when motion_account can
/// be pinned. No local account or membership is invented here.
class AccountConnection {
  const AccountConnection({
    required this.userId,
    required this.pageBuilder,
    this.requirePaidAccess,
  });

  final ValueListenable<String?> userId;
  final WidgetBuilder pageBuilder;
  final Future<bool> Function(BuildContext)? requirePaidAccess;
}

class AccountScope extends InheritedWidget {
  const AccountScope({
    required this.connection,
    required this.currentUserId,
    required super.child,
    super.key,
  });

  final AccountConnection? connection;
  final String? currentUserId;

  static AccountScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountScope>();

  @override
  bool updateShouldNotify(AccountScope oldWidget) =>
      connection != oldWidget.connection ||
      currentUserId != oldWidget.currentUserId;
}
