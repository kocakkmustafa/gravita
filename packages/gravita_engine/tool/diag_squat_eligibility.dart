import 'dart:convert';
import 'dart:io';

import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;

/// G-069 DENETİMİ: kanonik CLI'ın KENDİ uygunluk katmanı (M-F-43
/// `referenceEligible`) squat havuzunda ne yapıyor? Bu araç hüküm vermez,
/// yalnız `ReferenceCli.eligibilityOf`'un her take için ne döndüğünü ve
/// M-F-47 anlaşma kapısına GERÇEKTE kaç take/kaç kaynak ulaştığını sayar.
///
/// Neden yazıldı: G-069'da sapan 100 take'i "3 kaynağın kümelenmemesi" diye
/// raporladım, ama havuzun geri kalanının kapıya HİÇ ULAŞMADIĞINI kontrol
/// etmedim — `excludedOutlierIds`'i okudum, `excludedIneligibleIds`'i
/// okumadım (G-059'un ta kendisi: kapıya soran var mı?).
void main(List<String> args) {
  final Directory slicedDir = Directory(
      '${Platform.environment['HOME']}/motion-harvest/gravita-squat/landmarks-rep-sliced');

  final Map<String, dynamic> gateDoc = jsonDecode(
      File('../../content/harvest/hip_knee_coupling.bodyweight_squat.json')
          .readAsStringSync()) as Map<String, dynamic>;
  final Map<String, dynamic> gateInstructors =
      gateDoc['instructors'] as Map<String, dynamic>;
  final Set<String> passChannels = gateInstructors.entries
      .where((MapEntry<String, dynamic> e) =>
          (e.value as Map<String, dynamic>)['gate'] == 'pass')
      .map((MapEntry<String, dynamic> e) => e.key)
      .toSet();

  final Map<String, Map<String, int>> byChannel = <String, Map<String, int>>{};
  final Map<String, List<String>> admittedIdsByChannel = <String, List<String>>{};
  for (final File f in slicedDir
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.json'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path))) {
    final Fixture fx = Fixture.decode(f.readAsStringSync());
    final String channel = fx.provenance?.channel ?? '?';
    if (!passChannels.contains(channel)) continue;
    final TakeEligibility elig = ReferenceCli.eligibilityOf(fx);
    (byChannel[channel] ??= <String, int>{})
        .update(elig.name, (int v) => v + 1, ifAbsent: () => 1);
    // allowUnattested:true YALNIZ `unattested`ı kabul eder; `ineligible`
    // her koşulda reddedilir (reference_cli.dart eligibilityOf/buildArtifact).
    if (elig == TakeEligibility.attested ||
        elig == TakeEligibility.firstParty ||
        elig == TakeEligibility.unattested) {
      (admittedIdsByChannel[channel] ??= <String>[])
          .add(f.uri.pathSegments.last.replaceAll('.full.json', ''));
    }
  }

  stdout.writeln('hipKneeCoupling gate=pass eğitmenler: ${passChannels.length}\n');
  stdout.writeln('${'kanal'.padRight(24)} ${'attested'.padLeft(9)} '
      '${'unattested'.padLeft(11)} ${'ineligible'.padLeft(11)}');
  int totAtt = 0, totUnatt = 0, totInel = 0;
  for (final String ch in byChannel.keys.toList()..sort()) {
    final Map<String, int> m = byChannel[ch]!;
    final int a = m['attested'] ?? 0,
        u = m['unattested'] ?? 0,
        i = m['ineligible'] ?? 0;
    totAtt += a;
    totUnatt += u;
    totInel += i;
    stdout.writeln('${ch.padRight(24)} ${a.toString().padLeft(9)} '
        '${u.toString().padLeft(11)} ${i.toString().padLeft(11)}');
  }
  stdout.writeln('${'TOPLAM'.padRight(24)} ${totAtt.toString().padLeft(9)} '
      '${totUnatt.toString().padLeft(11)} ${totInel.toString().padLeft(11)}');

  final int admitted =
      admittedIdsByChannel.values.fold(0, (int s, List<String> l) => s + l.length);
  stdout.writeln('\n== M-F-47 ANLAŞMA KAPISINA ULAŞAN HAVUZ ==');
  stdout.writeln('kabul edilen take: $admitted · '
      'DİSTİNCT KAYNAK: ${admittedIdsByChannel.length}');
  for (final String ch in admittedIdsByChannel.keys.toList()..sort()) {
    stdout.writeln('  $ch: ${admittedIdsByChannel[ch]!.length}');
  }
  stdout.writeln('\nkapıdan ÖNCE ineligible olarak düşen: $totInel take');
}
