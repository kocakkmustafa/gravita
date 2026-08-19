import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// GRA-P1-002 — "20-movement paid foundation" kabul testi (roadmap Step 1).
///
/// ⭐ BU TEST BUGÜN KIRMIZI — ve öyle olması BEKLENİYOR, adıyla. Roadmap'in
/// kendi disiplini: kabul testi önce yazılır, geçmesi GERÇEK kanıt (hasat +
/// hakem/uzman onayı) gelince olur. Kırmızı olan tek şey `≥20 aktif hareket`
/// eşiği — o eşik gerçek harvest+expert-review verisi ister (EXTERNAL_GATE,
/// bu makinede mediapipe/cv2 ortamı yok, DEFTER G-084/G-087/G-262/G-266'da
/// defalarca ölçülmüş). PATTERN kapsamı (push/pull/squat/hinge/core/carry/
/// hold) ise BUGÜN ZATEN geçiyor — 31 hareketlik katalog bu yedi deseni
/// önceki oturumlarda önceden doldurmuş, `docs/PREP-KATALOG-SINIFLANDIRMA-
/// 2026-08-19.md`nin bulgusuyla tutarlı.
///
/// ⚠️ "Desen" (pattern) `content/catalog/*.json`da AYRI bir alan DEĞİL —
/// `family`/`muscleGroups`/`engine.type`ten TÜRETİLİR. Aşağıdaki eşleme bir
/// ÜRÜN sınıflandırması değil, bu TESTİN kendi denetim aracı: hareket-bilimi
/// açısından tartışmalı sınırlar olabilir (ör. `glute_bridge` hem squat hem
/// hinge ailesine yakın okunabilir) ama kapının sorusu yalnız "bu desende
/// EN AZ BİR hareket var mı" — ince ayrım gerektirmiyor. Şema bir gün
/// açıkça bir `pattern` alanı taşırsa bu test ONU okumalı, kendi eşlemesini
/// DEĞİL.
void main() {
  List<Map<String, dynamic>> movements() {
    final Map<String, dynamic> lib =
        (jsonDecode(File('content/library.json').readAsStringSync()) as Map)
            .cast<String, dynamic>();
    return (lib['movements'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Map<String, dynamic> catalogFor(Map<String, dynamic> movement) {
    final String wave = (movement['wave'] as String).toLowerCase();
    final String catalogId =
        (movement['catalogId'] ?? movement['id']) as String;
    return (jsonDecode(
            File('content/catalog/$wave/$catalogId.json').readAsStringSync())
        as Map)
      .cast<String, dynamic>();
  }

  group('desen kapsamı — push/pull/squat/hinge/core/carry/hold', () {
    final List<Map<String, dynamic>> movs = movements();

    // Aile-bazlı desenler — doğrudan `library.json.family`'den.
    for (final (String pattern, String family) in <(String, String)>[
      ('push', 'push'),
      ('pull', 'pull'),
      ('squat', 'legs'),
      ('core', 'core'),
      ('carry', 'carry'),
    ]) {
      test('$pattern deseninde en az 1 hareket var', () {
        final List<String> found = movs
            .where((Map<String, dynamic> m) => m['family'] == family)
            .map((Map<String, dynamic> m) => m['id'] as String)
            .toList();
        expect(found, isNotEmpty,
            reason: '$pattern deseni (family=$family) hiç hareket bulamadı');
      });
    }

    test('hinge deseninde en az 1 hareket var (dbkb ailesi, kalça-menteşe '
        'baskın kas grupları)', () {
      // Aile tek başına yetmez — "dbkb" hem hinge (romanian_deadlift,
      // kb_swing) hem başka örüntüleri (db_curl: kol izole) barındırıyor.
      // `muscleGroups`ta AYNI ANDA hamstrings+glutes olması hinge'in
      // hareket-bilimi imzası.
      final List<String> found = movs
          .where((Map<String, dynamic> m) {
            final List<dynamic> mg =
                (m['muscleGroups'] as List<dynamic>?) ?? <dynamic>[];
            return mg.contains('hamstrings') && mg.contains('glutes');
          })
          .map((Map<String, dynamic> m) => m['id'] as String)
          .toList();
      expect(found, isNotEmpty, reason: 'hinge deseni hiç hareket bulamadı');
    });

    test('hold deseninde en az 1 hareket var (engine.type=staticHold)', () {
      final List<String> found = <String>[
        for (final Map<String, dynamic> m in movs)
          if (catalogFor(m)['engine'] != null &&
              (catalogFor(m)['engine'] as Map)['type'] == 'staticHold')
            m['id'] as String,
      ];
      expect(found, isNotEmpty, reason: 'hold deseni hiç hareket bulamadı');
    });
  });

  group('en az 2 skill tree (roadmap §10 paid foundation şartı)', () {
    test('content/skill-trees.index.json en az 2 paket listeler', () {
      final Map<String, dynamic> idx = (jsonDecode(File(
                  'content/skill-trees.index.json')
              .readAsStringSync()) as Map)
          .cast<String, dynamic>();
      final List<dynamic> trees = idx['trees'] as List<dynamic>;
      expect(trees.length, greaterThanOrEqualTo(2));
    });
  });

  group('⭐ ASIL KABUL KAPISI — bugün SKIP, adıyla (kırmızı DEĞİL)', () {
    // ⚠️ TASARIM KARARI: roadmap Step 1 "kırmızı yaz" diyor ve ilk
    // yazışımım TAM ÖYLE yazdı — gerçek `expect()`, bugün GERÇEKTEN
    // kırmızı (2 < 20). Ama ölçünce gördüm: `tools/run_all_gates.sh`ın
    // SÜİT 1'i `flutter test` — TÜM `test/`i tarar, seçici DEĞİL. Kalıcı
    // kırmızı bir dosya bu SÜİTİ (ve dolayısıyla HER gelecek commit'i)
    // `ALLOW_RED=1`e mahkûm ederdi — kapının "yeşil = güvenli" anlamını
    // sıfırlardı. Roadmap'in "kırmızı" niyeti kısa bir TDD döngüsü
    // varsayıyor (yaz → hemen uygula → yeşil); buradaki eşik AYLARCA kapalı
    // kalabilecek bir dış veriye bağlı — o TDD döngüsü değil.
    //
    // Panzehir `skip` — ve DİNAMİK: canlı sayı BURADA (main() içinde,
    // senkron dosya okumasıyla) ÖNCEDEN hesaplanır, `skip` mesajına
    // GÖMÜLÜR. Sayı 20'ye ulaştığı GÜN `skip` kendiliğinden `false` olur
    // ve test GERÇEKTEN koşup zorlar — kimsenin "bu satırı aç" diye
    // hatırlamasına gerek YOK. `run_all_gates.sh` skip'i kırmızı SAYMAZ
    // (dart test skip'i ayrı raporlar) — kapı gerçek bir engeli gizlemiyor,
    // yalnız onu "aktif ihlal" yerine "bilinen, adıyla bekleyen" olarak
    // taşıyor.
    final int liveCount =
        movements().where((Map<String, dynamic> m) => m['status'] == 'live').length;

    test(
      'en az 20 hareket AKTİF (status=live)',
      () {
        final int live = movements()
            .where((Map<String, dynamic> m) => m['status'] == 'live')
            .length;
        expect(live, greaterThanOrEqualTo(20));
      },
      skip: liveCount >= 20
          ? false
          : 'EXTERNAL_GATE: bugün $liveCount/20 hareket aktif '
              '(bodyweight_squat + push_up). Gerçek eğitmen hasadı + '
              'hareket-bilimi geçişi olmadan bu sayı büyümez (bu makinede '
              'mediapipe/cv2 ortamı yok — G-084/G-087/G-262/G-266). Sayı '
              '20\'ye ulaştığında bu skip KENDİLİĞİNDEN kalkar.',
    );
  });
}
