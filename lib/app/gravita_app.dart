import 'package:flutter/material.dart';
import 'package:gravita_engine/gravita_engine.dart';

import 'content_failure.dart';
import 'content_failure_screen.dart';
import 'content_repository.dart';
import 'live_session_screen.dart';
import 'live_strings.dart';
import 'progress_view.dart';
import 'theme.dart';

/// Uygulama kabuğu — bugün TEK yüzey: ilerleme.
///
/// Kasıtlı olarak dar: seans ekranı kamera köprüsüne bağlı (ailenin en büyük
/// eksik bloku) ve kamerasız bir "seans" ekranı çalışmayan bir buton olurdu.
/// Ölü buton koymuyoruz (aile kuralı) — yüzey, arkasında ÇALIŞAN ölçüm olan
/// kadarıyla açılıyor.
class GravitaApp extends StatelessWidget {
  const GravitaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Gravita',
        // M-F-282 giydirme turu: tema artık design panel v1'den (`theme.dart`).
        // Yapıyı DEVRALDI, icat etmedi — bkz. `progress_view.dart` dosya
        // yorumu ve `docs/design/DESIGN-AHEAD-OF-CODE.md`.
        theme: GravitaTheme.light,
        home: const ProgressScreen(),
      );
}

/// Yükleme sonucu — İKİ başarısızlık AYRI taşınır.
///
/// Tek bir `Object? error` alanı bu ayrımı yok ederdi: geçmiş hatası bütün
/// uygulamayı bloklardı, ya da daha kötüsü sessizce boş geçmiş gösterirdi
/// (bkz. [HistoryStatus] gerekçesi).
final class _Loaded {
  const _Loaded({
    required this.summary,
    required this.historyStatus,
    this.liveConfig,
  });
  final ProgressSummary summary;
  final HistoryStatus historyStatus;

  /// Canlı seansın koşabileceği hareket — `null` ise giriş ÇİZİLMEZ.
  /// Bugün yalnız `push_up` (tek `derived` ön koşullu hareket).
  final MovementConfig? liveConfig;
}

/// İlerleme ekranı — veriyi toplar, YAPIyı [ProgressView]'a bırakır.
class ProgressScreen extends StatefulWidget {
  /// Canlı seans girişinin nöbet anahtarı — testler bu butonun VARLIĞINI ve
  /// YOKLUĞUNU ayrı ayrı sınıyor (M-F-194).
  static const Key liveFabKey = Key('progress.liveFab');

  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  Future<_Loaded>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<_Loaded> _load() async {
    // İÇERİK hatası fırlar ve BLOKLAR — yakalanmıyor, `FutureBuilder`a gidiyor.
    final ContentRepository content =
        await ContentRepository.load(DefaultAssetBundle.of(context));

    // GEÇMİŞ ayrı ele alınır: içerik sağlamsa dersler açılabilir. Ama hata
    // YUTULMAZ — `historyStatus` yüzeye taşınır ve orada BEYAN EDİLİR.
    // `catch` içinde boş liste dönüp devam etmek, kullanıcının geçmişini
    // "yok" ilan etmek olurdu (Gravita deltası, `content_failure.dart`).
    List<SessionRecord> records = const <SessionRecord>[];
    HistoryStatus historyStatus = const HistoryOk();
    try {
      final SessionStore store = await ContentRepository.openSessionStore();
      records = await store.recent();
      // Çekirdek 0.10.0: kayıp satır sayısı ARTIK ÖLÇÜLEBİLİR. Aynı depodan
      // okunur ki sayılar ile kayıp aynı ana ait olsun.
      final int unreadable = await store.unreadableRecords();
      historyStatus =
          unreadable > 0 ? HistoryPartial(unreadable) : const HistoryOk();
    } on Object catch (e) {
      historyStatus = HistoryUnavailable(e.toString());
    }

    // Canlı yol YALNIZ kimlik ön koşulu TÜRETİLMİŞ harekette açılır.
    // Bu, K8'in (kütüphane kapısı) çalışma-zamanı ikizi: kapı içerikte
    // "live" demeyi engelliyor, bu satır da yüzeyde butonu engelliyor.
    MovementConfig? liveConfig;
    for (final MovementConfig c in content.movementConfigs) {
      if (c.preconditionDerived) {
        liveConfig = c;
        break;
      }
    }

    return _Loaded(
      liveConfig: liveConfig,
      summary: ProgressSummary.build(
        lessonSurfaces: content.lessonSurfaces,
        records: records,
      ),
      historyStatus: historyStatus,
    );
  }

  Future<void> _retry() async => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Loaded>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<_Loaded> snapshot) {
        // İçerik hatası tipli ekrana gider (JabLab J-079 deseni). Eski hâli
        // `Text('Could not load: ${snapshot.error}')`ti — yani kullanıcıya
        // `StateError` gövdesi gösteriyordu: "çökmüyor" ile "dürüstçe
        // açıklıyor" aynı şey değil.
        if (snapshot.hasError) {
          return ContentFailureScreen(
            failure: ContentFailure.from(snapshot.error!),
            onRetry: _retry,
          );
        }
        final _Loaded? loaded = snapshot.data;
        if (loaded == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Gravita')),
          body: ProgressView(
            summary: loaded.summary,
            historyStatus: loaded.historyStatus,
          ),
          // CANLI seans girişi. ⚠️ "Ölü buton YOK" kuralı gereği bu buton
          // ancak arkasında ÇALIŞAN bir ölçüm varken çizilir: canlı yol
          // yalnız `precondition.status == derived` olan hareketler için
          // açılır (K8'in ürün tarafındaki karşılığı — kimlik kapısı
          // olmayan bir harekette sayım salınımı sayardı, G-043).
          floatingActionButton: loaded.liveConfig == null
              ? null
              : FloatingActionButton.extended(
                  key: ProgressScreen.liveFabKey,
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          LiveSessionScreen(config: loaded.liveConfig!),
                    ),
                  ),
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text(LiveStrings.title),
                ),
        );
      },
    );
  }
}
