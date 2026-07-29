import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;

import 'harvest_reps.dart' show mandatoryFor, requiredFor;

/// G-064 diferansiyel testi (koordinatör M-F-92, Lissom L-154 sonrası):
/// Gravita'nın taraf-agnostik/düz-izotropik hipKneeCoupling formülü ↔
/// Lissom'un DÜZELTİLMİŞ formülü (mocore `geometry.body_axes(mode:
/// proximal)` + `measures.evaluate(anatomical: true)`) aynı squat
/// fixture'larında YAN YANA.
///
/// Lissom formülü (mocore/geometry.py + measures.py'den BİREBİR taşındı):
///  * hip_flexion_right: RIGHT_SHOULDER-RIGHT_HIP-RIGHT_KNEE, `sagittal`
///    düzleme, `proximal` gövde eksenine (kalça-ortası→omuz-ortası, WORLD
///    3D) izdüşürülerek. `frameRef=proximal` — küresel eklem, gövde eğilince
///    uzvun sagittal düzlemi de eğilir.
///  * knee_flexion_right: RIGHT_HIP-RIGHT_KNEE-RIGHT_ANKLE, `frameRef=none`
///    — menteşe eklem, izdüşüm YOK, doğrudan 3D açı (WORLD koordinatı).
///
/// Gravita formülü: `MovementMetrics.hipAngle`/`kneeAngle` — GÖRÜNEN taraf
/// (ADR-003), düz izotropik 2D açı (image-plane, world DEĞİL).
///
/// ⚠️ İKİ FARK BİRDEN test ediliyor (taraf-seçimi: görünen vs sabit-right +
/// çerçeve: düz-izotropik-2D vs proximal-projeksiyonlu-3D) — hangisinin daha
/// çok etkilediği bu testte AYRIŞTIRILMIYOR, koordinatörün istediği "üç-yönlü
/// yan yana" kıyas bu.
void main(List<String> args) {
  final Directory dir = Directory(args.isEmpty
      ? '${Platform.environment['HOME']}/motion-harvest/gravita-squat/landmarks'
      : args[0]);
  const String movementId = 'bodyweight_squat';

  // Koordinatörün "3-5 ortak fixture" isteği: gate sonucu yayılımını temsil
  // eden 5 eğitmen (G-064 tablosundan) — temiz/yüksek-r, sınırda-geçen,
  // reddedilen, en zengin-n, kneeSymmetry-şüpheli.
  const Set<String> selected = <String>{
    'WeShape', 'Tom Merrick', 'TappBrothers', 'K boges', 'Squat University',
  };

  final File cfgFile = File('../../content/catalog/w1/$movementId.json');
  final MovementConfig cfg = MovementConfig.parse(cfgFile.readAsStringSync());
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

  // MediaPipe standart indeksleri (Lissom formülü sabit-right kullanıyor).
  const int lShoulder = 11, rShoulder = 12;
  const int lHip = 23, rHip = 24;
  const int rKnee = 26, rAnkle = 28;

  double norm(List<double> v) =>
      math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
  List<double> sub(List<double> a, List<double> b) =>
      <double>[a[0] - b[0], a[1] - b[1], a[2] - b[2]];
  List<double> add(List<double> a, List<double> b) =>
      <double>[a[0] + b[0], a[1] + b[1], a[2] + b[2]];
  List<double> scale(List<double> a, double s) =>
      <double>[a[0] * s, a[1] * s, a[2] * s];
  double dot(List<double> a, List<double> b) =>
      a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
  List<double> cross(List<double> a, List<double> b) => <double>[
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
      ];
  List<double> normalize(List<double> a) {
    final double n = norm(a);
    return n < 1e-9 ? a : scale(a, 1 / n);
  }

  // geometry.py body_axes(mode:"proximal") — satırlar [ML, SI, AP].
  ({List<double> ml, List<double> si, List<double> ap})? bodyAxesProximal(
      List<List<double>> w) {
    final List<double> ml0 =
        add(sub(w[rShoulder], w[lShoulder]), sub(w[rHip], w[lHip]));
    final List<double> midSh =
        scale(add(w[lShoulder], w[rShoulder]), 0.5);
    final List<double> midHip = scale(add(w[lHip], w[rHip]), 0.5);
    List<double> si = sub(midSh, midHip);
    if (norm(si) < 1e-9) return null;
    si = normalize(si);
    if (norm(ml0) < 1e-9) return null;
    // Gram-Schmidt: ml'yi si'ye dik hale getir.
    List<double> ml = sub(ml0, scale(si, dot(ml0, si)));
    if (norm(ml) < 1e-9) return null;
    ml = normalize(ml);
    final List<double> ap = cross(si, ml);
    return (ml: ml, si: si, ap: ap);
  }

  // project(v, "sagittal", axes) — ML bileşenini (axes satır 0) sıfırla.
  List<double> projectSagittal(
      List<double> v, ({List<double> ml, List<double> si, List<double> ap}) axes) {
    // sagittal düzlem = ML bileşenini sıfırla, SI+AP alt-uzayında geri kur
    // (mocore geometry.project, drop=0).
    final double compSi = dot(v, axes.si);
    final double compAp = dot(v, axes.ap);
    final List<double> out = <double>[0, 0, 0];
    for (int k = 0; k < 3; k++) {
      out[k] = compSi * axes.si[k] + compAp * axes.ap[k];
    }
    return out;
  }

  double angleBetween(List<double> a, List<double> b) {
    final double n = norm(a) * norm(b);
    if (n < 1e-9) return double.nan;
    final double c = (dot(a, b) / n).clamp(-1.0, 1.0);
    return math.acos(c) * 180 / math.pi;
  }

  double angle3ptDirect(List<double> a, List<double> b, List<double> c) =>
      angleBetween(sub(a, b), sub(c, b));

  final Map<String, List<double>> gHip = <String, List<double>>{};
  final Map<String, List<double>> gKnee = <String, List<double>>{};
  final Map<String, List<double>> lHipFlex = <String, List<double>>{};
  final Map<String, List<double>> lKneeFlex = <String, List<double>>{};

  for (final File f in dir
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.json'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path))) {
    final Map<String, dynamic> fx =
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final Map<String, dynamic> prov =
        (fx['provenance'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final String channel = (prov['channel'] as String?) ?? '?';
    if (!selected.contains(channel)) continue;

    final Map<String, dynamic> meta = fx['recordingMeta'] as Map<String, dynamic>;
    final List<String> wh =
        ((meta['resolution'] as String?) ?? '1280x720').split('x');
    final FrameSize size =
        FrameSize(int.parse(wh[0]), int.parse(wh.length > 1 ? wh[1] : wh[0]));

    // t(ms)->world dizisi eşlemesi: raw frame listesini indeksle tarayacağız
    // (RepEngine'e verilen PoseFrame listesiyle AYNI sırada).
    const int maxGapUs = 2000000;
    final List<List<({PoseFrame pf, List<dynamic>? world})>> windows =
        <List<({PoseFrame pf, List<dynamic>? world})>>[];
    List<({PoseFrame pf, List<dynamic>? world})> cur =
        <({PoseFrame pf, List<dynamic>? world})>[];
    int lastUs = -1 << 40;
    for (final dynamic raw in fx['frames'] as List<dynamic>) {
      final Map<String, dynamic> fr = raw as Map<String, dynamic>;
      if (fr['detected'] != true) continue;
      final List<dynamic> lm = fr['lm'] as List<dynamic>;
      if (lm.length != Lm.count) continue;
      final PoseFrame pf = PoseFrame(
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
      );
      if (!judge(pf)) continue;
      if (pf.tUs - lastUs > maxGapUs && cur.isNotEmpty) {
        windows.add(cur);
        cur = <({PoseFrame pf, List<dynamic>? world})>[];
      }
      cur.add((pf: pf, world: fr['world'] as List<dynamic>?));
      lastUs = pf.tUs;
    }
    if (cur.isNotEmpty) windows.add(cur);

    for (final List<({PoseFrame pf, List<dynamic>? world})> w in windows) {
      final RepEngine e = RepEngine(cfg, judge: judge);
      final StructuralValidator sv = StructuralValidator();
      final List<({int tUs, double gh, double gk, double? lh, double? lk})>
          trace = <({int tUs, double gh, double gk, double? lh, double? lk})>[];
      for (final ({PoseFrame pf, List<dynamic>? world}) t in w) {
        e.addFrame(t.pf, size);
        final PoseFrame iso = t.pf.toIsotropic(size);
        if (!sv.check(iso).plausible) continue;
        final MovementMetrics m = MovementMetrics.of(iso);
        double? lh, lk;
        if (t.world != null && t.world!.length == Lm.count) {
          final List<List<double>> wpts = t.world!
              .map((dynamic p) => (p as List<dynamic>)
                  .cast<num>()
                  .take(3)
                  .map((num n) => n.toDouble())
                  .toList())
              .toList();
          final axes = bodyAxesProximal(wpts);
          if (axes != null) {
            // A-B-C = RIGHT_SHOULDER-RIGHT_HIP-RIGHT_KNEE; BA/BC hip (B)
            // merkezli, sagittal düzleme izdüşürülür (mocore angle_3pt_projected).
            final List<double> ba = projectSagittal(
                sub(wpts[rShoulder], wpts[rHip]), axes);
            final List<double> bc =
                projectSagittal(sub(wpts[rKnee], wpts[rHip]), axes);
            lh = angleBetween(ba, bc);
          }
          lk = angle3ptDirect(wpts[rHip], wpts[rKnee], wpts[rAnkle]);
        }
        trace.add((tUs: t.pf.tUs, gh: m.hipAngle, gk: m.kneeAngle, lh: lh, lk: lk));
      }
      for (final Rep r in e.reps) {
        for (final ({int tUs, double gh, double gk, double? lh, double? lk}) t
            in trace) {
          if (t.tUs < r.startUs || t.tUs > r.endUs) continue;
          if (!t.gh.isNaN && !t.gk.isNaN) {
            gHip.putIfAbsent(channel, () => <double>[]).add(t.gh);
            gKnee.putIfAbsent(channel, () => <double>[]).add(t.gk);
          }
          if (t.lh != null && t.lk != null && !t.lh!.isNaN && !t.lk!.isNaN) {
            lHipFlex.putIfAbsent(channel, () => <double>[]).add(t.lh!);
            lKneeFlex.putIfAbsent(channel, () => <double>[]).add(t.lk!);
          }
        }
      }
    }
  }

  double pearson(List<double> xs, List<double> ys) {
    final int n = xs.length;
    if (n < 3) return double.nan;
    final double mx = xs.reduce((a, b) => a + b) / n;
    final double my = ys.reduce((a, b) => a + b) / n;
    double cov = 0, vx = 0, vy = 0;
    for (int i = 0; i < n; i++) {
      final double dx = xs[i] - mx, dy = ys[i] - my;
      cov += dx * dy;
      vx += dx * dx;
      vy += dy * dy;
    }
    if (vx <= 0 || vy <= 0) return double.nan;
    return cov / math.sqrt(vx * vy);
  }

  stdout.writeln('== G-064 diferansiyel testi: Gravita (taraf-agnostik/2D) '
      'vs Lissom-düzeltilmiş (proximal/3D, anatomical=true) ==\n');
  stdout.writeln('${"eğitmen".padRight(20)}${"n(G)".padLeft(7)}'
      '${"r(Gravita)".padLeft(13)}${"n(L)".padLeft(7)}${"r(Lissom-düz)".padLeft(15)}');
  for (final String ch in selected) {
    final double rG = gHip.containsKey(ch)
        ? pearson(gHip[ch]!, gKnee[ch]!)
        : double.nan;
    final double rL = lHipFlex.containsKey(ch)
        ? pearson(lHipFlex[ch]!, lKneeFlex[ch]!)
        : double.nan;
    stdout.writeln('${ch.padRight(20)}'
        '${(gHip[ch]?.length ?? 0).toString().padLeft(7)}'
        '${rG.toStringAsFixed(3).padLeft(13)}'
        '${(lHipFlex[ch]?.length ?? 0).toString().padLeft(7)}'
        '${rL.toStringAsFixed(3).padLeft(15)}');
  }
}
