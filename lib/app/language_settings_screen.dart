import 'dart:async';

import 'package:flutter/material.dart';

import 'app_locale.dart';
import 'language_preferences.dart';
import 'theme.dart';

/// Autonyms stay recognizable while the surrounding app language changes.
const Map<String, String> languageAutonyms = <String, String>{
  'en': 'English',
  'tr': 'Türkçe',
  'es-419': 'Español (Latinoamérica)',
  'pt-BR': 'Português (Brasil)',
  'de': 'Deutsch',
  'fr': 'Français',
  'ja': '日本語',
  'ar': 'العربية',
  'it': 'Italiano',
  'ko': '한국어',
  'id': 'Bahasa Indonesia',
  'pl': 'Polski',
  'hi': 'हिन्दी',
  'zh-Hans': '简体中文',
};

class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  static const Key systemKey = Key('language.system');
  static const Key savingKey = Key('language.saving');
  static const Key statusPanelKey = Key('language.statusPanel');
  static const Key failureKey = Key('language.saveFailure');
  static const Key loadIssueKey = Key('language.loadIssue');
  static const Key retryKey = Key('language.retry');
  static Key languageKey(String tag) => ValueKey<String>('language.$tag');
  static const String _systemValue = 'system';

  @override
  Widget build(BuildContext context) {
    final controller = LanguagePreferencesScope.of(context);
    final colors = GravitaColors.of(context);
    final status = <Widget>[
      if (controller.saving) ...<Widget>[
        const SizedBox(height: 18),
        Semantics(
          key: savingKey,
          liveRegion: true,
          child: Row(
            children: <Widget>[
              if (GravitaMotion.reduceMotion(context))
                const Icon(Icons.hourglass_empty, size: 18)
              else
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  localized(context, 'Saving language…', 'Dil kaydediliyor…'),
                ),
              ),
            ],
          ),
        ),
      ],
      if (controller.loadIssue != null && !controller.saveFailed) ...<Widget>[
        const SizedBox(height: 18),
        Semantics(
          key: loadIssueKey,
          liveRegion: true,
          child: Text(
            localized(
              context,
              controller.loadIssue == LanguagePreferencesLoadIssue.invalid
                  ? 'The saved language could not be read. The device language is being used; the original file has been kept.'
                  : 'Saved language is unavailable. The device language is being used.',
              controller.loadIssue == LanguagePreferencesLoadIssue.invalid
                  ? 'Kayıtlı dil okunamadı. Cihaz dili kullanılıyor; özgün dosya korundu.'
                  : 'Kayıtlı dile erişilemiyor. Cihaz dili kullanılıyor.',
            ),
            style: GravitaType.body(
              context: context,
              color: colors.honestyText,
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
              'Language could not be saved. Your choice applies for this session; try saving again.',
              'Dil kaydedilemedi. Seçiminiz bu oturumda geçerli; yeniden kaydetmeyi deneyin.',
            ),
            style: GravitaType.body(context: context, color: colors.error),
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
    ];
    return Scaffold(
      appBar: AppBar(title: Text(localized(context, 'Language', 'Dil'))),
      body: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                children: <Widget>[
                  Text(
                    localized(
                      context,
                      'Choose the app language',
                      'Uygulama dilini seçin',
                    ),
                    style: GravitaType.display(context: context, size: 24),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    localized(
                      context,
                      'Language is saved on this device and shared by all accounts.',
                      'Dil bu cihazda saklanır ve tüm hesaplarda kullanılır.',
                    ),
                    style: GravitaType.body(
                      context: context,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GravitaCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: RadioGroup<String>(
                      groupValue: controller.selectedTag ?? _systemValue,
                      onChanged: (String? value) {
                        if (value != null) {
                          unawaited(
                            controller.setSelectedTag(
                              value == _systemValue ? null : value,
                            ),
                          );
                        }
                      },
                      child: Column(
                        children: <Widget>[
                          RadioListTile<String>(
                            key: systemKey,
                            value: _systemValue,
                            title: Text(
                              localized(
                                context,
                                'Use device language',
                                'Cihaz dilini kullan',
                              ),
                            ),
                            subtitle: Text(
                              localized(
                                context,
                                'Follow your device’s preferred languages. Use English if none are supported.',
                                'Cihazınızın tercih edilen dillerini izleyin. Hiçbiri desteklenmiyorsa İngilizce kullanılır.',
                              ),
                            ),
                          ),
                          for (final entry in languageAutonyms.entries)
                            RadioListTile<String>(
                              key: languageKey(entry.key),
                              value: entry.key,
                              title: Text(
                                entry.value,
                                locale: localeForAppTag(entry.key),
                                textDirection: entry.key == 'ar'
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (status.isNotEmpty)
              // Feedback must remain reachable when the language list scrolls.
              // Bound the complete panel, including system insets, to leave
              // usable space for choices at large text sizes and short heights.
              ConstrainedBox(
                key: statusPanelKey,
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.4,
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    primary: false,
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: status,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
