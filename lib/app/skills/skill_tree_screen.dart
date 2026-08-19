import 'package:flutter/material.dart';

import '../library_model.dart';
import '../library_strings.dart';
import '../surface_widgets.dart';
import '../theme.dart';

/// Tek bir beceri ağacının GERÇEKTEN gösterilebilir yüzü (GRA-P1-001).
///
/// ## Neden bu sayfa `lib/app/skills/skill_progress.dart`ın ZENGİN
/// `SkillPack`/`SkillNode` tiplerini KULLANMIYOR
///
/// `content/skill-graph/*.json` (düğüm başlıkları, alıştırmalar, ön-koşul
/// zinciri) `pubspec.yaml`de BİLEREK paketlenmiyor — yorum aynen: *"Paketlerin
/// kendisi PAKETLENMEZ: `nodes[]` doğrulanmamış eşik değerleri taşıyor...
/// onları uygulamaya sokmak, ölçülmemiş bir sayıyı kapı gibi çizmeye davet
/// olurdu."* Yani `SkillPack.parse()`in okuyacağı bir bundle yolu ÜRETİMDE
/// YOK — yalnız testlerde (`dart:io File`, gerçek repo ağacı) çalışır.
///
/// Bu sayfa bunun yerine ZATEN PAKETLİ [SkillTree] özetini kullanır
/// (`content/skill-trees.index.json`, `library_model.dart`) —
/// `LibraryScreen`in "Skill trees" bölümüyle AYNI kaynak, AYNI disiplin,
/// yalnız TEK bir ağaca odaklanmış NAVİGE EDİLEBİLİR bir yüzey. Düğüm
/// listesi/ilerleme/mevcut-adım ÇİZİLMEZ (roadmap'in "current node UI" tam
/// tanımı) — bu, eksik bir ekran DEĞİL, `M-F-38` hareket-bilimi geçişine
/// EXTERNAL_GATE'li bir yüzeyin dürüst hâli (bkz. DEFTER G-269).
class SkillTreeScreen extends StatelessWidget {
  const SkillTreeScreen({required this.tree, super.key});

  static const Key statusKey = Key('skillTree.status');

  final SkillTree tree;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tree.displayName)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 48),
          children: <Widget>[
            Text(
              LibraryStrings.skillTreeScreenStepCount(tree.nodeCount)
                  .toUpperCase(),
              style: GravitaType.mono(
                  size: 11,
                  color: GravitaColors.textSecondary,
                  weight: FontWeight.w600,
                  letterSpacingEm: 0.12),
            ),
            const SizedBox(height: 14),
            NoteCard(
              key: SkillTreeScreen.statusKey,
              sealed: true,
              icon: Icons.account_tree_outlined,
              // ⚠️ İKİ dal da VAR ama bugün yalnız BİRİ gerçekten ulaşılabilir
              // (`thresholdsValidated` her iki gerçek pakette de `false`) —
              // `test/skill_tree_screen_test.dart`ın POZİTİF İKİZ grubu
              // ikisini de sentetik veriyle sınıyor, ölü kod bırakmaz.
              text: tree.thresholdsValidated
                  ? LibraryStrings.skillTreeScreenValidatedBody
                  : LibraryStrings.skillTreeScreenNotDrawnBody(
                      tree.displayName),
            ),
          ],
        ),
      );
}
