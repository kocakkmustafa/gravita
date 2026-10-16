import 'package:flutter/material.dart';
import 'package:gravita_engine/gravita_engine.dart';
import 'app_locale.dart';
import 'catalog_copy_tr.dart';
import 'camera_release_policy.dart';

import 'content_repository.dart';
import 'calisthenics_course.dart';
import 'calisthenics_course_screen.dart';
import 'library_model.dart';
import 'library_strings.dart';
import 'skills/skill_tree_screen.dart';
import 'surface_widgets.dart';
import 'theme.dart';

typedef StartMovementSession = void Function(MovementConfig config);

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
/// | Canlı seans girişi | `status: live` + türetilmiş kimlik ön koşulu |
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
    this.accountUserId,
    this.onStartSession,
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
  static const Key startSessionKey = Key('movement.startSession');
  static const Key learningGuideKey = Key('movement.learningGuide');

  final MovementEntry movement;
  final String? accountUserId;
  final ContentRepository content;
  final StartMovementSession? onStartSession;

  @override
  State<MovementPage> createState() => _MovementPageState();
}

class _MovementPageState extends State<MovementPage> {
  late final Future<MovementConfig> _config = widget.content.catalogFor(
    widget.movement.id,
  );

  /// Geçmiş YALNIZ **canlı** harekette okunur.
  ///
  /// ⚠️ Koşul `lessonCount == 0` İDİ ve G-132'den sonra YANLIŞ oldu: serbest
  /// seans DERSE değil HAREKETE yazılıyor, yani dersi olmayan bir hareketin
  /// de geçmişi olabilir. Ama girilebilir olmayan bir harekette seans
  /// başlatılamaz, o yüzden doğru koşul CANLI olmak.
  late final Future<_Trend>? _trend = widget.movement.isLive
      ? _loadTrend()
      : null;

