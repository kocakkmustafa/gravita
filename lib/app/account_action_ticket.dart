import 'package:motion_account/motion_account.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session;

import 'account_store_epoch.dart';

/// Authority captured when the account page mounts, before any confirmation
/// dialog. Tokens stay private and are never included in errors or reports.
final class AccountActionTicket {
  AccountActionTicket._(
    this.userId,
    this.epoch,
    this._accessToken,
    this._session,
  );

  final String userId;
  final AccountStoreEpoch epoch;
  final String _accessToken;
  final Session _session;

  static AccountActionTicket? capture(
    MotionAccountClient account, {
    bool isIdentityAdmitted = true,
    bool passwordRecovery = false,
  }) {
    final userId = account.currentUser?.id;
    final session = account.supabase.auth.currentSession;
    if (!isIdentityAdmitted ||
        passwordRecovery ||
        userId == null ||
        session?.user.id != userId ||
        session == null ||
        session.accessToken.isEmpty ||
        AccountStoreEpochRegistry.isAccountErasureBlocked(userId)) {
      return null;
    }
    try {
      return AccountActionTicket._(
        userId,
        AccountStoreEpochRegistry.capture(userId),
        session.accessToken,
        session,
      );
    } on Object {
      // Closed history admission does not block sign-in/password recovery.
      // It only removes authority to start a common-account deletion.
      return null;
    }
  }

  void checkCurrent(MotionAccountClient account) {
    epoch.checkCurrent();
    final session = account.supabase.auth.currentSession;
    if (AccountStoreEpochRegistry.isAccountErasureBlocked(userId) ||
        account.currentUser?.id != userId ||
        session?.user.id != userId ||
        session?.accessToken != _accessToken ||
        !identical(session, _session)) {
      throw StateError(
        'Account action authority changed; reopen the account page',
      );
    }
  }

  bool hasSameAuthority(AccountActionTicket other) =>
      userId == other.userId &&
      identical(epoch, other.epoch) &&
      _accessToken == other._accessToken &&
      identical(_session, other._session);
}

/// Preserve the real Core client and its strict response/UUID handling. Only
/// deletion initiation gains the host's immutable pre-dialog authority check.
class EpochBoundMotionAccountClient extends MotionAccountClient {
  EpochBoundMotionAccountClient({
    required MotionAccountClient original,
    required this.ticket,
  }) : super(
         supabase: original.supabase,
         app: original.app,
         emailRedirectTo: original.emailRedirectTo,
         deletionReceipt: original.deletionReceipt,
         operationTimeout: original.operationTimeout,
         readTimeout: original.readTimeout,
       );

  final AccountActionTicket? ticket;

  @override
  Future<void> deleteCommonAccount({
    Future<void> Function(String userId)? afterRemoteDelete,
  }) {
    final captured = ticket;
    if (captured == null) {
      return Future<void>.error(
        StateError('Account deletion admission is closed'),
      );
    }
    try {
      // This check and the Core invocation have no await between them.
      captured.checkCurrent(this);
      return super.deleteCommonAccount(
        afterRemoteDelete: (confirmedUserId) async {
          if (confirmedUserId != captured.userId) {
            throw StateError('Account deletion owner was not confirmed');
          }
          // A verified remote deletion still cleans its captured UUID after an
          // auth switch. The host erasure callback owns that UUID's admission.
          await afterRemoteDelete?.call(captured.userId);
        },
      );
    } on Object catch (error, stack) {
      return Future<void>.error(error, stack);
    }
  }
}
