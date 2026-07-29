import 'dart:convert';
import 'dart:io';

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart';

/// Hasat fixture'ından TEKRAR çıkarımı — hasat→referans hattının ilk halkası.
///
/// Rig ham videodan landmark üretir; bu araç o landmark'ları hareketin KENDİ
/// config'iyle koşturup kaç temiz tekrar çıktığını ölçer. M-F-38'in yeterlilik
/// kapısı (≥3 eğitmen × ≥3 temiz tekrar) ancak bu sayıyla değerlendirilebilir.
///
/// Kullanım:
///   dart run tool/harvest_reps.dart push_up ~/motion-harvest/gravita/landmarks
/// ÖLÇÜM-KRİTİK landmark'lar: bunlar eksikse hareketin sinyali hesaplanamaz.
/// Yardımcı landmark'lardan (form metriklerinin kullandıkları) ayrı tutulur —
/// bir kare tekrar sayımını destekleyip form hükmünü desteklemeyebilir ve bu
/// normaldir ("hüküm yok" karenin tamamı için değil, METRİK başına verilir).
List<int> mandatoryFor(MovementConfig cfg) {
  final String joint = cfg.rep?.joint ?? 'elbow';
  return switch (joint) {
    'elbow' => <int>[Lm.leftShoulder, Lm.rightShoulder, Lm.leftElbow,
                     Lm.rightElbow, Lm.leftWrist, Lm.rightWrist,
                     Lm.leftHip, Lm.rightHip],
    'knee' => <int>[Lm.leftHip, Lm.rightHip, Lm.leftKnee, Lm.rightKnee,
                    Lm.leftAnkle, Lm.rightAnkle],
    'hip' => <int>[Lm.leftShoulder, Lm.rightShoulder, Lm.leftHip, Lm.rightHip,
                   Lm.leftKnee, Lm.rightKnee],
    _ => <int>[Lm.leftShoulder, Lm.rightShoulder, Lm.leftHip, Lm.rightHip],
  };
}

