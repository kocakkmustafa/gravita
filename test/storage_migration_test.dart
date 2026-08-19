import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/storage/gravita_database.dart';
import 'package:gravita/app/storage/session_projector.dart';
import 'package:motion_core/motion_core.dart' show JsonlSessionStore, SessionRecord;

/// [GravitaDatabase]/[SessionProjector] — GRA-P1-004 Step 3. Roadmap'in
/// KENDİ adlandırdığı dosya. `content` bilerek YOK: bu şema `SessionRecord`
/// dışında hiçbir hareket/katalog verisiyle konuşmuyor.
///
/// `schemaVersion` sabit bir `int` döndürüyor — instance'ı yalnız bunu OKUMAK
/// için kurmak GERÇEK bir sorgu/dosya açmıyor, alttaki `skip:` koşulu bu
/// yüzden test-kaydı anında GÜVENLE senkron okunabiliyor.
final int _currentSchemaVersion = GravitaDatabase.forTesting().schemaVersion;

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('gra_storage');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  SessionRecord record(String id, DateTime at, {int units = 5}) =>
      SessionRecord(
        lessonId: 'movement:$id',
        completedAt: at,
        workedSeconds: 120,
        unitsCompleted: units,
        plannedUnits: 0,
        unitLabel: 'rep',
        lessonClass: 'measurementOnly',
      );

  group('şema — TEMİZ kurulum', () {
    test('yeni veritabanı sessionIndexEntries tablosunu GERÇEKTEN kuruyor',
        () async {
      final GravitaDatabase db = GravitaDatabase.forTesting();
      addTearDown(db.close);
      final List<SessionIndexEntry> rows =
          await db.select(db.sessionIndexEntries).get();
      expect(rows, isEmpty,
          reason: 'Taze kurulum boş başlamalı — hayalet satır YOK.');
    });
  });

  group('SessionProjector — journal\'dan YENİDEN KURMA', () {
    test('gerçek JSONL kayıtları Drift satırlarına DOĞRU yansıyor', () async {
      final JsonlSessionStore lessons =
          JsonlSessionStore(File('${tmp.path}/sessions.jsonl'));
      final JsonlSessionStore free =
          JsonlSessionStore(File('${tmp.path}/free_sessions.jsonl'));
      await lessons.append(record('bodyweight_squat', DateTime.utc(2026, 8, 1)));
      await free.append(record('push_up', DateTime.utc(2026, 8, 2), units: 3));

      final GravitaDatabase db = GravitaDatabase.forTesting();
      addTearDown(db.close);
      final int n =
          await SessionProjector(db: db).rebuild(lessons: lessons, free: free);

      expect(n, 2);
      final List<SessionIndexEntry> rows =
          await db.select(db.sessionIndexEntries).get();
      expect(rows.length, 2);
      expect(rows.map((SessionIndexEntry r) => r.lessonId).toSet(),
          <String>{'movement:bodyweight_squat', 'movement:push_up'});
      expect(
          rows
              .firstWhere((SessionIndexEntry r) =>
                  r.lessonId == 'movement:push_up')
              .unitsCompleted,
          3);
    });

    test(
        '⭐ IDEMPOTENT REPLAY — AYNI journal\'ı İKİ KEZ oynatmak satırı '
        'İKİYE KATLAMAZ', () async {
      // Bu testin varlık sebebi roadmap'in KENDİ kelimesi: "idempotent
      // replay". Doğal bir benzersiz anahtar OLMADIĞI için (`gravita_
      // database.dart`ın kendi gerekçesi) bu özellik artımlı upsert'ten
      // DEĞİL, `rebuild()`ün HER ZAMAN tam yeniden kurmasından gelir —
      // burada TAM O DAVRANIŞ ölçülüyor, varsayılmıyor.
      final JsonlSessionStore lessons =
          JsonlSessionStore(File('${tmp.path}/sessions.jsonl'));
      final JsonlSessionStore free =
          JsonlSessionStore(File('${tmp.path}/free_sessions.jsonl'));
      await lessons.append(record('bodyweight_squat', DateTime.utc(2026, 8, 1)));

      final GravitaDatabase db = GravitaDatabase.forTesting();
      addTearDown(db.close);
      final SessionProjector projector = SessionProjector(db: db);

      await projector.rebuild(lessons: lessons, free: free);
      await projector.rebuild(lessons: lessons, free: free);
      await projector.rebuild(lessons: lessons, free: free);

      final List<SessionIndexEntry> rows =
          await db.select(db.sessionIndexEntries).get();
      expect(rows.length, 1,
          reason: 'ÜÇ kez yeniden kurmak HÂLÂ bir satır vermeli — journal '
              'değişmedi, izdüşüm de değişmemeli.');
    });

    test('boş journal — hata YOK, tablo boş kalır (ilk açılış)', () async {
      final JsonlSessionStore lessons =
          JsonlSessionStore(File('${tmp.path}/sessions.jsonl'));
      final JsonlSessionStore free =
          JsonlSessionStore(File('${tmp.path}/free_sessions.jsonl'));

      final GravitaDatabase db = GravitaDatabase.forTesting();
      addTearDown(db.close);
      final int n =
          await SessionProjector(db: db).rebuild(lessons: lessons, free: free);

      expect(n, 0);
      expect(await db.select(db.sessionIndexEntries).get(), isEmpty);
    });

    test(
        'var olan satırlar SİLİNİP journal\'ın GÜNCEL hâliyle DEĞİŞTİRİLİR '
        '— eski + yeni KARIŞMAZ', () async {
      final JsonlSessionStore lessons =
          JsonlSessionStore(File('${tmp.path}/sessions.jsonl'));
      final JsonlSessionStore free =
          JsonlSessionStore(File('${tmp.path}/free_sessions.jsonl'));
      await lessons.append(record('bodyweight_squat', DateTime.utc(2026, 8, 1)));

      final GravitaDatabase db = GravitaDatabase.forTesting();
      addTearDown(db.close);
      final SessionProjector projector = SessionProjector(db: db);
      await projector.rebuild(lessons: lessons, free: free);

      // Journal'a İKİNCİ bir kayıt eklendi — sonraki rebuild BUNU da görmeli.
      await lessons.append(record('push_up', DateTime.utc(2026, 8, 3)));
      await projector.rebuild(lessons: lessons, free: free);

      final List<SessionIndexEntry> rows =
          await db.select(db.sessionIndexEntries).get();
      expect(rows.length, 2,
          reason: 'İkinci rebuild journal\'ın GÜNCEL hâlini yansıtmalı — '
              'ne eksik (ilk kayıp) ne fazla (satır çakışması).');
    });
  });

  group('göç (migration) — N-2 şemadan güncele', () {
    // ⛔ EXTERNAL_GATE, adıyla: `02-MOTION-AILESI-ORKESTRASYON.md` §8.1
    // "migration testleri N-2 şemadan güncele koşar" diyor ama BUGÜN yalnız
    // TEK şema sürümü var (`GravitaDatabase.schemaVersion == 1`) — N-2 göçü
    // sınamak için önce şemanın GERÇEKTEN en az iki kez evrilmesi gerekir.
    // Bu test o güne kadar KENDİNİ SİLAHSIZLANDIRIR (GRA-P1-002'nin dinamik
    // `skip` deseniyle AYNI): sayı UYDURULMUYOR, koşul GERÇEK
    // `schemaVersion`dan okunuyor — şema evrilince test KENDİLİĞİNDEN
    // gerçek koşuma döner, elle açılması GEREKMEZ.
    test(
        'gerçek şema sürümü ≥3 olunca N-2→güncel göçü kanıtlanmalı',
        () {
          fail('GravitaDatabase.schemaVersion henüz 1 — bu test şema en az '
              'iki kez evrilene kadar GERÇEK bir göç sınayamaz. Skip '
              'koşulunun kendisi bunu doğruluyor.');
        },
        skip: _currentSchemaVersion < 3
            ? 'N-2 migration EXTERNAL_GATE: schemaVersion henüz '
                '$_currentSchemaVersion, en az 3 gerekiyor (bugünkü + iki '
                'geçmiş sürüm) — 02-MOTION-AILESI-ORKESTRASYON.md §8.1'
            : false);
  });
}
