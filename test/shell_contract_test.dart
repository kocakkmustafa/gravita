import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Kabuk SÖZLEŞMESİ — paketleme ve pin nöbetleri.
///
/// Bu testler widget çizmez; kabuğun **neyi paketlediğini** ve **bağımlılığını
/// nasıl pinlediğini** tutar. İkisi de sessizce bozulabilen ve ancak cihazda
/// ya da haftalar sonra fark edilen sınıflardır.
void main() {
  final YamlMap pubspec =
      loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
  final List<String> assets =
      ((pubspec['flutter'] as YamlMap)['assets'] as YamlList)
          .cast<String>()
          .toList();

  bool declared(String path) => assets.any((String a) =>
      a == path || (a.endsWith('/') && path.startsWith(a)));

  group('paketleme', () {
    test('bildirilen HER asset diskte var', () {
      // Eksik asset `flutter build`i kırar — cihazda değil BURADA yakalanmalı.
      for (final String a in assets) {
        final bool ok = a.endsWith('/')
            ? Directory(a).existsSync()
            : File(a).existsSync();
        expect(ok, isTrue, reason: 'pubspec asset yok: $a');
      }
    });

    test('library.json\'daki her hareketin katalog dosyası PAKETLENİYOR', () {
      // Kabuk katalog adresini hareketin `wave` alanından kuruyor. Dalga
      // dizini pubspec'e eklenmezse uygulama ÇALIŞMA ZAMANINDA patlar; bu test
      // aynı kusuru derleme öncesi yakalar (G-099 dalga-körlüğü ailesi).
      final Map<String, dynamic> lib =
          (jsonDecode(File('content/library.json').readAsStringSync()) as Map)
              .cast<String, dynamic>();
      final List<Map<String, dynamic>> movements =
          (lib['movements'] as List<dynamic>).cast<Map<String, dynamic>>();
      expect(movements, isNotEmpty);
      for (final Map<String, dynamic> m in movements) {
        final String id = (m['catalogId'] ?? m['id']) as String;
        final String wave = (m['wave'] as String).toLowerCase();
        final String path = 'content/catalog/$wave/$id.json';
        expect(declared(path), isTrue,
            reason: '${m['id']}: $path pubspec assets\'te bildirilmemiş.');
        expect(File(path).existsSync(), isTrue, reason: '$path diskte yok.');
      }
    });

    test('DERLEME DEFTERLERİ paketlenmiyor — content/harvest/ dizin olarak YOK',
        () {
      // `content/harvest/` 18 dosya taşıyor ve 16'sı derleme defteri:
      // `decisions.bodyweight_squat.json` (HÜKÜM kaydı), `queue.*.json`, sonda
      // çıktıları. Dizin olarak bildirilse hepsi uygulamaya girerdi — Choreia'nın
      // aynı tuzağa dair kaydı bu satırın gerekçesi.
      // POZİTİF İKİZ: liste okunuyor mu?
      expect(assets, isNotEmpty);
      expect(assets.contains('content/library.json'), isTrue);
      expect(assets.contains('content/harvest/'), isFalse,
          reason: 'harvest DİZİN olarak bildirilmiş: derleme defterleri '
              'uygulamaya sızar. Gereken referansı DOSYA DOSYA ekle.');
      final int harvestFiles = Directory('content/harvest')
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.endsWith('.json'))
          .length;
      expect(harvestFiles, greaterThan(2),
          reason: 'Sayı düştüyse gerekçe zayıflamış olabilir — gözden geçir.');
    });

    test('katalog kökündeki exclusions.json paketlenmiyor', () {
      // Dalga dizinleri bildiriliyor, katalog KÖKÜ bildirilmiyor: `exclusions.json`
      // bir derleme defteri ve çalışma-zamanı okuyucusu YOK.
      expect(File('content/catalog/exclusions.json').existsSync(), isTrue);
      expect(declared('content/catalog/exclusions.json'), isFalse);
      // POZİTİF İKİZ (M-F-194): `declared()` her zaman false dönseydi bu
      // grubun BÜTÜN yokluk-iddiaları geçerdi. Bildiğimiz iki varlık:
      expect(declared('content/library.json'), isTrue);
      expect(declared('content/catalog/w1/push_up.json'), isTrue,
          reason: 'Dizin-önekli eşleşme çalışmıyor → yokluk iddiaları da '
              'anlamsız olurdu.');
    });
  });

  group('pin rejimi (M-F-154)', () {
    final YamlMap enginePubspec = loadYaml(
        File('packages/gravita_engine/pubspec.yaml').readAsStringSync())
        as YamlMap;

    test('motion_core TAG ile pinli — dal ya da eksik ref DEĞİL', () {
      // `path:` bağımlılığı paylaşımlı ağaçta o an hangi dal çıkılıysa onu
      // okur: bağımlılığımız BAŞKA bir oturumun dal değiştirmesiyle sessizce
      // değişirdi (M-F-22 ile aynı aile). Dal adı da yetmez — dal ilerler.
      final YamlMap core =
          (enginePubspec['dependencies'] as YamlMap)['motion_core'] as YamlMap;
      final YamlMap git = core['git'] as YamlMap;
      final String? ref = git['ref'] as String?;
      expect(ref, isNotNull, reason: 'ref YOK — pin yok demektir.');
      expect(ref, matches(RegExp(r'^motion_core-v\d+\.\d+\.\d+$')),
          reason: 'ref bir SÜRÜM TAG\'i olmalı. Bulunan: $ref');
    });

    test('kabuk motion_core\'u BİLDİRİYOR ve pin motorla EŞİT (J-071)', () {
      // Kabuk `SessionRecord`ı doğrudan kullanıyor (SessionStore 0.9.0'da
      // çekirdeğe terfi etti), o yüzden bağımlılığı BİLDİRMEK zorunda:
      // transitif paketten tip almak bağımlılığı görünmez kılar ve motor
      // yarın çekirdeği bırakırsa kabuk sessizce kırılır.
      //
      // ⚠️ Daha önemlisi EŞİTLİK: iki farklı ref, pub'a aynı paket için iki
      // kaynak gösterir (JabLab J-071). Bu testin ilk hâli "kabuk core
      // BİLDİRMİYOR" diyordu ve adopsiyon turunda AŞIRDI — kapı işini yaptı,
      // yerine geçen kural bu.
      final YamlMap deps = pubspec['dependencies'] as YamlMap;
      final YamlMap? shellCore = deps['motion_core'] as YamlMap?;
      expect(shellCore, isNotNull,
          reason: 'Kabuk SessionRecord kullanıyor ama motion_core bildirmiyor.');
      final String shellRef =
          (shellCore!['git'] as YamlMap)['ref'] as String;
      final String engineRef = (((enginePubspec['dependencies']
              as YamlMap)['motion_core'] as YamlMap)['git']
          as YamlMap)['ref'] as String;
      expect(shellRef, engineRef,
          reason: 'Pin EŞİTSİZ (kabuk $shellRef · motor $engineRef). '
              'Aynı paket için iki kaynak = çözülemeyen bağımlılık.');
    });

    test('motion_camera HENÜZ yok — bağlandığı gün pin-eşitliği ŞART', () {
      // Yokluk kapısı. POZİTİF İKİZİ hemen altında (M-F-194).
      final YamlMap deps = pubspec['dependencies'] as YamlMap;
      expect(deps.containsKey('motion_camera'), isFalse,
          reason: 'Kamera köprüsü bağlandı: TAM-40-SHA zeyli + pin-eşitliği '
              'testi ŞART (J-071). Bu nöbeti onunla değiştir.');
    });

    test('POZİTİF İKİZ: yokluk-kapısı gerçekten VARLIĞI görebiliyor', () {
      // M-F-194: "X yok" kapısı, kendi okuma hatasını göremez. Yukarıdaki
      // `containsKey('motion_camera') == false` iddiası, `deps` boş bir map
      // olsaydı da geçerdi. Bu satır okuyucunun ÇALIŞTIĞINI gösteriyor:
      // BİLDİĞİMİZ bir bağımlılık gerçekten görünüyor.
      final YamlMap deps = pubspec['dependencies'] as YamlMap;
      expect(deps.containsKey('gravita_engine'), isTrue);
      expect(deps.containsKey('path_provider'), isTrue);
    });
  });
}
