import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/catalogue_translations_tr.dart';
import 'package:gravita/app/content_repository.dart';

void main() {
  final fixture =
      (jsonDecode(
                File(
                  'test/fixtures/catalogue-tr-completion.json',
                ).readAsStringSync(),
              )
              as Map)['entries']
          as List;
  const kinds = {
    'notMeasured': CatalogueTextKind.notMeasured,
    'comingSoon': CatalogueTextKind.comingSoon,
    'formError.label': CatalogueTextKind.ruleLabel,
    'formError.cue': CatalogueTextKind.ruleCue,
  };
  late ContentRepository content;
  setUp(() async {
    content = await ContentRepository.load(rootBundle);
    await Future.wait(
      content.catalogue.movements.map((m) => content.catalogFor(m.id)),
    );
  });

  for (final language in ['en', 'tr']) {
    testWidgets(
      '$language closes all233 real remaining uses with guarded sources',
      (tester) async {
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            home: Builder(
              builder: (value) {
                context = value;
                return const SizedBox();
              },
            ),
          ),
        );
        final used = <String>{};
        final counts = <String, int>{};
        for (final movement in content.catalogue.movements) {
          final config = await content.catalogFor(movement.id);
          final sources = <String, Iterable<String>>{
            'notMeasured': movement.honesty.notMeasured,
            'comingSoon': movement.comingSoon,
            'formError.label': config.formErrors.map((e) => e.label),
            'formError.cue': config.formErrors.map((e) => e.cue),
          };
          for (final entry in sources.entries) {
            for (final source in entry.value) {
              final matching = fixture.where(
                (f) =>
                    f['kind'] == entry.key &&
                    f['english'] == source &&
                    (f['movement_ids'] as List).contains(movement.id),
              );
              if (matching.isEmpty) continue;
              expect(matching.length, 1);
              final approved = matching.single;
              final actual = catalogueText(
                context,
                movement.id,
                kinds[entry.key]!,
                source,
              );
              expect(
                actual,
                approved[language == 'tr' ? 'turkish' : 'english'],
                reason: '${movement.id}/${entry.key}',
              );
              expect(
                catalogueText(
                  context,
                  movement.id,
                  kinds[entry.key]!,
                  '$source Revised.',
                ),
                '$source Revised.',
              );
              expect(
                catalogueText(
                  context,
                  'future_movement',
                  kinds[entry.key]!,
                  source,
                ),
                source,
              );
              for (final otherKind in kinds.values.where(
                (k) => k != kinds[entry.key],
              )) {
                expect(
                  catalogueText(context, movement.id, otherKind, source),
                  source,
                );
              }
              final key = '${movement.id}/${entry.key}/$source';
              expect(used.add(key), isTrue);
              counts.update(entry.key, (n) => n + 1, ifAbsent: () => 1);
            }
          }
        }
        expect(fixture.length, 221);
        expect(used.length, 233);
        expect(counts, {
          'notMeasured': 50,
          'comingSoon': 41,
          'formError.label': 71,
          'formError.cue': 71,
        });
        for (final approved in fixture) {
          final en = approved['english'] as String;
          final tr = approved['turkish'] as String;
          expect(tr, isNot(en));
          expect(tr.trim(), isNotEmpty);
          List<String> numbers(String s) =>
              RegExp(r'\d+(?:[.,]\d+)?')
                  .allMatches(s)
                  .map((m) => m.group(0)!.replaceAll(',', '.'))
                  .toList()
                ..sort();
          expect(numbers(tr), numbers(en), reason: en);
          for (final token in ['ATTESTED', 'derivedJoints']) {
            expect(
              token.allMatches(tr).length,
              token.allMatches(en).length,
              reason: en,
            );
          }
          for (final id in approved['movement_ids'] as List) {
            expect(
              used.contains('$id/${approved['kind']}/$en'),
              isTrue,
              reason: 'orphan translation',
            );
          }
        }
      },
    );
  }
}
