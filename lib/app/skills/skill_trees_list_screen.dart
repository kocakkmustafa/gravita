import 'package:flutter/material.dart';

import '../app_locale.dart';
import '../library_model.dart';
import '../library_strings.dart';
import '../surface_widgets.dart';
import '../theme.dart';
import 'skill_tree_screen.dart';

/// Beceri ağaçları — GEZİLEBİLİR indeks (GRA-P1-001).
///
/// ## Neden bu ekran var — bir gezilebilirlik kusuru DÜZELTİYOR
///
/// İlk yazışımda beceri ağacına giden TEK yol hareket sayfasındaki
/// `skillGraphNode` bağıydı — ama bu bağı taşıyan üç hareketin (`hollow_hold`
/// · `wall_handstand` · `tuck_planche`) ÜÇÜ de `coming_soon` ve aile-sıralı
/// 31 hareketlik listede geç sırada. `test/reachability_test.dart`ın gerçek
/// dokunuş yürüyüşü (Home→Library, sekme başına ilk 8 kontrol) bu bağa HİÇ
/// ULAŞAMADI — bu bir test kusuru DEĞİLDİ, gerçek bir ürün kusuruydu: bir
/// özelliğin tetiği varsa ama sıradan bir keşifte bulunamıyorsa, o tetik
/// yok denecek kadar gizlidir.
///
/// Bu ekran Home'dan (az sayıda kontrol taşıyan, en erişilebilir sekme)
/// doğrudan erişilebilir bir İNDEKS — belirli bir harekete bağlı değil,
/// `content/skill-trees.index.json`daki (ZATEN paketli) TÜM ağaçları listeler.
class SkillTreesListScreen extends StatelessWidget {
  const SkillTreesListScreen({required this.trees, super.key});

  static const Key emptyKey = Key('skillTreesList.empty');

  final List<SkillTree> trees;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        localized(context, LibraryStrings.skillTreesTitle, 'Beceri ağaçları'),
      ),
    ),
    body: trees.isEmpty
        ? Padding(
            padding: const EdgeInsets.all(18),
            child: NoteCard(
              key: emptyKey,
              icon: Icons.account_tree_outlined,
              text: localized(
                context,
                LibraryStrings.skillTreesEmpty,
                'Şu anda taslak ilerleme ağacı bulunmuyor.',
              ),
            ),
          )
        : ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 48),
            children: <Widget>[
              for (int i = 0; i < trees.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: 10),
                _TreeRow(tree: trees[i]),
              ],
            ],
          ),
  );
}

class _TreeRow extends StatelessWidget {
  const _TreeRow({required this.tree});

  final SkillTree tree;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: () => Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => SkillTreeScreen(tree: tree)),
    ),
    child: GravitaCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  tree.displayName,
                  style: GravitaType.display(size: 16, weight: FontWeight.w500),
                ),
                const SizedBox(height: 5),
                Text(
                  localized(
                    context,
                    LibraryStrings.skillTreeRowSteps(tree.nodeCount),
                    '${tree.nodeCount} adım',
                  ),
                  style: GravitaType.body(
                    size: 12.5,
                    color: GravitaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: GravitaColors.textTertiary,
          ),
        ],
      ),
    ),
  );
}
