import 'package:flutter/material.dart';
import 'package:gravita_engine/gravita_engine.dart';

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

/// İlerleme ekranı — veriyi toplar, YAPIyı [ProgressView]'a bırakır.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  Future<ProgressSummary>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load(DefaultAssetBundle.of(context));
  }

  Future<ProgressSummary> _load(AssetBundle bundle) async {
    final ContentRepository content = await ContentRepository.load(bundle);
    final SessionStore store = await ContentRepository.openSessionStore();
    return ProgressSummary.build(
      lessonSurfaces: content.lessonSurfaces,
      records: await store.recent(),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Gravita')),
        body: FutureBuilder<ProgressSummary>(
          future: _future,
          builder: (BuildContext context,
              AsyncSnapshot<ProgressSummary> snapshot) {
            // Üç durumun ÜÇÜ de var. Hata durumunu atlamak, içerik yüklenmezse
            // BOŞ bir ilerleme ekranı göstermek olurdu — "hiç çalışmadın"
            // diyen bir yalan. Metin ham: tasarım turu biçimlendirecek.
            if (snapshot.hasError) {
              return Center(child: Text('Could not load: ${snapshot.error}'));
            }
            final ProgressSummary? summary = snapshot.data;
            if (summary == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return ProgressView(summary: summary);
          },
        ),
      );
}
