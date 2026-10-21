import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/catalog_copy_tr.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/library_model.dart';
import 'package:gravita/app/library_screen.dart';
import 'package:gravita/app/movement_page.dart';
import 'package:gravita/app/why_not_here_screen.dart';

import 'support/locale_asset_harness.dart'
    show warmActualLocaleAssets, pumpActualLocaleReady;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentRepository content;
  late Map<String, dynamic> rawLibrary;
  setUpAll(() async {
    await warmActualLocaleAssets();
    content = await ContentRepository.load(rootBundle);
    rawLibrary =
        jsonDecode(await rootBundle.loadString('content/library.json'))
            as Map<String, dynamic>;
  });

  Widget host(Locale locale, Widget child) => MaterialApp(
    locale: locale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    home: child,
  );

  testWidgets('Turkish catalog copy is covered by exact source guards', (
    tester,
  ) async {
    late Set<String> untranslatedBlurbs;
    late Set<String> untranslatedWarnings;
    late Set<String> untranslatedExamples;
    late int translatedTitles;
    late int translatedReasons;
    late bool introTranslated;
    await tester.pumpWidget(
      host(
        const Locale('tr'),
        Builder(
          builder: (context) {
            untranslatedBlurbs = content.catalogue.movements
                .where(
                  (movement) =>
                      movementBlurb(context, movement) == movement.blurb,
                )
                .map((movement) => movement.id)
                .toSet();
            untranslatedWarnings = content.catalogue.movements
                .expand((movement) => movement.safetyWarnings)
                .where((warning) => safetyWarning(context, warning) == warning)
                .toSet();
            translatedTitles = content.catalogue.exclusions.sections
                .where(
                  (section) =>
                      exclusionSectionTitle(context, section) != section.title,
                )
                .length;
            translatedReasons = content.catalogue.exclusions.sections
                .where(
                  (section) =>
                      exclusionSectionReason(context, section) !=
                      section.userReason,
                )
                .length;
            untranslatedExamples = content.catalogue.exclusions.sections
                .expand((section) => section.examples)
                .where(
                  (example) => exclusionExample(context, example) == example,
                )
                .toSet();
            introTranslated =
                exclusionPageIntro(context, content.catalogue.exclusions) !=
                content.catalogue.exclusions.intro;
            return const SizedBox();
          },
        ),
      ),
    );
    await pumpActualLocaleReady(tester);
    expect(untranslatedBlurbs, isEmpty);
    expect(untranslatedWarnings, isEmpty);
    expect(translatedTitles, content.catalogue.exclusions.sections.length);
    expect(translatedReasons, content.catalogue.exclusions.sections.length);
    expect(untranslatedExamples, <String>{
      'Leg press',
      'Lat pulldown',
      'Hack squat',
    });
    expect(introTranslated, isTrue);
  });

  testWidgets(
    'closed metadata stays guarded and live copy obeys release policy',
    (tester) async {
      final original = MovementEntry.fromJson(
        (rawLibrary['movements'] as List<dynamic>)[2] as Map<String, dynamic>,
      );
      final changed = MovementEntry.fromJson(<String, dynamic>{
        ...(rawLibrary['movements'] as List<dynamic>)[2]
            as Map<String, dynamic>,
        'blurb': 'New source wording requiring review.',
      });
      final liveSource = (rawLibrary['movements'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((movement) => movement['id'] == 'bodyweight_squat');
      final changedLive = MovementEntry.fromJson(<String, dynamic>{
        ...liveSource,
        'blurb': 'Changed live description requiring review.',
      });
      late String english;
      late String changedTurkish;
      late String changedLiveTurkish;
      await tester.pumpWidget(
        host(
          const Locale('en'),
          Builder(
            builder: (context) {
              english = movementBlurb(context, original);
              return const SizedBox();
            },
          ),
        ),
      );
      await pumpActualLocaleReady(tester);
      await tester.pumpWidget(
        host(
          const Locale('tr'),
          Builder(
            builder: (context) {
              changedTurkish = movementBlurb(context, changed);
              changedLiveTurkish = movementBlurb(context, changedLive);
              return const SizedBox();
            },
          ),
        ),
      );
      await pumpActualLocaleReady(tester);
      // Readiness is observed at the Navigator before locale dependents
      // rebuild; after a locale switch, pump that rebuild frame.
      await tester.pump();
      expect(english, original.blurb);
      expect(changedTurkish, changed.blurb);
      expect(
        changedLiveTurkish,
        contains('Canlı kamera seansları bu sürümde kullanılamıyor'),
      );
      expect(changedLiveTurkish, isNot(changedLive.blurb));
    },
  );

  testWidgets('live blurbs and closed planche match startable contracts', (
    tester,
  ) async {
    final squat = content.catalogue.movements.firstWhere(
      (movement) => movement.id == 'bodyweight_squat',
    );
    final pushUp = content.catalogue.movements.firstWhere(
      (movement) => movement.id == 'push_up',
    );
    final planche = content.catalogue.movements.firstWhere(
      (movement) => movement.id == 'tuck_planche',
    );
    expect(content.liveConfig?.id, 'bodyweight_squat');
    expect(content.startableConfigFor('push_up')?.id, 'push_up');
    expect(squat.isLive, isTrue);
    expect(pushUp.isLive, isTrue);
    expect(planche.isLive, isFalse);
    expect(planche.courseCount, 0);
    expect(planche.safetyWarnings, <String>[
      'High wrist and elbow load. Build the lean gradually; stop at joint pain.',
    ]);
    expect(pushUp.blurb, contains('median down/up tempo after the set'));
    expect(pushUp.blurb, contains('cue is not displayed during the set'));

    late String squatTurkish;
    late String pushUpTurkish;
    await tester.pumpWidget(
      host(
        const Locale('tr'),
        Builder(
          builder: (context) {
            squatTurkish = movementBlurb(context, squat);
            pushUpTurkish = movementBlurb(context, pushUp);
            return const SizedBox();
          },
        ),
      ),
    );
    await pumpActualLocaleReady(tester);
    for (final displayed in [squatTurkish, pushUpTurkish]) {
      expect(
        displayed,
        contains('Canlı kamera seansları bu sürümde kullanılamıyor'),
      );
      expect(displayed, isNot(contains('sayar')));
      expect(displayed, isNot(contains('temponu ölçeriz')));
      expect(displayed, isNot(contains('ortancasını gösteririz')));
    }
  });

  testWidgets('both live honesty contracts have guarded Turkish copy', (
    tester,
  ) async {
    final live = content.catalogue.movements
        .where((movement) => movement.isLive)
        .toList(growable: false);
    expect(live.map((movement) => movement.id).toSet(), <String>{
      'bodyweight_squat',
      'push_up',
    });
    late List<(String, String)> pairs;
    late String changedSource;
    late String wrongMovement;
    await tester.pumpWidget(
      host(
        const Locale('tr'),
        Builder(
          builder: (context) {
            pairs = <(String, String)>[
              for (final movement in live)
                for (final source in <String>[
                  ...movement.honesty.measured,
                  ...movement.honesty.notMeasured,
                  movement.honesty.scoring!,
                ])
                  (source, liveHonestyCopy(context, movement.id, source)),
            ];
            changedSource = liveHonestyCopy(
              context,
              'push_up',
              'Force or load — source changed',
            );
            wrongMovement = liveHonestyCopy(
              context,
              'bodyweight_squat',
              'Force or load',
            );
            return const SizedBox();
          },
        ),
      ),
    );
    await pumpActualLocaleReady(tester);
    expect(pairs, hasLength(13));
    for (final (source, translated) in pairs) {
      expect(translated, isNot(source), reason: source);
    }
    expect(changedSource, 'Force or load — source changed');
    expect(wrongMovement, 'Force or load');

    late String english;
    await tester.pumpWidget(
      host(
        const Locale('en'),
        Builder(
          builder: (context) {
            english = liveHonestyCopy(context, 'push_up', 'Force or load');
            return const SizedBox();
          },
        ),
      ),
    );
    await pumpActualLocaleReady(tester);
    // Same locale-switch rebuild frame as above.
    await tester.pump();
    expect(english, 'Force or load');
  });

  testWidgets(
    'Turkish Push-Up detail states unavailable measurements and limits',
    (tester) async {
      await tester.pumpWidget(
        host(
          const Locale('tr'),
          MovementPage(
            movement: content.catalogue.byId('push_up')!,
            content: content,
          ),
        ),
      );
      await pumpActualLocaleReady(tester);
      expect(
        find.textContaining('tekrarlarını saymaz veya zamanlamaz'),
        findsOneWidget,
      );
      expect(find.textContaining('gövdeniz gerçekten yatay'), findsNothing);
      expect(find.text('Kuvvet veya yük'), findsOneWidget);
      expect(find.text('Kas aktivasyonu'), findsOneWidget);
      expect(find.text('Eldeki basınç dağılımı'), findsOneWidget);
      expect(find.text('Force or load'), findsNothing);
      expect(
        find.textContaining('Bu sürüm formunu ölçmez veya puanlamaz'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Turkish Library exclusion search opens a Turkish reason page', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const Locale('tr'), LibraryScreen(content: content)),
    );
    await pumpActualLocaleReady(tester);
    await tester.scrollUntilVisible(
      find.byKey(LibraryScreen.searchFieldKey),
      200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 100,
    );
    await tester.enterText(
      find.byKey(LibraryScreen.searchFieldKey),
      'leg press',
    );
    await tester.pump();
    expect(find.text('Spor salonu makineleri'), findsOneWidget);
    expect(find.textContaining('Tahminde bulunmak yerine'), findsOneWidget);
    tester.testTextInput.hide();
    await tester.pump();
    final exclusion = find.byKey(const Key('library.exclusion.machines'));
    await tester.scrollUntilVisible(
      exclusion,
      150,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 100,
    );
    await tester.ensureVisible(exclusion);
    await tester.pumpAndSettle();
    await tester.tap(exclusion);
    await tester.pumpAndSettle();
    expect(find.byType(WhyNotHereScreen), findsOneWidget);
    expect(find.text('Gravita’da neler yok — ve neden'), findsOneWidget);
    expect(find.textContaining('kapsamı sınırlı tutuyoruz'), findsOneWidget);
    expect(find.text('SINIF C'), findsOneWidget);
    expect(
      find.text('Tek telefon kamerası gerekenleri göremez.'),
      findsWidgets,
    );
  });

  testWidgets('Turkish movement detail renders guarded blurb and safety copy', (
    tester,
  ) async {
    final closed = content.catalogue.byId('farmer_carry')!;
    await tester.pumpWidget(
      host(
        const Locale('tr'),
        MovementPage(movement: closed, content: content),
      ),
    );
    await pumpActualLocaleReady(tester);
    expect(
      find.textContaining('3 ölçüm eksik; adları ve gerekçeleri aşağıda.'),
      findsOneWidget,
    );

    final handstand = content.catalogue.byId('wall_handstand')!;
    await tester.pumpWidget(
      host(
        const Locale('tr'),
        MovementPage(movement: handstand, content: content),
      ),
    );
    await pumpActualLocaleReady(tester);
    await tester.scrollUntilVisible(
      find.byKey(MovementPage.safetyKey),
      400,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 30,
    );
    await tester.pump();
    expect(
      find.text(
        'Düşme riski gerçektir. Alanı boşalt, duvar kullan ve '
        'çıktığın yoldan geri in.',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });
}
