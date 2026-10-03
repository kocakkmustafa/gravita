import 'package:flutter/material.dart';
import 'package:motion_account/motion_account.dart';
import 'package:path_provider/path_provider.dart';

import 'account_connection.dart';
import 'account_data_directory.dart';
import 'account_store_epoch.dart';
import 'app_locale.dart';
import 'gravita_account_page.dart';

const _url = String.fromEnvironment('MOTION_SUPABASE_URL');
const _publishableKey = String.fromEnvironment(
  'MOTION_SUPABASE_PUBLISHABLE_KEY',
);
const _redirect = 'com.yulalab.gravita://auth/callback';

/// The shared identity comes from Core. Gravita clears only its own local
/// account directory after Core confirms common-account deletion.
Future<(MotionAccountRuntime, AccountConnection)>
initializeMotionAccount() async {
  await AccountStoreEpochRegistry.enableManagedAdmission();
  final supportRoot = await getApplicationSupportDirectory();
  Future<void> clearLocalAccountData(String userId) async {
    await AccountStoreEpochRegistry.beginConfirmedAccountErasure(
      userId,
      () => deleteAccountData(supportRoot, userId),
    );
  }

  final runtime = await MotionAccountRuntime.initialize(
    url: _url,
    publishableKey: _publishableKey,
    app: MotionApp.gravita,
    emailRedirectTo: _redirect,
    onDeletedAccount: clearLocalAccountData,
    localAccountIds: () => localAccountIds(supportRoot),
  );
  return (runtime, bindGravitaMotionAccount(runtime, clearLocalData: clearLocalAccountData));
}

/// Retained owner lifetime is distinct from fresh credential admission.
AccountConnection bindGravitaMotionAccount(MotionAccountRuntime runtime, {
  required Future<void> Function(String userId) clearLocalData,
}) {
  Widget accountPage(BuildContext _) => GravitaAccountPage(
    client: runtime.account,
    passwordRecovery: runtime.passwordRecovery,
    identityAdmissionChanges: Listenable.merge([runtime.phase, runtime.identityVerification]),
    isIdentityAdmitted: () =>
        runtime.isCurrentSessionVerified &&
        !runtime.passwordRecovery.value,
    clearLocalData: clearLocalData,
    onRetryIdentity: runtime.refreshIdentity,
  );
  final connection = AccountConnection(
    userId: runtime.userId,
    passwordRecovery: runtime.passwordRecovery,
    identityAdmissionChanges: runtime.phase,
    currentIdentityChanges: runtime.identityVerification,
    isCurrentIdentityVerified: () => runtime.isCurrentSessionVerified ||
        (!runtime.isDisposed &&
         runtime.phase.value == MotionIdentityPhase.signedOut &&
         runtime.account.supabase.auth.currentSession == null),
    ownerSessionChanges: runtime.account.authChanges
        .where(
          (state) => const {
            'signedIn',
            'signedOut',
            'passwordRecovery',
          }.contains(state.event.name),
        )
        .map<void>((_) {}),
    isIdentityAdmitted: () =>
        (!runtime.isDisposed &&
         runtime.phase.value == MotionIdentityPhase.signedOut &&
         runtime.account.supabase.auth.currentSession == null) ||
        (!runtime.isDisposed &&
         runtime.phase.value == MotionIdentityPhase.verified &&
         runtime.userId.value != null &&
         runtime.userId.value == runtime.account.supabase.auth.currentSession?.user.id),
    pageBuilder: accountPage,
    requirePaidAccess: (context) => requireMotionPaidAccess(
      context,
      account: runtime.account,
      accountPageBuilder: accountPage,
    ),
  );
  return connection;
}

/// Invalid build settings must not silently allow the guest shell.
class AccountStartupFailure extends StatelessWidget {
  const AccountStartupFailure({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              localized(
                context,
                'Sign-in is unavailable in this build. Please try an updated version.',
                'Bu sürümde giriş kullanılamıyor. Lütfen güncel bir sürüm deneyin.',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
}
