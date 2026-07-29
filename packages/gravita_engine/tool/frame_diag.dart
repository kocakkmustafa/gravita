import 'dart:convert';
import 'dart:io';

import 'package:motion_core/motion_core.dart';

/// "Kadraj dışı" reddi GERÇEK kırpılma mı, yoksa kapı hareketin ihtiyacından
/// fazlasını mı istiyor?
///
/// Güven kapısı hareket-agnostiktir: sabit bir landmark kümesini kadrajda arar.
/// Ama şınav için gereken şey omuz/dirsek/bilek/kalça/ayak — burun, kulak,
/// parmak uçları değil. Triyaj bu dersi zaten öğrenmişti (L-080, harekete-özel
/// `lower_body_ids`); güven kapısında aynı ders uygulanmamış olabilir.
void main(List<String> args) {
  // Şınavın measurementContract'ının gerçekten kullandığı landmark'lar.
  const List<int> needed = <int>[
    Lm.leftShoulder, Lm.rightShoulder, Lm.leftElbow, Lm.rightElbow,
    Lm.leftWrist, Lm.rightWrist, Lm.leftHip, Lm.rightHip,
    Lm.leftAnkle, Lm.rightAnkle,
  ];

  stdout.writeln('${'kaynak'.padRight(14)}${'algılanan'.padLeft(10)}'
      '${'33ü içeride'.padLeft(13)}${'GEREKLİ içeride'.padLeft(16)}'
      '${'gerekli+görünür'.padLeft(17)}');

  for (final File f in Directory(args[0])
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.json'))) {
    final Map<String, dynamic> fx =
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    int det = 0, allIn = 0, needIn = 0, needInVis = 0;
    for (final dynamic raw in fx['frames'] as List<dynamic>) {
      final Map<String, dynamic> fr = raw as Map<String, dynamic>;
      if (fr['detected'] != true) continue;
      final List<dynamic> lm = fr['lm'] as List<dynamic>;
      if (lm.length != Lm.count) continue;
      det++;
      bool inside(int i) {
        final List<dynamic> p = lm[i] as List<dynamic>;
        final double x = (p[0] as num).toDouble();
        final double y = (p[1] as num).toDouble();
        return x >= 0 && x <= 1 && y >= 0 && y <= 1;
      }

      bool visible(int i) => ((lm[i] as List<dynamic>)[3] as num) >= 0.5;

      if (List<int>.generate(Lm.count, (int i) => i).every(inside)) allIn++;
      if (needed.every(inside)) needIn++;
      if (needed.every((int i) => inside(i) && visible(i))) needInVis++;
    }
    if (det == 0) continue;
    stdout.writeln('${f.uri.pathSegments.last.replaceAll('.full.json', '').padRight(14)}'
        '${det.toString().padLeft(10)}'
        '${'${allIn * 100 ~/ det}%'.padLeft(13)}'
        '${'${needIn * 100 ~/ det}%'.padLeft(16)}'
        '${'${needInVis * 100 ~/ det}%'.padLeft(17)}');
  }
}
