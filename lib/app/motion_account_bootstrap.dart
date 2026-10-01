import 'package:flutter/material.dart';
import 'package:motion_account/motion_account.dart';
import 'package:path_provider/path_provider.dart';

import 'account_connection.dart';
import 'account_data_directory.dart';
import 'app_locale.dart';

const _url = String.fromEnvironment('MOTION_SUPABASE_URL');
const _publishableKey = String.fromEnvironment(
  'MOTION_SUPABASE_PUBLISHABLE_KEY',
);
const _redirect = 'com.yulalab.gravita://auth/callback';

/// The shared identity comes from Core. Gravita clears only its own local
/// account directory after Core confirms common-account deletion.
Future<(MotionAccountRuntime, AccountConnection)>
initializeMotionAccount() async {
  Future<void> clearLocalAccountData(String userId) async {
    await deleteAccountData(await getApplicationSupportDirectory(), userId);
  }

  final runtime = await MotionAccountRuntime.initialize(
    url: _url,
    publishableKey: _publishableKey,
    app: MotionApp.gravita,
    emailRedirectTo: _redirect,
    onDeletedAccount: clearLocalAccountData,
    localAccountIds: () async =>
        localAccountIds(await getApplicationSupportDirectory()),
  );
  Widget accountPage(BuildContext _) => MotionAccountPage(
    account: runtime.account,
    initialPasswordRecovery: runtime.isPasswordRecovery,
    clearLocalData: clearLocalAccountData,
    onRetryIdentity: runtime.refreshIdentity,
  );
  final connection = AccountConnection(
    userId: runtime.userId,
    pageBuilder: accountPage,
    requirePaidAccess: (context) => requireMotionPaidAccess(
      context,
      account: runtime.account,
      accountPageBuilder: accountPage,
    ),
  );
  return (runtime, connection);
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
