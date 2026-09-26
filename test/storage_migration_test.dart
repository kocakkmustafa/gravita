import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/storage/gravita_database.dart';
import 'package:gravita/app/storage/session_projector.dart';
import 'package:motion_core/motion_core.dart'
    show JsonlSessionStore, SessionRecord;

/// [GravitaDatabase]/[SessionProjector] — GRA-P1-004 Step 3. Roadmap'in
/// KENDİ adlandırdığı dosya. `content` bilerek YOK: bu şema `SessionRecord`
/// dışında hiçbir hareket/katalog verisiyle konuşmuyor.
///
/// The current schema is v1. Exercise real persisted v1 compatibility now;
/// historical N-2 coverage requires actual published schema history.

// Deliberately unsupported future tag, not a claimed historical v2 schema.
final class _FutureVersionProbe extends GravitaDatabase {
  _FutureVersionProbe(File file) : super(NativeDatabase(file));
  @override
  int get schemaVersion => 2;
}

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
    test(
      'yeni veritabanı sessionIndexEntries tablosunu GERÇEKTEN kuruyor',
      () async {
        final GravitaDatabase db = GravitaDatabase.forTesting();
        addTearDown(db.close);
        final List<SessionIndexEntry> rows = await db
            .select(db.sessionIndexEntries)
            .get();
        expect(
          rows,
          isEmpty,
          reason: 'Taze kurulum boş başlamalı — hayalet satır YOK.',
        );
      },
    );
  });

  group('SessionProjector — journal\'dan YENİDEN KURMA', () {
    test('gerçek JSONL kayıtları Drift satırlarına DOĞRU yansıyor', () async {
      final JsonlSessionStore lessons = JsonlSessionStore(
        File('${tmp.path}/sessions.jsonl'),
      );
      final JsonlSessionStore free = JsonlSessionStore(
        File('${tmp.path}/free_sessions.jsonl'),
      );
      await lessons.append(
        record('bodyweight_squat', DateTime.utc(2026, 8, 1)),
      );
      await free.append(record('push_up', DateTime.utc(2026, 8, 2), units: 3));

      final GravitaDatabase db = GravitaDatabase.forTesting();
      addTearDown(db.close);
      final int n = await SessionProjector(
        db: db,
      ).rebuild(lessons: lessons, free: free);

      expect(n, 2);
      final List<SessionIndexEntry> rows = await db
          .select(db.sessionIndexEntries)
          .get();
      expect(rows.length, 2);
      expect(rows.map((SessionIndexEntry r) => r.lessonId).toSet(), <String>{
        'movement:bodyweight_squat',
        'movement:push_up',
      });
      expect(
        rows
            .firstWhere(
              (SessionIndexEntry r) => r.lessonId == 'movement:push_up',
            )
            .unitsCompleted,
        3,
      );
    });

    test('⭐ IDEMPOTENT REPLAY — AYNI journal\'ı İKİ KEZ oynatmak satırı '
        'İKİYE KATLAMAZ', () async {
      // Bu testin varlık sebebi roadmap'in KENDİ kelimesi: "idempotent
      // replay". Doğal bir benzersiz anahtar OLMADIĞI için (`gravita_
      // database.dart`ın kendi gerekçesi) bu özellik artımlı upsert'ten
      // DEĞİL, `rebuild()`ün HER ZAMAN tam yeniden kurmasından gelir —
      // burada TAM O DAVRANIŞ ölçülüyor, varsayılmıyor.
      final JsonlSessionStore lessons = JsonlSessionStore(
        File('${tmp.path}/sessions.jsonl'),
      );
      final JsonlSessionStore free = JsonlSessionStore(
        File('${tmp.path}/free_sessions.jsonl'),
      );
      await lessons.append(
        record('bodyweight_squat', DateTime.utc(2026, 8, 1)),
      );

      final GravitaDatabase db = GravitaDatabase.forTesting();
      addTearDown(db.close);
      final SessionProjector projector = SessionProjector(db: db);

      await projector.rebuild(lessons: lessons, free: free);
      await projector.rebuild(lessons: lessons, free: free);
      await projector.rebuild(lessons: lessons, free: free);

      final List<SessionIndexEntry> rows = await db
          .select(db.sessionIndexEntries)
          .get();
      expect(
        rows.length,
        1,
        reason:
            'ÜÇ kez yeniden kurmak HÂLÂ bir satır vermeli — journal '
            'değişmedi, izdüşüm de değişmemeli.',
      );
    });

    test('boş journal — hata YOK, tablo boş kalır (ilk açılış)', () async {
      final JsonlSessionStore lessons = JsonlSessionStore(
        File('${tmp.path}/sessions.jsonl'),
      );
      final JsonlSessionStore free = JsonlSessionStore(
        File('${tmp.path}/free_sessions.jsonl'),
      );

      final GravitaDatabase db = GravitaDatabase.forTesting();
      addTearDown(db.close);
      final int n = await SessionProjector(
        db: db,
      ).rebuild(lessons: lessons, free: free);

      expect(n, 0);
      expect(await db.select(db.sessionIndexEntries).get(), isEmpty);
    });

    test('var olan satırlar SİLİNİP journal\'ın GÜNCEL hâliyle DEĞİŞTİRİLİR '
        '— eski + yeni KARIŞMAZ', () async {
      final JsonlSessionStore lessons = JsonlSessionStore(
        File('${tmp.path}/sessions.jsonl'),
      );
      final JsonlSessionStore free = JsonlSessionStore(
        File('${tmp.path}/free_sessions.jsonl'),
      );
      await lessons.append(
        record('bodyweight_squat', DateTime.utc(2026, 8, 1)),
      );

      final GravitaDatabase db = GravitaDatabase.forTesting();
      addTearDown(db.close);
      final SessionProjector projector = SessionProjector(db: db);
      await projector.rebuild(lessons: lessons, free: free);

      // Journal'a İKİNCİ bir kayıt eklendi — sonraki rebuild BUNU da görmeli.
      await lessons.append(record('push_up', DateTime.utc(2026, 8, 3)));
      await projector.rebuild(lessons: lessons, free: free);

      final List<SessionIndexEntry> rows = await db
          .select(db.sessionIndexEntries)
          .get();
      expect(
        rows.length,
        2,
        reason:
            'İkinci rebuild journal\'ın GÜNCEL hâlini yansıtmalı — '
            'ne eksik (ilk kayıp) ne fazla (satır çakışması).',
      );
    });
  });

  group('persisted schema compatibility — all existing versions (v1)', () {
    test(
      'v1 file closes and reopens with rows, defaults and nulls intact',
      () async {
        final file = File('${tmp.path}/projection.sqlite');
        final journal = JsonlSessionStore(File('${tmp.path}/source.jsonl'));
        await journal.append(
          record('bodyweight_squat', DateTime.utc(2026, 8, 1)),
        );
        final original = GravitaDatabase(NativeDatabase(file));
        await SessionProjector(db: original).rebuild(
          lessons: journal,
          free: JsonlSessionStore(File('${tmp.path}/empty.jsonl')),
        );
        await original.close();

        final reopened = GravitaDatabase(NativeDatabase(file));
        addTearDown(reopened.close);
        final row =
            (await reopened.select(reopened.sessionIndexEntries).get()).single;
        expect(row.lessonId, 'movement:bodyweight_squat');
        expect(row.completedAt.toUtc(), DateTime.utc(2026, 8, 1));
        expect(row.unitsCompleted, 5);
        expect(row.workedSeconds, 120);
        expect(row.unmeasuredUnits, 0);
        expect(row.unmeasuredReason, isNull);
        expect(
          (await reopened.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          1,
        );
        // A future schema change must add its real fixture/migration coverage.
        expect(reopened.schemaVersion, 1);
      },
    );

    test(
      'unsupported future version is rejected without downgrading or deleting rows',
      () async {
        final file = File('${tmp.path}/future.sqlite');
        final future = _FutureVersionProbe(file);
        await future.customStatement(
          'CREATE TABLE sentinel (value TEXT NOT NULL)',
        );
        await future.customStatement(
          "INSERT INTO sentinel VALUES ('retain-me')",
        );
        await future.close();
        final current = GravitaDatabase(NativeDatabase(file));
        await expectLater(
          current.select(current.sessionIndexEntries).get(),
          throwsA(isA<UnsupportedError>()),
        );
        await current.close();

        final inspect = _FutureVersionProbe(file);
        addTearDown(inspect.close);
        expect(
          (await inspect.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          2,
        );
        expect(
          (await inspect.customSelect('SELECT value FROM sentinel').getSingle())
              .read<String>('value'),
          'retain-me',
        );
      },
    );
  });
}
