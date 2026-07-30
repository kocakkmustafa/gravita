import 'dart:convert';
import 'dart:io';

import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;

/// Barbell-kaynaklı take'ler referansı BOZUYOR mu? (M-F-171 hüküm 4 uzantısı)
///
/// "Kirlenme var" demek yetmez — kirlenmenin ÖLÇÜLEBİLİR bir etkisi var mı?
/// Yüklü squat'ta bar orta-ayak üzerinde tutulmak için gövde DAHA ÖNE eğilir.
/// Bu araç katkı veren 36 take'i iki gruba ayırıp gövde eğimi ve diz açısını
/// karşılaştırır. SALT RAPOR — eşik yok, artefakt değişmiyor.
void main(List<String> args) {
  const Set<String> barbellVideos = <String>{
    'sdeQjm7avi8', 'bEv6CCg2BC8', 'gcNh17Ckjgg',
  };
  final Directory sliced = Directory('${Platform.environment['HOME']}'
      '/motion-harvest/gravita-squat/landmarks-rep-sliced');
  final Map<String, dynamic> ref = jsonDecode(
      File('../../content/harvest/reference.bodyweight_squat.json')
          .readAsStringSync()) as Map<String, dynamic>;
  final Set<String> excluded =
      (ref['result']['excludedOutlierIds'] as List<dynamic>).cast<String>().toSet();

  const ReferenceCli cli = ReferenceCli(allowUnattested: true);
  final Map<String, List<double>> trunk = <String, List<double>>{
    'barbell': <double>[], 'other': <double>[],
  };
  final Map<String, List<double>> knee = <String, List<double>>{
    'barbell': <double>[], 'other': <double>[],
  };
  final Map<String, int> takes = <String, int>{'barbell': 0, 'other': 0};

  for (final File f in sliced
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.json'))) {
    final String id = f.uri.pathSegments.last.replaceAll('.full.json', '');
    if (excluded.contains(id)) continue; // yalnız KATKI VEREN take'ler
    final Fixture fx = Fixture.decode(f.readAsStringSync());
    final String rule = (fx.provenance?.raw['windowRule'] as String?) ??
        (fx.provenance?.raw[r'$windowRule'] as String?) ?? '';
    final RegExpMatch? m =
        RegExp(r'source=.*/([A-Za-z0-9_\-]+)\.full\.json').firstMatch(rule);
    final String vid = m?.group(1) ?? '?';
    final String grp = barbellVideos.contains(vid) ? 'barbell' : 'other';
    final List<JointAngleVector> frames = cli.prepareTake(id, fx).take.frames;
    if (frames.isEmpty) continue;
    takes[grp] = takes[grp]! + 1;
    // Dip anı = diz açısının EN KÜÇÜK olduğu kare (squat'ın ayırt edici anı)
    double bestKnee = double.infinity, bestTrunk = double.nan;
    for (final JointAngleVector v in frames) {
      final double? k = v.degreesById('left_knee') ?? v.degreesById('right_knee');
      final double? t = v.degreesById('trunk_tilt');
      if (k == null || t == null) continue;
      if (k < bestKnee) {
        bestKnee = k;
        bestTrunk = t;
      }
    }
    if (bestKnee.isFinite && !bestTrunk.isNaN) {
      knee[grp]!.add(bestKnee);
      trunk[grp]!.add(bestTrunk);
    }
  }

  double med(List<double> xs) {
    if (xs.isEmpty) return double.nan;
    final List<double> s = List<double>.of(xs)..sort();
    return s[s.length ~/ 2];
  }
  double mean(List<double> xs) =>
      xs.isEmpty ? double.nan : xs.reduce((double a, double b) => a + b) / xs.length;

  stdout.writeln('KATKI VEREN take\'ler, DİP anında (diz açısı en küçük kare)\n');
  stdout.writeln('${'grup'.padRight(10)} ${'take'.padLeft(5)} '
      '${'gövde eğimi medyan'.padLeft(20)} ${'ort'.padLeft(8)} '
      '${'diz medyan'.padLeft(12)}');
  for (final String g in <String>['barbell', 'other']) {
    stdout.writeln('${g.padRight(10)} ${takes[g].toString().padLeft(5)} '
        '${med(trunk[g]!).toStringAsFixed(1).padLeft(20)} '
        '${mean(trunk[g]!).toStringAsFixed(1).padLeft(8)} '
        '${med(knee[g]!).toStringAsFixed(1).padLeft(12)}');
  }
  final double d = med(trunk['barbell']!) - med(trunk['other']!);
  stdout.writeln('\ngövde eğimi FARKI (barbell − diğer): '
      '${d.toStringAsFixed(1)}°');
  final Map<String, dynamic> out = <String, dynamic>{
    r'$measurement': 'barbell-sourced vs other contributing takes, trunk tilt '
        'and knee angle at the deepest frame — REPORT ONLY',
    r'$barbellVideos': barbellVideos.toList(),
    'groups': <String, dynamic>{
      for (final String g in <String>['barbell', 'other'])
        g: <String, dynamic>{
          'takes': takes[g],
          'trunkTiltMedianDeg': double.parse(med(trunk[g]!).toStringAsFixed(2)),
          'trunkTiltMeanDeg': double.parse(mean(trunk[g]!).toStringAsFixed(2)),
          'kneeMedianDeg': double.parse(med(knee[g]!).toStringAsFixed(2)),
        },
    },
    'trunkTiltMedianDeltaDeg': double.parse(d.toStringAsFixed(2)),
  };
  File('../../content/harvest/barbell-distortion.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(out)}\n');
  stdout.writeln('yazıldı: content/harvest/barbell-distortion.json');
}
