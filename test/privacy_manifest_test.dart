import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// ⭐ GİZLİLİK MANİFESTİ KAPISI — G-191 (yayın denetimi kalemi ⑥).
///
/// İki katman, ikisi de ölçülmüş referanstan (icat yok):
///
/// **① ÖLÇÜM (JabLab'ın katmanı):** `NSPrivacyAccessedAPITypes` beyanı,
/// uygulamanın VE **pinli çekirdeğin** gerçek kullanımına karşı ölçülür —
/// çünkü beyan yalnız app'in değil, **tükettiği çekirdeğin** davranışını da
/// taahhüt eder. Çekirdek bulunamazsa test **gürültüyle düşer**: bulunamayan
/// bir ağaç üzerinden "0 isabet" raporlamak, ölçüm değil körlüktür.
///
/// **② PAKETLEME (Lissom'un katmanı) — ve asıl kritik olan bu:**
/// > *Bağlı olmayan bir manifest depoda durur, git mutlu, mağaza yine
/// > REDDEDER.*
/// Dosyanın VARLIĞI yetmez; `.app` içine girmesi gerekir. Bunun için
/// `project.pbxproj`ta **dört ayrı yapısal çapa** olmalı ve bu test onları
/// **AYRI AYRI** arar — Lissom'un tuzağı tam buradaydı: tek bir sayaç
/// (`.count()`) *geçiş* sayıyordu, satır değil, ve üç çapa eksikken bile
/// yeşil kalabiliyordu.
// package_config includes dev/tool packages and Core checkout siblings are not
// dependency selection. Follow only production edges from package_graph roots.
List<Map<String, dynamic>> productionPackages(
  Map<String, dynamic> graph,
  Map<String, dynamic> config,
) {
  Map<String, Map<String, dynamic>> indexed(Map<String, dynamic> document) {
    final rows = (document['packages'] as List).cast<Map<String, dynamic>>();
    final result = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final name = row['name'] as String;
      if (result.containsKey(name)) {
        throw StateError('Duplicate package: $name');
      }
      result[name] = row;
    }
    return result;
  }

  final nodes = indexed(graph);
  final locations = indexed(config);
  final pending = (graph['roots'] as List).cast<String>().toList();
  if (pending.isEmpty) throw StateError('Production graph has no roots');
  final selected = <String>{};
  while (pending.isNotEmpty) {
    final name = pending.removeLast();
    if (!selected.add(name)) continue;
    final node = nodes[name];
    if (node == null || !locations.containsKey(name)) {
      throw StateError('Missing selected production package: $name');
    }
    pending.addAll((node['dependencies'] as List).cast<String>());
  }
  final names = selected.toList()..sort();
  return names.map((name) => locations[name]!).toList();
}

