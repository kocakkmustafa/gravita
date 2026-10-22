// Source-only regression authoring. Execution belongs to the coordinated lane.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_connection.dart';
import 'package:gravita/app/account_store_epoch.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/calisthenics_course.dart';
import 'package:gravita/app/calisthenics_course_screen.dart';
import 'package:gravita/app/calisthenics_progress.dart';
import 'package:gravita/app/theme.dart';
import 'support/locale_asset_harness.dart' show warmActualLocaleAssets, pumpActualLocaleReady;

const a = '11111111-1111-4111-8111-111111111111';
const b = '22222222-2222-4222-8222-222222222222';

final class PausedExistsFile implements File {
  PausedExistsFile(this.delegate);
  final File delegate;
  final started = Completer<void>();
  final release = Completer<bool>();
  @override
  String get path => delegate.path;
  @override
  File get absolute => delegate.absolute;
  @override
  Directory get parent => delegate.parent;
  @override
  Future<bool> exists() {
    if (!started.isCompleted) started.complete();
    return release.future;
  }
  @override
  Future<String> readAsString({Encoding encoding = utf8}) =>
      delegate.readAsString(encoding: encoding);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(warmActualLocaleAssets);
  final course = CalisthenicsCourse.parse(
    File('content/courses/dbkb-written.v1.json').readAsStringSync());
  late Directory root;
  setUp(() async {
    await AccountStoreEpochRegistry.resetForTest();
    root = await Directory.systemTemp.createTemp('dbkb-lifecycle-');
  });
  tearDown(() async {
    await AccountStoreEpochRegistry.resetForTest();
    if (await root.exists()) await root.delete(recursive: true);
  });
  Widget host(Widget child, String language, {double scale = 1}) => MaterialApp(
    theme: GravitaTheme.light,
    locale: Locale(language), supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!),
    home: child,
  );
  Future<void> to(WidgetTester tester, Key key, {double delta = 200}) async {
    // The lesson body mounts after its real-IO progress store resolves.
    for (var i = 0; i < 40 && find.byKey(const Key('calisthenics.lesson.body')).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.scrollUntilVisible(find.byKey(key), delta,
      scrollable: find.descendant(of: find.byKey(const Key('calisthenics.lesson.body')),
        matching: find.byType(Scrollable)).first, maxScrolls: 150);
    await tester.pump();
  }
  Future<void> settleIo(WidgetTester tester) async {
    // Flush every filesystem continuation back through the widget fake-async zone.
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump();
    }
  }
  Future<T> awaitIo<T>(WidgetTester tester, Future<T> pending) async {
    var completed = false;
    pending.then<void>((_) { completed = true; }, onError: (Object _, StackTrace __) { completed = true; });
    for (var i = 0; i < 100 && !completed; i++) { await settleIo(tester); }
    expect(completed, isTrue, reason: 'Journal IO must settle while the widget zone is pumped');
    return pending;
  }
  void drainAfter(WidgetTester tester) {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 8; i++) { await settleIo(tester); }
      var drained = false;
      final pending = AccountStoreEpochRegistry.resetForTest().then((_) { drained = true; });
      for (var i = 0; i < 30 && !drained; i++) { await settleIo(tester); }
      expect(drained, isTrue, reason: 'All admitted journal IO must drain before teardown');
      await pending;
    });
  }
  CalisthenicsProgressStore store(String? id) =>
      calisthenicsProgressStoreFor(root, id, courseId: course.id);

  test('old owner and ABA epochs cannot finish awaited DB/KB IO', () async {
    await AccountStoreEpochRegistry.enableManagedAdmission();
    final firstEpoch = AccountStoreEpochRegistry.activate(a);
    final target = store(a).file;
    final gate = PausedExistsFile(target);
    final old = CalisthenicsProgressStore(gate, epoch: firstEpoch, courseId: course.id);
    final pending = old.markSeen(course, course.lessons.first);
    final rejected = expectLater(pending, throwsStateError);
    await gate.started.future;
    AccountStoreEpochRegistry.activate(b);
    AccountStoreEpochRegistry.activate(a);
    gate.release.complete(false);
    await rejected;
    expect(await target.exists(), isFalse);
    final fresh = store(a);
    await fresh.markSeen(course, course.lessons.first);
    expect((await fresh.load()).records, hasLength(1));
  });

  test('failed temp write retains prior journal; partial temp is ignored', () async {
    final journal = store(null);
    await journal.markSeen(course, course.lessons.first);
    final before = await journal.file.readAsString();
    final tmp = File('${journal.file.path}.tmp');
    await tmp.writeAsString('{partial');
    expect((await journal.load()).records, hasLength(1));
    await tmp.delete();
    await Directory(tmp.path).create();
    await expectLater(journal.markPractised(course, course.lessons.first),
      throwsA(isA<FileSystemException>()));
    expect(await journal.file.readAsString(), before);
    expect((await journal.load()).records.values.single.practiceCount, 0);
  });

  for (final language in ['en', 'tr']) {
    testWidgets('03 stays written and opens actual cal-04 route in $language', (tester) async {
      drainAfter(tester);
      final preparation = CalisthenicsCourse.parse(File('content/courses/calisthenics.v1.json').readAsStringSync());
      final lesson = course.lessons[2];
      await tester.pumpWidget(host(CalisthenicsLessonScreen(
        course: course, lesson: lesson, preparationCourse: preparation,
        storeLoader: (_) async => store(null)), language));
      await pumpActualLocaleReady(tester);
      await settleIo(tester);
      expect(lesson.learningOnly, isTrue);
      expect(find.byKey(const Key('calisthenics.prepared')), findsNothing);
      await to(tester, const Key('dbkb.lesson.preparation.cal-04'));
      await tester.tap(find.byKey(const Key('dbkb.lesson.preparation.cal-04')));
      await settleIo(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<CalisthenicsLessonScreen>(find.byType(CalisthenicsLessonScreen).last)
        .lesson.id, 'cal-04');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 8; i++) { await settleIo(tester); }
    });

    testWidgets('learning-only reveal pause resume hides answer in $language', (tester) async {
      drainAfter(tester);
      final lesson = course.lessons.first;
      await tester.pumpWidget(host(CalisthenicsLessonScreen(course: course,
        lesson: lesson, storeLoader: (_) async => store(null)), language));
      await pumpActualLocaleReady(tester);
      await settleIo(tester);
      await to(tester, const Key('dbkb.answer.toggle'));
      await tester.tap(find.byKey(const Key('dbkb.answer.toggle')));
      await tester.pump();
      await to(tester, const Key('dbkb.answer.content'));
      expect(find.text(lesson.answer!.inLanguage(language)), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byKey(const Key('dbkb.answer.content')), findsNothing);
    });

    testWidgets('owner callback and delayed ABA open leave fresh state in $language', (tester) async {
      drainAfter(tester);
      final ids = ValueNotifier<String?>(a);
      final owners = StreamController<void>.broadcast(sync: true);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        for (var i = 0; i < 8; i++) { await settleIo(tester); }
        await tester.runAsync(() => owners.close());
        ids.dispose();
      });
      final lateOpen = Completer<CalisthenicsProgressStore>();
      var opens = 0;
      final connection = AccountConnection(userId: ids,
        ownerSessionChanges: owners.stream, pageBuilder: (_) => const SizedBox());
      final page = AccountScope(connection: connection, currentUserId: a,
        child: CalisthenicsLessonScreen(course: course, lesson: course.lessons.first,
          storeLoader: (id) {
            opens++;
            return opens == 2 ? lateOpen.future : Future.value(store(id));
          }));
        await tester.pumpWidget(host(page, language));
        await pumpActualLocaleReady(tester);
      await settleIo(tester);
      await to(tester, const Key('dbkb.answer.toggle'));
      await tester.tap(find.byKey(const Key('dbkb.answer.toggle')));
      await tester.pump();
      owners.add(null); // Same UUID, fresh owner must reset revealed answer.
      await tester.pump();
      expect(find.byKey(const Key('dbkb.answer.content')), findsNothing);
      ids.value = b;
      ids.value = a;
      await settleIo(tester);
      lateOpen.complete(store(a));
      await settleIo(tester);
      expect(opens, 4);
      expect(find.byKey(const Key('dbkb.answer.content')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final id in ['dbkb-10', 'dbkb-11']) {
      testWidgets('$id gate, pause, next-date rebuild and record contract in $language', (tester) async {
      drainAfter(tester);
        final lesson = course.lessons.singleWhere((l) => l.id == id);
        final journal = store(null);
        var date = DateTime(2026, 10, 4, 23, 59);
        Widget page() => host(CalisthenicsLessonScreen(course: course, lesson: lesson,
          storeLoader: (_) async => journal, now: () => date), language);
        await tester.pumpWidget(page());
        await pumpActualLocaleReady(tester);
        await settleIo(tester);
        await to(tester, const Key('calisthenics.practiceOptions'));
        expect(find.text(lesson.practice.inLanguage(language)), findsNothing);
        await to(tester, const Key('dbkb.answer.toggle'));
        expect(tester.widget<TextButton>(find.byKey(const Key('dbkb.answer.toggle'))).onPressed, isNull);
        expect(find.text(lesson.correction!.inLanguage(language)), findsNothing);
        await to(tester, const Key('calisthenics.practised'));
        expect(tester.widget<OutlinedButton>(find.byKey(const Key('calisthenics.practised'))).onPressed, isNull);
        await to(tester, const Key('calisthenics.prepared'), delta: -200);
        await tester.tap(find.byKey(const Key('calisthenics.prepared')));
        await tester.pump();
        await to(tester, const Key('calisthenics.practiceOptions'));
        expect(find.text(lesson.practice.inLanguage(language)), findsOneWidget);
        await to(tester, const Key('dbkb.answer.toggle'));
        await tester.tap(find.byKey(const Key('dbkb.answer.toggle')));
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        expect(find.byKey(const Key('dbkb.answer.content')), findsNothing);
        await to(tester, const Key('calisthenics.prepared'), delta: -200);
        expect(tester.widget<CheckboxListTile>(find.byKey(const Key('calisthenics.prepared'))).value, isFalse);
        await tester.tap(find.byKey(const Key('calisthenics.prepared')));
        await tester.pump();
        // Date expiry is observed on the next widget rebuild.
        // This does not test or claim an automatic midnight timer.
        date = DateTime(2026, 10, 5, 0, 1);
        await tester.pumpWidget(page());
        await pumpActualLocaleReady(tester);
        await tester.pump();
        expect(tester.widget<CheckboxListTile>(find.byKey(const Key('calisthenics.prepared'))).value, isFalse);
        await to(tester, const Key('calisthenics.practised'));
        expect(tester.widget<OutlinedButton>(find.byKey(const Key('calisthenics.practised'))).onPressed, isNull);
        await tester.runAsync(() async {
          await journal.markPractised(course, lesson);
          await expectLater(journal.markCompleted(course, lesson, selfChecksConfirmed: true), throwsStateError);
          await journal.markPractised(course, lesson);
          await journal.markCompleted(course, lesson, selfChecksConfirmed: true);
        });
      });
    }

    testWidgets('save failure keeps reading available in $language', (tester) async {
      drainAfter(tester);
      final journal = store(null);
      final lesson = course.lessons.first;
      await tester.pumpWidget(host(CalisthenicsLessonScreen(course: course, lesson: lesson,
        storeLoader: (_) async => journal), language));
      await pumpActualLocaleReady(tester);
      await settleIo(tester);
      await tester.runAsync(() async => Directory('${journal.file.path}.tmp').create());
      await to(tester, const Key('calisthenics.practised'));
      await tester.tap(find.byKey(const Key('calisthenics.practised')));
      await settleIo(tester);
      expect(find.textContaining(language == 'tr' ? 'İlerleme okunamadı' : 'Progress could not'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('calisthenics.practised'))).onPressed, isNull);
      await to(tester, const Key('dbkb.answer.toggle'), delta: -200);
      expect(tester.widget<TextButton>(find.byKey(const Key('dbkb.answer.toggle'))).onPressed, isNotNull);
      // Remove only this test's injected temp-path obstruction, then retry storage.
      await tester.runAsync(() async => Directory('${journal.file.path}.tmp').delete());
      await tester.scrollUntilVisible(
        find.text(language == 'tr' ? 'Kaydı yeniden dene' : 'Retry storage'), 200,
        maxScrolls: 150);
      final retry = find.text(language == 'tr' ? 'Kaydı yeniden dene' : 'Retry storage');
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await settleIo(tester);
      for (var i = 0; i < 8; i++) { await settleIo(tester); }
      await to(tester, const Key('calisthenics.practised'));
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('calisthenics.practised'))).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('calisthenics.practised')));
      await settleIo(tester);
      final saved = await awaitIo(tester, journal.load());
      expect(saved.forLesson(lesson, course.version)!.practiceCount, 1);
      expect(find.textContaining(language == 'tr' ? 'İlerleme okunamadı' : 'Progress could not'), findsNothing);
    });

    testWidgets('back and reopen starts with hidden answer in $language', (tester) async {
      drainAfter(tester);
      final lesson = course.lessons.first;
      await tester.pumpWidget(host(Builder(builder: (context) => Scaffold(body: TextButton(
        onPressed: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
          builder: (_) => CalisthenicsLessonScreen(course: course, lesson: lesson,
            storeLoader: (_) async => store(null)))), child: const Text('open')))), language));
      await pumpActualLocaleReady(tester);
      for (var visit = 0; visit < 2; visit++) {
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await settleIo(tester);
        expect(find.byKey(const Key('dbkb.answer.content')), findsNothing);
        await to(tester, const Key('dbkb.answer.toggle'));
        await tester.tap(find.byKey(const Key('dbkb.answer.toggle')));
        await tester.pump();
        await to(tester, const Key('dbkb.answer.content'));
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }
    });

    for (final lesson in course.lessons) {
      testWidgets('${lesson.id} large text/answer semantics $language', (tester) async {
      drainAfter(tester);
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        try {
        await tester.pumpWidget(host(CalisthenicsLessonScreen(course: course, lesson: lesson,
          storeLoader: (_) async => store(null)), language, scale: 2));
        await pumpActualLocaleReady(tester);
        await settleIo(tester);
        expect(find.byKey(const Key('dbkb.answer.content')), findsNothing);
        if (!lesson.learningOnly) {
          await to(tester, const Key('calisthenics.prepared'));
          await tester.tap(find.byKey(const Key('calisthenics.prepared')));
          await tester.pump();
        }
        await to(tester, const Key('dbkb.answer.toggle'));
        expect(tester.getSemantics(find.byKey(const Key('dbkb.answer.toggle'))).label,
          contains(language == 'tr' ? 'gerekçeyi karşılaştır' : 'compare reasoning'));
        await tester.tap(find.byKey(const Key('dbkb.answer.toggle')));
        await tester.pump();
        await to(tester, const Key('dbkb.answer.content'));
        expect(find.text(lesson.answer!.inLanguage(language)), findsOneWidget);
        expect(tester.takeException(), isNull);
        } finally { semantics.dispose(); }
      });
    }
  }
}
