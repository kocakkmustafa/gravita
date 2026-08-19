import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Bir programın CANLI takvimi + tamamlanma durumu (GRA-P1-003 Step 3/4).
///
/// ## Neden [ProgramStore]dan AYRI
///
/// [ProgramStore] yalnız GİRDİYİ (deneyim/ekipman/gün) tutar — [WorkoutProgram]
/// her açılışta güncel katalogdan YENİDEN üretilir, dondurulmuş bir kopya
/// TUTULMAZ (`program_store.dart`nın kendi dosya-başı gerekçesi). Ama TAKVİM
/// (hangi seans hangi tarihte) ve TAMAMLANMA (hangi seans bitti, RPE'si ne)
/// programın KENDİSİ gibi türetilemez — bunlar KULLANICININ GEÇMİŞİ,
/// deterministik yeniden-üretimin kapsamı DIŞINDA. Bu yüzden ayrı, kendi
/// dosyasında kalıcı; iki kaygı iki store'da kalıyor (`OnboardingStore`/
/// `ProgramStore` ayrımıyla AYNI disiplin).
final class ProgramSchedule {
  const ProgramSchedule({required this.dates, required this.rpeByDayIndex});

  /// [WorkoutProgram.days] ile AYNI uzunlukta, AYNI indeksle eşlenen düz
  /// tarih listesi. Program yeniden üretildiğinde (ör. girdi değişti) uzunluk
  /// tutmayabilir — çağıran taraf bunu kontrol edip gerekirse YENİDEN kurar.
  final List<DateTime> dates;

  /// Tamamlanan günlerin RPE'si (1-10) — bir indeksin BURADA var OLMASI
  /// "bu gün bitti" demektir; yoksa gün henüz açık. RPE KULLANICI
  /// dokunuşundan gelir (roadmap Step 3: "camera sonucu değildir") — bu
  /// dosya `gravita_engine`e ya da `live_session.dart`a HİÇ bağımlı değil,
  /// yalnız `int` taşır.
  final Map<int, int> rpeByDayIndex;

  ProgramSchedule withRpe(int dayIndex, int rpe) => ProgramSchedule(
        dates: dates,
        rpeByDayIndex: <int, int>{...rpeByDayIndex, dayIndex: rpe},
      );

  ProgramSchedule withDates(List<DateTime> newDates) => ProgramSchedule(
        dates: newDates,
        rpeByDayIndex: rpeByDayIndex,
      );
}

/// [ProgramStore]nun BİREBİR deseni — `open()`/`forFile()`/fail-open `read()`.
final class ProgramScheduleStore {
  const ProgramScheduleStore._(this._file);

  final File _file;

  static Future<ProgramScheduleStore> open() async {
    final Directory dir = await getApplicationSupportDirectory();
    return ProgramScheduleStore._(File('${dir.path}/program_schedule.json'));
  }

  /// Yalnız test/harness için — gerçek dizin yerine verilen dosyayı kullanır.
  static ProgramScheduleStore forFile(File file) => ProgramScheduleStore._(file);

  /// Kayıtlı takvim — hiç kurulmamışsa ya da dosya okunamıyorsa `null`.
  /// ⚠️ Bozuk/okunamayan dosya "hiç kurulmamış" SAYILIR — `ProgramStore.read`
  /// ile AYNI fail-open gerekçesi: kullanıcı kilitlenmez, çağıran taraf
  /// (`WorkoutScreen._load`) yalnız takvimi SIFIRDAN kurar.
  Future<ProgramSchedule?> read() async {
    if (!await _file.exists()) return null;
    try {
      final Map<String, dynamic> j =
          jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      return ProgramSchedule(
        dates: (j['dates'] as List<dynamic>)
            .map((dynamic e) => DateTime.parse(e as String))
            .toList(growable: false),
        rpeByDayIndex: (j['rpeByDayIndex'] as Map<String, dynamic>).map(
            (String k, dynamic v) => MapEntry<int, int>(int.parse(k), v as int)),
      );
    } on Object {
      return null;
    }
  }

  Future<void> write(ProgramSchedule schedule) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'dates':
          schedule.dates.map((DateTime d) => d.toIso8601String()).toList(),
      'rpeByDayIndex': schedule.rpeByDayIndex
          .map((int k, int v) => MapEntry<String, int>(k.toString(), v)),
    }));
  }

  /// Takvimi kaldırır (ör. kullanıcı programı yeniden kurarsa). Dosya yoksa
  /// sessizce başarılı sayılır — `ProgramStore.clear` ile AYNI gerekçe.
  Future<void> clear() async {
    if (await _file.exists()) await _file.delete();
  }
}
