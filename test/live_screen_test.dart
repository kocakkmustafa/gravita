import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/live_session.dart';
import 'package:gravita/app/live_strings.dart';
import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_camera/motion_camera.dart';

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
}
