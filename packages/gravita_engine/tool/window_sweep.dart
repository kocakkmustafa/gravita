import 'dart:convert';
import 'dart:io';

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;

/// G-041 — pencere darboğazı parametre taraması.
///
/// İki aday: **zamansal histerezis** (tek karelik titreme pencereyi kapatmasın)
/// ve **N-of-10** (landmark'ların hepsi yerine N tanesi yetsin). Koordinatörün
/// gerekçesi: N-of-10 hangi landmark'ın eksik olduğuna KÖR — ölçtüğün metriğin
/// landmark'ı eksikse N sağlansa bile ölçüm yok. Histerezis gerçek titremeyi
/// hedefliyor. Yine de ikisi de ölçülüyor; seçimi sayı versin.
void main(List<String> args) {
  final Directory dir = Directory(args.isEmpty
      ? '${Platform.environment['HOME']}/motion-harvest/gravita/landmarks'
      : args[0]);
  final MovementConfig cfg = MovementConfig.parse(
      File('../../content/catalog/w1/push_up.json').readAsStringSync());

  const List<int> needed = <int>[
    Lm.leftShoulder, Lm.rightShoulder, Lm.leftElbow, Lm.rightElbow,
    Lm.leftWrist, Lm.rightWrist, Lm.leftHip, Lm.rightHip,
    Lm.leftAnkle, Lm.rightAnkle,
  ];

  /// Ölçüm için ZORUNLU olanlar: dirsek zinciri + gövde referansı. Bunlar
  /// eksikse açı hesaplanamaz, N kaç olursa olsun.
  const Set<int> mandatory = <int>{
    Lm.leftShoulder, Lm.rightShoulder, Lm.leftElbow, Lm.rightElbow,
    Lm.leftWrist, Lm.rightWrist, Lm.leftHip, Lm.rightHip,
  };

  final List<({String name, bool Function(PoseFrame) judge, int bridgeMs})>
      variants = <({String name, bool Function(PoseFrame) judge, int bridgeMs})>[
    (name: 'taban (10/10, köprü 0.5sn)', judge: scopedJudge(needed), bridgeMs: 500),
    (name: 'histerezis 1.0sn', judge: scopedJudge(needed), bridgeMs: 1000),
    (name: 'histerezis 2.0sn', judge: scopedJudge(needed), bridgeMs: 2000),
    (
      name: '8/10 (zorunlular şart)',
      judge: (PoseFrame f) {
        int ok = 0;
        for (final int i in needed) {
          final PoseLandmark l = f.landmarks[i];
          final bool good = l.x >= 0 && l.x <= 1 && l.y >= 0 && l.y <= 1 &&
              l.visibility >= 0.5;
          if (!good && mandatory.contains(i)) return false;
          if (good) ok++;
        }
        return ok >= 8;
      },
      bridgeMs: 500
    ),
    (
      name: '8/10 + histerezis 2.0sn',
      judge: (PoseFrame f) {
        int ok = 0;
        for (final int i in needed) {
          final PoseLandmark l = f.landmarks[i];
          final bool good = l.x >= 0 && l.x <= 1 && l.y >= 0 && l.y <= 1 &&
              l.visibility >= 0.5;
          if (!good && mandatory.contains(i)) return false;
          if (good) ok++;
        }
        return ok >= 8;
      },
      bridgeMs: 2000
    ),
  ];

  final List<({String src, FrameSize size, List<PoseFrame> frames})> sources =
      <({String src, FrameSize size, List<PoseFrame> frames})>[];
  for (final File f in dir.listSync().whereType<File>().where(
      (File f) => f.path.endsWith('.json'))) {
    final Map<String, dynamic> fx =
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final Map<String, dynamic> meta = fx['recordingMeta'] as Map<String, dynamic>;
    final List<String> wh =
        ((meta['resolution'] as String?) ?? '1920x1080').split('x');
    final List<PoseFrame> frames = <PoseFrame>[];
    for (final dynamic raw in fx['frames'] as List<dynamic>) {
      final Map<String, dynamic> fr = raw as Map<String, dynamic>;
      if (fr['detected'] != true) continue;
      final List<dynamic> lm = fr['lm'] as List<dynamic>;
      if (lm.length != Lm.count) continue;
      frames.add(PoseFrame(
        tUs: ((fr['t'] as num) * 1000).round(), // `t` MİLİSANİYE (G-040)
        landmarks: lm
            .map((dynamic p) => PoseLandmark(
                  ((p as List<dynamic>)[0] as num).toDouble(),
                  (p[1] as num).toDouble(),
                  (p[2] as num).toDouble(),
                  (p[3] as num).toDouble(),
                ))
            .toList(),
      ));
    }
    sources.add((
      src: f.uri.pathSegments.last.replaceAll('.full.json', ''),
      size: FrameSize(int.parse(wh[0]), int.parse(wh[1])),
      frames: frames
    ));
  }

  stdout.writeln('${'varyant'.padRight(26)}${'TEKRAR'.padLeft(8)}'
      '${'≥3 tekrar veren'.padLeft(16)}${'pencere'.padLeft(9)}'
      '${'en uzun'.padLeft(9)}${'medyan pencere'.padLeft(15)}');

  for (final ({String name, bool Function(PoseFrame) judge, int bridgeMs}) v
      in variants) {
    int totalReps = 0, totalWindows = 0, enough = 0;
    double longest = 0;
    final List<double> lens = <double>[];
    for (final ({String src, FrameSize size, List<PoseFrame> frames}) s
        in sources) {
      final List<List<PoseFrame>> windows = <List<PoseFrame>>[];
      List<PoseFrame> cur = <PoseFrame>[];
      int last = -1 << 40;
      for (final PoseFrame f in s.frames) {
        if (!v.judge(f)) continue;
        if (f.tUs - last > v.bridgeMs * 1000 && cur.isNotEmpty) {
          windows.add(cur);
          cur = <PoseFrame>[];
        }
        cur.add(f);
        last = f.tUs;
      }
      if (cur.isNotEmpty) windows.add(cur);

      int reps = 0;
      for (final List<PoseFrame> w in windows) {
        final double len = (w.last.tUs - w.first.tUs) / 1e6;
        lens.add(len);
        if (len > longest) longest = len;
        final RepEngine e = RepEngine(cfg, judge: v.judge);
        for (final PoseFrame f in w) {
          e.addFrame(f, s.size);
        }
        reps += e.repCount;
      }
      totalReps += reps;
      totalWindows += windows.length;
      if (reps >= 3) enough++;
    }
    lens.sort();
    final double med = lens.isEmpty ? 0 : lens[lens.length ~/ 2];
    stdout.writeln('${v.name.padRight(26)}${totalReps.toString().padLeft(8)}'
        '${'$enough/${sources.length}'.padLeft(16)}'
        '${totalWindows.toString().padLeft(9)}'
        '${'${longest.toStringAsFixed(1)}s'.padLeft(9)}'
        '${'${med.toStringAsFixed(1)}s'.padLeft(15)}');
  }
}
