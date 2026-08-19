import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/content_repository.dart';
import 'package:gravita/app/program/program_builder.dart';
import 'package:gravita/app/program/program_model.dart';
import 'package:gravita/app/program/program_schedule_store.dart';
import 'package:gravita/app/program/program_store.dart';
import 'package:gravita/app/theme.dart';
import 'package:gravita/app/workout/workout_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/launch_harness.dart' show FakeSupportDir, realIo, settleUntil;

/// GRA-P1-003 Step 3/4 — RPE toplama (yalnız kullanıcı beyanı, "camera
/// sonucu değildir") + kaçırılan günü CEZASIZ yeniden sıralama. İkisi de
/// `WorkoutScreen`in KENDİ yükleyicisi + `ProgramScheduleStore`ın GERÇEK
/// G/Ç zinciriyle sınanıyor — `FakeSupportDir`/`realIo`/`settleUntil`
/// `test/support/launch_harness.dart`tan, İKİNCİ bir sahte YAZILMADI.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PathProviderPlatform defaultProvider;
  late Directory tmp;
  late ContentRepository content;

  setUp(() async {
    defaultProvider = PathProviderPlatform.instance;
    tmp = await Directory.systemTemp.createTemp('gra_workout_flow');
  });

  tearDown(() async {
    PathProviderPlatform.instance = defaultProvider;
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Widget host(Widget child) =>
      MaterialApp(theme: GravitaTheme.light, home: child);

  // `_DayCard._isMissed`in AYNI gün-bazlı karşılaştırması (saat DEĞİL) —
  // `settleUntil`in gerçek-zaman turları test gövdesinde SANİYELER
  // geçirebilir, tam ANA karşılaştırma bu yüzden GERÇEK saatte kayan bir
  // testte YANLIŞ pozitif verirdi (ölçüldü: birinci yazımda `isBefore`
  // birkaç saniyelik sürüklenme yüzünden `true` çıktı).
  DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  const ProgramInputs inputs = ProgramInputs(
    availableEquipment: <String>{},
    daysPerWeek: 3,
    experience: ExperienceLevel.beginner,
  );

  /// Girdi + takvimi GERÇEK G/Ç ile önceden kurar — `program_builder_test.
  /// dart`ın GERÇEK katalog entegrasyon testiyle AYNI girdi (beginner+
  /// bodyweight, çökmediği zaten kanıtlı). [scheduleStart] takvimin İLK
  /// gününü belirler; geçmişte bir tarih verilirse o gün "kaçırıldı" olur.
  Future<int> seed(WidgetTester tester, DateTime scheduleStart) async {
    PathProviderPlatform.instance = FakeSupportDir(tmp.path);
    await tester.runAsync(
        () async => content = await ContentRepository.load(rootBundle));

    await realIo(
        tester, () async => (await ProgramStore.open()).write(inputs));

    final WorkoutProgram program = await realIo(tester, () async {
      final ProgramConfig config =
          await ContentRepository.loadProgramConfig(rootBundle);
      final List<ProgramCatalogEntry> entries =
          await content.programCatalogEntries();
      return ProgramBuilder(config: config, catalog: entries).build(inputs);
    });

    final ProgramSchedule schedule = ProgramSchedule(
      dates: scheduleProgram(
          program: program, startDate: scheduleStart, daysPerWeek: 3),
      rpeByDayIndex: const <int, int>{},
    );
    await realIo(tester,
        () async => (await ProgramScheduleStore.open()).write(schedule));

    return program.days.length;
  }

  testWidgets(
      'RPE toplama — GERÇEK dokunuştan geliyor, kalıcı, kamera DEĞİL',
      (WidgetTester tester) async {
    // Takvim BUGÜN başlıyor — 1. gün henüz kaçırılmamış, "Mark done" akışı.
    await seed(tester, DateTime.now());

    await tester.pumpWidget(host(WorkoutScreen(content: content)));
    // ⚠️ `maxRounds` VARSAYILANDAN (10) YÜKSELTİLDİ — ölçüldü: `WorkoutScreen`i
    // KÖK olarak doğrudan pump etmek (`program_setup_screen_test.dart`ın
    // AKSİNE, orada ÖNCE bir ekran daha ısınıyor) soğuk-açılış G/Ç zincirini
    // (asset + iki store okuması) 10 turda BİTİREMEDİ — 30 turda güvenle
    // bitti. Bu bir "sonsuz asılı kalma" DEĞİL, ölçülen bir yavaşlık payı.
    await settleUntil(
        tester,
        () => find
            .byKey(const ValueKey<String>('workout.markDone.1.1'))
            .evaluate()
            .isNotEmpty,
        maxRounds: 30);

    await tester
        .tap(find.byKey(const ValueKey<String>('workout.markDone.1.1')));
    await tester.pump();

    // RPE 7 seç — çip metniyle DEĞİL, `ChoiceChip` soyundan arayarak (başka
    // bir yerde tesadüfen "7" metni olabilir, ör. set/tekrar sayısı).
    await tester.tap(find.descendant(
        of: find.byType(ChoiceChip), matching: find.text('7')));
    await tester.pump();

    await tester
        .tap(find.byKey(const ValueKey<String>('workout.saveRpe.1.1')));
    await settleUntil(
        tester, () => find.text('Done · RPE 7').evaluate().isNotEmpty,
        maxRounds: 30);

    expect(find.text('Done · RPE 7'), findsOneWidget,
        reason: 'UI-GÖZLEMLİ İDDİA: kaydedilen RPE ekranda GÖRÜNÜYOR.');

    // MOTOR-SONUCU İDDİASI — ayrı: ekranın kendi belleğine güvenmeden,
    // BAĞIMSIZ bir store örneğiyle diskten OKUNARAK doğrulanıyor.
    final ProgramSchedule? saved = await realIo(
        tester, () async => (await ProgramScheduleStore.open()).read());
    expect(saved, isNotNull);
    expect(saved!.rpeByDayIndex[0], 7,
        reason: 'GERÇEKTEN kalıcı — RPE kamera/motor sonucu DEĞİL, yalnız '
            'bu dokunuşun taşıdığı sayı.');
  });

  testWidgets(
      'kaçırılan gün CEZASIZ yeniden sıralanıyor — kayıp/tekrar YOK, kalıcı',
      (WidgetTester tester) async {
    // 1. gün TAM BİR aralık (gapDays) önce planlanmış → bugünden ÖNCE,
    // yani "kaçırıldı". 2. gün TAM BUGÜN (gapDays sonra) — henüz kaçırılmadı.
    // Bu seçim BİLEREK: yeniden sıralama sonrası 1. gün TAM bugüne kayar ve
    // "Missed" etiketi KAYBOLUR — koşul-bağlı bekleme için gözlemlenebilir,
    // gerçek bir tarih-sınır sabiti UYDURMADAN.
    final int totalDays = await seed(
        tester, DateTime.now().subtract(const Duration(days: 2)));

    await tester.pumpWidget(host(WorkoutScreen(content: content)));
    // ⚠️ `maxRounds` yükseltildi — üstteki testle AYNI ölçülmüş gerekçe.
    await settleUntil(
        tester,
        () => find
            .byKey(const ValueKey<String>('workout.reschedule.1.1'))
            .evaluate()
            .isNotEmpty,
        maxRounds: 30);

    expect(find.text('Missed'), findsOneWidget,
        reason: '1. gün geçmişte planlanmıştı — kaçırıldı sayılmalı.');

    await tester
        .tap(find.byKey(const ValueKey<String>('workout.reschedule.1.1')));
    await settleUntil(tester, () => find.text('Missed').evaluate().isEmpty,
        maxRounds: 30);

    expect(find.text('Missed'), findsNothing,
        reason: 'UI-GÖZLEMLİ İDDİA: yeniden sıralama sonrası 1. gün artık '
            'kaçırılmış GÖRÜNMÜYOR.');

    // MOTOR-SONUCU İDDİASI — ayrı, diskten okunarak.
    final ProgramSchedule? saved = await realIo(
        tester, () async => (await ProgramScheduleStore.open()).read());
    expect(saved, isNotNull);
    expect(saved!.dates.length, totalDays,
        reason: 'CEZASIZ: hiçbir seans SİLİNMEDİ ya da EKLENMEDİ, yalnız '
            'tarihler kaydı.');
    expect(dateOnly(saved.dates[0]).isBefore(dateOnly(DateTime.now())), isFalse,
        reason: '1. günün YENİ tarihi artık geçmişte DEĞİL.');
    expect(saved.rpeByDayIndex, isEmpty,
        reason: 'Yeniden sıralama TAMAMLANMA durumunu DEĞİŞTİRMEZ — yalnız '
            'tarih kayar, hiçbir gün sahte "done" olmaz.');
  });
}
