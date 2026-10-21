import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/calisthenics_course.dart';
import 'package:gravita/app/catalogue_translations_tr.dart';
import 'package:gravita/app/localization/locale_delegate.dart';
import 'package:gravita/app/progress_copy.dart';
import 'package:gravita/app/progress_strings.dart';
import 'package:gravita/app/study_review_content.dart';
import 'package:gravita_engine/gravita_engine.dart';

const _titleId = 'g_000000000001';
const _countId = 'g_000000000002';
const _gripId = 'g_000000000003';
const _upperId = 'g_000000000004';
const _headings = <String, String>{
  'en': 'Written course',
  'tr': 'Yazılı kurs',
  'es-419': 'Curso escrito',
  'pt-BR': 'Curso escrito',
  'de': 'Schriftlicher Kurs',
  'fr': 'Cours écrit',
  'ja': '筆記コース',
  'ar': 'دورة مكتوبة',
  'it': 'Corso scritto',
  'ko': '글로 배우는 과정',
  'id': 'Kursus tertulis',
  'pl': 'Kurs pisemny',
  'hi': 'लिखित पाठ्यक्रम',
  'zh-Hans': '文字课程',
};

class _DisplayBundle extends CachingAssetBundle {
  _DisplayBundle({this.invalidTag});
  final String? invalidTag;

  @override
  Future<ByteData> load(String key) async {
    final tag = key
        .replaceFirst('content/locales/', '')
        .replaceFirst('.json', '');
    if (!_headings.containsKey(tag)) {
      throw StateError('Unexpected fixture $key');
    }
    final messages = <String, String>{
      _titleId: _headings[tag]!,
      _countId: tag == 'ar'
          ? '{count} جلسة'
          : tag == 'tr'
          ? '{count} oturum'
          : '{count} sessions',
      _gripId: tag == 'de' ? 'Griffausdauer' : 'Grip endurance',
      _upperId: tag == 'tr' ? 'i ı' : 'i i',
    };
    final source = jsonEncode(<String, Object>{
      'schemaVersion': 1,
      'localeTag': invalidTag == tag ? 'fr' : tag,
      'messages': messages,
    });
    final bytes = Uint8List.fromList(utf8.encode(source));
    return ByteData.sublistView(bytes);
  }
}

class _EnglishDisplayBundle extends CachingAssetBundle {
  _EnglishDisplayBundle({this.localeTag = 'en'});
  final String localeTag;

  @override
  Future<ByteData> load(String key) async {
    if (key != 'content/locales/display-overrides/en.json') {
      throw StateError('Unexpected English display fixture $key');
    }
    return ByteData.sublistView(
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'schemaVersion': 1,
            'localeTag': localeTag,
            'messages': {_titleId: 'Reviewed written course'},
          }),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(LocaleCatalogRegistry.clearForTesting);
  tearDown(LocaleCatalogRegistry.clearForTesting);

  Widget host(String tag, Widget child, {AssetBundle? bundle}) => MaterialApp(
    locale: localeForAppTag(tag),
    supportedLocales: appSupportedLocales,
    localeListResolutionCallback: resolveAppLocales,
    localizationsDelegates: <LocalizationsDelegate<dynamic>>[
      GravitaLocalizationsDelegate(bundle: bundle ?? _DisplayBundle()),
      ...appLocalizationsDelegates.where(
        (d) => d is! GravitaLocalizationsDelegate,
      ),
    ],
    home: Scaffold(body: child),
  );

