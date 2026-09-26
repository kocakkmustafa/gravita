import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/account_connection.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/calisthenics_course_screen.dart';
import 'package:gravita/app/calisthenics_progress.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/home_screen.dart';
import 'package:gravita/app/library_screen.dart';
import 'package:gravita/app/theme.dart';
import 'support/launch_harness.dart';

class _FileBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File(key).readAsBytes());
  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      File(key).readAsString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late ContentRepository content;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('gravita-course-ui-');
    content = await ContentRepository.load(_FileBundle());
  });
  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });
  Widget host(Widget child) => MaterialApp(
    theme: GravitaTheme.light,
    locale: const Locale('tr'),
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    home: child,
  );
  void size(WidgetTester tester) {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> to(WidgetTester tester, Key key, {double delta = 200}) async {
    await tester.scrollUntilVisible(
      find.byKey(key),
      delta,
      scrollable: find
          .descendant(
            of: find.byKey(
              find
                      .byKey(const Key('calisthenics.lesson.body'))
                      .evaluate()
                      .isNotEmpty
                  ? const Key('calisthenics.lesson.body')
                  : const Key('calisthenics.course.body'),
            ),
            matching: find.byType(Scrollable),
          )
          .first,
      maxScrolls: 35,
    );
    await tester.pump();
  }

  testWidgets(
    'Home and Library expose real complete course without measurement promotion',
    (tester) async {
      size(tester);
      for (final page in <Widget>[
        HomeScreen(content: content, onBrowseLibrary: () {}),
        LibraryScreen(content: content),
      ]) {
        await tester.pumpWidget(host(page));
        await tester.pump();
        expect(find.byKey(const Key('calisthenics.entry')), findsOneWidget);
        await tester.tap(find.byKey(const Key('calisthenics.entry')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(find.byType(CalisthenicsCourseScreen), findsOneWidget);
        expect(find.text('0 / 56'), findsOneWidget);
        await tester.tap(find.byKey(const Key('calisthenics.next')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(find.byType(CalisthenicsLessonScreen), findsOneWidget);
        expect(find.text('Çalışma alanın'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
      expect(content.catalogue.liveCount, 2);
      expect(content.catalogue.movements.where((m) => !m.isLive).length, 29);
    },
  );
  testWidgets('real lesson task/save/pop/reopen reads completed progress', (
    tester,
  ) async {
    size(tester);
    final course = content.calisthenicsCourse;
    Future<CalisthenicsProgressStore> loader(String? id) async =>
        calisthenicsProgressStoreFor(temp, id);
    await tester.pumpWidget(
      host(CalisthenicsCourseScreen(course: course, storeLoader: loader)),
    );
    await settleUntil(
      tester,
      () => find.byKey(const Key('calisthenics.next')).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(const Key('calisthenics.next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await to(tester, const Key('calisthenics.practised'));
    await settleUntil(
      tester,
      () =>
          tester
              .widget<OutlinedButton>(
                find.byKey(const Key('calisthenics.practised')),
              )
              .onPressed !=
          null,
    );
    await to(tester, const Key('calisthenics.practised'));
    await tester.tap(find.byKey(const Key('calisthenics.practised')));
    await settleUntil(
      tester,
      () => find.text('Görev bildirimleri: 1').evaluate().isNotEmpty,
    );
    await to(tester, const Key('calisthenics.confirm'));
    await settleUntil(
      tester,
      () =>
          tester
              .widget<CheckboxListTile>(
                find.byKey(const Key('calisthenics.confirm')),
              )
              .onChanged !=
          null,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('calisthenics.confirm')),
          )
          .onChanged,
      isNotNull,
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('calisthenics.confirm')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('calisthenics.confirm')),
          )
          .value,
      true,
    );
    await to(tester, const Key('calisthenics.complete'));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('calisthenics.complete')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('calisthenics.complete')));
    await to(tester, const Key('calisthenics.state'), delta: -200);
    await settleUntil(
      tester,
      () => tester
          .widget<Text>(find.byKey(const Key('calisthenics.state')))
          .data!
          .startsWith('Öğrenme tamamlandı'),
    );
    final persisted = await realIo(
      tester,
      () => calisthenicsProgressStoreFor(temp, null).load(),
    );
    expect(persisted.completedCount(course), 1);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await settleUntil(tester, () => find.text('1 / 56').evaluate().isNotEmpty);
    expect(find.text('1 / 56'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      host(CalisthenicsCourseScreen(course: course, storeLoader: loader)),
    );
    await settleUntil(tester, () => find.text('1 / 56').evaluate().isNotEmpty);
    expect(find.text('1 / 56'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'identity switch discards previous lesson state and confirmation',
    (tester) async {
      size(tester);
      const a = '11111111-1111-4111-8111-111111111111';
      const b = '22222222-2222-4222-8222-222222222222';
      final id = ValueNotifier<String?>(a);
      addTearDown(id.dispose);
      final course = content.calisthenicsCourse;
      await realIo(
        tester,
        () => calisthenicsProgressStoreFor(
          temp,
          a,
        ).markPractised(course, course.lessons.first),
      );
      final connection = AccountConnection(
        userId: id,
        pageBuilder: (_) => const SizedBox(),
      );
      await tester.pumpWidget(
        host(
          AccountScope(
            connection: connection,
            currentUserId: a,
            child: CalisthenicsLessonScreen(
              course: course,
              lesson: course.lessons.first,
              storeLoader: (id) async => calisthenicsProgressStoreFor(temp, id),
            ),
          ),
        ),
      );
      await settleUntil(
        tester,
        () => find.text('Görev bildirimleri: 1').evaluate().isNotEmpty,
      );
      await to(tester, const Key('calisthenics.confirm'));
      await tester.tap(find.byKey(const Key('calisthenics.confirm')));
      await tester.pump();
      id.value = b;
      await tester.pump();
      await settleUntil(
        tester,
        () =>
            tester
                .widget<OutlinedButton>(
                  find.byKey(const Key('calisthenics.practised')),
                )
                .onPressed !=
            null,
      );
      expect(find.text('Görev bildirimleri: 0'), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('calisthenics.confirm')),
            )
            .value,
        false,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('calisthenics.complete')),
            )
            .onPressed,
        isNull,
      );
      expect(
        (await realIo(
          tester,
          () => calisthenicsProgressStoreFor(temp, a).load(),
        )).forLesson(course.lessons.first, course.version)?.practiceCount,
        1,
      );
      expect(
        (await realIo(
          tester,
          () => calisthenicsProgressStoreFor(temp, b).load(),
        )).forLesson(course.lessons.first, course.version)?.state,
        CalisthenicsLessonState.seen,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
