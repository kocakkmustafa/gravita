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
      // ⚠️ NÖBET DEĞİŞTİ (M-F-263, J-071 zeyli), SİLİNMEDİ: eskiden SÜRÜM
      // TAG'i isteniyordu. Kamera köprüsü bağlanınca tag ADI ÇALIŞMIYOR —
      // plugin `motion_core`u PATH ile çekiyor, pub transitif core'u ÇÖZÜLMÜŞ
      // SHA olarak görüyor ve tag adıyla yazılmış pini FARKLI descriptor
      // sayıyor ("incompatible ... from path"). Kural yerini TAM-40-SHA'ya
      // bıraktı; hangi tag olduğu pubspec YORUMUNDA duruyor.
      expect(ref, matches(RegExp(r'^[0-9a-f]{40}$')),
          reason: 'ref TAM-40-SHA olmalı (tag adı pub tarafında çözülmüyor). '
              'Bulunan: $ref');
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

    test('çekirdek 0.10.0 `unreadableRecords` ÜRÜNDE tüketiliyor', () {
      // Pin bump'ı tek başına "adopsiyon" değildir: yeni zorunlu üye
      // bildirilip OKUNMAZSA yüzey eski ikili modelde kalır ve kısmi geçmiş
      // sessizce "tam" görünür. Bu, defterdeki "okuyanı olmayan beyan"
      // sınıfının aynası — beyan çekirdekte, tüketici yok.
      final String app = File('lib/app/gravita_app.dart').readAsStringSync();
      expect(app, contains('unreadableRecords()'),
          reason: 'Pin 0.10.0 ama kayıp-satır sayımı hiç okunmuyor.');
      final String view = File('lib/app/progress_view.dart').readAsStringSync();
      expect(view, contains('HistoryPartial'),
          reason: 'Üçüncü hâl yüzeyde dallanmıyor — ikili model sürüyor.');
    });

    test('motion_camera BAĞLI ve pin ÜÇLÜ eşitlikte (J-071 · M-F-263)', () {
      // ⚠️ Bu test, eski 'motion_camera HENÜZ yok' YOKLUK nöbetinin YERİNE
      // GEÇTİ — kapı görevini yaptı (kamera bağlanınca kırıldı) ve kendi
      // yazdığı kuralla değiştirildi, silinmedi.
      //
      // Üç ref birden eşit olmak ZORUNDA: kabuk core · kabuk camera · motor
      // core. Plugin core'u PATH ile çekiyor, yani farklı bir ref pub'a aynı
      // paket için iki kaynak gösterir ve çözülemez.
      final YamlMap deps = pubspec['dependencies'] as YamlMap;
      final YamlMap? cam = deps['motion_camera'] as YamlMap?;
      expect(cam, isNotNull,
          reason: 'Kamera köprüsü bildirilmiyor — canlı yol pluginsiz olamaz.');
      final String camRef = (cam!['git'] as YamlMap)['ref'] as String;
      final String shellCoreRef =
          ((deps['motion_core'] as YamlMap)['git'] as YamlMap)['ref'] as String;
      final String engineCoreRef = (((enginePubspec['dependencies']
              as YamlMap)['motion_core'] as YamlMap)['git']
          as YamlMap)['ref'] as String;
      expect(camRef, shellCoreRef,
          reason: 'motion_camera ($camRef) ile kabuk motion_core '
              '($shellCoreRef) AYNI commit olmalı.');
      expect(camRef, engineCoreRef,
          reason: 'motion_camera ($camRef) ile MOTOR motion_core '
              '($engineCoreRef) AYNI commit olmalı.');
    });

    test('ÜÇÜNCÜ ÇAPA: pin DOĞRU şeyde eşit — dış sabitle çivili (M-F-265)', () {
      // ⚠️ Üçlü eşitlik testi "iki kilit aynı mı" der, "DOĞRU şeyde mi aynı"
      // DEMEZ: üç ref'i birden yanlış bir commit'e taşıyan bir düzenleme
      // eşitliği bozmaz ve sessizce geçer. Çapa bu yüzden DIŞARIDA — hem
      // mühürlü ref hem KİLİTTEN ÇÖZÜLEN sürümler.
      //
      // Bu test bir pin bump'ta KIRILIR ve kırılması DOĞRUDUR: bump bilinçli
      // bir karardır, sessiz bir kayma değil. Kıran kişi buradaki sabitleri
      // de günceller ve böylece bump kayda geçer.
      const String sealedRef = 'f2ea161c7e974d57b114ba7773836c72be17a381';
      const String sealedCoreVersion = '0.11.0';
      const String sealedCameraVersion = '0.1.2';

      final YamlMap deps = pubspec['dependencies'] as YamlMap;
      for (final String pkg in <String>['motion_core', 'motion_camera']) {
        final String ref =
            ((deps[pkg] as YamlMap)['git'] as YamlMap)['ref'] as String;
        expect(ref, sealedRef,
            reason: '$pkg pini mühürlü ref\'den kaymış. Bump bilinçliyse '
                'bu testteki sabiti de güncelle.');
      }

      // Kilitten ÇÖZÜLEN sürüm: ref doğru yazılmış olsa bile yanlış paketi
      // gösteriyorsa burada yakalanır. Kilit bloğu SATIR SATIR okunuyor —
      // regex'e göre daha az kırılgan ve hangi alanı sınadığı okunur.
      final List<String> lock =
          File('pubspec.lock').readAsLinesSync();
      Map<String, String> lockBlock(String pkg) {
        final int i = lock.indexOf('  $pkg:');
        expect(i, isNot(-1), reason: '$pkg pubspec.lock\'ta yok.');
        final Map<String, String> out = <String, String>{};
        for (int j = i + 1; j < lock.length; j++) {
          final String line = lock[j];
          // Bir sonraki paket bloğu iki boşlukla başlar.
          if (RegExp(r'^  [a-z_]+:').hasMatch(line)) break;
          final Match? kv = RegExp(r'^\s+([a-z_-]+): "?([^"]*)"?\s*$')
              .firstMatch(line);
          if (kv != null) out[kv.group(1)!] = kv.group(2)!;
        }
        return out;
      }

      final Map<String, String> core = lockBlock('motion_core');
      expect(core['version'], sealedCoreVersion,
          reason: 'motion_core kilitte beklenen sürüm değil — ref doğru '
              'yazılmış olsa bile çözülen paket başka.');
      expect(core['resolved-ref'], sealedRef,
          reason: 'motion_core çözülen commit mühürlü ref değil.');

      final Map<String, String> cam = lockBlock('motion_camera');
      expect(cam['version'], sealedCameraVersion,
          reason: 'motion_camera kilitte beklenen sürüm değil.');
      expect(cam['resolved-ref'], sealedRef,
          reason: 'motion_camera çözülen commit mühürlü ref değil.');
    });

    test('kısa-SHA YASAK — pub ref\'leri METİN olarak karşılaştırıyor', () {
      // Choreia ölçtü (M-F-265): `motion_camera` kendi `motion_core`
      // bağımlılığını TAM-40-SHA bildiriyor. Kısa SHA yazarsak aynı commit
      // İKİ AYRI KAYNAK sayılır ve pub reddeder. Eşitlik aynı COMMIT değil
      // aynı DİZE meselesidir.
      //
      // ⚠️ SINANDI (G-121): kısa SHA yazınca bu test ATEŞLENMEDİ çünkü pub
      // DAHA ÖNCE durdu — `flutter pub get` çözümlemede düşüyor:
      //   "...at f13bdc9..., motion_camera from git is forbidden."
      // Yani asıl kapı çözümleyicide ve testten ÖNCE geliyor; bu test
      // savunma derinliği (lock önceden çözülmüşken pubspec'e kısa SHA
      // sızarsa yakalar), tek kapı DEĞİL. Ölü test değil ama tek başına
      // güvenilecek kapı da değil — hangi kapının önce ötüğü kayıtlı.
      final YamlMap deps = pubspec['dependencies'] as YamlMap;
      for (final String pkg in <String>['motion_core', 'motion_camera']) {
        final String ref =
            ((deps[pkg] as YamlMap)['git'] as YamlMap)['ref'] as String;
        expect(ref.length, 40,
            reason: '$pkg ref uzunluğu ${ref.length} — kısa SHA pub '
                'tarafında ayrı kaynak sayılır.');
      }
    });

    test('model pini asset olarak PAKETLİ ve git dışında', () {
      // Yokluk+varlık ikizi tek testte: dosya asset listesinde OLMALI ama
      // git'te OLMAMALI (aile kuralı: 9 MB ikili izlenmez, pin SHA olarak
      // yaşar ve `tool/fetch_pose_model.sh` her build'de doğrular).
      expect(File('tool/fetch_pose_model.sh').existsSync(), isTrue,
          reason: 'Model fetch/doğrulama betiği yok — pin doğrulanamaz.');
      expect(File('.gitignore').readAsStringSync(),
          contains('assets/models/*.task'),
          reason: '.task git\'e girerse pin iki yerde yaşar ve ayrışır.');
      final YamlList assets =
          (pubspec['flutter'] as YamlMap)['assets'] as YamlList;
      expect(assets.map((Object? e) => e.toString()),
          contains('assets/models/'),
          reason: 'Model asset listesinde yok — plugin dosyayı bulamaz.');
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