  Future<_Trend> _loadTrend() async {
    try {
      // İKİ KOVA, AYRI dosyalar (G-132): ders seansları + serbest seanslar.
      // Burada birleştirmek MEŞRU çünkü soru HAREKET düzeyinde ("bu hareketle
      // geçmişin"). Yasak olan, farklı `focus`lu DERSLERİ tek trendde
      // toplamaktı; bu sayfa ders trendi çizmiyor.
      final SessionStore lessons = await ContentRepository.openSessionStore(
        accountUserId: widget.accountUserId,
      );
      final SessionStore free = await ContentRepository.openFreeSessionStore(
        accountUserId: widget.accountUserId,
      );
      final Set<String> mineIds = widget.movement.lessonIds.toSet();
      final String freeKey = ContentRepository.freeSessionKey(
        widget.movement.id,
      );
      final List<SessionRecord> mine = <SessionRecord>[
        ...(await lessons.recent()).where(
          (SessionRecord r) => mineIds.contains(r.lessonId),
        ),
        ...(await free.recent()).where(
          (SessionRecord r) => r.lessonId == freeKey,
        ),
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
    final MovementConfig? startable = widget.content.startableConfigFor(m.id);
    return Scaffold(
      appBar: AppBar(title: Text(catalogName(context, m.id, m.displayName))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 48),
        children: <Widget>[
          _header(m),
          if (startable != null && widget.onStartSession != null) ...<Widget>[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: MovementPage.startSessionKey,
                onPressed: motionPaidCameraLaunchEnabled
                    ? () => widget.onStartSession!(startable)
                    : null,
                icon: const Icon(Icons.videocam_outlined),
                label: Text(
                  localized(
                    context,
                    motionPaidCameraLaunchEnabled
                        ? LibraryStrings.startSession
                        : LibraryStrings.cameraUnavailable,
                    motionPaidCameraLaunchEnabled
                        ? 'Seansı başlat'
                        : 'Kamera kapalı',
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _howTo(m),
          const SizedBox(height: 28),
          // ⭐ Dürüstlük kutusu sayfanın ÜST YARISINDA. Aşağıya atmak onu
          // "küçük yazı" hâline getirirdi; ürünün iddiası tam olarak bu kutu.
          _honestyBox(m),
          if (widget.content.calisthenicsCourse.guideFor(m.id) != null) ...[
            const SizedBox(height: 20),
            _learningGuide(m),
          ],
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
                ? localized(
                    context,
                    LibraryStrings.openBadge,
                    motionPaidCameraLaunchEnabled ? 'AÇIK' : 'KAMERA KAPALI',
                  )
                : localized(context, LibraryStrings.queuedBadge, 'KAPALI'),
            tone: m.isLive ? GravitaColors.accent : GravitaColors.textSecondary,
            filled: m.isLive,
          ),
          if (m.classBadge != null)
            GravitaPill(
              label: movementClassBadge(context, m.classBadge!),
              tone: GravitaColors.textSecondary,
              filled: false,
            ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        movementMetaLine(context, m),
        style: GravitaType.mono(size: 11, color: GravitaColors.textSecondary),
      ),
      const SizedBox(height: 12),
      Text(
        movementBlurb(context, m),
        style: GravitaType.body(
          size: 14.5,
          color: GravitaColors.inkMuted,
          height: 1.6,
        ),
      ),
      // ⚠️ Sınıf bilinmiyorsa SATIR HİÇ ÇİZİLMEZ — boş bir cümle
      // yerine hiçbir cümle. Eksik veri bir iddiaya dönüşmesin (O-070).
      if (m.movementClass != null) ...<Widget>[
        const SizedBox(height: 12),
        Text(
          movementClassExplanation(context, m.movementClass),
          style: GravitaType.body(
            size: 12.5,
            color: GravitaColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    ],
  );

  // ── 2. Nasıl yapılır — referans YOK, sahte avatar da YOK ────────────────

  /// Bugün HER hareket için bu hâl çiziliyor: hiçbirinin ekranda çizilebilir
  /// bir referans dizisi yok (`provenance.referenceId` üretimi hasat işi).
  /// Kod bu gerçeği KOŞULLU yazıyor — referans geldiği gün burası bir demo
  /// bloku hâline gelir ve bu metin kendiliğinden düşer.
  Widget _howTo(MovementEntry m) => SurfaceSection(
    key: MovementPage.howToKey,
    title: localized(
      context,
      LibraryStrings.howToTitle.toUpperCase(),
      'NASIL YAPILIR',
    ),
    children: <Widget>[
      NoteCard(
        icon: Icons.videocam_off_outlined,
        // ⚠️ KOŞULLU — ve bu bir DÜZELTMENİN ürünü. Cümle koşulsuzdu:
        // `push_up`ta üstte *"hiç kayıtlı eğitmen referansımız yok"*
        // yazarken, iki blok altındaki dürüstlük kutusu *"5 eğitmen,
        // 36 çekim ATTESTED"* diyordu. Aynı sayfanın iki bloğu
        // birbiriyle çelişiyordu.
        text: m.referenceSources == 0
            ? localized(
                context,
                LibraryStrings.howToNoReference,
                'Bu hareket için kayıtlı eğitmen referansımız yok; bu yüzden gösterilecek bir uygulama örneği de yok. Uydurma bir figür göstermek istemiyoruz.',
              )
            : localized(
                context,
                LibraryStrings.howToReferenceNotDrawable(m.referenceSources),
                'Bu hareket için ${m.referenceSources} eğitmenden görüntü var. Ancak bunlardan izlenebilir bir gösterim hazırlanmadı; türetilen şey ölçüm, oynatılabilir bir hareket dizisi değil.',
              ),
      ),
    ],
  );

  // ── 3. ⭐ Dürüstlük kutusu — ÜRETİLMİŞ, esnek yükseklik ─────────────────

  Widget _learningGuide(MovementEntry movement) {
    final course = widget.content.calisthenicsCourse;
    final guide = course.guideFor(movement.id)!;
    final (en, tr) = switch (guide.kind) {
      MovementGuideKind.practice => (
        'Related practice · self-report',
        'İlgili pratik · öz bildirim',
      ),
      MovementGuideKind.preparation => (
        'Preparation variants · self-report',
        'Hazırlık varyasyonları · öz bildirim',
      ),
      MovementGuideKind.readingOnly => (
        'Reading pathway · no physical task',
        'Bilgi yolu · fiziksel görev yok',
      ),
    };
    return SurfaceSection(
      key: MovementPage.learningGuideKey,
      title: localized(context, en, tr),
      children: [
        Text(
          localized(
            context,
            'Read the prerequisites and adaptations first. Learning records do not validate technique or open camera coaching.',
            'Önce önkoşulları ve uyarlamaları oku. Öğrenme kaydı teknik doğrulamaz veya kamera koçluğunu açmaz.',
          ),
          style: GravitaType.body(size: 13, color: GravitaColors.textSecondary),
        ),
        for (final id in guide.lessonIds)
          TextButton.icon(
            key: Key('movement.guide.$id'),
            icon: const Icon(Icons.menu_book_outlined),
            label: Text(
              course.lessons
                  .singleWhere((l) => l.id == id)
                  .title
                  .inLanguage(Localizations.localeOf(context).languageCode),
            ),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => CalisthenicsLessonScreen(
                  course: course,
                  lesson: course.lessons.singleWhere((l) => l.id == id),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Catalogue contracts remain intact. A closed release must not present
  /// their historical counting/comparison copy as a service the user receives.
  String _honestyCopy(MovementEntry m, String source) {
    if (!motionPaidCameraLaunchEnabled && m.isLive) {
      if (m.honesty.measured.contains(source)) {
        return localized(
          context,
          LibraryStrings.cameraClosedCountBody,
          'Tekrar sayımı ölçüm kataloğunda yer alır. Bu sürüm '
          'tekrarlarını saymaz veya zamanlamaz.',
        );
      }
      if (source == m.honesty.scoring) {
        return localized(
          context,
          LibraryStrings.cameraClosedScoreBody,
          'Bu sürüm formunu ölçmez veya puanlamaz. Kurs ve öğrenme rehberi '
          'ilerlemesi yalnız kendi pratik bildirimini kaydeder.',
        );
      }
      if (source.startsWith('How your form compares to instructors.')) {
        return localized(
          context,
          LibraryStrings.cameraClosedComparisonBody,
          'Bu sürüm hareketini eğitmenlerle karşılaştırmaz veya form puanı sunmaz.',
        );
      }
    }
    return m.isLive
        ? liveHonestyCopy(context, m.id, source)
        : catalogEvidenceCopy(context, source);
  }

  Widget _honestyBox(MovementEntry m) => SurfaceSection(
    key: MovementPage.honestyKey,
    title: localized(
      context,
      LibraryStrings.honestyTitle.toUpperCase(),
      motionPaidCameraLaunchEnabled
          ? 'NEYİ ÖLÇÜYORUZ, NEYİ ÖLÇMÜYORUZ'
          : 'ÖLÇÜM KATALOĞU VE SINIRLAR',
    ),
    children: <Widget>[
      GravitaCard(
        sealed: true,
        radius: 24,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _honestyHeading(
              localized(
                context,
                LibraryStrings.honestyMeasuredLabel,
                motionPaidCameraLaunchEnabled ? 'Ölçülen' : 'Katalog ölçümleri',
              ),
            ),
            const SizedBox(height: 10),
            if (m.honesty.measuresNothing)
              // BASKIN hâl (31'in 30'u). Onurlu bir cümle — boş kutu,
              // gri "—" ya da hata rengi DEĞİL.
              Text(
                localized(
                  context,
                  LibraryStrings.honestyMeasuresNothing,
                  'Hiçbir şey. Bu hareket için eksik olan ölçümler ve nedenleri aşağıda listelenir.',
                ),
                style: GravitaType.body(
                  size: 13.5,
                  color: GravitaColors.honestyText,
                  height: 1.55,
                ),
              )
            else
              ReasonList(
                items: m.honesty.measured
                    .map((source) => _honestyCopy(m, source))
                    .toList(growable: false),
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
                  _honestyCopy(m, m.honesty.scoring!),
                  key: MovementPage.scoringKey,
                  style: GravitaType.body(
                    size: 12.5,
                    color: GravitaColors.honestyText,
                    height: 1.55,
                  ),
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
              _honestyHeading(
                localized(
                  context,
                  LibraryStrings.honestyWaitingLabel,
                  'Ölçüm eksik',
                ),
              ),
              const SizedBox(height: 10),
              ReasonList(
                items: m.honesty.waitingOnMeasurement
                    .map((source) => waitingMeasurementCopy(context, m, source))
                    .toList(growable: false),
                color: GravitaColors.honestyText,
                bulletColor: GravitaColors.honestySeal,
              ),
            ],
            if (m.honesty.notMeasured.isNotEmpty) ...<Widget>[
              const SizedBox(height: 20),
              _honestyHeading(
                localized(
                  context,
                  LibraryStrings.honestyNotMeasuredLabel,
                  'Tek kamera bunu göremez',
                ),
              ),
              const SizedBox(height: 10),
              ReasonList(
                items: m.honesty.notMeasured
                    .map((source) => _honestyCopy(m, source))
                    .toList(growable: false),
                color: GravitaColors.honestyText,
                bulletColor: GravitaColors.honestySeal,
              ),
            ],
          ],
        ),
      ),
    ],
  );

  /// ✅ F2 (D1, 2026-08-16) — KÖK ÇÖZÜLDÜ: aşağıdaki kısıt artık geçmiş.
  /// Fontlar `pubspec.yaml`de PAKETLİ (OFL, `assets/fonts/`); `flutter_test`
  /// artık hiçbir ağırlık için ağ istemiyor, makine önbelleğine bağımlı
  /// değil. Bu ağırlığı (`w600`) DEĞİŞTİRMEDİM — teknik kısıt kalktı ama
  /// hangi ağırlığın kullanılacağı bir TASARIM kararı, bu turun kapsamı
  /// değil.
  ///
  /// **Tarihsel not (artık geçerli değil, silinmedi):** ağırlık w700 değil
  /// w600'dü çünkü `google_fonts` fontu çalışma zamanında indiriyordu;
  /// `flutter_test` altında indirme yoktu ve paket, daha önce hiç
  /// kullanılmamış bir ağırlık istendiğinde teste asenkron istisna
  /// fırlatıyordu. Kabuğun o zamana dek kullandığı ağırlıklar (w400-w600)
  /// bu makinenin google_fonts önbelleğinde duruyordu; w700 durmuyordu ve
  /// tuzak tam orada ateşlenmişti.
  Widget _honestyHeading(String label) => Text(
    label.toUpperCase(),
    style: GravitaType.mono(
      size: 10.5,
      color: GravitaColors.honestySeal,
      weight: FontWeight.w600,
      letterSpacingEm: 0.14,
    ),
  );

  // ── 4. Ölçüm kuyruğu — her madde kendi gerekçesini taşır ────────────────

  Widget _queue(MovementEntry m) => SurfaceSection(
    key: MovementPage.queueKey,
    title: localized(
      context,
      LibraryStrings.queueTitle.toUpperCase(),
      'EKSİK OLANLAR',
    ),
    children: <Widget>[
      GravitaCard(
        child: ReasonList(items: m.comingSoon, color: GravitaColors.inkMuted),
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
        title: localized(
          context,
          LibraryStrings.formErrorsTitle.toUpperCase(),
          'KURALLAR NEYİ İZLER',
        ),
        // ⚠️ Cümle harekete göre değişir: kural SAYISI verilerden gelir ve
        // "koşmuyor" beyanı hareketin CANLI olup olmamasına bağlı.
        // Kuralların varlığını "çalışıyor" gibi sunmak, bu ürünün en
        // kolay düşeceği yalan olurdu.
        subtitle: m.isLive
            ? localized(
                context,
                LibraryStrings.formErrorsBodyLive(c.formErrors.length),
                motionPaidCameraLaunchEnabled
                    ? '${c.formErrors.length} kural kayıtlı görüntülerde ve canlı çalışmada değerlendirilir; sonuçlar set sırasında gösterilmez.'
                    : '${c.formErrors.length} kural kayıtlı görüntü tekrarları için yapılandırılmıştır. '
                          'Canlı kamera seansları bu sürümde kullanılamıyor; kamera geri bildirimi veya form puanı sunulmaz.',
              )
            : localized(
                context,
                LibraryStrings.formErrorsBody(c.formErrors.length),
                '${c.formErrors.length} kural yazılıdır; şu anda çalışmaz.',
              ),
        children: c.formErrors
            .map(
              (FormError e) => GravitaCard(
                radius: 18,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      e.label,
                      style: GravitaType.display(
                        size: 14.5,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Kullanıcıya İPUCU gösterilir; eşik değeri, metrik
                    // adı ve `sustainedMs` GÖSTERİLMEZ — onlar ölçüm
                    // tarafının dili (ham detay yüzeye sızmaz).
                    Text(
                      e.cue,
                      style: GravitaType.body(
                        size: 13,
                        color: GravitaColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      );
    },
  );

  // ── 6. Kurslar ─────────────────────────────────────────────────────────

  Widget _courses(MovementEntry m) => SurfaceSection(
    key: MovementPage.coursesKey,
    title: localized(
      context,
      LibraryStrings.coursesTitle.toUpperCase(),
      'KAMERA DERSİ KATALOĞU',
    ),
    children: <Widget>[
      if (m.courseCount == 0)
        NoteCard(
          icon: Icons.school_outlined,
          text: localized(
            context,
            LibraryStrings.coursesNone,
            'Bu hareket için kamera dersi yapılandırılmadı. Yukarıda listelenen ilgili öğrenme rehberleri yalnız kendi pratik beyanını kaydeder.',
          ),
        )
      else
        GravitaCard(
          child: Text(
            localized(
              context,
              LibraryStrings.coursesCount(m.courseCount, m.lessonCount),
              '${m.courseCount} kurs · ${m.lessonCount} ders',
            ),
            style: GravitaType.mono(size: 12, color: GravitaColors.ink),
          ),
        ),
    ],
  );

  // ── 7. Kişisel trend ───────────────────────────────────────────────────

  Widget _trendBlock() {
    final Future<_Trend>? future = _trend;
    if (future == null) {
      return SurfaceSection(
        key: MovementPage.trendKey,
        title: localized(
          context,
          'YOUR HISTORY WITH THIS MOVEMENT',
          'BU HAREKETTE GEÇMİŞİN',
        ),
        children: <Widget>[
          NoteCard(
            icon: Icons.show_chart,
            text: localized(
              context,
              LibraryStrings.trendNoLesson,
              'Bu hareket için kamera ölçüm geçmişi kullanılamıyor. Öz bildirimli kurs ilerlemesi kursta ayrı tutulur.',
            ),
          ),
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
          title: localized(
            context,
            LibraryStrings.trendTitle.toUpperCase(),
            'BU HAREKETTE GEÇMİŞİN',
          ),
          children: <Widget>[
            if (!t.readable)
              NoteCard(
                sealed: true,
                icon: Icons.history_toggle_off,
                text: localized(
                  context,
                  LibraryStrings.trendUnreadable,
                  'Bu cihazdaki çalışma geçmişi okunamadı; ne kadar çalıştığını bilmiyoruz. Burada bir sayı uydurmayacağız.',
                ),
              )
            else if (t.records.isEmpty)
              NoteCard(
                icon: Icons.show_chart,
                text: localized(
                  context,
                  LibraryStrings.trendNoSessions,
                  'Bu hareket için kayıtlı oturum yok.',
                ),
              )
            else
              GravitaCard(
                child: Text(
                  movementTrendSummary(
                    context,
                    t.records.length,
                    t.records.fold<int>(
                      0,
                      (int n, SessionRecord r) => n + r.unitsCompleted,
                    ),
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
    title: localized(
      context,
      LibraryStrings.safetyTitle.toUpperCase(),
      'BAŞLAMADAN ÖNCE',
    ),
    children: <Widget>[
      GravitaCard(
        sealed: true,
        child: ReasonList(
          items: m.safetyWarnings
              .map((warning) => safetyWarning(context, warning))
              .toList(growable: false),
          color: GravitaColors.honestyText,
          bulletColor: GravitaColors.honestySeal,
        ),
      ),
    ],
  );

  // ── 9. Beceri ağacı bağı ───────────────────────────────────────────────

  /// ⭐ GRA-P1-001: bu blok artık NAVİGE EDİLEBİLİR — ağaç BULUNDUĞUNDA
  /// [SkillTreeScreen]e gider (`lib/app/skills/`). Ağaç bulunamazsa
  /// (`skillTreeUnknown` hâli) dokunma hedefi YOK — var olmayan bir yere
  /// giden bir buton, ölü buton yasağının ta kendisi olurdu.
  Widget _skillTree(MovementEntry m) {
    final SkillTree? tree = widget.content.catalogue.skillTrees.treeFor(
      m.skillGraphNode!,
    );
    final Widget card = NoteCard(
      icon: Icons.account_tree_outlined,
      text: switch (tree) {
        final SkillTree t => localized(
          context,
          LibraryStrings.skillTreeIn(t.displayName),
          'Bu hareket, taslak ${skillTreeName(context, t)} gelişim yolunun bir adımı. '
          'Açılma ölçütleri hareket bilimi incelemesinden geçmediği '
          'için bu yolu çizim olarak göstermiyoruz.',
        ),
        null => localized(
          context,
          LibraryStrings.skillTreeUnknown,
          'Bu hareket bir gelişim yolunun parçası olarak işaretli, ancak '
          'hangi yol olduğunu bulamadık. Tahminde bulunmuyoruz.',
        ),
      },
    );
    return SurfaceSection(
      key: MovementPage.skillTreeKey,
      title: localized(
        context,
        LibraryStrings.skillTreeLinkTitle.toUpperCase(),
        'BİR GELİŞİM YOLUNUN PARÇASI',
      ),
      children: <Widget>[
        if (tree == null)
          card
        else
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => SkillTreeScreen(tree: tree),
              ),
            ),
            child: card,
          ),
      ],
    );
  }
}

/// Bir hareketin geçmişi — "boş" ile "okunamadı" AYRI taşınır.
final class _Trend {
  const _Trend({required this.records, required this.readable});
  final List<SessionRecord> records;
  final bool readable;
}
