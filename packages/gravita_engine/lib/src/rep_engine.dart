// ⚠️ Ad çakışması: çekirdek v0.4.x `phase_config.dart` ile bu paketin
// kendi config tipleri aynı adları taşıyor. Bu, v3 çeviricisinde ÇEKİRDEK
// tiplerine geçilmesi gerektiğinin sinyali (M-F-35 göç yolu); o güne kadar
// hedefli gizleme — sessiz gölgeleme yerine açık beyan.
import 'package:motion_core/motion_core.dart' hide MetricCondition, PhaseSpec;

import 'metrics.dart';
import 'movement_config.dart';

/// Görünen tarafın GEOMETRİK seçimi.
///
/// ADR-003 / M-F-06: modelin `LEFT_*`/`RIGHT_*` etiketlerine güvenilmez —
/// ters-duruşta takas olabiliyor (D1'de ölçüldü). Taraf, o karedeki zincirin
/// görünürlüğüne göre seçilir; kural motoru "sol dirsek" değil "görünen dirsek"
/// üzerinden çalışır.
enum VisibleSide {
  left,
  right;

  String jointId(String joint) => '${name}_$joint';
}

VisibleSide resolveVisibleSide(PoseFrame frame) {
  const List<int> l = <int>[
    Lm.leftShoulder, Lm.leftElbow, Lm.leftWrist,
    Lm.leftHip, Lm.leftKnee, Lm.leftAnkle,
  ];
  const List<int> r = <int>[
    Lm.rightShoulder, Lm.rightElbow, Lm.rightWrist,
    Lm.rightHip, Lm.rightKnee, Lm.rightAnkle,
  ];
  double mean(List<int> ids) =>
      ids.map(frame.visibility).reduce((double a, double b) => a + b) / ids.length;
  return mean(l) >= mean(r) ? VisibleSide.left : VisibleSide.right;
}

/// Tek bir tamamlanmış tekrar.
final class Rep {
  const Rep({
    required this.index,
    required this.startUs,
    required this.endUs,
    required this.descentUs,
    required this.ascentUs,
    required this.extremeAngleDeg,
  });

  final int index;
  final int startUs;
  final int endUs;

  /// Başlangıç ucundan karşı uca geçen süre.
  final int descentUs;

  /// Karşı uçtan başlangıç ucuna dönen süre.
  final int ascentUs;

  /// Çevrimin uç noktasındaki eklem açısı — ROM hükmünün kaynağı.
  final double extremeAngleDeg;

  int get durationUs => endUs - startUs;
}

enum _End { open, closed }

/// Config-güdümlü tekrar sayacı.
///
/// Motor jeneriktir: şınav, squat, dip, barfiks, leg raise ve glute bridge aynı
/// kodu kullanır; fark yalnız `content/catalog/**.json` içindedir (ADR-004).
///
/// Sayım FAZ ADLARINA bağlı DEĞİLDİR. Hareketler fazlarını farklı adlandırır
/// (şınav `top/bottom`, barfiks `hang/top`) ve bazıları kapalı uçtan başlar
/// (dead bug). Motor iki ucu eşik türünden tanır ve bir tekrarı **tam çevrim**
/// olarak sayar: başlangıç ucu → karşı uç → başlangıç ucu. Böylece hangi uçtan
/// başlandığı önemsizdir.
///
/// Zamanlama metrikleri kare-arası piksel hızından DEĞİL uç geçişlerinin
/// damgalarından türetilir (aile kuralı D2).
/// Bir karenin hüküm verilebilir olup olmadığına karar veren yargıç.
///
/// İki farklı bağlam, iki farklı katılık ister ve bunu karıştırmak hattı
/// tıkıyor (ölçüldü):
///
/// * **Ürün (canlı koçluk):** çekirdeğin `ConfidenceGate`'i doğru seçim —
///   kullanıcı kadrajı düzeltebilir, biz de düzeltmesini isteriz.
/// * **Referans hasadı:** eğitmene "yeniden çek" diyemeyiz. Hareket-agnostik
///   bir kapı, hareketin İHTİYAÇ DUYDUĞU landmark'lar tamamen kadrajdayken bile
///   reddediyor: push-up hasadında gerekli landmark'lar karelerin %46-99'unda
///   kadrajdaydı ama kapı %96-100'ünü eledi. Aynı ders triyajda öğrenilmişti
///   (L-080 harekete-özel `lower_body_ids`); burada da geçerli.
typedef FrameJudge = bool Function(PoseFrame frame);

