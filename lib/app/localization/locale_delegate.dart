import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'locale_catalog.dart';

final class GravitaLocalizations {
  const GravitaLocalizations(this.localeTag);
  final String localeTag;
}

/// Bundled display dictionaries only. A missing/broken asset is a loading
/// error, rather than silently claiming an accepted language bundle.
final class GravitaLocalizationsDelegate
    extends LocalizationsDelegate<GravitaLocalizations> {
  const GravitaLocalizationsDelegate({
    this.bundle,
    this.pluralBundle,
    this.englishDisplayBundle,
  });

  /// An injected bundle lets reader tests use small display-only fixtures.
  /// Production continues to read the packaged assets through rootBundle.
  final AssetBundle? bundle;

  /// Production plural sidecars use rootBundle. Reader fixtures may opt in
  /// separately, so a small injected dictionary remains a valid test seam.
  final AssetBundle? pluralBundle;

  /// Optional fixture seam for reviewed English presentation corrections.
  /// Source IDs and packaged course bytes keep the canonical English index.
  final AssetBundle? englishDisplayBundle;

  @override
  bool isSupported(Locale locale) =>
      isSupportedLocaleTag(locale.toLanguageTag());

  @override
  Future<GravitaLocalizations> load(Locale locale) async {
    final tag = canonicalLocaleTag(locale.toLanguageTag());
    final assets = bundle ?? rootBundle;
    final english = LocaleCatalog.parse(
      await assets.loadString('content/locales/en.json'),
    );
    final requested = tag == 'en'
        ? english
        : LocaleCatalog.parse(
            await assets.loadString('content/locales/$tag.json'),
          );
    if (requested.localeTag != tag) {
      throw const FormatException('Locale asset does not match requested tag');
    }
    final plurals = bundle == null || pluralBundle != null
        ? LocalePluralCatalog.parse(
            await (pluralBundle ?? rootBundle).loadString(
              'content/locales/plurals/$tag.json',
            ),
          )
        : null;
    final englishDisplay = bundle == null || englishDisplayBundle != null
        ? LocaleCatalog.parse(
            await (englishDisplayBundle ?? rootBundle).loadString(
              'content/locales/display-overrides/en.json',
            ),
          )
        : null;
    await initializeDateFormatting(localeFormattingName(tag));
    LocaleCatalogRegistry.register(
      english,
      requested,
      plurals: plurals,
      englishDisplayOverrides: englishDisplay,
    );
    return GravitaLocalizations(tag);
  }

  @override
  bool shouldReload(GravitaLocalizationsDelegate old) =>
      bundle != old.bundle ||
      pluralBundle != old.pluralBundle ||
      englishDisplayBundle != old.englishDisplayBundle;
}
