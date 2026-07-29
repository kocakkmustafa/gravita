import 'dart:convert';
import 'dart:io';

import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;

import 'harvest_reps.dart' show mandatoryFor, requiredFor;

/// REPLAY KAPISI (Ostinato deseni, aile standardı) — "hiç ateşlenmeyen faz".
///
/// Doğrulayıcı config'in ŞEKLİNİ denetler: şema geçerli mi, eşik metriği kayıtlı
/// mı, perturbasyon hedefi eşiği aşıyor mu. Hiçbiri şunu sormaz: **bu kural
/// gerçek kare akışında hiç ateşleniyor mu?** Şemadan temiz geçen, metriği
/// hesaplanabilen, sarkan atıfı olmayan bir kural yine de ÖLÜ olabilir — giriş
/// koşulu hiç sağlanmıyorsa kullanıcı doğru yapsa bile hüküm çıkmaz.
///
/// Üç sonuç ayrılır ve KARIŞTIRILMAZ (ayrım kapının değerini belirler):
///   ✅ ateşlendi
///   ◻️ kanal dışı — bu harekete ait fixture YOK. Kapsama boşluğu; config
///      kusuru değil, ama SAYILIR. Ölü fazla aynı işarete koymak, gerçek ölü
///      fazı gürültüde kaybeder.
///   ⛔ ÖLÜ — fixture vardı, kural yine de hiç ateşlenmedi. Gerçek kusur.
///
/// ⚠️ Metrikler burada YENİDEN YAZILMAZ; ürünün kendi motoru koşturulur.
/// Paralel bir ölçüm uygulaması, kapının sınadığı şeyden sessizce ayrışır.
void main(List<String> args) {
  final Directory lm = Directory(args.isEmpty
      ? '${Platform.environment['HOME']}/motion-harvest/gravita/landmarks'
      : args[0]);

  // Fixture'lar hareket-başına: hasat kütüphanesi şu an yalnız push_up taşıyor.
  final Map<String, List<File>> fixtures = <String, List<File>>{
    'push_up': lm
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.endsWith('.json'))
        .toList(),
  };

  final List<File> configs = <File>[
    ...Directory('../../content/catalog/w1').listSync().whereType<File>(),
    ...Directory('../../content/catalog/w2').listSync().whereType<File>(),
  ].where((File f) => f.path.endsWith('.json')).toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));

  int fired = 0, dead = 0, outOfChannel = 0;
  final List<String> deadUnits = <String>[];
  final List<String> report = <String>[];

  for (final File cf in configs) {
    final MovementConfig cfg = MovementConfig.parse(cf.readAsStringSync());
    final List<File>? fx = fixtures[cfg.id];

    // Bu hareketin "ateşlenebilir birimleri".
    final List<String> units = <String>[
      if (cfg.engineType == EngineType.repFsm) ...<String>['end:open', 'end:closed', 'rep:cycle'],
      if (cfg.engineType == EngineType.staticHold) ...<String>[
        'hold:entry',
        for (final FormBreak b in cfg.hold!.formBreaks) 'break:${b.id}',
      ],
      if (cfg.engineType == EngineType.multiPhaseFsm)
        for (final PhaseSpec p in cfg.multi!.sequence) 'phase:${p.id}',
      for (final FormError e in cfg.formErrors)
        if (e.metric != null) 'error:${e.id}',
    ];

    if (fx == null || fx.isEmpty) {
      outOfChannel += units.length;
      report.add('◻️  ${cfg.id.padRight(22)} ${units.length} birim — fixture YOK');
      continue;
    }

    final Map<String, int> hits = <String, int>{for (final String u in units) u: 0};
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

    for (final File f in fx) {
      final Map<String, dynamic> doc =
          jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final Map<String, dynamic> meta =
          doc['recordingMeta'] as Map<String, dynamic>;
      final List<String> wh =
          ((meta['resolution'] as String?) ?? '1920x1080').split('x');
      final FrameSize size = FrameSize(int.parse(wh[0]), int.parse(wh[1]));

      final List<PoseFrame> frames = <PoseFrame>[];
      for (final dynamic raw in doc['frames'] as List<dynamic>) {
        final Map<String, dynamic> fr = raw as Map<String, dynamic>;
        if (fr['detected'] != true) continue;
        final List<dynamic> pts = fr['lm'] as List<dynamic>;
        if (pts.length != Lm.count) continue;
        final PoseFrame pf = PoseFrame(
          tUs: ((fr['t'] as num) * 1000).round(),
          landmarks: pts
              .map((dynamic p) => PoseLandmark(
                    ((p as List<dynamic>)[0] as num).toDouble(),
                    (p[1] as num).toDouble(),
                    (p[2] as num).toDouble(),
                    (p[3] as num).toDouble(),
                  ))
              .toList(),
        );
        if (judge(pf)) frames.add(pf);
      }
      if (frames.isEmpty) continue;

      if (cfg.engineType == EngineType.repFsm) {
        final RepEngine e = RepEngine(cfg, judge: judge);
        for (final PoseFrame pf in frames) {
          e.addFrame(pf, size);
          final PoseFrame iso = pf.toIsotropic(size);
          if (!StructuralValidator().check(iso).plausible) continue;
          // Ön koşul geçmeyen kare bu hareketin karesi değildir; kural
          // ateşlenmesi de oradan sayılmaz (G-043 ile tutarlı).
          final MovementMetrics m = MovementMetrics.of(iso);
          bool pre = true;
          for (final MetricCondition c in cfg.precondition) {
            final double? v = m.byName(c.metric);
            if (v == null || v.isNaN || !c.holds(v)) {
              pre = false;
              break;
            }
          }
          if (!pre) continue;

          final double? deg = m.byName('${cfg.rep!.joint}_angle') ??
              m.byName(cfg.rep!.joint);
          if (deg != null && !deg.isNaN) {
            if (deg >= cfg.rep!.openEndMin) hits['end:open'] = hits['end:open']! + 1;
            if (deg <= cfg.rep!.closedEndMax) {
              hits['end:closed'] = hits['end:closed']! + 1;
            }
          }
          for (final FormError err in cfg.formErrors) {
            if (err.metric == null) continue;
            final double? v = m.byName(err.metric!);
            if (v != null && !v.isNaN && err.fires(v)) {
              hits['error:${err.id}'] = hits['error:${err.id}']! + 1;
            }
          }
        }
        hits['rep:cycle'] = e.repCount;
        // TEKRAR-KAPSAMLI kurallar çevrim tamamlanınca değerlendirilir; kare
        // döngüsünde aranırsa hiç ateşlenmez ve kural ÖLÜ görünür (gerçekte
        // ölüydü de — G-054).
        for (final Rep r in e.reps) {
          final Map<String, double> rm = e.repMetrics(r);
          for (final FormError err in cfg.formErrors) {
            if (err.metric == null || !rm.containsKey(err.metric)) continue;
            if (err.fires(rm[err.metric]!)) {
              hits['error:${err.id}'] = hits['error:${err.id}']! + 1;
            }
          }
        }
      }
    }

    final List<String> local = <String>[];
    for (final MapEntry<String, int> h in hits.entries) {
      if (h.value > 0) {
        fired++;
      } else {
        dead++;
        deadUnits.add('${cfg.id}/${h.key}');
        local.add(h.key);
      }
    }
    report.add('${local.isEmpty ? "✅" : "⛔"}  ${cfg.id.padRight(22)}'
        '${hits.length} birim · ateşlenen ${hits.values.where((int v) => v > 0).length}'
        '${local.isEmpty ? "" : " · ÖLÜ: ${local.join(", ")}"}');
  }

  report.forEach(stdout.writeln);
  stdout.writeln('\n✅ ateşlenen $fired · ⛔ ÖLÜ $dead · ◻️ kanal dışı '
      '$outOfChannel (fixture bekliyor)');
  if (dead > 0) {
    stdout.writeln('\nÖLÜ birimler — fixture VARDI, kural hiç ateşlenmedi:');
    for (final String d in deadUnits) {
      stdout.writeln('  $d');
    }
  }
  exit(dead > 0 ? 1 : 0);
}
