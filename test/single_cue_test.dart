import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/workout/feedback_controller.dart';
import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_core/motion_core.dart' show FeedbackDecision, FeedbackSeverity;

/// [LiveFeedbackController] — GRA-P1-004 Step 1/2. Adı roadmap'in KENDİ
/// dosya listesinden (`22-GRAVITA-MASTER-ROADMAP.md`): "tek düzeltme"
/// disiplinini sınıyor.
void main() {
  MovementConfig load(String id, {String wave = 'w1'}) => MovementConfig.parse(
      File('content/catalog/$wave/$id.json').readAsStringSync());

  /// [load] gibi ama sınıfı ZORLA verilen değere çeviriyor —
  /// `rep_engine_test.dart`nın `loadWithPreconditionStatus` deseniyle AYNI
  /// teknik: gerçek bir hareketin BUGÜNKÜ sınıfına bağlı kalmadan "sınıfı
  /// B olsaydı ne olurdu" sınamak için.
  MovementConfig loadAsClass(String id, String forcedClass, {String wave = 'w1'}) {
    final Map<String, dynamic> j = jsonDecode(
        File('content/catalog/$wave/$id.json').readAsStringSync())
        as Map<String, dynamic>;
    j['class'] = forcedClass;
    return MovementConfig.fromJson(j);
  }

  // `rep_engine_test.dart`ın KENDİ kanıtladığı, GERÇEKTEN ateşleyen metrik
  // seti (`bodyweight_squat` + bu üçlü → `butt_wink`, priority 'safety') —
  // burada AYNEN tekrar kullanılıyor: "hiçbir şey zaten ateşlemiyordu"
  // tesadüfüyle karışmasın diye, sahte-negatif riskini SIFIRLAYAN seçim.
  const Map<String, double> firingMetrics = <String, double>{
    'rom_bottom_angle': 130,
    'torso_angle_from_vertical': 55,
    'lumbar_flexion_proxy': 26,
  };

  // Yalnız `excessive_forward_lean`i (priority 'major_alignment') ateşler —
  // `lumbar_flexion_proxy` metriği HİÇ verilmiyor, o yüzden 'butt_wink'
  // (safety) ateşleyemez. Cooldown testleri BUNU kullanır: 'safety' önceliği
  // `FeedbackPrioritizer`da BİLEREK cooldown'u bypass eder ("risk sürdükçe
  // tekrar söylenir" — `feedback_prioritizer.dart:6-7`), o yüzden NORMAL
  // bastırmayı sınamak için safety-DIŞI bir düzeltme gerekir.
  const Map<String, double> nonSafetyFiringMetrics = <String, double>{
    'torso_angle_from_vertical': 55,
  };

  group('Step 1 — sınıf B asla form hükmü ÜRETMEZ', () {
    test(
        'GERÇEKTEN ateşleyen metriklerle BİLE — negatif test, tesadüf DEĞİL',
        () {
      final MovementConfig squatAsB = loadAsClass('bodyweight_squat', 'B');
      expect(squatAsB.claimsFormVerdict, isFalse);

      // ⚖️ TANIK — bu fixture'ın GERÇEKTEN anlamlı olduğunu kanıtlar: motor
      // GATE'SİZ sorulsaydı bir şey ATEŞLERDİ. Bu satır düşerse test kendi
      // iddiasını ÖLÇMÜYOR demektir (boş bir "hiçbir şey olmadı" testi).
      final RepEngine ungated = RepEngine(squatAsB);
      expect(ungated.topCorrection(firingMetrics), isNotNull,
          reason: 'fixture GERÇEKTEN ateşlemiyorsa aşağıki ret hiçbir şey '
              'KANITLAMAZ — sessizlik ya sınıf-kapısından ya da tesadüften '
              'gelebilir, ikisini AYIRT ETMEK bu satırın işi.');

      final LiveFeedbackController controller = LiveFeedbackController();
      final RepEngine engine = RepEngine(squatAsB);
      final FeedbackDecision d =
          controller.evaluate(engine: engine, metrics: firingMetrics, tUs: 0);

      expect(d.willSpeak, isFalse);
      expect(d.suppressedReason, contains('does not claim form verdict'));
    });

    test('sınıf C katalogda hiç YOK — MovementClass enum\'ında temsili yok',
        () {
      // Üçüncü katman: tip sistemi. `MovementClass` yalnız a/b/d taşır —
      // "C" değerini temsil eden bir üye YOK, bu yüzden runtime'da bir
      // MovementConfig'in classı asla C OLAMAZ (derleme-zamanı garanti).
      expect(MovementClass.values.map((MovementClass c) => c.name),
          <String>['a', 'b', 'd']);
    });
  });

  group('Step 1 — sınıf A/D form hükmü ÜRETİR, tek adayla', () {
    test('gerçek bodyweight_squat (sınıf A) — doğru kod + önem derecesi', () {
      final MovementConfig squat = load('bodyweight_squat');
      expect(squat.claimsFormVerdict, isTrue);

      final LiveFeedbackController controller = LiveFeedbackController();
      final RepEngine engine = RepEngine(squat);
      final FeedbackDecision d =
          controller.evaluate(engine: engine, metrics: firingMetrics, tUs: 0);

      expect(d.willSpeak, isTrue);
      expect(d.candidate!.code, 'butt_wink');
      expect(d.candidate!.severity, FeedbackSeverity.safety,
          reason: "motorun 'safety' önceliği motion_core'un "
              'FeedbackSeverity.safety\'sine eşlenmeli.');
    });

    test('düzeltme ateşlemiyorsa sessizlik — "sessizlik yanlış söylemekten '
        'iyidir" (rep_engine_test.dart\'ın AYNI ilkesi)', () {
      final MovementConfig pushUp = load('push_up');
      final LiveFeedbackController controller = LiveFeedbackController();
      final RepEngine engine = RepEngine(pushUp);
      final FeedbackDecision d = controller.evaluate(
          engine: engine, metrics: <String, double>{'line_deviation_deg': 3}, tUs: 0);

      expect(d.willSpeak, isFalse);
      expect(d.suppressedReason, contains('no correction firing'));
    });
  });

  group('Step 2 — cooldown: aynı anda en fazla BİR şey söylenir', () {
    test('aynı kod hemen tekrar ateşlerse BASTIRILIR', () {
      final MovementConfig squat = load('bodyweight_squat');
      final LiveFeedbackController controller = LiveFeedbackController();
      final RepEngine engine = RepEngine(squat);

      final FeedbackDecision first = controller.evaluate(
          engine: engine, metrics: nonSafetyFiringMetrics, tUs: 0);
      expect(first.willSpeak, isTrue);
      expect(first.candidate!.severity, FeedbackSeverity.major,
          reason: 'bu fixture BİLEREK safety-DIŞI — cooldown\'un kendisini '
              'sınıyoruz, safety\'nin bypass ayrıcalığını değil.');

      // ⚠️ 1 saniye sonra — hem global (2.5s) hem kod-bazlı (8s) cooldown
      // içinde, İKİSİ de bu turu bastırmalı.
      final FeedbackDecision second = controller.evaluate(
          engine: engine, metrics: nonSafetyFiringMetrics, tUs: 1000000);
      expect(second.willSpeak, isFalse,
          reason: 'Aynı hatayı arka arkaya söylemek "coach durmadan aynı '
              'cümleyi tekrarlıyor" deneyimi yaratır — motion_core\'un '
              'kendi FeedbackPrioritizer\'ı bunu bastırmalı.');
    });

    test('global cooldown geçince AYNI kod yeniden söylenebilir', () {
      final MovementConfig squat = load('bodyweight_squat');
      final LiveFeedbackController controller = LiveFeedbackController();
      final RepEngine engine = RepEngine(squat);

      controller.evaluate(
          engine: engine, metrics: nonSafetyFiringMetrics, tUs: 0);
      // Kod-bazlı cooldown (varsayılan 8s) da geçecek kadar ileri —
      // sonsuza dek susmadığını, yalnız GEÇİCİ bir bekleme olduğunu kanıtlar.
      final FeedbackDecision third = controller.evaluate(
          engine: engine, metrics: nonSafetyFiringMetrics, tUs: 9000000);
      expect(third.willSpeak, isTrue,
          reason: 'Bastırma KALICI değil — cooldown süresi dolunca aynı '
              'gerçek hata yeniden söylenebilmeli, aksi hâlde kullanıcı '
              'düzeltmeden habersiz kalırdı.');
    });

    test('reset() sonrası cooldown geçmişi TEMİZLENİR — yeni seans', () {
      final MovementConfig squat = load('bodyweight_squat');
      final LiveFeedbackController controller = LiveFeedbackController();
      final RepEngine engine = RepEngine(squat);

      controller.evaluate(
          engine: engine, metrics: nonSafetyFiringMetrics, tUs: 0);
      controller.reset();
      final FeedbackDecision afterReset = controller.evaluate(
          engine: engine, metrics: nonSafetyFiringMetrics, tUs: 1);
      expect(afterReset.willSpeak, isTrue,
          reason: 'Yeni bir seans önceki seansın cooldown\'ını MİRAS '
              'ALMAMALI.');
    });

    test(
        'GÜVENLİK önceliği cooldown\'u BYPASS EDER — risk sürdükçe tekrar '
        'söylenir', () {
      // `firingMetrics` BİLEREK burada: `butt_wink` (priority 'safety').
      // `FeedbackPrioritizer`ın KENDİ tasarım kararı (`feedback_prioritizer.
      // dart:6-7`: "Risk of injury — always wins, always allowed to
      // interrupt") — normal cooldown testinin YANLIŞ fixture'ı SEÇİLDİĞİNDE
      // ilk yazımda ölçümle bulunan bir davranış; burada KASITLI bir iddiaya
      // çevrildi, sessizce atılmadı.
      final MovementConfig squat = load('bodyweight_squat');
      final LiveFeedbackController controller = LiveFeedbackController();
      final RepEngine engine = RepEngine(squat);

      final FeedbackDecision first =
          controller.evaluate(engine: engine, metrics: firingMetrics, tUs: 0);
      expect(first.candidate!.severity, FeedbackSeverity.safety);

      final FeedbackDecision second = controller.evaluate(
          engine: engine, metrics: firingMetrics, tUs: 1000000);
      expect(second.willSpeak, isTrue,
          reason: 'Bir güvenlik uyarısı normal cooldown\'a tabi olsaydı, '
              'kullanıcı riskli formu SÜRDÜRÜRKEN coach 2.5 saniye sessiz '
              'kalırdı — kabul edilemez.');
    });
  });
}
