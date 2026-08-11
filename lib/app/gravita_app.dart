import 'package:flutter/material.dart';
import 'package:gravita_engine/gravita_engine.dart';

import 'content_failure.dart';
import 'content_failure_screen.dart';
import 'content_repository.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'library_strings.dart';
import 'live_session_screen.dart';
import 'onboarding_screen.dart';
import 'onboarding_store.dart';
import 'profile_screen.dart';
import 'progress_strings.dart';
import 'progress_view.dart';
import 'theme.dart';

/// Uygulama kabuğu.
///
/// ## 2026-08-06: TEK yüzeyden dört sekmeye
///
/// Bu dosyanın önceki hâli tek bir `ProgressScreen` açıyordu ve gerekçesi
/// dürüsttü: *"yüzey, arkasında ÇALIŞAN ölçüm olan kadarıyla açılıyor."*
/// O gerekçe bir yüzeyi değil bir BUTONU koruyordu — kullanıcı 31 hareketlik
/// kataloğu hiç göremiyordu, çünkü görecek ekran yoktu. Ölü buton yasağı
/// "ekran yapma" demiyor; "arkasında bir şey olmayan giriş çizme" diyor.
///
/// Şimdi dört sekme var ve HER BİRİNİN arkasında gerçek veri duruyor:
/// Today (ne açık/ne kuyrukta) · Library (31 hareket + "Neden yok?") ·
/// Progress (gerçek geçmiş) · Profile (sınırlar + veri yeri). Ortadaki seans
/// düğmesi hâlâ NÖBETLİ: canlı yol yoksa ÇİZİLMEZ.
class GravitaApp extends StatelessWidget {
  const GravitaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Gravita',
        // M-F-282 giydirme turu: tema design panel v1'den (`theme.dart`).
        theme: GravitaTheme.light,
        home: const GravitaRoot(),
      );
}

/// İçeriğin TEK kapısı — uygulamanın ürün yolu buradan geçer.
///
/// ⚠️ Bu widget'ın ayrı olmasının sebebi test edilebilirlik DEĞİL, tersi:
/// testler ürünün KENDİ kapısını pump edebilsin diye. Önceki turda içerik
/// yükleme `ProgressScreen`in içindeydi ve bir test onun KOPYASINI (`_Probe`)
/// sınıyordu — G-079'un "iki ev tutarsızlaşır" dersi. Kapı tek olunca kopya
/// yazmaya gerek kalmıyor.
class GravitaRoot extends StatefulWidget {
  const GravitaRoot({super.key});

  @override
  State<GravitaRoot> createState() => _GravitaRootState();
}

class _GravitaRootState extends State<GravitaRoot> {
  Future<ContentRepository>? _future;
  Future<bool>? _onboardingDone;
  bool _onboardingJustCompleted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= ContentRepository.load(DefaultAssetBundle.of(context));
    // ⚠️ `path_provider` testte YOK (Gravita deltası, `ProgressTab._load`
    // ile AYNI olgu) — burada da AYNI kural: bir depolama ARIZASI birincil
    // içerik yolunu BLOKLAMAZ. Fark: geçmiş için "okunamadı" dürüstçe
    // BEYAN edilir (ekranda görünür), onboarding için BEYAN edilecek bir
    // yüzey yok — tek seçenek geçmek ya da sonsuza dek döndürmek, ikincisi
    // gerçek bir kullanıcıyı depolama arızasında UYGULAMAYA HİÇ SOKMAZ.
    // Bu yüzden BURADA fail-open: okunamıyorsa TAMAMLANMIŞ sayılır.
    _onboardingDone ??= OnboardingStore.open()
        .then((OnboardingStore s) => s.isComplete())
        .catchError((Object _) => true);
  }

  Future<void> _completeOnboarding() async {
    await (await OnboardingStore.open()).markComplete();
    if (!mounted) return;
    setState(() => _onboardingJustCompleted = true);
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<ContentRepository>(
        future: _future,
        builder: (BuildContext context,
            AsyncSnapshot<ContentRepository> snapshot) {
          // İçerik hatası TİPLİ ekrana gider — ham `StateError` gövdesi
          // kullanıcıya gösterilmez ("çökmüyor" ≠ "dürüstçe açıklıyor").
          if (snapshot.hasError) {
            return ContentFailureScreen(
              failure: ContentFailure.from(snapshot.error!),
              onRetry: () async => setState(() => _future =
                  ContentRepository.load(DefaultAssetBundle.of(context))),
            );
          }
          final ContentRepository? content = snapshot.data;
          if (content == null) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          // ⭐ İçerik yüklendi AMA onboarding tamamlanmadıysa kabuk hiç
          // ÇİZİLMEZ — ilk açılışın TEK kapısı burası (G-079 dersinin
          // aynısı: kapı iki yerde durursa bir gün tutarsızlaşır).
          if (_onboardingJustCompleted) return GravitaShell(content: content);
          return FutureBuilder<bool>(
            future: _onboardingDone,
            builder:
                (BuildContext context, AsyncSnapshot<bool> onboardingSnap) {
              if (!onboardingSnap.hasData) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              if (onboardingSnap.data == true) {
                return GravitaShell(content: content);
              }
              return OnboardingFlow(onComplete: _completeOnboarding);
            },
          );
        },
      );
}

