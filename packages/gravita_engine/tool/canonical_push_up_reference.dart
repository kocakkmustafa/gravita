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
/// Provenance notu (M-F-120'de DÜZELTİLDİ): eskiden bu araç rig-triyaj
/// `referenceEligible` bayrağını kesilen tekrar-fixture'larına HİÇ yazmıyordu
/// → CLI onları `unattested` sınıflıyor, `allowUnattested:true` kabul ediyor
/// ve artefakt `PROVISIONAL` damgalanıyordu. Gerekçe makuldü ama SONUCU
/// şuydu: rig'in `ineligible` dediği 25 kaynak sessizce referansa giriyordu,
/// squat ise AYNI bayrağı koruduğu için fail-closed reddediyordu — aynı
/// app'in iki referansı ZIT disiplin uyguluyordu (G-070). Artık bayrak
/// BİREBİR KORUNUR; uygunluk kararı rig'in işi (M-F-120 sınıf-düzeyi
/// muafiyetiyle: push_up YAPISAL-AKTİF, `unknown` klipler uygun).
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
            // M-F-120: ham fixture'ın uygunluk beyanı BİREBİR KORUNUR.
            // Eskiden bu bayrak KASITLI düşürülüyordu (aşağıdaki eski nota
            // bak) ve CLI take'leri `unattested` sınıflayıp `allowUnattested`
            // ile kabul ediyordu — squat aynı bayrağı koruduğu için
            // fail-closed reddediyordu, yani AYNI app'in iki referansı ZIT
            // disiplin uyguluyordu (G-070). Tek disiplin: koru.
            raw: <String, dynamic>{
              'windowRule': windowRule,
              if (prov['referenceEligible'] != null)
                'referenceEligible': prov['referenceEligible'],
              if (prov['romMode'] != null) 'romMode': prov['romMode'],
            },
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
  final Set<String> contributingSources =
      (result['sources'] as List<dynamic>).cast<String>().toSet();
  stdout.writeln('contributing sources: ${contributingSources.join(", ")}');
  const Set<String> oldInstructors = <String>{
    'FitnessFAQs', 'Calisthenicmovement', 'Renaissance Periodization',
    'THENX', 'Upright Health', 'Jeremy Ethier', 'Cara Kuykens',
    'GMB Fitness (Praxis)', 'K boges',
  };
  final Set<String> droppedFromOld =
      oldInstructors.difference(contributingSources);
  stdout.writeln('eski 9 eğitmenden düşenler: ${droppedFromOld.join(", ")}');
  for (final String ch in droppedFromOld) {
    final int n = eligibleByChannel[ch] ?? 0;
    stdout.writeln('  $ch: ${n == 0 ? "hiç derin tekrar üretmedi (ön-filtrede elendi)" : "$n derin tekrar ÜRETTİ ama M-F-47 anlaşma-kapısında aykırı sayıldı"}');
  }
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
  // v0.8.4 görünürlük-kapısı düzeltmesi (J-056): ölçülemeyen hücreler artık
  // DÜRÜST null — `num`'a zorla cast etmek (eski davranış) bu koşumda
  // patlıyordu. null → NaN (aile kuralı: ölçülemeyen "hüküm yok" demektir).
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
  stdout.writeln('\nmeanLeftRightDiffDeg (kendi hesabımız): '
      '${meanLr.toStringAsFixed(2)}° (eski: 5,03°) → '
      'mirrorAgnostic=$mirrorAgnostic');

  // ---- YAYIM (koordinatör hükmü, M-F-90): kanonik artefakt reference.
  // push_up.json'ı DEĞİŞTİRİR — üç şart: mirrorAgnostic beyanı + eğitmen-başı
  // thinEvidence + 9→5 düşüşün İSİMLİ sebebi. --------------------------------
  final List<String> thinEvidenceInstructors = <String>[
    for (final MapEntry<String, int> e in eligibleByChannel.entries)
      if (e.value <= 2) '${e.key} (${e.value} tekrar)',
  ];
  final Map<String, dynamic> dropReasons = <String, dynamic>{
    for (final String ch in droppedFromOld)
      ch: (eligibleByChannel[ch] ?? 0) == 0
          ? 'hiç derin tekrar üretmedi (formErrors.partial_rom≤110° geçen '
              'tekrar bulunamadı — ön-filtrede elendi, CLI'
              "'ye hiç girmedi)"
          : '${eligibleByChannel[ch]} derin tekrar üretti ama M-F-47 '
              'anlaşma-kapısında (14° küme toleransı) aykırı sayıldı, '
              'excludedOutlierIds içinde',
  };
  final Map<String, dynamic> published = <String, dynamic>{
    ...artifact,
    r'$mirrorAgnostic': mirrorAgnostic,
    r'$meanLeftRightDiffDeg': double.parse(meanLr.toStringAsFixed(2)),
    r'$mirrorAgnosticNote': 'G-056/M-F-57(2): şınav iki-taraflı simetrik bir '
        'harekettir — sol-sağ eklem farkı skorlama tabanının (7°) altında '
        'kalırsa aynalama sıra-kararsızlığı bir kusur değil malzemenin '
        'özelliğidir. DÖRT bağımsız pipeline'
        "'de doğrulandı (build_reference.dart 5,03° · kanonik-pencere 4,51° "
        '· kanonik-tekrar (bu artefakt) ${meanLr.toStringAsFixed(2)}°) — '
        'hepsi 4,3-5,0° bandında istikrarlı.',
    r'$thinEvidenceInstructors': thinEvidenceInstructors,
    r'$thinEvidenceNote': 'Bu eğitmenler yalnız 1-2 derin tekrarla katkıda '
        'bulunuyor (Choreia'
        "'nın thinEvidence dersi: az çevrim take-medyanını gürültüler, "
        'sıkı-uyum gerçek kalır ama örneklem ince). İsimli kuyruk kalemi — '
        'ayrı hasat turu AÇILMAZ, ileride herhangi bir Gravita hasat turuna '
        'katlanır.',
    r'$instructorDropFromOldReference': dropReasons,
    r'$windowRule': windowRule,
    r'$supersedes': 'harvested_provisional (9 eğitmen/44 take, build_reference'
        '.dart, kanonik-CLI-öncesi) — G-063/G-064 (docs/gates/), koordinatör '
        'hükmü M-F-90.',
  };
  File('../../content/harvest/reference.push_up.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(published)}\n');
  stdout.writeln('\nyazıldı: content/harvest/reference.push_up.json '
      '(eski harvested_provisional artefaktın YERİNE)');
}
