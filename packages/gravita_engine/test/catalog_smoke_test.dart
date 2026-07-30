import 'dart:io';

import 'package:gravita_engine/gravita_engine.dart';
import 'package:test/test.dart';

/// Katalog duman testi — motor, kataloğun TAMAMINI tüketebilmeli.
///
/// Bu test "yeni hareket = yeni JSON" iddiasının (ADR-004) kanıtıdır: kod
/// değişmeden her girdi yüklenebiliyorsa motor gerçekten jeneriktir.
///
/// ⚠️ **DALGA KAPSAMI:** bu test uzun süre YALNIZ `w1`i okudu; W2 eklendiğinde
/// (11 hareket) okuyucu genişletilmedi, yani "kataloğun TAMAMI" iddiası 20/31
/// hareketle sınanıyordu. `replay_gate`/`harvest_reps`/`build_reference` iki
/// dalgayı da okuyordu — sapma tam da bu yüzden görünmedi. Bu yüzden dizinler
/// artık ELLE sayılmıyor: `content/catalog/` altındaki HER `w*` dizini taranır,
/// yani W3 eklendiğinde kapı kendiliğinden genişler.
void main() {
  final List<File> files = Directory('../../content/catalog')
      .listSync()
      .whereType<Directory>()
      .where((Directory d) => d.uri.pathSegments.reversed
          .firstWhere((String s) => s.isNotEmpty)
          .startsWith('w'))
      .expand((Directory d) => d.listSync().whereType<File>())
      .where((File f) => f.path.endsWith('.json'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));

  test('katalogda hareket var', () => expect(files, isNotEmpty));

  // Kapsam SAYIYLA sabitlenir: dalga dizini gözden kaçarsa test düşer.
  test('kapı TÜM dalgaları okuyor (dalga-körlüğü nöbeti)', () {
    expect(files.length, 31,
        reason: 'Katalog büyüdü/küçüldü. Yeni bir dalga dizini eklendiyse '
            'bu sayı bilerek güncellenmeli — sessizce daralan kapı, '
            "W2'nin 11 hareketini 20/31 iddiasının arkasında sakladı.");
  });

  for (final File f in files) {
    final String id = f.uri.pathSegments.last.replaceAll('.json', '');
    test('$id — motor tarafından yüklenebiliyor', () {
      final MovementConfig c = MovementConfig.parse(f.readAsStringSync());
      expect(c.id, id);
      expect(c.contract.measured, isNotEmpty);
      // M-F-04/K8: kalibrasyon kapısı geçilmeden sayısal skor yok.
      expect(c.contract.numericScoreAllowed, isFalse);
      if (c.engineType == EngineType.repFsm) {
        // Uçlar ayrık olmalı — örtüşürse motor durmadan tekrar üretir.
        expect(c.rep!.endsAreDisjoint, isTrue,
            reason: '${c.rep!.openEndMin} ≤ ${c.rep!.closedEndMax}');
        // J-027: hızlı hareket filtre kesimini beyan etmeli.
        if (c.rep!.fastTransition) {
          expect(c.rep!.filterCutoffHz, isNotNull);
        }
      }
    });
  }
}
