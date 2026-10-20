import 'package:flutter/material.dart';
import 'study_review.dart';
import 'account_connection.dart';
import 'camera_release_policy.dart';

import 'app_locale.dart';
import 'catalog_copy_tr.dart';
import 'content_repository.dart';
import 'calisthenics_course_screen.dart';
import 'dbkb_course_entry.dart';
import 'foundation_course_entry.dart';
import 'library_model.dart';
import 'library_strings.dart';
import 'movement_page.dart';
import 'surface_widgets.dart';
import 'theme.dart';
import 'why_not_here_screen.dart';

/// Kütüphane — 31 hareket, 9 aile, ve kapsamın SINIRI.
///
/// ## Bu ekranın tek kritik kısıtı (W0 §4, "dar-app algısı yasağı")
///
/// **Kapsam-dışı arama BOŞ DÖNMEZ.** *"leg press"* yazan kullanıcı sıfır sonuç
/// değil, `exclusions.json`'dan üretilmiş ilgili bölümü görür — makineleri
/// neden koçlamadığımızı okur. Boş sonuç, ürünün DAR olduğu izlenimini
/// bırakır; gerekçeli bir sınır, KASITLI olduğu izlenimini bırakır. İkisi
/// aynı veriyle çizilir, tamamen farklı iki ürün anlatır.
///
/// Bu yüzden arama sonucu `List<MovementEntry>` değil [LibrarySearchResult]:
/// tip düzeyinde "hiç hareket yok" ile "kapsam dışı" ayrı duruyor, ekran
/// ikisini karıştıramıyor.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({required this.content, this.onStartSession, super.key});

  static const Key searchFieldKey = Key('library.search');
  static const Key exclusionResultsKey = Key('library.searchExclusions');
  static const Key movementResultsKey = Key('library.searchMovements');
  static const Key emptyResultKey = Key('library.searchNothing');
  static const Key whyNotLinkKey = Key('library.whyNotLink');
  static const Key skillTreesKey = Key('library.skillTrees');

  final ContentRepository content;
  final StartMovementSession? onStartSession;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  LibraryCatalogue get _catalogue => widget.content.catalogue;

  void _openMovement(MovementEntry m) => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => MovementPage(
        movement: m,
        content: widget.content,
        onStartSession: widget.onStartSession,
        accountUserId: AccountScope.maybeOf(context)?.currentUserId,
      ),
    ),
  );

  void _openWhyNot({String? focusSectionId}) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => WhyNotHereScreen(
            page: _catalogue.exclusions,
            focusSectionId: focusSectionId,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final LibrarySearchResult result = _catalogue.search(
      _query.text,
      additionalMovementTerms: (movement) => <String>[
        catalogName(context, movement.id, movement.displayName),
        familyDisplayName(
          context,
          movement.family,
          LibraryCatalogue.labelFor(movement.family),
        ),
        // Includes the card's actual family/level/equipment wording, including
        // its no-equipment label, rather than a second search translation map.
        movementMetaLine(context, movement),
        for (final equipment in movement.equipment)
          equipmentDisplayName(context, equipment),
      ],
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          localized(context, LibraryStrings.libraryTitle, 'Kütüphane'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 96),
        children: <Widget>[
          StudyReviewEntry(content: widget.content),
          CalisthenicsEntryCard(content: widget.content),
          const SizedBox(height: 10),
          DbkbEntryCard(content: widget.content),
          const SizedBox(height: 10),
          FoundationCourseEntry(content: widget.content),
          const SizedBox(height: 10),
          Text(
            localized(
              context,
              '{guides} movement guides · {reading} reading pathways · self-report',
              '{guides} hareket rehberi · {reading} bilgi yolu · öz bildirim',
              values: <String, Object>{
                'guides':
                    widget.content.foundationCoverage.practiceGuideIds.length,
                'reading':
                    widget.content.foundationCoverage.readingGuideIds.length,
              },
            ),
            key: const Key('library.learningCoverage'),
            style: GravitaType.body(
              context: context,
              size: 12,
              color: GravitaColors.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            localized(
              context,
              motionPaidCameraLaunchEnabled
                  ? '{total} movements · {live} open · {pending} waiting on a measurement'
                  : '{total} movements · {live} configured measurements · {pending} pending measurement evidence',
              motionPaidCameraLaunchEnabled
                  ? '{total} hareket · '
                        '{live} açık · '
                        '{pending} '
                        'ölçüm bekliyor'
                  : '{total} hareket · '
                        '{live} yapılandırılmış ölçüm · '
                        '{pending} ölçüm kanıtı bekliyor',
              values: <String, Object>{
                'total': _catalogue.movements.length,
                'live': _catalogue.liveCount,
                'pending': _catalogue.movements.length - _catalogue.liveCount,
              },
            ),
            style: GravitaType.mono(
              context: context,
              size: 11,
              color: GravitaColors.of(context).textSecondary,
            ),
          ),
          if (!motionPaidCameraLaunchEnabled) ...[
            const SizedBox(height: 10),
            Text(
              localized(
                context,
                LibraryStrings.cameraUnavailableBody,
                'Canlı kamera seansları bu sürümde kullanılamıyor. '
                'Öğrenme rehberleri yalnız kendi pratik bildirimini kaydeder.',
              ),
              key: const Key('library.cameraUnavailable'),
              style: GravitaType.body(
                context: context,
                size: 12,
                color: GravitaColors.of(context).textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _searchField(),
          const SizedBox(height: 22),
          if (result.hasQuery) ..._searchResults(result) else ..._browse(),
        ],
      ),
    );
  }

  Widget _searchField() => TextField(
    key: LibraryScreen.searchFieldKey,
    controller: _query,
    onChanged: (_) => setState(() {}),
    style: GravitaType.body(context: context, size: 15),
    decoration: InputDecoration(
      hintText: localized(context, LibraryStrings.searchHint, 'Hareket ara'),
      // İpucu metni de METİNDİR — placeholder olması WCAG'den muaf
      // tutmaz; kullanıcı onu okuyup ne yazacağını anlıyor.
      hintStyle: GravitaType.body(
        context: context,
        size: 15,
        color: GravitaColors.of(context).textSecondary,
      ),
      prefixIcon: Icon(
        Icons.search,
        color: GravitaColors.of(context).textTertiary,
      ),
      suffixIcon: _query.text.isEmpty
          ? null
          : IconButton(
              tooltip: localized(
                context,
                LibraryStrings.searchClear,
                'Aramayı temizle',
              ),
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(_query.clear),
            ),
      filled: true,
      fillColor: GravitaColors.of(context).cardTop,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: GravitaColors.of(context).cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: GravitaColors.of(context).cardBorder),
      ),
    ),
  );

  // ── Arama sonuçları ─────────────────────────────────────────────────────

  List<Widget> _searchResults(LibrarySearchResult result) => <Widget>[
    if (result.movements.isNotEmpty)
      SurfaceSection(
        key: LibraryScreen.movementResultsKey,
        title: localized(
          context,
          result.movements.length == 1
              ? '{count} movement'
              : '{count} movements',
          '{count} hareket',
          values: <String, Object>{'count': result.movements.length},
        ),
        children: result.movements
            .map(
              (MovementEntry m) =>
                  MovementCard(movement: m, onTap: () => _openMovement(m)),
            )
            .toList(growable: false),
      ),
    // ⭐ KRİTİK KISIT: kapsam-dışı eşleşme, hareket eşleşmesi olsa da
    // olmasa da GÖSTERİLİR. Yalnız "hareket bulunamadıysa" gösterseydik,
    // "squat" arayan kullanıcı hem hack squat'ı hem gerekçesini kaçırırdı.
    if (result.exclusions.isNotEmpty) ...<Widget>[
      if (result.movements.isNotEmpty) const SizedBox(height: 30),
      SurfaceSection(
        key: LibraryScreen.exclusionResultsKey,
        title: localized(
          context,
          LibraryStrings.searchExclusionHeading,
          'Gravita kapsamı dışında — nedeni',
        ),
        children: result.exclusions
            .map(
              (ExclusionSection s) => InkWell(
                onTap: () => _openWhyNot(focusSectionId: s.id),
                borderRadius: BorderRadius.circular(22),
                child: NoteCard(
                  key: Key('library.exclusion.${s.id}'),
                  sealed: true,
                  title: exclusionSectionTitle(context, s),
                  text: exclusionSectionReason(context, s),
                ),
              ),
            )
            .toList(growable: false),
      ),
    ],
    // GERÇEK boşluk — sessiz boş liste değil, bir cümle.
    if (result.isEmpty)
      NoteCard(
        key: LibraryScreen.emptyResultKey,
        icon: Icons.search_off,
        text: localized(
          context,
          'Nothing in our catalogue matches "{query}", and it is not one of the things we have deliberately left out either. It may simply be a movement we have not written up.',
          'Katalogda "{query}" ile eşleşen bir hareket '
              'veya kapsam dışı gerekçe bulunamadı.',
          values: <String, Object>{'query': result.query.trim()},
        ),
      ),
    const SizedBox(height: 24),
    _whyNotLink(),
  ];

  // ── Gezinme (arama yokken) ──────────────────────────────────────────────

  List<Widget> _browse() {
    final List<Widget> out = <Widget>[];
    for (final ({String family, String label, List<MovementEntry> movements}) f
        in _catalogue.families) {
      out.add(
        SurfaceSection(
          key: Key('library.family.${f.family}'),
          title: localizedUpper(
            context,
            f.label,
            familyDisplayName(context, f.family, f.label),
          ),
          trailing: Text(
            formatLocaleNumber(
              f.movements.length,
              Localizations.localeOf(context).toLanguageTag(),
            ),
            style: GravitaType.mono(
              context: context,
              size: 11,
              color: GravitaColors.of(context).textSecondary,
            ),
          ),
          children: f.movements
              .map(
                (MovementEntry m) =>
                    MovementCard(movement: m, onTap: () => _openMovement(m)),
              )
              .toList(growable: false),
        ),
      );
      out.add(const SizedBox(height: 30));
    }
    out.add(_skillTrees());
    out.add(const SizedBox(height: 24));
    out.add(_whyNotLink());
    return out;
  }

  /// Beceri ağaçları — ÇİZİLMİYOR ve sebebi söyleniyor.
  ///
  /// ⚠️ Bu bir eksiklik beyanıdır, bir "yakında" değil. `content/skill-graph/`
  /// iki paket taşıyor ve ikisi de `status: DRAFT` — kilit eşikleri bir
  /// hareket-bilimi geçişinden GEÇMEDİ. Ağacı çizmek, o eşikleri "ölçülmüş
  /// kapı" gibi sunmak olurdu (eşik icadı yasağı). Kullanıcıya ne olduğunu
  /// söylüyoruz; ne zaman geleceğini söylemiyoruz.
  ///
  /// ⛔ Falsifiable — H-44: bkz. `LibraryStrings.skillTreesBody` üstündeki
  /// not (`library_strings.dart`). Kısaca: bu ekran `SkillTree.
  /// thresholdsValidated`e bakıyor, o alan `tools/build_skill_tree_index.py`
  /// tarafından paketin kendi `status` önekinden MEKANİK üretiliyor — ve
  /// model `nodes[]`i hiç ayrıştırmadığı için (satır ~342) taslak bir
  /// paketin eşiği bu ekrandan yapısal olarak SIZAMAZ.
  Widget _skillTrees() => SurfaceSection(
    key: LibraryScreen.skillTreesKey,
    title: localizedUpper(
      context,
      LibraryStrings.skillTreesTitle,
      'BECERİ AĞAÇLARI',
    ),
    children: <Widget>[
      NoteCard(
        sealed: true,
        icon: Icons.account_tree_outlined,
        text: localized(
          context,
          'Drafted progression trees: {count} ({names}). Their unlock criteria have not been through a movement-science review. We are not drawing a tree whose gates would be numbers we picked ourselves. Some related movement pages are in the library. Learning guides and camera availability are shown separately; this summary does not approve physical practice.',
          '{count} taslak ilerleme ağacı '
              'bulunuyor ({names}). İlerleme koşulları '
              'hareket bilimi incelemesinden geçmediği için ağaçları adım adım '
              'göstermiyoruz. İlgili bazı hareket sayfaları kütüphanede bulunur. '
              'Öğrenme rehberleri ve kamera erişimi ayrıca belirtilir; '
              'bu özet fiziksel uygulamayı onaylamaz.',
          values: <String, Object>{
            'count': _catalogue.skillTrees.drafted.length,
            'names': draftedTreeNames(context, _catalogue.skillTrees),
          },
        ),
      ),
    ],
  );

  Widget _whyNotLink() => InkWell(
    key: LibraryScreen.whyNotLinkKey,
    onTap: _openWhyNot,
    borderRadius: BorderRadius.circular(18),
    child: GravitaCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.help_outline,
            size: 18,
            color: GravitaColors.of(context).accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              localized(
                context,
                LibraryStrings.whyNotLink,
                'Bir hareket neden burada yok?',
              ),
              style: GravitaType.body(
                context: context,
                size: 14,
                weight: FontWeight.w500,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: GravitaColors.of(context).textTertiary,
          ),
        ],
      ),
    ),
  );
}
