import 'dart:convert';
import 'dart:io';

import 'package:gravita_engine/gravita_engine.dart';
import 'package:test/test.dart';

/// Beceri ağaçları ↔ katalog bütünlüğü.
///
/// Ağaç, kataloğun başka bir görünümü değil AYRI bir yapıdır: hareket sayfası
/// "nasıl yapılır"ı, ağaç "ne zaman açılır"ı taşır. İkisi `skillGraphNode` ile
/// bağlanır ve o bağ kopuksa kullanıcı var olmayan bir düğüme yollanır.
void main() {
  List<Map<String, dynamic>> packs() => Directory('../../content/skill-graph')
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.json'))
      .map((File f) => jsonDecode(f.readAsStringSync()) as Map<String, dynamic>)
      .toList();

  List<MovementConfig> catalog() => Directory('../../content/catalog')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.json') && !f.path.endsWith('exclusions.json'))
      .map((File f) => MovementConfig.parse(f.readAsStringSync()))
      .toList();

  test('her ağaç paketi düğüm taşıyor ve ön-koşulları çözülüyor', () {
    final List<Map<String, dynamic>> ps = packs();
    expect(ps, isNotEmpty);
    for (final Map<String, dynamic> p in ps) {
      final List<Map<String, dynamic>> nodes =
          (p['nodes'] as List<dynamic>).cast<Map<String, dynamic>>();
      expect(nodes, isNotEmpty, reason: '${p['packId']}');
      final Set<String> ids =
          nodes.map((Map<String, dynamic> n) => n['id'] as String).toSet();
      for (final Map<String, dynamic> n in nodes) {
        for (final dynamic r in (n['requires'] as List<dynamic>? ?? <dynamic>[])) {
          expect(ids, contains(r),
              reason: '${p['packId']}/${n['id']}: kırık ön-koşul "$r"');
        }
      }
    }
  });

  test('DAG — döngü yok (kilit açılamaz düğüm üretmez)', () {
    for (final Map<String, dynamic> p in packs()) {
      final Map<String, List<String>> g = <String, List<String>>{
        for (final dynamic n in p['nodes'] as List<dynamic>)
          (n as Map<String, dynamic>)['id'] as String:
              ((n['requires'] as List<dynamic>?) ?? <dynamic>[]).cast<String>(),
      };
      final Set<String> done = <String>{};
      final Set<String> stack = <String>{};
      void visit(String id) {
        expect(stack.contains(id), isFalse, reason: 'döngü: $id');
        if (done.contains(id)) return;
        stack.add(id);
        for (final String r in g[id]!) {
          visit(r);
        }
        stack.remove(id);
        done.add(id);
      }
      g.keys.forEach(visit);
    }
  });

  test('katalog → ağaç bağı KOPUK DEĞİL', () {
    final Set<String> nodeIds = <String>{
      for (final Map<String, dynamic> p in packs())
        for (final dynamic n in p['nodes'] as List<dynamic>)
          (n as Map<String, dynamic>)['id'] as String,
    };
    final List<MovementConfig> movs = catalog();
    expect(movs.length, greaterThanOrEqualTo(27));
    // En az bir hareket ağaca bağlı olmalı, yoksa test hiçbir şey sınamaz.
    int bound = 0;
    for (final MovementConfig m in movs) {
      final Map<String, dynamic> raw = jsonDecode(
          File('../../content/catalog/${m.wave == 1 ? "w1" : "w2"}/${m.id}.json')
              .readAsStringSync()) as Map<String, dynamic>;
      final String? node = raw['skillGraphNode'] as String?;
      if (node == null) continue;
      bound++;
      expect(nodeIds, contains(node), reason: '${m.id} → $node');
    }
    expect(bound, greaterThan(0), reason: 'hiç bağ yoksa bu test boş geçer');
  });

  test('aspirasyonel düğümler ROZETSİZ (blueprint §8)', () {
    for (final Map<String, dynamic> p in packs()) {
      for (final dynamic n in p['nodes'] as List<dynamic>) {
        final Map<String, dynamic> node = n as Map<String, dynamic>;
        if (node['aspirational'] == true) {
          expect(node['milestone'], isNot(true),
              reason: '${node['id']}: elit beceri rozetle ödüllendirilmez');
        }
      }
    }
  });
}
