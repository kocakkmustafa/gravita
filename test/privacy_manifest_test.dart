import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
void main() {
  final File manifest = File('ios/Runner/PrivacyInfo.xcprivacy');
  final File pbx = File('ios/Runner.xcodeproj/project.pbxproj');

  /// Gerekçe-zorunlu API kategorileri → o kategoriyi ELE VEREN dizgeler.
  /// Beyan `[]` diyorsa bu dizgelerin HİÇBİRİ isabet etmemeli.
  const Map<String, List<String>> categories = <String, List<String>>{
    'FileTimestamp': <String>[
      '.stat(', 'lastModified', 'lastAccessed', 'creationDate',
      'modificationDate',
    ],
    'DiskSpace': <String>['statfs', 'freeSpace', 'volumeAvailable'],
    'SystemBootTime': <String>['systemUptime', 'kern.boottime'],
    'UserDefaults': <String>['SharedPreferences', 'NSUserDefaults'],
    'ActiveKeyboards': <String>['activeInputModes'],
  };

  List<File> dartFilesUnder(Directory d) => d
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();

  test('manifest VAR ve beyanı ÖLÇÜMLE uyuşuyor (app + PİNLİ ÇEKİRDEK)', () {
    expect(manifest.existsSync(), isTrue,
        reason: 'PrivacyInfo.xcprivacy yokluğu 2024\'ten beri KOŞULSUZ ret '
            'sebebidir.');
    final String text = manifest.readAsStringSync();

    // Beyan bugün BOŞ; bu test onu ölçüme çiviliyor.
    expect(RegExp(r'<key>NSPrivacyAccessedAPITypes</key>\s*<array\s*/>')
        .hasMatch(text), isTrue,
        reason: 'Beyan artık boş değilse ölçüm de değişmiş olmalı — ikisi '
            'birlikte güncellenir.');
    expect(RegExp(r'<key>NSPrivacyTracking</key>\s*<false\s*/>')
        .hasMatch(text), isTrue);

    // --- ölçülecek ağaçlar ---
    final List<File> files = <File>[
      ...dartFilesUnder(Directory('lib')),
      ...dartFilesUnder(Directory('packages/gravita_engine/lib')),
    ];

    // PİNLİ ÇEKİRDEK: ref pubspec.lock'tan okunur, yol UYDURULMAZ.
    final String lock = File('pubspec.lock').readAsStringSync();
    final RegExpMatch? ref =
        RegExp(r'resolved-ref: "?([0-9a-f]{40})"?').firstMatch(lock);
    expect(ref, isNotNull, reason: 'pubspec.lock\'ta çözülmüş ref bulunamadı.');
    final Directory core = Directory(
        '${Platform.environment['HOME']}/.pub-cache/git/motion-core-${ref!.group(1)}/packages');
    expect(core.existsSync(), isTrue,
        reason: 'PİNLİ ÇEKİRDEK bulunamadı (${core.path}). Bulunamayan bir '
            'ağaç üzerinden "0 isabet" raporlamak ölçüm değil KÖRLÜKTÜR.');
    files.addAll(dartFilesUnder(core));

    final String corpus = files.map((File f) => f.readAsStringSync()).join('\n');

    // POZİTİF KONTROL: korpus gerçekten çekirdeği İÇERİYOR mu?
    expect(corpus.contains('JsonlSessionStore'), isTrue,
        reason: 'Çekirdek okunamadıysa aşağıdaki her "0" sahtedir.');
    expect(corpus.contains('ZZQQ_bulunmaz_dizge'), isFalse,
        reason: 'Negatif kontrol: uydurma dizge isabet ETMEMELİ.');

    final List<String> found = <String>[];
    categories.forEach((String name, List<String> needles) {
      for (final String n in needles) {
        if (corpus.contains(n)) found.add('$name ← "$n"');
      }
    });
    expect(found, isEmpty,
        reason: 'Gerekçe-zorunlu API kullanımı ÖLÇÜLDÜ ama manifest boş '
            'beyan ediyor. Beyan ölçümle birlikte güncellenmeli: $found');
  });

  test('manifest PAKETE giriyor — dört çapa AYRI AYRI aranıyor', () {
    final String p = pbx.readAsStringSync();

    // Lissom'un tuzağı: TEK sayaç geçiş sayar, satır değil. Dördü AYRI.
    final Map<String, RegExp> anchors = <String, RegExp>{
      'PBXBuildFile': RegExp(
          r'/\* PrivacyInfo\.xcprivacy in Resources \*/ = \{isa = PBXBuildFile'),
      'PBXFileReference': RegExp(
          r'/\* PrivacyInfo\.xcprivacy \*/ = \{isa = PBXFileReference'),
      'grup çocuğu': RegExp(r'^\t+\w+ /\* PrivacyInfo\.xcprivacy \*/,$',
          multiLine: true),
      'Resources fazı': RegExp(
          r'^\t+\w+ /\* PrivacyInfo\.xcprivacy in Resources \*/,$',
          multiLine: true),
    };

    final List<String> missing = <String>[];
    anchors.forEach((String name, RegExp re) {
      if (!re.hasMatch(p)) missing.add(name);
    });
    expect(missing, isEmpty,
        reason: 'Bağlı olmayan bir manifest depoda durur, git mutlu, mağaza '
            'yine REDDEDER. Eksik çapa: $missing');
  });

  /// POZİTİF İKİZ — saptayıcı gerçekten ateşleniyor mu.
  ///
  /// ⚠️ Sahte, GERÇEK pbxproj biçiminde: sahte bir biçim, gerçeğin
  /// reddedeceği bir girdiyi kabul ederdi ve kapı hiçbir şey ölçmezdi.
  test('POZİTİF İKİZ: çapası eksik bir pbxproj YAKALANIYOR', () {
    final String real = pbx.readAsStringSync();
    // Yalnız Resources fazı satırını düş — diğer üç çapa DURUYOR.
    final String sabotaged = real.replaceAll(
        RegExp(r'^\t+\w+ /\* PrivacyInfo\.xcprivacy in Resources \*/,\n',
            multiLine: true),
        '');
    expect(sabotaged.length, lessThan(real.length),
        reason: 'Sabotaj uygulanamadıysa bu ikiz hiçbir şey ölçmez.');

    final RegExp resourcesAnchor = RegExp(
        r'^\t+\w+ /\* PrivacyInfo\.xcprivacy in Resources \*/,$',
        multiLine: true);
    expect(resourcesAnchor.hasMatch(real), isTrue);
    expect(resourcesAnchor.hasMatch(sabotaged), isFalse,
        reason: 'Saptayıcı sentetik eksiği göremiyorsa gerçeğini de göremez.');
  });
}
