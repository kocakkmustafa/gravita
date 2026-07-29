import 'dart:convert';

/// Bir hareketin çalıştırılabilir yapılandırması — `content/catalog/**/*.json`.
///
/// Kural: motor jeneriktir, hareket içeriktir (ADR-004). Bu sınıf o sözleşmenin
/// Dart tarafıdır; yeni hareket eklemek yeni JSON demektir, yeni kod değil.
enum MovementClass { a, b, d }

enum EngineType { repFsm, staticHold, multiPhaseFsm }

/// Ölçüm sözleşmesi. Dürüstlük kutusu **buradan üretilir**, elle yazılmaz —
/// 180 hareketin elle yazılmış metni motorla kaçınılmaz olarak ayrışır.
final class MeasurementContract {
  const MeasurementContract({
    required this.measured,
    required this.notMeasured,
    required this.gateableMetrics,
    required this.scoreDisplay,
  });

  factory MeasurementContract.fromJson(Map<String, dynamic> j) =>
      MeasurementContract(
        measured: (j['measured'] as List<dynamic>).cast<String>(),
        notMeasured:
            ((j['notMeasured'] as List<dynamic>?) ?? const <dynamic>[]).cast<String>(),
        gateableMetrics:
            ((j['gateableMetrics'] as List<dynamic>?) ?? const <dynamic>[]).cast<String>(),
        scoreDisplay: (j['scoreDisplay'] as String?) ?? 'band',
      );

  final List<String> measured;
  final List<String> notMeasured;
  final List<String> gateableMetrics;

  /// M-F-04 / K8: kalibrasyon kapısı geçilmeden SAYISAL skor gösterilmez.
  final String scoreDisplay;

  bool get numericScoreAllowed => scoreDisplay == 'numeric';
}

/// Bir form hatasının tespit kuralı ve — kritik olarak — o hatayı fixture'da
/// ÜRETEN perturbasyonu. İkisi aynı yerde durur ki biri değişince diğerinin
/// hâlâ eşiği aştığı betikle denetlenebilsin (G-013/G-015/G-016).
final class FormError {
  const FormError({
    required this.id,
    required this.label,
    required this.priority,
    required this.cue,
    this.metric,
    this.op,
    this.threshold,
    this.sustainedMs,
    this.perturbationTarget,
  });

