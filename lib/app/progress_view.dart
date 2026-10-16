import 'package:flutter/material.dart';
import 'package:gravita_engine/gravita_engine.dart';

import 'content_failure.dart';
import 'camera_release_policy.dart';
import 'progress_copy.dart';
import 'theme.dart';

/// İlerleme yüzeyinin **YAPISI** — görsel tasarım artık design panel v1'den
/// (`docs/design/DESIGN-PANEL-PROMPT.md`, `theme.dart`).
///
/// ## Bu widget ne için var
///
/// M-F-168'in üç kuralı (*ölçümler not değil · geçilemez kapı beyan edilir ·
/// retroaktif kredi yok*) biçim tercihi değil, **neyin neyin yanında
/// görünebileceğine dair kısıt.** Kilitli ders listeden düşmemeli · ölçülemeyen
/// iş görünmeli · geçmişe not verilmemeli. Bu kısıtların **SINANMIŞ KODDA**
/// olması gerekiyor ki tasarım turu onları DEVRALSIN, yeniden keşfetmek zorunda
/// kalmasın. JabLab emsali: yapı-düzeyi widget testleri gerçek bir dürüstlük
/// kusurunu yakaladı (üç ders kendi kapısını geçemiyordu).
///
/// ## Giydirme turu (M-F-282, 2026-08-06) neyi değiştirdi, neyi değiştirmedi
///
/// Bu dosyanın önceki hâli "biçim BİLEREK yok" diyordu — artık var, ama
/// hangi ders/not HANGİ bölümde göründüğüne dair YAPI aynı `build()` mantığı:
/// sadece `_section`/`_measuredRow`/`_lockedRow` gibi yardımcıların İÇİ,
/// [GravitaCard]/[GravitaType] ile giydirildi. Testler bunu doğruluyor:
/// `test/progress_view_test.dart` bu dosyaya TEK satır dokunmadan aynen geçti.
///
/// Kanıtın sınırı NET olsun: yapı testle kanıtlandı **ve kabuk iPhone 17 Pro Max
/// simülatöründe GERÇEKTEN koştu** (G-100 ekran görüntüsü). Kamera yolu hâlâ
/// yok; bu ekran ondan bağımsız.
///
/// ⚠️ Simülatörde koşturmanın bedeli hemen ödendi: 16 test yeşilken ekranda ders
/// adı yerine `push_foundations.reps_and_tempo` yazıyordu ve altta sahipsiz bir
/// boş "Notes" başlığı duruyordu. İkisi de bu dosyada düzeltildi ve ikisi için
/// de nöbet eklendi. Testlerim kimliği iddia ettiği için kimliğin sızmasını
/// kutsamışlardı — "testler yeşil ≠ kullanıcı doğru şeyi görüyor".
///
/// Her bölüm bir [Key] taşıyor: bir test, bir metnin HANGİ BÖLÜMDE geçtiğini
/// iddia edebilsin. "Metin bir yerde var" diyen test, iki bölüm birleştirilse
/// bile geçerdi — `ProgressSummary`'nin tip ayrımı tam bunu önlemek için var.
class ProgressView extends StatelessWidget {
  const ProgressView({
    required this.summary,
    this.historyStatus = const HistoryOk(),
    this.freeSessions = const <SessionRecord>[],
    super.key,
  });

  static const Key measuredSectionKey = Key('progress.measured');
  static const Key lockedSectionKey = Key('progress.locked');
  static const Key notesSectionKey = Key('progress.notes');
  static const Key freeSectionKey = Key('progress.free');
  static const Key historyFailureKey = Key('progress.historyUnavailable');

  /// Kısmi okuma beyanı — `historyFailureKey`den AYRI anahtar: iki hâl
  /// yüzeyde de ayrı ayrı sınanabilsin (biri ötekinin yerine geçemez).
  static const Key historyPartialKey = Key('progress.historyPartial');

  final ProgressSummary summary;

