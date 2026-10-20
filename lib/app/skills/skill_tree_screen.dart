import 'package:flutter/material.dart';

import '../app_locale.dart';
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
    appBar: AppBar(title: Text(skillTreeName(context, tree))),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 48),
      children: <Widget>[
        Text(
          localizedUpper(
            context,
            tree.nodeCount == 1
                ? '{count} step, drafted'
                : '{count} steps, drafted',
            '{count} adım, taslak',
            values: <String, Object>{'count': tree.nodeCount},
          ),
          style: GravitaType.mono(
            context: context,
            size: 11,
            color: GravitaColors.of(context).textSecondary,
            weight: FontWeight.w600,
            letterSpacingEm: 0.12,
          ),
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
              ? localized(
                  context,
                  LibraryStrings.skillTreeScreenValidatedBody,
                  'Bu ilerleme yolunun açılma koşulları hareket bilimi '
                  'incelemesinden geçmiştir. Adım adım görünüm oluşturulmamıştır.',
                )
              : localized(
                  context,
                  'We are not showing you the individual steps of {tree}: their '
                      'unlock criteria have not been through a movement-science review, and '
                      'we do not want to draw a gate whose number we picked ourselves. The '
                      'related movement pages in the library show their learning guides and '
                      'camera availability separately; this summary does not approve physical '
                      'practice.',
                  '{tree} adımlarını tek tek göstermiyoruz: '
                      'ilerleme koşulları hareket bilimi incelemesinden geçmedi. '
                      'İlgili bazı hareket sayfaları kütüphanede bulunur. '
                      'Öğrenme rehberleri ve kamera erişimi ayrıca belirtilir; '
                      'bu özet fiziksel uygulamayı onaylamaz.',
                  values: <String, Object>{
                    'tree': skillTreeName(context, tree),
                  },
                ),
        ),
      ],
    ),
  );
}
