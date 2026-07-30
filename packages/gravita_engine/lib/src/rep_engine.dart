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
    required this.startedAtOpenEnd,
  });

  final int index;
  final int startUs;
  final int endUs;

  /// Başlangıç ucundan karşı uca geçen süre.
  final int descentUs;

  /// Karşı uçtan başlangıç ucuna dönen süre.
  final int ascentUs;

  /// Çevrimin uç noktasındaki eklem açısı — ROM hükmünün kaynağı.
  ///
  /// ⚠️ HANGİ uç olduğu [startedAtOpenEnd]'e bağlıdır: açık uçtan başlayan
  /// çevrimde bu MİNİMUM (şınavın dibi), kapalı uçtan başlayanda MAKSİMUM
  /// (tepe). İkisini aynı sütunda karşılaştırmak, 8° ile 179°'yi "anlaşmazlık"
  /// sanmaktır — bu tam olarak yaşandı, o yüzden ayrım artık TİPTE duruyor.
  final double extremeAngleDeg;

  /// Çevrim açık uçtan mı başladı? [extremeAngleDeg]'in anlamını belirler.
  final bool startedAtOpenEnd;

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
      {JointAngleExtractor? extractor,
      PoseNormalizer? normalizer,
      FrameJudge? judge,
      this.harvestIdentityAttested = false})
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

  /// HASAT yolu için açık dikiş: bu koşumun kimlik güvencesi ÜRÜN ön
  /// koşulundan DEĞİL, take-düzeyi hasat-kimlik kapısından geliyor.
  ///
  /// Neden gerekli: hasat, ön koşulu TÜRETECEK malzemeyi üreten yerdir —
  /// ondan "ön koşul zaten türetilmiş olsun" istemek yumurta-tavuk olur
  /// (aynı gerekçe `measure_knee_symmetry.dart`ta da yazılı). Ama bu bir
  /// muafiyet DEĞİL, kapı DEĞİŞİMİDİR: squat referansı meşru çünkü
  /// malzemesi hipKneeCoupling take-düzeyi kimlik kapısından geçti
  /// (12/16 eğitmen PASS, M-F-106/G-067) — kare-düzeyi ön koşul yerine
  /// take-düzeyi kanıt. Farklı sorular, farklı kapılar (G-039/G-048).
  ///
  /// ⚠️ ÜRÜN yolunda ASLA `true` verilmez: kullanıcının canlı denemesinin
  /// take-düzeyi bir hasat kapısı yoktur.
  final bool harvestIdentityAttested;

  /// Motorun neden hiç tekrar üretmediğinin İSİMLİ sebebi (null = red yok).
  ///
  /// M-F-122 hüküm 1 (fail-closed, koçlanan-durumlu): kimlik ön koşulu
  /// `derived` değilse motor tekrar ÜRETMEZ. Sebep G-071'de ölçüldü —
  /// `precondition.conditions` BOŞ olduğunda kimlik kapısı hiç kurulmuyordu
  /// (`isNotEmpty` false), yani squat'ta rep FSM'i hareketi değil sinyal
  /// ekleminin salınımını sayıyordu: ayakta duran birinin dizi de bükülür
  /// (G-043'ün şınavda kapattığı sınıf, squat'ta AÇIKTI). `status: pending`
  /// beyanı vardı ama ürün tarafında OKUYANI yoktu (beşinci canlılık
  /// sorusu, G-059).
  ///
  /// Sessiz sıfır DEĞİL: sebep isimlendirilir, UI bunu "ölçüm kapısı
  /// türetilmedi" durumu olarak gösterir (UI-BRIEF §5 "ölçülemedi" sınıfı,
  /// başarısızlık DEĞİL). Sessiz-yanlış sayım, sayım yokluğundan kötüdür
  /// (M-F-57 sayım dürüstlüğü).
  String? get refusalReason {
    if (config.preconditionDerived || harvestIdentityAttested) return null;
    return 'identity precondition not derived '
        '(engine.precondition.status=${config.preconditionStatus}) — '
        'reps are not counted, because counting without an identity gate '
        'counts limb swing, not ${config.id}';
  }

  bool get _refused => refusalReason != null;

  final List<Rep> _reps = <Rep>[];
  List<Rep> get reps => List<Rep>.unmodifiable(_reps);
  int get repCount => _reps.length;

  /// Hüküm verilemeyen kare sayısı — "analiz edemedim" oranının kaynağı.
  int skippedFrames = 0;

  /// Beyan edilen `minPhaseMs` tabanının ALTINA düşen faz sayısı (M-F-162).
  ///
  /// **SALT RAPOR — hiçbir tekrar bu yüzden reddedilmez.** Sebep G-054:
  /// sayım eşiği CÖMERT DIŞ SINIR olmak zorunda; sıkılaştırmak hata
  /// kuralını ulaşılamaz kılar ve kullanıcıyı sıfır-tekrar + sıfır-geri-
  /// bildirim durumunda bırakır (o hata bir kez yapıldı ve 5 harekette
  /// birden bulundu). Zorlama kararı ancak ölçülmüş dağılımdan verilir.
  ///
  /// Neden bu sayaç VAR: `minPhaseMs` config'de beyan ediliyor ve
  /// `MovementConfig` onu `minPhaseUs` olarak ayrıştırıyordu, ama
  /// **hiçbir motor/araç/test OKUMUYORDU** (G-081 — dördüncü ölü-config
  /// vakası, `preconditionStatus`/`unreliableJoints` ile aynı sınıf).
  /// Beyanı silmek yerine TÜKETİCİ verildi: taban artık ölçülüyor,
  /// zorlanmıyor.
  int phasesBelowMinMs = 0;

  /// Sayılan toplam faz (her tamamlanan tekrar 2 faz: iniş + çıkış).
  /// `phasesBelowMinMs / phasesCounted` oranı, zorlama kararının dayanağı
  /// olacak dağılımın kendisidir.
  int phasesCounted = 0;

  _End? _current;
  _End? _cycleStart;
  bool _visitedOther = false;
  int? _cycleStartUs;
  int? _midpointUs;
  double _extreme = double.nan;

  /// Uç değere ULAŞILAN an. Tempo eşik geçişinden DEĞİL buradan türetilir:
  /// sayım eşiği gevşediğinde (V16/G-054) eşik-tabanlı ölçüm iniş saatini
  /// erken durdurur — kullanıcı 80°'ye inse bile 116°'de "iniş bitti" der.
  /// Uç-tabanlı ölçüm eşikten BAĞIMSIZDIR ve gerçek dönüş anını verir.
  int? _extremeUs;

  /// Bir kareyi işler. [expected] verilirse yapısal denetim faz-eksen uyumunu
  /// da sınar (ADR-001 → ADR-002 zinciri).
  /// [size] ZORUNLUDUR: ham normalize koordinat anizotropiktir ve açı
  /// matematiğini en-boy oranı kadar bozar (J-028 / M-F-30). Varsayılan vermek,
  /// hatayı sessizce geri getirmek olurdu. Dönüşümün kendisi çekirdeğin kanonik
  /// `PoseFrame.toIsotropic` API'sindedir (M-F-33 yakınsama emri) — bu paket
  /// artık kendi kopyasını taşımaz.
  void addFrame(PoseFrame rawFrame, FrameSize size, {BodyOrientation? expected}) {
    // 0) Kimlik ön koşulu BEYAN EDİLMEMİŞSE hiç sayma (M-F-122 hüküm 1).
    //    Kareler `skippedFrames`e yazılır ki "hüküm veremedim" oranı dürüst
    //    kalsın; sebep `refusalReason`da İSİMLİ durur.
    if (_refused) {
      skippedFrames++;
      return;
    }
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
      final bool better = _cycleStart == _End.open ? deg < _extreme : deg > _extreme;
      if (better) {
        _extreme = deg;
        _extremeUs = tUs;
      }
    }

    final _End? here = _endAt(deg, c);
    if (here == null || here == _current) return;

    if (_cycleStart == null) {
      _cycleStart = here;
      _cycleStartUs = tUs;
      _extreme = deg;
      _extremeUs = tUs;
    } else if (here != _cycleStart) {
      _visitedOther = true;
      _midpointUs = tUs;
    } else if (_visitedOther) {
      _reps.add(Rep(
        index: _reps.length + 1,
        startUs: _cycleStartUs ?? tUs,
        endUs: tUs,
        // Dönüş anı = uç değere ulaşılan an; eşik geçişi DEĞİL.
        descentUs: (_extremeUs ?? _midpointUs ?? tUs) - (_cycleStartUs ?? tUs),
        ascentUs: tUs - (_extremeUs ?? _midpointUs ?? tUs),
        extremeAngleDeg: _extreme,
        startedAtOpenEnd: _cycleStart == _End.open,
      ));
      // Beyan edilen taban SALT-RAPOR olarak ölçülür (M-F-162) — tekrar
      // eklendikten SONRA, çünkü hüküm değişmiyor, yalnız gözlem yazılıyor.
      final Rep justAdded = _reps.last;
      for (final int phaseUs in <int>[
        justAdded.descentUs,
        justAdded.ascentUs,
      ]) {
        phasesCounted++;
        if (phaseUs < c.minPhaseUs) phasesBelowMinMs++;
      }
      _cycleStart = here;
      _cycleStartUs = tUs;
      _visitedOther = false;
      _midpointUs = null;
      _extreme = deg;
      _extremeUs = tUs;
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
    _extremeUs = null;
  }

  /// Bir tekrarın TEKRAR-KAPSAMLI metrikleri.
  ///
  /// Metriklerin kapsamı aynı değil ve bunu karıştırmak kuralı sessizce ÖLDÜRÜR:
  /// `line_deviation_deg` kare başına ölçülür, `rom_bottom_angle` ise ancak bir
  /// çevrim TAMAMLANINCA bilinir. Motor yalnız kare başına hüküm verdiği sürece
  /// tekrar-kapsamlı kurallar değerlendirilecek yer bulamaz — replay kapısı
  /// `partial_rom`'u tam bu yüzden ÖLÜ buldu: şemadan temiz, metriği kayıtlı,
  /// testi var ve gerçek kullanıcı için hiç ateşlenmiyordu.
  Map<String, double> repMetrics(Rep rep) => <String, double>{
        if (rep.startedAtOpenEnd)
          'rom_bottom_angle': rep.extremeAngleDeg
        else
          'rom_top_angle': rep.extremeAngleDeg,
      };

  /// Bir tekrar tamamlandığında söylenecek düzeltme (tekrar-kapsamlı kurallar).
  FormError? correctionFor(Rep rep) => topCorrection(repMetrics(rep));

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
