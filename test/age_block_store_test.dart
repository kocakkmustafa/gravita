import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_data_directory.dart';
import 'package:gravita/app/age_block_store.dart';

void main() {
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('gravita_age_block_');
  });
  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('a fresh device starts unblocked', () async {
    final store = AgeBlockStore(directory: () async => temp);
    await store.load();
    expect(store.blocked, isFalse);
  });

  test('a recorded block survives a restart', () async {
    final first = AgeBlockStore(directory: () async => temp);
    await first.load();
    await first.markBlocked();
    expect(first.blocked, isTrue);

    final restarted = AgeBlockStore(directory: () async => temp);
    await restarted.load();
    expect(restarted.blocked, isTrue);
  });

  test('an unreadable location starts unblocked', () async {
    final store = AgeBlockStore(
      directory: () async => throw const FileSystemException('denied'),
    );
    await store.load();
    expect(store.blocked, isFalse);
    await store.markBlocked();
    expect(store.blocked, isTrue, reason: 'in-memory block holds this run');
  });

  test('the block is not an account and survives confirmed erasure', () async {
    const user = '11111111-1111-4111-8111-111111111111';
    await Directory('${temp.path}/accounts/$user').create(recursive: true);
    final store = AgeBlockStore(directory: () async => temp);
    await store.markBlocked();

    expect(await localAccountIds(temp), <String>[user]);
    await deleteAccountData(temp, user);

    final restarted = AgeBlockStore(directory: () async => temp);
    await restarted.load();
    expect(restarted.blocked, isTrue);
  });

  test('production wires the durable block into the shared account page', () {
    final bootstrap = File(
      'lib/app/motion_account_bootstrap.dart',
    ).readAsStringSync();
    expect(bootstrap, contains('await ageBlock.load();'));
    expect(bootstrap, contains('ageBlocked: ageBlock?.blocked ?? false'));
    expect(bootstrap, contains('unawaited(ageBlock.markBlocked())'));
    final page = File('lib/app/gravita_account_page.dart').readAsStringSync();
    expect(page, contains('ageBlocked: widget.ageBlocked'));
    expect(page, contains('onAgeBlocked: widget.onAgeBlocked'));
  });
}
