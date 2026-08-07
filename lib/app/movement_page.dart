import 'package:flutter/material.dart';
import 'package:gravita_engine/gravita_engine.dart';

import 'content_repository.dart';
import 'library_model.dart';
import 'library_strings.dart';
import 'surface_widgets.dart';
import 'theme.dart';

/// Hareket sayfası — W0 §2'nin DOKUZ zorunlu bloku.
///
/// Her blok bir VERİ KAYNAĞINA bağlı; elle yazılmış serbest metin YOK:
///
/// | Blok | Kaynak |
/// |---|---|
/// | Başlık + aile + seviye + ekipman | `library.json` (katalogdan üretilmiş) |
/// | Nasıl yapılır | referans dizisi — **bugün YOK, sahte avatar da yok** |
/// | Form hataları | `MovementConfig.formErrors` (katalog, tembel yüklenir) |
/// | ⭐ Dürüstlük kutusu | `honesty` — `measurementContract`ten ÜRETİLMİŞ |
/// | Sınıf rozeti | `classBadge` (`movement-classes.json.userCopy.badge`) |
/// | Kurslar | `courses[]` |
/// | Kişisel trend | yerel seans kayıtları |
/// | Güvenlik uyarısı | `safety.warnings` — KIRPILAMAZ |
/// | Beceri ağacı bağı | `skillGraphNode` |
///
/// ## Bu sayfanın en zor kısıtı: "referans YOK" BASKIN hâldir
///
/// 31 hareketin 30'unun eğitmen referansı YOK. Yani "nasıl yapılır" bloku
/// bugün ÇOĞUNLUKLA boştur. Bir hata/eksik gibi çizilirse ürün kırık görünür;
/// sahte bir iskelet-avatarla doldurulursa ürün YALAN söyler. Üçüncü yol:
/// boşluğu TASARLANMIŞ bir hâl olarak çizmek ve sebebini söylemek.
///
/// ## Dürüstlük kutusu neden sabit yükseklikte DEĞİL
///
/// İçeriği harekete göre 3 maddeden 10 maddeye, 40 karakterden 400 karaktere
/// değişiyor (`push_up`'ın "which side is doing more work" maddesi tek başına
/// bir paragraf). Sabit yükseklik onu kırpardı; kırpılmış bir dürüstlük
/// beyanı, olmayan bir beyandır. Ayrıca sayfanın ORTASINDA, kurslardan ÖNCE
/// duruyor — dipnot değil.
class MovementPage extends StatefulWidget {
  const MovementPage({
    required this.movement,
    required this.content,
    super.key,
  });

  static const Key honestyKey = Key('movement.honesty');
  static const Key scoringKey = Key('movement.scoring');
  static const Key howToKey = Key('movement.howTo');
  static const Key formErrorsKey = Key('movement.formErrors');
  static const Key safetyKey = Key('movement.safety');
  static const Key coursesKey = Key('movement.courses');
  static const Key trendKey = Key('movement.trend');
  static const Key queueKey = Key('movement.queue');
  static const Key skillTreeKey = Key('movement.skillTree');

  final MovementEntry movement;
  final ContentRepository content;

  @override
  State<MovementPage> createState() => _MovementPageState();
}

class _MovementPageState extends State<MovementPage> {
  late final Future<MovementConfig> _config =
      widget.content.catalogFor(widget.movement.id);

  /// Geçmiş YALNIZ **canlı** harekette okunur.
  ///
  /// ⚠️ Koşul `lessonCount == 0` İDİ ve G-132'den sonra YANLIŞ oldu: serbest
  /// seans DERSE değil HAREKETE yazılıyor, yani dersi olmayan bir hareketin
  /// de geçmişi olabilir. Ama girilebilir olmayan bir harekette seans
  /// başlatılamaz, o yüzden doğru koşul CANLI olmak.
  late final Future<_Trend>? _trend =
      widget.movement.isLive ? _loadTrend() : null;

