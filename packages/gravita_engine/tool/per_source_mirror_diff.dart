import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;

/// KAYNAK-BAŞINA sol-sağ eklem farkı — Paket 1b'nin Dart ayağı (M-F-131 hüküm 4).
///
/// Soru: squat referansının `meanLeftRightDiffDeg` değeri **32,26°** çıktı
/// (push_up: 5,16°). Squat İKİ-TARAFLI SİMETRİK bir harekettir; bu kadar büyük
/// bir sol-sağ farkı gerçek bir asimetri DEĞİL, yandan çekimde yakın bacağın
/// uzağı kapatmasından doğan bir 2B-İZDÜŞÜM ARTEFAKTI olabilir (G-061'in
/// kneeAngleAsymmetry bulgusunun referans düzeyindeki karşılığı).
///
/// Bu araç hükmü VERMEZ, yalnız kaynak-başına farkı ölçer. Kamera-açısı ayağı
/// (`shoulder_line_foreshortening`, mocore Python) ayrı araçta; korelasyon
/// `tools/mirror_vs_foreshortening.py`de kurulur.
///
/// ⚠️ Açı matematiği YENİDEN YAZILMADI: kanonik `ReferenceCli.prepareTake`
/// çağrılıyor — yani izotropik dönüşüm, güven kapısı, normalizasyon ve açı
/// çıkarımı referansın kullandığı KOD YOLUNUN AYNISI (kopya-sürüklenmesi
/// riski yok; bu gece bir kez avlandı — G-065/G-066).
///
/// ⚠️ Referansın 32,26°'si KONSENSÜS üzerinde (36 katkı take'i, 6 kaynak);
/// buradaki sayı KAYNAK-BAŞINA ve 12 kaynağın tamamında. İlişkili ama AYNI
/// nicelik değil — karşılaştırırken bu ayrım korunmalı.
void main(List<String> args) {
  final Directory slicedDir = Directory(
      '${Platform.environment['HOME']}/motion-harvest/gravita-squat/landmarks-rep-sliced');

  const ReferenceCli cli = ReferenceCli(allowUnattested: true);

  final Map<String, List<double>> diffsByChannel = <String, List<double>>{};
  final Map<String, int> takesByChannel = <String, int>{};
  // EKLEM-ÇİFTİ kırılımı: 32,26°'yi hangi çiftler sürüklüyor? Squat'ta KOLLAR
  // serbesttir (göğüste, önde, başta, kalçada — eğitmene göre değişir), yani
  // kol asimetrisi GERÇEK davranıştır, izdüşüm artefaktı değil. Referansın
  // `unreliableJoints` listesi de tam olarak kol eklemleriydi.
  final Map<String, List<double>> byPair = <String, List<double>>{};

  for (final File f in slicedDir
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.json'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path))) {
    final Fixture fx = Fixture.decode(f.readAsStringSync());
    final String channel = fx.provenance?.channel ?? '?';
    final String id = f.uri.pathSegments.last.replaceAll('.full.json', '');

    final ({ReferenceTake take, Map<String, dynamic> report}) p =
        cli.prepareTake(id, fx);
    if (p.take.frames.isEmpty) continue;

    // Take içindeki her karede, her sol/sağ eklem ÇİFTİ için dairesel fark.
    double sum = 0;
    int n = 0;
    for (final JointAngleVector v in p.take.frames) {
      for (final JointSpec s in v.specs) {
        if (!s.id.startsWith('left_')) continue;
        final double? a = v.byId(s.id);
        final double? b = v.byId(s.id.replaceFirst('left_', 'right_'));
        if (a == null || b == null) continue;
        // Dairesel fark (G-051: doğrusal çıkarma 359,7° sahte farkı üretir).
        final double d = math.atan2(math.sin(a - b), math.cos(a - b)).abs() *
            180 /
            math.pi;
        sum += d;
        n++;
        (byPair[s.id.replaceFirst('left_', '')] ??= <double>[]).add(d);
      }
    }
    if (n == 0) continue;
    (diffsByChannel[channel] ??= <double>[]).add(sum / n);
    takesByChannel[channel] = (takesByChannel[channel] ?? 0) + 1;
  }

  final Map<String, dynamic> out = <String, dynamic>{
    r'$measurement': 'per-source mean |left-right| joint angle difference '
        '(circular), computed via canonical ReferenceCli.prepareTake',
    r'$why': 'Squat referansının konsensüs meanLeftRightDiffDeg değeri 32,26° '
        '(push_up 5,16°). Squat iki-taraflı simetrik bir harekette bu büyüklük '
        'muhtemelen 2B izdüşüm artefaktı — kamera açısıyla korelasyonu '
        'sınanacak (M-F-131 hüküm 4).',
    r'$caveat': 'Referansın 32,26°si KONSENSÜS üzerinde (36 take/6 kaynak); '
        'buradaki sayılar KAYNAK-BAŞINA ve 12 kaynağın tamamında. İlişkili '
        'ama aynı nicelik DEĞİL.',
    'sources': <String, dynamic>{},
  };
  final Map<String, dynamic> sources = out['sources'] as Map<String, dynamic>;

  stdout.writeln('${'kaynak'.padRight(24)} ${'take'.padLeft(5)} '
      '${'ort.sol-sağ fark°'.padLeft(18)}');
  for (final String ch in diffsByChannel.keys.toList()..sort()) {
    final List<double> ds = diffsByChannel[ch]!;
    final double mean = ds.reduce((double a, double b) => a + b) / ds.length;
    sources[ch] = <String, dynamic>{
      'takes': takesByChannel[ch],
      'meanLeftRightDiffDeg': double.parse(mean.toStringAsFixed(3)),
    };
    stdout.writeln('${ch.padRight(24)} ${ds.length.toString().padLeft(5)} '
        '${mean.toStringAsFixed(2).padLeft(18)}');
  }

  // --- EKLEM-ÇİFTİ kırılımı ---
  const Set<String> armPairs = <String>{
    'shoulder', 'elbow', 'upper_arm', 'forearm',
  };
  stdout.writeln('\n-- eklem-çifti kırılımı (32,26°yi ne sürüklüyor?) --');
  final Map<String, dynamic> pairOut = <String, dynamic>{};
  double armSum = 0, legSum = 0;
  int armN = 0, legN = 0;
  for (final String pair in byPair.keys.toList()..sort()) {
    final List<double> ds = byPair[pair]!;
    final double mean = ds.reduce((double a, double b) => a + b) / ds.length;
    final bool isArm = armPairs.contains(pair);
    pairOut[pair] = <String, dynamic>{
      'meanDiffDeg': double.parse(mean.toStringAsFixed(2)),
      'samples': ds.length,
      'group': isArm ? 'arm' : 'leg/trunk',
    };
    if (isArm) {
      armSum += mean;
      armN++;
    } else {
      legSum += mean;
      legN++;
    }
    stdout.writeln('${pair.padRight(14)} ${isArm ? "KOL " : "bacak"} '
        '${mean.toStringAsFixed(2).padLeft(8)}°  (n=${ds.length})');
  }
  final double armMean = armN == 0 ? double.nan : armSum / armN;
  final double legMean = legN == 0 ? double.nan : legSum / legN;
  stdout.writeln('\nKOL çiftleri ortalaması   : ${armMean.toStringAsFixed(2)}°');
  stdout.writeln('BACAK/GÖVDE ort.          : ${legMean.toStringAsFixed(2)}°');
  stdout.writeln('(push_up referansı bütününde: 5,16°)');
  out[r'$byJointPair'] = pairOut;
  out[r'$armVsLeg'] = <String, dynamic>{
    'armMeanDiffDeg': double.parse(armMean.toStringAsFixed(2)),
    'legTrunkMeanDiffDeg': double.parse(legMean.toStringAsFixed(2)),
    'note': 'Squat\'ta kollar serbesttir (eğitmene göre göğüste/önde/başta) — '
        'kol asimetrisi GERÇEK davranış, izdüşüm artefaktı DEĞİL. Referansın '
        'unreliableJoints listesi de kol eklemleriydi. Bu kırılım, 32,26°lık '
        'toplu sayının hangi gruptan geldiğini gösterir.',
  };

  File('../../content/harvest/mirror-diff-by-source.bodyweight_squat.json')
      .writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(out)}\n');
  stdout.writeln('\nyazıldı: content/harvest/'
      'mirror-diff-by-source.bodyweight_squat.json');
}