/// Dört sekme + nöbetli seans düğmesi.
class GravitaShell extends StatefulWidget {
  const GravitaShell({required this.content, super.key});

  /// Seans girişinin nöbet anahtarı. Testler bu düğmenin VARLIĞINI ve
  /// YOKLUĞUNU ayrı ayrı sınıyor (M-F-194 pozitif-ikiz kuralı).
  static const Key startSessionKey = Key('shell.startSession');
  static const Key navBarKey = Key('shell.nav');

  final ContentRepository content;

  @override
  State<GravitaShell> createState() => _GravitaShellState();
}

class _GravitaShellState extends State<GravitaShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final MovementConfig? live = widget.content.liveConfig;
    return Scaffold(
      // IndexedStack: sekme değişince ekranın DURUMU (arama metni, kaydırma
      // konumu) kaybolmaz. Bedeli, dört sekmenin de inşa edilmesi — testler
      // bu yüzden "görünüyor mu"yu değil "doğru sekmede mi"yi sormalı.
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: <Widget>[
            HomeScreen(
              content: widget.content,
              onBrowseLibrary: () => setState(() => _index = 1),
            ),
            LibraryScreen(content: widget.content),
            ProgressTab(content: widget.content),
            ProfileScreen(content: widget.content),
          ],
        ),
      ),
      // ⚠️ `centerDocked` DEĞİL. Simülatörde ölçüldü: `centerDocked` bir
      // `BottomAppBar`ın çentiğine oturmak için tasarlanmış; `NavigationBar`
      // ile birlikte düğme çubuğun ÜSTÜNE BİNİYOR ve "Library"/"Progress"
      // etiketlerini kapatıyordu. `centerFloat` çubuğun hemen üstünde durur.
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      // ⚠️ "Ölü buton YOK" kuralının çalışma-zamanı hâli: seans düğmesi ancak
      // İKİ bağımsız iddia birlikte tuttuğunda çizilir — kütüphane "live"
      // diyor VE kataloğun kimlik ön koşulu gerçekten `derived`
      // (`ContentRepository.liveConfig`). Biri ötekinden ayrışırsa buton
      // KAYBOLUR, yanlış çalışmaz.
      floatingActionButton: live == null
          ? null
          : FloatingActionButton.extended(
              key: GravitaShell.startSessionKey,
              // ⚠️ Renkler AÇIKÇA veriliyor. Material 3'ün varsayılanı
              // `colorScheme.primaryContainer` — tohumlanmış paletten gelen
              // SOLGUN pembe; simülatörde ürünün TEK birincil eylemi arka
              // planda kaybolmuş görünüyordu. Vurgu rengi burada "ölçülen
              // kriter / kapı / mühür" kuralının dışında bir dördüncü iş
              // yapmıyor: bu düğme canlı ölçümün TEK girişi.
              backgroundColor: GravitaColors.accent,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => LiveSessionScreen(config: live),
                ),
              ),
              icon: const Icon(Icons.videocam_outlined),
              label: const Text(LibraryStrings.startSession),
            ),
      bottomNavigationBar: NavigationBar(
        key: GravitaShell.navBarKey,
        selectedIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        backgroundColor: GravitaColors.page,
        indicatorColor: GravitaColors.accent.withValues(alpha: 0.1),
        destinations: const <NavigationDestination>[
          NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: LibraryStrings.tabToday),
          NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: LibraryStrings.tabLibrary),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: LibraryStrings.tabProgress),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: LibraryStrings.tabProfile),
        ],
      ),
    );
  }
}

