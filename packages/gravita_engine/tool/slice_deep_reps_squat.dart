import 'dart:convert';
import 'dart:io';

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;

import 'harvest_reps.dart' show mandatoryFor, requiredFor;

/// Dart REP-SLICER (G-066/M-F-101 sıralaması): "önce Dart rep-slicer, sonra
/// kanonik damga KESİLMİŞ fixture'lara" — Python'a FSM portu YOK, iki aracın
/// doğru SIRALAMASI yeterli.
///
/// Bu araç ürünün gerçek rep-FSM'ini (RepEngine) koşturur, her İSİMLİ-derin
/// tekrarı (`formErrors.shallow_depth` bloke eşiğini AŞMAYAN, `rom_bottom_
/// angle ≤110°`) kendi fixture dosyasına KESER — ham frame kayıtları (t/
/// detected/lm/world) AYNEN kopyalanır, yeniden hesaplanmaz. FSM hiç
/// tamamlanmış tekrar üretmeyen bir video (ör. Vast Fitness Academy) SIFIR
/// dilim üretir → kanonik script'e hiç girmez → dürüstçe "veri yok".
///
/// Çıktı dizini `tools/hip_knee_coupling_canonical.py`'nin girdisi olur.
void main(List<String> args) {
  final Directory srcDir = Directory(
      '${Platform.environment['HOME']}/motion-harvest/gravita-squat/landmarks');
  final Directory outDir = Directory(
      '${Platform.environment['HOME']}/motion-harvest/gravita-squat/landmarks-rep-sliced');
  if (outDir.existsSync()) outDir.deleteSync(recursive: true);
  outDir.createSync(recursive: true);

  const String movementId = 'bodyweight_squat';
  final File cfgFile = File('../../content/catalog/w1/$movementId.json');
  final MovementConfig cfg = MovementConfig.parse(cfgFile.readAsStringSync());
  final List<dynamic> formErrors = (jsonDecode(cfgFile.readAsStringSync())
      as Map<String, dynamic>)['formErrors'] as List<dynamic>;
  final Map<String, dynamic> shallowErr = formErrors.cast<Map<String, dynamic>>().firstWhere(
      (Map<String, dynamic> e) => e['id'] == 'shallow_depth',
      orElse: () => throw StateError('shallow_depth formError yok'));
  final double shallowThreshold =
      ((shallowErr['detect'] as Map<String, dynamic>)['value'] as num).toDouble();

  stdout.writeln('hareket: ${cfg.name} · derin-tekrar kriteri: '
      'rom_bottom_angle ≤ $shallowThreshold° (formErrors.shallow_depth)\n');

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

  int totalReps = 0, deepReps = 0, filesWritten = 0;
  final Map<String, int> deepByChannel = <String, int>{};
  final Set<String> allChannels = <String>{};
  final Set<String> channelsWithDeepRep = <String>{};

  for (final File f in srcDir
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
    allChannels.add(channel);
    final List<String> wh =
        ((meta['resolution'] as String?) ?? '1280x720').split('x');
    final FrameSize size =
        FrameSize(int.parse(wh[0]), int.parse(wh.length > 1 ? wh[1] : wh[0]));

    // Ham kare kayıtlarını (t/detected/lm/world) tUs anahtarıyla indeksle —
    // dilimleme bunlardan AYNEN kopyalar, yeniden hesaplamaz.
    final List<dynamic> rawFrames = fx['frames'] as List<dynamic>;
    final Map<int, Map<String, dynamic>> rawByTUs = <int, Map<String, dynamic>>{};

    const int maxGapUs = 2000000;
    final List<List<PoseFrame>> windows = <List<PoseFrame>>[];
    List<PoseFrame> cur = <PoseFrame>[];
    int lastUs = -1 << 40;
    for (final dynamic raw in rawFrames) {
      final Map<String, dynamic> fr = raw as Map<String, dynamic>;
      if (fr['detected'] != true) continue;
      final List<dynamic> lm = fr['lm'] as List<dynamic>;
      if (lm.length != Lm.count) continue;
      final int tUs = ((fr['t'] as num) * 1000).round();
      final PoseFrame pf = PoseFrame(
        tUs: tUs,
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
      rawByTUs[tUs] = fr;
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
      // M-F-122 hüküm 1: motor artık `precondition.status != derived` ise
      // tekrar ÜRETMEZ. Bu HASAT yolu ve kimlik güvencesi kare-düzeyi ürün
      // ön koşulundan değil, take-düzeyi hasat-kimlik kapısından geliyor
      // (hipKneeCoupling, 12/16 eğitmen PASS — M-F-106/G-067). Hasat, ön
      // koşulu TÜRETECEK malzemeyi üreten yerdir; ondan "ön koşul zaten
      // türetilmiş olsun" istemek yumurta-tavuk olurdu. Muafiyet DEĞİL,
      // kapı DEĞİŞİMİ (G-039/G-048: farklı sorular, farklı kapılar).
      final RepEngine e =
          RepEngine(cfg, judge: judge, harvestIdentityAttested: true);
      for (final PoseFrame pf in w) {
        e.addFrame(pf, size);
      }
      for (int rIdx = 0; rIdx < e.reps.length; rIdx++) {
        final Rep r = e.reps[rIdx];
        totalReps++;
        if (r.extremeAngleDeg > shallowThreshold) continue;
        deepReps++;
        channelsWithDeepRep.add(channel);
        deepByChannel[channel] = (deepByChannel[channel] ?? 0) + 1;

        final List<Map<String, dynamic>> slicedFrames = <Map<String, dynamic>>[];
        for (final PoseFrame pf in w) {
          if (pf.tUs < r.startUs || pf.tUs > r.endUs) continue;
          final Map<String, dynamic>? raw = rawByTUs[pf.tUs];
          if (raw != null) slicedFrames.add(raw);
        }
        if (slicedFrames.length < 4) continue;

        final Map<String, dynamic> sliced = <String, dynamic>{
          'schemaVersion': 2,
          'app': fx['app'] ?? 'gravita',
          'recordingMeta': meta,
          'modelVersion': fx['modelVersion'],
          'frames': slicedFrames,
          'provenance': <String, dynamic>{
            ...prov,
            r'$windowRule': 'rep_fsm@dart-slicer shallow_depth=$shallowThreshold '
                'source=${f.path}',
          },
        };
        final String outName = '${channel}_w${wIdx}_r$rIdx.full.json'
            .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        File('${outDir.path}/$outName')
            .writeAsStringSync(jsonEncode(sliced));
        filesWritten++;
      }
    }
  }

  stdout.writeln('toplam tekrar: $totalReps (derin=$deepReps)');
  stdout.writeln('yazılan dilim-fixture: $filesWritten');
  stdout.writeln('eğitmen: ${allChannels.length} toplam, '
      '${channelsWithDeepRep.length} en az bir derin tekrar üretti');
  final Set<String> noDeepRep = allChannels.difference(channelsWithDeepRep);
  if (noDeepRep.isNotEmpty) {
    stdout.writeln('  DERİN TEKRARSIZ (dilim üretilmedi, kanonik script\'e '
        'hiç girmeyecek): ${noDeepRep.join(", ")}');
  }
  stdout.writeln('eğitmen başına derin-tekrar dilim sayısı:');
  for (final MapEntry<String, int> e in deepByChannel.entries) {
    stdout.writeln('  ${e.key}: ${e.value}');
  }
  stdout.writeln('\nçıktı dizini: ${outDir.path}');
}
