import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:motion_account/motion_account.dart';

import 'account_action_ticket.dart';
import 'account_store_epoch.dart';
import 'paywall_policy.dart';

/// Account UI keeps Core's auth/password behavior while deletion belongs to a
/// pre-dialog UUID, host epoch and session token. Token refresh remounts only
/// this page; it never rotates shared resource or storage ownership.
class GravitaAccountPage extends StatefulWidget {
  const GravitaAccountPage({
    required this.client,
    this.passwordRecovery,
    this.identityAdmissionChanges,
    this.isIdentityAdmitted,
    this.clearLocalData,
    this.onRetryIdentity,
    this.ageBlocked = false,
    this.onAgeBlocked,
    this.paidFeaturesAvailable = gravitaSubscriptionSalesAvailable,
    super.key,
  });

  final MotionAccountClient client;
  final ValueListenable<bool>? passwordRecovery;
  final Listenable? identityAdmissionChanges;
  final bool Function()? isIdentityAdmitted;
  final Future<void> Function(String userId)? clearLocalData;
  final Future<void> Function()? onRetryIdentity;

  /// Durable device under-13 result ([AgeBlockStore]); Core keeps sign-up
  /// closed while it is true. The country rule comes from Core (explicit
  /// countryCode, then store region on newer pins, then device region).
  final bool ageBlocked;
  final VoidCallback? onAgeBlocked;

  /// Subscription sales section of the shared account page (paywall A);
  /// production keeps the default. The camera gate is separate.
  final bool paidFeaturesAvailable;

  @override
  State<GravitaAccountPage> createState() => _GravitaAccountPageState();
}

class _GravitaAccountPageState extends State<GravitaAccountPage> {
  StreamSubscription<dynamic>? _authSubscription;
  AccountActionTicket? _ticket;
  late EpochBoundMotionAccountClient _client;
  Future<void> Function(String userId)? _cleanup;
  int _revision = 0;
  bool _recovering = false;
  bool _authStreamHealthy = true;

  @override
  void initState() {
    super.initState();
    _bind();
    _refreshTicket(force: true, rebuild: false);
  }

  void _bind() {
    widget.passwordRecovery?.addListener(_admissionChanged);
    widget.identityAdmissionChanges?.addListener(_admissionChanged);
    AccountStoreEpochRegistry.admissionChanges.addListener(_admissionChanged);
    _authSubscription = widget.client.authChanges.listen(
      (_) {
        _authStreamHealthy = true;
        _refreshTicket();
      },
      onError: (Object _, StackTrace __) {
        _authStreamHealthy = false;
        _refreshTicket();
      },
    );
  }

  void _unbind() {
    widget.passwordRecovery?.removeListener(_admissionChanged);
    widget.identityAdmissionChanges?.removeListener(_admissionChanged);
    AccountStoreEpochRegistry.admissionChanges.removeListener(
      _admissionChanged,
    );
    final subscription = _authSubscription;
    _authSubscription = null;
    unawaited(_cancelAuth(subscription));
  }

  Future<void> _cancelAuth(StreamSubscription<dynamic>? subscription) async {
    try {
      await subscription?.cancel();
    } on Object {
      // Disposal cannot keep a page/dialog action admitted.
    }
  }

  void _admissionChanged() => _refreshTicket();

  void _refreshTicket({bool force = false, bool rebuild = true}) {
    final recovering = widget.passwordRecovery?.value ?? false;
    final next = AccountActionTicket.capture(
      widget.client,
      passwordRecovery: recovering,
      isIdentityAdmitted:
          _authStreamHealthy && (widget.isIdentityAdmitted?.call() ?? true),
    );
    final same = next == null
        ? _ticket == null
        : _ticket != null && next.hasSameAuthority(_ticket!);
    if (!force && same && recovering == _recovering) return;
    void replace() {
      _ticket = next;
      _recovering = recovering;
      _client = EpochBoundMotionAccountClient(
        original: widget.client,
        ticket: next,
      );
      // Keep the callback selected by this page mount. The confirmed UUID,
      // never mutable currentUser, selects the host erasure namespace.
      final cleanup = widget.clearLocalData;
      _cleanup = cleanup == null
          ? null
          : (confirmedUserId) async {
              if (next == null || confirmedUserId != next.userId) {
                throw StateError('Account deletion cleanup owner changed');
              }
              await cleanup(next.userId);
            };
      _revision++;
    }

    if (rebuild && mounted) {
      setState(replace);
    } else {
      replace();
    }
  }

  @override
  void didUpdateWidget(covariant GravitaAccountPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client != widget.client ||
        oldWidget.passwordRecovery != widget.passwordRecovery ||
        oldWidget.identityAdmissionChanges != widget.identityAdmissionChanges) {
      oldWidget.passwordRecovery?.removeListener(_admissionChanged);
      oldWidget.identityAdmissionChanges?.removeListener(_admissionChanged);
      AccountStoreEpochRegistry.admissionChanges.removeListener(
        _admissionChanged,
      );
      final subscription = _authSubscription;
      _authSubscription = null;
      unawaited(_cancelAuth(subscription));
      _authStreamHealthy = true;
      _bind();
    }
    if (oldWidget.client != widget.client ||
        oldWidget.passwordRecovery != widget.passwordRecovery ||
        oldWidget.identityAdmissionChanges != widget.identityAdmissionChanges ||
        oldWidget.isIdentityAdmitted != widget.isIdentityAdmitted ||
        oldWidget.clearLocalData != widget.clearLocalData ||
        oldWidget.onRetryIdentity != widget.onRetryIdentity) {
      _refreshTicket(force: true, rebuild: false);
    }
  }

  @override
  void dispose() {
    _unbind();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MotionAccountPage(
    key: ValueKey(_revision),
    account: _client,
    initialPasswordRecovery: _recovering,
    clearLocalData: _cleanup,
    onRetryIdentity: widget.onRetryIdentity,
    paidFeaturesAvailable: widget.paidFeaturesAvailable,
    ageBlocked: widget.ageBlocked,
    onAgeBlocked: widget.onAgeBlocked,
  );
}
