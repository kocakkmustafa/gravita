import 'package:flutter/material.dart';

import 'app_locale.dart';
import 'account_connection.dart';
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
    appBar: AppBar(
      title: Text(localized(context, LibraryStrings.profileTitle, 'Profil')),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 96),
      children: <Widget>[
        if (AccountScope.maybeOf(context)?.connection case final AccountConnection account) ...<Widget>[
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: account.pageBuilder),
            ),
            icon: const Icon(Icons.person_outline),
            label: Text(localized(context, 'Account', 'Hesap')),
          ),
          const SizedBox(height: 14),
        ],
        NoteCard(
          key: noSettingsKey,
          icon: Icons.tune_outlined,
          title: AccountScope.maybeOf(context)?.connection == null
              ? localized(context, LibraryStrings.profileNoSettings,
                  'Ayarlanacak seçenek yok')
              : localized(context, 'Measurement settings', 'Ölçüm ayarları'),
          text: AccountScope.maybeOf(context)?.connection == null
              ? localized(context, LibraryStrings.profileNoSettingsBody,
                  'Bu ekranda değiştirebileceğiniz bir ayar bulunmuyor.')
              : localized(context,
                  'There are no measurement preferences to change. Account options are available above.',
                  'Değiştirilecek bir ölçüm tercihi yok. Hesap seçenekleri yukarıdadır.'),
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
          title: localized(
            context,
            LibraryStrings.profileWontTitle.toUpperCase(),
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
                    const Icon(
                      Icons.help_outline,
                      size: 18,
                      color: GravitaColors.accent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        localized(context,
                            content.catalogue.exclusions.title,
                            'Gravita’da neler yok — ve neden'),
                        style: GravitaType.body(
                          size: 14,
                          weight: FontWeight.w500,
                        ),
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
            ),
          ],
        ),
      ],
    ),
  );
}
