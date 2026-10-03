import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_data_directory.dart';
import 'package:gravita/app/account_session_store.dart';
import 'package:gravita/app/account_store_epoch.dart';
import 'package:gravita/app/calisthenics_course.dart';
import 'package:gravita/app/calisthenics_progress.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/course_progress_io.dart';
import 'package:gravita/app/program/program_model.dart';
import 'package:gravita/app/program/program_schedule_store.dart';
import 'package:gravita/app/program/program_store.dart';
import 'package:motion_core/motion_core.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  const first = '11111111-1111-4111-8111-111111111111';
  const second = '22222222-2222-4222-8222-222222222222';
  late Directory root;
  late PathProviderPlatform originalProvider;

  setUp(() async {
    await AccountStoreEpochRegistry.resetForTest();
    root = await Directory.systemTemp.createTemp('gravita-store-epoch-');
    originalProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _SupportDirectory(root.path);
  });
  tearDown(() async {
    PathProviderPlatform.instance = originalProvider;
    await AccountStoreEpochRegistry.resetForTest();
    await root.delete(recursive: true);
  });

  SessionRecord record(String lesson) => SessionRecord(
    lessonId: lesson,
    completedAt: DateTime.utc(2026, 10, 2),
    workedSeconds: 30,
    unitsCompleted: 3,
    plannedUnits: 3,
    unitLabel: 'rep',
    lessonClass: 'measurementOnly',
  );

  Future<AccountStoreEpoch> activate(String? account) async {
    await AccountStoreEpochRegistry.enableManagedAdmission();
    final epoch = AccountStoreEpochRegistry.activate(account);
    await epoch.ready;
    return epoch;
  }

  test(
    'managed admission closes synchronously and guest is explicit',
    () async {
      await AccountStoreEpochRegistry.enableManagedAdmission();
      expect(() => AccountStoreEpochRegistry.capture(first), throwsStateError);
      expect(() => AccountStoreEpochRegistry.capture(null), throwsStateError);
      final epoch = AccountStoreEpochRegistry.activate(first);
      expect(AccountStoreEpochRegistry.capture(first), same(epoch));
      expect(() => AccountStoreEpochRegistry.capture(second), throwsStateError);
      expect(() => AccountStoreEpochRegistry.capture(null), throwsStateError);
      final drain = AccountStoreEpochRegistry.retireAll();
      expect(epoch.writeLease.isActive, isFalse);
      expect(epoch.checkCurrent, throwsStateError);
      expect(() => AccountStoreEpochRegistry.capture(first), throwsStateError);
      await drain;
      final guest = AccountStoreEpochRegistry.activate(null);
      expect(AccountStoreEpochRegistry.capture(null), same(guest));
      await guest.ready;
    },
  );

  test(
    'all journal handles use the active owner epoch and retain concurrent records',
    () async {
      final epoch = await activate(first);
      final directory = accountDataDirectory(root, first);
      final lessons = AccountSessionStore(
        File('${directory.path}/sessions.jsonl'),
      );
      final free = AccountSessionStore(
        File('${directory.path}/free_sessions.jsonl'),
      );
      final otherFree = AccountSessionStore(
        File('${directory.path}/free_sessions.jsonl'),
      );
      final lessonLease = CourseProgressLease(
        File('${directory.path}/sessions.jsonl'),
      );
      final freeLease = CourseProgressLease(
        File('${directory.path}/free_sessions.jsonl'),
      );
      expect(lessonLease.epoch, same(epoch));
      expect(freeLease.epoch.writeLease, same(epoch.writeLease));
      await Future.wait([
        lessons.append(record('lesson')),
        free.append(record('free-one')),
        otherFree.append(record('free-two')),
      ]);
      expect((await lessons.recent()).single.lessonId, 'lesson');
      expect((await free.recent()).map((entry) => entry.lessonId).toSet(), {
        'free-one',
        'free-two',
      });
      await AccountStoreEpochRegistry.retireAll();
      for (final store in [lessons, free, otherFree]) {
        await expectLater(store.append(record('late')), throwsStateError);
        await expectLater(store.recent(), throwsStateError);
        await expectLater(store.unreadableRecords(), throwsStateError);
      }
    },
  );

  test(
    'retirement covers journal course program and schedule without erasing files',
    () async {
      final oldEpoch = await activate(first);
      final lessons = await ContentRepository.openSessionStore(
        accountUserId: first,
      );
      final free = await ContentRepository.openFreeSessionStore(
        accountUserId: first,
      );
      final course = await ContentRepository.openCalisthenicsProgressStore(
        accountUserId: first,
      );
      final program = await ProgramStore.open(accountUserId: first);
      final schedule = await ProgramScheduleStore.open(accountUserId: first);
      final content = CalisthenicsCourse.parse(
        await File('content/courses/calisthenics.v1.json').readAsString(),
      );
      final inputs = ProgramInputs(
        availableEquipment: const {},
        daysPerWeek: 3,
        experience: ExperienceLevel.beginner,
      );
      final dates = ProgramSchedule(
        dates: [DateTime.utc(2026, 10, 2)],
        rpeByDayIndex: const {0: 4},
      );
      await lessons.append(record('lesson'));
      await free.append(record('free'));
      await course.markSeen(content, content.lessons.first);
      await program.write(inputs);
      await schedule.write(dates);
      final drain = AccountStoreEpochRegistry.retireAll();
      expect(oldEpoch.checkCurrent, throwsStateError);
      await expectLater(course.load(), throwsStateError);
      await expectLater(
        course.markSeen(content, content.lessons.first),
        throwsStateError,
      );
      await expectLater(program.read(), throwsStateError);
      await expectLater(program.write(inputs), throwsStateError);
      await expectLater(program.clear(), throwsStateError);
      await expectLater(schedule.read(), throwsStateError);
      await expectLater(schedule.write(dates), throwsStateError);
      await expectLater(schedule.clear(), throwsStateError);
      await drain;
      final fresh = AccountStoreEpochRegistry.activate(first);
      expect(fresh, isNot(same(oldEpoch)));
      await fresh.ready;
      expect(
        (await (await ContentRepository.openSessionStore(
          accountUserId: first,
        )).recent()).single.lessonId,
        'lesson',
      );
      expect(
        (await (await ContentRepository.openFreeSessionStore(
          accountUserId: first,
        )).recent()).single.lessonId,
        'free',
      );
      expect(
        (await (await ProgramStore.open(
          accountUserId: first,
        )).read())?.daysPerWeek,
        3,
      );
      expect(
        (await (await ProgramScheduleStore.open(
          accountUserId: first,
        )).read())?.rpeByDayIndex,
        {0: 4},
      );
      expect(
        (await (await ContentRepository.openCalisthenicsProgressStore(
          accountUserId: first,
        )).load()).records.keys,
        contains(content.lessons.first.id),
      );
      await expectLater(lessons.recent(), throwsStateError);
      await expectLater(
        free.append(record('old after fresh')),
        throwsStateError,
      );
    },
  );

  test(
    'A to B to fresh A preserves each journal and never reactivates old handles',
    () async {
      await activate(null);
      final guest = await ContentRepository.openFreeSessionStore();
      await guest.append(record('guest'));
      final oldA = AccountStoreEpochRegistry.activate(first);
      final a = await ContentRepository.openFreeSessionStore(
        accountUserId: first,
      );
      await a.append(record('A'));
      await expectLater(guest.recent(), throwsStateError);
      final oldB = AccountStoreEpochRegistry.activate(second);
      final b = await ContentRepository.openFreeSessionStore(
        accountUserId: second,
      );
      await b.append(record('B'));
      final freshA = AccountStoreEpochRegistry.activate(first);
      final fresh = await ContentRepository.openFreeSessionStore(
        accountUserId: first,
      );
      expect(freshA, isNot(same(oldA)));
      expect(oldA.checkCurrent, throwsStateError);
      expect(oldB.checkCurrent, throwsStateError);
      expect((await fresh.recent()).single.lessonId, 'A');
      await expectLater(a.append(record('late A')), throwsStateError);
      await expectLater(b.append(record('late B')), throwsStateError);
      AccountStoreEpochRegistry.activate(null);
      expect(
        (await (await ContentRepository.openFreeSessionStore()).recent())
            .single
            .lessonId,
        'guest',
      );
    },
  );

  test(
    'fresh same UUID waits for admitted host writer and queued stale writer drains',
    () async {
      await activate(first);
      final file = File(
        '${accountDataDirectory(root, first).path}/pending.json',
      );
      await file.parent.create(recursive: true);
      final old = CourseProgressLease(file);
      final started = Completer<void>();
      final release = Completer<void>();
      var queuedRan = false;
      final writing = old.mutate(() async {
        started.complete();
        await release.future;
        await file.writeAsString('admitted old write');
      });
      final staleWrite = expectLater(writing, throwsStateError);
      await started.future;
      final queued = expectLater(
        old.mutate(() async {
          queuedRan = true;
        }),
        throwsStateError,
      );
      var drained = false;
      final retirement = AccountStoreEpochRegistry.retireAll().then(
        (_) => drained = true,
      );
      AccountStoreEpochRegistry.activate(first);
      final fresh = CourseProgressLease(file);
      var freshRan = false;
      final reading = fresh.mutate(() async {
        freshRan = true;
        return file.readAsString();
      });
      try {
        await Future<void>.delayed(Duration.zero);
        expect(drained, isFalse);
        expect(freshRan, isFalse);
        expect(old.checkCurrent, throwsStateError);
      } finally {
        release.complete();
      }
      await staleWrite;
      await queued;
      await retirement;
      expect(queuedRan, isFalse);
      expect(await reading, 'admitted old write');
    },
  );

  test(
    'verified deletion retires synchronously and drains an in-flight Core append',
    () async {
      final epoch = await activate(first);
      final directory = await accountDataDirectory(
        root,
        first,
      ).create(recursive: true);
      final file = _GatedExistsFile(File('${directory.path}/sessions.jsonl'));
      final store = AccountSessionStore(file);
      final append = store.append(record('pending'));
      final rejected = expectLater(
        append,
        throwsA(anyOf(isA<StateError>(), isA<SessionStoreRetiredException>())),
      );
      await file.started.future;
      var deleted = false;
      final deletion = deleteAccountData(
        root,
        first,
      ).then((_) => deleted = true);
      expect(epoch.checkCurrent, throwsStateError);
      expect(epoch.writeLease.isActive, isFalse);
      try {
        await Future<void>.delayed(Duration.zero);
        expect(deleted, isFalse);
        expect(await directory.exists(), isTrue);
      } finally {
        file.result.complete(false);
      }
      await rejected;
      await deletion;
      expect(await directory.exists(), isFalse);
      await expectLater(store.append(record('late')), throwsStateError);
    },
  );

  test(
    'every async factory rejects its old capture after same UUID recovery',
    () async {
      final old = await activate(first);
      final provider = _GatedSupportDirectory(root.path);
      PathProviderPlatform.instance = provider;
      final opens = <Future<Object>>[
        ContentRepository.openSessionStore(accountUserId: first),
        ContentRepository.openFreeSessionStore(accountUserId: first),
        ContentRepository.openCalisthenicsProgressStore(accountUserId: first),
        ProgramStore.open(accountUserId: first),
        ProgramScheduleStore.open(accountUserId: first),
      ];
      final rejections = [
        for (final open in opens) expectLater(open, throwsStateError),
      ];
      await provider.allStarted.future;
      final drain = AccountStoreEpochRegistry.retireAll();
      final fresh = AccountStoreEpochRegistry.activate(first);
      expect(old.checkCurrent, throwsStateError);
      expect(fresh, isNot(same(old)));
      provider.release.complete();
      await Future.wait(rejections);
      await drain;
      await fresh.ready;
      PathProviderPlatform.instance = _SupportDirectory(root.path);
      final usable = await ContentRepository.openFreeSessionStore(
        accountUserId: first,
      );
      await usable.append(record('fresh'));
      expect((await usable.recent()).single.lessonId, 'fresh');
    },
  );

  test(
    'unregistered delayed open also rejects verified account deletion',
    () async {
      final epoch = await activate(first);
      final provider = _GatedSupportDirectory(root.path, expectedCalls: 1);
      PathProviderPlatform.instance = provider;
      final open = ContentRepository.openFreeSessionStore(accountUserId: first);
      final rejection = expectLater(open, throwsStateError);
      await provider.allStarted.future;
      await deleteAccountData(root, first);
      expect(epoch.checkCurrent, throwsStateError);
      provider.release.complete();
      await rejection;
      expect(await accountDataDirectory(root, first).exists(), isFalse);
    },
  );

  test('public course read is included in retirement drain', () async {
    await activate(first);
    final file = _GatedExistsFile(
      File('${accountDataDirectory(root, first).path}/course.json'),
    );
    await file.delegate.parent.create(recursive: true);
    await file.delegate.writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'courseId': 'calisthenics-foundations',
        'lessons': <String, Object>{},
      }),
    );
    final store = CalisthenicsProgressStore(file);
    final rejection = expectLater(store.load(), throwsStateError);
    await file.started.future;
    var drained = false;
    final drain = AccountStoreEpochRegistry.retireAll().then(
      (_) => drained = true,
    );
    try {
      await Future<void>.delayed(Duration.zero);
      expect(
        drained,
        isFalse,
        reason: 'the admitted public read is still pending',
      );
    } finally {
      file.result.complete(true);
      await rejection;
      await drain;
    }
    expect(file.readCalls, 0);
  });

  test(
    'fresh public course load waits for the old account file writer',
    () async {
      await activate(first);
      final file = File(
        '${accountDataDirectory(root, first).path}/course.json',
      );
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'courseId': 'calisthenics-foundations',
          'lessons': <String, Object>{},
        }),
      );
      final old = CourseProgressLease(file);
      final started = Completer<void>();
      final release = Completer<void>();
      final writing = old.mutate(() async {
        started.complete();
        await release.future;
        await file.writeAsString(
          jsonEncode({
            'schemaVersion': 1,
            'courseId': 'calisthenics-foundations',
            'lessons': {
              'cal-01': {
                'contentVersion': 'synthetic epoch ordering fixture',
                'state': 'seen',
                'seenAt': DateTime.utc(2026, 10, 2).toIso8601String(),
                'practiceCount': 0,
              },
            },
          }),
        );
      });
      final rejected = expectLater(writing, throwsStateError);
      await started.future;
      final drain = AccountStoreEpochRegistry.retireAll();
      AccountStoreEpochRegistry.activate(first);
      final observed = _ObservingReadFile(file);
      final reading = CalisthenicsProgressStore(observed).load();
      late CalisthenicsProgress result;
      try {
        await Future<void>.delayed(Duration.zero);
        expect(
          observed.readCalls,
          0,
          reason: 'fresh public load must await old IO drain',
        );
      } finally {
        release.complete();
        await rejected;
        await drain;
        result = await reading;
      }
      expect(result.records.keys, contains('cal-01'));
    },
  );

  test(
    'reset allows unmanaged reopening but keeps deleted-directory tombstone permanent',
    () async {
      final epoch = await activate(first);
      final file = File(
        '${accountDataDirectory(root, first).path}/sessions.jsonl',
      );
      final old = AccountSessionStore(file);
      await old.append(record('retained'));
      await AccountStoreEpochRegistry.resetForTest();
      expect(epoch.checkCurrent, throwsStateError);
      await expectLater(old.recent(), throwsStateError);
      final unmanaged = AccountSessionStore(file);
      expect((await unmanaged.recent()).single.lessonId, 'retained');
      await deleteAccountData(root, first);
      await AccountStoreEpochRegistry.resetForTest();
      expect(() => AccountSessionStore(file), throwsStateError);
      await expectLater(unmanaged.recent(), throwsStateError);
    },
  );
}

