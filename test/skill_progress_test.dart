import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/skills/skill_progress.dart';

/// [SkillProgressEvaluator] — deterministik açılma sözleşmesi (GRA-P1-001).
///
/// ⭐ Bu dosyanın en önemli testi "SABOTAJ" grubundadır: gerçek (bugün
/// DRAFT) paketlere karşı, GİRDİ "her şey tamamlandı" dese bile çıktının
/// `achieved` DÖNMEDİĞİNİ kanıtlar. Diğer testler mantığın DOĞRU çalıştığını
/// gösterir; bu test mantığın ERKEN AÇILAMAYACAĞINI gösterir — ikisi farklı
/// iddia.
void main() {
  SkillPack loadHandstand() => SkillPack.parse(
      File('content/skill-graph/handstand.v1.json').readAsStringSync());
  SkillPack loadPlanche() => SkillPack.parse(
      File('content/skill-graph/planche.v1.json').readAsStringSync());

  group('ayrıştırma — gerçek içerikle', () {
    test('handstand paketi 15 düğüm taşıyor, ilk giriş düğümleri doğru', () {
      final SkillPack p = loadHandstand();
      expect(p.packId, 'gravita.handstand');
      expect(p.nodes, hasLength(15));
      expect(p.byId('wrist_prep')!.entry, isTrue);
      expect(p.byId('wall_plank')!.requires, <String>['wrist_prep', 'hollow_body']);
    });

    test('bugünkü paketlerin İKİSİ de DRAFT — eşikler doğrulanmamış', () {
      // ⚠️ Bu test, aşağıdaki SABOTAJ grubunun ÖN KOŞULUDUR: bu iddia
      // yanlışsa (biri validate edilmişse) sabotaj testi hiçbir şey
      // ölçmeyen bir vakum olurdu.
      expect(loadHandstand().thresholdsValidated, isFalse);
      expect(loadPlanche().thresholdsValidated, isFalse);
    });

    test('güvenlik-onay bayrağı doğru düğümde: yalnız headstand', () {
      final SkillPack p = loadHandstand();
      final List<String> flagged = p.nodes
          .where((SkillNode n) => n.requiresExplicitAcknowledgement)
          .map((SkillNode n) => n.id)
          .toList();
      expect(flagged, <String>['headstand']);
    });

    test('drills/cues gerçek içerikten geliyor, boş değil', () {
      final SkillNode n = loadHandstand().byId('wall_plank')!;
      expect(n.drills, isNotEmpty);
      expect(n.cues, isNotEmpty);
      expect(n.drills.first.prescription, isNotEmpty);
    });

    test('planche paketinin HİÇBİR düğümü `summary` taşımıyor — null, '
        'uydurulmuş metin DEĞİL', () {
      // ⚠️ İki paket AYRI yazıldı ve planche `summary` alanını hiç
      // kullanmıyor (handstand'dan farklı). İlk yazışımım `summary`yi
      // ZORUNLU `String` sanmıştı ve planche'ı ayrıştırırken ÇÖKTÜ — ölçüm
      // düzeltti: alan opsiyonel, eksik veri bir iddia üretmez.
      final SkillPack p = loadPlanche();
      expect(p.nodes, isNotEmpty);
      for (final SkillNode n in p.nodes) {
        expect(n.summary, isNull, reason: n.id);
      }
      // Aynı ayrıştırıcı handstand'da GERÇEKTEN dolu değer okuyabiliyor —
      // pozitif ikiz, alan sessizce hep null dönmüyor.
      expect(loadHandstand().byId('wrist_prep')!.summary, isNotNull);
    });
  });

  group('kilitli / güvenlik-onayı bekliyor', () {
    test('ön-koşulu karşılanmayan düğüm KİLİTLİ', () {
      final SkillPack p = loadHandstand();
      final SkillProgressEvaluator e =
          SkillProgressEvaluator(pack: p); // hiçbir şey tamamlanmadı
      expect(e.availabilityOf('wall_plank'), SkillNodeAvailability.locked,
          reason: 'wrist_prep + hollow_body tamamlanmadan wall_plank açılamaz');
    });

    test('giriş düğümü (requires boş) hiçbir zaman ön-koşuldan KİLİTLİ '
        'değildir', () {
      final SkillPack p = loadHandstand();
      final SkillProgressEvaluator e = SkillProgressEvaluator(pack: p);
      expect(e.availabilityOf('hollow_body'), isNot(SkillNodeAvailability.locked));
    });

    test('kısmi ön-koşul yetmez — İKİSİ de gerekli', () {
      final SkillPack p = loadHandstand();
      final SkillProgressEvaluator e = SkillProgressEvaluator(
          pack: p, completedNodeIds: const <String>{'wrist_prep'});
      expect(e.availabilityOf('wall_plank'), SkillNodeAvailability.locked,
          reason: 'yalnız wrist_prep yeterli değil, hollow_body da lazım');
    });

    test('ön-koşullar tamam ama güvenlik onayı YOK → '
        'blockedBySafetyAcknowledgement', () {
      final SkillPack p = loadHandstand();
      final SkillProgressEvaluator e = SkillProgressEvaluator(
          pack: p, completedNodeIds: const <String>{'hollow_body'});
      expect(e.availabilityOf('headstand'),
          SkillNodeAvailability.blockedBySafetyAcknowledgement);
    });

    test('güvenlik onayı VERİLİNCE bloke kalkar (draft olsa bile '
        'pendingValidation\'a düşer, locked\'a DEĞİL)', () {
      final SkillPack p = loadHandstand();
      final SkillProgressEvaluator e = SkillProgressEvaluator(
        pack: p,
        completedNodeIds: const <String>{'hollow_body'},
        acknowledgedSafetyNodeIds: const <String>{'headstand'},
      );
      expect(e.availabilityOf('headstand'), SkillNodeAvailability.pendingValidation);
    });
  });

  group('⭐ SABOTAJ — erken açılma koruması', () {
    test('TÜM düğümler "tamamlandı" + TÜM onaylar verilse BİLE, gerçek '
        '(DRAFT) pakette HİÇBİR düğüm achieved DÖNMEZ', () {
      final SkillPack p = loadHandstand();
      final Set<String> everyNode = p.nodes.map((SkillNode n) => n.id).toSet();
      final SkillProgressEvaluator e = SkillProgressEvaluator(
        pack: p,
        completedNodeIds: everyNode, // fabrikasyon — gerçekte imkansız girdi
        acknowledgedSafetyNodeIds: everyNode,
      );
      for (final String id in everyNode) {
        expect(e.availabilityOf(id), isNot(SkillNodeAvailability.achieved),
            reason: '$id: DRAFT pakette "her şey tamam" girdisi bile '
                'achieved üretmemeli — bu koruma silinirse taslak eşikler '
                'kullanıcıya "başardın" olarak SIZAR.');
        expect(e.availabilityOf(id), SkillNodeAvailability.pendingValidation);
      }
    });

    test('AYNI sabotaj planche paketinde de tutuyor (tek pakete özel bir '
        'kural DEĞİL)', () {
      final SkillPack p = loadPlanche();
      final Set<String> everyNode = p.nodes.map((SkillNode n) => n.id).toSet();
      final SkillProgressEvaluator e = SkillProgressEvaluator(
        pack: p, completedNodeIds: everyNode, acknowledgedSafetyNodeIds: everyNode,
      );
      for (final String id in everyNode) {
        expect(e.availabilityOf(id), isNot(SkillNodeAvailability.achieved));
      }
    });
  });

  group('POZİTİF İKİZ — achieved GERÇEKTEN üretilebiliyor mu', () {
    // ⚠️ Sabotaj grubu yalnız `isNot(achieved)` diyor — bu, koruma bozup
    // HİÇBİR ŞEYİN achieved dönmediği bir sınıfta da geçerdi (vekil-ölçüm
    // hatası). Bu ikiz koruma OLMASA (validated pakette) achieved'ın
    // GERÇEKTEN üretildiğini kanıtlıyor — SENTETİK bir pakette, çünkü
    // bugün gerçek hiçbir pakette `thresholdsValidated:true` yok.
    test('validated + tamamlanmış düğüm → achieved', () {
      final SkillPack validated = SkillPack.parse('''
      {
        "packId": "test.synthetic",
        "status": "VALIDATED — expert-reviewed 2099-01-01",
        "nodes": [
          { "id": "a", "title": "A", "summary": "s", "requires": [], "entry": true }
        ]
      }
      ''');
      final SkillProgressEvaluator e = SkillProgressEvaluator(
          pack: validated, completedNodeIds: const <String>{'a'});
      expect(e.availabilityOf('a'), SkillNodeAvailability.achieved);
    });

    test('validated ama TAMAMLANMAMIŞ düğüm → pendingValidation, achieved '
        'DEĞİL', () {
      final SkillPack validated = SkillPack.parse('''
      {
        "packId": "test.synthetic",
        "status": "VALIDATED",
        "nodes": [
          { "id": "a", "title": "A", "summary": "s", "requires": [], "entry": true }
        ]
      }
      ''');
      final SkillProgressEvaluator e = SkillProgressEvaluator(pack: validated);
      expect(e.availabilityOf('a'), SkillNodeAvailability.pendingValidation);
    });
  });

  group('determinizm + hata sınırları', () {
    test('aynı girdi → aynı çıktı (yan etkisiz, saf fonksiyon)', () {
      final SkillPack p = loadHandstand();
      final SkillProgressEvaluator e = SkillProgressEvaluator(
          pack: p, completedNodeIds: const <String>{'wrist_prep', 'hollow_body'});
      final SkillNodeAvailability first = e.availabilityOf('wall_plank');
      final SkillNodeAvailability second = e.availabilityOf('wall_plank');
      expect(first, second);
    });

    test('pakette olmayan id → ArgumentError (sessizce yanlış bir hâl '
        'DÖNMEZ)', () {
      final SkillPack p = loadHandstand();
      final SkillProgressEvaluator e = SkillProgressEvaluator(pack: p);
      expect(() => e.availabilityOf('zzz_bulunmaz'), throwsArgumentError);
    });
  });

  group('currentFocus()', () {
    test('kilitli düğümleri VE zaten tamamlanmış düğümleri dışlıyor', () {
      final SkillPack p = loadHandstand();
      final SkillProgressEvaluator e = SkillProgressEvaluator(
          pack: p, completedNodeIds: const <String>{'wrist_prep'});
      final List<String> focus =
          e.currentFocus().map((SkillNode n) => n.id).toList();
      expect(focus, isNot(contains('wrist_prep')),
          reason: 'zaten tamamlanmış — odak listesinde tekrar görünmemeli');
      expect(focus, isNot(contains('wall_plank')),
          reason: 'hollow_body eksik — hâlâ kilitli');
      expect(focus, contains('hollow_body'),
          reason: 'giriş düğümü, ön-koşulsuz — odakta olmalı');
      expect(focus, contains('shoulder_flexion'));
    });
  });
}
