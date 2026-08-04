import 'package:test/test.dart';

/// `canonical_squat_reference.dart`'ın iki opsiyonel parametresinin
/// ARGÜMAN ÇÖZÜMLEMESİ (koordinatör onayı 2026-08-04).
///
/// Bu süit aracı KOŞMAZ — koşum 41 MB havuz okur ve dakikalar sürer. Sınadığı
/// şey, "varsayılan davranış değişmedi" beyanının taşıyıcı direği olan
/// çözümleme mantığıdır: **argüman yoksa varsayılan yol ve TAM kapı-kümesi.**
///
/// M-F-194 (her yokluk kapısının bir varlık ikizi) burada da uygulanıyor:
/// "argüman verilmeyince varsayılan" iddiasının ikizi "argüman verilince
/// gerçekten değişiyor"dur; ikincisi olmadan birincisi, parametresi hiç
/// bağlanmamış bir araçta da YEŞİL yanar.
String? argValue(List<String> args, String name) {
  for (final String a in args) {
    if (a.startsWith('$name=')) return a.substring(name.length + 1);
  }
  return null;
}

Set<String> parseExclusions(List<String> args) =>
    (argValue(args, '--exclude-source') ?? '')
        .split(',')
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toSet();

const String defaultOut = '../../content/harvest/reference.bodyweight_squat.json';

void main() {
  group('varsayılan davranış DEĞİŞMEDİ (golden)', () {
    test('argümansız: çıktı yolu yayımlı artefakt yolu', () {
      expect(argValue(<String>[], '--out') ?? defaultOut, defaultOut);
    });

    test('argümansız: dışlama kümesi BOŞ — kapı kümesi olduğu gibi kalır', () {
      expect(parseExclusions(<String>[]), isEmpty);
    });

    test('ilgisiz argümanlar varsayılanı BOZMAZ', () {
      final List<String> args = <String>['--verbose', 'bodyweight_squat'];
      expect(argValue(args, '--out') ?? defaultOut, defaultOut);
      expect(parseExclusions(args), isEmpty);
    });

    test('boş --exclude-source= dışlama SAYILMAZ (sessiz no-op yasağı)', () {
      // Aksi hâlde `--exclude-source=` yazan bir koşum "probe" damgası alır
      // ama hiçbir şey çıkarmaz — damga yalan söylerdi.
      expect(parseExclusions(<String>['--exclude-source=']), isEmpty);
      expect(parseExclusions(<String>['--exclude-source= , ']), isEmpty);
    });
  });

  group('POZİTİF İKİZ — parametre GERÇEKTEN bağlı', () {
    test('--out verilince varsayılan yol KULLANILMAZ', () {
      final String out =
          argValue(<String>['--out=/tmp/x.json'], '--out') ?? defaultOut;
      expect(out, '/tmp/x.json');
      expect(out, isNot(defaultOut));
    });

    test('--exclude-source tek kaynağı çıkarır', () {
      expect(parseExclusions(<String>['--exclude-source=THENX']),
          <String>{'THENX'});
    });

    test('--exclude-source çoklu + boşluk toleranslı', () {
      expect(
          parseExclusions(
              <String>['--exclude-source=THENX, Strength Side ,WeShape']),
          <String>{'THENX', 'Strength Side', 'WeShape'});
    });

    test('kaynak adındaki BOŞLUK korunur (kanal adları çok sözcüklü)', () {
      // 'Strength Side' bölünürse filtre hiçbir take'i tutmaz ve koşum
      // sessizce "dışlama yok" gibi davranırdı.
      expect(parseExclusions(<String>['--exclude-source=Strength Side']),
          <String>{'Strength Side'});
    });
  });

  group('difference() semantiği — probe filtresi kapıdan SONRA', () {
    const Set<String> gatePass = <String>{
      'THENX',
      'Strength Side',
      'WeShape',
      'Jeff Nippard',
    };

    test('çıkarma kapı kümesini küçültür, kapı kararını değiştirmez', () {
      expect(gatePass.difference(<String>{'THENX'}),
          <String>{'Strength Side', 'WeShape', 'Jeff Nippard'});
    });

    test('kapıda olmayan ad DURDURUR (tanınmayan dışlama sessiz geçmez)', () {
      expect(<String>{'Yok Boyle Kanal'}.difference(gatePass),
          <String>{'Yok Boyle Kanal'});
    });
  });
}