/// İlerleme sekmesi — İÇERİĞİ almış, yalnız GEÇMİŞİ kendi yükler.
///
/// İçerik hatası bütün uygulamayı bloklar ([GravitaRoot] halleder); geçmiş
/// hatası BLOKLAMAZ ama YUTULMAZ da — `historyStatus` yüzeye taşınır ve orada
/// BEYAN EDİLİR (Gravita deltası, `content_failure.dart`). `catch` içinde boş
/// liste dönüp devam etmek, kullanıcının geçmişini "yok" ilan etmek olurdu.
class ProgressTab extends StatefulWidget {
  const ProgressTab({required this.content, super.key});

  final ContentRepository content;

  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> {
  late final Future<
      ({
        ProgressSummary summary,
        HistoryStatus status,
        List<SessionRecord> free
      })> _future = _load();

  Future<
      ({
        ProgressSummary summary,
        HistoryStatus status,
        List<SessionRecord> free
      })> _load() async {
    List<SessionRecord> records = const <SessionRecord>[];
    // ⭐ SERBEST kova AYRI okunuyor ve `ProgressSummary`'ye HİÇ verilmiyor
    // (G-132: farklı `focus`lu dersler tek trendde toplanamaz). Ama ekranda
    // GÖRÜNÜYOR — çünkü okunmadığı sürece kullanıcı gerçek bir seans yapıp
    // buraya geldiğinde ekran ona "Not started" diyordu (J-124 sınıfı:
    // eksik bilgi değil, YANLIŞ bilgi).
    List<SessionRecord> free = const <SessionRecord>[];
    HistoryStatus status = const HistoryOk();
    try {
      final SessionStore store = await ContentRepository.openSessionStore();
      records = await store.recent();
      free = await (await ContentRepository.openFreeSessionStore()).recent();
      // Çekirdek 0.10.0: kayıp satır sayısı ÖLÇÜLEBİLİR. Aynı depodan okunur
      // ki sayılar ile kayıp aynı ana ait olsun.
      final int unreadable = await store.unreadableRecords();
      status = unreadable > 0 ? HistoryPartial(unreadable) : const HistoryOk();
    } on Object catch (e) {
      status = HistoryUnavailable(e.toString());
    }
    return (
      summary: ProgressSummary.build(
        lessonSurfaces: widget.content.lessonSurfaces,
        records: records,
      ),
      status: status,
      free: free,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        ({
          ProgressSummary summary,
          HistoryStatus status,
          List<SessionRecord> free
        })>(
      future: _future,
      builder: (BuildContext context,
          AsyncSnapshot<
                  ({
                    ProgressSummary summary,
                    HistoryStatus status,
                    List<SessionRecord> free
                  })>
              s) {
        final ({
          ProgressSummary summary,
          HistoryStatus status,
          List<SessionRecord> free
        })? data = s.data;
        if (data == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text(ProgressStrings.measuredSection)),
          body: ProgressView(
            summary: data.summary,
            historyStatus: data.status,
            freeSessions: data.free,
          ),
        );
      },
    );
  }
}
