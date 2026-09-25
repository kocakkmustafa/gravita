import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_data_directory.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/program/program_model.dart';
import 'package:gravita/app/program/program_store.dart';
import 'package:motion_core/motion_core.dart' show SessionRecord, SessionStore;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/launch_harness.dart';

void main() {
  const first = '11111111-1111-4111-8111-111111111111';
  const second = '22222222-2222-4222-8222-222222222222';
  late Directory root;
  late PathProviderPlatform original;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('gravita_accounts');
    original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = FakeSupportDir(root.path);
  });
  tearDown(() async {
    PathProviderPlatform.instance = original;
    await root.delete(recursive: true);
  });

  SessionRecord record(String lesson) => SessionRecord(
    lessonId: lesson,
    completedAt: DateTime.utc(2026, 9, 24),
    workedSeconds: 30,
    unitsCompleted: 3,
    plannedUnits: 0,
    unitLabel: 'rep',
    lessonClass: 'measurementOnly',
  );

  test('guest and two accounts keep distinct real session journals', () async {
    final SessionStore guest = await ContentRepository.openFreeSessionStore();
    final SessionStore one = await ContentRepository.openFreeSessionStore(
      accountUserId: first,
    );
    final SessionStore two = await ContentRepository.openFreeSessionStore(
      accountUserId: second,
    );
    await guest.append(record('guest'));
    await one.append(record('first'));
    await two.append(record('second'));

    expect((await guest.recent()).single.lessonId, 'guest');
    expect((await one.recent()).single.lessonId, 'first');
    expect((await two.recent()).single.lessonId, 'second');
    expect(await File('${root.path}/free_sessions.jsonl').exists(), isTrue);
    expect(
      await File('${root.path}/accounts/$first/free_sessions.jsonl').exists(),
      isTrue,
    );
    expect(
      await File('${root.path}/accounts/$second/free_sessions.jsonl').exists(),
      isTrue,
    );

    await deleteAccountData(root, first);
    await deleteAccountData(root, first); // idempotent on account deletion
    expect(
      await File('${root.path}/accounts/$first/free_sessions.jsonl').exists(),
      isFalse,
    );
    expect((await guest.recent()).single.lessonId, 'guest');
    expect((await two.recent()).single.lessonId, 'second');
  });

  test('program inputs follow the same account boundary', () async {
    final inputs = ProgramInputs(
      availableEquipment: const <String>{},
      daysPerWeek: 3,
      experience: ExperienceLevel.beginner,
    );
    await (await ProgramStore.open(accountUserId: first)).write(inputs);
    expect(
      await (await ProgramStore.open(accountUserId: second)).read(),
      isNull,
    );
    expect(await (await ProgramStore.open()).read(), isNull);
    expect(
      (await (await ProgramStore.open(
        accountUserId: first,
      )).read())?.daysPerWeek,
      3,
    );
  });

  test('user ID cannot escape local account directory', () {
    expect(
      () => accountDataDirectory(root, '../another-user'),
      throwsArgumentError,
    );
  });

  test(
    'deletion receipt scan sees only canonical account directories',
    () async {
      final accounts = await Directory('${root.path}/accounts').create();
      await Directory('${accounts.path}/$second').create();
      await Directory('${accounts.path}/$first').create();
      await Directory('${accounts.path}/other').create();
      await File(
        '${accounts.path}/33333333-3333-4333-8333-333333333333',
      ).create();
      await Link(
        '${accounts.path}/44444444-4444-4444-8444-444444444444',
      ).create(root.path);

      expect(await localAccountIds(root), [first, second]);
    },
  );
}
