import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/content_failure.dart';
import 'package:gravita/app/content_failure_screen.dart';
import 'package:gravita/app/progress_strings.dart';
import 'package:gravita/app/progress_view.dart';
import 'package:gravita_engine/gravita_engine.dart';

/// Dürüst hata ekranı — JabLab `6601b1b` uyarlamasının testleri + Gravita
/// deltası ([HistoryFailure]).
///
/// M-F-194 uygulanıyor: her "X yok" kapısının yanında "X var" ikizi var.
void main() {
  group('sınıflandırma METİNDEN değil TİPTEN', () {
    test('ContentIntegrityException → integrity, ihlaller detayda', () {
      final ContentFailure f = ContentFailure.from(
          const ContentIntegrityException(<String>['a bozuk', 'b eksik']));
      expect(f.kind, ContentFailureKind.integrity);
      expect(f.detail, contains('a bozuk'));
      expect(f.detail, contains('b eksik'));
    });

    test('StateError/ArgumentError → integrity (dosya OKUNDU, içeriği tutmuyor)',
        () {
      // `ContentRepository` eksik `wave` beyanını böyle bildiriyor.
      expect(ContentFailure.from(StateError('wave yok')).kind,
          ContentFailureKind.integrity);
      expect(ContentFailure.from(ArgumentError('bozuk config')).kind,
          ContentFailureKind.integrity);
    });

    test('bilinmeyen tip → unreadable (yanlış tarafa düşmek gerekiyorsa BU taraf)',
        () {
      // "Yeniden kurmayı dene" demek, "bu bizim içerik hatamız" demekten daha
      // az yanlış: ikincisi kullanıcıya bizim adımıza teşhis koyar.
      expect(ContentFailure.from(Exception('io')).kind,
          ContentFailureKind.unreadable);
      expect(ContentFailure.from(FlutterError('asset missing').toString()).kind,
          ContentFailureKind.unreadable);
    });
  });

  group('ekran değişmezleri', () {
    Future<void> pump(WidgetTester tester, ContentFailure f,
            {bool withRetry = true}) =>
        tester.pumpWidget(MaterialApp(
          home: ContentFailureScreen(
            failure: f,
            onRetry: withRetry ? () async {} : null,
          ),
        ));

    testWidgets('unreadable: "Try again" VAR', (WidgetTester tester) async {
      await pump(
          tester,
          const ContentFailure(
              kind: ContentFailureKind.unreadable, detail: 'io'));
      expect(find.byKey(ContentFailureScreen.retryKey), findsOneWidget);
    });

    testWidgets('integrity: "Try again" YOK — aynı asset aynı sonucu verir',
        (WidgetTester tester) async {
      await pump(
          tester,
          const ContentFailure(
              kind: ContentFailureKind.integrity, detail: 'ihlal'));
      // Yokluk kapısı; POZİTİF İKİZİ bir üstteki testtir (M-F-194) — retry
      // düğmesi HİÇBİR koşulda çizilmiyorsa bu iddia bedavaya geçerdi.
      expect(find.byKey(ContentFailureScreen.retryKey), findsNothing);
    });

    testWidgets('onRetry verilmezse retry sunulmaz — ekran retry UYDURMAZ',
        (WidgetTester tester) async {
      await pump(
          tester,
          const ContentFailure(
              kind: ContentFailureKind.unreadable, detail: 'io'),
          withRetry: false);
      expect(find.byKey(ContentFailureScreen.retryKey), findsNothing);
    });

    testWidgets('"Yine de devam et" HİÇ YOK — kaçış kapısı doğrulamayı süs yapar',
        (WidgetTester tester) async {
      for (final ContentFailureKind k in ContentFailureKind.values) {
        await pump(tester, ContentFailure(kind: k, detail: 'x'));
        final Iterable<String> labels = tester
            .widgetList<Text>(find.byType(Text))
            .map((Text t) => (t.data ?? '').toLowerCase());
        for (final String l in labels) {
          expect(
              l.contains('continue') ||
                  l.contains('anyway') ||
                  l.contains('skip') ||
                  l.contains('ignore'),
              isFalse,
              reason: '$k ekranında kaçış kapısı metni: "$l"');
        }
      }
    });

    testWidgets('MAKİNE metni BİRİNCİL olamaz — başlık insan cümlesi',
        (WidgetTester tester) async {
      const String raw = "Bad state: library.json: x `wave` bildirmiyor";
      await pump(tester,
          ContentFailure.from(StateError('library.json: x `wave` bildirmiyor')));
      final String headline =
          tester.widget<Text>(find.byKey(ContentFailureScreen.headlineKey)).data!;
      expect(headline, isNot(contains('wave')));
      expect(headline, isNot(contains('Bad state')));
      expect(raw, contains('wave')); // ham metnin ne olduğu kayıtta

      // ⚠️ Ayrıntı KATLANMIŞ bir `ExpansionTile` içinde: açılmadan widget
      // ağacında YOK. İlk yazışımda bunu bilmeden aradım ve test "Bad state:
      // No element" ile düştü. İki yanlış sonuç mümkündü: (a) benim gibi
      // düşmek, (b) daha kötüsü — `findsNothing` yazıp "ayrıntı gizlenmiş"
      // diye YANLIŞ bir dürüstlük iddiası kurmak. Doğrusu: AÇ ve ULAŞILDIĞINI
      // kanıtla. "Gizlenmedi, ikincilleştirildi" ancak erişilebilirse doğrudur.
      await tester.tap(find.text('Technical detail'));
      await tester.pumpAndSettle();
      final String detail = tester
          .widget<SelectableText>(find.byKey(ContentFailureScreen.detailKey))
          .data!;
      expect(detail, contains('wave'),
          reason: 'Ayrıntı ikincil katmanda DURMAK zorunda — sahada tek '
              'teşhis malzemesi o metin.');
    });

    testWidgets('gövde suçu KULLANICIYA atmıyor (integrity "bizde")',
        (WidgetTester tester) async {
      await pump(
          tester,
          const ContentFailure(
              kind: ContentFailureKind.integrity, detail: 'x'));
      final String body =
          tester.widget<Text>(find.byKey(ContentFailureScreen.bodyKey)).data!;
      expect(body, contains('on us'));
      expect(body.toLowerCase(), isNot(contains('your fault')));
    });
  });

  group('⭐ GRAVITA DELTASI — geçmiş okunamadı, içerik sağlam', () {
    const LessonSurface reps = LessonSurface(
      id: 'push_foundations.reps_and_tempo',
      displayName: 'Reps that count',
      unitLabel: 'rep',
      gradedToday: false,
    );

    Future<void> pump(WidgetTester tester, {HistoryFailure? failure}) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProgressView(
            summary: ProgressSummary.build(
              lessonSurfaces: const <LessonSurface>[reps],
              records: const <SessionRecord>[],
            ),
            historyFailure: failure,
          ),
        ),
      ));
    }

    testWidgets('geçmiş okunamadıysa "Not started" DEMİYOR — beyan ediyor',
        (WidgetTester tester) async {
      // Bu testin varlık sebebi kendi kodumdaki bir yalandı: kayıt listesi boş
      // gelince her ders `notStarted` oluyor ve yüzey "Not started" yazıyor —
      // depo okunamadığında bu cümle "hiç çalışmadın" demektir.
      await pump(tester, failure: const HistoryFailure('permission denied'));
      expect(find.byKey(ProgressView.historyFailureKey), findsOneWidget);
      expect(find.text(ProgressStrings.notStarted), findsNothing);
      expect(find.text(ProgressStrings.emptyHistory), findsNothing);
    });

    testWidgets('POZİTİF İKİZ: geçmiş SAĞLAMSA beyan GÖRÜNMEZ, "Not started" var',
        (WidgetTester tester) async {
      // M-F-194: yukarıdaki yokluk iddiaları, `notStarted` metni hiç
      // çizilmiyorsa da geçerdi. Bu ikiz o boşluğu kapatıyor.
      await pump(tester);
      expect(find.byKey(ProgressView.historyFailureKey), findsNothing);
      expect(find.text(ProgressStrings.notStarted), findsOneWidget);
    });

    testWidgets('beyan SAYI göstermiyor — bilmediğimizi sıfır yazmıyoruz',
        (WidgetTester tester) async {
      await pump(tester, failure: const HistoryFailure('io'));
      final RegExp anyCount = RegExp(r'\b\d+\s+(reps?|seconds?|sessions?)\b');
      for (final Text t in tester.widgetList<Text>(find.byType(Text))) {
        expect(anyCount.hasMatch(t.data ?? ''), isFalse,
            reason: 'Geçmiş okunamazken sayı gösterildi: "${t.data}"');
      }
    });
  });
}