class _SupportDirectory extends PathProviderPlatform {
  _SupportDirectory(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

final class _GatedSupportDirectory extends _SupportDirectory {
  _GatedSupportDirectory(super.path, {this.expectedCalls = 5});
  final int expectedCalls;
  int calls = 0;
  final allStarted = Completer<void>();
  final release = Completer<void>();
  @override
  Future<String?> getApplicationSupportPath() async {
    calls++;
    if (calls == expectedCalls) allStarted.complete();
    await release.future;
    return path;
  }
}

final class _GatedExistsFile implements File {
  _GatedExistsFile(this.delegate);
  final File delegate;
  final started = Completer<void>();
  final result = Completer<bool>();
  int readCalls = 0;
  @override
  File get absolute => delegate.absolute;
  @override
  String get path => delegate.path;
  @override
  Directory get parent => delegate.parent;
  @override
  Future<bool> exists() {
    if (!started.isCompleted) started.complete();
    return result.future;
  }

  @override
  Future<String> readAsString({Encoding encoding = utf8}) {
    readCalls++;
    return delegate.readAsString(encoding: encoding);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ObservingReadFile implements File {
  _ObservingReadFile(this.delegate);
  final File delegate;
  int readCalls = 0;
  @override
  File get absolute => delegate.absolute;
  @override
  String get path => delegate.path;
  @override
  Directory get parent => delegate.parent;
  @override
  Future<bool> exists() async => true;
  @override
  Future<String> readAsString({Encoding encoding = utf8}) {
    readCalls++;
    return delegate.readAsString(encoding: encoding);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
