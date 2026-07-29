import 'dart:convert';
import 'dart:io';

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart';

/// Zincirin HANGİ halkası tıkıyor? Tahmin değil, halka halka sayım.
void main(List<String> args) {
  const List<int> needed = <int>[
    Lm.leftShoulder, Lm.rightShoulder, Lm.leftElbow, Lm.rightElbow,
    Lm.leftWrist, Lm.rightWrist, Lm.leftHip, Lm.rightHip,
    Lm.leftAnkle, Lm.rightAnkle,
  ];
  final FrameJudge judge = scopedJudge(needed);
  const JointAngleExtractor extractor = JointAngleExtractor();

  stdout.writeln('${'kaynak'.padRight(14)}${'algıl.'.padLeft(8)}'
      '${'yargıç-RED'.padLeft(11)}${'yapısal-RED'.padLeft(12)}'
      '${'açı-YOK'.padLeft(9)}${'GEÇEN'.padLeft(7)}   başlıca yapısal kusur');

  for (final File f in Directory(args[0])
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.json'))) {
    final Map<String, dynamic> fx =
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final Map<String, dynamic> meta = fx['recordingMeta'] as Map<String, dynamic>;
    final List<String> wh =
        ((meta['resolution'] as String?) ?? '1920x1080').split('x');
    final FrameSize size = FrameSize(int.parse(wh[0]), int.parse(wh[1]));
    final PoseNormalizer normalizer = PoseNormalizer();

    int det = 0, judgeRej = 0, structRej = 0, angleNull = 0, pass = 0;
    final List<double> angles = <double>[];
    final Map<String, int> faults = <String, int>{};

    for (final dynamic raw in fx['frames'] as List<dynamic>) {
      final Map<String, dynamic> fr = raw as Map<String, dynamic>;
      if (fr['detected'] != true) continue;
      final List<dynamic> lm = fr['lm'] as List<dynamic>;
      if (lm.length != Lm.count) continue;
      det++;
      final PoseFrame frame = PoseFrame(
        // fixture `t` MİLİSANİYE (fps 29.97 -> 33.37 ms/kare). Saniye sanıp
        // 1e6 ile çarpmak zaman damgalarını 1000x şişirir: her boşluk zaman
        // aşımını tetikler, hiçbir çevrim tamamlanmaz ve motor sessizce 0 tekrar
        // üretir. Ölçüm birimini VARSAYMAK, bu gecenin en pahalı hatasıydı.
        tUs: ((fr['t'] as num) * 1000).round(),
        landmarks: lm
            .map((dynamic p) => PoseLandmark(
                  ((p as List<dynamic>)[0] as num).toDouble(),
                  (p[1] as num).toDouble(),
                  (p[2] as num).toDouble(),
                  (p[3] as num).toDouble(),
                ))
            .toList(),
      ).toIsotropic(size);

      if (!judge(PoseFrame(tUs: 0, landmarks: lm
              .map((dynamic p) => PoseLandmark(
                  ((p as List<dynamic>)[0] as num).toDouble(), (p[1] as num).toDouble(),
                  (p[2] as num).toDouble(), (p[3] as num).toDouble())).toList()))) {
        judgeRej++;
        continue;
      }
      final StructuralCheck s = StructuralValidator().check(frame);
      if (!s.plausible) {
        structRej++;
        for (final StructuralFault fl in s.faults) {
          faults[fl.name] = (faults[fl.name] ?? 0) + 1;
        }
        continue;
      }
      final VisibleSide side = resolveVisibleSide(frame);
      final double? deg = extractor
          .extract(normalizer.normalize(frame))
          .degreesById(side.jointId('elbow'));
      if (deg == null || deg.isNaN) {
        angleNull++;
        continue;
      }
      pass++;
      angles.add(deg);
    }
    if (det == 0) continue;
    final String top = faults.isEmpty
        ? '-'
        : (faults.entries.toList()
              ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
                  b.value.compareTo(a.value)))
            .first
            .key;
    stdout.writeln('${f.uri.pathSegments.last.replaceAll('.full.json', '').padRight(14)}'
        '${det.toString().padLeft(8)}${judgeRej.toString().padLeft(11)}'
        '${structRej.toString().padLeft(12)}${angleNull.toString().padLeft(9)}'
        '${pass.toString().padLeft(7)}   $top');
    if (angles.isNotEmpty) {
      angles.sort();
      final int n = angles.length;
      final int above155 = angles.where((double a) => a >= 155).length;
      final int below100 = angles.where((double a) => a <= 100).length;
      stdout.writeln('    açı: min ${angles.first.toStringAsFixed(0)}° · '
          'medyan ${angles[n ~/ 2].toStringAsFixed(0)}° · maks ${angles.last.toStringAsFixed(0)}°'
          '  |  açık uç(≥155): $above155  kapalı uç(≤100): $below100');
    }
  }
}
