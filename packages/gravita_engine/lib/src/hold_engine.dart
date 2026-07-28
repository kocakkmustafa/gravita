import 'package:motion_core/motion_core.dart';

import 'metrics.dart';
import 'movement_config.dart';

/// Bir tutuş sırasında yaşanan form kırılması olayı.
final class HoldBreakEvent {
  const HoldBreakEvent({
    required this.id,
    required this.cue,
    required this.atUs,
    required this.endedHold,
  });

  final String id;
  final String cue;
  final int atUs;
  final bool endedHold;
}

enum HoldState { waiting, holding, ended }

/// Statik tutuş motoru — plank, hollow, side plank, wall sit, superman.
///
/// Tutuşun ölçtüğü şey süre DEĞİL, **şeklini koruduğun süredir**. Bu ayrım
/// ürünün tamamı: "60 saniye plank yaptın" ile "42 saniye sonra kalçan düştü"
/// arasındaki fark, kullanıcının gerçekten öğrendiği şeydir.
///
/// Bu yüzden motor üç sayı üretir: toplam tutuş, ilk kırılmaya kadar geçen süre
/// ve kırılma olayları. Yalnız süre raporlayan bir tutuş sayacı, bozuk formu
/// ödüllendirir.
///
/// ⚠️ Girdi izotropik kare olmalı (J-028) — `addFrame` bunu kendisi yapar.
final class HoldEngine {
  HoldEngine(this.config)
      : assert(config.engineType == EngineType.staticHold,
            'HoldEngine yalnız staticHold yapılandırmalarını çalıştırır');

  final MovementConfig config;

  HoldState state = HoldState.waiting;
  int skippedFrames = 0;

  final List<HoldBreakEvent> breaks = <HoldBreakEvent>[];

  int? _entryStableSinceUs;
  int? _holdStartUs;
  int? _holdEndUs;
  int? _firstBreakUs;
  final Map<String, int> _breachSinceUs = <String, int>{};

  /// Şeklin korunduğu toplam süre (µs).
  int get holdDurationUs =>
      _holdStartUs == null ? 0 : (_holdEndUs ?? _lastUs ?? _holdStartUs!) - _holdStartUs!;

  /// İlk form kırılmasına kadar geçen süre — "ne kadar dayandın" değil,
  /// "ne kadar TEMİZ dayandın".
  int? get timeToFirstBreakUs =>
      (_holdStartUs == null || _firstBreakUs == null)
          ? null
          : _firstBreakUs! - _holdStartUs!;

  /// Tutuş geçerli sayılacak asgari süreyi doldurdu mu?
  bool get isValid =>
      _holdStartUs != null && holdDurationUs >= config.hold!.minHoldUs;

  int? _lastUs;

  void addFrame(PoseFrame rawFrame, FrameSize size) {
    if (state == HoldState.ended) return;
    final HoldConfig c = config.hold!;
    final PoseFrame frame = rawFrame.toIsotropic(size);
    _lastUs = frame.tUs;

    // Güven kapısı + yapısal denetim: ikisi de geçmeden hüküm yok.
    if (!ConfidenceGate.forVariant(PoseModelVariant.full).evaluate(frame).judgeable ||
        !StructuralValidator().check(frame).plausible) {
      skippedFrames++;
      // Takip kaybı tutuşu SESSİZCE bitirmez; kullanıcı hâlâ pozisyonda
      // olabilir. Süre işlemeye devam eder, kırılma sayaçları dondurulur.
      _breachSinceUs.clear();
      return;
    }

    final MovementMetrics m = MovementMetrics.of(frame);

    if (state == HoldState.waiting) {
      final bool ready = c.entry.every((MetricCondition cond) {
        final double? v = m.byName(cond.metric);
        return v != null && !v.isNaN && cond.holds(v);
      });
      if (!ready) {
        _entryStableSinceUs = null;
        return;
      }
      _entryStableSinceUs ??= frame.tUs;
      if (frame.tUs - _entryStableSinceUs! >= c.stableForUs) {
        state = HoldState.holding;
        _holdStartUs = frame.tUs;
      }
      return;
    }

    // HOLDING: form kırılmalarını süreyle birlikte izle.
    for (final FormBreak b in c.formBreaks) {
      final double? v = m.byName(b.condition.metric);
      if (v == null || v.isNaN) continue;
      if (!b.condition.holds(v)) {
        _breachSinceUs.remove(b.id);
        continue;
      }
      final int since = _breachSinceUs.putIfAbsent(b.id, () => frame.tUs);
      final int needUs = (b.condition.sustainedMs ?? 0) * 1000;
      if (frame.tUs - since < needUs) continue;
      if (breaks.any((HoldBreakEvent e) => e.id == b.id)) continue;

      _firstBreakUs ??= frame.tUs;
      breaks.add(HoldBreakEvent(
        id: b.id,
        cue: b.cue,
        atUs: frame.tUs,
        endedHold: b.endsHold,
      ));
      if (b.endsHold) {
        state = HoldState.ended;
        _holdEndUs = frame.tUs;
        return;
      }
    }
  }

  /// Kullanıcı durdurdu ya da seans bitti.
  void stop(int tUs) {
    if (state == HoldState.holding) {
      _holdEndUs = tUs;
    }
    state = HoldState.ended;
  }
}
