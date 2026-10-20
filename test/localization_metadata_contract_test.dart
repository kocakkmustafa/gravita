import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/app_locale.dart';
import 'package:gravita/app/catalog_copy_tr.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/library_model.dart';
import 'package:gravita/app/library_strings.dart';
import 'package:gravita/app/localization/locale_delegate.dart';

import 'support/launch_harness.dart' show settleUntil;

// Source-only authoring task: these definitions are not a runtime result.
// Each expectation requires an exact-case shipping English source and an
// explicit target dictionary entry before checking the production helper.
// A nonempty English/TR fallback therefore cannot satisfy this contract.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentRepository content;
  late Map<String, LocaleCatalog> catalogs;
  late Map<String, String> sourceIds;

  setUpAll(() async {
    content = await ContentRepository.load(rootBundle);
    catalogs = <String, LocaleCatalog>{};
    for (final tag in supportedLocaleTags) {
      catalogs[tag] = LocaleCatalog.parse(
        await rootBundle.loadString('content/locales/$tag.json'),
      );
    }
    final english = catalogs['en']!;
    sourceIds = <String, String>{
      for (final entry in english.messages.entries) entry.value: entry.key,
    };
    expect(
      sourceIds.length,
      english.messages.length,
      reason: 'English source strings must identify one exact message.',
    );
  });

  setUp(LocaleCatalogRegistry.clearForTesting);
  tearDown(LocaleCatalogRegistry.clearForTesting);

  Locale locale(String tag) => switch (tag) {
    'es-419' => const Locale('es', '419'),
    'pt-BR' => const Locale('pt', 'BR'),
    _ => Locale(tag),
  };

  Future<BuildContext> loadContext(WidgetTester tester, String tag) async {
    BuildContext? loaded;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: locale(tag),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: Builder(
          builder: (context) {
            loaded = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await settleUntil(tester, () => loaded != null, maxRounds: 40);
    expect(loaded, isNotNull, reason: '$tag production locale delegate loaded');
    final context = loaded!;
    expect(Localizations.localeOf(context).toLanguageTag(), tag);
    expect(
      Localizations.of<GravitaLocalizations>(
        context,
        GravitaLocalizations,
      )?.localeTag,
      tag,
    );
    expect(tester.takeException(), isNull);
    return context;
  }

  String target(String source, String tag, String path) {
    expect(
      sourceIds.containsKey(source),
      isTrue,
      reason: '$tag $path: missing exact-case English source "$source"',
    );
    final id = sourceIds[source]!;
    final dictionary = catalogs[tag]!;
    expect(dictionary.localeTag, tag);
    expect(
      dictionary.messages.containsKey(id),
      isTrue,
      reason: '$tag $path: missing explicit translation for $id "$source"',
    );
    final expected = dictionary.messages[id]!;
    expect(
      LocaleCatalogRegistry.translatedSource(source, tag),
      expected,
      reason: '$tag $path: production registry must resolve this exact source',
    );
    return expected;
  }

  String upper(String value, String tag) =>
      (tag == 'tr' ? value.replaceAll('i', 'İ').replaceAll('ı', 'I') : value)
          .toUpperCase();

  for (final tag in supportedLocaleTags) {
    testWidgets('$tag shipping metadata has exact dictionary bindings', (
      tester,
    ) async {
      final context = await loadContext(tester, tag);
      final catalogue = content.catalogue;
      expect(catalogue.movements, isNotEmpty);

      for (final family in LibraryCatalogue.familyLabels.entries) {
        expect(
          familyDisplayName(context, family.key, family.value),
          target(family.value, tag, 'family.${family.key}'),
        );
      }

      final equipmentCodes = <String>{};
      for (final movement in catalogue.movements) {
        final path = 'movement.${movement.id}';
        final familySource = LibraryCatalogue.labelFor(movement.family);
        final expectedParts = <String>[
          target(familySource, tag, '$path.family'),
          if (movement.level != null)
            target(
              LibraryCatalogue.labelFor(movement.level!),
              tag,
              '$path.level',
            ),
          if (movement.equipment.isEmpty)
            target(
              LibraryStrings.equipmentLine(const <String>[]),
              tag,
              '$path.noEquipment',
            )
          else
            movement.equipment
                .map(
                  (equipment) => target(
                    LibraryStrings.equipmentLine(<String>[equipment]),
                    tag,
                    '$path.metaEquipment.$equipment',
                  ),
                )
                .join(' · '),
        ];
        expect(
          familyDisplayName(context, movement.family, familySource),
          expectedParts.first,
          reason: '$tag $path actual family source',
        );
        expect(
          movementMetaLine(context, movement),
          expectedParts.join(' · '),
          reason: '$tag $path actual metadata assembly',
        );
        equipmentCodes.addAll(movement.equipment);

        final badge = movement.classBadge;
        if (badge != null) {
          expect(
            movementClassBadge(context, badge),
            upper(target(badge, tag, '$path.badge'), tag),
            reason: '$tag $path resolves source before display casing',
          );
        }
        final classSource = LibraryStrings.classBadgeExplainer(
          movement.movementClass,
        );
        expect(
          movementClassExplanation(context, movement.movementClass),
          classSource.isEmpty ? '' : target(classSource, tag, '$path.class'),
          reason: '$tag $path class explanation',
        );
      }

      expect(equipmentCodes, isNotEmpty);
      for (final equipment in equipmentCodes) {
        // Setup/movement labels use lower-case source tokens, whereas the
        // metadata line uses LibraryStrings' title-cased equipment sources.
        final source = equipment.replaceAll('_', ' ');
        expect(
          equipmentDisplayName(context, equipment),
          target(source, tag, 'equipment.$equipment'),
          reason: '$tag setup equipment source is case-sensitive',
        );
      }

      final trees = catalogue.skillTrees.trees;
      expect(
        trees.map((tree) => tree.packId),
        containsAll(<String>['gravita.handstand', 'gravita.planche']),
      );
      for (final tree in trees) {
        expect(
          skillTreeName(context, tree),
          target(tree.displayName, tag, 'tree.${tree.packId}'),
          reason: '$tag actual shipping tree name',
        );
      }

      expect(catalogue.exclusions.sections, isNotEmpty);
      for (final section in catalogue.exclusions.sections) {
        final source = LibraryStrings.limitClassLine(section.limitClass);
        expect(
          exclusionClassLine(context, section.limitClass),
          source.isEmpty ? '' : target(source, tag, 'exclusion.${section.id}'),
          reason: '$tag actual exclusion class source',
        );
      }
      expect(movementClassExplanation(context, null), isEmpty);
      expect(exclusionClassLine(context, null), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tree translation requires both exact pack and source name', (
    tester,
  ) async {
    final context = await loadContext(tester, 'ar');
    for (final tree in content.catalogue.skillTrees.trees) {
      // Confirm the known pair is connected before testing its guard twins.
      expect(
        skillTreeName(context, tree),
        target(tree.displayName, 'ar', 'known.${tree.packId}'),
      );
      for (final revised in <SkillTree>[
        SkillTree(
          packId: tree.packId,
          displayName: '${tree.displayName} revised',
          nodeCount: tree.nodeCount,
          thresholdsValidated: tree.thresholdsValidated,
          nodeIds: tree.nodeIds,
        ),
        SkillTree(
          packId: 'unknown.${tree.packId}',
          displayName: tree.displayName,
          nodeCount: tree.nodeCount,
          thresholdsValidated: tree.thresholdsValidated,
          nodeIds: tree.nodeIds,
        ),
        SkillTree(
          packId: tree.packId,
          displayName: tree.displayName.toLowerCase(),
          nodeCount: tree.nodeCount,
          thresholdsValidated: tree.thresholdsValidated,
          nodeIds: tree.nodeIds,
        ),
      ]) {
        expect(
          skillTreeName(context, revised),
          revised.displayName,
          reason:
              'Unknown/revised names must not inherit a shipping translation.',
        );
      }
    }
    expect(tester.takeException(), isNull);
  });
}
