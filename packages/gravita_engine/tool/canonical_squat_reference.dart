import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:gravita_engine/gravita_engine.dart' show MirrorSymmetry;
import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;

/// bodyweight_squat referansı — ailenin ÜÇÜNCÜ ürün referansı (M-F-106
/// yeşil ışığı). push_up ile AYNI kanonik `ReferenceCli` (v0.8.4), AYNI
/// yayım disiplini (M-F-90 üç şartı + G-066/067'nin iki yeni beyanı).
///
/// Girdi HAZIR: `slice_deep_reps_squat.dart`'ın kestiği rep-FSM-dilimli
/// fixture'lar (G-067) — bu araç kendi windowlama/RepEngine mantığını
/// TEKRARLAMAZ, yalnız hangi EĞİTMENLERİN dahil olacağına karar verir:
/// `hip_knee_coupling.bodyweight_squat.json` (windowBasis=rep-fsm) içinde
/// `gate:"pass"` olanlar — HASAT-KİMLİK kapısını geçmiş take'ler (M-F-106
/// hüküm 1: hipKneeCoupling take-düzeyi hasat-kimlik sinyalidir, çalışma-
/// zamanı kare-metriğine çevrilmez; bu yüzden burada bir FİLTRE olarak
/// kullanılır, `engine.precondition`'a yazılmaz).
///
/// M-F-106 hüküm 3 (provisional eşik riski BEYANLA çözülür): artefakta
/// `$identityGateBasis` + `$minAcceptedR` eklenir — kabul edilenlerin en
/// düşük r'ı eşiğin (0,2) ne kadar üstünde olduğunu gösterir (duyarlılık
/// kanıtı, blok değil).
///
/// **M-F-120 (M-F-113 İPTAL):** G-069/G-070'in kilidi bir kümelenme sorunu
/// DEĞİLDİ — havuzun 133/233 take'i M-F-47 kapısına hiç ULAŞMIYORDU, çünkü
/// Gravita'nın hasadı M-F-45'in sınıf-düzeyi muafiyetini TAŞIMAYAN bayat bir
/// rig kopyasıyla koşmuştu (G-072). Muafiyet uygulandıktan sonra 233 take /
/// 12 kaynak kapıya ulaşıyor ve M-F-47 İLK KEZ meşru havuzda soruluyor.
/// Bu yüzden ELLE kaynak-düzeyi dışlama YOK: hangi take'in aykırı olduğuna
/// motorun kendi M-F-47 mekanizması karar verir ve `excludedOutlierIds`de
/// ADIYLA raporlar (push_up emsali: 71→37, 34 adlandırılmış dışlama).
void main(List<String> args) {
  const String movementId = 'bodyweight_squat';
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
  final double minAcceptedR = passChannels
      .map((String ch) =>
          ((gateInstructors[ch] as Map<String, dynamic>)['pearsonHipKnee'] as num)
              .toDouble())
      .reduce(math.min);
  final double gateThreshold = (gateDoc['gateThreshold'] as num).toDouble();

  stdout.writeln('hareket: $movementId · hasat-kimlik filtresi: '
      'hipKneeCoupling gate=pass (windowBasis=rep-fsm)');
  stdout.writeln('kabul edilen ${passChannels.length} eğitmen: '
      '${passChannels.join(", ")}');
  stdout.writeln('minAcceptedR=$minAcceptedR (eşik=$gateThreshold, '
      'fark=${(minAcceptedR - gateThreshold).toStringAsFixed(3)})\n');

  final Map<String, Fixture> eligible = <String, Fixture>{};
  final Map<String, int> countByChannel = <String, int>{};
  for (final File f in slicedDir
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.json'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path))) {
    final Fixture fx = Fixture.decode(f.readAsStringSync());
    final String channel = fx.provenance?.channel ?? '?';
    if (!passChannels.contains(channel)) continue;
    final String id = f.uri.pathSegments.last.replaceAll('.full.json', '');
    eligible[id] = fx;
    countByChannel[channel] = (countByChannel[channel] ?? 0) + 1;
  }
  stdout.writeln('uygun (hipKneeCoupling PASS) fixture sayısı: '
      '${eligible.length} · ${countByChannel.length} kaynak');
  for (final String ch in countByChannel.keys.toList()..sort()) {
    stdout.writeln('  $ch: ${countByChannel[ch]}');
  }

  // G-050 deseni: varsayılan 14° ölçülmeden GENİŞLETİLMEZ. Önce dene; M-F-47
  // düşerse ÖLÇÜLMÜŞ bir genişletme olarak 30° denenir ve İKİ sonuç da
  // şeffaf raporlanır. İkisi de düşerse DURULUR (veriye uydurma yapılmaz).
  late final double clusterToleranceDeg;
  late final Map<String, dynamic> artifact;
  try {
    artifact = ReferenceCli(allowUnattested: true, clusterToleranceDeg: 14)
        .buildArtifact(technique: movementId, fixturesById: eligible);
    clusterToleranceDeg = 14;
    stdout.writeln('\n✅ clusterToleranceDeg=14° (varsayılan) ile KÜMELENDİ.');
  } on ReferenceAgreementError catch (e14) {
    stdout.writeln('\n⚠️ 14° ile kümelenemedi: $e14');
    stdout.writeln('\nG-050 deseni: 30° ile YENİDEN deneniyor (ÖLÇÜLMÜŞ '
        'genişletme — sessizce büyütülmedi)...');
    try {
      artifact = ReferenceCli(allowUnattested: true, clusterToleranceDeg: 30)
          .buildArtifact(technique: movementId, fixturesById: eligible);
      clusterToleranceDeg = 30;
      stdout.writeln('✅ clusterToleranceDeg=30° ile KÜMELENDİ.');
    } on ReferenceAgreementError catch (e30) {
      stdout.writeln('\n⚠️⚠️ 30° ile de kümelenemedi: $e30');
      stdout.writeln('\nDURDURULDU — daha fazla genişletme DENENMEDİ (veriye '
          'uydurma olurdu). Artefakt YAZILMADI. Bu, meşru havuzda (233 take / '
          '12 kaynak, 0 ineligible) alınmış GERÇEK bir anlaşmazlık bulgusudur '
          '— koordinatöre bildirilecek.');
      exit(1);
    }
  }

  final Map<String, dynamic> result = artifact['result'] as Map<String, dynamic>;
  final Map<String, dynamic> tol = artifact['tolerance'] as Map<String, dynamic>;
  final Map<String, dynamic> cycleSeg =
      artifact['cycleSegmentation'] as Map<String, dynamic>;

  stdout.writeln('\n== ARTEFAKT (kanonik CLI) ==');
  stdout.writeln('measurementProvenance: ${artifact['measurementProvenance']}');
  stdout.writeln('contributingTakes: ${result['contributingTakes']} · '
      'distinctSources: ${result['distinctSources']} · '
      'excludedOutlierIds: ${(result['excludedOutlierIds'] as List<dynamic>).length}');
  stdout.writeln('contributing sources: '
      '${(result['sources'] as List<dynamic>).cast<String>().toSet().join(", ")}');
  stdout.writeln('mirrorConfident: ${result['mirrorConfident']} · '
      'mirrorGapMeasured: ${result['mirrorGapMeasured']} · '
      'mirrorSearchDecisive: ${result['mirrorSearchDecisive']}');
  stdout.writeln('cycleSegmentation: state=${cycleSeg['state']} · '
      'reason=${cycleSeg['reason']}');
  stdout.writeln('unreliableJoints: ${result['unreliableJoints']}');
  stdout.writeln('meanAgreement: ${result['meanAgreement']}');

  stdout.writeln('\n-- tolerans kaynağı (taraf-başına) --');
  final Map<String, dynamic> perJointSource =
      tol['perJointSource'] as Map<String, dynamic>;
  final Map<String, dynamic> floorShare = tol['floorBoundShare'] as Map<String, dynamic>;
  int floorCount = 0, varianceCount = 0;
  for (final String joint in perJointSource.keys.toList()..sort()) {
    final String src = perJointSource[joint] as String;
    if (src == 'floor') {
      floorCount++;
    } else {
      varianceCount++;
    }
    stdout.writeln('${joint.padRight(20)} $src  '
        'floorShare=${(floorShare[joint] as num?)?.toStringAsFixed(2)}');
  }
  stdout.writeln('(toplam: $varianceCount varyans / $floorCount taban)');

  // TARAF-SİMETRİSİ (M-F-145): eski `meanLeftRightDiffDeg` ÖLDÜ.
  // O alan konsensüs üzerinde |ortalama| hesaplıyordu ve İKİ soruyu
  // karıştırıyordu (büyüklük × take'ler-arası işaret tutarlılığı) — G-078
  // Bulgu B'de ölçüldü: push_up take-düzeyi 19,25° iken konsensüs 5,16°
  // gösteriyordu (3,73× işaret-iptali). Artık iki ayrı alan var ve bayrak
  // YALNIZ BÜYÜKLÜKTEN türüyor. Hesap tek evde (`MirrorSymmetry`), iki
  // referans aracı da onu çağırıyor — kopya-sürüklenmesi yok.
  final MirrorSymmetry mirror = MirrorSymmetry.fromTakes(
      eligible.entries.map((MapEntry<String, Fixture> e) =>
          ReferenceCli(allowUnattested: true).prepareTake(e.key, e.value).take.frames));
  stdout.writeln('\ntakeMeanAbsLRDiffDeg: '
      '${mirror.takeMeanAbsLRDiffDeg.toStringAsFixed(2)}° · '
      'signConsistencyRatio: '
      '${mirror.signConsistencyRatio.toStringAsFixed(3)} → '
      'mirrorAgnostic=${mirror.mirrorAgnostic}');

  final List<dynamic> takeReports = artifact['takes'] as List<dynamic>;
  final Map<String, int> repsByChannel = <String, int>{};
  for (final dynamic t in takeReports) {
    final Map<String, dynamic> tm = t as Map<String, dynamic>;
    final String id = tm['id'] as String? ?? tm['source'] as String? ?? '?';
    final Fixture? fx = eligible[id];
    final String ch = fx?.provenance?.channel ?? (tm['source'] as String? ?? '?');
    repsByChannel[ch] = (repsByChannel[ch] ?? 0) + 1;
  }
  final List<String> thinEvidence = <String>[
    for (final MapEntry<String, int> e in countByChannel.entries)
      if (e.value <= 2) '${e.key} (${e.value} tekrar)',
  ];

  final Map<String, dynamic> published = <String, dynamic>{
    ...artifact,
    r'$identityGateBasis': 'provisional($gateThreshold)',
    r'$minAcceptedR': double.parse(minAcceptedR.toStringAsFixed(3)),
    r'$identityGateNote': 'hipKneeCoupling eşiği (0,2) PROVISIONAL — ama '
        'kabul edilen ${passChannels.length} eğitmenin en düşük r\'ı '
        '${minAcceptedR.toStringAsFixed(3)} (eşiğin '
        '${(minAcceptedR - gateThreshold).toStringAsFixed(3)} üstünde). '
        'Eşik belirsizliği bu marjda kompozisyonu ETKİLEMİYOR — duyarlılık '
        'kanıtı (M-F-106 hüküm 3), blok değil.',
    r'$mirrorSymmetry': mirror.toJson(),
    r'$mirrorAgnostic': mirror.mirrorAgnostic,
    r'$mirrorMetricNote': 'M-F-145: eski `meanLeftRightDiffDeg` (konsensüs '
        'üzerinde |ortalama|) KALDIRILDI — iki soruyu karıştırıyordu '
        '(büyüklük × take\'ler-arası işaret tutarlılığı). Yerine iki alan: '
        '`takeMeanAbsLRDiffDeg` (büyüklük) + `signConsistencyRatio` '
        '(sistematik tek-yanlılık). `mirrorAgnostic` YALNIZ büyüklükten '
        'türer — "teknik tarafı ayırt etmiyor" iddiası küçük FARK ister, '
        'işaret-iptali değil. Eşik (7°) temeli metrik-ayrımı ÖNCESİ döneme '
        'ait; şu an sınırda vaka yok, bir referans eşiğe YAKLAŞIRSA önce '
        'temeli yeniden türetilmeli.',
    r'$thinEvidenceInstructors': thinEvidence,
    r'$firstReference': true,
    r'$clusterToleranceDegUsed': clusterToleranceDeg,
    r'$clusterToleranceNote': clusterToleranceDeg == 14
        ? 'Varsayilan 14 derece (push_up ile ayni) ile kumelendi — ELLE kaynak '
            'dislama YOK; aykiri take\'ler motorun kendi M-F-47 mekanizmasiyla '
            'secildi ve excludedOutlierIds\'de adiyla duruyor.'
        : 'G-050 deseni: 14 derece ile ReferenceAgreementError alindi, 30 derece '
            'ile YENIDEN denendi ve kumelendi — OLCULMUS genisletme, veriye '
            'uydurulmus degil.',
    r'$eligibilityBasis': 'M-F-120 sinif-duzeyi muafiyet: bodyweight_squat '
        'YAPISAL-AKTIF (pasif icrasi biyomekanik olarak imkansiz), bu yuzden '
        'romMode=unknown klipler referansa UYGUN. Uygunluk kanonik rig '
        'e882a96 rom_mode.classify() ile yeniden hesaplandi (G-072); '
        'romMode=passive olan kaynak YINE dislaniyor. M-F-113 IPTAL: elle '
        'kaynak-duzeyi dislama YOK.',
    r'$windowRule': 'rep_fsm (slice_deep_reps_squat.dart) + '
        'hipKneeCoupling gate (rep-fsm, hip_knee_coupling.bodyweight_squat.json)',
  };
  File('../../content/harvest/reference.bodyweight_squat.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(published)}\n');
  stdout.writeln('\nyazıldı: content/harvest/reference.bodyweight_squat.json '
      '(ailenin ÜÇÜNCÜ ürün referansı)');
}
