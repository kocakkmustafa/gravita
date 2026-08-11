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
/// 0,2 Pearson eşiği) AYRI bir motor işi (çekirdek kuyruğu, pencere-koşulu).
///
/// **`harvestIdentityAttested: true` BİLEREK verildi** (`rep_engine.dart`
/// belgesi: "HASAT yolu için açık dikiş... ÜRÜN yolunda ASLA true
/// verilmez"). Bu ÜRÜN yolu DEĞİL: bugünkü katalog `precondition.status:
/// pending` taşıyor ve motor M-F-122 hüküm 1 gereği (`refusalReason`,
/// `rep_engine.dart:197-205`) bunu FAIL-CLOSED reddediyor — dikiş
/// olmadan 30 dilimin hiçbiri tek kare bile işlenmeden atlanıyordu (ilk
/// koşum ÖLÇÜLDÜ). Dikiş burada MEŞRU çünkü malzemenin kimlik güvencesi
/// ÜRÜN ön koşulundan değil, take-düzeyi hasat-kimlik kapısından geliyor:
/// 30 dilimin hepsi `identity-triage.bodyweight_squat.json`de
/// `gate:"pass"` verilmiş kanallardan (12/16 eğitmen). Bu test o boşluğu
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
        final RepEngine e = RepEngine(config, harvestIdentityAttested: true);
        for (final PoseFrame f in repFrames(rep)) {
          e.addFrame(f, sizeOf(rep));
        }
        // ignore: avoid_print
        print('$takeId: repCount=${e.repCount} skipped=${e.skippedFrames}/'
            '${(rep['frames'] as List<dynamic>).length}');
        // ÖLÇÜLDÜ (2026-08-12, güven-kapısı düzeltmesinden SONRA): bu 30
        // dilimin HER biri tam 1 sayıyor. Bu artık bir tahmin değil, bir
        // KARAKTERİZASYON sınırı — kötüleşirse (motor bir dilimi bir daha
        // sayamazsa) burası KIRILIR, sessizce geçmez.
        expect(e.repCount, 1, reason: '$takeId artık 1 saymalı (ölçüldü)');
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
      final RepEngine e = RepEngine(config, harvestIdentityAttested: true);
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
    // ⚠️ Bu satır önceden "SAYIYI raporluyor, EŞİK sınamıyor" diyordu — o
    // gün ölçüm 0/30'du ve %100 beklemek İCAT olurdu. Güven-kapısı
    // düzeltmesinden SONRA ölçüm 30/30 — artık icat değil KAYITLI SONUÇ, ve
    // bu satırın işi o sonucu KORUMAK (`validate_library.py`nin
    // `replayFixture:missing` ölçütü de bu testin GEÇMESİNE bağlı, koordinatör
    // hükmü 2026-08-12 — "dosya var" tek başına yetmiyor).
    expect(agree, total,
        reason: 'UYUM $agree/$total — ölçülmüş taban 30/30, gerileme VAR');
  });

  group('NEGATİF KONTROL — 30/30 kanıt mı, sahte-oracle mı (koordinatör '
      'hükmü, 2026-08-12)', () {
    // ⭐ "30/30'da TAM 1" iki farklı şeyin sonucu olabilir: ① FSM gerçekten
    // her dilimde bir tekrar tanıyor ② FSM İÇERİĞE BAKMADAN 1 döndürüyor.
    // Dıştan ikisi BİREBİR aynı görünür (Choreia: "pozitif kontrol kendisinin
    // indiği doğrulanmadan kanıt değildir"). Bu grup GERÇEK veriyi BİLEREK
    // bozar ve 0 BEKLER — 0 gelirse üstteki 30/30 kanıttır, 1 gelirse
    // oracle sahtedir.
    final Map<String, dynamic> sample =
        reps.firstWhere((dynamic r) => (r as Map<String, dynamic>)['takeId']
            == 'K_boges_w0_r0') as Map<String, dynamic>;

    test('YARIM tekrar — dilim ortadan kesilirse rep TAMAMLANMAZ', () {
      final List<PoseFrame> full = repFrames(sample);
      final List<PoseFrame> half = full.sublist(0, full.length ~/ 2);
      final RepEngine e = RepEngine(config, harvestIdentityAttested: true);
      for (final PoseFrame f in half) {
        e.addFrame(f, sizeOf(sample));
      }
      // ignore: avoid_print
      print('YARIM ${sample['takeId']}: repCount=${e.repCount} '
          '(${half.length}/${full.length} kare)');
      expect(e.repCount, 0,
          reason: 'yarım bir iniş TAM tekrar sayılırsa oracle içeriğe '
              'bakmıyor demektir — bu, üstteki 30/30un kanıt DEĞERİNİ '
              'geçersiz kılar');
    });

    test('HAREKETSİZ — tek gerçek kare çoğaltılırsa faz geçişi HİÇ olmaz',
        () {
      final List<PoseFrame> full = repFrames(sample);
      final PoseFrame still = full[full.length ~/ 2];
      final RepEngine e = RepEngine(config, harvestIdentityAttested: true);
      for (int i = 0; i < full.length; i++) {
        // Aynı KARE, farklı zaman damgası — "video donmuş" senaryosu.
        e.addFrame(
            PoseFrame(tUs: still.tUs + i * 33000, landmarks: still.landmarks),
            sizeOf(sample));
      }
      // ignore: avoid_print
      print('HAREKETSİZ ${sample['takeId']}: repCount=${e.repCount}');
      expect(e.repCount, 0,
          reason: 'hareketsiz bir kare dizisi tekrar sayılırsa FSM zaman '
              'geçtiği için değil salınım gördüğü için sayıyor demektir '
              '(G-043in tam kendisi) — oracle sahte olurdu');
    });
  });
}