  for (final tag in supportedLocaleTags) {
    for (final layout in <({double width, double scale})>[
      (width: 320, scale: 2),
      (width: 1024, scale: 1),
    ]) {
      testWidgets(
        '$tag ${layout.width}px/${layout.scale}x reader locale and direction',
        (tester) async {
          tester.view.physicalSize = Size(layout.width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          const course = CourseText('Written course', 'Türkçe yedek');
          const study = StudyText('Written course', 'Türkçe yedek');
          late String selected;
          late TextDirection direction;
          late GravitaLocalizations? loaded;
          await tester.pumpWidget(
            host(
              tag,
              Builder(
                builder: (context) {
                  selected = Localizations.localeOf(context).toLanguageTag();
                  direction = Directionality.of(context);
                  loaded = Localizations.of<GravitaLocalizations>(
                    context,
                    GravitaLocalizations,
                  );
                  return MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(layout.scale)),
                    child: Column(
                      children: <Widget>[
                        Text(
                          course.inLanguage(selected),
                          key: const Key('course'),
                        ),
                        Text(
                          study.inLanguage(selected),
                          key: const Key('study'),
                        ),
                        Text(
                          localized(context, 'Written course', 'Türkçe yedek'),
                          key: const Key('helper'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(selected, tag);
          expect(loaded?.localeTag, tag);
          expect(
            direction,
            tag == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(find.text(_headings[tag]!), findsNWidgets(3));
          expect(course.en, 'Written course');
          expect(course.tr, 'Türkçe yedek');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'locale change resolves readers without changing source or identity',
    (tester) async {
      final course = CourseText.parse(<String, String>{
        'en': 'Written course',
        'tr': 'Türkçe yedek',
      });
      const study = StudyText('Written course', 'Türkçe yedek');
      final bundle = _DisplayBundle();
      Widget reader() => Builder(
        builder: (context) => Text(
          course.inLanguage(Localizations.localeOf(context).toLanguageTag()),
        ),
      );
      for (final tag in supportedLocaleTags) {
        await tester.pumpWidget(host(tag, reader(), bundle: bundle));
        await tester.pumpAndSettle();
        expect(find.text(_headings[tag]!), findsOneWidget);
        expect(study.inLanguage(tag), _headings[tag]);
        expect(course.en, 'Written course');
        expect(course.tr, 'Türkçe yedek');
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'named Arabic values keep isolation and semantic label at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      try {
        late String label;
        await tester.pumpWidget(
          host(
            'ar',
            Builder(
              builder: (context) {
                label = localized(
                  context,
                  '{count} sessions',
                  '{count} oturum',
                  values: const <String, Object>{'count': 12},
                );
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(2)),
                  child: TextButton(onPressed: () {}, child: Text(label)),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(label, '\u2068${formatLocaleNumber(12, 'ar')}\u2069 جلسة');
        expect(find.bySemanticsLabel(label), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  test('locale resolution preserves script and device preference order', () {
    expect(
      resolveAppLocales(const [
        Locale('zh', 'TW'),
        Locale('it', 'IT'),
      ], appSupportedLocales),
      const Locale('it'),
    );
    expect(
      resolveAppLocales(const [
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        Locale('tr', 'TR'),
      ], appSupportedLocales),
      const Locale('tr'),
    );
    expect(
      resolveAppLocales(const [Locale('zh', 'CN')], appSupportedLocales),
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    );
    expect(
      resolveAppLocales(const [
        Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
          countryCode: 'TW',
        ),
      ], appSupportedLocales),
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    );
    expect(
      resolveAppLocales(const [Locale('zh', 'HK')], appSupportedLocales),
      const Locale('en'),
    );
    expect(
      resolveAppLocales(const [Locale('pt', 'PT')], appSupportedLocales),
      const Locale('en'),
    );
    expect(
      resolveAppLocales(const [Locale('es', 'MX')], appSupportedLocales),
      const Locale('es', '419'),
    );
    expect(resolveAppLocales(null, appSupportedLocales), const Locale('en'));
    expect(
      appSupportedLocales.map((locale) => locale.toLanguageTag()).toSet(),
      supportedLocaleTags.toSet(),
    );
  });

  testWidgets(
    'catalogue ID and complete source guard survives new locale lookup',
    (tester) async {
      late List<String> copy;
      await tester.pumpWidget(
        host(
          'de',
          Builder(
            builder: (context) {
              copy = <String>[
                catalogueText(
                  context,
                  'farmer_carry',
                  CatalogueTextKind.notMeasured,
                  'Grip endurance',
                ),
                catalogueText(
                  context,
                  'future_movement',
                  CatalogueTextKind.notMeasured,
                  'Grip endurance',
                ),
                catalogueText(
                  context,
                  'farmer_carry',
                  CatalogueTextKind.notMeasured,
                  'Grip endurance revised',
                ),
              ];
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(copy, <String>[
        'Griffausdauer',
        'Grip endurance',
        'Grip endurance revised',
      ]);
    },
  );

  testWidgets(
    'display uppercasing follows source lookup and Turkish dotted i',
    (tester) async {
      late String result;
      for (final tag in <String>['en', 'tr']) {
        await tester.pumpWidget(
          host(
            tag,
            Builder(
              builder: (context) {
                result = localizedUpper(context, 'i i', 'i ı');
                return Text(result);
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(result, tag == 'tr' ? 'İ I' : 'I I');
      }
    },
  );

  for (final tag in <String>['en', 'tr']) {
    testWidgets(
      '$tag progress templates preserve baseline units and closed measurement boundary',
      (tester) async {
        late ProgressCopy copy;
        await tester.pumpWidget(
          host(
            tag,
            Builder(
              builder: (context) {
                copy = ProgressCopy(context);
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final n in <int>[0, 1, 2, 3, 11, 100]) {
          expect(
            copy.units(n, 'rep'),
            tag == 'tr' ? '$n tekrar' : ProgressStrings.units(n, 'rep'),
          );
          expect(
            copy.units(n, 'second'),
            tag == 'tr' ? '$n saniye' : ProgressStrings.units(n, 'second'),
          );
          expect(copy.units(n, 'future_unit'), '$n future_unit');
          expect(
            copy.sessions(n),
            tag == 'tr' ? '$n oturum' : ProgressStrings.sessions(n),
          );
          if (tag == 'en') {
            expect(copy.historyPartial(n), ProgressStrings.historyPartial(n));
            expect(copy.unscored(n), ProgressStrings.unscored(n));
            expect(
              copy.retroactiveWithheld(n),
              ProgressStrings.retroactiveWithheld(n),
            );
            expect(copy.orphanRecords(n), ProgressStrings.orphanRecords(n));
          }
        }
        for (final seconds in <int>[0, 59, 60, 61, 120]) {
          if (tag == 'en') {
            expect(copy.worked(seconds), ProgressStrings.worked(seconds));
          }
        }
        expect(
          copy.unmeasured(2, 'rep', <String>['framing', 'future_reason']),
          tag == 'tr'
              ? '2 tekrar ölçülemedi (kadraj, future_reason). İlerlemen azalmaz.'
              : ProgressStrings.unmeasured(2, 'rep', <String>[
                  'framing',
                  'future_reason',
                ]),
        );
        SessionRecord record(String unit, int n) => SessionRecord(
          lessonId: 'fixture.lesson',
          completedAt: DateTime.utc(2026, 10, 19),
          workedSeconds: 60,
          unitsCompleted: n,
          plannedUnits: n,
          unitLabel: unit,
          lessonClass: 'measurementOnly',
          unmeasuredUnits: 0,
          unmeasuredReason: null,
        );
        expect(
          copy.freeSessions(<SessionRecord>[
            record('rep', 3),
            record('second', 45),
          ]),
          tag == 'tr'
              ? '2 oturum · 3 tekrar · 45 saniye sayıldı'
              : '2 sessions · 3 reps · 45 seconds counted',
        );
        final summary = ProgressSummary.build(
          lessonSurfaces: const <LessonSurface>[
            LessonSurface(
              id: 'future.lesson',
              displayName: 'Future lesson',
              movementName: 'Future movement',
              unitLabel: 'rep',
              gradedToday: false,
              lockedReason: 'Changed measurement contract.',
            ),
          ],
          records: const <SessionRecord>[],
        );
        final lesson = summary.lessons.single;
        expect(copy.lessonName(lesson), 'Future lesson');
        expect(copy.movementName(lesson), 'Future movement');
        expect(copy.lockedReason(lesson), 'Changed measurement contract.');
        expect(
          copy.releaseBoundary,
          contains(
            tag == 'tr'
                ? 'canlı kamera oturumları kullanılamıyor'
                : 'Live camera sessions are unavailable',
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'delegate rejects an asset whose tag does not match the requested locale',
    () async {
      final delegate = GravitaLocalizationsDelegate(
        bundle: _DisplayBundle(invalidTag: 'de'),
      );
      await expectLater(
        delegate.load(const Locale('de')),
        throwsFormatException,
      );
    },
  );

  test(
    'delegate loads English display copy without changing source lookup',
    () async {
      final delegate = GravitaLocalizationsDelegate(
        bundle: _DisplayBundle(),
        englishDisplayBundle: _EnglishDisplayBundle(),
      );
      for (final locale in [const Locale('en'), const Locale('de')]) {
        await delegate.load(locale);
        expect(
          resolveLocalized('en', 'Written course'),
          'Reviewed written course',
        );
        expect(resolveLocalized('en', 'Grip endurance'), 'Grip endurance');
        expect(
          resolveLocalized('de', 'Written course'),
          locale.languageCode == 'de' ? _headings['de'] : 'Written course',
        );
      }
    },
  );

  test('delegate rejects a non-English display override asset', () async {
    final delegate = GravitaLocalizationsDelegate(
      bundle: _DisplayBundle(),
      englishDisplayBundle: _EnglishDisplayBundle(localeTag: 'de'),
    );
    await expectLater(delegate.load(const Locale('en')), throwsFormatException);
  });
}
