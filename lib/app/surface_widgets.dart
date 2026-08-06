/// Yeni yüzeylerin (Home · Library · Movement · Profile) PAYLAŞTIĞI parçalar.
///
/// `progress_view.dart` kendi `_section`/`_stat` yardımcılarını koruyor:
/// onları buraya taşımak, 61 testin doğruladığı bir dosyayı bu turda
/// gereksizce açmak olurdu. Aynı görsel dili iki yerde tutmanın bedeli
/// bilinerek ödeniyor; birleştirme, ilerleme yüzeyi de yeniden ele alındığı
/// turda yapılır.
library;

import 'package:flutter/material.dart';

import 'library_model.dart';
import 'library_strings.dart';
import 'theme.dart';


/// Bölüm başlığı + isteğe bağlı alt satır — design'ın mono "eyebrow" deseni.
class SurfaceSection extends StatelessWidget {
  const SurfaceSection({
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: GravitaType.mono(
                      size: 11,
                      color: GravitaColors.textTertiary,
                      weight: FontWeight.w600,
                      letterSpacingEm: 0.12),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: GravitaType.body(
                    size: 12.5,
                    color: GravitaColors.textSecondary,
                    height: 1.5)),
          ],
          const SizedBox(height: 14),
          for (int i = 0; i < children.length; i++) ...<Widget>[
            children[i],
            if (i < children.length - 1) const SizedBox(height: 10),
          ],
        ],
      );
}

/// Bir hareketin liste satırı.
///
/// ⚠️ Kuyruktaki hareket SOLGUN çizilmez. 31'in 30'u kuyrukta; onları ikinci
/// sınıf göstermek, kataloğun tamamını bir "yakında" duvarı gibi okuturdu.
/// Ayrım RENKTE değil ROZETTE ve alt satırdaki İSİMLİ gerekçe sayısında.
class MovementCard extends StatelessWidget {
  const MovementCard({required this.movement, required this.onTap, super.key});

  final MovementEntry movement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool live = movement.isLive;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: GravitaCard(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(movement.displayName,
                      style: GravitaType.display(
                          size: 16, weight: FontWeight.w500)),
                  const SizedBox(height: 5),
                  Text(
                    LibraryStrings.metaLine(movement),
                    style: GravitaType.body(
                        size: 12.5, color: GravitaColors.textSecondary),
                  ),
                  if (!live && movement.blockedBy.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 7),
                    Text(
                      LibraryStrings.blockerCount(movement.blockedBy.length),
                      style: GravitaType.mono(
                          size: 10.5, color: GravitaColors.honestySeal),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            GravitaPill(
              label: live
                  ? LibraryStrings.openBadge
                  : LibraryStrings.queuedBadge,
              tone: live ? GravitaColors.accent : GravitaColors.textTertiary,
              filled: live,
            ),
          ],
        ),
      ),
    );
  }
}

/// Düz bilgi kartı — bir cümle, hiçbir iddia.
class NoteCard extends StatelessWidget {
  const NoteCard({
    required this.text,
    this.title,
    this.sealed = false,
    this.icon,
    super.key,
  });

  final String text;
  final String? title;

  /// Dürüstlük mührü treatment'ı — sınır/kapı anlatan kartlar için.
  final bool sealed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color ink =
        sealed ? GravitaColors.honestyText : GravitaColors.textSecondary;
    return GravitaCard(
      sealed: sealed,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon,
                size: 18,
                color: sealed
                    ? GravitaColors.honestySeal
                    : GravitaColors.textTertiary),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (title != null) ...<Widget>[
                  Text(title!,
                      style: GravitaType.display(
                          size: 15,
                          weight: FontWeight.w500,
                          color: sealed ? GravitaColors.honestyText : null)),
                  const SizedBox(height: 8),
                ],
                Text(text,
                    style:
                        GravitaType.body(size: 13.5, color: ink, height: 1.55)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Madde işaretli dürüst liste — her satır VERİDEN gelir.
///
/// Sabit yükseklik YOK ve olamaz: gerçek içerik satırları 40 karakterden 400
/// karaktere kadar değişiyor (`push_up`'ın "which side is doing more work"
/// maddesi tek başına bir paragraf). Bu, bu ailenin ölçülmüş dersi —
/// *"gerçek metin fixture'dan uzundur."*
class ReasonList extends StatelessWidget {
  const ReasonList({
    required this.items,
    this.color = GravitaColors.ink,
    this.bulletColor = GravitaColors.textTertiary,
    super.key,
  });

  final List<String> items;
  final Color color;
  final Color bulletColor;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < items.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  // Madde işareti ilk satırın x-yüksekliğine hizalanır;
                  // `CrossAxisAlignment.start` tek başına onu satırın TEPESİNE
                  // yapıştırır ve çok satırlı maddede kayık görünür.
                  padding: const EdgeInsets.only(top: 7, right: 10),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                        color: bulletColor, shape: BoxShape.circle),
                  ),
                ),
                Expanded(
                  child: Text(items[i],
                      style: GravitaType.body(
                          size: 13.5, color: color, height: 1.55)),
                ),
              ],
            ),
          ],
        ],
      );
}
