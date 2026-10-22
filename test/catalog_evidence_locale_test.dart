import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/catalog_copy_tr.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/movement_page.dart';
import 'package:gravita/app/theme.dart';

import 'support/locale_asset_harness.dart'
    show warmActualLocaleAssets, pumpActualLocaleReady;

void main() {
  setUpAll(warmActualLocaleAssets);
  late ContentRepository content;
  setUp(() async => content = await ContentRepository.load(rootBundle));
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

  for (final language in ['en', 'tr']) {
    testWidgets(
      '$language all real waiting paragraphs use exact-source guards',
      (tester) async {
        late BuildContext context;
        await tester.pumpWidget(
          host(
            Builder(
              builder: (value) {
                context = value;
                return const SizedBox();
              },
            ),
            language,
          ),
        );
        await pumpActualLocaleReady(tester);
        var uses = 0;
        for (final movement in content.catalogue.movements.where(
          (m) => !m.isLive,
        )) {
          for (final source in movement.honesty.waitingOnMeasurement) {
            uses++;
            final text = waitingMeasurementCopy(context, movement, source);
            if (language == 'tr') {
              expect(text, isNot(source), reason: '${movement.id}: $source');
            } else {
              // The reviewed EN display override (g_466c477d6020) corrects
              // only the singular source's grammar; plural sources show as-is.
              const singularSource =
                  'Its 1 error rule have never been run against real '
                  'footage. There is no replay fixture for this movement, so '
                  'we have no evidence they fire when they should — or stay '
                  'quiet when they should.';
              const singularDisplay =
                  'Its 1 error rule has never been run against real footage. '
                  'There is no replay fixture for this movement, so we have '
                  'no evidence that it fires when it should — or stays quiet '
                  'when it should.';
              expect(text, source == singularSource ? singularDisplay : source);
            }
            expect(
              waitingMeasurementCopy(context, movement, '$source Revised.'),
              '$source Revised.',
            );
          }
        }
        expect(uses, 117);
        expect(
          catalogEvidenceCopy(context, 'Future measurement limit'),
          'Future measurement limit',
        );
      },
    );
  }

  testWidgets(
    'real queued movement renders Turkish measurement limits at phone width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        host(
          MovementPage(
            content: content,
            movement: content.catalogue.byId('floor_press')!,
          ),
          'tr',
        ),
      );
      await pumpActualLocaleReady(tester);
      for (final phrase in [
        'Burada hiçbir şey ölçülmüyor.',
        'Bu hareket için henüz hiçbir hata kuralı yazılmadı.',
        'Varsayılan bir sayı ölçüm değildir.',
      ]) {
        await tester.scrollUntilVisible(
          find.textContaining(phrase),
          350,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 80,
        );
        expect(find.textContaining(phrase), findsOneWidget);
      }
      expect(find.byKey(MovementPage.startSessionKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
