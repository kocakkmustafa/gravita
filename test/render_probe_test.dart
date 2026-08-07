import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/library_model.dart';
import 'package:gravita/app/movement_page.dart';
import 'package:gravita/app/progress_strings.dart';
import 'package:gravita/app/progress_view.dart';
import 'package:gravita/app/theme.dart';
import 'package:gravita_engine/gravita_engine.dart';

/// ⭐ RENDER PROBU — ekranın GERÇEKTEN ne yazdığını basar ve sınar.
///
/// > **Render probu = içerik/olgu doğrulaması · Sim = ALGI doğrulaması.**
///
/// JabLab bir P0'ı (*"seans özeti her zaman 0 diyor"*) **sim olmadan**, bu
/// yöntemle buldu. Bu hattın `c3cb694` turunda simülatörle iki kusur
/// bulunmuştu (`Parallel_bars` · görünmez düğme) — ama o tur **elle** ve
/// **bir kez** yapılabilir; render probu onu **her terfide tekrarlanabilir**
/// kılıyor.
///
/// Sim'in yerini ALMAZ: kontrast, hiza, çakışma, dokunulabilirlik ALGI
/// sorularıdır ve gözle ölçülür. Bu dosya OLGUYU ölçer — sayı doğru mu,
/// cümle doğru mu, ham anahtar sızıyor mu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host(Widget child) =>
      MaterialApp(theme: GravitaTheme.light, home: child);

  /// Ağaçtaki tüm görünür metni toplar — ekranın SÖYLEDİĞİ şey.
  List<String> renderedText(WidgetTester tester) => find
      .byType(Text, skipOffstage: false)
      .evaluate()
      .map((Element e) => (e.widget as Text).data)
      .whereType<String>()
      .where((String s) => s.trim().isNotEmpty)
      .toList();

  testWidgets('PROGRESS — gerçek bir seanstan sonra ne yazıyor?',
      (WidgetTester tester) async {
    // ⚠️ Koordinatörün sorusu buydu: *"Progress ekranı BUGÜN ne gösteriyor?"*
    // Cevap iddiayla değil, ekranın kendi metniyle veriliyor.
    tester.view.physicalSize = const Size(375, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late ContentRepository c;
    await tester.runAsync(() async => c = await ContentRepository.load(rootBundle));

    // 12 tekrarlık GERÇEK bir serbest seans.
    final SessionRecord free = SessionRecord(
      lessonId: ContentRepository.freeSessionKey('push_up'),
      completedAt: DateTime.utc(2026, 8, 7, 11),
      workedSeconds: 240,
      unitsCompleted: 12,
      plannedUnits: 0,
      unitLabel: 'rep',
      lessonClass: 'measurementOnly',
    );

    await tester.pumpWidget(host(Scaffold(
      body: ProgressView(
        summary: ProgressSummary.build(
          lessonSurfaces: c.lessonSurfaces,
          records: const <SessionRecord>[],
        ),
        freeSessions: <SessionRecord>[free],
      ),
    )));
    await tester.pump();

    final List<String> shown = renderedText(tester);
    // Kanıt olarak basılıyor: bir sonraki tur "Progress ne diyor" diye
    // sormak zorunda kalmasın.
    debugPrint('── PROGRESS EKRANI (12 tekrarlık seans sonrası) ──');
    for (final String s in shown) {
      debugPrint('  • ${s.length > 100 ? '${s.substring(0, 100)}…' : s}');
    }

    // ⭐ J-156 sınıfı: ÖLÇÜLEN SAYI KAYBOLMAMALI. Ekran 12'yi yazmalı.
    expect(shown.any((String s) => s.contains('12 reps')), isTrue,
        reason: 'Seansta 12 tekrar sayıldı ama ekran onu YAZMIYOR — '
            'ölçülen atılıp yerine yanlış görünüyor (J-156).');

    // Ve "0" YAZMAMALI: kaybın en kötü hâli sessizlik değil, YANLIŞ SAYI.
    expect(shown.any((String s) => RegExp(r'\b0 reps?\b').hasMatch(s)), isFalse,
        reason: 'Ekran "0 rep" yazıyor — ölçülen sayı kaybolmuş ve yerine '
            'sıfır konmuş.');

    // Serbest seansın AYRI tutulduğu da yazılı olmalı (G-132 hükmü).
    expect(shown, contains(ProgressStrings.freeSubtitle));
  });

  testWidgets('HAREKET SAYFASI — 31 hareketin çizdiği metin dökülüyor',
      (WidgetTester tester) async {
    // 28 terfi sonrası bu prob elle gözden geçirilebilir bir DÖKÜM verir:
    // dürüstlük kutusu doğru mu, sayılar doğru mu, ham anahtar var mı.
    tester.view.physicalSize = const Size(375, 12000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late ContentRepository c;
    await tester.runAsync(() async => c = await ContentRepository.load(rootBundle));

    int totalLines = 0;
    for (final MovementEntry m in c.catalogue.movements) {
      await tester.pumpWidget(host(MovementPage(movement: m, content: c)));
      await tester.pump();
      final List<String> shown = renderedText(tester);
      totalLines += shown.length;

      // Her sayfa EN AZ bu dördünü söylemeli — boş bir sayfa sessizce
      // "hazır" görünmesin.
      expect(shown, contains(m.displayName), reason: '${m.id}: adı yok');
      expect(shown.any((String s) => s == m.blurb), isTrue,
          reason: '${m.id}: özeti yok');
      expect(
          shown.any((String s) =>
              s.contains('camera') || s.contains('measure') ||
              s.contains('rules') || s.contains('score')),
          isTrue,
          reason: '${m.id}: sayfada tek bir ölçüm/sınır cümlesi bile yok');
    }

    debugPrint('── RENDER PROBU: ${c.catalogue.movements.length} hareket '
        'sayfası, toplam $totalLines görünür metin satırı ──');
    // Kapsam sessizce küçülmesin: 31 sayfa × ortalama 15+ satır.
    expect(totalLines, greaterThan(c.catalogue.movements.length * 10),
        reason: 'Sayfalar beklenenden çok daha az şey söylüyor — bir blok '
            'sessizce düşmüş olabilir.');
  });
}
