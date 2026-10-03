import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_action_ticket.dart';
import 'package:gravita/app/account_store_epoch.dart';
import 'package:motion_account/motion_account.dart';
// Frozen preview already resolves these exact transitive fixtures; do not
// mutate pubspec/locks or fetch a new dependency for synthetic HTTP tests.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
// ignore: depend_on_referenced_packages
import 'package:supabase_flutter/supabase_flutter.dart';

const ticketAlice = '00000000-0000-4000-8000-000000000001';
const ticketBob = '00000000-0000-4000-8000-000000000002';

String testAccountSession(String userId, {String token = 'synthetic-A-old'}) =>
    jsonEncode({
      'access_token': token,
      'refresh_token': 'synthetic-refresh',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': userId,
        'aud': 'authenticated',
        'created_at': '2026-10-02T00:00:00Z',
        'app_metadata': <String, dynamic>{},
      },
    });

http.Response accountHttpResponse(Object? body, {int status = 200}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

/// Shared by the two owned test files. Real Core/Supabase clients dispatch
/// through this synthetic HTTP boundary; no provider or real account is used.
class AccountHttpFixture {
  AccountHttpFixture() {
    client = SupabaseClient(
      'https://motion.example.invalid',
      'public-synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(_handle),
    );
    account = MotionAccountClient(
      supabase: client,
      app: MotionApp.gravita,
      emailRedirectTo: 'com.yulalab.gravita://auth/callback',
    );
  }
  late final SupabaseClient client;
  late final MotionAccountClient account;
  final requests = <http.Request>[];
  final _pending = <Completer<http.Response>>[];
  Completer<http.Response>? deletionReply;
  Object receipt = <String, Object>{'deleted': true, 'userId': ticketAlice};
  Completer<void>? userReadHold;
  Completer<void>? userReadStarted;
  String refreshToken = 'synthetic-A-refreshed';

  List<http.Request> get deletions => requests
      .where((request) => request.url.path.endsWith('/motion-delete-account'))
      .toList();
  int get logoutCalls =>
      requests.where((request) => request.url.path.endsWith('/logout')).length;

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    if (request.url.path.endsWith('/motion-delete-account')) {
      final reply = deletionReply;
      deletionReply = null;
      if (reply == null) return accountHttpResponse(receipt);
      _pending.add(reply);
      return reply.future;
    }
    if (request.url.path.endsWith('/token')) {
      return accountHttpResponse(
        jsonDecode(testAccountSession(ticketAlice, token: refreshToken)),
      );
    }
    if (request.url.path.endsWith('/user')) {
      final started = userReadStarted;
      if (started != null && !started.isCompleted) started.complete();
      await userReadHold?.future;
      return accountHttpResponse({
        'id': client.auth.currentUser?.id ?? ticketAlice,
        'aud': 'authenticated',
        'created_at': '2026-10-02T00:00:00Z',
        'app_metadata': <String, dynamic>{},
      });
    }
    if (request.url.path.endsWith('/logout')) {
      return accountHttpResponse(<String, Object>{});
    }
    return accountHttpResponse(null);
  }

  Future<void> session(
    String userId, {
    String token = 'synthetic-A-old',
  }) async {
    await client.auth.setInitialSession(
      testAccountSession(userId, token: token),
    );
  }

  Completer<http.Response> delayDeletion() =>
      deletionReply = Completer<http.Response>();
  void releasePending() {
    for (final pending in _pending) {
      if (!pending.isCompleted) pending.complete(accountHttpResponse(receipt));
    }
  }

  Future<void> dispose() async {
    releasePending();
    await client.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AccountHttpFixture fixture;
  setUp(() async {
    await AccountStoreEpochRegistry.resetForTest();
    await AccountStoreEpochRegistry.enableManagedAdmission();
    AccountStoreEpochRegistry.activate(ticketAlice);
    fixture = AccountHttpFixture();
    await fixture.session(ticketAlice);
  });
  tearDown(() async {
    await fixture.dispose();
    await AccountStoreEpochRegistry.resetForTest();
  });

  EpochBoundMotionAccountClient bound(AccountActionTicket? ticket) =>
      EpochBoundMotionAccountClient(original: fixture.account, ticket: ticket);

  test('same UUID new token cannot dispatch a pre-dialog ticket', () async {
    final old = bound(AccountActionTicket.capture(fixture.account));
    await fixture.session(ticketAlice, token: 'synthetic-A-new');
    await expectLater(old.deleteCommonAccount(), throwsStateError);
    expect(fixture.deletions, isEmpty);
    expect(fixture.client.auth.currentSession?.accessToken, 'synthetic-A-new');
  });

  test(
    'stale epoch cannot dispatch even with unchanged UUID and token',
    () async {
      final ticket = AccountActionTicket.capture(fixture.account)!;
      final old = bound(ticket);
      await AccountStoreEpochRegistry.retireAll();
      final fresh = AccountStoreEpochRegistry.activate(ticketAlice);
      expect(identical(fresh, ticket.epoch), isFalse);
      await expectLater(old.deleteCommonAccount(), throwsStateError);
      expect(fixture.deletions, isEmpty);
      expect(fresh.isActive, isTrue);
    },
  );

  test('same UUID and token new Session cannot spend a pre-dialog ticket', () async {
    final captured = AccountActionTicket.capture(fixture.account)!;
    final original = fixture.client.auth.currentSession;
    await fixture.session(ticketAlice, token: 'synthetic-A-old');
    expect(identical(original, fixture.client.auth.currentSession), isFalse);
    final replacement = AccountActionTicket.capture(fixture.account)!;
    expect(captured.hasSameAuthority(replacement), isFalse);
    await expectLater(bound(captured).deleteCommonAccount(), throwsStateError);
    expect(fixture.deletions, isEmpty);
    expect(fixture.client.auth.currentUser?.id, ticketAlice);
  });

  test('replacement UUID cannot dispatch an old action ticket', () async {
    final old = bound(AccountActionTicket.capture(fixture.account));
    await fixture.session(ticketBob, token: 'synthetic-B');
    await expectLater(old.deleteCommonAccount(), throwsStateError);
    expect(fixture.deletions, isEmpty);
    expect(fixture.client.auth.currentUser?.id, ticketBob);
  });

  test(
    'closed identity history and recovery have no deletion ticket',
    () async {
      expect(
        AccountActionTicket.capture(fixture.account, isIdentityAdmitted: false),
        isNull,
      );
      expect(
        AccountActionTicket.capture(fixture.account, passwordRecovery: true),
        isNull,
      );
      await AccountStoreEpochRegistry.retireAll();
      expect(AccountActionTicket.capture(fixture.account), isNull);
      await expectLater(bound(null).deleteCommonAccount(), throwsStateError);
      expect(fixture.deletions, isEmpty);
    },
  );

  test(
    'fresh ticket accepts only the strict confirmed UUID through real Core',
    () async {
      final current = bound(AccountActionTicket.capture(fixture.account));
      final cleaned = <String>[];
      await current.deleteCommonAccount(
        afterRemoteDelete: (id) async => cleaned.add(id),
      );
      expect(fixture.deletions, hasLength(1));
      expect(
        fixture.deletions.single.headers['Authorization'],
        'Bearer synthetic-A-old',
      );
      expect(jsonDecode(fixture.deletions.single.body), {
        'confirmation': 'DELETE',
        'expectedUserId': ticketAlice,
      });
      expect(cleaned, [ticketAlice]);
      expect(fixture.client.auth.currentUser, isNull);
    },
  );

  for (final receipt in [
    <String, Object>{'deleted': true},
    <String, Object>{'deleted': true, 'userId': ticketBob},
  ]) {
    test(
      'legacy or wrong-owner receipt $receipt never cleans local data',
      () async {
        fixture.receipt = receipt;
        var cleaned = false;
        final current = bound(AccountActionTicket.capture(fixture.account));
        await expectLater(
          current.deleteCommonAccount(
            afterRemoteDelete: (_) async => cleaned = true,
          ),
          throwsStateError,
        );
        expect(cleaned, isFalse);
        expect(fixture.client.auth.currentUser?.id, ticketAlice);
      },
    );
  }

  test(
    'null deletion ticket preserves inherited password API and original client settings',
    () async {
      final current = bound(null);
      expect(identical(current.supabase, fixture.account.supabase), isTrue);
      expect(current.app, MotionApp.gravita);
      expect(current.emailRedirectTo, fixture.account.emailRedirectTo);
      await current.updatePassword('Synthetic!Password123');
      expect(
        fixture.requests.where(
          (request) =>
              request.method == 'PUT' && request.url.path.endsWith('/user'),
        ),
        hasLength(1),
      );
      expect(fixture.deletions, isEmpty);
    },
  );
}
