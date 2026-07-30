import 'package:flutter/widgets.dart';
import 'package:gravita_engine/gravita_engine.dart';

import 'progress_strings.dart';

/// İlerleme yüzeyinin **YAPISI** — görsel tasarım BİLEREK yok.
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
/// ## Bu widget ne DEĞİL
///
/// Bitmiş ekran değil. Renk, tipografi, boşluk, ikonografi ve yerleşim
/// tasarım turunun işi. **Tasarım BİÇİMİ değiştirir, YAPIYI devralır — icat
/// etmez.** Tema bilerek Material varsayılanı.
///
/// Kanıtın sınırı NET olsun: yapı testle kanıtlandı **ve kabuk iPhone 17 Pro Max
/// simülatöründe GERÇEKTEN koştu** (G-100 ekran görüntüsü) — yani "derlendi ama
/// koşmadı" değil. Kanıtlanmayan şey GÖRÜNÜŞÜN İYİ OLDUĞU: ekran şu an
/// biçimlendirilmemiş düz metin. Kamera yolu da hâlâ yok.
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
  const ProgressView({required this.summary, super.key});

  static const Key measuredSectionKey = Key('progress.measured');
  static const Key lockedSectionKey = Key('progress.locked');
  static const Key notesSectionKey = Key('progress.notes');

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final List<LessonProgress> open = summary.lessons
        .where((LessonProgress l) => l.state != LessonProgressState.locked)
        .toList(growable: false);
    // Kilitli dersler AYRI bölümde ama listeden DÜŞMEZ. Kilitliyken geçmişi
    // olan ders de burada — geçmişini göstermek onu gizlemekten iyidir.
    final List<LessonProgress> locked = summary.lessons
        .where((LessonProgress l) => l.state == LessonProgressState.locked)
        .toList(growable: false);

    final List<Widget> notes = <Widget>[
      if (summary.withheldRetroactiveCredit > 0)
        Text(ProgressStrings.retroactiveWithheld(
            summary.withheldRetroactiveCredit)),
      if (summary.hasHistoryUnderLock)
        const Text(ProgressStrings.historyUnderLock),
      if (summary.orphanRecordLessonIds.isNotEmpty)
        Text(ProgressStrings.orphanRecords(
            summary.orphanRecordLessonIds.length)),
    ];

    return ListView(
      children: <Widget>[
        _section(
          key: measuredSectionKey,
          title: ProgressStrings.measuredSection,
          subtitle: ProgressStrings.measuredSubtitle,
          children: open.isEmpty
              ? const <Widget>[Text(ProgressStrings.emptyHistory)]
              : open.map(_measuredRow).toList(growable: false),
        ),
        if (locked.isNotEmpty)
          _section(
            key: lockedSectionKey,
            title: ProgressStrings.lockedSection,
            subtitle: ProgressStrings.lockedSubtitle,
            children: locked.map(_lockedRow).toList(growable: false),
          ),
        // ⚠️ BOŞ "Notes" başlığı ÇİZİLMEZ. İlk hâlinde çiziliyordu ve
        // simülatörde ekranın altında sahipsiz bir "Notes" kelimesi duruyordu:
        // başlık bir SÖZ verir, altı boşsa söz tutulmaz. Choreia'nın "boş bölüm
        // bir CÜMLEDİR" kaydının tersten hâli — orada boşluğun İÇİNE gerekçe
        // konmuştu, burada söylenecek bir şey YOK, o yüzden bölüm de yok.
        if (notes.isNotEmpty)
          _section(
            key: notesSectionKey,
            title: ProgressStrings.notesSection,
            children: notes,
          ),
      ],
    );
  }

  Widget _measuredRow(LessonProgress l) {
    return Column(
      key: Key('progress.measured.${l.lessonId}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Kullanıcıya AD gösterilir, kimlik gösterilmez. `lessonId` yalnız
        // [Key]'de: test hangi satıra baktığını bilsin diye.
        Text(l.displayName),
        if (l.state == LessonProgressState.notStarted)
          // "Hiç yapmadın" bir VERİdir; satırı silmek onu saklamak olurdu.
          const Text(ProgressStrings.notStarted)
        else ...<Widget>[
          // Birim satırdan gelir, çıplak sayı YOK.
          Text(ProgressStrings.units(l.unitsMeasured, l.unitLabel)),
          Text(ProgressStrings.worked(l.workedSeconds)),
          Text(ProgressStrings.sessions(l.sessionCount)),
          if (l.unitsUnmeasured > 0)
            Text(ProgressStrings.unmeasured(
                l.unitsUnmeasured, l.unitLabel, l.unmeasuredReasons)),
          if (l.measurementOnlySessions > 0)
            Text(ProgressStrings.measurementOnly(l.measurementOnlySessions)),
        ],
      ],
    );
  }

  Widget _lockedRow(LessonProgress l) {
    return Column(
      key: Key('progress.locked.${l.lessonId}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l.displayName),
        // Gerekçe İÇERİKTEN aynen gelir — kabuk kendi cümlesini kurmaz.
        Text(l.lockedReason ?? ''),
        // Kilitli ders ÇALIŞILMIŞSA sayıları da görünür: kilit ölçümü kapatır,
        // geçmişi silmez.
        if (l.sessionCount > 0) ...<Widget>[
          Text(ProgressStrings.units(l.unitsMeasured, l.unitLabel)),
          Text(ProgressStrings.sessions(l.sessionCount)),
        ],
      ],
    );
  }

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
        Text(title),
        if (subtitle != null) Text(subtitle),
        ...children,
      ],
    );
  }
}
