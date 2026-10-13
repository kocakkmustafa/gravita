import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'privacy_manifest_test.dart' show productionPackages;

void main() {
  test('shipping graph excludes the test-only SQLite projection', () {
    final graph =
        jsonDecode(File('.dart_tool/package_graph.json').readAsStringSync())
            as Map<String, dynamic>;
    final config =
        jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
            as Map<String, dynamic>;
    final names = productionPackages(
      graph,
      config,
    ).map((row) => row['name'] as String).toSet();
    expect(
      names.intersection({'drift', 'sqlite3', 'sqlite3_flutter_libs'}),
      isEmpty,
      reason: 'The app uses JSONL; SQLite is a test-only prototype.',
    );

    final spec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    expect(spec['dev_dependencies']['drift'], isNotNull);
    expect(spec['dependencies']['sqlite3_flutter_libs'], isNull);
    expect(spec['dev_dependencies']['sqlite3_flutter_libs'], isNull);
    expect(Directory('lib/app/storage').existsSync(), isFalse);
    expect(
      File('test/support/storage/gravita_database.dart').existsSync(),
      isTrue,
    );
    expect(
      File('test/support/storage/session_projector.dart').existsSync(),
      isTrue,
    );
  });
}
