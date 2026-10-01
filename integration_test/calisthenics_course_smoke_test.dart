import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:gravita/app/account_connection.dart';
import 'package:gravita/app/account_data_directory.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/calisthenics_course_screen.dart';
import 'package:gravita/app/calisthenics_progress.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/theme.dart';

/// Native plugin/UI smoke only. No auth provider, camera, pose, physiological
/// readiness, media or purchase acceptance is inferred from this test.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native calisthenics asset, account task save and file readback', (
    tester,
  ) async {
    final actualSupport = await getApplicationSupportDirectory();
    final owned = await Directory(
      '${actualSupport.path}/gravita-course-native-smoke-${DateTime.now().microsecondsSinceEpoch}',
    ).create();
    const userId = '77777777-7777-4777-8777-777777777777';
    final identity = ValueNotifier<String?>(userId);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await deleteAccountData(owned, userId);
      identity.dispose();
      if (await owned.exists()) await owned.delete(recursive: true);
      debugPrint(
        'GRAVITA_COURSE_SMOKE_CLEANUP: ${owned.path} exists=${await owned.exists()}',
      );
    });
    final content = await ContentRepository.load(rootBundle);
    expect(content.calisthenicsCourse.lessons.length, 56);
    expect(content.catalogue.liveCount, 2);
    Future<CalisthenicsProgressStore> loader(String? id) =>
        ContentRepository.openCalisthenicsProgressStore(
          accountUserId: id,
          supportDirectory: owned,
        );
    Widget host() => AccountScope(
      connection: AccountConnection(
        userId: identity,
        pageBuilder: (_) => const SizedBox.shrink(),
      ),
      currentUserId: userId,
      child: MaterialApp(
        theme: GravitaTheme.light,
        locale: const Locale('tr'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: CalisthenicsCourseScreen(
          course: content.calisthenicsCourse,
          storeLoader: loader,
        ),
      ),
    );
    Future<void> waitFor(bool Function() ready) async {
      for (var round = 0; round < 40 && !ready(); round++) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await tester.pump(const Duration(milliseconds: 80));
      }
      expect(
        ready(),
        isTrue,
        reason: 'Bounded native storage/UI wait did not complete',
      );
    }

    Future<void> to(Key key, {double delta = 200}) async {
      final body = find.byKey(
        find.byKey(const Key('calisthenics.lesson.body')).evaluate().isNotEmpty
            ? const Key('calisthenics.lesson.body')
            : const Key('calisthenics.course.body'),
      );
      await tester.scrollUntilVisible(
        find.byKey(key),
        delta,
        scrollable: find
            .descendant(of: body, matching: find.byType(Scrollable))
            .first,
        maxScrolls: 40,
      );
      await tester.pump();
    }

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await to(const Key('calisthenics.next'));
    await tester.tap(find.byKey(const Key('calisthenics.next')));
    await tester.pumpAndSettle();
    await to(const Key('calisthenics.practised'));
    await waitFor(
      () =>
          tester
              .widget<OutlinedButton>(
                find.byKey(const Key('calisthenics.practised')),
              )
              .onPressed !=
          null,
    );
    await tester.tap(find.byKey(const Key('calisthenics.practised')));
    await to(const Key('calisthenics.confirm'));
    await waitFor(
      () =>
          tester
              .widget<CheckboxListTile>(
                find.byKey(const Key('calisthenics.confirm')),
              )
              .onChanged !=
          null,
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('calisthenics.confirm')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pump();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('calisthenics.confirm')),
          )
          .value,
      true,
    );
    await to(const Key('calisthenics.complete'));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('calisthenics.complete')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('calisthenics.complete')));
    await to(const Key('calisthenics.state'), delta: -200);
    await waitFor(
      () => tester
          .widget<Text>(find.byKey(const Key('calisthenics.state')))
          .data!
          .startsWith('Öğrenme tamamlandı'),
    );
    final file = (await loader(userId)).file;
    expect(file.path, contains('/accounts/$userId/'));
    expect(await File('${file.path}.tmp').exists(), false);
    final fromNewStore = await CalisthenicsProgressStore(
      File(file.path),
    ).load();
    expect(fromNewStore.completedCount(content.calisthenicsCourse), 1);
    expect(
      fromNewStore
          .forLesson(
            content.calisthenicsCourse.lessons.first,
            content.calisthenicsCourse.version,
          )
          ?.practiceCount,
      1,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(host());
    await waitFor(() => find.text('1 / 56').evaluate().isNotEmpty);
    expect(tester.takeException(), isNull);
    debugPrint(
      'GRAVITA_COURSE_SMOKE_READBACK: version=${content.calisthenicsCourse.version} completed=1/56 accountScoped=true pathProvider=native file=${file.path}',
    );
  });
}
