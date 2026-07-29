import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;

/// G-075 TERS-ÇEVİRME PROBE'u — "kopyalama imzası" (M-F-141 hüküm 2).
///
/// Soru ters çevrildi. G-075'te üç probe da squat'ın 32,26° sol-sağ farkını
/// açıklayamadı. Yeni hipotez: asıl anormallik squat'ta DEĞİL, **push_up'ın
/// yalnız 5,16° oluşunda.** Yandan çekilmiş bir şınavda sol ve sağ uzuvlar
/// görüntüde neredeyse ÜST ÜSTE düşer; model UZAK uzvu göremediğinde yakın
/// uzvun değerini kopyalamaya/yansıtmaya meyilli olabilir (J-056'nın
/// "görünmeyen eklem için de sayı üretiyor" bulgusunun kardeşi). Öyleyse
/// push_up'ın küçük farkı bir SİMETRİ KANITI değil, MODEL KÖRLÜĞÜNÜN eseri.
///
/// **Koordinatörün belirlediği imza (betimsel, EŞİKSİZ, KAPISIZ):**
/// kopyalama imzası GÖRÜNÜRLÜK-KOŞULLU |L−R|'dir.
///   • |L−R| görünürlük DÜŞTÜKÇE KÜÇÜLÜYORSA → imza POZİTİF: fark tam model
///     göremezken kayboluyor, yani o "anlaşma" ÜRETİLMİŞTİR.
///   • Dürüst ölçümde fark görünürlük düşerken BÜYÜR ya da gürültüyle sabit
///     kalır (belirsizlik arttıkça uyum artmaz).
///
/// ⚠️ **METODOLOJİK BEYAN — görünürlük kapısı KASITLI UYGULANMADI.**
/// Kanonik `ReferenceCli.prepareTake` düşük-görünürlüklü kareleri eler ve
/// düşük-görünürlüklü açıları NaN'a çeker (J-056 düzeltmesi, ÜRÜN için
/// DOĞRU). Ama bu probe tam olarak O KARELERİ inceliyor — kapıyı uygulamak
/// ölçmek istediğimiz rejimi silerdi. Bu yüzden açı çıkarımı kanonik
/// `JointAngleExtractor`+`PoseNormalizer` ile yapılır (formül aynı, kopya
/// yok) ama görünürlük-NaN kapısı ATLANIR. Buradan ÜRÜN hükmü çıkmaz;
/// çıktı yalnız kanıt-okuma sorusunu yanıtlar.
void main(List<String> args) {
  final Map<String, Directory> pools = <String, Directory>{
    'push_up': Directory('${Platform.environment['HOME']}'
        '/motion-harvest/gravita/landmarks'),
    'bodyweight_squat': Directory('${Platform.environment['HOME']}'
        '/motion-harvest/gravita-squat/landmarks-rep-sliced'),
  };

  const JointAngleExtractor extractor =
      JointAngleExtractor(specs: StandardJoints.fullBody);
  final PoseNormalizer normalizer = PoseNormalizer();

  // Görünürlük bantları — İCAT EDİLMİŞ EŞİK DEĞİL, betimsel histogram kovaları.
  const List<double> edges = <double>[0.0, 0.2, 0.4, 0.6, 0.8, 1.01];

  final Map<String, dynamic> report = <String, dynamic>{
    r'$probe': 'copying signature: visibility-conditioned |left-right| joint '
        'angle difference (M-F-141 hüküm 2)',
    r'$signature': 'If |L-R| SHRINKS as far-limb visibility DROPS, the '
        'agreement is MANUFACTURED (model copies the near limb). Honest '
        'measurement: difference GROWS or stays noisy-flat as visibility '
        'drops.',
    r'$visibilityGateDeliberatelyOff': 'Kanonik prepareTake düşük-görünürlüklü '
        'kareleri eler / açıları NaN yapar (J-056, ÜRÜN için doğru). Bu probe '
        'tam o rejimi inceliyor, bu yüzden kapı ATLANDI. Ürün hükmü çıkmaz.',
    r'$bands': edges,
    'movements': <String, dynamic>{},
  };

  for (final MapEntry<String, Directory> pool in pools.entries) {
    final String movement = pool.key;
    if (!pool.value.existsSync()) {
      stdout.writeln('⚠️ $movement havuzu yok: ${pool.value.path}');
      continue;
    }

    // bant -> (|L-R| toplamı, sayı) ve ayrıca world-z ayrımı (tamamlayıcı).
    final List<double> diffSum = List<double>.filled(edges.length - 1, 0);
    final List<int> diffN = List<int>.filled(edges.length - 1, 0);
    final List<double> dzSum = List<double>.filled(edges.length - 1, 0);
    final List<int> dzN = List<int>.filled(edges.length - 1, 0);

    int band(double v) {
      for (int i = 0; i < edges.length - 1; i++) {
        if (v >= edges[i] && v < edges[i + 1]) return i;
      }
      return edges.length - 2;
    }

    for (final File f in pool.value
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.endsWith('.json'))
        .toList()
      ..sort((File a, File b) => a.path.compareTo(b.path))) {
      final Map<String, dynamic> fx =
          jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final Map<String, dynamic> meta =
          fx['recordingMeta'] as Map<String, dynamic>;
      final String res = (meta['resolution'] as String?) ?? '1920x1080';
      final List<String> wh = res.split('x');
      final FrameSize size = FrameSize(int.parse(wh[0]), int.parse(wh[1]));

      for (final dynamic rawFr in fx['frames'] as List<dynamic>) {
        final Map<String, dynamic> fr = rawFr as Map<String, dynamic>;
        if (fr['detected'] != true) continue;
        final List<dynamic>? lm = fr['lm'] as List<dynamic>?;
        if (lm == null || lm.length != Lm.count) continue;

        final List<PoseLandmark> marks = lm
            .map((dynamic p) => PoseLandmark(
                  ((p as List<dynamic>)[0] as num).toDouble(),
                  (p[1] as num).toDouble(),
                  (p[2] as num).toDouble(),
                  (p[3] as num).toDouble(),
                ))
            .toList();
        final PoseFrame pf = PoseFrame(
          tUs: ((fr['t'] as num) * 1000).round(),
          modelVersion: fx['modelVersion'] as String,
          landmarks: marks,
        );

        // Kanonik açı yolu (izotropik + normalize + extract) — görünürlük
        // NaN kapısı UYGULANMIYOR (yukarıdaki beyan).
        final JointAngleVector v =
            extractor.extract(normalizer.normalize(pf.toIsotropic(size)));

        for (final JointSpec s in v.specs) {
          if (!s.id.startsWith('left_')) continue;
          final String rightId = s.id.replaceFirst('left_', 'right_');
          final double? a = v.byId(s.id);
          final double? b = v.byId(rightId);
          if (a == null || b == null) continue;
          final JointSpec? rs =
              v.specs.where((JointSpec x) => x.id == rightId).firstOrNull;
          if (rs == null) continue;

          // UZAK uzuv = görünürlüğü DAHA DÜŞÜK olan taraf (kendini tanımlar;
          // hangi tarafın kameraya yakın olduğunu varsaymaya gerek yok).
          double minVis(JointSpec spec) {
            double m = 1.0;
            for (final int i in spec.requiredLandmarks) {
              if (i < 0 || i >= marks.length) continue;
              m = math.min(m, marks[i].visibility);
            }
            return m;
          }

          final double farVis = math.min(minVis(s), minVis(rs));
          final int bi = band(farVis);
          diffSum[bi] += math.atan2(math.sin(a - b), math.cos(a - b)).abs() *
              180 /
              math.pi;
          diffN[bi]++;
        }

        // Tamamlayıcı: yakın/uzak uzuv world-z ayrımı, görünürlük-koşullu.
        final List<dynamic>? world = fr['world'] as List<dynamic>?;
        if (world != null && world.length == Lm.count) {
          const List<List<int>> zPairs = <List<int>>[
            <int>[23, 24], <int>[25, 26], <int>[27, 28],
          ];
          for (final List<int> pr in zPairs) {
            final double vis =
                math.min(marks[pr[0]].visibility, marks[pr[1]].visibility);
            final double zl =
                ((world[pr[0]] as List<dynamic>)[2] as num).toDouble();
            final double zr =
                ((world[pr[1]] as List<dynamic>)[2] as num).toDouble();
            final int bi = band(vis);
            dzSum[bi] += (zl - zr).abs();
            dzN[bi]++;
          }
        }
      }
    }

    stdout.writeln('\n== $movement ==');
    stdout.writeln('${'uzak-uzuv görünürlük bandı'.padRight(28)} '
        '${'|L−R|°'.padLeft(9)} ${'n'.padLeft(9)}   ${'|Δz|'.padLeft(8)}');
    final List<Map<String, dynamic>> bands = <Map<String, dynamic>>[];
    for (int i = 0; i < edges.length - 1; i++) {
      final double? d = diffN[i] == 0 ? null : diffSum[i] / diffN[i];
      final double? z = dzN[i] == 0 ? null : dzSum[i] / dzN[i];
      bands.add(<String, dynamic>{
        'band': '${edges[i].toStringAsFixed(1)}-${edges[i + 1] == 1.01 ? "1.0" : edges[i + 1].toStringAsFixed(1)}',
        'meanAbsLeftRightDeg': d == null ? null : double.parse(d.toStringAsFixed(2)),
        'samples': diffN[i],
        'meanAbsWorldZGap': z == null ? null : double.parse(z.toStringAsFixed(4)),
        'zSamples': dzN[i],
      });
      stdout.writeln('${bands[i]['band'].toString().padRight(28)} '
          '${(d == null ? "—" : d.toStringAsFixed(2)).padLeft(9)} '
          '${diffN[i].toString().padLeft(9)}   '
          '${(z == null ? "—" : z.toStringAsFixed(4)).padLeft(8)}');
    }

    // İmza okuması: en DÜŞÜK ile en YÜKSEK dolu bandı karşılaştır.
    final List<Map<String, dynamic>> filled = bands
        .where((Map<String, dynamic> b) => (b['samples'] as int) >= 100)
        .toList();
    String reading;
    if (filled.length < 2) {
      reading = 'ölçülemedi (yeterli dolu bant yok)';
    } else {
      final double lo = filled.first['meanAbsLeftRightDeg'] as double;
      final double hi = filled.last['meanAbsLeftRightDeg'] as double;
      final String dir = lo < hi ? 'KÜÇÜLÜYOR' : 'BÜYÜYOR';
      reading = 'görünürlük düşerken |L−R| $dir '
          '(en düşük bant ${lo.toStringAsFixed(2)}° · '
          'en yüksek bant ${hi.toStringAsFixed(2)}°) → '
          '${lo < hi ? "KOPYALAMA İMZASI POZİTİF: fark tam model göremezken "
              "kayboluyor, anlaşma ÜRETİLMİŞ olabilir"
              : "imza NEGATİF: fark belirsizlikte büyüyor, dürüst ölçüm "
                  "davranışı"}';
    }
    stdout.writeln('okuma: $reading');
    (report['movements'] as Map<String, dynamic>)[movement] =
        <String, dynamic>{'bands': bands, 'reading': reading};
  }

  File('../../content/harvest/copying-signature.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n');
  stdout.writeln('\nyazıldı: content/harvest/copying-signature.json');
}
