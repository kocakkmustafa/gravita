import 'dart:convert';
import 'dart:io';

import 'package:gravita_engine/gravita_engine.dart';
import 'package:test/test.dart';

/// SessionStore portu — JabLab J-064 deseninin ARIZA testleri (birebir taşındı)
/// + Gravita'nın üç deltası (`docs/design/SESSION-STORE-DELTA.md`).
///
/// Arıza testleri kopyalanmadı, PORT EDİLDİ: her biri JabLab'ın gerçek veri
/// kaybı riskine karşı yazdığı bir davranışı sabitliyor. Bu depo kullanıcının
/// aylarca birikmiş geçmişini tutacak — "bozuk satır tüm geçmişi silmez"
/// bir konfor değil, veri kaybı sınırı.
void main() {
  late Directory dir;
  late File file;
  late JsonlSessionStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('gravita_sessions');
    file = File('${dir.path}/sessions.jsonl');
    store = JsonlSessionStore(file);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  SessionRecord rec({
    String lessonId = 'push_foundations.reps_and_tempo',
    int worked = 120,
    int done = 5,
    int planned = 5,
    String unit = 'rep',
    LessonClass lessonClass = LessonClass.scored,
    int unmeasured = 0,
    String? reason,
    DateTime? at,
  }) =>
      SessionRecord(
        lessonId: lessonId,
        completedAt: at ?? DateTime.utc(2026, 7, 30, 12),
        workedSeconds: worked,
        unitsCompleted: done,
        plannedUnits: planned,
        unitLabel: unit,
        lessonClass: lessonClass,
        unmeasuredUnits: unmeasured,
        unmeasuredReason: reason,
      );

  group('JabLab arıza davranışları (port)', () {
    test('boş depo boş liste döner — dosya yokluğu HATA DEĞİL', () async {
      expect(await store.recent(), isEmpty);
      expect(await store.workedSecondsFor('x'), 0);
    });

    test('_readAll DEĞİŞTİRİLEBİLİR liste döner (const [] ilk açılışı çökertir)',
        () async {
      // JabLab'da bu gerçek bir kusurdu: recent() sonucu YERİNDE sıralıyor.
      final List<SessionRecord> empty = await store.recent();
      expect(() => empty.sort((a, b) => 0), returnsNormally);
    });

    test('ekleme kalıcı, okuma EN YENİ ÖNCE', () async {
      await store.append(rec(at: DateTime.utc(2026, 7, 28)));
      await store.append(rec(at: DateTime.utc(2026, 7, 30)));
      final List<SessionRecord> got = await store.recent();
      expect(got.length, 2);
      expect(got.first.completedAt.day, 30);
    });

    test('APPEND-ONLY: eski satırlar korunur', () async {
      await store.append(rec(worked: 60));
      await store.append(rec(worked: 90));
      expect((await store.recent()).length, 2);
      expect(await store.workedSecondsFor(rec().lessonId), 150);
    });

    test('her satır ŞEMA SÜRÜMÜNÜ taşır', () async {
      await store.append(rec());
      final Map<String, dynamic> j =
          jsonDecode(file.readAsLinesSync().first) as Map<String, dynamic>;
      expect(j['v'], JsonlSessionStore.schemaVersion);
    });

    test('BİLİNMEYEN sürümlü satır ATLANIR, gerisi okunur', () async {
      await store.append(rec());
      file.writeAsStringSync('${jsonEncode(<String, dynamic>{
            'v': 999,
            ...rec().toJson(),
          })}\n', mode: FileMode.append);
      expect((await store.recent()).length, 1);
    });

    test('BOZUK satır tüm geçmişi SİLMEZ', () async {
      await store.append(rec());
      file.writeAsStringSync('{bu json değil\n', mode: FileMode.append);
      await store.append(rec(worked: 30));
      expect((await store.recent()).length, 2);
    });

    test('YARIM yazılmış son satır sağlam kayıtları götürmez', () async {
      await store.append(rec());
      file.writeAsStringSync('{"v":1,"lessonId":"yar', mode: FileMode.append);
      expect((await store.recent()).length, 1);
    });

    test('ATOMİKLİK: yazma sonrası geçici dosya KALMAZ', () async {
      await store.append(rec());
      expect(File('${file.path}.tmp').existsSync(), isFalse);
    });

    test('yarıda bırakılan seans KAYDEDİLİR ve ayırt edilebilir', () async {
      await store.append(rec(done: 2, planned: 5));
      final SessionRecord r = (await store.recent()).single;
      expect(r.isComplete, isFalse);
      expect(r.unitsCompleted, 2);
    });

    test('zaman UTC yazılır, gidiş-dönüş korunur', () async {
      final DateTime t = DateTime.utc(2026, 7, 30, 9, 15, 30);
      await store.append(rec(at: t));
      expect((await store.recent()).single.completedAt.toUtc(), t);
    });
  });

  group('Gravita deltaları', () {
    test('DELTA 1 — birim etiketi KAYIT başına: rep ve second yan yana yaşar',
        () async {
      // Ölçülmüş olgu: katalogda 14 repFsm + 5 staticHold var. Aynı app
      // içinde iki birim → app-düzeyi tek etiket bunu ifade EDEMEZ.
      await store.append(rec(lessonId: 'push.reps', unit: 'rep', done: 5));
      await store.append(rec(
          lessonId: 'plank.hold', unit: 'second', done: 45, planned: 60));
      final List<SessionRecord> got = await store.recent();
      expect(got.map((SessionRecord r) => r.unitLabel).toSet(),
          <String>{'rep', 'second'});
    });

    test('DELTA 2 — lessonClass kayda YAZILIR (retroaktif yeniden yorum yok)',
        () async {
      // Ders sınıfı ölçüm geliştikçe TERFİ ediyor (G-091: squat kalça/uyluk
      // varyansa geçti). Kayıt yazıldığı günün sınıfını taşımazsa, form-notu
      // açıldığı gün ÖNCEKİ seanslar geçmişte "notlanmış" görünür.
      await store.append(rec(lessonClass: LessonClass.measurementOnly));
      expect((await store.recent()).single.lessonClass,
          LessonClass.measurementOnly);
      final Map<String, dynamic> j =
          jsonDecode(file.readAsLinesSync().first) as Map<String, dynamic>;
      expect(j['lessonClass'], 'measurementOnly');
    });

    test('DELTA 3 — ölçülemeyen birimler KAYDEDİLİR, iş toplamı korunur',
        () async {
      // PRD §3.4: "analiz edilemeyen deneme → ilerleme DÜŞMEZ". Ölçülemeyeni
      // kaydetmemek, yarın yüzeyin kullanıcının yaptığı işi SAKLAMASI olurdu.
      await store.append(
          rec(done: 3, planned: 5, unmeasured: 2, reason: 'kadraj dışı'));
      final SessionRecord r = (await store.recent()).single;
      expect(r.unitsCompleted, 3, reason: 'ÖLÇÜLEN 3');
      expect(r.unmeasuredUnits, 2, reason: 'görüldü ama hüküm verilemedi');
      expect(r.attemptedUnits, 5,
          reason: 'kullanıcının yaptığı iş ölçülen+ölçülemeyen');
      expect(r.unmeasuredReason, 'kadraj dışı');
    });

    test('DELTA 3 — ölçülemeyen birim ilerlemeyi DÜŞÜRMEZ: isComplete '
        'ölçülene bakar, cezalandırmaz', () async {
      // 5 planlanan, 5'i de ölçüldü + ayrıca 2 ölçülemeyen → tamamlanmış.
      await store.append(rec(done: 5, planned: 5, unmeasured: 2));
      expect((await store.recent()).single.isComplete, isTrue);
    });
  });
}
