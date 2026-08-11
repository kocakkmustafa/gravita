import 'dart:convert';
import 'dart:io';

import 'package:gravita_engine/gravita_engine.dart';
import 'package:test/test.dart';

/// İlerleme yüzeyi ↔ GERÇEK içerik kablolaması.
///
/// `progress_summary_test.dart` matematiği elle kurulmuş yüzeylerle sınıyor.
/// Bu dosya farklı bir soruyu soruyor: **yüzey listesi gerçek içerikten
/// TÜRETİLEBİLİYOR mu?** Türetilemiyorsa `LessonSurface` listesi elle yazılır,
/// elle yazılan liste `library.json` ile ayrışır ve bir ders bir gün yüzeyden
/// sessizce düşer — gecenin tekrar eden dersinin ("beyan var, okuyanı yok")
/// bu ürüne düşen hâli.
///
/// Kablolamanın gerçek getirisi ölçüldü: `unitLabel` KATALOGDAN gelir
/// (`engine.type`), `library.json`da böyle bir alan YOKTUR. Elle yazılsaydı
/// bir statik tutuş dersi yüzeyde "5 tekrar" diye görünebilirdi.
void main() {
  final Map<String, dynamic> library =
      jsonDecode(File('../../content/library.json').readAsStringSync())
          as Map<String, dynamic>;

  /// Katalog dosyasını DALGA-BAĞIMSIZ bulur. `w1` sabitlemek, W2'nin 11
  /// hareketini kapı dışında bırakan hatanın (catalog_smoke_test) aynısı olurdu.
  File catalogFile(String id) {
    final List<Directory> waves = Directory('../../content/catalog')
        .listSync()
        .whereType<Directory>()
        .toList()
      ..sort((Directory a, Directory b) => a.path.compareTo(b.path));
    for (final Directory w in waves) {
      final File f = File('${w.path}/$id.json');
      if (f.existsSync()) return f;
    }
    throw StateError('Katalogda yok: $id (hiçbir dalgada)');
  }

  /// Yüzey listesini ÜRETİM yoluyla türetir — `LessonSurface.deriveAll`.
  ///
  /// Testin kendi türetmesini yazması cazipti; yazmadım. İki türetme
  /// tutarsızlaşır (G-079 dersi): test `status: locked`i okur, üretim okumaz ve
  /// kilitli ders üretimde AÇIK görünür — test YEŞİL kalarak. Bu yüzden test
  /// üretimin çağırdığı fonksiyonun AYNISINI çağırıyor; buradaki tek fark
  /// katalog dosyasının nereden okunduğu.
  List<LessonSurface> deriveSurfaces() => LessonSurface.deriveAll(
        library: library,
        catalogFor: (String cid) =>
            MovementConfig.parse(catalogFile(cid).readAsStringSync()),
      );

  test('yüzey listesi gerçek içerikten türetilebiliyor', () {
    final List<LessonSurface> s = deriveSurfaces();
    expect(s, isNotEmpty);
    // Bugünkü içerik (2026-08-12, G-133): push_up'ın iki dersi + squat'ın
    // terfisiyle gelen iki ders (pencere-koşulu, K14/G-128/G-131/G-132).
    expect(s.map((LessonSurface x) => x.id).toList(), <String>[
      'push_foundations.reps_and_tempo',
      'push_foundations.form_check',
      'leg_foundations.reps_and_depth',
      'leg_foundations.depth_and_lean_check',
    ]);
    expect(s.every((LessonSurface x) => x.unitLabel == 'rep'), isTrue,
        reason: 'push_up VE bodyweight_squat ikisi de repFsm — birim '
            'TEKRAR. Katalogdan geldi, elle değil.');
  });

  test('coming_soon hareket yüzeye ders SOKMAZ', () {
    final Iterable<Map<String, dynamic>> soon =
        (library['movements'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .where((Map<String, dynamic> m) => m['status'] == 'coming_soon');
    expect(soon, isNotEmpty, reason: 'Test konusu kalmadıysa güncelle.');
    for (final Map<String, dynamic> m in soon) {
      expect((m['courses'] as List<dynamic>?) ?? const <dynamic>[], isEmpty,
          reason: '${m['id']}: sahte kurs listelenemez (K1).');
    }
  });

  test('boş geçmişte HİÇBİR ders düşmüyor; kilitli ders gerekçesiyle görünüyor',
      () {
    final List<LessonSurface> surfaces = deriveSurfaces();
    final ProgressSummary s = ProgressSummary.build(
      lessonSurfaces: surfaces,
      records: const <SessionRecord>[],
    );
    expect(s.lessons.length, surfaces.length);
    expect(s.orphanRecordLessonIds, isEmpty);

    final LessonProgress form = s.lessons.firstWhere(
        (LessonProgress l) => l.lessonId == 'push_foundations.form_check');
    expect(form.state, LessonProgressState.locked);
    expect(form.lockedReason, contains('default floor'),
        reason: 'Kilit gerekçesi içerikten geliyor — motor metin ÜRETMİYOR.');

    final LessonProgress reps = s.lessons.firstWhere(
        (LessonProgress l) => l.lessonId == 'push_foundations.reps_and_tempo');
    expect(reps.state, LessonProgressState.notStarted);
  });

  test('BUGÜN forma not veren AÇIK ders YOK — retroaktif kural henüz uykuda', () {
    // Bu bir ÖLÇÜM, dilek değil: `gradedToday` bugün hiçbir derste true değil
    // (form dersi kilitli, tekrar dersi zaten not vermiyor). Yani
    // `withheldRetroactiveCredit` bugün yapısal olarak 0 olmak ZORUNDA.
    // Form notu açıldığı gün bu test DÜŞER ve retroaktif kuralın gerçek
    // veriyle sınanması gerektiğini hatırlatır — bayat-yokluk (M-F-165)
    // karşıtı bir nöbet.
    final List<LessonSurface> surfaces = deriveSurfaces();
    expect(surfaces.any((LessonSurface x) => x.gradedToday), isFalse,
        reason: 'Bir ders forma not vermeye BAŞLADI. Retroaktif kredi kuralını '
            'gerçek geçmişle sına: eski kayıtlar measurementOnly olarak '
            'yazılmıştı ve öyle KALMALI.');
    expect(
      ProgressSummary.build(
        lessonSurfaces: surfaces,
        records: <SessionRecord>[
          SessionRecord(
            lessonId: 'push_foundations.reps_and_tempo',
            completedAt: DateTime.utc(2026, 7, 30),
            workedSeconds: 90,
            unitsCompleted: 6,
            plannedUnits: 8,
            unitLabel: 'rep',
            lessonClass: 'measurementOnly',
          ),
        ],
      ).withheldRetroactiveCredit,
      0,
    );
  });
}
