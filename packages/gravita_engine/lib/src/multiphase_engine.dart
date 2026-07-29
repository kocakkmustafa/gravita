import 'dart:math' as math;

// ⚠️ Ad çakışması: çekirdek v0.4.x `phase_config.dart` ile bu paketin
// kendi config tipleri aynı adları taşıyor. Bu, v3 çeviricisinde ÇEKİRDEK
// tiplerine geçilmesi gerektiğinin sinyali (M-F-35 göç yolu); o güne kadar
// hedefli gizleme — sessiz gölgeleme yerine açık beyan.
import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;

import 'metrics.dart';
import 'movement_config.dart';

/// Zemin-göreli metrikler durum ister: "ayak yerden kesildi" ancak zeminin
/// nerede olduğu biliniyorsa söylenebilir.
///
/// Zemin, AYAĞIN (parmak ucu/topuk — ayak bileği değil) gördüğümüz en alçak
/// konumundan kestirilir (görüntüde en büyük y). Kalibrasyon sihirbazı zaten kullanıcıyı sabit kamerayla
/// çerçeveye sokuyor; zemin çizgisi seans boyunca sabit varsayılır.
final class GroundReference {
  double? _groundY;
  double? get groundY => _groundY;

  void observe(MovementMetrics m) {
    final double y = m.footContactY;
    if (y.isNaN) return;
    _groundY = _groundY == null ? y : math.max(_groundY!, y);
  }

  /// Ayak bileği zeminden [minRiseTorso] gövde-boyu yükseldiyse ayak kesilmiştir.
  bool feetOffGround(MovementMetrics m, {double minRiseTorso = 0.12}) {
    if (_groundY == null) return false;
    final double rise = (_groundY! - m.footContactY) / m.torsoLength;
    return rise > minRiseTorso;
  }
}

/// Bir tekrarın faz-faz kaydı.
final class PhaseRun {
  const PhaseRun(this.phaseId, this.enteredUs, this.leftUs);
  final String phaseId;
  final int enteredUs;
  final int? leftUs;
  int? get durationUs => leftUs == null ? null : leftUs! - enteredUs;
}

final class MultiPhaseRep {
  const MultiPhaseRep({
    required this.index,
    required this.runs,
    required this.startUs,
    required this.endUs,
    required this.errors,
  });

  final int index;
  final List<PhaseRun> runs;
  final int startUs;
  final int endUs;

  /// Bu tekrarda tetiklenen form hatası kimlikleri.
  final List<String> errors;

  int get durationUs => endUs - startUs;
  int? phaseDurationUs(String id) => runs
      .where((PhaseRun r) => r.phaseId == id)
      .map((PhaseRun r) => r.durationUs)
      .firstWhere((int? d) => d != null, orElse: () => null);
}

/// Çok-faz teknik motoru — burpee, Turkish get-up, skin-the-cat.
///
/// Rep-FSM'den farkı: iki uç arasında salınım değil, **sıralı bir faz zinciri**.
/// Zincir tamamlanmadan tekrar sayılmaz (yarım burpee "tekrar" değildir).
///
/// **Checkpoint fazları** (`checkpointOnly`) kare-kare SKORLANMAZ: patlayıcı faz
/// 20-30 fps'te 1-2 kare + blur olduğu için orada ölçüm dürüst değildir
/// (G-006'da ölçüldü). O fazda tek sorulan şey "gerçekleşti mi" — büyüklüğü
/// değil. Bu, ürünün "ölçemediğini ölçüyormuş gibi sunmama" kuralının motordaki
/// karşılığıdır.
final class MultiPhaseEngine {
  MultiPhaseEngine(this.config)
      : assert(config.engineType == EngineType.multiPhaseFsm,
            'MultiPhaseEngine yalnız multiPhaseFsm yapılandırmalarını çalıştırır');

  final MovementConfig config;
  final GroundReference ground = GroundReference();

  final List<MultiPhaseRep> reps = <MultiPhaseRep>[];
  int get repCount => reps.length;
  int skippedFrames = 0;

