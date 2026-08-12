import 'dart:convert';
import 'dart:io';

import 'package:gravita_engine/gravita_engine.dart';
import 'package:test/test.dart';

/// ⭐ ÇİVİ — `_runChecks()` SESSİZ ATLAMA tuzağı (G-182, koordinatör kısıtı 2).
///
/// **Bulgu:** `feet_off_ground` motorda ÖZEL DURUM olarak uygulanmış, ama
/// YALNIZ `MultiPhaseEngine._enters()` içinde. `_runChecks()` aynı metriği
/// `m.byName()`e soruyor ve null gelince **`continue`** ediyor — yani o
/// metrik bir `checks` bloğunda kullanılsaydı kural **sessizce atlanırdı**
/// ve kullanıcı hiçbir şey görmezdi.
///
/// Bugün hiçbir hareket onu orada kullanmıyor: bu bir **gizli tuzak**, canlı
/// kusur DEĞİL. Koordinatör hükmü nettir ve bu dosya onu harfiyen uygular:
///
/// > **ÇİVİLE, DAVRANIŞI DEĞİŞTİRME.** Motorun `continue` davranışı bu turda
/// > değişmez — kime dokunduğu ÖLÇÜLMEDİ; sessiz bir atlamayı gürültülü
/// > yapmak ayrı bir karar ve ayrı bir ölçüm ister.
///
/// Yani burada dondurulan şey bir TASARIM değil, **adı konmuş bir KUSUR**.
/// Biri o metriği bir `checks` bloğuna koyduğu gün bu test kırmızı yanar ve
/// kararı o gün ölçümle verir. Çivinin kendi ömrü de yazılı: metrik `byName`
/// tarafından üretilmeye başlarsa test bunu söyler ve **silinmesini** ister.
void main() {
  test('motor-ÖZEL metrikler faz KONTROLÜNDE kullanılmıyor (sessiz atlama)',
      () {
    // Özel-durumlu metrikler ELLE YAZILMIYOR, kaynaktan türetiliyor: elle
    // liste tam da bu kusurun ilk ölçümünde yanlış cevap üretmişti
    // (kapsamı tek dosya sanmak — `burpee` yanlış-pozitifi).
    final String engineSrc =
        File('lib/src/multiphase_engine.dart').readAsStringSync();
    final Set<String> specialCased =
        RegExp(r"\w*[Mm]etric\s*==\s*'([a-z_0-9]+)'")
            .allMatches(engineSrc)
            .map((RegExpMatch m) => m.group(1)!)
            .toSet();

    expect(specialCased, isNotEmpty,
        reason: 'POZİTİF KONTROL: tarama motorun özel durumlarını GÖREBİLİYOR '
            'olmalı. Boş küme, çivinin hiçbir şeye çakılmadığı — yani bu '
            'testin koşup hiçbir şey ölçmediği anlamına gelirdi.');

    // Çivinin DAYANAĞI: bu metrikleri `byName` üretmiyor.
    for (final String metric in specialCased) {
      expect(MovementMetrics.unimplemented, contains(metric),
          reason: '$metric artık `byName`de üretiliyorsa bu çivi GEREKSİZDİR '
              've silinmelidir — çivilenen kusur ortadan kalkmış olur.');
    }

    final List<File> catalogs = <File>[
      for (final String wave in <String>['w1', 'w2'])
        ...Directory('../../content/catalog/$wave')
            .listSync()
            .whereType<File>()
            .where((File f) => f.path.endsWith('.json')),
    ];
    expect(catalogs, isNotEmpty,
        reason: 'POZİTİF KONTROL: katalog gerçekten okunabildi.');

    final List<String> offenders = <String>[];
    for (final File f in catalogs) {
      final Map<String, dynamic> d =
          jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final Map<String, dynamic> eng =
          (d['engine'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      for (final dynamic phase
          in (eng['sequence'] as List<dynamic>?) ?? const <dynamic>[]) {
        final Map<String, dynamic> p = phase as Map<String, dynamic>;
        for (final dynamic chk
            in (p['checks'] as List<dynamic>?) ?? const <dynamic>[]) {
          final String? metric =
              (chk as Map<String, dynamic>)['metric'] as String?;
          if (metric != null && specialCased.contains(metric)) {
            offenders.add('${d['id']}.${p['id']}.checks → $metric');
          }
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'Bu metrik(ler) motorda YALNIZ faz GİRİŞİNDE özel-durumlu; '
            "`_runChecks()` `byName`e düşüp null'da `continue` ediyor, yani "
            'buradaki kural SESSİZCE atlanır — kullanıcı hiçbir şey görmez. '
            'Motoru değiştirmeden önce bunun kime dokunduğu ÖLÇÜLMELİ.');
  });

  /// TERS İKİZ — çivinin gerçekten ateşlenebildiğini kanıtlar.
  ///
  /// Üstteki test "hiçbir hareket bunu yapmıyor" diyor ve BUGÜN doğru. Ama
  /// koşulsuz doğru bir kapı hiçbir şey ölçmez: aynı mantık, ihlali
  /// GÖREMEYEN bir tarayıcıda da yeşil kalırdı. Burada ihlal SENTETİK olarak
  /// kuruluyor ve saptayıcının onu yakaladığı gösteriliyor.
  test('POZİTİF İKİZ: sentetik ihlal YAKALANIYOR', () {
    const String metric = 'feet_off_ground';
    final Map<String, dynamic> fakeCatalog = <String, dynamic>{
      'id': 'zzqq_movement',
      'engine': <String, dynamic>{
        'sequence': <dynamic>[
          <String, dynamic>{
            'id': 'land',
            'checks': <dynamic>[
              <String, dynamic>{'metric': metric, 'op': '==', 'value': false},
            ],
          },
        ],
      },
    };

    final List<String> offenders = <String>[];
    final Map<String, dynamic> eng =
        fakeCatalog['engine'] as Map<String, dynamic>;
    for (final dynamic phase in eng['sequence'] as List<dynamic>) {
      final Map<String, dynamic> p = phase as Map<String, dynamic>;
      for (final dynamic chk in p['checks'] as List<dynamic>) {
        final String? m = (chk as Map<String, dynamic>)['metric'] as String?;
        if (m != null && m == metric) {
          offenders.add('${fakeCatalog['id']}.${p['id']}.checks → $m');
        }
      }
    }

    expect(offenders, hasLength(1),
        reason: 'Saptayıcı sentetik ihlali göremiyorsa, gerçeğini de göremez.');
  });
}
