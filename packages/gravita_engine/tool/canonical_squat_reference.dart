import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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
/// **M-F-113 (G-069 sonrası koordinatör hükmü, seçenek c):** 14°'de de
/// 30°'de de AYNI 3 kaynak (Strength Side/THENX tam, Tom Merrick 2/11)
/// M-F-47 anlaşma kapısında kilitlendiği ölçüldü (bkz. G-069). Karar:
/// Strength Side + THENX KAYNAK-düzeyinde dışlanır (`excludedClusterOutlier`
/// — profil analizi ayrı bir iş, G-070); Tom Merrick TAM girdi olarak kalır
/// ve onun 2 sapan take'i motorun KENDİ normal M-F-47 take-düzeyi
/// mekanizmasıyla (push_up'ta da kanıtlanan yol: 71→37, 34 excludedOutlierIds)
/// elenir — elle filtrelenmez, kaynak-düzeyi ile take-düzeyi dışlama
/// KARIŞTIRILMAZ (koordinatörün açık talebi).
const Set<String> _clusterOutlierChannels = <String>{'Strength Side', 'THENX'};

void main(List<String> args) {
  // `--include-all`: G-069'un ORİJİNAL koşumunu (hiçbir kaynak-düzeyi dışlama
  // yapmadan) yeniden üretir — bulgunun tekrar-üretilebilir olması için.
  final bool includeAll = args.contains('--include-all');
  final Set<String> outlierChannels =
      includeAll ? <String>{} : _clusterOutlierChannels;
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
  final Map<String, int> excludedClusterOutlierCount = <String, int>{};
  for (final File f in slicedDir
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.json'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path))) {
    final Fixture fx = Fixture.decode(f.readAsStringSync());
    final String channel = fx.provenance?.channel ?? '?';
    if (!passChannels.contains(channel)) continue;
    if (outlierChannels.contains(channel)) {
      excludedClusterOutlierCount[channel] =
          (excludedClusterOutlierCount[channel] ?? 0) + 1;
      continue;
    }
    final String id = f.uri.pathSegments.last.replaceAll('.full.json', '');
    eligible[id] = fx;
    countByChannel[channel] = (countByChannel[channel] ?? 0) + 1;
  }
  stdout.writeln('uygun (PASS eğitmen, kaynak-kümesi HARİÇ Strength Side/'
      'THENX — G-069/M-F-113) fixture sayısı: ${eligible.length}');
  for (final MapEntry<String, int> e in countByChannel.entries) {
    stdout.writeln('  ${e.key}: ${e.value}');
  }
  stdout.writeln('kaynak-düzeyi DIŞLANAN (excludedClusterOutlier): '
      '${excludedClusterOutlierCount.entries.map((MapEntry<String, int> e) => '${e.key}=${e.value}').join(", ")}');

  // M-F-113: 9 temiz kaynak + Tom Merrick (TAM, 11 take) tek seferde
  // varsayılan 14°'de denenir. Tom Merrick'in 2 sapan take'i (G-069'da
  // ölçüldü) motorun KENDİ take-düzeyi M-F-47 mekanizmasıyla elenmesi
  // beklenir (push_up emsali: 71→37, 34 excludedOutlierIds) — elle
  // filtrelenmedi. Yine de beklenmedik bir kilitlenme ihtimaline karşı
  // sessiz çökme yerine adlandırılmış teşhisle dur (aile disiplini).
  const double clusterToleranceDeg = 14;
  late final Map<String, dynamic> artifact;
  try {
    artifact = ReferenceCli(allowUnattested: true, clusterToleranceDeg: 14)
        .buildArtifact(technique: movementId, fixturesById: eligible);
    stdout.writeln('\nclusterToleranceDeg=14° ile KÜMELENDİ.');
  } on ReferenceAgreementError catch (e) {
    stdout.writeln('\n⚠️ BEKLENMEDİK: 9-kaynak+Tom Merrick havuzu (${eligible.length} '
        'take) 14°\'de de KÜMELENEMEDİ: $e');
    stdout.writeln('\nBu, G-069\'un varsaydığından FARKLI bir bulgu olur — '
        'Strength Side/THENX\'i çıkarmak yetmedi demektir. Körlemesine '
        'genişletme YOK; artefakt YAZILMADI, koordinatöre yeni bulgu olarak '
        'bildirilecek.');
    exit(1);
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

  // mirrorAgnostic — G-056(2)/M-F-57(2) yalnız squat'ın kendi malzemesi
  // için ölçülmeli; push_up'taki 4,3-5,0° bandını burada VARSAYMIYORUZ.
  final List<String> joints = (artifact['joints'] as List<dynamic>).cast<String>();
  final List<dynamic> meanRadRaw =
      (artifact['frames'] as Map<String, dynamic>)['meanRad'] as List<dynamic>;
  final List<List<double>> meanRad = meanRadRaw
      .map((dynamic row) => (row as List<dynamic>)
          .map((dynamic n) => n == null ? double.nan : (n as num).toDouble())
          .toList())
      .toList();
  double symSum = 0;
  int symCnt = 0;
  for (int fi = 0; fi < meanRad.length; fi++) {
    for (int j = 0; j < joints.length; j++) {
      if (!joints[j].startsWith('left_')) continue;
      final int k = joints.indexOf(joints[j].replaceFirst('left_', 'right_'));
      if (k < 0) continue;
      final double a = meanRad[fi][j], b = meanRad[fi][k];
      if (a.isNaN || b.isNaN) continue;
      final double diff = math.atan2(math.sin(a - b), math.cos(a - b));
      symSum += diff.abs() * 180 / math.pi;
      symCnt++;
    }
  }
  final double meanLr = symCnt == 0 ? double.nan : symSum / symCnt;
  final bool mirrorAgnostic = meanLr < 7;
  stdout.writeln('\nmeanLeftRightDiffDeg: ${meanLr.toStringAsFixed(2)}° → '
      'mirrorAgnostic=$mirrorAgnostic (squat İÇİN İLK ölçüm — push_up '
      'bandını varsaymadık)');

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

  final List<dynamic> excludedOutlierIds =
      (result['excludedOutlierIds'] as List<dynamic>?) ?? <dynamic>[];
  final List<String> tomMerrickTakeOutliers = excludedOutlierIds
      .cast<String>()
      .where((String id) => id.startsWith('Tom_Merrick'))
      .toList();

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
    r'$mirrorAgnostic': mirrorAgnostic,
    r'$meanLeftRightDiffDeg': double.parse(meanLr.toStringAsFixed(2)),
    r'$thinEvidenceInstructors': thinEvidence,
    r'$firstReference': true,
    r'$clusterToleranceDegUsed': clusterToleranceDeg,
    r'$clusterToleranceNote': 'Varsayılan 14° ile kümelendi (Strength Side/'
        'THENX kaynak-düzeyinde dışlandıktan SONRA) — ölçülmedi diye '
        'genişletilmedi.',
    r'$excludedClusterOutlier': excludedClusterOutlierCount.keys.toList(),
    r'$excludedClusterOutlierNote': 'G-069/M-F-113: Strength Side '
        '(${excludedClusterOutlierCount['Strength Side'] ?? 0} take) ve THENX '
        '(${excludedClusterOutlierCount['THENX'] ?? 0} take — hasat-kimlik '
        'kapısını geçen 12 eğitmenlik havuzun TEK EN BÜYÜK kaynağıydı, ~%29) '
        'M-F-47 anlaşma kapısında hem 14°\'de hem 2× genişletilmiş 30°\'de '
        'AYNI takelerle, AYNI sapma dereceleriyle kilitlendiği ÖLÇÜLDÜĞÜ için '
        '(G-069) kaynak-DÜZEYİNDE dışlandı — kodlama hatası değil, malzeme '
        'yapısı (bkz. G-069). Bu iki kaynağın hipKneeCoupling KİMLİK kapısını '
        'GEÇTİĞİ değişmedi (hâlâ 12 PASS eğitmenden ikisi) — yalnız BU '
        'referansın kümelenme kapısından elendiler; sapma-profili analizi '
        '(G-070, ayrı iş) hangisinin gerçek stil-varyantı hangisinin '
        'pipeline sorunu olduğuna karar verecek.',
    r'$partialSourceOutliers': <String, dynamic>{
      'Tom Merrick': {
        'excludedTakes': tomMerrickTakeOutliers,
        'note': 'Kaynak-düzeyinde DIŞLANMADI (9 temiz kaynak + Tom Merrick '
            'TAM olarak, 11 take, girdi olarak verildi) — ${tomMerrickTakeOutliers.length} '
            'take normal M-F-47 take-düzeyi mekanizmasıyla elendi (push_up '
            'emsali: 71→37, 34 excludedOutlierIds). Kaynak-düzeyi dışlamayla '
            '(Strength Side/THENX) KARIŞTIRILMASIN — koordinatörün açık '
            'talebi.',
      },
    },
    r'$windowRule': 'rep_fsm (slice_deep_reps_squat.dart) + '
        'hipKneeCoupling gate (rep-fsm, hip_knee_coupling.bodyweight_squat.json)',
  };
  File('../../content/harvest/reference.bodyweight_squat.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(published)}\n');
  stdout.writeln('\nyazıldı: content/harvest/reference.bodyweight_squat.json '
      '(ailenin ÜÇÜNCÜ ürün referansı)');
  stdout.writeln('Tom Merrick take-düzeyi dışlama: $tomMerrickTakeOutliers');
}
