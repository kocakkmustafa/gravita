import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show AssetBundle;
import 'package:gravita_engine/gravita_engine.dart';
import 'package:path_provider/path_provider.dart';

import 'content_failure.dart';
import 'library_model.dart';
import 'live_session.dart';

/// İçerik + kalıcılık KABLOLAMASI — kabuğun motora bakan tek yüzü.
///
/// **Neden burada:** motor (`gravita_engine`) saf Dart'tır ve dosya sistemini de
/// asset bundle'ı da bilmez. Bu sınıf "nereden okunur" sorusunu cevaplar, "ne
/// anlama gelir" sorusuna KARIŞMAZ — türetme motorun `LessonSurface.deriveAll`
/// fonksiyonunda, tek evde (G-079 dersi: aynı ölçümün iki evi tutarsızlaşır).
///
/// `JsonlSessionStore` bir `File` alır; `path_provider` çağrısı BU katmanda
/// kalır. Terfi-arayüzünün 1. şartı budur (`docs/design/SESSION-STORE-DELTA.md`
/// §0): depo saf Dart, KABLOLAMA Flutter.
///
/// ## Katalog yüklemesi neden TEMBEL (2026-08-06 terfi turu)
///
/// Kütüphane 2 hareketten 31'e çıktı. Eski hâl açılışta HER hareketin katalog
/// dosyasını açıyordu — 31 JSON ayrıştırması, hepsi bir LİSTE ekranı çizmek
/// için. Liste ekranının ihtiyacı olan her alan (`displayName`, `equipment`,
/// rozet, dürüstlük kutusu) zaten `library.json`'da ÜRETİLMİŞ hâlde duruyor
/// (`tools/promote_library.py`), yani katalog yalnız ÖLÇÜM tarafı için gerekli.
///
/// Bu yüzden açılışta yalnız **kursu olan** hareketlerin kataloğu okunur
/// (`LessonSurface.deriveAll`in ihtiyacı bu) — bugün bir tane. Kalanı hareket
/// sayfası açıldığında [catalogFor] ile gelir.
/// Kabuğun ayrıştırabileceği `library.json` şema sürümü.
const int _librarySchemaVersion = 1;

final class ContentRepository {
  ContentRepository._({
    required this.library,
    required this.catalogue,
    required this.lessonSurfaces,
    required Map<String, MovementConfig> eagerCatalog,
    required AssetBundle bundle,
  })  : _catalog = eagerCatalog,
        _bundle = bundle;

  /// İçeriği asset bundle'dan yükler.
  ///
  /// Katalog dosyası ADRESİ hareketin kendi `wave` alanından kurulur —
  /// `content/catalog/w1` SABİTLEMEK, G-099'da üç yerde birden bulunan
  /// dalga-körlüğünün aynısı olurdu. Dosya bundle'da yoksa yükleme GÜRÜLTÜLÜ
  /// patlar; sessizce boş liste dönmek dersleri yüzeyden sessizce düşürürdü.
  static Future<ContentRepository> load(AssetBundle bundle) async {
    final Map<String, dynamic> lib =
        (jsonDecode(await bundle.loadString('content/library.json')) as Map)
            .cast<String, dynamic>();

    // ⚠️ `schemaVersion` bir ÖKSÜZ ANAHTARdı: dosyada duruyordu, kimse
    // okumuyordu (J-129 kapısı yakaladı). Bir sürüm işareti okunmadığı sürece
    // işaret değildir — şema değişip kabuk eski varsayımla ayrıştığında
    // sessizce yanlış ayrıştırırdı. Artık ÖNCE bu doğrulanıyor: uyuşmazlık
    // GÜRÜLTÜLÜ patlar ve tipli içerik-hatası ekranına gider.
    final int schema = (lib['schemaVersion'] as num?)?.toInt() ?? 0;
    if (schema != _librarySchemaVersion) {
      throw StateError(
          'library.json şema sürümü $schema; bu kabuk '
          '$_librarySchemaVersion bekliyor. İçerik ile kod ayrışmış.');
    }

    final List<Map<String, dynamic>> raw =
        (lib['movements'] as List<dynamic>).cast<Map<String, dynamic>>();

    final Map<String, MovementConfig> eager = <String, MovementConfig>{};
    for (final Map<String, dynamic> m in raw) {
      // Kursu olmayan hareketin DERSİ de yoktur (kütüphane kapısı K1/K10);
      // `deriveAll` ona bakmaz, o yüzden kataloğu şimdi okunmaz.
      if (((m['courses'] as List<dynamic>?) ?? const <dynamic>[]).isEmpty) {
        continue;
      }
      final String catalogId = (m['catalogId'] ?? m['id']) as String;
      eager[catalogId] = await _loadCatalog(bundle, m, catalogId);
    }

    return ContentRepository._(
      library: lib,
      bundle: bundle,
      eagerCatalog: eager,
      catalogue: LibraryCatalogue(
        movements: raw
            .map((Map<String, dynamic> m) => MovementEntry.fromJson(m))
            .toList(growable: false),
        exclusions: ExclusionsPage.parse(
            await bundle.loadString('content/exclusions.page.json')),
        skillTrees: SkillTreeIndex.parse(
            await bundle.loadString('content/skill-trees.index.json')),
      ),
      lessonSurfaces: LessonSurface.deriveAll(
        library: lib,
        catalogFor: (String id) => eager[id]!,
      ),
    );
  }