  Future<_Trend> _loadTrend() async {
    try {
      // İKİ KOVA, AYRI dosyalar (G-132): ders seansları + serbest seanslar.
      // Burada birleştirmek MEŞRU çünkü soru HAREKET düzeyinde ("bu hareketle
      // geçmişin"). Yasak olan, farklı `focus`lu DERSLERİ tek trendde
      // toplamaktı; bu sayfa ders trendi çizmiyor.
      final SessionStore lessons = await ContentRepository.openSessionStore();
      final SessionStore free = await ContentRepository.openFreeSessionStore();
      final Set<String> mineIds = widget.movement.lessonIds.toSet();
      final String freeKey =
          ContentRepository.freeSessionKey(widget.movement.id);
      final List<SessionRecord> mine = <SessionRecord>[
        ...(await lessons.recent())
            .where((SessionRecord r) => mineIds.contains(r.lessonId)),
        ...(await free.recent())
            .where((SessionRecord r) => r.lessonId == freeKey),
      ];
      return _Trend(records: mine, readable: true);
    } on Object {
      // Okunamadı ≠ boş. Bu ayrımın kaybolması, bu üründe defalarca
      // adlandırılmış bir hata sınıfı.
      return const _Trend(records: <SessionRecord>[], readable: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MovementEntry m = widget.movement;
    return Scaffold(
      appBar: AppBar(title: Text(m.displayName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 48),
        children: <Widget>[
          _header(m),
          const SizedBox(height: 24),
          _howTo(m),
          const SizedBox(height: 28),
          // ⭐ Dürüstlük kutusu sayfanın ÜST YARISINDA. Aşağıya atmak onu
          // "küçük yazı" hâline getirirdi; ürünün iddiası tam olarak bu kutu.
          _honestyBox(m),
          const SizedBox(height: 28),
          if (m.comingSoon.isNotEmpty) ...<Widget>[
            _queue(m),
            const SizedBox(height: 28),
          ],
          _formErrors(m),
          const SizedBox(height: 28),
          _courses(m),
          const SizedBox(height: 28),
          _trendBlock(),
          if (m.safetyWarnings.isNotEmpty) ...<Widget>[
            const SizedBox(height: 28),
            _safety(m),
          ],
          if (m.skillGraphNode != null) ...<Widget>[
            const SizedBox(height: 28),
            _skillTree(m),
          ],
        ],
      ),
    );
  }

  // ── 1. Başlık + aile + seviye + ekipman + sınıf rozeti ──────────────────

  Widget _header(MovementEntry m) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              GravitaPill(
                label: m.isLive
                    ? LibraryStrings.openBadge
                    : LibraryStrings.queuedBadge,
                tone: m.isLive
                    ? GravitaColors.accent
                    : GravitaColors.textSecondary,
                filled: m.isLive,
              ),
              if (m.classBadge != null)
                GravitaPill(
                  label: m.classBadge!.toUpperCase(),
                  tone: GravitaColors.textSecondary,
                  filled: false,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(LibraryStrings.metaLine(m),
              style: GravitaType.mono(
                  size: 11, color: GravitaColors.textSecondary)),
          const SizedBox(height: 12),
          Text(m.blurb,
              style: GravitaType.body(
                  size: 14.5, color: GravitaColors.inkMuted, height: 1.6)),
          const SizedBox(height: 12),
          Text(LibraryStrings.classBadgeExplainer(m.movementClass),
              style: GravitaType.body(
                  size: 12.5,
                  color: GravitaColors.textSecondary,
                  height: 1.5)),
        ],
      );

  // ── 2. Nasıl yapılır — referans YOK, sahte avatar da YOK ────────────────

  /// Bugün HER hareket için bu hâl çiziliyor: hiçbirinin ekranda çizilebilir
  /// bir referans dizisi yok (`provenance.referenceId` üretimi hasat işi).
  /// Kod bu gerçeği KOŞULLU yazıyor — referans geldiği gün burası bir demo
  /// bloku hâline gelir ve bu metin kendiliğinden düşer.
  Widget _howTo(MovementEntry m) => SurfaceSection(
        key: MovementPage.howToKey,
        title: LibraryStrings.howToTitle.toUpperCase(),
        children: <Widget>[
          NoteCard(
            icon: Icons.videocam_off_outlined,
            // ⚠️ KOŞULLU — ve bu bir DÜZELTMENİN ürünü. Cümle koşulsuzdu:
            // `push_up`ta üstte *"hiç kayıtlı eğitmen referansımız yok"*
            // yazarken, iki blok altındaki dürüstlük kutusu *"5 eğitmen,
            // 36 çekim ATTESTED"* diyordu. Aynı sayfanın iki bloğu
            // birbiriyle çelişiyordu.
            text: m.referenceSources == 0
                ? LibraryStrings.howToNoReference
                : LibraryStrings.howToReferenceNotDrawable(m.referenceSources),
          ),
        ],
      );

  // ── 3. ⭐ Dürüstlük kutusu — ÜRETİLMİŞ, esnek yükseklik ─────────────────

  Widget _honestyBox(MovementEntry m) => SurfaceSection(
        key: MovementPage.honestyKey,
        title: LibraryStrings.honestyTitle.toUpperCase(),
        children: <Widget>[
          GravitaCard(
            sealed: true,
            radius: 24,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _honestyHeading(LibraryStrings.honestyMeasuredLabel),
                const SizedBox(height: 10),
                if (m.honesty.measuresNothing)
                  // BASKIN hâl (31'in 30'u). Onurlu bir cümle — boş kutu,
                  // gri "—" ya da hata rengi DEĞİL.
                  Text(LibraryStrings.honestyMeasuresNothing,
                      style: GravitaType.body(
                          size: 13.5,
                          color: GravitaColors.honestyText,
                          height: 1.55))
                else
                  ReasonList(
                    items: m.honesty.measured,
                    color: GravitaColors.honestyText,
                    bulletColor: GravitaColors.honestySeal,
                  ),
                // ⭐ Ayrım, `measured` listesinin HEMEN ALTINDA duruyor —
                // "not measured" başlığından ÖNCE. Aşağı atmak onu ikinci
                // sınıf bir dipnot yapardı, oysa okuyucunun `measured`ı
                // yanlış okuduğu an tam burası.
                if (m.honesty.scoring != null) ...<Widget>[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      // ⚠️ 0.07 DEĞİL 0.05 — ölçümle ayarlandı (WCAG nöbeti,
                      // J-114 aktarımı). 0.07'de zemin `#EED9D9` oluyor ve
                      // `textSecondary` orada **4.35:1**'e düşüyordu: eşik
                      // altı. Bugün bu kutuda yalnız `honestyText` (7.42)
                      // çiziliyor, yani kusur BUGÜN ısırmıyordu — ama zemin
                      // herhangi bir ikincil tonu eşik altına düşürüyorsa,
                      // o zemin bir TUZAKTIR ve ilk yeniden düzenlemede
                      // ısırır. Zemin düzeltildi, ton değil.
                      color: GravitaColors.honestySeal.withValues(alpha: 0.05),
                    ),
                    child: Text(
                      m.honesty.scoring!,
                      key: MovementPage.scoringKey,
                      style: GravitaType.body(
                          size: 12.5,
                          color: GravitaColors.honestyText,
                          height: 1.55),
                    ),
                  ),
                ],
                // ⭐ İKİ AYRI KUYRUK, İKİ AYRI BAŞLIK. Tek listede
                // toplandıklarında kullanıcı *"henüz ölçmedik"* ile *"tek
                // kamera bunu göremez"* arasındaki farkı göremiyordu — biri
                // bir gün kapanır, öteki asla, ve ürünü doğru anlamak tam
                // olarak bu farka bağlı.
                if (m.honesty.waitingOnMeasurement.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  _honestyHeading(LibraryStrings.honestyWaitingLabel),
                  const SizedBox(height: 10),
                  ReasonList(
                    items: m.honesty.waitingOnMeasurement,
                    color: GravitaColors.honestyText,
                    bulletColor: GravitaColors.honestySeal,
                  ),
                ],
                if (m.honesty.notMeasured.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  _honestyHeading(LibraryStrings.honestyNotMeasuredLabel),
                  const SizedBox(height: 10),
                  ReasonList(
                    items: m.honesty.notMeasured,
                    color: GravitaColors.honestyText,
                    bulletColor: GravitaColors.honestySeal,
                  ),
                ],
              ],
            ),
          ),
        ],
      );

  /// ⚠️ Ağırlık w700 DEĞİL w600 — ve bu bir tasarım tercihi değil, ÖLÇÜLMÜŞ
  /// bir kısıt. `google_fonts` uygulamada fontu çalışma zamanında indiriyor;
  /// `flutter_test` altında indirme yoktur ve paket, **daha önce hiç
  /// kullanılmamış** bir ağırlık istendiğinde teste asenkron istisna
  /// fırlatıyor. Kabuğun bugüne dek kullandığı ağırlıklar (w400-w600) bu
  /// makinenin google_fonts önbelleğinde duruyordu; w700 durmuyordu ve tuzak
  /// tam orada ateşlendi.
  ///
  /// 🔴 Bu düzeltme SEMPTOMU alıyor, KÖKÜ değil: fontlar hâlâ paketlenmiyor,
  /// yani test paketi bu makinenin önbelleğine BAĞIMLI ve temiz bir makinede
  /// (CI) mevcut testler de düşer. Kök çözüm fontları asset olarak paketlemek
  /// — paketleme + lisans (OFL) kararı, koordinatör kuyruğunda.
  Widget _honestyHeading(String label) => Text(
        label.toUpperCase(),
        style: GravitaType.mono(
            size: 10.5,
            color: GravitaColors.honestySeal,
            weight: FontWeight.w600,
            letterSpacingEm: 0.14),
      );

  // ── 4. Ölçüm kuyruğu — her madde kendi gerekçesini taşır ────────────────

  Widget _queue(MovementEntry m) => SurfaceSection(
        key: MovementPage.queueKey,
        title: LibraryStrings.queueTitle.toUpperCase(),
        children: <Widget>[
          GravitaCard(
            child: ReasonList(
              items: m.comingSoon,
              color: GravitaColors.inkMuted,
            ),
          ),
        ],
      );

  // ── 5. Form hataları — katalogdan, TEMBEL yüklenir ──────────────────────

  Widget _formErrors(MovementEntry m) => FutureBuilder<MovementConfig>(
        future: _config,
        builder: (BuildContext context, AsyncSnapshot<MovementConfig> snap) {
          final MovementConfig? c = snap.data;
          if (c == null) {
            return const SizedBox(height: 24);
          }
          return SurfaceSection(
            key: MovementPage.formErrorsKey,
            title: LibraryStrings.formErrorsTitle.toUpperCase(),
            // ⚠️ Cümle harekete göre değişir: kural SAYISI verilerden gelir ve
            // "koşmuyor" beyanı hareketin CANLI olup olmamasına bağlı.
            // Kuralların varlığını "çalışıyor" gibi sunmak, bu ürünün en
            // kolay düşeceği yalan olurdu.
            subtitle: m.isLive
                ? LibraryStrings.formErrorsBodyLive(c.formErrors.length)
                : LibraryStrings.formErrorsBody(c.formErrors.length),
            children: c.formErrors
                .map((FormError e) => GravitaCard(
                      radius: 18,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(e.label,
                              style: GravitaType.display(
                                  size: 14.5, weight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          // Kullanıcıya İPUCU gösterilir; eşik değeri, metrik
                          // adı ve `sustainedMs` GÖSTERİLMEZ — onlar ölçüm
                          // tarafının dili (ham detay yüzeye sızmaz).
                          Text(e.cue,
                              style: GravitaType.body(
                                  size: 13,
                                  color: GravitaColors.textSecondary,
                                  height: 1.5)),
                        ],
                      ),
                    ))
                .toList(growable: false),
          );
        },
      );

  // ── 6. Kurslar ─────────────────────────────────────────────────────────

  Widget _courses(MovementEntry m) => SurfaceSection(
        key: MovementPage.coursesKey,
        title: LibraryStrings.coursesTitle.toUpperCase(),
        children: <Widget>[
          if (m.courseCount == 0)
            const NoteCard(
                icon: Icons.school_outlined, text: LibraryStrings.coursesNone)
          else
            GravitaCard(
              child: Text(
                LibraryStrings.coursesCount(m.courseCount, m.lessonCount),
                style: GravitaType.mono(size: 12, color: GravitaColors.ink),
              ),
            ),
        ],
      );

  // ── 7. Kişisel trend ───────────────────────────────────────────────────

  Widget _trendBlock() {
    final Future<_Trend>? future = _trend;
    if (future == null) {
      return const SurfaceSection(
        key: MovementPage.trendKey,
        title: 'YOUR HISTORY WITH THIS MOVEMENT',
        children: <Widget>[
          NoteCard(
              icon: Icons.show_chart, text: LibraryStrings.trendNoLesson),
        ],
      );
    }
    return FutureBuilder<_Trend>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<_Trend> snap) {
        final _Trend? t = snap.data;
        if (t == null) return const SizedBox(height: 24);
        return SurfaceSection(
          key: MovementPage.trendKey,
          title: LibraryStrings.trendTitle.toUpperCase(),
          children: <Widget>[
            if (!t.readable)
              const NoteCard(
                  sealed: true,
                  icon: Icons.history_toggle_off,
                  text: LibraryStrings.trendUnreadable)
            else if (t.records.isEmpty)
              const NoteCard(
                  icon: Icons.show_chart,
                  text: LibraryStrings.trendNoSessions)
            else
              GravitaCard(
                child: Text(
                  LibraryStrings.trendSummary(
                    t.records.length,
                    t.records.fold<int>(
                        0, (int n, SessionRecord r) => n + r.unitsCompleted),
                    t.records.first.unitLabel,
                  ),
                  style: GravitaType.mono(size: 12, color: GravitaColors.ink),
                ),
              ),
          ],
        );
      },
    );
  }

  // ── 8. Güvenlik uyarısı — KIRPILAMAZ ───────────────────────────────────

  /// Uyarı metni katalogdan AYNEN gelir ve kısaltılmaz. Kırpılabilir bir
  /// güvenlik uyarısı, güvenlik uyarısı değildir.
  Widget _safety(MovementEntry m) => SurfaceSection(
        key: MovementPage.safetyKey,
        title: LibraryStrings.safetyTitle.toUpperCase(),
        children: <Widget>[
          GravitaCard(
            sealed: true,
            child: ReasonList(
              items: m.safetyWarnings,
              color: GravitaColors.honestyText,
              bulletColor: GravitaColors.honestySeal,
            ),
          ),
        ],
      );

  // ── 9. Beceri ağacı bağı ───────────────────────────────────────────────

  Widget _skillTree(MovementEntry m) => SurfaceSection(
        key: MovementPage.skillTreeKey,
        title: LibraryStrings.skillTreeLinkTitle.toUpperCase(),
        children: <Widget>[
          NoteCard(
            icon: Icons.account_tree_outlined,
            text: LibraryStrings.skillTreeNode(m.skillGraphNode!),
          ),
        ],
      );
}

/// Bir hareketin geçmişi — "boş" ile "okunamadı" AYRI taşınır.
final class _Trend {
  const _Trend({required this.records, required this.readable});
  final List<SessionRecord> records;
  final bool readable;
}
