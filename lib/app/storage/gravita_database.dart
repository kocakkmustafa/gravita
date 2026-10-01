import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import '../account_data_directory.dart';

// `sqlite3_flutter_libs` içe aktarılmıyor — yalnız `pubspec.yaml`de bir
// bağımlılık olarak durması yeterli, native kütüphaneyi Flutter'ın plugin
// kayıt mekanizması OTOMATİK bağlıyor (drift'in KENDİ belgelenmiş deseni).

part 'gravita_database.g.dart';

/// Ders/serbest seans geçmişinin YENİDEN-KURULABİLİR izdüşümü (GRA-P1-004
/// Step 3, `02-MOTION-AILESI-ORKESTRASYON.md` §8.1).
///
/// ## Bu tablo GERÇEĞİN KAYNAĞI DEĞİL
///
/// `JsonlSessionStore` (motion_core, salt-okunur) HÂLÂ provenance — bu tablo
/// yalnız `session_projector.dart`ın journal'ı okuyarak KURDUĞU bir önbellek.
/// Tablo silinse/bozulsa bile journal'dan TAM olarak yeniden üretilebilir;
/// `SessionRecord`ın kendisi HİÇBİR yeni bilgi taşımıyor, yalnız Drift'in
/// sorgu/agregasyon yeteneğini KATALOG geçmişine EKLİYOR.
///
/// ⚠️ Doğal bir benzersiz anahtar YOK (`SessionRecord`ın kendi ID alanı yok) —
/// bu yüzden "idempotent replay" artımlı upsert yerine TAM YENİDEN KURMA ile
/// sağlanıyor (`session_projector.dart`ın `rebuild()`u): tabloyu boşalt, TÜM
/// journal'ı yeniden yaz. Aynı journal'ı iki kez oynatmak HER ZAMAN aynı
/// sonucu verir — kırılgan bir "aynı kayıt mı" varsayımına gerek yok.
class SessionIndexEntries extends Table {
  /// `SessionRecord.lessonId` — `movement:<id>` (serbest) ya da ders anahtarı.
  /// Kova AYRIMI burada YOK (aynı `content_repository.dart`nın kendi kuralı:
  /// kullanıcı için TEK bir geçmiş var), `lessonId`in ÖN EKİ zaten taşıyor.
  TextColumn get lessonId => text()();
  DateTimeColumn get completedAt => dateTime()();
  IntColumn get workedSeconds => integer()();
  IntColumn get unitsCompleted => integer()();
  IntColumn get plannedUnits => integer()();
  TextColumn get unitLabel => text()();
  TextColumn get lessonClass => text()();
  IntColumn get unmeasuredUnits => integer().withDefault(const Constant(0))();
  TextColumn get unmeasuredReason => text().nullable()();
}

@DriftDatabase(tables: <Type>[SessionIndexEntries])
class GravitaDatabase extends _$GravitaDatabase {
  GravitaDatabase(super.e);

  /// Yalnız test/harness için — belleği kullanan geçici bir veritabanı.
  ///
  /// ⚠️ Drift'in "aynı sınıf birden çok kez kuruldu" uyarısı BİLEREK
  /// susturuluyor — HER çağrı `NativeDatabase.memory()` ile TAMAMEN AYRI,
  /// izole bir örnek açıyor (production `open()`ın AKSİNE, orada AYNI
  /// dosyayı paylaşan iki örnek GERÇEK bir yarış riski taşırdı ve uyarı
  /// AÇIK kalmalı). Testte bu her zaman GÜVENLİ, ölçüldü (`storage_
  /// migration_test.dart` — çoklu test AYNI dosyada çakışmaz, her biri
  /// KENDİ belleğinde).
  GravitaDatabase.forTesting() : super(NativeDatabase.memory()) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (_, from, to) async {
      // No historical transition exists yet. Preserve unfamiliar databases;
      // a rebuildable projection is not permission to erase a user's file.
      throw UnsupportedError(
        'Unsupported Gravita schema transition $from → $to',
      );
    },
  );

  /// Gerçek uygulama-destek dizininde kalıcı bir veritabanı açar —
  /// `JsonlSessionStore`nun KENDİ deseni (`ProgramStore`/`ProgramScheduleStore`
  /// ile AYNI: `path_provider` çağrısı KABLOLAMA katmanında, kurucu değil).
  static Future<GravitaDatabase> open({String? accountUserId}) async {
    final Directory dir = accountDataDirectory(
      await getApplicationSupportDirectory(),
      accountUserId,
    );
    await dir.create(recursive: true);
    return GravitaDatabase(
      NativeDatabase.createInBackground(
        File('${dir.path}/gravita_projection.sqlite'),
      ),
    );
  }
}
