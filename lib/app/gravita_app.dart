import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gravita_engine/gravita_engine.dart';

import 'app_locale.dart';
import 'account_connection.dart';
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
  const GravitaApp({super.key, this.accountConnection});

  final AccountConnection? accountConnection;

  @override
  Widget build(BuildContext context) {
    final AccountConnection? account = accountConnection;
    Widget accountApp(String? userId) => AccountScope(
      connection: account,
      currentUserId: userId,
      child: MaterialApp(
        key: ValueKey<String>('gravita-account-${userId ?? 'signed-out'}'),
        title: 'Gravita',
        // M-F-282 giydirme turu: tema design panel v1'den (`theme.dart`).
        theme: GravitaTheme.light,
        builder: (BuildContext context, Widget? child) =>
            AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.dark,
              child: child ?? const SizedBox.shrink(),
            ),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        debugShowCheckedModeBanner: false,
        home: const GravitaRoot(),
      ),
    );
    if (account == null) return accountApp(null);
    return ValueListenableBuilder<String?>(
      valueListenable: account.userId,
      builder: (_, userId, __) => accountApp(userId),
    );
  }
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
    // ⚠️ DEPOLAMA ARIZASINDA ONBOARDING **GÖSTERİLİR** — koordinatör hükmü
    // (2026-08-12, G-183/④). Bu satır önceden `=> true` idi (fail-open:
    // okunamıyorsa TAMAMLANMIŞ say) ve gerekçesi *"arıza kullanıcıyı
    // uygulamaya hiç sokmasın"*dı. Ölçüm o gerekçenin bedelini adlandırdı
    // (G-181): O2'nin gösterdiği `safetyDisclaimer` metni `lib/`de BAŞKA
    // HİÇBİR YERDE geçmiyor, yani o dalda kullanıcı güvenlik uyarısını ve
    // açık onayı HİÇ görmüyordu. Ürünün kendi sert kuralı ise "güvenlik
    // kırpılmaz … + açık onay" diyor:
    //
    //   > Bir kuralı, en çok ihtiyaç duyulan anda (arıza) askıya alan
    //   > tasarım, o kuralı taşımıyordur.
    //
    // Yeni davranış: arızada onboarding gösterilir, yalnız KALICILAŞTIRILMAZ
    // (bkz. [_completeOnboarding]) — her açılışta tekrar sorar. Tekrar
    // sorması KABUL EDİLMİŞ maliyettir, gizlenecek kusur değil.
    //
    // ✅ Yan fayda: `OnboardingStore.isComplete()` bozuk/eksik dosyada zaten
    // `false` (= göster) dönüyordu; bu satır `true` (= atla) dönüyordu.
    // Aynı arızanın iki yüzü ZIT yönlere düşüyordu; artık ikisi de GÖSTER.
    _onboardingDone ??= OnboardingStore.open()
        .then((OnboardingStore s) => s.isComplete())
        .catchError((Object _) => false);
  }

  /// Onay alındı: kabuğa geç. Kalıcılaştırma **deneyen ama zorunlu olmayan**
  /// bir adımdır.
  ///
  /// ⚠️ Yazma hatası kullanıcıyı onboarding'de KİLİTLEYEMEZ. Okuma tarafı
  /// artık fail-closed (arıza → göster) olduğu için, yazma tarafı da
  /// yutulmazsa bozuk depolamalı bir cihazda kullanıcı onayı verir ve
  /// hiçbir yere gidemezdi — kapının iki yarısı birlikte tasarlanır.
  /// Bedeli bilinçli: bit yazılamadıysa akış bir sonraki açılışta TEKRAR
  /// sorar (G-183 hükmünün "kalıcılaştırılmaz" yarısı).
  Future<void> _completeOnboarding() async {
    try {
      await (await OnboardingStore.open()).markComplete();
    } on Object {
      // Yutulan tek şey KALICILIK; onayın kendisi yutulmuyor.
    }
    if (!mounted) return;
    setState(() => _onboardingJustCompleted = true);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ContentRepository>(
    future: _future,
    builder: (BuildContext context, AsyncSnapshot<ContentRepository> snapshot) {
      // İçerik hatası TİPLİ ekrana gider — ham `StateError` gövdesi
      // kullanıcıya gösterilmez ("çökmüyor" ≠ "dürüstçe açıklıyor").
      if (snapshot.hasError) {
        return ContentFailureScreen(
          failure: ContentFailure.from(snapshot.error!),
          onRetry: () async => setState(
            () => _future = ContentRepository.load(
              DefaultAssetBundle.of(context),
            ),
          ),
        );
      }
      final ContentRepository? content = snapshot.data;
      if (content == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      // ⭐ İçerik yüklendi AMA onboarding tamamlanmadıysa kabuk hiç
      // ÇİZİLMEZ — ilk açılışın TEK kapısı burası (G-079 dersinin
      // aynısı: kapı iki yerde durursa bir gün tutarsızlaşır).
      if (_onboardingJustCompleted) return GravitaShell(content: content);
      return FutureBuilder<bool>(
        future: _onboardingDone,
        builder: (BuildContext context, AsyncSnapshot<bool> onboardingSnap) {
          if (!onboardingSnap.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
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

  Future<void> _openLiveSession(MovementConfig config) async {
    final MovementConfig? startable = widget.content.startableConfigFor(
      config.id,
    );
    if (!identical(startable, config)) return;
    final guard = AccountScope.maybeOf(context)?.connection?.requirePaidAccess;
    if (guard != null && !await guard(context)) return;
    if (!mounted) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LiveSessionScreen(
          config: config,
          accountUserId: AccountScope.maybeOf(context)?.currentUserId,
        ),
      ),
    );
  }

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
              onStartSession: _openLiveSession,
            ),
            LibraryScreen(
              content: widget.content,
              onStartSession: _openLiveSession,
            ),
            ProgressTab(
              content: widget.content,
              accountUserId: AccountScope.maybeOf(context)?.currentUserId,
            ),
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
              // yapmıyor: bu düğme canlı ölçümün hızlı girişidir.
              backgroundColor: GravitaColors.accent,
              foregroundColor: Colors.white,
              onPressed: () => _openLiveSession(live),
              icon: const Icon(Icons.videocam_outlined),
              label: Text(
                localized(context, LibraryStrings.startSession, 'Başla'),
              ),
            ),
      bottomNavigationBar: NavigationBar(
        key: GravitaShell.navBarKey,
        selectedIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        backgroundColor: GravitaColors.page,
        indicatorColor: GravitaColors.accent.withValues(alpha: 0.1),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today),
            label: localized(context, LibraryStrings.tabToday, 'Bugün'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view),
            label: localized(context, LibraryStrings.tabLibrary, 'Kütüphane'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: localized(context, LibraryStrings.tabProgress, 'İlerleme'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: localized(context, LibraryStrings.tabProfile, 'Profil'),
          ),
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
  const ProgressTab({required this.content, this.accountUserId, super.key});

  final ContentRepository content;
  final String? accountUserId;

  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> {
  late final Future<
    ({ProgressSummary summary, HistoryStatus status, List<SessionRecord> free})
  >
  _future = _load();

  Future<
    ({ProgressSummary summary, HistoryStatus status, List<SessionRecord> free})
  >
  _load() async {
    List<SessionRecord> records = const <SessionRecord>[];
    // ⭐ SERBEST kova AYRI okunuyor ve `ProgressSummary`'ye HİÇ verilmiyor
    // (G-132: farklı `focus`lu dersler tek trendde toplanamaz). Ama ekranda
    // GÖRÜNÜYOR — çünkü okunmadığı sürece kullanıcı gerçek bir seans yapıp
    // buraya geldiğinde ekran ona "Not started" diyordu (J-124 sınıfı:
    // eksik bilgi değil, YANLIŞ bilgi).
    List<SessionRecord> free = const <SessionRecord>[];
    HistoryStatus status = const HistoryOk();
    try {
      final SessionStore store = await ContentRepository.openSessionStore(
        accountUserId: widget.accountUserId,
      );
      records = await store.recent();
      final SessionStore freeStore =
          await ContentRepository.openFreeSessionStore(
            accountUserId: widget.accountUserId,
          );
      free = await freeStore.recent();
      // Çekirdek 0.10.0: kayıp satır sayısı ÖLÇÜLEBİLİR. Aynı depodan okunur
      // ki sayılar ile kayıp aynı ana ait olsun.
      //
      // ⭐ G-211 — İKİ KOVA DA SAYILIR. Buradaki sayım YALNIZ ders kovasını
      // okuyordu; serbest kova `recent()` ile okunup **bütünlüğü hiç
      // sorulmuyordu**. Oysa bu üründe *"bugün her seans serbest seanstır"*
      // (`content_repository.dart`: ders bağlamlı başlatma yolu YOK) ⇒ kontrol
      // BUGÜN HER ZAMAN BOŞ olan dosyayı bekliyor, kullanıcının bütün verisini
      // tutan dosya ise **denetimsizdi**. Bozulan bir serbest seans satırı
      // sessizce düşer, yüzey toplamı yine kendinden emin gösterirdi.
      //
      // ⚠️ Metin taramalı kapı bunu göremezdi ve görmedi: `shell_contract_test`
      // *"`unreadableRecords()` üründe TÜKETİLİYOR"* diye kaynakta dizgi
      // arıyor — **çağrılıyor mu** sorusunu ölçüyor, **hangi depoda** sorusunu
      // ölçemiyor. (Bu hattın `M-F-598` ailesi: dizgi kapısı niyeti ölçer,
      // doğruluğu değil.)
      //
      // Hüküm `ContentRepository.readHistoryStatus`ta ve SAF — ekran onu
      // SÜRER, taşımaz (`buildFreeSessionRecord`/`buildFinishedState` emsali).
      status = await ContentRepository.readHistoryStatus(
        lessons: store,
        free: freeStore,
      );
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
        List<SessionRecord> free,
      })
    >(
      future: _future,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<
              ({
                ProgressSummary summary,
                HistoryStatus status,
                List<SessionRecord> free,
              })
            >
            s,
          ) {
            final ({
              ProgressSummary summary,
              HistoryStatus status,
              List<SessionRecord> free,
            })?
            data = s.data;
            if (data == null) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: const Text(ProgressStrings.measuredSection),
              ),
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
