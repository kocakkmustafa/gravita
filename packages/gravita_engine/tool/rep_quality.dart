import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;

import 'harvest_reps.dart' show mandatoryFor, requiredFor;

/// M-F-47 öncesi zorunlu adım: sayılan tekrarlar GERÇEKTEN o hareket mi?
///
/// `Rep.extremeAngleDeg` tek başına karşılaştırılamaz — çevrim hangi uçtan
/// başladıysa uç ONUN karşıtıdır (üstten başlayan çevrimde min, alttan
/// başlayanda maks). Aynı sütunda 8° ile 179° yan yana görünür ve bu bir
/// anlaşmazlık DEĞİL, iki farklı büyüklüğün aynı ada yazılmasıdır.
///
/// Dahası uç, çevrim boyunca görülen tek karelik min/maks'tır: 100 karelik bir
/// çevrimde bir tek bozuk kare ROM hükmünü zehirler. Bu araç her tekrarın TAM
/// açı izini çıkarır ve tepe değeri **yüzdelikle** (gürbüz) yeniden ölçer.
void main(List<String> args) {
  final Directory dir = Directory(args.isEmpty
      ? '${Platform.environment['HOME']}/motion-harvest/gravita/landmarks'
      : args[0]);
  final MovementConfig cfg = MovementConfig.parse(
      File('../../content/catalog/w1/push_up.json').readAsStringSync());
  const JointAngleExtractor extractor = JointAngleExtractor();

  final Set<int> mandatory = mandatoryFor(cfg).toSet();
  final List<int> all = requiredFor(cfg);
  bool judge(PoseFrame f) {
    int ok = 0;
    for (final int i in all) {
      final PoseLandmark l = f.landmarks[i];
      final bool good =
          l.x >= 0 && l.x <= 1 && l.y >= 0 && l.y <= 1 && l.visibility >= 0.5;
      if (!good && mandatory.contains(i)) return false;
      if (good) ok++;
    }
    return ok >= all.length - 2;
  }

  double pct(List<double> sorted, double p) =>
      sorted[((sorted.length - 1) * p).round()];

  final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];

  for (final File f in dir
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.json'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path))) {
    final Map<String, dynamic> fx =
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final Map<String, dynamic> meta = fx['recordingMeta'] as Map<String, dynamic>;
    final Map<String, dynamic> prov =
        (fx['provenance'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final List<String> wh =
        ((meta['resolution'] as String?) ?? '1920x1080').split('x');
    final FrameSize size = FrameSize(int.parse(wh[0]), int.parse(wh[1]));
    final PoseNormalizer normalizer = PoseNormalizer();

    // Kare akışı → pencereler (harvest_reps ile AYNI parametreler).
    const int maxGapUs = 2000000;
    final List<List<PoseFrame>> windows = <List<PoseFrame>>[];
    List<PoseFrame> cur = <PoseFrame>[];
    int lastUs = -1 << 40;
    for (final dynamic raw in fx['frames'] as List<dynamic>) {
      final Map<String, dynamic> fr = raw as Map<String, dynamic>;
      if (fr['detected'] != true) continue;
      final List<dynamic> lm = fr['lm'] as List<dynamic>;
      if (lm.length != Lm.count) continue;
      final PoseFrame pf = PoseFrame(
        tUs: ((fr['t'] as num) * 1000).round(),
        landmarks: lm
            .map((dynamic p) => PoseLandmark(
                  ((p as List<dynamic>)[0] as num).toDouble(),
                  (p[1] as num).toDouble(),
                  (p[2] as num).toDouble(),
                  (p[3] as num).toDouble(),
                ))
            .toList(),
      );
      if (!judge(pf)) continue;
      if (pf.tUs - lastUs > maxGapUs && cur.isNotEmpty) {
        windows.add(cur);
        cur = <PoseFrame>[];
      }
      cur.add(pf);
      lastUs = pf.tUs;
    }
    if (cur.isNotEmpty) windows.add(cur);

    final String src = f.uri.pathSegments.last.replaceAll('.full.json', '');
    for (final List<PoseFrame> w in windows) {
      // Motoru segmentasyon için kullan; açı izini AYNI zincirle ayrıca kaydet
      // (FSM mantığını burada KOPYALAMA — sapma riski).
      final RepEngine e = RepEngine(cfg, judge: judge);
      final List<({int tUs, double deg})> trace = <({int tUs, double deg})>[];
      for (final PoseFrame pf in w) {
        e.addFrame(pf, size);
        final PoseFrame iso = pf.toIsotropic(size);
        if (!StructuralValidator().check(iso).plausible) continue;
        final double? deg = extractor
            .extract(normalizer.normalize(iso))
            .degreesById(resolveVisibleSide(iso).jointId('elbow'));
        if (deg != null && !deg.isNaN) trace.add((tUs: pf.tUs, deg: deg));
      }
      for (final Rep r in e.reps) {
        final List<({int tUs, double deg})> inRep = trace
            .where((({int tUs, double deg}) t) =>
                t.tUs >= r.startUs && t.tUs <= r.endUs)
            .toList();
        final List<double> seg =
            inRep.map((({int tUs, double deg}) t) => t.deg).toList()..sort();
        if (seg.isEmpty) continue;

        // GÖRÜŞ GEÇERLİLİĞİ: 2B açı yalnız hareket düzlemi görüntü düzlemine
        // yakınsa anlamlıdır. Kameraya doğru uzanan bir kol projeksiyonda
        // kısalır ve açısı KEYFİ olur. İki gürbüz vekil:
        //  * omuz ayrımı / gövde boyu — yandan bakışta omuzlar üst üste biner,
        //    önden bakışta ayrılır.
        //  * ön kol / üst kol projeksiyon oranı — gerçekte benzer uzunluktalar,
        //    biri kısalmışsa o uzuv derinliğe kaçmıştır.
        final Set<int> tUsInRep =
            inRep.map((({int tUs, double deg}) t) => t.tUs).toSet();
        final List<double> sep = <double>[], armR = <double>[], tilt = <double>[];
        for (final PoseFrame pf in w.where((PoseFrame p) => tUsInRep.contains(p.tUs))) {
          final PoseFrame iso = pf.toIsotropic(size);
          final VisibleSide s = resolveVisibleSide(iso);
          double d(int a, int b) {
            final double dx = iso[a].x - iso[b].x, dy = iso[a].y - iso[b].y;
            return math.sqrt(dx * dx + dy * dy);
          }

          final double torso = (d(Lm.leftShoulder, Lm.leftHip) +
                  d(Lm.rightShoulder, Lm.rightHip)) /
              2;
          if (torso <= 0) continue;
          sep.add(d(Lm.leftShoulder, Lm.rightShoulder) / torso);
          final int sh = s == VisibleSide.left ? Lm.leftShoulder : Lm.rightShoulder;
          final int el = s == VisibleSide.left ? Lm.leftElbow : Lm.rightElbow;
          final int wr = s == VisibleSide.left ? Lm.leftWrist : Lm.rightWrist;
          final double upper = d(sh, el);
          if (upper > 0) armR.add(d(el, wr) / upper);

          // HAREKET KİMLİĞİ: şınavın gövdesi YATAYDIR. Ayakta konuşurken de
          // dirsek 155°↔100° arasında salınır (el hareketi, gösterim, kalkma) —
          // FSM bunu şınavdan ayırt EDEMEZ. Gövde eğimi ayırt eder.
          final double sx = (iso[Lm.leftShoulder].x + iso[Lm.rightShoulder].x) / 2;
          final double sy = (iso[Lm.leftShoulder].y + iso[Lm.rightShoulder].y) / 2;
          final double hx = (iso[Lm.leftHip].x + iso[Lm.rightHip].x) / 2;
          final double hy = (iso[Lm.leftHip].y + iso[Lm.rightHip].y) / 2;
          tilt.add(math.atan2((sy - hy).abs(), (sx - hx).abs()) * 180 / math.pi);
        }
        sep.sort();
        armR.sort();
        tilt.sort();

        out.add(<String, dynamic>{
          'source': src,
          'channel': prov['channel'],
          'frames': seg.length,
          'durS': (r.endUs - r.startUs) / 1e6,
          // GÜRBÜZ tepe değerler: tek kare değil, yüzdelik.
          'bottomP10': pct(seg, 0.10),
          'topP90': pct(seg, 0.90),
          'min': seg.first,
          'max': seg.last,
          'engineExtreme': r.extremeAngleDeg,
          'shoulderSep': sep.isEmpty ? null : pct(sep, 0.5),
          'armRatio': armR.isEmpty ? null : pct(armR, 0.5),
          'torsoTiltDeg': tilt.isEmpty ? null : pct(tilt, 0.5),
        });
      }
    }
  }

  stdout.writeln('${'kaynak'.padRight(14)}${'n'.padLeft(4)}'
      '${'süre-med'.padLeft(10)}${'ALT(p10) med'.padLeft(14)}'
      '${'ÜST(p90) med'.padLeft(14)}${'ham-min'.padLeft(9)}${'ham-maks'.padLeft(10)}');
  final Map<String, List<Map<String, dynamic>>> byS =
      <String, List<Map<String, dynamic>>>{};
  for (final Map<String, dynamic> r in out) {
    byS.putIfAbsent(r['source'] as String, () => <Map<String, dynamic>>[]).add(r);
  }
  double med(List<double> v) {
    v.sort();
    return v[v.length ~/ 2];
  }

  for (final MapEntry<String, List<Map<String, dynamic>>> e in byS.entries) {
    final List<Map<String, dynamic>> rs = e.value;
    stdout.writeln('${e.key.padRight(14)}${rs.length.toString().padLeft(4)}'
        '${'${med(rs.map((Map<String, dynamic> r) => r['durS'] as double).toList()).toStringAsFixed(1)}s'.padLeft(10)}'
        '${'${med(rs.map((Map<String, dynamic> r) => r['bottomP10'] as double).toList()).toStringAsFixed(0)}°'.padLeft(14)}'
        '${'${med(rs.map((Map<String, dynamic> r) => r['topP90'] as double).toList()).toStringAsFixed(0)}°'.padLeft(14)}'
        '${'${rs.map((Map<String, dynamic> r) => r['min'] as double).reduce((double a, double b) => a < b ? a : b).toStringAsFixed(0)}°'.padLeft(9)}'
        '${'${rs.map((Map<String, dynamic> r) => r['max'] as double).reduce((double a, double b) => a > b ? a : b).toStringAsFixed(0)}°'.padLeft(10)}');
  }

  File('../../content/harvest/rep-quality.push_up.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(out)}\n');
}
