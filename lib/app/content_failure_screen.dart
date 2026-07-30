import 'package:flutter/material.dart';

import 'content_failure.dart';

/// DÜRÜST HATA EKRANI — JabLab `6601b1b` uyarlaması.
///
/// Bu ekranın işi kötü haberi YUMUŞATMAK değil, **doğru söylemek.** Ürünün
/// tamamı "ölçemediğimi söylerim" iddiası üzerine kurulu; o iddia açılış
/// ekranında çöküyorsa geri kalan her dürüstlük beyanı da inandırıcılığını
/// kaybeder. JabLab'ın üç kararı AYNEN alındı:
///
///  * **"Try again" YALNIZ işe yarayabileceği sınıfta** ([ContentFailureKind.
///    unreadable]). Bütünlük hatasında aynı asset aynı sonucu verir; oradaki
///    retry, kullanıcıyı boşa uğraştıran bir nezaket jestidir.
///  * **"Yine de devam et" HİÇ YOK.** Doğrulamanın bloklama sebebi tam olarak
///    kısmi/sahte bir kütüphane göstermemek; kaçış kapısı onu süse çevirir.
///  * **Geliştirici ayrıntısı gizlenmedi, İKİNCİLLEŞTİRİLDİ.**
///
/// Gravita metni kendi vaadinden konuşuyor (ölçüm dürüstlüğü); yapı ve
/// kararlar JabLab'ın. Farklar: `docs/design/CONTENT-FAILURE-DELTA.md`.
class ContentFailureScreen extends StatelessWidget {
  const ContentFailureScreen({
    super.key,
    required this.failure,
    this.onRetry,
  });

  static const Key headlineKey = Key('failure-headline');
  static const Key bodyKey = Key('failure-body');
  static const Key retryKey = Key('failure-retry');
  static const Key detailKey = Key('failure-detail');

  final ContentFailure failure;

  /// `null` ise yeniden deneme sunulmaz. Çağıran karar verir — ekran kendi
  /// başına bir retry UYDURMAZ.
  final Future<void> Function()? onRetry;

  bool get _retryable => failure.kind == ContentFailureKind.unreadable;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            const SizedBox(height: 24),
            Icon(Icons.report_outlined,
                size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(_headline, key: headlineKey, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(_body, key: bodyKey, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 20),
            if (_retryable && onRetry != null)
              FilledButton(
                key: retryKey,
                onPressed: () => onRetry!(),
                child: const Text('Try again'),
              ),
            const SizedBox(height: 24),
            Card(
              child: ExpansionTile(
                title: const Text('Technical detail'),
                subtitle: const Text('What to send us if you report this'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: <Widget>[
                  SelectableText(
                    failure.detail.isEmpty
                        ? '(no detail reported)'
                        : failure.detail,
                    key: detailKey,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // "Bir şeyler ters gitti" DEMİYOR: o cümle hiçbir şey söylemez ve kullanıcıya
  // ne yapacağını bırakmaz.
  String get _headline => switch (failure.kind) {
        ContentFailureKind.integrity => 'We stopped ourselves',
        ContentFailureKind.unreadable => 'We could not read our own content',
      };

  String get _body => switch (failure.kind) {
        ContentFailureKind.integrity =>
          'The movement library that shipped with this build does not pass our '
              'own honesty checks — something in it claims more than the app '
              'can actually measure. Rather than show you a library we cannot '
              'vouch for, we show you nothing. This one is on us, not on your '
              'device, and trying again will not change it: the next build '
              'will.',
        ContentFailureKind.unreadable =>
          'The app could not read the movement content that ships inside it. '
              'That usually means the installation is damaged rather than the '
              'content being wrong. Trying again is worth one attempt; if it '
              'keeps failing, reinstalling should fix it.',
      };
}
