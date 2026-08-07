import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// ⭐ VARLIK BEYANI KAPISI — *"dosya diskte var"* ≠ *"dosya PAKETTE var".*
///
/// Choreia'nın ölçtüğü kusurun Gravita hâli: onun aracı **dosya sistemini**
/// okuyup *"1 ders başlatılabilir"* dedi, yüzey **Start** çizdi, basınca
/// gerçek `rootBundle` patladı — dosya diskte 75 KB'tı, `pubspec`'te
/// beyansız.
///
/// > ***Sahte, yanlış makineyi taklit ediyordu.***
///
/// Bende koşullar **daha ağır**: katalog yüklemesi TEMBEL. Ölçüldü —
/// `ContentRepository.load` yalnız **dersi olan** hareketin kataloğunu
/// okuyor, yani açılışta **31'den 1'i**. Uygulamanın açılması diğer 30'un
/// paketlendiğini KANITLAMAZ; biri beyansız olsa kullanıcı ona dokunduğu
/// an çöker ve testler yeşil kalır.
///
/// Bu yüzden burada `rootBundle` kullanılıyor — **gerçek makine**. Dosya
/// sistemine bakan bir kapı, tam da bu kusuru göremeyen kapıdır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('çalışma-zamanında çözülebilen HER varlık yolu PAKETTE var', () async {
    // Yollar ELLE yazılmıyor: `library.json`ın kendisinden türetiliyor —
    // `content_repository.dart` hangi adresi kuruyorsa aynısı.
    final Map<String, dynamic> lib =
        (jsonDecode(await rootBundle.loadString('content/library.json')) as Map)
            .cast<String, dynamic>();

    final List<String> paths = <String>[
      'content/exclusions.page.json',
      'content/skill-trees.index.json',
      for (final Map<String, dynamic> m
          in (lib['movements'] as List<dynamic>).cast<Map<String, dynamic>>())
        'content/catalog/${(m['wave'] as String).toLowerCase()}/'
            '${(m['catalogId'] ?? m['id']) as String}.json',
    ];

    final List<String> broken = <String>[];
    for (final String p in paths) {
      try {
        final String s = await rootBundle.loadString(p);
        // Yüklenmesi yetmez: AYRIŞMASI da gerek. Bozuk JSON da çalışma
        // zamanında çöker ve bu kapı onu da tutmalı.
        jsonDecode(s);
      } on Object catch (e) {
        broken.add('$p → $e');
      }
    }

    expect(broken, isEmpty,
        reason: 'Bu yollar çalışma zamanında çözülüyor ama PAKETTEN '
            'okunamıyor. Kullanıcı bunlara dokunduğu an ÇÖKER:\n'
            '${broken.join('\n')}');

    // Kapsam sessizce küçülmesin: 31 hareket + 2 üretilmiş sayfa.
    expect(paths.length, greaterThanOrEqualTo(33));
  });

  test('NEGATİF İKİZ: beyansız bir yol GERÇEKTEN patlıyor mu', () async {
    // Kapı "her şey yüklenir" mi diyor, yoksa gerçekten paketi mi
    // sorguluyor? Diskte VAR ama `pubspec`'te BEYANSIZ bir dosya seçildi:
    // `content/catalog/exclusions.json` — bilerek paketlenmiyor, çünkü
    // içinde iç kural metni ve yol haritası dili taşıyor.
    expect(File('content/catalog/exclusions.json').existsSync(), isTrue,
        reason: 'İkiz fikstürü diskten kaybolmuş — yeni bir beyansız '
            'dosya seç, yoksa bu ikiz hiçbir şey kanıtlamıyor.');

    await expectLater(
        rootBundle.loadString('content/catalog/exclusions.json'),
        throwsA(anything),
        reason: 'İKİZ ÖLDÜ: beyansız bir dosya pakete girmiş — ya '
            '`pubspec` genişlemiş ya kapı gerçek bundle\'ı sorgulamıyor.');
  });
}