/// Yalnız [required] landmark'ları sınayan hareket-kapsamlı yargıç.
///
/// ⚠️ **HAM (izotropik OLMAYAN) kareyle çağrılmalıdır.** "Kadraj içinde mi"
/// sorusu yalnız orijinal normalize uzayda anlamlıdır: `toIsotropic` x'i
/// en-boy oranıyla çarpar (16:9'da 1,78), yani izotropik uzayda x ∈ [0, 1.78].
/// Orada `x <= 1` sınaması neredeyse her landmark'ı "kadraj dışı" sayar.
/// Ölçüldü: aynı hasat setinde ham uzayda %5-14 kare geçerken izotropik
/// uzayda %0 geçti.
FrameJudge scopedJudge(List<int> required, {double minVisibility = 0.5}) =>
    (PoseFrame f) => required.every((int i) {
          final PoseLandmark l = f.landmarks[i];
          return l.x >= 0 && l.x <= 1 && l.y >= 0 && l.y <= 1 &&
              l.visibility >= minVisibility;
        });

final class RepEngine {
  RepEngine(this.config,
      {JointAngleExtractor? extractor, PoseNormalizer? normalizer, FrameJudge? judge})
      : assert(config.engineType == EngineType.repFsm,
            'RepEngine yalnız repFsm yapılandırmalarını çalıştırır'),
        _extractor = extractor ?? const JointAngleExtractor(),
        _normalizer = normalizer ?? PoseNormalizer(),
        _judge = judge;

  final MovementConfig config;
  final JointAngleExtractor _extractor;
  final PoseNormalizer _normalizer;

  /// null ise çekirdeğin ürün-katılığındaki güven kapısı kullanılır.
  final FrameJudge? _judge;

  final List<Rep> _reps = <Rep>[];
  List<Rep> get reps => List<Rep>.unmodifiable(_reps);
  int get repCount => _reps.length;

  /// Hüküm verilemeyen kare sayısı — "analiz edemedim" oranının kaynağı.
  int skippedFrames = 0;

  _End? _current;
  _End? _cycleStart;
  bool _visitedOther = false;
  int? _cycleStartUs;
  int? _midpointUs;
  double _extreme = double.nan;

  /// Bir kareyi işler. [expected] verilirse yapısal denetim faz-eksen uyumunu
  /// da sınar (ADR-001 → ADR-002 zinciri).
  /// [size] ZORUNLUDUR: ham normalize koordinat anizotropiktir ve açı
  /// matematiğini en-boy oranı kadar bozar (J-028 / M-F-30). Varsayılan vermek,
  /// hatayı sessizce geri getirmek olurdu. Dönüşümün kendisi çekirdeğin kanonik
  /// `PoseFrame.toIsotropic` API'sindedir (M-F-33 yakınsama emri) — bu paket
  /// artık kendi kopyasını taşımaz.
  void addFrame(PoseFrame rawFrame, FrameSize size, {BodyOrientation? expected}) {
    final RepConfig c = config.rep!;
    final PoseFrame frame = rawFrame.toIsotropic(size);

    // 1) Güven kapısı — modelin net görüp görmediği.
    //
    // ⚠️ Kadraj sınaması HAM kareyle yapılır: `toIsotropic` koordinat aralığını
    // [0,1]'den [0,aspect]'e taşır ve [0,1] varsayan her kadraj kontrolü
    // sessizce "kadraj dışı" der. Açı matematiği izotropik uzayda kalır.
    final bool judgeable = _judge != null
        ? _judge(rawFrame)
        : ConfidenceGate.forVariant(PoseModelVariant.full).evaluate(rawFrame).judgeable;
    if (!judgeable) {
      skippedFrames++;
      return;
    }

    // 2) Yapısal denetim — gördüğü şeyin bir vücut olup olmadığı. Güven kapısı
    //    uzuv-etiketi terslemesini YAKALAYAMIYOR (D1'de ölçüldü), bu yüzden
    //    ikisi birlikte çalışır; biri diğerinin yerine geçmez.
    final StructuralCheck structural =
        StructuralValidator().check(frame, expected: expected);
    if (!structural.plausible) {
      skippedFrames++;
      return;
    }

    // 3) Hareket kimliği — gördüğü vücut BU hareketi yapıyor mu?
    //
    //    Güven kapısı "net görüyor muyum", yapısal denetim "bu bir vücut mu"
    //    sorusunu cevaplar; ikisi de "bu vücut ŞINAV mı yapıyor" sorusunu
    //    cevaplamaz. FSM sinyal ekleminin salınımını sayar: ayakta konuşurken
    //    el hareketi de dirseği 155°↔100° arasında gezdirir ve tekrar olarak
    //    sayılır (G-043, hasatta ölçüldü). Ön koşul config'den gelir.
    if (config.precondition.isNotEmpty) {
      final MovementMetrics pre = MovementMetrics.of(frame);
      for (final MetricCondition c in config.precondition) {
        final double? v = pre.byName(c.metric);
        // Ölçülemeyen ön koşul "geçti" sayılmaz — hüküm yok (fail-closed).
        if (v == null || v.isNaN || !c.holds(v)) {
          skippedFrames++;
          return;
        }
      }
    }

    // 4) Açıyı GÖRÜNEN taraftan oku (taraf-agnostik kural — ADR-003).
    final VisibleSide side = resolveVisibleSide(frame);
    final JointAngleVector angles =
        _extractor.extract(_normalizer.normalize(frame));
    final double? deg = angles.degreesById(side.jointId(c.joint));
    if (deg == null) {
      skippedFrames++;
      return;
    }

    _advance(deg, frame.tUs, c);
  }

