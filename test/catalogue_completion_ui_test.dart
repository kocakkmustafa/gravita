import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/movement_page.dart';
import 'package:gravita/app/theme.dart';

void main() {
  late ContentRepository content;
  late List<Map<String, dynamic>> translations;
  setUp(() async {
    content = await ContentRepository.load(rootBundle);
    await Future.wait(
      content.catalogue.movements.map((m) => content.catalogFor(m.id)),
    );
    translations =
        ((jsonDecode(
                      File(
                        'test/fixtures/catalogue-tr-completion.json',
                      ).readAsStringSync(),
                    )
                    as Map)['entries']
                as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
  });

  Widget host(Widget child, String language) => MaterialApp(
    theme: GravitaTheme.light,
    locale: Locale(language),
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
      child: child!,
    ),
    home: child,
  );

  final movementIds =
      ((jsonDecode(File('content/library.json').readAsStringSync())
                  as Map)['movements']
              as List)
          .map((m) => m['id'] as String);
  for (final movementId in movementIds) {
    for (final language in ['en', 'tr']) {
      testWidgets('$language $movementId catalogue renders at320px/2x', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          host(
            MovementPage(
              content: content,
              movement: content.catalogue.byId(movementId)!,
            ),
            language,
          ),
        );
        await tester.pumpAndSettle();
        final selected = translations.where(
          (e) => (e['movement_ids'] as List).contains(movementId),
        );
        for (final key in [
          MovementPage.honestyKey,
          MovementPage.queueKey,
          MovementPage.formErrorsKey,
        ]) {
          await tester.scrollUntilVisible(
            find.byKey(key),
            300,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 200,
          );
          await tester.ensureVisible(find.byKey(key));
          await tester.pumpAndSettle();
          final kinds = key == MovementPage.honestyKey
              ? ['notMeasured']
              : key == MovementPage.queueKey
              ? ['comingSoon']
              : ['formError.label', 'formError.cue'];
          if (key == MovementPage.queueKey) {
            expect(
              find.descendant(
                of: find.byKey(key),
                matching: find.text(
                  language == 'tr'
                      ? 'Bu açıklamalar ölçüm kataloğuna aittir. Canlı kamera oturumları ve kamera geri bildirimi bu sürümde kullanılamıyor.'
                      : 'These descriptions belong to the measurement catalogue. Live camera sessions and camera feedback are unavailable in this release.',
                ),
              ),
              findsOneWidget,
            );
          }
          for (final entry in selected.where(
            (e) => kinds.contains(e['kind']),
          )) {
            expect(
              find.descendant(
                of: find.byKey(key),
                matching: find.text(
                  entry[language == 'tr' ? 'turkish' : 'english'] as String,
                ),
              ),
              findsOneWidget,
            );
          }
        }
        expect(find.byKey(MovementPage.startSessionKey), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
