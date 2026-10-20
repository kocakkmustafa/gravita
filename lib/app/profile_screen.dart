import 'package:flutter/material.dart';

import 'app_locale.dart';
import 'catalog_copy_tr.dart';
import 'account_connection.dart';
import 'content_repository.dart';
import 'library_strings.dart';
import 'language_preferences.dart';
import 'language_settings_screen.dart';
import 'surface_widgets.dart';
import 'theme.dart';
import 'theme_preferences.dart';
import 'theme_settings_screen.dart';
import 'why_not_here_screen.dart';

/// Profil — bugün yalnız DOĞRU olan şeyleri söyleyen bir ekran.
///
/// Görünüm cihaz tercihidir. Kamera izni işletim sisteminde, veri yeri sabit;
/// ölçüm ayarı ve tıbbi iddia eklenmez. Kapsam dışı blok gerçek kataloğa bağlıdır.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.content, super.key});

  static const Key noSettingsKey = Key('profile.noSettings');
  static const Key appearanceKey = Key('profile.appearance');
  static const Key languageKey = Key('profile.language');
  static const Key dataKey = Key('profile.data');
  static const Key wontDoKey = Key('profile.wontDo');

  final ContentRepository content;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      title: Text(localized(context, LibraryStrings.profileTitle, 'Profil')),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 96),
      children: <Widget>[
        if (AccountScope.maybeOf(context)?.connection
            case final AccountConnection account) ...<Widget>[
          OutlinedButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push<void>(MaterialPageRoute<void>(builder: account.pageBuilder)),
            icon: const Icon(Icons.person_outline),
            label: Text(localized(context, 'Account', 'Hesap')),
          ),
          const SizedBox(height: 14),
        ],
        if (ThemePreferencesScope.maybeOf(context) != null) ...<Widget>[
          ListTile(
            key: appearanceKey,
            leading: Icon(
              Icons.contrast,
              color: GravitaColors.of(context).accent,
            ),
            title: Text(localized(context, 'Appearance', 'Görünüm')),
            subtitle: Text(
              localized(
                context,
                'Device, light or dark',
                'Cihaz, açık veya koyu',
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const ThemeSettingsScreen(),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (LanguagePreferencesScope.maybeOf(context) != null) ...<Widget>[
          ListTile(
            key: languageKey,
            leading: Icon(
              Icons.translate,
              color: GravitaColors.of(context).accent,
            ),
            title: Text(localized(context, 'Language', 'Dil')),
            subtitle: Text(
              localized(
                context,
                'Choose the app language',
                'Uygulama dilini seçin',
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const LanguageSettingsScreen(),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        NoteCard(
          key: noSettingsKey,
          icon: Icons.tune_outlined,
          title: localized(context, 'Measurement settings', 'Ölçüm ayarları'),
          text: localized(
            context,
            'There are no measurement preferences to change.',
            'Değiştirilecek bir ölçüm tercihi yok.',
          ),
        ),
        const SizedBox(height: 14),
        NoteCard(
          key: dataKey,
          icon: Icons.folder_outlined,
          title: localized(
            context,
            LibraryStrings.profileDataTitle,
            'Verileriniz',
          ),
          text: localized(
            context,
            LibraryStrings.profileDataBody,
            'Oturum geçmişiniz yalnız bu cihazdaki uygulama klasöründe '
            'saklanır; yüklenmez. Uygulamayı silmek geçmişi de siler.',
          ),
        ),
        const SizedBox(height: 30),
        SurfaceSection(
          key: wontDoKey,
          title: localizedUpper(
            context,
            LibraryStrings.profileWontTitle,
            'BU UYGULAMANIN YAPMADIKLARI',
          ),
          subtitle: localized(
            context,
            LibraryStrings.profileWontBody,
            'Yaralanma tanısı veya rehabilitasyon önerisi sunmayız; '
            'kuvvet ölçmeyiz ve dayanağı olmayan puanlar vermeyiz. '
            'Kapsam dışında kalanların listesi aşağıdadır.',
          ),
          children: <Widget>[
            InkWell(
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      WhyNotHereScreen(page: content.catalogue.exclusions),
                ),
              ),
              borderRadius: BorderRadius.circular(18),
              child: GravitaCard(
                radius: 18,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
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
                        exclusionPageTitle(
                          context,
                          content.catalogue.exclusions,
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
            ),
          ],
        ),
      ],
    ),
  );
}
