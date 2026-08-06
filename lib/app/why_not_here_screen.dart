import 'package:flutter/material.dart';

import 'library_model.dart';
import 'theme.dart';

/// "Neden yok?" — kapsamın SINIRI, gerekçesiyle.
///
/// ## Tek satır bile elle yazılmadı
///
/// Sayfanın başlığı, girişi, her bölümü ve her örneği
/// `content/catalog/exclusions.json`'dan ÜRETİLİR
/// (`tools/build_exclusions_page.py` → `content/exclusions.page.json`).
/// Gerekçe metni destek yanıtlarıyla ve pazarlamayla AYNI cümledir — üç yerde
/// üç farklı gerekçe olmaz (kaynak dosyanın kendi `purpose` beyanı).
///
/// Kaynağın iç alanları (`internalRule_tr`, `reconsiderIf`) uygulamaya HİÇ
/// girmiyor: üretim adımı beyaz listeyle çalışıyor.
///
/// ## Neden bu bir "boş sonuç" ekranı değil
///
/// Kütüphanede *"leg press"* arayan kullanıcı buraya DÜŞER. Bu sayfa o yüzden
/// bir hata/boşluk hâli gibi değil, ürünün kendi kararlarını anlattığı bir
/// yüzey gibi görünmek zorunda: sıfır sonuç ürünü DAR gösterir, gerekçeli bir
/// sınır KASITLI gösterir.
class WhyNotHereScreen extends StatelessWidget {
  const WhyNotHereScreen({
    required this.page,
    this.focusSectionId,
    super.key,
  });

  static const Key introKey = Key('whyNot.intro');
  static Key sectionKey(String id) => Key('whyNot.section.$id');

  final ExclusionsPage page;

  /// Aramadan gelindiyse ilgili bölüm VURGULANIR — kullanıcı yedi bölümün
  /// içinde kendi aradığını aramak zorunda kalmasın.
  final String? focusSectionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(page.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: <Widget>[
          Text(
            page.intro,
            key: introKey,
            style: GravitaType.body(
                size: 14.5, color: GravitaColors.inkMuted, height: 1.6),
          ),
          const SizedBox(height: 26),
          for (final ExclusionSection s in page.sections) ...<Widget>[
            _section(s, focused: s.id == focusSectionId),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _section(ExclusionSection s, {required bool focused}) => GravitaCard(
        key: sectionKey(s.id),
        // Vurgu MÜHÜR ile yapılıyor, ayrı bir "seçili" rengiyle değil: aynı
        // görsel dil, ikinci bir anlam katmanı eklemeden.
        sealed: focused,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    s.title,
                    style: GravitaType.display(
                        size: 17,
                        weight: FontWeight.w600,
                        color: focused ? GravitaColors.honestyText : null),
                  ),
                ),
                if (s.movementClass != null) ...<Widget>[
                  const SizedBox(width: 10),
                  GravitaPill(
                    label: 'CLASS ${s.movementClass}',
                    tone: GravitaColors.textTertiary,
                    filled: false,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              s.userReason,
              style: GravitaType.body(
                  size: 13.5,
                  height: 1.6,
                  color: focused
                      ? GravitaColors.honestyText
                      : GravitaColors.inkMuted),
            ),
            if (s.examples.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              // Örnekler ARAMANIN eşleştiği sözcüklerdir; göstermek, "bunu
              // aradıysan doğru yerdesin" demenin en kısa yolu.
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: s.examples
                    .map((String e) => GravitaPill(
                          label: e,
                          tone: GravitaColors.textTertiary,
                          filled: false,
                        ))
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      );
}
