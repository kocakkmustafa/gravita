import 'movement_config.dart';
import 'session_store.dart';

/// Bir dersin birim etiketi — **ÜRETİCİSİ katalogdur**, elle yazılmaz.
///
/// Delta 1 (`docs/design/SESSION-STORE-DELTA.md` §2) `unitLabel`i KAYIT-başına
/// bir alan yaptı; ama alanı DOLDURAN bir üretici yoktu. Elle yazılırsa
/// katalogla kaçınılmaz olarak ayrışır — `MeasurementContract`'ın "dürüstlük
/// kutusu elle yazılmaz" gerekçesinin aynısı.
///
/// `switch` **kapsayıcıdır (exhaustive)**: kataloğa yeni bir `EngineType`
/// eklenirse bu fonksiyon DERLENMEZ. Kasıtlı: çalışma-zamanı `throw`u ancak o
/// hareket bir kez oynanınca patlar, derleme hatası ise ekleyen kişiyi HEMEN
/// yakalar. Sessiz varsayılan (`?? 'rep'`) en kötüsü olurdu — bir statik tutuş
/// yüzeyde "5 tekrar" diye görünürdü.
String unitLabelForEngineType(EngineType t) => switch (t) {
      EngineType.repFsm => 'rep',
      // Burpee: çok fazlı ama kullanıcı için sayılan şey hâlâ TEKRARdır.
      EngineType.multiPhaseFsm => 'rep',
      EngineType.staticHold => 'second',
    };

/// İlerleme yüzeyinin VERİ katmanı — kayıtlardan türetilir, hiçbir şey icat etmez.
///
/// Koordinatör hükmü M-F-168 (orta yol): veri katmanı TAM, yapısal widget İNCE,
/// görsel cila tasarım oturumuna. Bu dosya "TAM" olan taraftır ve üç kuralı
/// YAPISAL olarak taşır — yorum olarak değil, alan/tip olarak:
///
///  1. **ÖLÇÜMLER, NOT DEĞİL.** Burada skor/derece/seri/seviye alanı YOKTUR ve
///     olamaz. [ProgressSummary.toJson] anahtar kümesi teste ÇİVİLENMİŞTİR
///     (`progress_summary_test.dart` → "yüzey sözleşmesi"): yeni bir alan
///     eklemek testi ADIYLA kırar. Gerekçe: gecenin tekrar eden dersi
///     "okuyanı olmayan beyan"ın kardeşi — *yazanı olmayan kural*. Yorumla
///     yazılan "skor koymayacağız" sözü, ilk aceleci commit'te ölür.
///  2. **GEÇİLEMEZ KAPI BEYAN EDİLİR.** Kilitli veya hiç başlanmamış ders
///     yüzeyden DÜŞMEZ; [LessonProgress.state] ile ve kilitliyse
///     [LessonProgress.lockedReason] ile GÖRÜNÜR. Listelemeyi atlamak,
///     kullanıcıya "böyle bir ders yok" demektir; kilit bir ölçüm sınırıdır,
///     saklanacak bir utanç değil (J-066 disiplini, UI-BRIEF §5-6).
///  3. **RETROAKTİF KREDİ YOK.** Bir seansın skorlanıp skorlanmadığı KAYDIN
///     kendi [SessionRecord.lessonClass]'ından okunur — dersin BUGÜNKÜ
///     durumundan değil. Form notu yarın açılırsa, dün ölçüm-olarak yapılmış
///     seanslar geçmişte "notlanmış" hâle GELMEZ ([withheldRetroactiveCredit]
///     bunu ayrıca sayar).
final class ProgressSummary {
  const ProgressSummary._({
    required this.lessons,
    required this.totalWorkedSeconds,
    required this.unitTotals,
    required this.orphanRecordLessonIds,
  });

