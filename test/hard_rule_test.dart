import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ⛔ SERT KURAL SÜPÜRMESİ — *"kural var"* ile *"kural ZORLANIYOR"* ayrı şeyler.
///
/// JabLab sekiz sert kuralını tek tek süpürdü ve en pahalı bulgusu şuydu:
/// canlı replik southpaw duruşta **yanlış eli** söylüyordu, ve kural
/// (*"sol/sağ denmez"*) **zaten vardı — kapı yoktu.**
///
/// Bu hatta kanıtı `02253bc`: *"sahte iskelet-avatar YOK"* bir sert kuraldı,
/// nöbeti VARDI, ve **nöbet vakum-doğruydu** — kural üç yıl yeşil kalabilirdi.
///
/// ## Taksonomi (kapı YOKSA hangi sınıftan yok)
///
/// **① meşru hâli var** — bugün ihlal edilemiyor çünkü ilgili yüzey/yol yok.
///    Bir gün bağlanabilir; kutuya konursa o gün kaybolur.
/// **② kural kendi ölçütünü geçemiyor** — ölçülebilir ama ölçülmemiş.
/// **③ yanlışlayacak referans yok** — mekanik olarak kapatılamaz (göz işi).
///
/// Üçü tek kutuya konursa **hangisinin bir gün bağlanabileceği kaybolur.**
void main() {
  List<File> dartIn(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();

  group('⛔ TEK GENEL SKOR YOK — 7 bileşen asla toplanmaz', () {
    // Sınıf ①→ artık KAPALI. Bugün hiçbir yerde toplama yok (ölçüldü), ama
    // *"bugün yok"* bir kapı değildi: bileşenler yüzeye çıktığı gün onları
    // toplamak tek satırlık bir iş ve hiçbir şey ötmezdi.
    test('toplayıcı bir kimlik YOK — ne motorda ne kabukta', () {
      // Toplama niyetini ele veren adlar. Bir gün biri "genel skor"
      // hesaplarsa, adı bunlardan biri olma ihtimali yüksek — ve bu kapı
      // niyeti ADIYLA yakalar, aritmetiği izlemeye çalışmaz.
      final RegExp summing = RegExp(
          r'\b(overallScore|totalScore|compositeScore|finalScore|'
          r'combinedScore|aggregateScore|genelSkor|toplamSkor)\b');
      final List<String> offenders = <String>[
        for (final File f in <File>[
          ...dartIn('lib'),
          ...dartIn('packages/gravita_engine/lib'),
        ])
          if (summing.hasMatch(f.readAsStringSync())) f.path,
      ];
      expect(offenders, isEmpty,
          reason: 'Toplayıcı bir skor kimliği belirdi: $offenders. 7 bileşen '
              'AYRIDIR ve asla toplanmaz — tek sayı, ölçülmemiş bir bütünlük '
              'iddiasıdır.');
    });

    test('hiçbir hareket SAYISAL skor göstermiyor — hepsi `band`', () {
      // K8'in içerik tarafı: kalibrasyon kapısı geçilmeden sayısal skor
      // gösterilmez. `validate_catalog` V4 bunu zaten denetliyor; buradaki
      // ikizi, kapının SONUCUNU bağımsız ölçüyor (V4 bir gün gevşerse).
      final Set<String?> displays = <String?>{};
      for (final FileSystemEntity d
          in Directory('content/catalog').listSync()) {
        if (d is! Directory) continue;
        for (final FileSystemEntity f in d.listSync()) {
          if (f is! File || !f.path.endsWith('.json')) continue;
          final Map<String, dynamic> m =
              (jsonDecode(f.readAsStringSync()) as Map).cast<String, dynamic>();
          displays.add(
              (m['measurementContract'] as Map?)?['scoreDisplay'] as String?);
        }
      }
      expect(displays, <String>{'band'},
          reason: 'Bir hareket `band` dışında bir skor gösterimi bildiriyor: '
              '$displays. Kalibre edilmemiş sayısal skor YOK (K8).');
    });
  });

  group('⛔ ASPİRASYONEL DÜĞÜM ROZETSİZ', () {
    // ⚠️ Sınıf ② idi: **ölçülebilir ama ölçülmemiş.** `planche` paketi ÜÇ
    // aspirasyonel düğüm taşıyor (`advanced_tuck_planche` ·
    // `straddle_planche` · `full_planche`) ve `aspirational` sözcüğü
    // `tools/` · `test/` · `lib/` hiçbirinde geçmiyordu — yani kural vardı,
    // kapı yoktu.
    //
    // ⚠️ Ve dikkat: *"hiçbir düğüm rozetli değil"* demek bugün VAKUM-DOĞRU
    // olurdu, çünkü ağaç HİÇ ÇİZİLMİYOR (koordinatör kararı bekliyor).
    // O yüzden kapı çizime değil, **veriye** kuruluyor: aspirasyonel
    // düğümler İSİMLİ kalmalı ve içeriklerinde ödül dili OLMAMALI.
    // Ağaç çizildiği gün bu liste hazır olacak.
    test('aspirasyonel düğümler İSİMLİ — sessizce sıradanlaşmıyorlar', () {
      final List<String> aspirational = <String>[];
      for (final FileSystemEntity f
          in Directory('content/skill-graph').listSync()) {
        if (f is! File || !f.path.endsWith('.json')) continue;
        final Map<String, dynamic> pack =
            (jsonDecode(f.readAsStringSync()) as Map).cast<String, dynamic>();
        for (final dynamic n
            in (pack['nodes'] as List<dynamic>?) ?? const <dynamic>[]) {
          if ((n as Map)['aspirational'] == true) {
            aspirational.add(n['id'] as String);
          }
        }
      }
      expect(aspirational, isNotEmpty,
          reason: 'Hiçbir düğüm `aspirational` işaretli değil. Ya işaret '
              'silindi ya da elit beceriler sıradan düğüm gibi duruyor — '
              'ikisi de rozet yasağını anlamsızlaştırır.');
    });

    test('uygulamada ROZET/ÖDÜL yüzeyi YOK — çizilemez, verilemez', () {
      // ⚠️ Bu testin İÇERİK sürümü İKİ KEZ fazla geniş çıktı ve ikincisi
      // öğreticiydi:
      //   1. tüm JSON taranıyordu → `unlock` ANAHTARINDA öttü (o bir ödül
      //      sözcüğü değil, ilerleme ölçütünün yapısal alanı)
      //   2. yalnız değerler tarandı → `full_planche`ın güvenlik notunda
      //      öttü: *"This is guided, **not badged** — there is no rush."*
      //      Yani kapı, **uyumu KANITLAYAN cümleyi** öldürüyordu.
      //
      // Prose taraması "badged" ile "not badged"i ayıramaz, ve uyumu
      // kanıtlayan cümleyi öldüren bir kapı, kapısızlıktan KÖTÜDÜR.
      // (Ters-ikiz dersinin en saf hâli, G-146.)
      //
      // O yüzden kapı KARAR VEREBİLECEĞİ şeye kuruluyor — `CustomPainter`
      // düzeltmesiyle aynı hamle: rozet yasağının asıl garantisi
      // **uygulamada rozet/ödül yüzeyinin HİÇ OLMAMASI.** Bir düğüm
      // rozetlenemez, çünkü rozet diye bir şey yok.
      const List<String> rewardUi = <String>[
        'Badge(', 'AchievementCard', 'TrophyWidget', 'RewardBanner',
        'StreakCounter',
      ];
      final List<String> found = <String>[
        for (final File f in dartIn('lib'))
          for (final String w in rewardUi)
            if (f.readAsStringSync().contains(w)) '${f.path}: $w',
      ];
      expect(found, isEmpty,
          reason: 'Uygulamada bir ödül/rozet yüzeyi belirdi: $found. '
              'Aspirasyonel düğümler ROZETSİZDİR (blueprint §8) — ve rozet '
              'diye bir şey olmadığı sürece bu yapısal olarak garanti.');

      // İkinci yarı: `GravitaPill` rozet-benzeri TEK bileşen ve yalnız
      // DURUM etiketi taşıyor (OPEN/CLOSED/LOCKED/CLASS). Bir başarı adı
      // taşırsa ödül rozetine dönüşür.
      const List<String> statusOnly = <String>[
        'OPEN', 'CLOSED', 'LOCKED', 'CLASS',
      ];
      final String strings =
          File('lib/app/library_strings.dart').readAsStringSync();
      final RegExp pillLabel = RegExp(r"Badge\s*=\s*'([A-Z ]+)'");
      for (final RegExpMatch m in pillLabel.allMatches(strings)) {
        expect(statusOnly.any((String s) => m.group(1)!.contains(s)), isTrue,
            reason: 'Rozet etiketi bir DURUM değil: "${m.group(1)}" — '
                'başarı adı taşıyan pill, ödül rozetidir.');
      }
    });

    test('aspirasyonel düğüm metninde ödül dili — YALNIZ olumsuzlanmış hâlde',
        () {
      // ⚠️ Kapsam DAR: yalnız OLUMSUZLANMAMIŞ kullanım ihlaldir. Bu ayrım
      // olmadan kapı, kuralı doğrulayan cümleyi cezalandırıyordu.
      const List<String> reward = <String>[
        'badge', 'reward', 'achievement', 'trophy', 'earn',
      ];
      const List<String> negation = <String>['not ', 'no ', 'never ', "n't "];
      for (final FileSystemEntity f
          in Directory('content/skill-graph').listSync()) {
        if (f is! File || !f.path.endsWith('.json')) continue;
        final Map<String, dynamic> pack =
            (jsonDecode(f.readAsStringSync()) as Map).cast<String, dynamic>();
        for (final dynamic n
            in (pack['nodes'] as List<dynamic>?) ?? const <dynamic>[]) {
          if ((n as Map)['aspirational'] != true) continue;
          // ⚠️ YALNIZ DEĞERLER taranıyor, ANAHTARLAR değil — ve bu bir
          // düzeltmenin ürünü. İlk hâli tüm JSON'u tarıyordu ve `unlock`
          // anahtarında öttü: o bir ÖDÜL sözcüğü değil, beceri grafiğinin
          // kendi YAPISAL alanı (`unlock: {allOf: [...]}` = ilerleme
          // ölçütü). Ödül yasağı ilerleme ölçütünü yasaklamaz — düğümün
          // ROZETLENMESİNİ yasaklar.
          //
          // Bu, bu gecede kurduğum kapıların BEŞİNCİ fazla-geniş ilk hâli.
          // Desen artık tartışmasız: ilk taslak hep geniş çıkıyor.
          final List<String> values = <String>[];
          void harvest(Object? v) {
            if (v is String) {
              values.add(v.toLowerCase());
            } else if (v is Map) {
              v.values.forEach(harvest);
            } else if (v is List) {
              v.forEach(harvest);
            }
          }

          harvest(n);
          for (final String w in reward) {
            final Iterable<String> affirmative = values.where((String v) {
              final int i = v.indexOf(w);
              if (i < 0) return false;
              // Sözcükten ÖNCEKİ 12 karakterde olumsuzlama varsa, cümle
              // kuralı ANLATIYOR demektir — ihlal değil.
              final String before = v.substring((i - 12).clamp(0, i), i);
              return !negation.any(before.contains);
            });
            expect(affirmative, isEmpty,
                reason: '${n['id']}: aspirasyonel düğümün metninde ödül dili '
                    '"$w" OLUMLU kullanılmış — rehberli ilerleme VAR, ödül '
                    'YOK (blueprint §8). Geçtiği yer: '
                    '${affirmative.take(1).join()}');
          }
        }
      }
    });
  });

  group('⛔ identityGapShare RAPOR-ONLY kalır', () {
    test('kabuk onu HİÇ okumuyor — hüküm kurmuyor', () {
      // Sınıf ①→ KAPALI. Alan motorda hesaplanıyor (`Rep.identityGapShare`)
      // ama kabuğa taşınmamalı: taşınırsa bir kullanıcı hükmüne dönüşmesi
      // bir satır uzaklıkta olur. Kapı o satırı yakalar.
      final List<String> leaked = <String>[
        for (final File f in dartIn('lib'))
          if (f.readAsStringSync().contains('identityGapShare')) f.path,
      ];
      expect(leaked, isEmpty,
          reason: 'identityGapShare kabuğa sızdı: $leaked. RAPOR-ONLY kalması '
              'gerekiyordu — yüzeye çıkan her ölçüm bir hükme dönüşmeye '
              'adaydır.');
    });
  });

  group('⛔ DERS İZLEMEKLE KİLİT AÇILMAZ', () {
    test('kilit yalnız ÖLÇÜM sınıfından açılabilir', () {
      // `lockClass: measurement` zorunlu (K9) — yapı/ekran kilidi ölçüm
      // kilidi gibi sunulamaz. Buradaki ikizi, kilidin AÇILMA yolunu
      // sorguluyor: hiçbir kilit "izlendi/tamamlandı" gibi bir DAVRANIŞA
      // bağlı olamaz.
      final Map<String, dynamic> lib =
          (jsonDecode(File('content/library.json').readAsStringSync()) as Map)
              .cast<String, dynamic>();
      for (final Map<String, dynamic> m
          in (lib['movements'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        for (final dynamic c
            in (m['courses'] as List<dynamic>?) ?? const <dynamic>[]) {
          for (final dynamic l in ((c as Map)['lessons'] as List<dynamic>?) ??
              const <dynamic>[]) {
            if ((l as Map)['status'] != 'locked') continue;
            expect(l['lockClass'], 'measurement',
                reason: '${l['id']}: kilit sınıfı `measurement` değil — '
                    'ders izlemekle ya da başka bir davranışla açılabilir '
                    'görünüyor.');
          }
        }
      }
    });
  });
}
