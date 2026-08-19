import 'package:drift/drift.dart' show Value;
import 'package:motion_core/motion_core.dart' show SessionRecord, SessionStore;

import 'gravita_database.dart';

/// Journal'ı (`JsonlSessionStore`) okuyup [SessionIndexEntries]i YENİDEN
/// KURAR (GRA-P1-004 Step 3). Journal HER ZAMAN gerçeğin kaynağı — bu sınıf
/// yalnız onu Drift'in sorgulanabilir biçimine YANSITIR.
///
/// ## Neden TAM YENİDEN KURMA, artımlı upsert DEĞİL
///
/// `SessionRecord`ın doğal bir benzersiz kimliği yok (`gravita_database.dart`ın
/// dosya-başı gerekçesiyle AYNI). Tam yeniden kurma "idempotent replay"i
/// BEDAVA verir: aynı journal'ı N kez oynatmak HER ZAMAN aynı sonucu üretir —
/// kırılgan bir "bu satır zaten var mıydı" karşılaştırmasına gerek YOK.
/// Bugünkü veri hacmi (erken aşama ürün) bu stratejinin maliyetini
/// önemsizleştiriyor; hacim büyürse artımlı bir strateji AYRI, ÖLÇÜLMÜŞ bir
/// karar olur — `pubspec.yaml`daki J-064 notunun AYNI disiplini: performans
/// ihtiyacı ÖLÇÜLÜNCE gelir, önceden VARSAYILMAZ.
final class SessionProjector {
  const SessionProjector({required this.db});

  final GravitaDatabase db;

  /// [lessons]/[free] KOVALARININ TAMAMINI okuyup tabloyu YENİDEN KURAR.
  /// Kova ayrımı `content_repository.dart`nın KENDİ kuralı — kullanıcı için
  /// TEK bir geçmiş var, `lessonId`in ön eki (`movement:` ya da ders anahtarı)
  /// zaten hangi kovadan geldiğini taşıyor; bu tablo o ayrımı TEKRARLAMAZ.
  ///
  /// Dönen sayı yansıtılan TOPLAM kayıt sayısıdır — çağıran taraf bunu
  /// `unreadableRecords()`un yanına koyup "kaç kayıt görüldü, kaçı okunamadı"
  /// diye AYRI ölçebilir (bu sınıf o sayımı KENDİSİ yapmaz; iki kaygı iki
  /// dosyada kalır — `readHistoryStatus`ın kendi tekilliği).
  Future<int> rebuild({
    required SessionStore lessons,
    required SessionStore free,
  }) async {
    final List<SessionRecord> all = <SessionRecord>[
      ...await lessons.recent(),
      ...await free.recent(),
    ];
    await db.transaction(() async {
      await db.delete(db.sessionIndexEntries).go();
      for (final SessionRecord r in all) {
        await db.into(db.sessionIndexEntries).insert(
              SessionIndexEntriesCompanion.insert(
                lessonId: r.lessonId,
                completedAt: r.completedAt,
                workedSeconds: r.workedSeconds,
                unitsCompleted: r.unitsCompleted,
                plannedUnits: r.plannedUnits,
                unitLabel: r.unitLabel,
                lessonClass: r.lessonClass,
                unmeasuredUnits: Value<int>(r.unmeasuredUnits),
                unmeasuredReason: Value<String?>(r.unmeasuredReason),
              ),
            );
      }
    });
    return all.length;
  }
}
