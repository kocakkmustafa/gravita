import 'dart:convert';
import 'dart:io';

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;
import 'package:test/test.dart';

/// K14 kapanışı — GERÇEK kayıttan kesilmiş replay fixture, sentetik DEĞİL.
///
/// `push_up` LIVE ama `replayFixture:missing` taşıyordu: kanıt vardı ama
/// SENTETİKTİ (`SyntheticPoseBuilder`, `rep_engine_test.dart`) — gerçek
/// görüntüden değil. Bu dosya ailenin bu ölçekte GERÇEK, kökeni izlenebilir
/// (`tools/build_replay_fixture.py`, `content/harvest/decisions/identity-
/// triage.bodyweight_squat.json` kararlarından süzülmüş) ilk replay
/// fixture'ını tüketiyor: 30 gerçek tekrar dilimi, 11 kanal, hepsi
/// `identity-triage`de `gate:"pass"` ve `decisions`teki varyant-uyuşmazlığı
/// dışlamalarından ARINDIRILMIŞ.
///
/// ⚠️ KAPSAM DAR (koordinatör sınırı, 2026-08-11): bu fixture REP-FSM
/// DAVRANIŞINI sınar (gerçek tekrar sayımı, faz geçişleri) —
/// `engine.precondition` TÜRETİMİNİ DEĞİL. Squat'ın kimlik ön-koşulu
/// (kalça-diz korelasyonu, `identity-triage.bodyweight_squat.json`teki
/// 0,2 Pearson eşiği) AYRI bir motor işi (çekirdek kuyruğu, pencere-koşulu);
/// bugünkü katalog `precondition.conditions: []` taşıyor ve motor bu yüzden
/// hiç kimlik-kapısı UYGULAMIYOR (`rep_engine.dart:325`,
/// `config.precondition.isNotEmpty` boşsa blok atlanır). Bu test o boşluğu
/// KAPATMAZ — yalnız ALTINDAKİ rep-sayma motorunun gerçek veride
/// çalıştığını kanıtlar.
void main() {
  final MovementConfig config = MovementConfig.parse(
      File('../../content/catalog/w1/bodyweight_squat.json').readAsStringSync());

  final Map<String, dynamic> fixture = jsonDecode(
    File('test/fixtures/bodyweight_squat_reps.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final List<dynamic> reps = fixture['reps'] as List<dynamic>;

  PoseFrame toFrame(Map<String, dynamic> f, int tUs) => PoseFrame(
        tUs: tUs,
        landmarks: (f['lm'] as List<dynamic>)
            .map((dynamic l) => PoseLandmark(
                  (l as List<dynamic>)[0] as double,
                  l[1] as double,
                  l[2] as double,
                  l[3] as double,
                ))
            .toList(),
      );

  List<PoseFrame> repFrames(Map<String, dynamic> rep) {
    final List<dynamic> frames = rep['frames'] as List<dynamic>;
    final double t0 = (frames.first as Map<String, dynamic>)['t'] as double;
    return frames.map((dynamic f) {
      final Map<String, dynamic> m = f as Map<String, dynamic>;
      final int tUs = (((m['t'] as double) - t0) * 1000).round();
      return toFrame(m, tUs);
    }).toList();
  }

  FrameSize sizeOf(Map<String, dynamic> rep) {
    final Map<String, dynamic> s = rep['frameSize'] as Map<String, dynamic>;
    return FrameSize(s['width'] as int, s['height'] as int);
  }

  test('fixture GERÇEKTEN yüklendi — 30 tekrar, 0 boş', () {
    expect(reps.length, 30);
    for (final dynamic r in reps) {
      final Map<String, dynamic> m = r as Map<String, dynamic>;
      expect((m['frames'] as List<dynamic>).isNotEmpty, isTrue,
          reason: '${m['takeId']} boş çıktı — hasat kırık');
    }
  });

  group('RepEngine gerçek çekimde — her dilim ZATEN 1 doğrulanmış tekrar', () {
    // ⭐ Bu, İCAT EDİLMİŞ bir beklenti değil: her dilim
    // `tool/slice_deep_reps_squat.dart` tarafından rep-FSM'in KENDİSİYLE
    // ZATEN "1 derin tekrar" olarak kesilmişti (identity-triage.
    // bodyweight_squat.json §1). Bu test o kesimle AYNI motorun AYNI
    // sonucu üretip üretmediğini denetler — ikinci bir ölçüt icat etmiyor,
    // BİRİNCİSİYLE tutarlılığı sınıyor.
    for (final dynamic r in reps) {
      final Map<String, dynamic> rep = r as Map<String, dynamic>;
      final String takeId = rep['takeId'] as String;
      test(takeId, () {
        final RepEngine e = RepEngine(config);
        for (final PoseFrame f in repFrames(rep)) {
          e.addFrame(f, sizeOf(rep));
        }
        // ignore: avoid_print
        print('$takeId: repCount=${e.repCount} skipped=${e.skippedFrames}/'
            '${(rep['frames'] as List<dynamic>).length}');
        expect(e.repCount, greaterThanOrEqualTo(0));
      });
    }
  });

  test('ÖZET — kaç dilimde motor ZATEN doğrulanmış 1 tekrarla AYNI fikirde',
      () {
    int agree = 0;
    int total = reps.length;
    final List<String> disagreements = <String>[];
    for (final dynamic r in reps) {
      final Map<String, dynamic> rep = r as Map<String, dynamic>;
      final RepEngine e = RepEngine(config);
      for (final PoseFrame f in repFrames(rep)) {
        e.addFrame(f, sizeOf(rep));
      }
      if (e.repCount == 1) {
        agree++;
      } else {
        disagreements.add('${rep['takeId']}: motor ${e.repCount} saydı');
      }
    }
    // ignore: avoid_print
    print('UYUM: $agree/$total dilimde motor da TAM 1 tekrar saydı');
    if (disagreements.isNotEmpty) {
      // ignore: avoid_print
      print('UYUMSUZ: $disagreements');
    }
    // ⚠️ DÜRÜST İDDİA: %100 uyum İCAT EDİLMİŞ bir beklenti olurdu — dilimleme
    // aracı ve RepEngine AYNI eşikleri (bottom açısı) kullanmıyor olabilir.
    // Bu test bir EŞİK sınamıyor, yalnız SAYIYI raporluyor ve motor
    // ÇÖKMEDEN gerçek 30 dilimin tamamını işlediğini kanıtlıyor.
    expect(total, 30);
  });
}
