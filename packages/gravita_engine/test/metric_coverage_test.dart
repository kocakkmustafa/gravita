import 'dart:io';
import 'dart:math' as math;

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;
import 'package:test/test.dart';

/// KAPI (koordinatör hükmü, 2026-08-12, G-178): `holdEntry.requires`/
/// `formBreak`/`sequence[].enter`/`sequence[].checks` içinde geçen HER metrik
/// ya `MovementMetrics.byName`de hesaplı ya `MovementMetrics.unimplemented`da
/// adlandırılmış olmak ZORUNDA — üçüncü bir hâl (ne hesaplı ne adlandırılmış)
/// YASAK.
///
/// Bu kapı `tuck_planche`nin `planche_lean_deg`ini yakalardı: o metrik NE
/// switch'te NE `unimplemented`daydı — `holdEntry.requires`inde olduğu için
/// tutuş muhtemelen HİÇ başlamıyordu ve hiçbir şey bunu beyan etmiyordu.
/// Kapı bunu "adlandırılmamış boşluk" diye ÖTÜRÜR, sessizce geçmez.
void main() {
  final SyntheticPoseBuilder builder = const SyntheticPoseBuilder();
  final MovementMetrics probe = MovementMetrics.of(builder
      .build(const SyntheticPose(), tUs: 0)
      .toIsotropic(const FrameSize(900, 900)));

  bool known(String metric) =>
      probe.byName(metric) != null || MovementMetrics.unimplemented.contains(metric);

  List<String> catalogFiles() => Directory('../../content/catalog')
      .listSync()
      .whereType<Directory>()
      .expand((Directory w) => w.listSync().whereType<File>())
      .where((File f) => f.path.endsWith('.json'))
      .map((File f) => f.path)
      .toList()
    ..sort();

  test('katalogdaki HER staticHold/multiPhaseFsm hareketin metrikleri'
      ' ya hesaplı ya adlandırılmış (G-178 kapısı)', () {
    final List<String> gaps = <String>[];
    for (final String path in catalogFiles()) {
      final MovementConfig c = MovementConfig.parse(File(path).readAsStringSync());
      final Set<String> metrics = switch (c.engineType) {
        EngineType.staticHold => c.hold!.referencedMetrics,
        EngineType.multiPhaseFsm => c.multi!.referencedMetrics,
        EngineType.repFsm => const <String>{},
      };
      for (final String m in metrics) {
        if (!known(m)) gaps.add('${c.id}: $m');
      }
    }
    expect(gaps, isEmpty,
        reason: 'adlandırılmamış metrik boşluğu (ne byName ne unimplemented): '
            '${gaps.join(', ')}');
  });

  test('POZİTİF İKİZ: kapı GERÇEKTEN ateşliyor — bilinmeyen bir metrik'
      ' yakalanıyor', () {
    expect(known('this_metric_does_not_exist_anywhere'), isFalse,
        reason: 'kapı hiçbir zaman ötmüyorsa test konusu kalmamış demektir.');
  });

  test('9 hold/multiphase hareketin HİÇBİRİ required: türetmesi için 0'
      ' landmark üretmiyor (en az bir metriği hesaplı)', () {
    // `required:` boşsa motor eski fullBody varsayılanına düşer — bu
    // GÜVENLİDİR ama 9 hareketin HİÇBİRİNİN bugün bu duruma düşmediğini
    // (yani G-178 fix'inin GERÇEKTEN bir şey türettiğini) ölçer.
    for (final String path in catalogFiles()) {
      final MovementConfig c = MovementConfig.parse(File(path).readAsStringSync());
      if (c.engineType != EngineType.staticHold &&
          c.engineType != EngineType.multiPhaseFsm) {
        continue;
      }
      final Set<String> metrics = c.engineType == EngineType.staticHold
          ? c.hold!.referencedMetrics
          : c.multi!.referencedMetrics;
      final bool anyResolved = metrics.any((String m) =>
          MovementMetrics.requiredLandmarksFor(m, VisibleSide.left) != null);
      expect(anyResolved, isTrue,
          reason: '${c.id}: hiçbir metriği required-landmark\'a çözülmüyor — '
              'motor sessizce fullBody varsayılanına düşüyor demektir.');
    }
  });
}
