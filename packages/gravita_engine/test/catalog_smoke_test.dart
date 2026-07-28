import 'dart:io';

import 'package:gravita_engine/gravita_engine.dart';
import 'package:test/test.dart';

/// Katalog duman testi — motor, kataloğun TAMAMINI tüketebilmeli.
///
/// Bu test "yeni hareket = yeni JSON" iddiasının (ADR-004) kanıtıdır: kod
/// değişmeden her girdi yüklenebiliyorsa motor gerçekten jeneriktir.
void main() {
  final List<File> files = Directory('../../content/catalog/w1')
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.json'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));

  test('katalogda hareket var', () => expect(files, isNotEmpty));

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