  /// Kayıtları yüzey tanımlarıyla birleştirir.
  ///
  /// [lessonSurfaces] yüzeyin BUGÜN bildiği dersler (içerik katmanından gelir);
  /// [records] kullanıcının geçmişi. İkisi ayrı yaşar, o yüzden üç kenar durum
  /// da açıkça ele alınır: kaydı olmayan ders · kilitliyken kaydı olan ders ·
  /// yüzeyde karşılığı olmayan kayıt.
  factory ProgressSummary.build({
    required List<LessonSurface> lessonSurfaces,
    required List<SessionRecord> records,
  }) {
    final Map<String, List<SessionRecord>> byLesson =
        <String, List<SessionRecord>>{};
    for (final SessionRecord r in records) {
      byLesson.putIfAbsent(r.lessonId, () => <SessionRecord>[]).add(r);
    }

    final List<LessonProgress> out = <LessonProgress>[];
    for (final LessonSurface s in lessonSurfaces) {
      out.add(LessonProgress._from(s, byLesson[s.id] ?? const <SessionRecord>[]));
    }

    // YÜZEYDE KARŞILIĞI OLMAYAN KAYIT: ders yeniden adlandırıldıysa ya da
    // içerikten kaldırıldıysa, kullanıcının o seansları YAPILMIŞ İŞTİR. Sessizce
    // düşürmek geçmişi silmekle aynı sonucu verir; toplamlara katılmaz ama
    // ADIYLA rapor edilir (rig tarafındaki "yetim karantinası" deseninin,
    // G-095, ürün tarafına düşen hâli).
    final Set<String> known = lessonSurfaces.map((LessonSurface s) => s.id).toSet();
    final List<String> orphans = byLesson.keys
        .where((String id) => !known.contains(id))
        .toList()
      ..sort();

    // TEK SKALER "toplam birim" YOK: 5 tekrar + 45 saniye toplanamaz. Birim
    // etiketine göre AYRI toplanır (delta 1'in doğrudan sonucu). Bir gün
    // `totalUnits` diye bir getter eklenirse, o gün yüzey yalan söylemeye başlar.
    final Map<String, int> unitTotals = <String, int>{};
    int seconds = 0;
    for (final LessonProgress lp in out) {
      seconds += lp.workedSeconds;
      if (lp.unitsMeasured == 0) continue;
      unitTotals[lp.unitLabel] = (unitTotals[lp.unitLabel] ?? 0) + lp.unitsMeasured;
    }

    return ProgressSummary._(
      lessons: List<LessonProgress>.unmodifiable(out),
      totalWorkedSeconds: seconds,
      unitTotals: Map<String, int>.unmodifiable(unitTotals),
      orphanRecordLessonIds: List<String>.unmodifiable(orphans),
    );
  }

  /// Yüzeyin bildiği HER ders — kaydı olmayan ve kilitli olanlar DAHİL.
  final List<LessonProgress> lessons;

  /// Toplam çalışılan saniye. Bu tek skaler MEŞRUDUR: saniye her derste aynı
  /// birimdir (dinlenme hariç — J-064 gerekçesi).
  final int totalWorkedSeconds;

  /// Birim etiketi → ölçülen birim toplamı (`rep` · `second`). Ayrı tutulur.
  final Map<String, int> unitTotals;

  /// Yüzeyde karşılığı olmayan kayıtların ders kimlikleri (sıralı).
  final List<String> orphanRecordLessonIds;

  /// Kaydı olan ama BUGÜN kilitli olan ders var mı (ders açıkken çalışılmış,
  /// sonra ölçüm geri çekilmiş — G-070 sınıfı bir geri adım).
  bool get hasHistoryUnderLock =>
      lessons.any((LessonProgress l) => l.hasRecordsWhileLocked);

  /// Bugün notlanan ama geçmişte ölçüm-olarak yapılmış seans sayısı.
  /// Sıfırdan büyükse yüzey "bunlar notlanmadı" demek ZORUNDA.
  int get withheldRetroactiveCredit => lessons.fold<int>(
      0, (int a, LessonProgress l) => a + l.withheldRetroactiveCredit);

  /// ⚠️ Anahtar kümesi teste çivilenmiştir (kural 1). Alan eklemek/çıkarmak
  /// `progress_summary_test.dart`'taki "yüzey sözleşmesi" testini kırar.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'totalWorkedSeconds': totalWorkedSeconds,
        'unitTotals': unitTotals,
        'orphanRecordLessonIds': orphanRecordLessonIds,
        'lessons': lessons.map((LessonProgress l) => l.toJson()).toList(),
      };
}

/// Yüzeyin BUGÜN bildiği bir ders — içerik katmanından (library.json) türetilir.
final class LessonSurface {
  const LessonSurface({
    required this.id,
    required this.displayName,
    required this.unitLabel,
    required this.gradedToday,
    this.lockedReason,
  }) : assert(lockedReason == null || !gradedToday,
            'Kilitli ders notlanıyor sayılamaz — K9 lockClass:measurement.');

