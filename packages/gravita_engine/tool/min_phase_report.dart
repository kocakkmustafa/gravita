import 'dart:convert';
import 'dart:io';

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;

import 'harvest_reps.dart' show mandatoryFor, requiredFor;

/// `minPhaseMs` SALT-RAPOR dağılımı (M-F-162 hüküm 3, adım c).
///
/// Zorlama kararı ancak ÖLÇÜLMÜŞ dağılımdan verilir — bu araç o dağılımı
/// üretir. Hiçbir eşik uygulanmaz, hiçbir tekrar reddedilmez; yalnız
/// `RepEngine.phasesBelowMinMs / phasesCounted` okunur.
///
/// G-081: beyan bugüne dek ayrıştırılıp hiç okunmuyordu (dördüncü ölü-config
/// vakası). Şimdi ölçülüyor, hâlâ zorlanmıyor (G-054 koruması).
void main(List<String> args) {
  final Map<String, ({String dir, bool harvest})> pools =
      <String, ({String dir, bool harvest})>{
    'push_up': (
      dir: '${Platform.environment['HOME']}/motion-harvest/gravita/landmarks',
      harvest: false,
    ),
    'bodyweight_squat': (
      dir: '${Platform.environment['HOME']}'
          '/motion-harvest/gravita-squat/landmarks',
      harvest: true,
    ),
  };

  final Map<String, dynamic> report = <String, dynamic>{
    r'$measurement': 'phases below declared minPhaseMs — REPORT ONLY',
    r'$ruling': 'M-F-162 hüküm 3: beyan edilen taban RAPORLANIR, ZORLANMAZ. '
        'Zorlama kararı ancak ölçülmüş dağılımdan verilir (G-054: sayım '
        'eşiği CÖMERT DIŞ SINIR olmalı).',
    'movements': <String, dynamic>{},
  };

  for (final MapEntry<String, ({String dir, bool harvest})> pool
      in pools.entries) {
    final String id = pool.key;
    final Directory dir = Directory(pool.value.dir);
    if (!dir.existsSync()) continue;

    final MovementConfig cfg = MovementConfig.parse(
        File('../../content/catalog/w1/$id.json').readAsStringSync());
    final Set<int> mandatory = mandatoryFor(cfg).toSet();
    final List<int> all = requiredFor(cfg);
    bool judge(PoseFrame f) {
      int ok = 0;
      for (final int i in all) {
        final PoseLandmark l = f.landmarks[i];
        final bool good = l.x >= 0 && l.x <= 1 && l.y >= 0 && l.y <= 1 &&
            l.visibility >= 0.5;
        if (!good && mandatory.contains(i)) return false;
        if (good) ok++;
      }
      return ok >= all.length - 2;
    }

    int below = 0, counted = 0, reps = 0, clips = 0;
    for (final File f in dir
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.endsWith('.json'))) {
      final Map<String, dynamic> fx =
          jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final Map<String, dynamic> meta =
          fx['recordingMeta'] as Map<String, dynamic>;
      final List<String> wh =
          ((meta['resolution'] as String?) ?? '1920x1080').split('x');
      final FrameSize size = FrameSize(int.parse(wh[0]), int.parse(wh[1]));
      final RepEngine e = RepEngine(cfg,
          judge: judge, harvestIdentityAttested: pool.value.harvest);
      for (final dynamic raw in fx['frames'] as List<dynamic>) {
        final Map<String, dynamic> fr = raw as Map<String, dynamic>;
        if (fr['detected'] != true) continue;
        final List<dynamic>? lm = fr['lm'] as List<dynamic>?;
        if (lm == null || lm.length != Lm.count) continue;
        e.addFrame(
          PoseFrame(
            tUs: ((fr['t'] as num) * 1000).round(),
            modelVersion: fx['modelVersion'] as String,
            landmarks: lm
                .map((dynamic p) => PoseLandmark(
                      ((p as List<dynamic>)[0] as num).toDouble(),
                      (p[1] as num).toDouble(),
                      (p[2] as num).toDouble(),
                      (p[3] as num).toDouble(),
                    ))
                .toList(),
          ),
          size,
        );
      }
      below += e.phasesBelowMinMs;
      counted += e.phasesCounted;
      reps += e.repCount;
      clips++;
    }

    final int minMs = (cfg.rep?.minPhaseUs ?? 0) ~/ 1000;
    final double share = counted == 0 ? double.nan : below / counted;
    stdout.writeln('$id · minPhaseMs=$minMs · klip=$clips · tekrar=$reps');
    stdout.writeln('  taban ALTI faz: $below / $counted '
        '(${(share * 100).toStringAsFixed(1)}%)');
    (report['movements'] as Map<String, dynamic>)[id] = <String, dynamic>{
      'minPhaseMs': minMs,
      'clips': clips,
      'reps': reps,
      'phasesCounted': counted,
      'phasesBelowMinMs': below,
      'shareBelow': counted == 0
          ? null
          : double.parse((below / counted).toStringAsFixed(4)),
    };
  }

  File('../../content/harvest/min-phase-report.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n');
  stdout.writeln('\nyazıldı: content/harvest/min-phase-report.json');
}