  static Future<MovementConfig> _loadCatalog(
      AssetBundle bundle, Map<String, dynamic> movement, String catalogId) async {
    final String? wave = movement['wave'] as String?;
    if (wave == null) {
      throw StateError(
          'library.json: ${movement['id']} `wave` bildirmiyor — katalog adresi '
          'kurulamaz. Dalga beyanı zorunlu.');
    }
    return MovementConfig.parse(await bundle
        .loadString('content/catalog/${wave.toLowerCase()}/$catalogId.json'));
  }

  final Map<String, dynamic> library;

  /// Kütüphane yüzeyinin okuduğu tipli hâl (31 hareket + "Neden yok?").
  final LibraryCatalogue catalogue;

  /// Yüzeyin BUGÜN bildiği dersler — kilitliler DAHİL (M-F-168 kural 2).
  final List<LessonSurface> lessonSurfaces;

  final Map<String, MovementConfig> _catalog;
  final AssetBundle _bundle;

  /// Açılışta okunmuş config'ler — kursu olan hareketler.
  ///
  /// ⚠️ Adı bilerek `movementConfigs` DEĞİL: eski ad "hepsi" diye okunuyordu
  /// ve tembel yüklemeyle birlikte o okuma YANLIŞ olurdu. Bir alanın kapsamı
  /// daraldığında adının da daralması gerekir, yoksa çağıran taraf eski
  /// varsayımla devam eder.
  List<MovementConfig> get eagerlyLoadedConfigs =>
      List<MovementConfig>.unmodifiable(_catalog.values);

  MovementConfig? loadedCatalog(String catalogId) => _catalog[catalogId];

