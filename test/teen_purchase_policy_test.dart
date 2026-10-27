import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/paywall_policy.dart';
import 'package:motion_account/motion_account.dart';

// K-2 (founder decision 2026-10-27) on Core R4: Gravita leaves 13–17 purchases
// to the store's family controls. Core keeps parentalConsentRequired as its
// default, so every Core purchase entry point Gravita opens must carry the
// app's choice; a missing argument silently falls back to the Core default.
void main() {
  test('Gravita selects store family controls, not the Core default', () {
    expect(
      gravitaTeenPurchasePolicy,
      MotionTeenPurchasePolicy.storeFamilyControls,
    );
    expect(
      const MotionAccountPage(account: _NeverAccount()).teenPurchasePolicy,
      MotionTeenPurchasePolicy.parentalConsentRequired,
      reason: 'Core default unchanged; Gravita must pass its policy',
    );
    expect(
      const MotionMembershipPage(account: _NeverAccount()).teenPurchasePolicy,
      MotionTeenPurchasePolicy.parentalConsentRequired,
      reason: 'Core default unchanged; Gravita must pass its policy',
    );
  });

  // The account page test pumps the production page and reads the policy;
  // this guards the call sites that only open on a purchase (the membership
  // builder and the paid gate), which Core R4 tests for forwarding.
  test('every Core purchase entry point passes the Gravita policy', () {
    final entries = <String, List<String>>{
      'lib/app/motion_account_bootstrap.dart': [
        'MotionMembershipPage(',
        'requireMotionPaidAccess(',
      ],
      'lib/app/gravita_account_page.dart': ['MotionAccountPage('],
    };
    for (final MapEntry(key: path, value: calls) in entries.entries) {
      final source = File(path).readAsStringSync();
      for (final entry in calls) {
        final start = source.indexOf(entry);
        expect(start, isNonNegative, reason: '$path $entry');
        expect(source.indexOf(entry, start + 1), -1, reason: '$path $entry');
        final call = source.substring(start, _closingParen(source, start));
        expect(
          call,
          contains('teenPurchasePolicy: gravitaTeenPurchasePolicy'),
          reason: '$path $entry',
        );
      }
    }
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final code = file
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        code,
        isNot(contains('requireMotionCameraAccess(')),
        reason: '${file.path}: a camera gate must also pass the policy',
      );
      if (entries.containsKey(file.path)) continue;
      for (final entry in ['MotionMembershipPage(', 'MotionAccountPage(']) {
        expect(
          code,
          isNot(contains(entry)),
          reason: '${file.path}: unguarded Core purchase entry point',
        );
      }
    }
  });
}

int _closingParen(String source, int from) {
  var depth = 0;
  for (var i = source.indexOf('(', from); i < source.length; i++) {
    if (source[i] == '(') depth++;
    if (source[i] == ')' && --depth == 0) return i;
  }
  throw StateError('unbalanced call at $from');
}

final class _NeverAccount implements MotionAccountClient {
  const _NeverAccount();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('not used');
}