  /// Zincir tamamlanmadan bırakılan denemeler — "yarım tekrar" sayısı.
  int abandonedAttempts = 0;

  int _cursor = 0;
  final List<PhaseRun> _runs = <PhaseRun>[];
  final List<String> _errors = <String>[];
  int? _attemptStartUs;
  int? _phaseEnteredUs;

  void addFrame(PoseFrame rawFrame, FrameSize size) {
    final MultiPhaseConfig c = config.multi!;
    final PoseFrame frame = rawFrame.toIsotropic(size);

    if (!ConfidenceGate.forVariant(PoseModelVariant.full).evaluate(frame).judgeable ||
        !StructuralValidator().check(frame).plausible) {
      skippedFrames++;
      return;
    }

    final MovementMetrics m = MovementMetrics.of(frame);
    ground.observe(m);
    final int tUs = frame.tUs;

    // Faz zaman aşımı: zincir yarıda kaldıysa deneme düşer (J-009).
    if (_attemptStartUs != null && tUs - _attemptStartUs! > c.timeoutUs) {
      if (_cursor > 0) abandonedAttempts++;
      _resetAttempt();
    }

    final PhaseSpec next = c.sequence[_cursor];
    if (!_enters(next, m, c)) {
      // İsteğe bağlı fazı atla ve bir sonrakini dene.
      if (next.optional && _cursor + 1 < c.sequence.length &&
          _enters(c.sequence[_cursor + 1], m, c)) {
        _cursor++;
      } else {
        _runChecks(c, m);
        return;
      }
    }

    // Faza girildi.
    if (_runs.isNotEmpty) {
      final PhaseRun last = _runs.removeLast();
      _runs.add(PhaseRun(last.phaseId, last.enteredUs, tUs));
    }
    _runs.add(PhaseRun(c.sequence[_cursor].id, tUs, null));
    _phaseEnteredUs = tUs;
    _attemptStartUs ??= tUs;

    if (_cursor == c.sequence.length - 1) {
      // Zincir tamamlandı = bir tekrar.
      reps.add(MultiPhaseRep(
        index: reps.length + 1,
        runs: List<PhaseRun>.unmodifiable(_runs),
        startUs: _attemptStartUs!,
        endUs: tUs,
        errors: List<String>.unmodifiable(_errors),
      ));
      _resetAttempt();
    } else {
      _cursor++;
    }
  }

  bool _enters(PhaseSpec p, MovementMetrics m, MultiPhaseConfig c) {
    if (p.enterMetric == 'feet_off_ground') {
      return ground.feetOffGround(m) == (p.enterValue != 0);
    }
    final double? v = m.byName(p.enterMetric);
    if (v == null || v.isNaN) return false;
    return switch (p.enterOp) {
      '>' => v > p.enterValue,
      '>=' => v >= p.enterValue,
      '<' => v < p.enterValue,
      '<=' => v <= p.enterValue,
      '==' => (v - p.enterValue).abs() < 1e-9,
      _ => false,
    };
  }

  /// Aktif fazın kontrolleri. Checkpoint fazlarında ÇALIŞMAZ — orada ölçüm
  /// dürüst değil, o yüzden hüküm de verilmez.
  void _runChecks(MultiPhaseConfig c, MovementMetrics m) {
    if (_cursor == 0 || _phaseEnteredUs == null) return;
    final PhaseSpec active = c.sequence[_cursor - 1];
    if (c.checkpointOnly.contains(active.id)) return;
    for (final PhaseCheck chk in active.checks) {
      final double? v = m.byName(chk.metric);
      if (v == null || v.isNaN) continue;
      final bool violated = switch (chk.op) {
        '<' => !(v < chk.value),
        '<=' => !(v <= chk.value),
        '>' => !(v > chk.value),
        '>=' => !(v >= chk.value),
        _ => false,
      };
      if (violated && !_errors.contains(chk.errorId)) _errors.add(chk.errorId);
    }
  }

  void _resetAttempt() {
    _cursor = 0;
    _runs.clear();
    _errors.clear();
    _attemptStartUs = null;
    _phaseEnteredUs = null;
  }
}
