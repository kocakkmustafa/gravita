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
    this.passwordRecovery,
    this.identityAdmissionChanges,
    this.isIdentityAdmitted,
    this.isCurrentIdentityVerified,
    this.currentIdentityChanges,
    this.ownerSessionChanges,
  });

  final ValueListenable<String?> userId;
  final WidgetBuilder pageBuilder;

  /// The shared runtime owns this signal, including same-user callbacks.
  final ValueListenable<bool>? passwordRecovery;

  /// The identity gate may close while the UUID itself remains unchanged.
  final Listenable? identityAdmissionChanges;
  final bool Function()? isIdentityAdmitted;

  /// Exact current Session proof for new camera/account admission.
  final bool Function()? isCurrentIdentityVerified;
  final Listenable? currentIdentityChanges;

  /// Fresh sign-in/sign-out/recovery retires resources even for the same UUID.
  /// Normal token refresh is deliberately excluded from this owner stream.
  final Stream<void>? ownerSessionChanges;
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