  factory FormError.fromJson(Map<String, dynamic> j) {
    final Map<String, dynamic>? d = j['detect'] as Map<String, dynamic>?;
    final Map<String, dynamic>? p = j['perturbation'] as Map<String, dynamic>?;
    return FormError(
      id: j['id'] as String,
      label: j['label'] as String,
      priority: j['priority'] as String,
      cue: j['cue'] as String,
      metric: d?['metric'] as String?,
      op: d?['op'] as String?,
      threshold: (d?['value'] as num?)?.toDouble(),
      sustainedMs: (d?['sustainedMs'] as num?)?.toInt(),
      perturbationTarget: (p?['targetValue'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String label;
  final String priority;
  final String cue;
  final String? metric;
  final String? op;
  final double? threshold;
  final int? sustainedMs;
  final double? perturbationTarget;

  /// Tek-düzeltme önceliklendirmesi (plan §9): küçük sayı = önce söylenir.
  int get rank => const <String>[
        'safety',
        'blocking',
        'balance',
        'major_alignment',
        'minor_form',
        'optimization',
      ].indexOf(priority);

  bool fires(double value) => switch (op) {
        '>' => value > threshold!,
        '>=' => value >= threshold!,
        '<' => value < threshold!,
        '<=' => value <= threshold!,
        _ => false,
      };
}

/// repFsm ayarları.
final class RepConfig {
  const RepConfig({
    required this.joint,
    required this.topAngleMin,
    required this.bottomAngleMax,
    required this.timeoutUs,
    required this.minPhaseUs,
    this.fastTransition = false,
    this.filterCutoffHz,
  });

  /// Faz ADLARINA bağlanmaz.
  ///
  /// Hareketler fazlarını farklı adlandırır (şınav `top/bottom`, barfiks
  /// `hang/top`, leg raise `top/bottom` ama ters yönde). Motor bunları
  /// isimden değil **eşik türünden** okur: `angleMin` taşıyan faz "açık uç"
  /// (angle ≥ v), `angleMax` taşıyan faz "kapalı uç" (angle ≤ v). Tekrar, iki
  /// uç arasında bir TAM çevrimdir — hangi uçtan başlandığı önemli değildir,
  /// böylece kalça-kapalı başlayan hareketler (dead bug) de aynı kodu kullanır.
  factory RepConfig.fromJson(Map<String, dynamic> e) {
    final Map<String, dynamic> ph = e['phases'] as Map<String, dynamic>;
    final Map<String, dynamic>? sf = e['signalFilter'] as Map<String, dynamic>?;
    double? openEnd;
    double? closedEnd;
    for (final MapEntry<String, dynamic> entry in ph.entries) {
      final dynamic v = entry.value;
      if (v is! Map<String, dynamic>) continue;
      if (v['angleMin'] is num) openEnd = (v['angleMin'] as num).toDouble();
      if (v['angleMax'] is num) closedEnd = (v['angleMax'] as num).toDouble();
    }
    if (openEnd == null || closedEnd == null) {
      throw FormatException(
          'repFsm fazları iki uç tanımlamalı: biri angleMin, biri angleMax '
          '(bulunan: ${ph.keys.join(", ")})');
    }
    return RepConfig(
      joint: (e['signal'] as Map<String, dynamic>)['joint'] as String,
      topAngleMin: openEnd,
      bottomAngleMax: closedEnd,
      timeoutUs: ((e['timeoutMs'] as num).toInt()) * 1000,
      minPhaseUs: (((e['minPhaseMs'] as num?)?.toInt()) ?? 200) * 1000,
      fastTransition: e['fastTransition'] as bool? ?? false,
      filterCutoffHz: (sf?['cutoffHz'] as num?)?.toDouble(),
    );
  }

  final String joint;
  final double topAngleMin;
  final double bottomAngleMax;
  final int timeoutUs;
  final int minPhaseUs;

  /// J-027: hızlı hareketlerde çekirdek varsayılan yumuşatması geçişleri
  /// söndürür. Kesim frekansı eşiklerle BİRLİKTE pinlenir.
  final bool fastTransition;
  final double? filterCutoffHz;

  /// Açık uç eşiği (angle ≥ bu değer) ile kapalı uç eşiği (angle ≤ bu değer).
  double get openEndMin => topAngleMin;
  double get closedEndMax => bottomAngleMax;

  /// Sağlık kontrolü: iki uç birbirinden ayrık olmalı, yoksa her kare her iki
  /// uçta sayılır ve motor sürekli "tekrar" üretir.
  bool get endsAreDisjoint => openEndMin > closedEndMax;

  bool get topIsExtended => topAngleMin > bottomAngleMax;
}

/// Bir eşik koşulu: `{metric, op, value}` — hem tutuş girişinde hem form
/// kırılmasında aynı yapı kullanılır.
final class MetricCondition {
  const MetricCondition(this.metric, this.op, this.value, {this.sustainedMs});

  factory MetricCondition.fromJson(Map<String, dynamic> j) => MetricCondition(
        j['metric'] as String,
        (j['op'] as String?) ?? '>',
        (j['value'] as num).toDouble(),
        sustainedMs: (j['sustainedMs'] as num?)?.toInt(),
      );

  final String metric;
  final String op;
  final double value;
  final int? sustainedMs;

  bool holds(double v) => switch (op) {
        '>' => v > value,
        '>=' => v >= value,
        '<' => v < value,
        '<=' => v <= value,
        _ => false,
      };
}

/// Form kırılması: koşul + süre + ne yapılacağı.
final class FormBreak {
  const FormBreak({
    required this.id,
    required this.condition,
    required this.cue,
    required this.endsHold,
  });

  factory FormBreak.fromJson(Map<String, dynamic> j) => FormBreak(
        id: j['id'] as String,
        condition: MetricCondition.fromJson(j),
        cue: (j['cue'] as String?) ?? '',
        endsHold: (j['action'] as String?) == 'warn_then_end',
      );

  final String id;
  final MetricCondition condition;
  final String cue;

  /// `warn` yalnız uyarır; `warn_then_end` tutuşu bitirir. Ayrım içerikte
  /// durur çünkü hangi bozulmanın tutuşu geçersiz kıldığı harekete özgüdür.
  final bool endsHold;
}

/// staticHold ayarları.
final class HoldConfig {
  const HoldConfig({
    required this.entry,
    required this.stableForUs,
    required this.minHoldUs,
    required this.formBreaks,
  });

  factory HoldConfig.fromJson(Map<String, dynamic> e) {
    final Map<String, dynamic> entry = e['holdEntry'] as Map<String, dynamic>;
    return HoldConfig(
      entry: (entry['requires'] as List<dynamic>)
          .map((dynamic r) =>
              MetricCondition.fromJson(r as Map<String, dynamic>))
          .toList(),
      stableForUs: (((entry['stableForMs'] as num?)?.toInt()) ?? 1000) * 1000,
      minHoldUs: (((e['minHoldMs'] as num?)?.toInt()) ?? 0) * 1000,
      formBreaks: ((e['formBreak'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic b) => FormBreak.fromJson(b as Map<String, dynamic>))
          .toList(),
    );
  }

  final List<MetricCondition> entry;
  final int stableForUs;
  final int minHoldUs;
  final List<FormBreak> formBreaks;
}

/// Çok-faz zincirindeki tek faz.
final class PhaseSpec {
  const PhaseSpec({
    required this.id,
    required this.enterMetric,
    required this.enterOp,
    required this.enterValue,
    required this.optional,
    required this.checks,
  });

  factory PhaseSpec.fromJson(Map<String, dynamic> j) {
    final Map<String, dynamic> e = j['enter'] as Map<String, dynamic>;
    final dynamic v = e['value'];
    return PhaseSpec(
      id: j['id'] as String,
      enterMetric: e['metric'] as String,
      enterOp: (e['op'] as String?) ?? '>',
      enterValue: v is bool ? (v ? 1.0 : 0.0) : (v as num).toDouble(),
      optional: j['optional'] as bool? ?? false,
      checks: ((j['checks'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic c) => PhaseCheck.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String enterMetric;
  final String enterOp;
  final double enterValue;

  /// Varyanta göre atlanabilen faz (ör. chest-to-floor burpee).
  final bool optional;
  final List<PhaseCheck> checks;
}

/// Faz içinde sürekli sınanan kalite koşulu — ihlali bir form hatasına bağlanır.
final class PhaseCheck {
  const PhaseCheck(this.metric, this.op, this.value, this.errorId);

  factory PhaseCheck.fromJson(Map<String, dynamic> j) => PhaseCheck(
        j['metric'] as String,
        (j['op'] as String?) ?? '<',
        (j['value'] as num).toDouble(),
        j['errorId'] as String,
      );

  final String metric;
  final String op;
  final double value;
  final String errorId;
}

/// multiPhaseFsm ayarları.
final class MultiPhaseConfig {
  const MultiPhaseConfig({
    required this.sequence,
    required this.checkpointOnly,
    required this.timeoutUs,
  });

  factory MultiPhaseConfig.fromJson(Map<String, dynamic> e) => MultiPhaseConfig(
        sequence: (e['sequence'] as List<dynamic>)
            .map((dynamic p) => PhaseSpec.fromJson(p as Map<String, dynamic>))
            .toList(),
        checkpointOnly:
            ((e['checkpointOnly'] as List<dynamic>?) ?? const <dynamic>[])
                .cast<String>()
                .toSet(),
        timeoutUs: ((e['timeoutMs'] as num).toInt()) * 1000,
      );

  final List<PhaseSpec> sequence;

  /// Kare-kare SKORLANMAYAN fazlar (patlayıcı/blur). Orada yalnız "gerçekleşti
  /// mi" sorulur; büyüklük iddia edilmez (G-006).
  final Set<String> checkpointOnly;
  final int timeoutUs;
}

final class MovementConfig {
  const MovementConfig({
    required this.id,
    required this.name,
    required this.family,
    required this.movementClass,
    required this.engineType,
    required this.contract,
    required this.formErrors,
    required this.rep,
    required this.hold,
    required this.multi,
    required this.cameraSetup,
    required this.expectedOrientation,
    required this.wave,
  });

  factory MovementConfig.fromJson(Map<String, dynamic> j) {
    final Map<String, dynamic> e = j['engine'] as Map<String, dynamic>;
    final EngineType t = switch (e['type'] as String) {
      'repFsm' => EngineType.repFsm,
      'staticHold' => EngineType.staticHold,
      _ => EngineType.multiPhaseFsm,
    };
    return MovementConfig(
      id: j['id'] as String,
      name: j['name'] as String,
      family: j['family'] as String,
      movementClass: switch (j['class'] as String) {
        'A' => MovementClass.a,
        'B' => MovementClass.b,
        _ => MovementClass.d,
      },
      engineType: t,
      contract: MeasurementContract.fromJson(
          j['measurementContract'] as Map<String, dynamic>),
      formErrors: ((j['formErrors'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic f) => FormError.fromJson(f as Map<String, dynamic>))
          .toList(),
      rep: t == EngineType.repFsm ? RepConfig.fromJson(e) : null,
      hold: t == EngineType.staticHold ? HoldConfig.fromJson(e) : null,
      multi: t == EngineType.multiPhaseFsm ? MultiPhaseConfig.fromJson(e) : null,
      cameraSetup: (j['camera'] as Map<String, dynamic>)['setup'] as String,
      expectedOrientation: (e['expectedOrientation'] as String?) ?? 'upright',
      wave: (j['wave'] as num).toInt(),
    );
  }

  static MovementConfig parse(String jsonText) =>
      MovementConfig.fromJson(jsonDecode(jsonText) as Map<String, dynamic>);

  final String id;
  final String name;
  final String family;
  final MovementClass movementClass;
  final EngineType engineType;
  final MeasurementContract contract;
  final List<FormError> formErrors;
  final RepConfig? rep;
  final HoldConfig? hold;
  final MultiPhaseConfig? multi;
  final String cameraSetup;

  /// Ters-duruş bir motor tipi DEĞİL, bir yönelim niteliğidir: bir tutuş da bir
  /// tekrar da (HSPU) ters olabilir. `inverted` ise motor ADR-001 yönelim-farkında
  /// çıkarımını ve ADR-002 yapısal denetimini devreye alır.
  final String expectedOrientation;

  bool get isInverted => expectedOrientation == 'inverted';

  /// Hangi dalgada açıldığı — IA'da "yakında" etiketi ve kapsam takibi için.
  final int wave;

  /// B sınıfı form hükmü VERMEZ (blueprint §1/§8) — bu, UI'ın değil motorun
  /// zorladığı bir kuraldır.
  bool get claimsFormVerdict => movementClass != MovementClass.b;

  /// Dürüstlük kutusu: elle yazılmaz, sözleşmeden üretilir.
  ({List<String> measured, List<String> notMeasured}) honestyBox() => (
        measured: contract.measured,
        notMeasured: <String>[
          ...contract.notMeasured,
          if (!claimsFormVerdict)
            'Form verdict — the camera looks down the movement path here, so we '
                'count and time your reps instead of judging your form',
        ],
      );
}
