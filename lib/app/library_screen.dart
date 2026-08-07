import 'package:flutter/material.dart';

import 'content_repository.dart';
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
  const LibraryScreen({required this.content, super.key});

  static const Key searchFieldKey = Key('library.search');
  static const Key exclusionResultsKey = Key('library.searchExclusions');
  static const Key movementResultsKey = Key('library.searchMovements');
  static const Key emptyResultKey = Key('library.searchNothing');
  static const Key whyNotLinkKey = Key('library.whyNotLink');
  static const Key skillTreesKey = Key('library.skillTrees');

  final ContentRepository content;

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
          builder: (_) =>
              MovementPage(movement: m, content: widget.content),
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
    final LibrarySearchResult result = _catalogue.search(_query.text);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text(LibraryStrings.libraryTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 96),
        children: <Widget>[
          Text(
            LibraryStrings.libraryCount(
                _catalogue.movements.length, _catalogue.liveCount),
            style: GravitaType.mono(
                size: 11, color: GravitaColors.textSecondary),
          ),
          const SizedBox(height: 14),
          _searchField(),
          const SizedBox(height: 22),
          if (result.hasQuery)
            ..._searchResults(result)
          else
            ..._browse(),
        ],
      ),
    );
  }

  Widget _searchField() => TextField(
        key: LibraryScreen.searchFieldKey,
        controller: _query,
        onChanged: (_) => setState(() {}),
        style: GravitaType.body(size: 15),
        decoration: InputDecoration(
          hintText: LibraryStrings.searchHint,
          // İpucu metni de METİNDİR — placeholder olması WCAG'den muaf
          // tutmaz; kullanıcı onu okuyup ne yazacağını anlıyor.
          hintStyle: GravitaType.body(
              size: 15, color: GravitaColors.textSecondary),
          prefixIcon:
              const Icon(Icons.search, color: GravitaColors.textTertiary),
          suffixIcon: _query.text.isEmpty
              ? null
              : IconButton(
                  tooltip: LibraryStrings.searchClear,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(_query.clear),
                ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.55),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
          ),
        ),
      );

  // ── Arama sonuçları ─────────────────────────────────────────────────────

  List<Widget> _searchResults(LibrarySearchResult result) => <Widget>[
        if (result.movements.isNotEmpty)
          SurfaceSection(
            key: LibraryScreen.movementResultsKey,
            title: LibraryStrings.searchMovementHeading(
                result.movements.length),
            children: result.movements
                .map((MovementEntry m) =>
                    MovementCard(movement: m, onTap: () => _openMovement(m)))
                .toList(growable: false),
          ),
        // ⭐ KRİTİK KISIT: kapsam-dışı eşleşme, hareket eşleşmesi olsa da
        // olmasa da GÖSTERİLİR. Yalnız "hareket bulunamadıysa" gösterseydik,
        // "squat" arayan kullanıcı hem hack squat'ı hem gerekçesini kaçırırdı.
        if (result.exclusions.isNotEmpty) ...<Widget>[
          if (result.movements.isNotEmpty) const SizedBox(height: 30),
          SurfaceSection(
            key: LibraryScreen.exclusionResultsKey,
            title: LibraryStrings.searchExclusionHeading,
            children: result.exclusions
                .map((ExclusionSection s) => InkWell(
                      onTap: () => _openWhyNot(focusSectionId: s.id),
                      borderRadius: BorderRadius.circular(22),
                      child: NoteCard(
                        key: Key('library.exclusion.${s.id}'),
                        sealed: true,
                        title: s.title,
                        text: s.userReason,
                      ),
                    ))
                .toList(growable: false),
          ),
        ],
        // GERÇEK boşluk — sessiz boş liste değil, bir cümle.
        if (result.isEmpty)
          NoteCard(
            key: LibraryScreen.emptyResultKey,
            icon: Icons.search_off,
            text: LibraryStrings.searchNothing(result.query.trim()),
          ),
        const SizedBox(height: 24),
        _whyNotLink(),
      ];

  // ── Gezinme (arama yokken) ──────────────────────────────────────────────

  List<Widget> _browse() {
    final List<Widget> out = <Widget>[];
    for (final ({String family, String label, List<MovementEntry> movements}) f
        in _catalogue.families) {
      out.add(SurfaceSection(
        key: Key('library.family.${f.family}'),
        title: f.label.toUpperCase(),
        trailing: Text(
          '${f.movements.length}',
          style: GravitaType.mono(
              size: 11, color: GravitaColors.textSecondary),
        ),
        children: f.movements
            .map((MovementEntry m) =>
                MovementCard(movement: m, onTap: () => _openMovement(m)))
            .toList(growable: false),
      ));
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
  Widget _skillTrees() => SurfaceSection(
        key: LibraryScreen.skillTreesKey,
        title: LibraryStrings.skillTreesTitle.toUpperCase(),
        children: <Widget>[
          NoteCard(
            sealed: true,
            icon: Icons.account_tree_outlined,
            text: LibraryStrings.skillTreesBody(
                _catalogue.skillTrees.drafted.length,
                _catalogue.skillTrees.draftedNames),
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
              const Icon(Icons.help_outline,
                  size: 18, color: GravitaColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(LibraryStrings.whyNotLink,
                    style: GravitaType.body(
                        size: 14, weight: FontWeight.w500)),
              ),
              const Icon(Icons.chevron_right,
                  size: 20, color: GravitaColors.textTertiary),
            ],
          ),
        ),
      );
}
