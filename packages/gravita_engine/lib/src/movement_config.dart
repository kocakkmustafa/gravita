import 'dart:convert';

/// Bir hareketin çalıştırılabilir yapılandırması — `content/catalog/**/*.json`.
///
/// Kural: motor jeneriktir, hareket içeriktir (ADR-004). Bu sınıf o sözleşmenin
/// Dart tarafıdır; yeni hareket eklemek yeni JSON demektir, yeni kod değil.
enum MovementClass { a, b, d }

enum EngineType { repFsm, staticHold, multiPhaseFsm, inversion }

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
    required this.cameraSetup,
  });

  factory MovementConfig.fromJson(Map<String, dynamic> j) {
    final Map<String, dynamic> e = j['engine'] as Map<String, dynamic>;
    final EngineType t = switch (e['type'] as String) {
      'repFsm' => EngineType.repFsm,
      'staticHold' => EngineType.staticHold,
      'multiPhaseFsm' => EngineType.multiPhaseFsm,
      _ => EngineType.inversion,
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
      cameraSetup: (j['camera'] as Map<String, dynamic>)['setup'] as String,
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
  final String cameraSetup;

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
