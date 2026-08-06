import 'package:flutter/material.dart';

import 'content_repository.dart';
import 'library_strings.dart';
import 'surface_widgets.dart';
import 'theme.dart';
import 'why_not_here_screen.dart';

/// Profil — bugün yalnız DOĞRU olan şeyleri söyleyen bir ekran.
///
/// ## Tasarımın kamera/veri AYARLARI neden yok
///
/// Design'ın `profile` ekranı ayar satırları çiziyor. Bir ayar satırı, arkasında
/// DEĞİŞTİRİLECEK bir şey olmadan çizilirse ölü butondur — bu ailenin en açık
/// yasaklarından biri. Bugün değiştirilebilir tek bir tercih yok: kamera izni
/// işletim sisteminde, veri yeri sabit, ölçüm ayarı yok.
///
/// Tasarımın AYNI ekranda istediği "what this app won't do" bloku ise
/// GERÇEK ve `exclusions.json`'a bağlı. Bu ekran o bloku taşıyor, ayarları
/// taşımıyor — ve ayarların yokluğunu da söylüyor, sessizce atlamıyor.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.content, super.key});

  static const Key noSettingsKey = Key('profile.noSettings');
  static const Key dataKey = Key('profile.data');
  static const Key wontDoKey = Key('profile.wontDo');

  final ContentRepository content;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text(LibraryStrings.profileTitle)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 96),
          children: <Widget>[
            const NoteCard(
              key: noSettingsKey,
              icon: Icons.tune_outlined,
              title: LibraryStrings.profileNoSettings,
              text: LibraryStrings.profileNoSettingsBody,
            ),
            const SizedBox(height: 14),
            const NoteCard(
              key: dataKey,
              icon: Icons.folder_outlined,
              title: LibraryStrings.profileDataTitle,
              text: LibraryStrings.profileDataBody,
            ),
            const SizedBox(height: 30),
            SurfaceSection(
              key: wontDoKey,
              title: LibraryStrings.profileWontTitle.toUpperCase(),
              subtitle: LibraryStrings.profileWontBody,
              children: <Widget>[
                InkWell(
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => WhyNotHereScreen(
                          page: content.catalogue.exclusions),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(18),
                  child: GravitaCard(
                    radius: 18,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 15),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.help_outline,
                            size: 18, color: GravitaColors.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(content.catalogue.exclusions.title,
                              style: GravitaType.body(
                                  size: 14, weight: FontWeight.w500)),
                        ),
                        const Icon(Icons.chevron_right,
                            size: 20, color: GravitaColors.textTertiary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}
