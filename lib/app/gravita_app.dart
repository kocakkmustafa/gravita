import 'package:flutter/material.dart';
import 'package:gravita_engine/gravita_engine.dart';

import 'content_failure.dart';
import 'content_failure_screen.dart';
import 'content_repository.dart';
import 'progress_view.dart';

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
        // Tema BİLEREK varsayılan: renk/tipografi tasarım turunun işi
        // (M-F-168 sınır beyanı). Burada "seçilmiş" gibi görünen bir tema
        // bırakmak, tasarımın devralacağı yapıyı gizlerdi.
        home: const ProgressScreen(),
      );
}

/// Yükleme sonucu — İKİ başarısızlık AYRI taşınır.
///
/// Tek bir `Object? error` alanı bu ayrımı yok ederdi: geçmiş hatası bütün
/// uygulamayı bloklardı, ya da daha kötüsü sessizce boş geçmiş gösterirdi
/// (bkz. [HistoryFailure] gerekçesi).
final class _Loaded {
  const _Loaded({required this.summary, this.historyFailure});
  final ProgressSummary summary;
  final HistoryFailure? historyFailure;
}

/// İlerleme ekranı — veriyi toplar, YAPIyı [ProgressView]'a bırakır.
class ProgressScreen extends StatefulWidget {
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
    // YUTULMAZ — `historyFailure` yüzeye taşınır ve orada BEYAN EDİLİR.
    // `catch` içinde boş liste dönüp devam etmek, kullanıcının geçmişini
    // "yok" ilan etmek olurdu (Gravita deltası, `content_failure.dart`).
    List<SessionRecord> records = const <SessionRecord>[];
    HistoryFailure? historyFailure;
    try {
      records = await (await ContentRepository.openSessionStore()).recent();
    } on Object catch (e) {
      historyFailure = HistoryFailure(e.toString());
    }

    return _Loaded(
      summary: ProgressSummary.build(
        lessonSurfaces: content.lessonSurfaces,
        records: records,
      ),
      historyFailure: historyFailure,
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
            historyFailure: loaded.historyFailure,
          ),
        );
      },
    );
  }
}
