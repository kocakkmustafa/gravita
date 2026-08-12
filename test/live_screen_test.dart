import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/live_session.dart';
import 'package:gravita/app/live_strings.dart';
import 'package:gravita_engine/gravita_engine.dart';
import 'package:gravita/app/live_session_screen.dart';
import 'package:motion_camera/motion_camera.dart';

import 'support/launch_harness.dart';

/// Canlı seans YÜZEYİ — her hâlin ekranda ne dediği.
///
/// ⚠️ Bu süit kamerayı SÜRMÜYOR: `LiveSessionScreen` native kanal açıyor ve
/// widget testinde o kanal yok. Sınanan şey **hâl → metin** eşlemesi, yani
/// `LiveStrings` sözleşmesi ve hâllerin ayrılığı. Ekranın kendi kablolaması
/// simülatörde görüldü (G-120 ekran kanıtları), canlı zincir ise
/// `live_session_test.dart`te gerçek motorla koşuyor.
void main() {
  MovementConfig load() => MovementConfig.parse(
      File('packages/gravita_engine/../../content/catalog/w1/push_up.json')
          .readAsStringSync());

  group('hâl → metin sözleşmesi', () {
    test('her tanınan arıza AYRI başlık ve gövde alıyor', () {
      final Set<String> titles = <String>{};
      final Set<String> bodies = <String>{};
      for (final CameraFailure f in CameraFailure.values) {
        titles.add(LiveStrings.failureTitle(f));
        bodies.add(LiveStrings.failureBody(f));
      }
      expect(titles.length, CameraFailure.values.length,
          reason: 'İki arıza aynı cümleyi paylaşıyorsa biri diğerinin '
              'arkasına saklanır.');
      expect(bodies.length, CameraFailure.values.length);
    });

    test('tanınmayan arıza da ADLANDIRILIYOR — boş bırakılmıyor', () {
      expect(LiveStrings.failureTitle(null), isNotEmpty);
      expect(LiveStrings.failureBody(null), isNotEmpty);
      expect(LiveStrings.failureTitle(null).toLowerCase(),
          contains("don't recognise"),
          reason: 'Bilinmeyeni bilinen bir arıza gibi sunmak yalan olur.');
    });

    test('izin metni gizliliği SÖYLÜYOR — kamera istemek açıklama ister', () {
      final String body =
          LiveStrings.failureBody(CameraFailure.permissionDenied).toLowerCase();
      expect(body, contains('never leaves'),
          reason: 'Kamera izni isterken verinin nereye gittiğini söylemeyen '
              'metin, izni hak etmiyor.');
    });

    test('sayım metni SKOR DEĞİL diyor', () {
      expect(LiveStrings.countingNote.toLowerCase(), contains('not scored'));
      expect(LiveStrings.reps(1), '1 rep');
      expect(LiveStrings.reps(3), '3 reps');
    });

    test('tekrar yokken "0" YAZILMIYOR — ne beklendiği söyleniyor', () {
      // "0 reps" teknik olarak doğru ama kullanıcıya bir HÜKÜM gibi okunur.
      expect(LiveStrings.noRepsYet.toLowerCase(), isNot(contains('0 ')));
      expect(LiveStrings.noRepsYet, isNotEmpty);
    });

    test('kalibrasyon kapısı beyanı doğrulanmayanı ATTIĞINI söylüyor', () {
      expect(LiveStrings.gateNote.toLowerCase(), contains('rather than guessed'),
          reason: 'Kapının varlığı değil, DAVRANIŞI beyan edilir.');
    });
  });

  group('hâller birbirinin yerine geçmiyor', () {
    test('"kimse yok" LiveRunning içinde, LiveFailed DEĞİL', () {
      const LiveState s =
          LiveRunning(reps: <Rep>[], personVisible: false, framesSeen: 3);
      expect(s, isA<LiveRunning>());
      expect(s, isNot(isA<LiveFailed>()));
    });

    test('POZİTİF İKİZ: gerçek arıza LiveFailed, LiveRunning DEĞİL', () {
      const LiveState s = LiveFailed(CameraFailure.noSuchCamera);
      expect(s, isA<LiveFailed>());
      expect(s, isNot(isA<LiveRunning>()));
    });
  });

  group('canlı giriş: ölü buton yok', () {
    testWidgets('kimlik ön koşulu DERIVED olan hareket canlı yola uygun',
        (WidgetTester tester) async {
      // FAB'ın çizilme koşulu bu; koşul kayarsa buton ölü butona dönerdi.
      expect(load().preconditionDerived, isTrue);
    });

    testWidgets('LiveStrings.title ekranda kullanılabilir bir etiket',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: Text(LiveStrings.title))));
      expect(find.text(LiveStrings.title), findsOneWidget);
    });
  });

  /// ⭐ KALICI RET — G-185. Koordinatörün aile taraması bende `permanentlyDenied`
  /// için SIFIR isabet bulmuştu ve ölçüm onu doğruladı: kusur eksiklik değil
  /// **ayrımsızlıktı** — üç hâl de `!isGranted` kovasına düşüyordu.
  ///
  /// Bu grup ekranı GERÇEKTEN pump ediyor ve izin kanalını yanıtlıyor;
  /// sınanan şey "hangi hâl doğdu" değil **kullanıcının ekranda ne
  /// görebildiği ve neye basabildiği**.
  group('kamera izni KALICI reddedildiğinde ölü döngü YOK', () {
    Future<void> pumpScreen(WidgetTester tester, {required int status}) async {
      mockPermissionChannel(status: status);
      await tester.pumpWidget(MaterialApp(
          home: LiveSessionScreen(config: load(), controller: _NoCamera())));
      await tester.tap(find.byKey(LiveSessionScreen.startButtonKey));
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    testWidgets('kalıcı ret: Settings eylemi ÇİZİLİR, Start çizilmez',
        (WidgetTester tester) async {
      await pumpScreen(tester, status: 4); // permanentlyDenied

      expect(find.byKey(LiveSessionScreen.openSettingsKey), findsOneWidget,
          reason: 'İşe yarayan TEK eylem bu; yoksa metin Settings diyor ama '
              'oraya götüren hiçbir kontrol olmuyor.');
      expect(find.byKey(LiveSessionScreen.startButtonKey), findsNothing,
          reason: 'Basılabilir ama ASLA başarılı olamayacak bir düğme, ölü '
              'butondan farksızdır.');
      expect(find.text(LiveStrings.permissionBlockedTitle), findsOneWidget);
    });

    testWidgets('KISITLI cihaz (MDM/ebeveyn) da aynı yere düşer',
        (WidgetTester tester) async {
      // `isRestricted` sezgiyle bulunamaz: diyalog HİÇ çıkmaz, yani
      // "ikinci ret = kalıcı" sezgisi bu vakayı İLKECE göremez.
      await pumpScreen(tester, status: 2); // restricted

      expect(find.byKey(LiveSessionScreen.openSettingsKey), findsOneWidget);
      expect(find.byKey(LiveSessionScreen.startButtonKey), findsNothing);
    });

    testWidgets(
        'POZİTİF İKİZ — GEÇİCİ rette Start KALIR, Settings çizilmez',
        (WidgetTester tester) async {
      // Bu ikiz olmadan üstteki iki test, Start düğmesini HER arızada gizleyen
      // bir uygulamada da geçerdi. Geçici rette tekrar denemek ANLAMLI:
      // sistem diyaloğu bir daha çıkar.
      await pumpScreen(tester, status: 0); // denied

      expect(find.byKey(LiveSessionScreen.startButtonKey), findsOneWidget);
      expect(find.byKey(LiveSessionScreen.openSettingsKey), findsNothing);
      expect(find.text(LiveStrings.permissionBlockedTitle), findsNothing);
    });

    testWidgets('ham durum ADIYLA gösteriliyor — sabit "denied" değil',
        (WidgetTester tester) async {
      // Eski kod `detail`e SABİT 'permission_handler: denied' yazıyordu:
      // gerçek durum `permanentlyDenied` olsa bile "denied" diyordu.
      await pumpScreen(tester, status: 4);
      expect(find.textContaining('permanentlyDenied'), findsOneWidget);
    });
  });
}

/// Kamera AÇILMADAN önce izin kapısına takılıyoruz; bu denetleyicinin hiçbir
/// üyesi çağrılmamalı. Çağrılırsa test ADIYLA düşsün — sessiz bir sahte,
/// izin kapısının atlandığını gizlerdi.
class _NoCamera implements MotionCameraController {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('İzin kapısı geçilmemeliydi: ${invocation.memberName}');
}
