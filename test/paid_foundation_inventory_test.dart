import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:gravita/app/content_repository.dart';

/// The historical target remains20 camera movement contracts. Teaching access
/// is exercised separately and cannot promote the camera capability gate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  List<Map<String, dynamic>> movements() {
    final Map<String, dynamic> lib =
        (jsonDecode(File('content/library.json').readAsStringSync()) as Map)
            .cast<String, dynamic>();
    return (lib['movements'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Map<String, dynamic> catalogFor(Map<String, dynamic> movement) {
    final String wave = (movement['wave'] as String).toLowerCase();
    final String catalogId =
        (movement['catalogId'] ?? movement['id']) as String;
    return (jsonDecode(
              File('content/catalog/$wave/$catalogId.json').readAsStringSync(),
            )
            as Map)
        .cast<String, dynamic>();
  }

  group('desen kapsamı — push/pull/squat/hinge/core/carry/hold', () {
    final List<Map<String, dynamic>> movs = movements();

    // Aile-bazlı desenler — doğrudan `library.json.family`'den.
    for (final (String pattern, String family) in <(String, String)>[
      ('push', 'push'),
      ('pull', 'pull'),
      ('squat', 'legs'),
      ('core', 'core'),
      ('carry', 'carry'),
    ]) {
      test('$pattern deseninde en az 1 hareket var', () {
        final List<String> found = movs
            .where((Map<String, dynamic> m) => m['family'] == family)
            .map((Map<String, dynamic> m) => m['id'] as String)
            .toList();
        expect(
          found,
          isNotEmpty,
          reason: '$pattern deseni (family=$family) hiç hareket bulamadı',
        );
      });
    }

    test('hinge deseninde en az 1 hareket var (dbkb ailesi, kalça-menteşe '
        'baskın kas grupları)', () {
      // Aile tek başına yetmez — "dbkb" hem hinge (romanian_deadlift,
      // kb_swing) hem başka örüntüleri (db_curl: kol izole) barındırıyor.
      // `muscleGroups`ta AYNI ANDA hamstrings+glutes olması hinge'in
      // hareket-bilimi imzası.
      final List<String> found = movs
          .where((Map<String, dynamic> m) {
            final List<dynamic> mg =
                (m['muscleGroups'] as List<dynamic>?) ?? <dynamic>[];
            return mg.contains('hamstrings') && mg.contains('glutes');
          })
          .map((Map<String, dynamic> m) => m['id'] as String)
          .toList();
      expect(found, isNotEmpty, reason: 'hinge deseni hiç hareket bulamadı');
    });

    test('hold deseninde en az 1 hareket var (engine.type=staticHold)', () {
      final List<String> found = <String>[
        for (final Map<String, dynamic> m in movs)
          if (catalogFor(m)['engine'] != null &&
              (catalogFor(m)['engine'] as Map)['type'] == 'staticHold')
            m['id'] as String,
      ];
      expect(found, isNotEmpty, reason: 'hold deseni hiç hareket bulamadı');
    });
  });

  group('en az 2 skill tree (roadmap §10 paid foundation şartı)', () {
    test('content/skill-trees.index.json en az 2 paket listeler', () {
      final Map<String, dynamic> idx =
          (jsonDecode(File('content/skill-trees.index.json').readAsStringSync())
                  as Map)
              .cast<String, dynamic>();
      final List<dynamic> trees = idx['trees'] as List<dynamic>;
      expect(trees.length, greaterThanOrEqualTo(2));
    });
  });

  group('camera foundation readiness — teaching is not measurement', () {
    test(
      'real packaged contracts report the still-unmet20-movement target',
      () async {
        final content = await ContentRepository.load(rootBundle);
        final coverage = content.foundationCoverage;
        expect(coverage.catalogueIds.length, 31);
        expect(coverage.configuredCameraIds, {'bodyweight_squat', 'push_up'});
        expect(coverage.cameraShortfall, 18);
        expect(coverage.configuredCameraTargetReached, isFalse);
        expect(coverage.cameraUnavailableIds.length, 29);
        expect(coverage.practiceGuideIds.length, 17);
        expect(coverage.readingGuideIds, {'wall_handstand', 'tuck_planche'});
        for (final id in coverage.cameraUnavailableIds) {
          expect(content.startableConfigFor(id), isNull);
        }
      },
    );

    test(
      'a status-only promotion and real teaching links cannot open a camera contract',
      () async {
        final content = await ContentRepository.load(
          _StatusOnlyPromotionBundle(),
        );
        expect(content.catalogue.byId('plank')!.isLive, isTrue);
        expect(content.calisthenicsCourse.guideFor('plank'), isNotNull);
        expect(content.startableConfigFor('plank'), isNull);
        await content.catalogFor('plank');
        expect(content.startableConfigFor('plank'), isNull);
        expect(content.foundationCoverage.configuredCameraIds, {
          'bodyweight_squat',
          'push_up',
        });
        expect(
          content.foundationCoverage.configuredCameraTargetReached,
          isFalse,
        );
      },
    );
  });
}

class _StatusOnlyPromotionBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => rootBundle.load(key);
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final source = await rootBundle.loadString(key);
    if (key != 'content/library.json') return source;
    final json = jsonDecode(source) as Map<String, dynamic>;
    for (final movement in json['movements'] as List) {
      if (movement['id'] == 'plank') movement['status'] = 'live';
    }
    return jsonEncode(json);
  }
}
