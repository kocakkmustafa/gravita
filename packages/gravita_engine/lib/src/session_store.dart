import 'dart:convert';
import 'dart:io';

/// Tamamlanmış bir seansın kaydı — JabLab J-064 deseninin Gravita portu.
///
/// **Neden bu kadar az alan var** (JabLab'ın kararı, aynen taşındı):
/// kaydedilen her alan, sonradan bir ürün yüzeyinin ona dayanmasına
/// davetiyedir. Hüküm/skor alanı **bilerek YOK** — kamera köprüsü yokken
/// sıfır kaydetmek, yarın "ilerleme" grafiğinde sıfır çizmek olurdu.
///
/// Gravita'nın üç deltası (`docs/design/SESSION-STORE-DELTA.md`):
///  1. [unitLabel] KAYIT-başına — app-başına DEĞİL. Gravita'da aynı app içinde
///     `repFsm` hareketleri TEKRAR, `staticHold` hareketleri SANİYE sayar;
///     tek bir app-düzeyi etiket bunu ifade edemez (ölçüldü: katalogda 14
///     repFsm + 5 staticHold + 1 multiPhaseFsm).
///  2. [lessonClass] — ders sınıfı ölçüm geliştikçe TERFİ ediyor (G-091'de
///     squat'ın kalça/uyluk toleransları varyansa geçti), o yüzden kayıt
///     yazıldığı günün sınıfını taşır; yoksa form-notu açıldığı gün ÖNCEKİ
///     seanslar geçmişte "notlanmış" görünür. (Choreia ile bağımsız yakınsama.)
///  3. [unmeasuredUnits] — PRD §3.4 sözü: "analiz edilemeyen deneme →
///     ilerleme DÜŞMEZ". Ölçülemeyeni kaydetmemek, yarın yüzeyin kullanıcının
///     yaptığı işi SAKLAMASI olurdu; sessizlik yalandır.
final class SessionRecord {
  const SessionRecord({
    required this.lessonId,
    required this.completedAt,
    required this.workedSeconds,
    required this.unitsCompleted,
    required this.plannedUnits,
    required this.unitLabel,
    required this.lessonClass,
    this.unmeasuredUnits = 0,
    this.unmeasuredReason,
  });

  factory SessionRecord.fromJson(Map<String, dynamic> j) => SessionRecord(
        lessonId: j['lessonId'] as String,
        completedAt: DateTime.parse(j['completedAt'] as String),
        workedSeconds: (j['workedSeconds'] as num).toInt(),
        unitsCompleted: (j['unitsCompleted'] as num).toInt(),
        plannedUnits: (j['plannedUnits'] as num).toInt(),
        unitLabel: j['unitLabel'] as String,
        lessonClass: LessonClass.values
            .firstWhere((LessonClass c) => c.name == j['lessonClass']),
        unmeasuredUnits: (j['unmeasuredUnits'] as num?)?.toInt() ?? 0,
        unmeasuredReason: j['unmeasuredReason'] as String?,
      );

  final String lessonId;
  final DateTime completedAt;

  /// Fiilen ÇALIŞILAN saniye — dinlenme HARİÇ (JabLab gerekçesi: ilerleme
  /// kapıları çalışma süresini sayıyor; dinlenmeyi toplasak kullanıcı kapıyı
  /// hak etmeden geçerdi).
  final int workedSeconds;

  /// ÖLÇÜLEN iş birimi. Yarıda bırakılan seans da kaydedilir — "bıraktı" bir
  /// veridir, silinmesi gereken bir utanç değil.
  final int unitsCompleted;
  final int plannedUnits;

  /// Birimin adı (`rep` · `second`). **Kayıt-başına** taşınır (delta 1).
  final String unitLabel;

  final LessonClass lessonClass;

  /// Görülen ama HÜKÜM VERİLEMEYEN birim sayısı (delta 3). `unitsCompleted`
  /// ölçülenleri sayar; kullanıcının yaptığı iş ikisinin TOPLAMIdır.
  final int unmeasuredUnits;

  /// Neden ölçülemedi (PRD §3.4 listesi: kadraj · ışık · çok kişi · kamera
  /// hareketi). `unmeasuredUnits == 0` ise anlamsızdır.
  final String? unmeasuredReason;

  bool get isComplete => unitsCompleted >= plannedUnits;

  /// Kullanıcının yaptığı toplam iş — ölçülen + ölçülemeyen.
  int get attemptedUnits => unitsCompleted + unmeasuredUnits;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lessonId': lessonId,
        'completedAt': completedAt.toUtc().toIso8601String(),
        'workedSeconds': workedSeconds,
        'unitsCompleted': unitsCompleted,
        'plannedUnits': plannedUnits,
        'unitLabel': unitLabel,
        'lessonClass': lessonClass.name,
        'unmeasuredUnits': unmeasuredUnits,
        if (unmeasuredReason != null) 'unmeasuredReason': unmeasuredReason,
      };
}

