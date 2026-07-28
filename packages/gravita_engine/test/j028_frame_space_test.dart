import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:motion_core/motion_core.dart';
import 'package:test/test.dart';

/// J-028 (aile kuralı M-F-30) — GERÇEK kare regresyonu.
///
/// Sentetik testler bu hatayı yakalayamaz: sentetik iskelet tek bir uzayda
/// üretilir, üretim ve ölçüm aynı çarpıklığı paylaşır, fark görünmez. Bu yüzden
/// motorun gerçek karelerle ≥1 regresyon testi taşıması zorunludur.
void main() {
  final Map<String, dynamic> fx = jsonDecode(
      File('test/fixtures/d1_correct_frames.json').readAsStringSync())
      as Map<String, dynamic>;
  final List<Map<String, dynamic>> frames =
      (fx['frames'] as List<dynamic>).cast<Map<String, dynamic>>();

  PoseFrame toFrame(Map<String, dynamic> f) => PoseFrame(
        tUs: 0,
        landmarks: (f['landmarks'] as List<dynamic>)
            .map((dynamic l) => PoseLandmark((l as List<dynamic>)[0] as double,
                l[1] as double, l[2] as double, l[3] as double))
            .toList(),
      );

  FrameSize sizeOf(Map<String, dynamic> f) {
    final Map<String, dynamic> s = f['frameSize'] as Map<String, dynamic>;
    return FrameSize(s['width'] as int, s['height'] as int);
  }

  /// Bağımsız referans: açıyı doğrudan PİKSEL uzayında hesapla.
  /// Motorun izotropik yolu bununla birebir uyuşmalı — izotropik ölçekleme
  /// tekdüze bir çarpandır, açıyı değiştirmez.
  double angleInPixels(PoseFrame f, FrameSize s, int a, int b, int c) {
    double px(int i) => f[i].x * s.width;
    double py(int i) => f[i].y * s.height;
    final double v1x = px(a) - px(b), v1y = py(a) - py(b);
    final double v2x = px(c) - px(b), v2y = py(c) - py(b);
    final double dot = v1x * v2x + v1y * v2y;
    final double n = math.sqrt(v1x * v1x + v1y * v1y) *
        math.sqrt(v2x * v2x + v2y * v2y);
    return math.acos(math.max(-1, math.min(1, dot / n))) * 180 / math.pi;
  }

  double angleOf(PoseFrame f, int a, int b, int c) {
    final double v1x = f[a].x - f[b].x, v1y = f[a].y - f[b].y;
    final double v2x = f[c].x - f[b].x, v2y = f[c].y - f[b].y;
    final double dot = v1x * v2x + v1y * v2y;
    final double n = math.sqrt(v1x * v1x + v1y * v1y) *
        math.sqrt(v2x * v2x + v2y * v2y);
    return math.acos(math.max(-1, math.min(1, dot / n))) * 180 / math.pi;
  }

  group('J-028 — kare uzayı', () {
    test('fixture kare boyutlarını taşıyor (yoksa test anlamsız)', () {
      expect(frames, isNotEmpty);
      for (final Map<String, dynamic> f in frames) {
        expect(f['frameSize'], isNotNull);
      }
      final Set<String> shapes = frames
          .map((Map<String, dynamic> f) => sizeOf(f).toString())
          .toSet();
      expect(shapes.length, greaterThan(5),
          reason: 'tek en-boy oranıyla bu hata görünmez');
    });

    test('izotropik dönüşüm açıyı KORUYOR — piksel uzayıyla 1e-6 uyum', () {
      for (final Map<String, dynamic> f in frames) {
        final PoseFrame raw = toFrame(f);
        final FrameSize s = sizeOf(f);
        final PoseFrame iso = raw.toIsotropic(s);
        for (final List<int> j in <List<int>>[
          <int>[Lm.leftShoulder, Lm.leftElbow, Lm.leftWrist],
          <int>[Lm.leftHip, Lm.leftKnee, Lm.leftAnkle],
          <int>[Lm.leftShoulder, Lm.leftHip, Lm.leftKnee],
        ]) {
          expect(angleOf(iso, j[0], j[1], j[2]),
              closeTo(angleInPixels(raw, s, j[0], j[1], j[2]), 1e-6));
        }
      }
    });

    test('HAM normalize uzay gerçekten bozuk — hata form eşiklerimiz kadar büyük',
        () {
      final List<double> deltas = <double>[];
      for (final Map<String, dynamic> f in frames) {
        final PoseFrame raw = toFrame(f);
        final FrameSize s = sizeOf(f);
        if (s.width == s.height) continue;
        final PoseFrame iso = raw.toIsotropic(s);
        deltas.add((angleOf(raw, Lm.leftShoulder, Lm.leftElbow, Lm.leftWrist) -
                angleOf(iso, Lm.leftShoulder, Lm.leftElbow, Lm.leftWrist))
            .abs());
      }
      deltas.sort();
      final double median = deltas[deltas.length ~/ 2];
      final double p90 = deltas[(deltas.length * 0.9).floor()];
      // ignore: avoid_print
      print('dirsek açısı sapması — medyan ${median.toStringAsFixed(2)}° · '
          'p90 ${p90.toStringAsFixed(2)}° · maks ${deltas.last.toStringAsFixed(2)}°');
      expect(median, greaterThan(1.0),
          reason: 'sapma yoksa ya fixture kare ya dönüşüm çalışmıyor');
      expect(p90, greaterThan(5.0),
          reason: 'form eşiklerimiz 12-45° bandında; p90 sapması bu düzeydeyse '
              'ham uzayda kalibre edilen her eşik yanlıştır');
    });

    test('kare görüntüde dönüşüm koordinatları DEĞİŞTİRMİYOR', () {
      // Çekirdek her zaman kopya döndürür (kimlik garantisi vermez); önemli
      // olan kare en-boyda değerlerin aynı kalması.
      final PoseFrame raw = toFrame(frames.first);
      final PoseFrame iso = raw.toIsotropic(const FrameSize(720, 720));
      for (int i = 0; i < Lm.count; i++) {
        expect(iso[i].x, closeTo(raw[i].x, 1e-12));
        expect(iso[i].y, closeTo(raw[i].y, 1e-12));
      }
    });
  });
}
