import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;

import 'harvest_reps.dart' show mandatoryFor, requiredFor;

/// push_up referansı — motion-core'un KANONİK `ReferenceCli`'siyle (v0.8.2,
/// L-139/0.8.0 çevrim-segmentasyonu dahil) yeniden üretilir.
///
/// ⚠️ Gravita'nın kendi `build_reference.dart`/`harvest_reps.dart` aracı
/// KULLANILMAZ (koordinatör talimatı): "kanonik ancak herkes aynı fonksiyonu
/// koşarsa doğru kalır" — bu araçlar kanonik CLI'nin tasarım temeliydi, artık
/// üstünü kanonik devraldı.
///
/// **Granülerite (G-063 koordinatör revizyonu — v2):** take birimi TEKRARDIR,
/// pencere DEĞİL. İlk deneme (v1) bir kesintisiz-hareket PENCERESİNİ tek take
/// yapıyordu; havuzu 638→30'a (44 contributing→7) küçültmüştü — çoğu pencere
/// karışık/az-tekrarlı olduğu için. Koordinatör kararı: kesici zaten ÜRÜNÜN
/// KENDİ rep-FSM'i olmalı (M-F-54'ün üç sayım biriminden TEKRAR; kaynak=
/// EĞİTMEN zaten `minSources`'ta korunuyor). Her İSİMLİ-derin tekrar
/// (`rom_bottom_angle ≤110°`, `formErrors.partial_rom`) kendi `Fixture`'ına
/// kesilir; `windowRule` beyanı provenance'a gömülür (hangi kuralla, hangi
/// config sürümüyle kesildiği İZLENEBİLİR — G-043 kalıbı: bedava varsayım
/// hasatta açık ölçüme döner).
///
/// Çevrim-segmentasyonunun devreye GİRMEMESİ bu granüleritede BEKLENEN ve
/// DÜRÜST: tek-tekrarlık bir fixture tanım gereği aperiyodiktir (`measured:
/// false`), segmentasyon rep-FSM'i OLMAYAN çok-tekrarlı video sınıfı için
/// kalır (ör. rep-FSM'siz statik/döngüsel hareketler).
///
/// Bölünen sorumluluk: bu araç yalnız TEKRAR-DÜZEYİ UYGUNLUK kararı verir
/// (derin mi, sığ mı — sığsa fixture hiç ÜRETİLMEZ, adıyla dışlanır). Geri
/// kalan HER ŞEY (izotropik dönüşüm, güven kapısı, aykırı-kaynak dışlama,
/// ayna çözümü, tolerans kaynağı) `ReferenceCli.buildArtifact` içindedir.
///
/// Provenance notu: fixture'ların rig-triyaj `referenceEligible` bayrağı
/// `false` (bu koşum ayrı bir eşiği ölçüyor, rig-triyaj sorusunu YANITLAMIYOR)
/// — bunu sahte `true` yapmak yerine sentetik tekrar-fixture'larına HİÇ
/// `referenceEligible` yazılmaz (provenance sourceUrl taşır) → CLI bunları
/// `unattested` sınıflar, `allowUnattested:true` ile kabul eder VE artefaktı
/// dürüstçe `PROVISIONAL` damgalar (zaten `harvested_provisional` idi).
void main(List<String> args) {
  final Directory dir = Directory(args.isEmpty
      ? '${Platform.environment['HOME']}/motion-harvest/gravita/landmarks'
      : args[0]);
  const String movementId = 'push_up';

  final File cfgFile = File('../../content/catalog/w1/$movementId.json');
  final MovementConfig cfg = MovementConfig.parse(cfgFile.readAsStringSync());
  final Map<String, dynamic> rawCfg =
      jsonDecode(cfgFile.readAsStringSync()) as Map<String, dynamic>;
  final List<dynamic> formErrors = rawCfg['formErrors'] as List<dynamic>;
  final Map<String, dynamic> partialRom = formErrors.cast<Map<String, dynamic>>().firstWhere(
      (Map<String, dynamic> e) => e['id'] == 'partial_rom',
      orElse: () => throw StateError('partial_rom formError yok'));
  final double shallowThreshold =
      ((partialRom['detect'] as Map<String, dynamic>)['value'] as num).toDouble();

  stdout.writeln('hareket: ${cfg.name} · fixture-uygunluk kriteri: '
      'en az bir tekrar rom_bottom_angle ≤ $shallowThreshold° (formErrors.partial_rom)\n');

  final Set<int> mandatory = mandatoryFor(cfg).toSet();
  final List<int> all = requiredFor(cfg);
  bool judge(PoseFrame f) {
    int ok = 0;
    for (final int i in all) {
      final PoseLandmark l = f.landmarks[i];
      final bool good =
          l.x >= 0 && l.x <= 1 && l.y >= 0 && l.y <= 1 && l.visibility >= 0.5;
      if (!good && mandatory.contains(i)) return false;
      if (good) ok++;
    }
    return ok >= all.length - 2;
  }

  final String repoSha = Process.runSync('git', <String>['rev-parse', '--short', 'HEAD'])
      .stdout
      .toString()
      .trim();
  final String windowRule = 'rep_fsm@$repoSha partial_rom=$shallowThreshold';

  final Map<String, Fixture> eligible = <String, Fixture>{};
  int windowCount = 0;
  int totalReps = 0;
  int shallowReps = 0;

  for (final File f in dir
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.json'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path))) {
    final Map<String, dynamic> fx =
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final Map<String, dynamic> meta = fx['recordingMeta'] as Map<String, dynamic>;
    final Map<String, dynamic> prov =
        (fx['provenance'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final String channel = (prov['channel'] as String?) ?? '?';
    final String? sourceUrl = prov['sourceUrl'] as String?;
    final String resolution = (meta['resolution'] as String?) ?? '1920x1080';
    final List<String> wh = resolution.split('x');
    final FrameSize size = FrameSize(int.parse(wh[0]), int.parse(wh[1]));
    final int fps = ((meta['fps'] as num?) ?? 30).round();

    const int maxGapUs = 2000000;
    final List<List<PoseFrame>> windows = <List<PoseFrame>>[];
    List<PoseFrame> cur = <PoseFrame>[];
    int lastUs = -1 << 40;
    for (final dynamic raw in fx['frames'] as List<dynamic>) {
      final Map<String, dynamic> fr = raw as Map<String, dynamic>;
      if (fr['detected'] != true) continue;
      final List<dynamic> lm = fr['lm'] as List<dynamic>;
      if (lm.length != Lm.count) continue;
      final PoseFrame pf = PoseFrame(
        tUs: ((fr['t'] as num) * 1000).round(),
        modelVersion: fx['modelVersion'] as String,
        landmarks: lm
            .map((dynamic p) => PoseLandmark(
                  ((p as List<dynamic>)[0] as num).toDouble(),
                  (p[1] as num).toDouble(),
                  (p[2] as num).toDouble(),
                  (p[3] as num).toDouble(),
                ))
            .toList(),
      );
      if (!judge(pf)) continue;
      if (pf.tUs - lastUs > maxGapUs && cur.isNotEmpty) {
        windows.add(cur);
        cur = <PoseFrame>[];
      }
      cur.add(pf);
      lastUs = pf.tUs;
    }
    if (cur.isNotEmpty) windows.add(cur);

    for (int wIdx = 0; wIdx < windows.length; wIdx++) {
      final List<PoseFrame> w = windows[wIdx];
      windowCount++;
      final RepEngine e = RepEngine(cfg, judge: judge);
      for (final PoseFrame pf in w) {
        e.addFrame(pf, size);
      }
      for (int rIdx = 0; rIdx < e.reps.length; rIdx++) {
        final Rep r = e.reps[rIdx];
        totalReps++;
        if (r.extremeAngleDeg > shallowThreshold) {
          shallowReps++;
          continue;
        }
        final List<PoseFrame> repFrames = w
            .where((PoseFrame pf) => pf.tUs >= r.startUs && pf.tUs <= r.endUs)
            .toList(growable: false);
        if (repFrames.length < 4) continue; // hizalanacak bir şey yok
        final String id = '$channel#w$wIdx r$rIdx';
        eligible[id] = Fixture(
          app: 'gravita',
          technique: movementId,
          frames: repFrames,
          modelVersion: fx['modelVersion'] as String,
          recordingMeta: RecordingMeta(resolution: resolution, fps: fps),
          provenance: ProvenanceInfo(
            channel: channel,
            sourceUrl: sourceUrl,
            raw: <String, dynamic>{'windowRule': windowRule},
          ),
        );
      }
    }
  }

  stdout.writeln('pencere sayısı: $windowCount · toplam tekrar: $totalReps '
      '(derin=${totalReps - shallowReps} · sığ=$shallowReps) · '
      'uygun fixture (derin tekrar): ${eligible.length}');
  stdout.writeln('  windowRule: $windowRule');
  stdout.writeln('  eğitmen başına UYGUN tekrar sayısı:');
  final Map<String, int> eligibleByChannel = <String, int>{};
  for (final String id in eligible.keys) {
    final String ch = id.split('#').first;
    eligibleByChannel[ch] = (eligibleByChannel[ch] ?? 0) + 1;
  }
  for (final MapEntry<String, int> e in eligibleByChannel.entries) {
    stdout.writeln('    ${e.key}: ${e.value}');
  }

  const ReferenceCli cli = ReferenceCli(allowUnattested: true);
  final Map<String, dynamic> artifact =
      cli.buildArtifact(technique: movementId, fixturesById: eligible);

  final Map<String, dynamic> result = artifact['result'] as Map<String, dynamic>;
  final Map<String, dynamic> tol = artifact['tolerance'] as Map<String, dynamic>;
  final Map<String, dynamic> cycleSeg =
      artifact['cycleSegmentation'] as Map<String, dynamic>;

  stdout.writeln('\n== ARTEFAKT (kanonik CLI) ==');
  stdout.writeln('measurementProvenance: ${artifact['measurementProvenance']}');
  stdout.writeln('contributingTakes: ${result['contributingTakes']} · '
      'distinctSources: ${result['distinctSources']} · '
      'excludedOutlierIds: ${(result['excludedOutlierIds'] as List<dynamic>).length}');
  stdout.writeln('mirrorConfident: ${result['mirrorConfident']} · '
      'mirrorGapMeasured: ${result['mirrorGapMeasured']} · '
      'mirrorSearchDecisive: ${result['mirrorSearchDecisive']}');
  stdout.writeln('cycleSegmentation: state=${cycleSeg['state']} · '
      'reason=${cycleSeg['reason']}');
  final Map<String, dynamic> unalign =
      cycleSeg['excludedUnalignable'] as Map<String, dynamic>;
  if (unalign.isNotEmpty) {
    stdout.writeln('  unalignable (${unalign.length}): '
        '${unalign.entries.map((e) => '${e.key}: ${e.value}').join("; ")}');
  }
  final List<dynamic> takeReports = artifact['takes'] as List<dynamic>;
  final List<dynamic> measuredCycles = takeReports
      .cast<Map<String, dynamic>>()
      .where((Map<String, dynamic> t) => t['cycleCount'] != null)
      .toList();
  stdout.writeln('cycleCount ÖLÇÜLEN take sayısı: ${measuredCycles.length}/'
      '${takeReports.length}');
  stdout.writeln('unreliableJoints: ${result['unreliableJoints']}');

  stdout.writeln('\n-- tolerans kaynağı (yeni vs eski) --');
  final Map<String, dynamic> perJointSource =
      tol['perJointSource'] as Map<String, dynamic>;
  final Map<String, dynamic> floorShare = tol['floorBoundShare'] as Map<String, dynamic>;
  const Map<String, String> oldSource = <String, String>{
    'elbow': 'variance', 'shoulder': 'variance', 'upper_arm': 'variance',
    'hip': 'floor', 'knee': 'floor', 'forearm': 'floor', 'thigh': 'floor',
    'shin': 'floor', 'trunk_tilt': 'floor',
  };
  for (final String joint in perJointSource.keys.toList()..sort()) {
    final String now = perJointSource[joint] as String;
    // Eski build_reference.dart çıktısı SOL/SAĞ'ı tek çift altında birleştirmişti
    // (ör. "elbow"); yeni kanonik CLI perJointSource TARAF-BAŞINA raporluyor
    // (left_elbow/right_elbow ayrı) — kıyas için önek soyulur.
    final String pairKey =
        joint.replaceFirst('left_', '').replaceFirst('right_', '');
    final String old = oldSource[pairKey] ?? '?';
    final String flag = now != old ? '  ⚠️ DEĞİŞTİ' : '';
    stdout.writeln('${joint.padRight(14)} eski=$old  yeni=$now  '
        'floorShare=${(floorShare[joint] as num?)?.toStringAsFixed(2)}$flag');
  }

  // mirrorAgnostic'i kendimiz hesaplıyoruz — canonik artefakt bu alanı taşımaz
  // (G-056/M-F-57(2) beyanı Gravita-özel bir yorum, çekirdek kavramı değil).
  final List<String> joints = (artifact['joints'] as List<dynamic>).cast<String>();
  final List<dynamic> meanRadRaw =
      (artifact['frames'] as Map<String, dynamic>)['meanRad'] as List<dynamic>;
  final List<List<double>> meanRad = meanRadRaw
      .map((dynamic row) => (row as List<dynamic>).cast<num>().map((num n) => n.toDouble()).toList())
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
  stdout.writeln('\nmeanLeftRightDiffDeg (kendi hesabımız): '
      '${meanLr.toStringAsFixed(2)}° (eski: 5,03°) → '
      'mirrorAgnostic=${meanLr < 7}');
}