List<File> productionSources(
  File configFile,
  List<Map<String, dynamic>> selected,
) {
  List<File> sources(Directory dir, Set<String> extensions) {
    if (!dir.existsSync()) return [];
    return dir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((file) {
          final dirs =
              file.absolute.path
                  .substring(dir.absolute.path.length)
                  .split(Platform.pathSeparator)
                ..removeLast();
          if (!extensions.contains('.dart') &&
              dirs.any((part) {
                final name = part.toLowerCase();
                return name.startsWith('test') ||
                    name.endsWith('tests') ||
                    {
                      'example',
                      'examples',
                      'build',
                      '.dart_tool',
                    }.contains(name);
              }))
            return false;
          return extensions.any(file.path.endsWith);
        })
        .toList();
  }

  final files = <String, File>{};
  for (final row in selected) {
    final root = Directory.fromUri(
      configFile.absolute.uri.resolve(row['rootUri'] as String),
    ).absolute.uri;
    final dart = sources(
      Directory.fromUri(root.resolve(row['packageUri'] as String? ?? 'lib/')),
      {'.dart'},
    );
    // Each declared native implementation must stand on its own. A different
    // platform or a Dart wrapper cannot supply missing Apple implementation.
    final spec = File.fromUri(root.resolve('pubspec.yaml'));
    final descriptor = spec.existsSync()
        ? loadYaml(spec.readAsStringSync())
        : null;
    final platforms = descriptor?['flutter']?['plugin']?['platforms'];
    var nativePlatforms = 0;
    if (platforms is Map) {
      for (final entry in platforms.entries) {
        final implementation = entry.value;
        if (implementation is! Map ||
            (implementation['pluginClass'] == null &&
                implementation['ffiPlugin'] != true))
          continue;
        nativePlatforms++;
        final platform = entry.key as String;
        final dir = implementation['sharedDarwinSource'] == true
            ? 'darwin'
            : platform;
        final needsSource =
            dart.isEmpty || platform == 'ios' || platform == 'macos';
        if (needsSource) {
          final bodies = sources(Directory.fromUri(root.resolve('$dir/')), {
            '.swift',
            '.m',
            '.mm',
            if (platform != 'ios' && platform != 'macos') ...{'.java', '.kt'},
            '.c',
            '.cc',
            '.cpp',
            '.cxx',
            '.C',
          });
          if (bodies.isEmpty) {
            throw StateError(
              'Missing native implementation sources: ${row['name']}/$platform; '
              'binary/generated implementation evidence unresolved',
            );
          }
        }
      }
    }
    if (dart.isEmpty && nativePlatforms == 0) {
      throw StateError('Missing or empty production sources: ${row['name']}');
    }
    for (final file in dart) {
      files[file.absolute.path] = file;
    }
    // Apple native C/C++ is measured alongside Swift/Objective-C. Generated
    // artifact source (for example app Pods) is token evidence, not attestation
    // of dependency linkage or of API use by the final native archive.
    for (final dir in ['ios', 'darwin', 'macos']) {
      for (final file in sources(Directory.fromUri(root.resolve('$dir/')), {
        '.swift',
        '.m',
        '.mm',
        '.h',
        '.hh',
        '.hpp',
        '.c',
        '.cc',
        '.cpp',
        '.cxx',
        '.C',
      })) {
        files[file.absolute.path] = file;
      }
    }
  }
  return files.values.toList();
}

