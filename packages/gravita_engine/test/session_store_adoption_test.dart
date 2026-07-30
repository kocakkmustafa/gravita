import 'dart:convert';
import 'dart:io';

import 'package:gravita_engine/gravita_engine.dart';
import 'package:test/test.dart';

/// SessionStore ÇEKİRDEK ADOPSİYONU — tüketici-tarafı sözleşme testleri.
///
/// Yerel port SİLİNDİ (çekirdek `motion_core-v0.9.0`, M-F-193 hakemliği). Ama
/// **delta testleri taşındı, silinmedi**: Gravita'nın DAYANDIĞI davranışları
/// artık çekirdek üzerinde iddia ediyorlar. Gerekçe basit — bir sonraki çekirdek
/// sürümü `isComplete`i tekrar `unitsCompleted` tabanına döndürürse bunu
/// kullanıcı değil bu dosya söyler.
///
/// Bu testler JabLab'ın arıza-davranışlarını (bozuk satır · yarım satır ·
/// bilinmeyen sürüm) TEKRAR ETMİYOR: onlar artık çekirdeğin kendi süitinde ve
/// orada olmaları doğru. Buradakiler ÜÇ DELTA + çekirdeğin adopsiyonla gelen
/// DAVRANIŞ DEĞİŞİKLİKLERİ.
void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('gravita_adoption');
    file = File('${dir.path}/sessions.jsonl');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  SessionRecord rec({
    String lessonId = 'push_foundations.reps_and_tempo',
    int worked = 120,
    int done = 5,
    int planned = 5,
    String unit = 'rep',
    String lessonClass = 'measurementOnly',
    int unmeasured = 0,
    String? reason,
  }) =>
      SessionRecord(
        lessonId: lessonId,
        completedAt: DateTime.utc(2026, 7, 30, 12),
        workedSeconds: worked,
        unitsCompleted: done,
        plannedUnits: planned,
        unitLabel: unit,
        lessonClass: lessonClass,
        unmeasuredUnits: unmeasured,
        unmeasuredReason: reason,
      );

  test('DELTA 1 — birim etiketi KAYIT-başına, aynı depoda iki farklı birim',
      () async {
    final JsonlSessionStore store = JsonlSessionStore(file);
    await store.append(rec(unit: 'rep', done: 5));
    await store.append(
        rec(lessonId: 'hold_foundations.plank', unit: 'second', done: 45));
    final List<SessionRecord> back = await store.recent();
    expect(back.map((SessionRecord r) => r.unitLabel).toSet(),
        <String>{'rep', 'second'});
  });

  group('DELTA 2 — lessonClass AÇIK SÖZLÜK + EN AZ YETKİLİ okuma', () {
    test('yalnız "scored" skorlanmış okunur', () {
      expect(rec(lessonClass: 'scored').isScoredClass, isTrue);
    });

    // "X değil" kapısının POZİTİF İKİZİ yukarıda (M-F-194): aşağıdaki liste
    // olumsuzu tarıyor, yukarıdaki tek satır kapının hiç ateşlenebildiğini
    // gösteriyor. İkizi olmayan yokluk-kapısı kendi yazım hatasını göremez —
    // `isScoredClass` her zaman false dönseydi aşağıdaki 5 vaka da geçerdi.
    test('bilinmeyen · boş · app-özel sınıf ASLA skorlanmış okunmaz', () {
      for (final String c in <String>[
        'measurementOnly',
        'demoOnly',
        '',
        'Scored',
        'sCoReD',
      ]) {
        expect(rec(lessonClass: c).isScoredClass, isFalse, reason: 'sınıf: "$c"');
      }
    });

    test('Gravita\'nın sözcüğü aynen taşınıyor — "measurementOnly" yuvarlanır',
        () async {
      final JsonlSessionStore store = JsonlSessionStore(file);
      await store.append(rec(lessonClass: 'measurementOnly'));
      expect((await store.recent()).single.lessonClass, 'measurementOnly');
    });
  });

  group('DELTA 3 — ölçülemeyen birim + ATTEMPTED üzerinden tamamlama', () {
    test('attemptedUnits ölçülen + ölçülemeyen', () {
      expect(rec(done: 3, unmeasured: 1).attemptedUnits, 4);
    });

    test('⚠️ DAVRANIŞ DEĞİŞİKLİĞİ: tamamlama ATTEMPTED sayar (portumda DEĞİLDİ)',
        () {
      // Yerel portumda `isComplete => unitsCompleted >= plannedUnits`'ti; yani
      // ölçülemeyen bir tekrar seansı TAMAMLANMAMIŞ gösteriyordu — PRD §3.4'ün
      // "ilerleme düşmez" sözüyle çelişiyordu. Hakemlik ATTEMPTED'ı seçti:
      // ölçülemeyen birim de OLDU. Bu satır o kararı çiviliyor.
      expect(rec(done: 3, unmeasured: 1, planned: 4).isComplete, isTrue);
      expect(rec(done: 3, unmeasured: 0, planned: 4).isComplete, isFalse);
    });

    test('unmeasuredUnits sıfırsa satıra YAZILMAZ (az-alan disiplini)', () {
      expect(rec().toJson().containsKey('unmeasuredUnits'), isFalse);
      // Pozitif ikiz: sıfır DEĞİLSE yazılıyor.
      expect(rec(unmeasured: 2).toJson()['unmeasuredUnits'], 2);
    });
  });

  test('staticHold dejenerasyonu KABUL + BELGELİ — çekirdek atmıyor, yüzey biliyor',
      () async {
    // Hakemlik §5: `unitLabel == 'second'` iken `unitsCompleted` ile
    // `workedSeconds` aynı sayıyı taşır; çekirdek buna izin veriyor. Sözleşme
    // yüzeyde: iki alanı bağımsız iki olgu gibi göstermek YASAK.
    const String plankId = 'hold_foundations.plank';
    final JsonlSessionStore store = JsonlSessionStore(file);
    await store.append(
        rec(lessonId: plankId, unit: 'second', done: 45, worked: 45, planned: 60));
    final SessionRecord back = (await store.recent()).single;
    expect(back.unitsCompleted, back.workedSeconds);

    final ProgressSummary s = ProgressSummary.build(
      lessonSurfaces: const <LessonSurface>[
        LessonSurface(
          id: plankId,
          displayName: 'Plank',
          unitLabel: 'second',
          gradedToday: false,
        )
      ],
      records: <SessionRecord>[back],
    );
    final LessonProgress lp = s.lessons.single;
    // ⚠️ İlk yazışımda kaydın `lessonId`si yüzeyle EŞLEŞMİYORDU: kayıt yetim
    // düşüyordu, ders 0 seanslı kalıyordu ve bayrak yalnızca etiketten
    // türediği için test yine geçiyordu — yani dejenerasyon yolunu hiç
    // koşmadan "koştu" görünüyordu. Şimdi gerçekten eşleşiyor:
    expect(s.orphanRecordLessonIds, isEmpty);
    expect(lp.sessionCount, 1);
    expect(lp.unitsMeasured, lp.workedSeconds, reason: 'dejenerasyon GERÇEKTEN oluştu');
    expect(lp.unitsDuplicateWorkedSeconds, isTrue);
  });

  test('File-kurucu: path_provider YOK, platform kanalı YOK', () {
    // Terfi şartı #1. Bu test bir platform kanalı olmadan koşuyor olması
    // sayesinde kendi iddiasının kanıtı.
    expect(JsonlSessionStore(file), isA<SessionStore>());
  });

  test('v1 satırı okunur ve BİLİNMEYEN birim sessizce "rep" olmaz', () async {
    // Çekirdek JabLab'ın v1 (rounds) satırlarını göç ettiriyor. Gravita v1
    // yazmadı, ama okuma yolu ortak: birim `round` olarak geliyor ve Gravita'nın
    // metin katmanı bilinmeyen etiketi UYDURMUYOR, olduğu gibi gösteriyor.
    file.writeAsStringSync('${jsonEncode(<String, dynamic>{
          'v': 1,
          'lessonId': 'jab_basics.rounds',
          'completedAt': '2026-07-30T12:00:00.000Z',
          'workedSeconds': 180,
          'roundsCompleted': 3,
          'plannedRounds': 3,
        })}\n');
    final SessionRecord back = (await JsonlSessionStore(file).recent()).single;
    expect(back.unitLabel, 'round');
    expect(back.isScoredClass, isFalse,
        reason: 'v1 satırının sınıfı boş — en az yetkili okuma NOT VERMEZ.');
  });
}