  _End? _endAt(double deg, RepConfig c) {
    if (deg >= c.openEndMin) return _End.open;
    if (deg <= c.closedEndMax) return _End.closed;
    return null; // iki uç arasında — hüküm yok
  }

  void _advance(double deg, int tUs, RepConfig c) {
    // Fiziksel üst sınır: zaman aşımı olmadan bir çevrim sonsuza kadar açık
    // kalır ve "kullanıcı durdu" durumundan ayırt edilemez (J-009 dersi).
    if (_cycleStartUs != null && tUs - _cycleStartUs! > c.timeoutUs) {
      _resetCycle();
    }

    if (_cycleStart != null && !_extreme.isNaN) {
      _extreme = _cycleStart == _End.open
          ? (deg < _extreme ? deg : _extreme)
          : (deg > _extreme ? deg : _extreme);
    }

    final _End? here = _endAt(deg, c);
    if (here == null || here == _current) return;

    if (_cycleStart == null) {
      _cycleStart = here;
      _cycleStartUs = tUs;
      _extreme = deg;
    } else if (here != _cycleStart) {
      _visitedOther = true;
      _midpointUs = tUs;
    } else if (_visitedOther) {
      _reps.add(Rep(
        index: _reps.length + 1,
        startUs: _cycleStartUs ?? tUs,
        endUs: tUs,
        descentUs: (_midpointUs ?? tUs) - (_cycleStartUs ?? tUs),
        ascentUs: tUs - (_midpointUs ?? tUs),
        extremeAngleDeg: _extreme,
      ));
      _cycleStart = here;
      _cycleStartUs = tUs;
      _visitedOther = false;
      _midpointUs = null;
      _extreme = deg;
    }
    _current = here;
  }

  void _resetCycle() {
    _current = null;
    _cycleStart = null;
    _visitedOther = false;
    _cycleStartUs = null;
    _midpointUs = null;
    _extreme = double.nan;
  }

  /// Tek-düzeltme seçimi: aynı anda EN FAZLA bir hata söylenir (plan §9).
  /// Güvenlik > engelleyici > denge > büyük hiza > küçük form > optimizasyon.
  FormError? topCorrection(Map<String, double> metrics) {
    final List<FormError> firing = config.formErrors
        .where((FormError e) =>
            e.metric != null &&
            metrics.containsKey(e.metric) &&
            e.fires(metrics[e.metric]!))
        .toList()
      ..sort((FormError a, FormError b) => a.rank.compareTo(b.rank));
    return firing.isEmpty ? null : firing.first;
  }
}
