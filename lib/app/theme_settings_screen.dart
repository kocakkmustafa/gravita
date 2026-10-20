import 'dart:async';

import 'package:flutter/material.dart';

import 'app_locale.dart';
import 'theme.dart';
import 'theme_preferences.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  static const Key systemKey = Key('appearance.system');
  static const Key lightKey = Key('appearance.light');
  static const Key darkKey = Key('appearance.dark');
  static const Key savingKey = Key('appearance.saving');
  static const Key failureKey = Key('appearance.saveFailure');
  static const Key loadIssueKey = Key('appearance.loadIssue');
  static const Key retryKey = Key('appearance.retry');

  @override
  Widget build(BuildContext context) {
    final controller = ThemePreferencesScope.of(context);
    final colors = GravitaColors.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(localized(context, 'Appearance', 'Görünüm'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: <Widget>[
          Text(
            localized(context, 'Choose a theme', 'Bir tema seçin'),
            style: GravitaType.display(context: context, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            localized(
              context,
              'Appearance is saved on this device and shared by all accounts.',
              'Görünüm bu cihazda saklanır ve tüm hesaplarda kullanılır.',
            ),
            style: GravitaType.body(
              context: context,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          GravitaCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: RadioGroup<GravitaThemeMode>(
              groupValue: controller.mode,
              onChanged: (mode) {
                if (mode != null) unawaited(controller.setMode(mode));
              },
              child: Column(
                children: <Widget>[
                  RadioListTile<GravitaThemeMode>(
                    key: systemKey,
                    value: GravitaThemeMode.system,
                    title: Text(
                      localized(
                        context,
                        'Use device theme',
                        'Cihaz temasını kullan',
                      ),
                    ),
                    subtitle: Text(
                      localized(
                        context,
                        'Follow the light or dark appearance set on your device.',
                        'Cihazınızda seçili açık veya koyu görünümü izleyin.',
                      ),
                    ),
                  ),
                  RadioListTile<GravitaThemeMode>(
                    key: lightKey,
                    value: GravitaThemeMode.light,
                    title: Text(localized(context, 'Light', 'Açık')),
                  ),
                  RadioListTile<GravitaThemeMode>(
                    key: darkKey,
                    value: GravitaThemeMode.dark,
                    title: Text(localized(context, 'Dark', 'Koyu')),
                  ),
                ],
              ),
            ),
          ),
          if (controller.saving) ...<Widget>[
            const SizedBox(height: 18),
            Semantics(
              key: savingKey,
              liveRegion: true,
              child: Row(
                children: <Widget>[
                  if (GravitaMotion.reduceMotion(context))
                    const Icon(Icons.hourglass_top, size: 18)
                  else
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      localized(
                        context,
                        'Saving appearance…',
                        'Görünüm kaydediliyor…',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (controller.loadIssue != null &&
              !controller.saveFailed) ...<Widget>[
            const SizedBox(height: 18),
            Semantics(
              key: loadIssueKey,
              liveRegion: true,
              child: Text(
                localized(
                  context,
                  controller.loadIssue == ThemePreferencesLoadIssue.invalid
                      ? 'The saved appearance could not be read. The device theme is being used; the original file has been kept.'
                      : 'Saved appearance is unavailable. The device theme is being used.',
                  controller.loadIssue == ThemePreferencesLoadIssue.invalid
                      ? 'Kayıtlı görünüm okunamadı. Cihaz teması kullanılıyor; özgün dosya korundu.'
                      : 'Kayıtlı görünüme erişilemiyor. Cihaz teması kullanılıyor.',
                ),
              ),
            ),
          ],
          if (controller.saveFailed) ...<Widget>[
            const SizedBox(height: 18),
            Semantics(
              key: failureKey,
              liveRegion: true,
              child: Text(
                localized(
                  context,
                  'Appearance could not be saved. Your choice applies for this session; try saving again.',
                  'Görünüm kaydedilemedi. Seçiminiz bu oturumda geçerli; yeniden kaydetmeyi deneyin.',
                ),
                style: GravitaType.body(
                  context: context,
                  color: colors.honestyText,
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: retryKey,
                onPressed: () => unawaited(controller.retrySave()),
                icon: const Icon(Icons.refresh),
                label: Text(
                  localized(context, 'Try saving again', 'Yeniden kaydet'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