  /// Bir hareketin ölçüm config'i — gerekiyorsa ŞİMDİ okunur ve saklanır.
  ///
  /// Hareket sayfası bunu çağırır: form hataları, ipuçları ve kamera kurulumu
  /// ölçüm tarafındadır ve `library.json`'a kopyalanmadı (kopyalansa iki ev
  /// olurdu — G-079).
  Future<MovementConfig> catalogFor(String movementId) async {
    final MovementConfig? cached = _catalog[movementId];
    if (cached != null) return cached;
    final Map<String, dynamic> m = (library['movements'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((Map<String, dynamic> e) => e['id'] == movementId,
            orElse: () => throw StateError(
                'library.json: `$movementId` diye bir hareket YOK'));
    final MovementConfig config = await _loadCatalog(
        _bundle, m, (m['catalogId'] ?? m['id']) as String);
    _catalog[config.id] = config;
    return config;
  }

  /// Canlı seansın koşabileceği hareket — İKİ bağımsız iddia birlikte.
  ///
  /// `library.json` "live" diyor (kütüphane kapısı K8/K10 orada denetlendi) VE
  /// kataloğun kimlik ön koşulu gerçekten `derived`. Tek başına ilki bir
  /// BEYAN, tek başına ikincisi bir ÖLÇÜM; ikisini birden istemek, birinin
  /// diğerinden sessizce ayrışmasını yüzeyde yakalar. Buton yalnız ikisi de
  /// tuttuğunda çizilir (ölü buton yasağının çalışma-zamanı hâli).
  MovementConfig? get liveConfig {
    for (final MovementEntry m in catalogue.movements) {
      if (!m.isLive) continue;
      final MovementConfig? c = _catalog[m.catalogId];
      if (c != null && c.preconditionDerived) return c;
    }
    return null;
  }

  /// DERS seansı geçmişi. `ProgressSummary` YALNIZ bunu okur.
  static Future<SessionStore> openSessionStore() async {
    final Directory dir = await getApplicationSupportDirectory();
    return JsonlSessionStore(File('${dir.path}/sessions.jsonl'));
  }

  /// ⭐ SERBEST seans kovası — AYRI DOSYA, koordinatör hükmü (G-132, 08-07).
  ///
  /// **Hüküm:** *"seans, başlatıldığı DERSİN kaydına yazılır"* — gerekçesi
  /// ürünün kendi sınırı: **7 bileşen ayrıdır, asla toplanmaz.** Farklı
  /// `focus`lu dersleri (rep sayımı ↔ derinlik ↔ tempo) tek trendde toplamak,
  /// "tek genel skor yok" yasağının ZAMAN eksenindeki hâli olurdu.
  ///
  /// **Dar-kapsam şartı ölçüldü ve DEVREDE:** hükmün *"ders bağlamı dışında
  /// bir seans yolu VARSA ayrı kovaya yazılır"* maddesi bu üründe geçerli —
  /// çünkü bugün `LiveSessionScreen`'e **tek giriş** kabuktaki seans düğmesi
  /// ve o giriş HAREKET düzeyinde (`gravita_app.dart`). Ders bağlamlı bir
  /// başlatma yolu HENÜZ YOK (kurs sayfası inşa edilmedi). Yani bugün her
  /// seans serbest seanstır.
  ///
  /// Bu yüzden ayrı DOSYA: `ProgressSummary` bu kovayı hiç görmez, serbest
  /// seanslar ders trendine KARIŞAMAZ. Karışma "unutulmadı" diye değil,
  /// okuyucu o dosyayı hiç açmadığı için imkânsız.
  ///
  /// ⚠️ `SessionRecord.lessonId` burada `movement:<id>` biçiminde bir HAREKET
  /// anahtarı taşır. Alan adı "lesson" diyor ama bu kovada ders yok; ad
  /// çekirdeğin ve değiştirilemez, o yüzden anlam BURADA beyan ediliyor.
  /// Kovaları karıştıran biri, bu ön eki görünce durur.
  /// Geçmişin BÜTÜNLÜK hükmü — **iki kovadan da** sorulur.
  ///
  /// ## ⭐ Neden ekrandan ayrı (G-211)
  ///
  /// `buildFreeSessionRecord` ve `buildFinishedState` ile aynı gerekçe:
  /// *"kullanıcıya geçmişinin eksik olduğunu ne zaman söyleriz"* bir ÜRÜN
  /// kararıdır, bir çizim değil. `_ProgressTabState` içinde kaldığı sürece
  /// yalnız **kabuğu render ederek** sınanabiliyordu ve o yol bugün `B5`
  /// (`google_fonts` → `fonts.gstatic.com`) yüzünden testte KAPALI.
  /// ⇒ Karar buraya taşındı; artık saf Dart'ta, gerçek dosyalarla sınanıyor.
  ///
  /// ## Kapattığı kusur
  ///
  /// Sayım **yalnız DERS kovasından** okunuyordu. Serbest kova `recent()` ile
  /// okunup **bütünlüğü hiç sorulmuyordu** — oysa bu üründe *"bugün her seans
  /// serbest seanstır"* (ders bağlamlı başlatma yolu YOK). Yani denetim,
  /// bugün her zaman BOŞ olan dosyayı bekliyordu; kullanıcının bütün verisini
  /// tutan dosya DENETİMSİZDİ.
  ///
  /// > ***BİR BÜTÜNLÜK DENETİMİ YANLIŞ DOSYAYA BAKIYORSA, DENETİM DEĞİL
  /// > TESELLİDİR.***
  ///
  /// Kayıp sayıları TOPLANIR: kullanıcının tek bir geçmişi var, iki dosyası
  /// olması bizim iç ayrımımız. "3 kayıp" derken hangi kovada olduğunu
  /// söylemiyoruz çünkü kullanıcı için fark etmez — kaybın KENDİSİ önemli.
  static Future<HistoryStatus> readHistoryStatus({
    required SessionStore lessons,
    required SessionStore free,
  }) async {
    try {
      final int kayip =
          await lessons.unreadableRecords() + await free.unreadableRecords();
      return kayip > 0 ? HistoryPartial(kayip) : const HistoryOk();
    } on Object catch (e) {
      return HistoryUnavailable(e.toString());
    }
  }

  static Future<SessionStore> openFreeSessionStore() async {
    final Directory dir = await getApplicationSupportDirectory();
    return JsonlSessionStore(File('${dir.path}/free_sessions.jsonl'));
  }

  /// Serbest seans kaydının hareket anahtarı. Gerçek tanım
  /// `live_session.dart`ta (kayıt kararıyla AYNI evde); burası yalnız
  /// okuma tarafının erişimi için delege ediyor — iki ayrı ön ek üretmek,
  /// kovayı yazanla okuyanı sessizce ayırırdı.
  static String freeSessionKey(String movementId) =>
      freeSessionKeyFor(movementId);
}
