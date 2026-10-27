import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// K-6 (founder decision 2026-10-27): store listing drafts in all 14 app
// languages. tools/validate_store_listing.py proves the EN/TR claims against
// the courses; this guards the 12 translations against drift from the EN
// source shape, the store field limits and the localized camera rationale.
const _locales = <String>[
  'es-419',
  'pt-BR',
  'de',
  'fr',
  'ja',
  'ar',
  'it',
  'ko',
  'id',
  'pl',
  'hi',
  'zh-Hans',
];

Map<String, Object?> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

void main() {
  final en = _read('docs/store/listing.json');
  final enParagraphs = (en['description']! as String).split('\n\n').length;

  test('every app language has a listing draft', () {
    expect(File('docs/store/listing.tr-TR.json').existsSync(), isTrue);
    final drafts = Directory('docs/store')
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .where((name) => RegExp(r'^listing\.[^.]+\.json$').hasMatch(name))
        .toSet();
    expect(drafts, {
      'listing.tr-TR.json',
      for (final locale in _locales) 'listing.$locale.json',
    });
  });

  for (final locale in _locales) {
    test('listing.$locale matches the EN source shape and store limits', () {
      final l = _read('docs/store/listing.$locale.json');
      expect(l.keys.toSet(), {
        r'$doc',
        r'$storeLocales',
        'appStore',
        'playStore',
        'description',
        'cameraPermissionRationale',
        'supportUrl',
        'privacyPolicyUrl',
      });
      expect(l[r'$doc'], contains('Not submitted'));
      expect(l['supportUrl'], en['supportUrl']);
      expect(l['privacyPolicyUrl'], en['privacyPolicyUrl']);

      final app = l['appStore']! as Map<String, Object?>;
      final limits = {
        'name': 30,
        'subtitle': 30,
        'promotionalText': 170,
        'keywords': 100,
      };
      expect(app.keys.toSet(), limits.keys.toSet());
      for (final MapEntry(key: field, value: max) in limits.entries) {
        final text = app[field]! as String;
        expect(text.trim(), isNotEmpty, reason: field);
        expect(text.length, lessThanOrEqualTo(max), reason: field);
      }
      expect(app['name'], startsWith('Gravita'));
      final short =
          (l['playStore']! as Map<String, Object?>)['shortDescription']!
              as String;
      expect(short.length, inInclusiveRange(1, 80));

      final description = l['description']! as String;
      expect(description.length, lessThanOrEqualTo(4000));
      expect(description.split('\n\n').length, enParagraphs);
      // Same counted facts as the EN source: 117 lessons / 7 courses, 44
      // free, 56 calisthenics lessons in 10 modules, 12-lesson foundations,
      // supervised teens aged 13-17.
      for (final number in ['117', '7', '44', '56', '10', '12', '13', '17']) {
        expect(description, contains(number), reason: number);
      }
      expect(description, contains('Motion+'));

      final camera = l['cameraPermissionRationale']! as Map<String, Object?>;
      final plist = File(
        'ios/Runner/$locale.lproj/InfoPlist.strings',
      ).readAsStringSync();
      final match = RegExp(
        r'"NSCameraUsageDescription"\s*=\s*"((?:[^"\\]|\\.)*)";',
      ).firstMatch(plist)!;
      expect(camera['ios'], match.group(1));
    });
  }
}