  /// Yüzey listesini içerikten TÜRETİR — **tek ev**.
  ///
  /// Hem üretim kabuğu (`lib/app/content_repository.dart`) hem içerik-kablolama
  /// testi bu fonksiyonu çağırır. İki ayrı türetme yazmak, G-079'un dersini
  /// (aynı ölçümün iki evi tutarsızlaşır) yüzey tarafında tekrarlamak olurdu:
  /// biri `status: locked`i okumayı unutsa kilitli ders üretimde AÇIK görünürdü.
  ///
  /// [library] `library.json`ın çözümlenmiş hâli; [catalogFor] hareketin
  /// `catalogId`sini alıp katalog config'ini döndürür (dosyayı nereden
  /// bulacağı ÇAĞIRANIN işi — motor dosya sistemi bilmez).
  static List<LessonSurface> deriveAll({
    required Map<String, dynamic> library,
    required MovementConfig Function(String catalogId) catalogFor,
  }) {
    final List<LessonSurface> out = <LessonSurface>[];
    for (final Map<String, dynamic> m
        in (library['movements'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      final List<dynamic> courses =
          (m['courses'] as List<dynamic>?) ?? const <dynamic>[];
      // K1: `coming_soon` harekette kurs OLAMAZ — sahte kurs listelenmez.
      if (courses.isEmpty) continue;
      final String unit =
          unitLabelForEngineType(catalogFor((m['catalogId'] ?? m['id']) as String)
              .engineType);
      for (final Map<String, dynamic> c in courses.cast<Map<String, dynamic>>()) {
        for (final Map<String, dynamic> l
            in (c['lessons'] as List<dynamic>).cast<Map<String, dynamic>>()) {
          final bool locked = l['status'] == 'locked';
          out.add(LessonSurface(
            id: l['id'] as String,
            displayName: l['displayName'] as String,
            unitLabel: unit,
            gradedToday:
                (l['gradesFormAgainstReference'] as bool? ?? false) && !locked,
            lockedReason: locked ? l['lockedReason'] as String : null,
          ));
        }
      }
    }
    return out;
  }

  final String id;

  /// Kullanıcıya GÖSTERİLECEK ad — `library.json`dan gelir.
  ///
  /// ⚠️ Bu alan, kabuğu SİMÜLATÖRDE koşturunca eklendi: ekranda ders adı yerine
  /// `push_foundations.reps_and_tempo` yazıyordu. 16 test yeşildi ve hiçbiri
  /// yakalamadı, çünkü testleri `lessonId` üzerinden yazmıştım — yani
  /// kullanıcıya GÖSTERİLMEMESİ gereken şeyi iddia ediyordum. Ders: yüzey
  /// testleri, yüzeyin göstermesi GEREKENİ iddia etmeli; kimliği iddia eden
  /// test, kimliğin sızmasını kutsar.
  final String displayName;

  /// `rep` · `second`. Yüzeyin bu dersi hangi birimde göstereceği.
  final String unitLabel;

  /// Ders BUGÜN forma not veriyor mu (library.json `gradesFormAgainstReference`
  /// ve `status != locked`). Geçmişi YORUMLAMAK için KULLANILMAZ — yalnız
  /// [LessonProgress.withheldRetroactiveCredit]'i saymak için.
  final bool gradedToday;

  /// Kilitliyse kullanıcıya gösterilecek gerekçe (K5: eşik değeri değil, EKSİK
  /// ÖLÇÜMÜN adı). `null` ise ders açık.
  final String? lockedReason;

  bool get isLocked => lockedReason != null;
}

/// Bir dersin ilerleme durumu.
enum LessonProgressState {
  /// Yüzeyde var, kilitli. Kayıt olabilir de olmayabilir de.
  locked,

  /// Açık ama hiç seans yok. **Listeden DÜŞMEZ** — "hiç yapmadın" bir veridir.
  notStarted,

  /// Açık ve en az bir seans var.
  inProgress,
}

final class LessonProgress {
  const LessonProgress._({
    required this.lessonId,
    required this.displayName,
    required this.state,
    required this.unitLabel,
    required this.sessionCount,
    required this.workedSeconds,
    required this.unitsMeasured,
    required this.unitsUnmeasured,
    required this.unmeasuredReasons,
    required this.scoredSessions,
    required this.measurementOnlySessions,
    required this.withheldRetroactiveCredit,
    required this.hasRecordsWhileLocked,
    required this.lockedReason,
  });

  factory LessonProgress._from(LessonSurface s, List<SessionRecord> rs) {
    int worked = 0;
    int measured = 0;
    int unmeasured = 0;
    int scored = 0;
    int measurementOnly = 0;
    final Set<String> reasons = <String>{};
    for (final SessionRecord r in rs) {
      worked += r.workedSeconds;
      measured += r.unitsCompleted;
      unmeasured += r.unmeasuredUnits;
      if (r.unmeasuredUnits > 0 && r.unmeasuredReason != null) {
        reasons.add(r.unmeasuredReason!);
      }
      // KAYDIN kendi sınıfı okunur — dersin bugünkü hâli DEĞİL (kural 3).
      switch (r.lessonClass) {
        case LessonClass.scored:
          scored++;
        case LessonClass.measurementOnly:
          measurementOnly++;
      }
    }

    final LessonProgressState state = s.isLocked
        ? LessonProgressState.locked
        : rs.isEmpty
            ? LessonProgressState.notStarted
            : LessonProgressState.inProgress;

    return LessonProgress._(
      lessonId: s.id,
      displayName: s.displayName,
      state: state,
      unitLabel: s.unitLabel,
      sessionCount: rs.length,
      workedSeconds: worked,
      unitsMeasured: measured,
      unitsUnmeasured: unmeasured,
      unmeasuredReasons: List<String>.unmodifiable(reasons.toList()..sort()),
      scoredSessions: scored,
      measurementOnlySessions: measurementOnly,
      // Ders bugün not veriyor ama bu seanslar ölçüm-olarak yapılmıştı →
      // geriye dönük not YOK. Ders bugün not vermiyorsa withheld anlamsızdır (0).
      withheldRetroactiveCredit: s.gradedToday ? measurementOnly : 0,
      hasRecordsWhileLocked: s.isLocked && rs.isNotEmpty,
      lockedReason: s.lockedReason,
    );
  }

  final String lessonId;

  /// Kullanıcıya gösterilecek ad. `lessonId` YALNIZ kayıt eşlemesi içindir.
  final String displayName;

  final LessonProgressState state;
  final String unitLabel;
  final int sessionCount;
  final int workedSeconds;

  /// ÖLÇÜLEN birim toplamı.
  final int unitsMeasured;

  /// Görülen ama hüküm verilemeyen birim toplamı (delta 3). Yüzey bunu
  /// GÖSTERMEK zorunda: PRD §3.4 "ilerleme düşmez" sözü buradan doğrulanır.
  final int unitsUnmeasured;

  /// Ölçülemeyenlerin gerekçeleri (sıralı, tekrarsız) — kadraj/ışık/çok-kişi/
  /// kamera hareketi.
  final List<String> unmeasuredReasons;

  final int scoredSessions;
  final int measurementOnlySessions;

  /// Bugün notlanan bir derste, geçmişte ölçüm-olarak yapılmış seans sayısı.
  final int withheldRetroactiveCredit;

  /// Ders kilitli olmasına rağmen geçmişte seans var (açıkken çalışılmış).
  final bool hasRecordsWhileLocked;

  final String? lockedReason;

  /// Kullanıcının yaptığı toplam iş — ölçülen + ölçülemeyen.
  int get unitsAttempted => unitsMeasured + unitsUnmeasured;

  /// ⚠️ `unitsMeasured` ile [workedSeconds] AYNI ÖLÇÜMÜN iki kopyası olur:
  /// `staticHold` dersinde birim saniyedir (plank/wall_sit/hollow_hold/
  /// side_plank/superman_hold — katalogda 5 hareket). Yüzey ikisini bağımsız
  /// iki olgu gibi yan yana gösterirse aynı sayıyı iki kez saymış olur.
  /// Delta belgesi §2 bu kararı AÇIK bıraktı (kabul-et-ve-belgele vs türet);
  /// karar gelene kadar yüzeyin bilmesi gereken şey bu bayraktır.
  bool get unitsDuplicateWorkedSeconds => unitLabel == 'second';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lessonId': lessonId,
        'displayName': displayName,
        'state': state.name,
        'unitLabel': unitLabel,
        'sessionCount': sessionCount,
        'workedSeconds': workedSeconds,
        'unitsMeasured': unitsMeasured,
        'unitsUnmeasured': unitsUnmeasured,
        'unmeasuredReasons': unmeasuredReasons,
        'scoredSessions': scoredSessions,
        'measurementOnlySessions': measurementOnlySessions,
        'withheldRetroactiveCredit': withheldRetroactiveCredit,
        'hasRecordsWhileLocked': hasRecordsWhileLocked,
        if (lockedReason != null) 'lockedReason': lockedReason,
      };
}