void main() {
  final File manifest = File('ios/Runner/PrivacyInfo.xcprivacy');
  final File pbx = File('ios/Runner.xcodeproj/project.pbxproj');

  /// Gerekçe-zorunlu API kategorileri → o kategoriyi ELE VEREN dizgeler.
  /// Beyan `[]` diyorsa bu dizgelerin HİÇBİRİ isabet etmemeli.
  const Map<String, List<String>> categories = <String, List<String>>{
    'FileTimestamp': <String>[
      '.stat(',
      'lastModified',
      'lastAccessed',
      'creationDate',
      'modificationDate',
    ],
    // freeSpace is also a Flutter layout variable, not a disk API.
    'DiskSpace': <String>[
      'statfs',
      'NSFileSystemFreeSize',
      'systemFreeSize',
      'volumeAvailable',
    ],
    'SystemBootTime': <String>['systemUptime', 'kern.boottime'],
    'UserDefaults': <String>['SharedPreferences', 'NSUserDefaults'],
    'ActiveKeyboards': <String>['activeInputModes'],
  };

  test('manifest VAR ve beyanı ÖLÇÜMLE uyuşuyor (app + PİNLİ ÇEKİRDEK)', () {
    expect(
      manifest.existsSync(),
      isTrue,
      reason:
          'PrivacyInfo.xcprivacy yokluğu 2024\'ten beri KOŞULSUZ ret '
          'sebebidir.',
    );
    final String text = manifest.readAsStringSync();

    // Declaration is checked against the selected source corpus below.
    expect(
      RegExp(r'<key>NSPrivacyTracking</key>\s*<false\s*/>').hasMatch(text),
      isTrue,
    );

    final configFile = File('.dart_tool/package_config.json').absolute;
    final config =
        jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    final graph =
        jsonDecode(File('.dart_tool/package_graph.json').readAsStringSync())
            as Map<String, dynamic>;
    final packages = productionPackages(graph, config);
    final files = productionSources(configFile, packages);
    final selected = packages
        .where((package) => (package['name'] as String).startsWith('motion_'))
        .toList();
    final coreTrees = selected
        .map(
          (package) => Directory.fromUri(
            configFile.uri.resolve(package['rootUri'] as String),
          ).parent.path,
        )
        .toSet();
    expect(
      coreTrees,
      hasLength(1),
      reason: 'All selected Motion packages must share one Core tree.',
    );
    final core = Directory(coreTrees.single);
    expect(
      core.existsSync(),
      isTrue,
      reason: 'Selected Core is missing; zero hits would be blindness.',
    );
    // UserDefaults lives in the actually selected native preferences plugin,
    // not necessarily in app/Core Dart wrappers after a dependency repin.
    final foundation = packages.singleWhere(
      (row) => row['name'] == 'shared_preferences_foundation',
    );
    final foundationRoot = Directory.fromUri(
      configFile.uri.resolve(foundation['rootUri'] as String),
    );
    final plugin = File(
      '${foundationRoot.path}/darwin/shared_preferences_foundation/'
      'Sources/shared_preferences_foundation/SharedPreferencesPlugin.swift',
    );
    expect(
      plugin.existsSync(),
      isTrue,
      reason:
          'Selected native preferences source must be available for measurement',
    );
    expect(plugin.readAsStringSync(), contains('UserDefaults.standard'));
    files.add(plugin);

    final String corpus = files
        .map((File f) => f.readAsStringSync())
        .join('\n');

    // POZİTİF KONTROL: korpus gerçekten çekirdeği İÇERİYOR mu?
    expect(
      corpus.contains('JsonlSessionStore'),
      isTrue,
      reason: 'Çekirdek okunamadıysa aşağıdaki her "0" sahtedir.',
    );
    expect(
      corpus.contains('ZZQQ_bulunmaz_dizge'),
      isFalse,
      reason: 'Negatif kontrol: uydurma dizge isabet ETMEMELİ.',
    );

    final found = <String>[];
    final foundCategories = <String>{};
    categories.forEach((String name, List<String> needles) {
      for (final n in needles) {
        if (corpus.contains(n)) {
          found.add('$name <- "$n"');
          foundCategories.add('NSPrivacyAccessedAPICategory$name');
        }
      }
    });
    final declared = RegExp(
      r'<key>NSPrivacyAccessedAPIType</key>\s*<string>([^<]+)</string>',
    ).allMatches(text).map((match) => match.group(1)!).toSet();
    expect(
      declared,
      foundCategories,
      reason:
          'Declaration must equal selected app/engine/Core source usage: $found',
    );
    expect(declared, {
      'NSPrivacyAccessedAPICategoryFileTimestamp',
      'NSPrivacyAccessedAPICategoryUserDefaults',
    });
    expect(text, contains('<string>CA92.1</string>'));
    expect(
      RegExp(
        r'<key>NSPrivacyAccessedAPITypeReasons</key>\s*<array>\s*<string>C617\.1</string>\s*</array>',
      ).hasMatch(text),
      isTrue,
      reason:
          'C617.1 declaration is retained; final native/SDK readback is separate.',
    );
  });

  test('manifest PAKETE giriyor — dört çapa AYRI AYRI aranıyor', () {
    final String p = pbx.readAsStringSync();

    // Lissom'un tuzağı: TEK sayaç geçiş sayar, satır değil. Dördü AYRI.
    final Map<String, RegExp> anchors = <String, RegExp>{
      'PBXBuildFile': RegExp(
        r'/\* PrivacyInfo\.xcprivacy in Resources \*/ = \{isa = PBXBuildFile',
      ),
      'PBXFileReference': RegExp(
        r'/\* PrivacyInfo\.xcprivacy \*/ = \{isa = PBXFileReference',
      ),
      'grup çocuğu': RegExp(
        r'^\t+\w+ /\* PrivacyInfo\.xcprivacy \*/,$',
        multiLine: true,
      ),
      'Resources fazı': RegExp(
        r'^\t+\w+ /\* PrivacyInfo\.xcprivacy in Resources \*/,$',
        multiLine: true,
      ),
    };

    final List<String> missing = <String>[];
    anchors.forEach((String name, RegExp re) {
      if (!re.hasMatch(p)) missing.add(name);
    });
    expect(
      missing,
      isEmpty,
      reason:
          'Bağlı olmayan bir manifest depoda durur, git mutlu, mağaza '
          'yine REDDEDER. Eksik çapa: $missing',
    );
  });

  /// POZİTİF İKİZ — saptayıcı gerçekten ateşleniyor mu.
  ///
  /// ⚠️ Sahte, GERÇEK pbxproj biçiminde: sahte bir biçim, gerçeğin
  /// reddedeceği bir girdiyi kabul ederdi ve kapı hiçbir şey ölçmezdi.
  test('POZİTİF İKİZ: çapası eksik bir pbxproj YAKALANIYOR', () {
    final String real = pbx.readAsStringSync();
    // Yalnız Resources fazı satırını düş — diğer üç çapa DURUYOR.
    final String sabotaged = real.replaceAll(
      RegExp(
        r'^\t+\w+ /\* PrivacyInfo\.xcprivacy in Resources \*/,\n',
        multiLine: true,
      ),
      '',
    );
    expect(
      sabotaged.length,
      lessThan(real.length),
      reason: 'Sabotaj uygulanamadıysa bu ikiz hiçbir şey ölçmez.',
    );

    final RegExp resourcesAnchor = RegExp(
      r'^\t+\w+ /\* PrivacyInfo\.xcprivacy in Resources \*/,$',
      multiLine: true,
    );
    expect(resourcesAnchor.hasMatch(real), isTrue);
    expect(
      resourcesAnchor.hasMatch(sabotaged),
      isFalse,
      reason: 'Saptayıcı sentetik eksiği göremiyorsa gerçeğini de göremez.',
    );
  });

  void withGraphFixture(
    void Function(File, Map<String, dynamic>, Map<String, dynamic>) body,
  ) {
    final temp = Directory.systemTemp.createTempSync('gravita-privacy-graph-');
    try {
      final graph = <String, dynamic>{
        'roots': ['app'],
        'packages': [
          {
            'name': 'app',
            'dependencies': ['consumer'],
            'devDependencies': ['devtool'],
          },
          {
            'name': 'consumer',
            'dependencies': ['transitive'],
          },
          {'name': 'transitive', 'dependencies': <String>[]},
          {'name': 'devtool', 'dependencies': <String>[]},
          {'name': 'motion_media', 'dependencies': <String>[]},
        ],
      };
      final config = <String, dynamic>{
        'packages': [
          for (final name in [
            'app',
            'consumer',
            'transitive',
            'devtool',
            'motion_media',
          ])
            {
              'name': name,
              'rootUri': name == 'consumer' ? name : '$name/',
              'packageUri': name == 'transitive' ? 'src/' : 'lib/',
            },
        ],
      };
      for (final row
          in (config['packages'] as List).cast<Map<String, dynamic>>()) {
        final file = File(
          '${temp.path}/${row['rootUri']}/${row['packageUri']}production.dart',
        );
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('// ${row['name']} production source');
      }
      File('${temp.path}/consumer/test/ignored.dart')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('ZZQQ_bulunmaz_dizge .stat(');
      body(File('${temp.path}/package_config.json'), graph, config);
    } finally {
      temp.deleteSync(recursive: true);
    }
  }

  test('production corpus excludes dev, sibling and package test sources', () {
    withGraphFixture((file, graph, config) {
      final selected = productionPackages(graph, config);
      expect(selected.map((row) => row['name']).toSet(), {
        'app',
        'consumer',
        'transitive',
      });
      final corpus = productionSources(
        file,
        selected,
      ).map((f) => f.readAsStringSync()).join('\n');
      expect(corpus, contains('transitive production source'));
      expect(corpus, isNot(contains('devtool')));
      expect(corpus, isNot(contains('motion_media')));
      expect(corpus, isNot(contains('ZZQQ_bulunmaz_dizge')));
    });
  });

  test(
    'new transitive production dependency is measured without a package allowlist',
    () {
      withGraphFixture((file, graph, config) {
        final nodes = (graph['packages'] as List).cast<Map<String, dynamic>>();
        nodes.singleWhere(
          (row) => row['name'] == 'transitive',
        )['dependencies'] = [
          'motion_media',
        ];
        File.fromUri(
          file.uri.resolve('motion_media/lib/production.dart'),
        ).writeAsStringSync('file.stat(');
        final selected = productionPackages(graph, config);
        final corpus = productionSources(
          file,
          selected,
        ).map((f) => f.readAsStringSync()).join('\n');
        expect(selected.map((row) => row['name']), contains('motion_media'));
        expect(corpus, contains('file.stat('));
      });
    },
  );

  test('missing selected graph node or package configuration fails closed', () {
    withGraphFixture((file, graph, config) {
      (config['packages'] as List).removeWhere(
        (row) => row['name'] == 'transitive',
      );
      expect(() => productionPackages(graph, config), throwsStateError);
    });
    withGraphFixture((file, graph, config) {
      (graph['packages'] as List).removeWhere(
        (row) => row['name'] == 'transitive',
      );
      expect(() => productionPackages(graph, config), throwsStateError);
    });
  });

  test('missing or empty selected production source fails closed', () {
    withGraphFixture((file, graph, config) {
      Directory.fromUri(
        file.uri.resolve('transitive/src/'),
      ).deleteSync(recursive: true);
      final selected = productionPackages(graph, config);
      expect(() => productionSources(file, selected), throwsStateError);
      Directory.fromUri(file.uri.resolve('transitive/src/')).createSync();
      expect(() => productionSources(file, selected), throwsStateError);
    });
  });

  test(
    'native-only selected dependency requires declared implementation sources',
    () {
      withGraphFixture((file, graph, config) {
        final lib = Directory.fromUri(file.uri.resolve('transitive/src/'));
        lib.deleteSync(recursive: true);
        File.fromUri(
          file.uri.resolve('transitive/pubspec.yaml'),
        ).writeAsStringSync(
          'flutter:\n  plugin:\n    platforms:\n      ios:\n        pluginClass: NativePlugin\n',
        );
        final native = File.fromUri(
          file.uri.resolve('transitive/ios/Classes/Plugin.m'),
        );
        native.parent.createSync(recursive: true);
        native.writeAsStringSync('NSUserDefaults.standardUserDefaults');
        final selected = productionPackages(graph, config);
        final corpus = productionSources(
          file,
          selected,
        ).map((f) => f.readAsStringSync()).join('\n');
        expect(corpus, contains('NSUserDefaults.standardUserDefaults'));
        native.deleteSync();
        expect(() => productionSources(file, selected), throwsStateError);
      });
    },
  );

  test(
    'Android-only native dependency stays selected without becoming Apple API evidence',
    () {
      withGraphFixture((file, graph, config) {
        Directory.fromUri(
          file.uri.resolve('transitive/src/'),
        ).deleteSync(recursive: true);
        File.fromUri(
          file.uri.resolve('transitive/pubspec.yaml'),
        ).writeAsStringSync(
          'flutter:\n  plugin:\n    platforms:\n      android:\n        pluginClass: NativePlugin\n',
        );
        final native = File.fromUri(
          file.uri.resolve('transitive/android/src/main/Plugin.java'),
        );
        native.parent.createSync(recursive: true);
        native.writeAsStringSync(
          '// Android implementation NSUserDefaults marker',
        );
        final selected = productionPackages(graph, config);
        expect(selected.map((row) => row['name']), contains('transitive'));
        final corpus = productionSources(
          file,
          selected,
        ).map((f) => f.readAsStringSync()).join('\n');
        expect(corpus, isNot(contains('NSUserDefaults marker')));
        native.deleteSync();
        expect(() => productionSources(file, selected), throwsStateError);
      });
    },
  );

  test('selected native-only Apple C and C++ FFI sources enter the corpus', () {
    for (final extension in ['c', 'cc', 'cpp', 'cxx', 'C']) {
      withGraphFixture((file, graph, config) {
        Directory.fromUri(
          file.uri.resolve('transitive/src/'),
        ).deleteSync(recursive: true);
        File.fromUri(
          file.uri.resolve('transitive/pubspec.yaml'),
        ).writeAsStringSync(
          'flutter:\n  plugin:\n    platforms:\n      ios:\n        ffiPlugin: true\n',
        );
        final native = File.fromUri(
          file.uri.resolve('transitive/ios/Plugin.$extension'),
        );
        native.parent.createSync(recursive: true);
        native.writeAsStringSync('statfs(path, &buffer);');
        final selected = productionPackages(graph, config);
        final corpus = productionSources(
          file,
          selected,
        ).map((f) => f.readAsStringSync()).join('\n');
        expect(corpus, contains('statfs(path, &buffer);'), reason: extension);
        expect(
          categories['DiskSpace']!.any(corpus.contains),
          isTrue,
          reason: extension,
        );
        native.deleteSync();
        expect(() => productionSources(file, selected), throwsStateError);
      });
    }
  });

  test(
    'Android source or Dart wrapper cannot mask missing declared Apple implementation',
    () {
      for (final keepDart in [false, true]) {
        withGraphFixture((file, graph, config) {
          if (!keepDart)
            Directory.fromUri(
              file.uri.resolve('transitive/src/'),
            ).deleteSync(recursive: true);
          File.fromUri(
            file.uri.resolve('transitive/pubspec.yaml'),
          ).writeAsStringSync(
            'flutter:\n  plugin:\n    platforms:\n      android:\n        pluginClass: AndroidPlugin\n      ios:\n        pluginClass: ApplePlugin\n',
          );
          final android = File.fromUri(
            file.uri.resolve('transitive/android/src/main/Plugin.java'),
          );
          android.parent.createSync(recursive: true);
          android.writeAsStringSync('// Android marker');
          final header = File.fromUri(
            file.uri.resolve('transitive/ios/Classes/Plugin.h'),
          );
          header.parent.createSync(recursive: true);
          header.writeAsStringSync(
            '// Interface only, no Apple implementation',
          );
          final selected = productionPackages(graph, config);
          expect(
            () => productionSources(file, selected),
            throwsStateError,
            reason: 'keepDart=$keepDart',
          );
          final apple = File.fromUri(
            file.uri.resolve('transitive/ios/Classes/Plugin.m'),
          );
          apple.writeAsStringSync('NSUserDefaults.standardUserDefaults');
          final corpus = productionSources(
            file,
            selected,
          ).map((f) => f.readAsStringSync()).join('\n');
          expect(corpus, contains('NSUserDefaults.standardUserDefaults'));
          expect(corpus, isNot(contains('Android marker')));
        });
      }
    },
  );

  test(
    'unsupported Apple Java or Kotlin bodies fail closed; Android formats remain valid',
    () {
      for (final extension in ['java', 'kt']) {
        for (final platform in ['ios', 'macos', 'android']) {
          withGraphFixture((file, graph, config) {
            Directory.fromUri(
              file.uri.resolve('transitive/src/'),
            ).deleteSync(recursive: true);
            File.fromUri(
              file.uri.resolve('transitive/pubspec.yaml'),
            ).writeAsStringSync(
              'flutter:\n  plugin:\n    platforms:\n      $platform:\n        ffiPlugin: true\n',
            );
            final body = File.fromUri(
              file.uri.resolve('transitive/$platform/Plugin.$extension'),
            );
            body.parent.createSync(recursive: true);
            body.writeAsStringSync('// Java/Kotlin native marker');
            final selected = productionPackages(graph, config);
            if (platform == 'android') {
              final corpus = productionSources(
                file,
                selected,
              ).map((f) => f.readAsStringSync()).join('\n');
              expect(
                selected.map((row) => row['name']),
                contains('transitive'),
              );
              expect(corpus, isNot(contains('Java/Kotlin native marker')));
            } else {
              expect(
                () => productionSources(file, selected),
                throwsA(
                  isA<StateError>().having(
                    (error) => error.message,
                    'unresolved implementation evidence',
                    contains('unresolved'),
                  ),
                ),
                reason: '$platform/Plugin.$extension',
              );
            }
          });
        }
      }
    },
  );
  test(
    'production graph rejects empty roots and duplicate graph/config records',
    () {
      withGraphFixture((file, graph, config) {
        graph['roots'] = <String>[];
        expect(() => productionPackages(graph, config), throwsStateError);
      });
      for (final duplicateGraph in [true, false]) {
        withGraphFixture((file, graph, config) {
          final rows = ((duplicateGraph ? graph : config)['packages'] as List);
          rows.add(rows.first);
          expect(() => productionPackages(graph, config), throwsStateError);
        });
      }
    },
  );

  test(
    'production dependency cycles are visited once without including dev edges',
    () {
      withGraphFixture((file, graph, config) {
        final nodes = (graph['packages'] as List).cast<Map<String, dynamic>>();
        nodes.singleWhere(
          (row) => row['name'] == 'transitive',
        )['dependencies'] = [
          'app',
        ];
        final selected = productionPackages(graph, config);
        expect(selected.map((row) => row['name']).toList(), [
          'app',
          'consumer',
          'transitive',
        ]);
        expect(productionSources(file, selected), hasLength(3));
      });
    },
  );

  test(
    'shared Darwin implementation includes C++ headers but headers alone fail closed',
    () {
      withGraphFixture((file, graph, config) {
        Directory.fromUri(
          file.uri.resolve('transitive/src/'),
        ).deleteSync(recursive: true);
        File.fromUri(
          file.uri.resolve('transitive/pubspec.yaml'),
        ).writeAsStringSync(
          'flutter:\n  plugin:\n    platforms:\n      ios:\n        pluginClass: Plugin\n        sharedDarwinSource: true\n      macos:\n        pluginClass: Plugin\n        sharedDarwinSource: true\n',
        );
        for (final extension in ['h', 'hh', 'hpp']) {
          final header = File.fromUri(
            file.uri.resolve('transitive/darwin/Plugin.$extension'),
          );
          header.parent.createSync(recursive: true);
          header.writeAsStringSync('// measured header $extension');
        }
        final selected = productionPackages(graph, config);
        expect(() => productionSources(file, selected), throwsStateError);
        File.fromUri(
          file.uri.resolve('transitive/darwin/Plugin.mm'),
        ).writeAsStringSync('statfs(path, &buffer);');
        final sources = productionSources(file, selected);
        final corpus = sources
            .map((source) => source.readAsStringSync())
            .join('\n');
        for (final extension in ['h', 'hh', 'hpp']) {
          expect(corpus, contains('measured header $extension'));
        }
        expect(corpus, contains('statfs(path, &buffer);'));
        expect(
          sources.map((source) => source.absolute.path).toSet(),
          hasLength(sources.length),
        );
      });
    },
  );

  test(
    'native exclusions are relative to source root and preserve production Dart utilities',
    () {
      withGraphFixture((file, graph, config) {
        final consumer = Directory.fromUri(file.uri.resolve('consumer/'));
        consumer.renameSync(
          Directory.fromUri(file.uri.resolve('tests-consumer/')).path,
        );
        final row = (config['packages'] as List)
            .cast<Map<String, dynamic>>()
            .singleWhere((row) => row['name'] == 'consumer');
        row['rootUri'] = 'tests-consumer';
        File.fromUri(
          file.uri.resolve('tests-consumer/pubspec.yaml'),
        ).writeAsStringSync(
          'flutter:\n  plugin:\n    platforms:\n      ios:\n        pluginClass: Plugin\n',
        );
        for (final entry in {
          'lib/testing/helper.dart': 'production Dart utility marker',
          'ios/Sources/Plugin.m': 'production Apple body marker',
          'ios/Tests/Plugin.m': 'excluded native marker',
          'ios/example/Plugin.m': 'excluded native marker',
          'ios/build/Plugin.m': 'excluded native marker',
          'ios/.dart_tool/Plugin.m': 'excluded native marker',
        }.entries) {
          final source = File.fromUri(
            file.uri.resolve('tests-consumer/${entry.key}'),
          );
          source.parent.createSync(recursive: true);
          source.writeAsStringSync(entry.value);
        }
        final selected = productionPackages(graph, config);
        final corpus = productionSources(
          file,
          selected,
        ).map((source) => source.readAsStringSync()).join('\n');
        expect(corpus, contains('production Dart utility marker'));
        expect(corpus, contains('production Apple body marker'));
        expect(corpus, isNot(contains('excluded native marker')));
      });
    },
  );

  test(
    'layout freeSpace is not a disk API; native disk API remains detectable',
    () {
      final needles = categories['DiskSpace']!;
      expect(
        needles.any('final freeSpace = availableWidth - childWidth;'.contains),
        isFalse,
      );
      expect(
        needles.any('let bytes = attributes[.systemFreeSize]'.contains),
        isTrue,
      );
      expect(needles.any('statfs(path, &buffer)'.contains), isTrue);
    },
  );
}