/// Hareketin GERÇEKTEN ihtiyaç duyduğu landmark'lar: sinyal ekleminin zinciri
/// + gövde referansı + triyaj profilinin harekete-özel alt-gövde kümesi.
List<int> requiredFor(MovementConfig cfg) {
  final Map<String, dynamic> prof = jsonDecode(
      File('../../content/harvest/triage-profile.gravita.v1.json').readAsStringSync())
      as Map<String, dynamic>;
  final List<int> lower = ((prof['perMovement'] as Map<String, dynamic>)[cfg.id]
          as List<dynamic>?)
      ?.cast<int>() ?? <int>[Lm.leftHip, Lm.rightHip];
  final String joint = cfg.rep?.joint ?? 'elbow';
  final List<int> chain = switch (joint) {
    'elbow' => <int>[Lm.leftShoulder, Lm.rightShoulder, Lm.leftElbow,
                     Lm.rightElbow, Lm.leftWrist, Lm.rightWrist],
    'knee' => <int>[Lm.leftHip, Lm.rightHip, Lm.leftKnee, Lm.rightKnee,
                    Lm.leftAnkle, Lm.rightAnkle],
    'hip' => <int>[Lm.leftShoulder, Lm.rightShoulder, Lm.leftHip, Lm.rightHip,
                   Lm.leftKnee, Lm.rightKnee],
    _ => <int>[Lm.leftShoulder, Lm.rightShoulder, Lm.leftHip, Lm.rightHip],
  };
  return <int>{...chain, ...lower}.toList();
}

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('kullanım: harvest_reps.dart <hareket-id> <landmarks-dizini>');
    exit(64);
  }
  final String movementId = args[0];
  final Directory dir = Directory(args[1]);

  final File cfgFile = <File>[
    File('../../content/catalog/w1/$movementId.json'),
    File('../../content/catalog/w2/$movementId.json'),
  ].firstWhere((File f) => f.existsSync(),
      orElse: () => throw StateError('config yok: $movementId'));
  final MovementConfig cfg = MovementConfig.parse(cfgFile.readAsStringSync());

  // FAIL-CLOSED (G-043/V15): kimlik ön koşulu türetilmeden tekrar çıkarılmaz.
  // Doğrulayıcı artefaktı sonradan reddediyor; asıl kapı ÜRETİM noktasındadır —
  // var olmayan bir hareketin "tekrarlarını" hiç üretmemek, sonra elemekten
  // iyidir (bir tur boyunca 85 el hareketi tekrar sanıldı).
  if (!cfg.preconditionDerived) {
    stderr.writeln('DURDU: ${cfg.id} için engine.precondition '
        'status=${cfg.preconditionStatus}. Hasatta kullanıcı beyanı YOKTUR; '
        'kimlik kapısı ölçümle türetilmeden çıkarılan tekrarlar, hareketi '
        'yapmayan kayıtları içerir (G-043).');
    exit(65);
  }

  stdout.writeln('hareket: ${cfg.name} (${cfg.engineType.name}, sınıf '
      '${cfg.movementClass.name.toUpperCase()})');
  stdout.writeln('${'kaynak'.padRight(16)}${'eğitmen'.padRight(24)}'
      '${'kare'.padLeft(7)}${'poz%'.padLeft(7)}${'TEKRAR'.padLeft(8)}'
      '${'pencere'.padLeft(9)}   en uzun  uç açı (medyan)');

  final List<Map<String, dynamic>> summary = <Map<String, dynamic>>[];

  for (final File f in dir
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.json'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path))) {
    final Map<String, dynamic> fx =
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final Map<String, dynamic> meta =
        fx['recordingMeta'] as Map<String, dynamic>;
    final Map<String, dynamic> prov =
        (fx['provenance'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final String res = (meta['resolution'] as String?) ?? '0x0';
    final List<String> wh = res.split('x');
    // J-028: kare boyutu OLMADAN açı hesaplanamaz.
    final FrameSize size =
        FrameSize(int.parse(wh[0]), int.parse(wh.length > 1 ? wh[1] : wh[0]));

    // Referans hasadında ÜRÜN kapısı değil, hareket-kapsamlı yargıç kullanılır:
    // eğitmene "yeniden çek" diyemeyiz (bkz. FrameJudge doc'u).
    // Kazanan yapılandırma (G-041 taraması): ÖLÇÜM-KRİTİK zincir zorunlu,
    // yardımcı landmark'lar (ör. şınavda ayak bileği) opsiyonel + 2 sn köprü.
    // Gerekçe ölçümde: ayak bileği tutorial'larda sık kadraj dışına çıkıyor ama
    // TEKRAR SAYIMI için gerekli değil — yalnız hat-sapması hükmü için gerekli.
    // Hepsini birden şart koşmak, form metriği yok diye tekrar verisini de
    // çöpe atıyordu.
    final Set<int> mandatory = mandatoryFor(cfg).toSet();
    final List<int> all = requiredFor(cfg);
    bool judge(PoseFrame f) {
      int ok = 0;
      for (final int i in all) {
        final PoseLandmark l = f.landmarks[i];
        final bool good = l.x >= 0 && l.x <= 1 && l.y >= 0 && l.y <= 1 &&
            l.visibility >= 0.5;
        if (!good && mandatory.contains(i)) return false;
        if (good) ok++;
      }
      return ok >= all.length - 2;
    }
    final List<dynamic> frames = fx['frames'] as List<dynamic>;

    // ⚠️ PENCERELEME ŞART. Tutorial'da kullanılabilir kareler videonun geneline
    // DAĞILMIŞTIR (konuşan-kafa, yakın çekim, b-roll araya girer). Tüm videoyu
    // tek akış gibi motora vermek, çevrimi sürekli zaman aşımına uğratır:
    // uçlar taranıyor olsa bile (ölçüldü: 264 açık / 56 kapalı uç karesi) tek
    // bir tekrar tamamlanmaz. Fixture için gereken şey temiz bir TEKRAR, temiz
    // bir VİDEO değil — bu yüzden önce kesintisiz pencerelere ayrılır.
    const int maxGapUs = 2000000; // histerezis 2 sn (G-041 taraması)
    final List<List<PoseFrame>> windows = <List<PoseFrame>>[];
    List<PoseFrame> current = <PoseFrame>[];
    int lastUs = -1 << 40;
    int detected = 0;
    for (final dynamic raw in frames) {
      final Map<String, dynamic> fr = raw as Map<String, dynamic>;
      if (fr['detected'] != true) continue;
      final List<dynamic> lm = fr['lm'] as List<dynamic>;
      if (lm.length != Lm.count) continue;
      detected++;
      final PoseFrame pf = PoseFrame(
        // fixture `t` MİLİSANİYE (fps 29.97 -> 33.37 ms/kare). Saniye sanıp
        // 1e6 ile çarpmak zaman damgalarını 1000x şişirir: her boşluk zaman
        // aşımını tetikler, hiçbir çevrim tamamlanmaz ve motor sessizce 0 tekrar
        // üretir. Ölçüm birimini VARSAYMAK, bu gecenin en pahalı hatasıydı.
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
      if (pf.tUs - lastUs > maxGapUs && current.isNotEmpty) {
        windows.add(current);
        current = <PoseFrame>[];
      }
      current.add(pf);
      lastUs = pf.tUs;
    }
    if (current.isNotEmpty) windows.add(current);

    int reps = 0;
    final List<double> extremes = <double>[];
    double bestWindowS = 0;
    for (final List<PoseFrame> w in windows) {
      final double lenS = (w.last.tUs - w.first.tUs) / 1e6;
      if (lenS > bestWindowS) bestWindowS = lenS;
      // Pencere başına TAZE motor: pencereler arası çevrim taşınmaz.
      final RepEngine e = RepEngine(cfg, judge: judge);
      for (final PoseFrame pf in w) {
        e.addFrame(pf, size);
      }
      reps += e.repCount;
      extremes.addAll(e.reps.map((Rep r) => r.extremeAngleDeg));
    }
    extremes.sort();

    final String med = extremes.isEmpty
        ? '-'
        : '${extremes[extremes.length ~/ 2].toStringAsFixed(0)}°';
    final String channel = (prov['channel'] as String?) ?? '?';
    stdout.writeln('${f.uri.pathSegments.last.replaceAll('.full.json', '').padRight(16)}'
        '${channel.padRight(24).substring(0, 24)}'
        '${frames.length.toString().padLeft(7)}'
        '${(detected * 100 ~/ frames.length).toString().padLeft(6)}%'
        '${reps.toString().padLeft(8)}'
        '${windows.length.toString().padLeft(9)}'
        '${'${bestWindowS.toStringAsFixed(1)}s'.padLeft(9)}   $med');

    summary.add(<String, dynamic>{
      'source': f.uri.pathSegments.last,
      'channel': channel,
      'sourceUrl': prov['sourceUrl'],
      'license': prov['license'],
      'reps': reps,
      'windows': windows.length,
      'longestWindowS': double.parse(bestWindowS.toStringAsFixed(1)),
      'extremeAnglesDeg': extremes.map((double e) => double.parse(e.toStringAsFixed(1))).toList(),
    });
  }

  final int enough = summary.where((Map<String, dynamic> s) => (s['reps'] as int) >= 3).length;
  stdout.writeln('\n≥3 tekrar veren eğitmen: $enough / ${summary.length}'
      '  → M-F-38 yeterlilik kapısı: ${enough >= 3 ? "AÇIK" : "KAPALI (muhafazakâr + provisional)"}');

  File('../../content/harvest/reps.$movementId.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        'movement': movementId,
        'rule': 'M-F-38: ≥3 eğitmen × ≥3 temiz tekrar olmadan varyans-türetim YAPILMAZ',
        'sufficiencyGate': enough >= 3 ? 'open' : 'closed',
        'sources': summary,
      })}\n');
}