/// Dersin o gün SKORLANIP skorlanmadığı (delta 2).
///
/// `measurementOnly`: ölçülüyor ama notlanmıyor — Gravita'da kilitli form
/// dersinin durumu (rep sayımı çalışır, form notu çalışmaz). Choreia'nın
/// `demoOnly`'siyle aynı AYRIM, farklı ad; ortak ad terfi günü seçilecek.
enum LessonClass { scored, measurementOnly }

/// Seans geçmişi deposu — **arayüz kasıtlı olarak DAR** (üçler kuralı).
abstract interface class SessionStore {
  Future<void> append(SessionRecord record);

  /// En yeni ÖNCE.
  Future<List<SessionRecord>> recent({int? limit});

  Future<int> workedSecondsFor(String lessonId);
}

/// Append-only JSONL depo.
///
/// **Neden JSONL ve append-only** (JabLab kaydı): seans kaydı bir OLAY
/// akışıdır, sorgu yükü yok. Bir DB şema göçü + platform bağımlılığı
/// getirirdi; sorgu ihtiyacı ÖLÇÜLDÜĞÜNDE gelir. (Hive aile-gotcha'sı ayrıca
/// kayıtlı: yanlış cipher'da FIRLATMAZ, içeriği sessizce siler.)
///
/// **Her satır kendi şema sürümünü taşır** — dosya düzeyinde tek sürüm, eski
/// satırların hangi kurala göre yazıldığını okunamaz kılar.
///
/// **Atomiklik:** geçici dosyaya yazıp `rename` ile yerine koyar. Doğrudan
/// append sırasında süreç ölürse (mobilde OS uygulamayı her an öldürebilir)
/// dosya sonunda YARIM satır kalır; `rename` POSIX'te atomiktir.
///
/// ⚠️ **Saf Dart — Flutter bağımlılığı YOK.** Kurucu bir `File` alır;
/// `path_provider` ÇAĞRI YERİNİN işidir. Choreia'nın "port yapılamaz" hükmü
/// bu ayrımı görmediği için verilmişti (delta belgesi §0).
final class JsonlSessionStore implements SessionStore {
  JsonlSessionStore(this._file);

  /// Bugünkü satır şeması. Yeni alan eklenince ARTIRILIR; okuma tarafı
  /// bilmediği sürümü ATLAR (patlamaz) — ileri uyumluluk, çünkü kullanıcı
  /// uygulamayı geri de kurabilir.
  static const int schemaVersion = 1;

  final File _file;

  @override
  Future<void> append(SessionRecord record) async {
    final String line = jsonEncode(<String, dynamic>{
      'v': schemaVersion,
      ...record.toJson(),
    });
    final String existing =
        await _file.exists() ? await _file.readAsString() : '';
    final String next = existing.isEmpty ? '$line\n' : '$existing$line\n';
    final File tmp = File('${_file.path}.tmp');
    await tmp.parent.create(recursive: true);
    await tmp.writeAsString(next, flush: true);
    await tmp.rename(_file.path);
  }

  @override
  Future<List<SessionRecord>> recent({int? limit}) async {
    final List<SessionRecord> all = await _readAll();
    all.sort((SessionRecord a, SessionRecord b) =>
        b.completedAt.compareTo(a.completedAt));
    if (limit == null || limit >= all.length) return all;
    return all.sublist(0, limit);
  }

  @override
  Future<int> workedSecondsFor(String lessonId) async {
    int total = 0;
    for (final SessionRecord r in await _readAll()) {
      if (r.lessonId == lessonId) total += r.workedSeconds;
    }
    return total;
  }

  Future<List<SessionRecord>> _readAll() async {
    // DEĞİŞTİRİLEBİLİR liste dönmek ZORUNLU: `recent()` sonucu yerinde
    // sıralıyor. JabLab'da `const []` dönmek boş-geçmiş yolunu — yani İLK
    // AÇILIŞI — çökertmişti; testin yakaladığı gerçek kusur.
    if (!await _file.exists()) return <SessionRecord>[];
    final List<SessionRecord> out = <SessionRecord>[];
    for (final String raw in (await _file.readAsString()).split('\n')) {
      final String line = raw.trim();
      if (line.isEmpty) continue;
      // BOZUK SATIR TÜM GEÇMİŞİ SİLMEZ: yarım yazılmış ya da gelecekten gelen
      // bir satır yüzünden aylarca birikmiş kaydı okunamaz ilan etmek, veriyi
      // kaybetmekle aynı sonucu verir — o satır atlanır, gerisi okunur.
      try {
        final Map<String, dynamic> j =
            (jsonDecode(line) as Map).cast<String, dynamic>();
        final int v = (j['v'] as num?)?.toInt() ?? 0;
        if (v != schemaVersion) continue;
        out.add(SessionRecord.fromJson(j));
      } on Object catch (_) {
        continue;
      }
    }
    return out;
  }
}