  /// ⭐ GRAVITA DELTASI (bkz. `content_failure.dart`): geçmiş okunamadıysa
  /// BLOKLAMIYORUZ (içerik sağlam) ama ölçüm bölümü sayı GÖSTERMEZ — yerine
  /// ne olduğunu söyler. Aksi hâlde her ders "Not started" görünür ve bu
  /// "hiç çalışmadın" demektir.
  final HistoryStatus historyStatus;

  /// Ders bağlamı DIŞINDA yapılmış seanslar (G-132 serbest kovası).
  ///
  /// ⚠️ `summary`ye HİÇ verilmez — ders trendine karışamaz. Ama ayrı bölümde
  /// GÖRÜNÜR: okunmadığı sürece bu ekran, gerçek bir seans yapmış kullanıcıya
  /// "Not started" diyordu.
  final List<SessionRecord> freeSessions;

  @override
  Widget build(BuildContext context) {
    final copy = ProgressCopy(context);
    final List<LessonProgress> open = summary.lessons
        .where((LessonProgress l) => l.state != LessonProgressState.locked)
        .toList(growable: false);
    // Kilitli dersler AYRI bölümde ama listeden DÜŞMEZ. Kilitliyken geçmişi
    // olan ders de burada — geçmişini göstermek onu gizlemekten iyidir.
    final List<LessonProgress> locked = summary.lessons
        .where((LessonProgress l) => l.state == LessonProgressState.locked)
        .toList(growable: false);

    final List<Widget> notes = historyStatus is HistoryUnavailable
        ? <Widget>[]
        : <Widget>[
            if (summary.withheldRetroactiveCredit > 0)
              _noteCard(
                Text(
                  copy.retroactiveWithheld(summary.withheldRetroactiveCredit),
                ),
              ),
            if (summary.hasHistoryUnderLock)
              _noteCard(Text(copy.historyUnderLock)),
            if (summary.orphanRecordLessonIds.isNotEmpty)
              _noteCard(
                Text(copy.orphanRecords(summary.orphanRecordLessonIds.length)),
              ),
          ];

    return ListView(
      // ⚠️ Alt pay 40 → 96 (G-203). Kabuğun seans düğmesi `centerFloat` ile
      // içeriğin ÜSTÜNDE yüzüyor; 40 ile son kart **hiçbir kaydırma
      // konumunda** temize çıkmıyordu (simülatörde ölçüldü: `Body-line
      // check` gövdesi düğmenin altında kalıyor). Diğer üç sekme zaten 96
      // ayırıyordu — kural biliniyordu, burada uygulanmamıştı.
      // Nöbetçisi: `test/fab_clearance_test.dart`, payı düğmenin GERÇEK
      // geometrisinden türetiyor.
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
      children: <Widget>[
        if (!motionPaidCameraLaunchEnabled) ...<Widget>[
          _noteCard(Text(copy.releaseBoundary)),
          const SizedBox(height: 20),
        ],
        _section(
          key: measuredSectionKey,
          title: copy.measuredSection,
          subtitle: copy.measuredSubtitle,
          // ÜÇ HÂL (çekirdek 0.10.0). Sıra önemli: `unavailable` sayıyı
          // GÖSTERMEZ, `partial` GÖSTERİR ama tabanın eksik olduğunu söyler.
          // İki beyan AYRI cümledir — biri ötekini susturmaz.
          children: switch (historyStatus) {
            HistoryUnavailable() => <Widget>[_historyUnavailableCard(copy)],
            HistoryPartial(:final int unreadableRecords) => <Widget>[
              _historyPartialBanner(copy, unreadableRecords),
              if (open.isEmpty)
                _emptyCard(copy.emptyHistory)
              else
                ...open.map((l) => _measuredRow(copy, l)),
            ],
            HistoryOk() =>
              open.isEmpty
                  ? <Widget>[_emptyCard(copy.emptyHistory)]
                  : open
                        .map((l) => _measuredRow(copy, l))
                        .toList(growable: false),
          },
        ),
        if (locked.isNotEmpty) ...<Widget>[
          const SizedBox(height: 32),
          _section(
            key: lockedSectionKey,
            title: copy.lockedSection,
            subtitle: copy.lockedSubtitle,
            children: locked
                .map((l) => _lockedRow(copy, l))
                .toList(growable: false),
          ),
        ],
        // ⚠️ BOŞ "Notes" başlığı ÇİZİLMEZ. İlk hâlinde çiziliyordu ve
        // simülatörde ekranın altında sahipsiz bir "Notes" kelimesi duruyordu:
        // başlık bir SÖZ verir, altı boşsa söz tutulmaz. Choreia'nın "boş bölüm
        // bir CÜMLEDİR" kaydının tersten hâli — orada boşluğun İÇİNE gerekçe
        // konmuştu, burada söylenecek bir şey YOK, o yüzden bölüm de yok.
        if (historyStatus is! HistoryUnavailable &&
            freeSessions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 32),
          _section(
            key: freeSectionKey,
            title: copy.freeSection,
            subtitle: copy.freeSubtitle,
            children: <Widget>[
              GravitaCard(
                child: Text(
                  copy.freeSessions(freeSessions),
                  style: GravitaType.mono(size: 11.5, color: GravitaColors.ink),
                ),
              ),
            ],
          ),
        ],
        if (notes.isNotEmpty) ...<Widget>[
          const SizedBox(height: 32),
          _section(
            key: notesSectionKey,
            title: copy.notesSection,
            children: notes,
          ),
        ],
      ],
    );
  }

  Widget _measuredRow(ProgressCopy copy, LessonProgress l) {
    final bool notStarted = l.state == LessonProgressState.notStarted;
    return GravitaCard(
      key: Key('progress.measured.${l.lessonId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ⚠️ HAREKET ADI ÜST SATIRDA — ve bu bir süs değil, AYIRT EDİCİ.
          // Simülatörde yürüyünce ölçüldü (G-203): bu ekranda **iki satır da**
          // "Reps that count" yazıyordu (biri squat'ın, biri şınavın) ve
          // kullanıcı hangisinin hangisi olduğunu **bilemiyordu**.
          // Ders adı kendi hareketinin bağlamında doğru; düşen şey BAĞLAMDI.
          _overline(copy.movementName(l)),
          const SizedBox(height: 4),
          // Kullanıcıya AD gösterilir, kimlik gösterilmez. `lessonId` yalnız
          // [Key]'de: test hangi satıra baktığını bilsin diye.
          Text(
            copy.lessonName(l),
            style: GravitaType.display(size: 16, weight: FontWeight.w500),
          ),
          if (notStarted) ...<Widget>[
            const SizedBox(height: 6),
            // "Hiç yapmadın" bir VERİdir; satırı silmek onu saklamak olurdu.
            Text(
              copy.notStarted,
              style: GravitaType.body(
                size: 13,
                color: GravitaColors.textSecondary,
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 10),
            // Birim satırdan gelir, çıplak sayı YOK.
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: <Widget>[
                _stat(copy.units(l.unitsMeasured, l.unitLabel)),
                _stat(copy.worked(l.workedSeconds)),
                _stat(copy.sessions(l.sessionCount)),
              ],
            ),
            if (l.unitsUnmeasured > 0) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                copy.unmeasured(
                  l.unitsUnmeasured,
                  l.unitLabel,
                  l.unmeasuredReasons,
                ),
                style: GravitaType.body(
                  size: 12.5,
                  color: GravitaColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
            if (l.unscoredSessions > 0) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                copy.unscored(l.unscoredSessions),
                style: GravitaType.mono(
                  size: 10.5,
                  color: GravitaColors.textSecondary,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _lockedRow(ProgressCopy copy, LessonProgress l) {
    return GravitaCard(
      key: Key('progress.locked.${l.lessonId}'),
      sealed: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Kilitli satırda da aynı ayrım gerekli: iki hareketin
                    // kilitli dersleri farklı adlar taşıyor OLABİLİR, ama
                    // "olabilir" bir güvence değildir (M-F-194 pozitif-ikiz
                    // mantığının yüzeydeki hâli).
                    _overline(copy.movementName(l)),
                    const SizedBox(height: 4),
                    Text(
                      copy.lessonName(l),
                      style: GravitaType.display(
                        size: 15.5,
                        weight: FontWeight.w500,
                        color: GravitaColors.honestyText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GravitaPill(
                label: copy.lockedBadge,
                tone: GravitaColors.honestySeal,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Only an exact reviewed source gets display translation or release-access clarification.
          // Gerçek katalog verisi bunun tek satır olmadığını gösterdi
          // (`push_foundations.form_check`: ~400 karakterlik paragraf) —
          // bu yüzden [GravitaCard] esnek yükseklikte, sabit-boy YOK.
          Text(
            copy.lockedReason(l),
            style: GravitaType.body(
              size: 13,
              color: GravitaColors.honestyText,
              height: 1.55,
            ),
          ),
          // Kilitli ders ÇALIŞILMIŞSA sayıları da görünür: kilit ölçümü kapatır,
          // geçmişi silmez.
          if (historyStatus is! HistoryUnavailable &&
              l.sessionCount > 0) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: <Widget>[
                _stat(
                  copy.units(l.unitsMeasured, l.unitLabel),
                  color: GravitaColors.honestyText,
                ),
                _stat(
                  copy.sessions(l.sessionCount),
                  color: GravitaColors.honestyText,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _historyUnavailableCard(ProgressCopy copy) => GravitaCard(
    key: historyFailureKey,
    sealed: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(
          Icons.history_toggle_off,
          color: GravitaColors.honestySeal,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            copy.historyUnavailable,
            style: GravitaType.body(
              size: 13.5,
              color: GravitaColors.honestyText,
              height: 1.55,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _historyPartialBanner(ProgressCopy copy, int unreadable) =>
      GravitaCard(
        sealed: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(
              Icons.info_outline,
              color: GravitaColors.honestySeal,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              // Key doğrudan Text'te: bir test `tester.widget<Text>(...)`
              // ile içeriğini okuyor, sarmalayıcıda olsa tip hatası verirdi.
              child: Text(
                copy.historyPartial(unreadable),
                key: historyPartialKey,
                style: GravitaType.body(
                  size: 13,
                  color: GravitaColors.honestyText,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _emptyCard(String text) => GravitaCard(
    child: Text(
      text,
      style: GravitaType.body(size: 13.5, color: GravitaColors.textSecondary),
    ),
  );

  Widget _noteCard(Widget child) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: GravitaColors.textTertiary.withValues(alpha: 0.35),
      ),
    ),
    child: DefaultTextStyle.merge(
      style: GravitaType.body(
        size: 12.5,
        color: GravitaColors.textSecondary,
        height: 1.6,
      ),
      child: child,
    ),
  );

  /// Satırın HANGİ HAREKETE ait olduğunu söyleyen üst satır.
  ///
  /// ⚠️ Yeni bir görsel dil İCAT ETMİYOR: bölüm başlıklarının (`_section`)
  /// zaten kullandığı mono/aralıklı/ikincil dizgisinin aynısı, bir punto
  /// küçüğü. *Bir kusuru düzeltirken tasarım yönü açmak, düzeltmenin
  /// kendisini bir karara dönüştürürdü* (M-F-77).
  Widget _overline(String text) => Text(
    text.toUpperCase(),
    style: GravitaType.mono(
      size: 10.5,
      color: GravitaColors.textSecondary,
      weight: FontWeight.w600,
      letterSpacingEm: 0.12,
    ),
  );

  Widget _stat(String text, {Color color = GravitaColors.ink}) => Text(
    text,
    style: GravitaType.mono(size: 11.5, color: color, weight: FontWeight.w500),
  );

  Widget _section({
    required Key key,
    required String title,
    required List<Widget> children,
    String? subtitle,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: GravitaType.mono(
            size: 11,
            color: GravitaColors.textSecondary,
            weight: FontWeight.w600,
            letterSpacingEm: 0.12,
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: GravitaType.body(
              size: 12.5,
              color: GravitaColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 14),
        for (int i = 0; i < children.length; i++) ...<Widget>[
          children[i],
          if (i < children.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}
