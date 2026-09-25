import 'package:flutter/widgets.dart';
import 'package:motion_account/motion_account.dart';

import 'app/gravita_app.dart';
import 'app/motion_account_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final (runtime, accountConnection) = await initializeMotionAccount();
    runApp(
      MotionIdentityGate(
        runtime: runtime,
        child: GravitaApp(accountConnection: accountConnection),
      ),
    );
  } on Object {
    runApp(const AccountStartupFailure());
  }
}
