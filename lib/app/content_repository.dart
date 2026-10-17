import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show AssetBundle;
import 'package:gravita_engine/gravita_engine.dart';
import 'package:motion_content/motion_content.dart';
import 'package:path_provider/path_provider.dart';
import 'account_data_directory.dart';
import 'account_session_store.dart';
import 'account_store_epoch.dart';
import 'calisthenics_course.dart';
import 'motion_observation.dart';
import 'calisthenics_progress.dart';
import 'foundation_coverage.dart';
import 'flutter_bundle_content_asset_reader.dart';

import 'content_failure.dart';
import 'library_model.dart';
import 'live_session.dart';
import 'program/program_model.dart';

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
/// (`LessonSurface.deriveAll`in ihtiyacı bu) — bugün iki tane. Kalanı hareket
/// sayfası açıldığında [catalogFor] ile gelir.
/// Kabuğun ayrıştırabileceği `library.json` şema sürümü.
const int _librarySchemaVersion = 1;
const String _calisthenicsAssetPath = 'content/courses/calisthenics.v1.json';
const String _calisthenicsIntegrityManifestPath =
    'content/motion_content/manifest.json';

final class ContentRepository {
  ContentRepository._({
    required this.library,
    required this.calisthenicsCourse,
    required this.dbkbCourse,
    required this.dbkbHandlingCourse,
    required this.dbkbTransitionsCourse,
    required this.foundationCourses,
    required this.observationManifest,
    required this.catalogue,
    required this.lessonSurfaces,
    required Map<String, MovementConfig> eagerCatalog,
    required AssetBundle bundle,
  }) : _catalog = eagerCatalog,
       _bundle = bundle {
    for (final guide in calisthenicsCourse.catalogueGuides) {
      if (catalogue.byId(guide.movementId) == null) {
        throw FormatException('Unknown teaching movement: ${guide.movementId}');
      }
    }
  }

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
        '$_librarySchemaVersion bekliyor. İçerik ile kod ayrışmış.',
      );
    }

    final List<Map<String, dynamic>> raw = (lib['movements'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

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

    final foundations = await _loadFoundations(bundle);
    return ContentRepository._(
      calisthenicsCourse: await _loadVerifiedCalisthenicsCourse(bundle),
      dbkbCourse: await _loadVerifiedDbkbCourse(bundle),
      dbkbHandlingCourse: await _loadVerifiedDbkbHandlingCourse(bundle),
      dbkbTransitionsCourse: await _loadVerifiedDbkbTransitionsCourse(bundle),
      foundationCourses: foundations.courses,
      observationManifest: foundations.manifest,
      library: lib,
      bundle: bundle,
      eagerCatalog: eager,
      catalogue: LibraryCatalogue(
        movements: raw
            .map((Map<String, dynamic> m) => MovementEntry.fromJson(m))
            .toList(growable: false),
        exclusions: ExclusionsPage.parse(
          await bundle.loadString('content/exclusions.page.json'),
        ),
        skillTrees: SkillTreeIndex.parse(
          await bundle.loadString('content/skill-trees.index.json'),
        ),
      ),
      lessonSurfaces: LessonSurface.deriveAll(
        library: lib,
        catalogFor: (String id) => eager[id]!,
      ),
    );
  }

  static Future<CalisthenicsCourse> _loadVerifiedCalisthenicsCourse(
    AssetBundle bundle,
  ) async {
    final ContentLoadResult result = await ContentBundleLoader(
      reader: FlutterBundleContentAssetReader(bundle: bundle),
      expectedAppId: 'com.yulalab.gravita',
      currentCoreContract: currentMotionContentContract,
      manifestPath: _calisthenicsIntegrityManifestPath,
    ).load();
    if (result is ContentBlocked) throw ContentException(result.error);
    if (result is! ContentReady) {
      throw const ContentException(
        ContentError(code: ContentErrorCode.capability),
      );
    }
    final bytes = await result.assets.read(_calisthenicsAssetPath);
    return CalisthenicsCourse.parse(utf8.decode(bytes));
  }

  static Future<CalisthenicsCourse> _loadVerifiedDbkbCourse(
    AssetBundle bundle,
  ) async {
    final result = await ContentBundleLoader(
      reader: FlutterBundleContentAssetReader(bundle: bundle),
      expectedAppId: 'com.yulalab.gravita',
      currentCoreContract: currentMotionContentContract,
      manifestPath: 'content/motion_content/dbkb-written.manifest.json',
    ).load();
    if (result is ContentBlocked) throw ContentException(result.error);
    if (result is! ContentReady) {
      throw const ContentException(
        ContentError(code: ContentErrorCode.capability),
      );
    }
    final bytes = await result.assets.read(
      'content/courses/dbkb-written.v1.json',
    );
    final course = CalisthenicsCourse.parse(utf8.decode(bytes));
    if (course.id != 'dbkb-written-foundations') {
      throw const FormatException('Wrong DB/KB course asset');
    }
    return course;
  }

  static Future<CalisthenicsCourse> _loadVerifiedDbkbHandlingCourse(
    AssetBundle bundle,
  ) async {
    final result = await ContentBundleLoader(
      reader: FlutterBundleContentAssetReader(bundle: bundle),
      expectedAppId: 'com.yulalab.gravita',
      currentCoreContract: currentMotionContentContract,
      manifestPath: 'content/motion_content/dbkb-handling.manifest.json',
    ).load();
    if (result is ContentBlocked) throw ContentException(result.error);
    if (result is! ContentReady) {
      throw const ContentException(
        ContentError(code: ContentErrorCode.capability),
      );
    }
    final course = CalisthenicsCourse.parse(
      utf8.decode(
        await result.assets.read('content/courses/dbkb-handling.v1.json'),
      ),
    );
    if (course.id != 'dbkb-controlled-handling') {
      throw const FormatException('Wrong DB/KB handling course asset');
    }
    return course;
  }

  static Future<CalisthenicsCourse> _loadVerifiedDbkbTransitionsCourse(
    AssetBundle bundle,
  ) async {
    final result = await ContentBundleLoader(
      reader: FlutterBundleContentAssetReader(bundle: bundle),
      expectedAppId: 'com.yulalab.gravita',
      currentCoreContract: currentMotionContentContract,
      manifestPath: 'content/motion_content/dbkb-transitions.manifest.json',
    ).load();
    if (result is ContentBlocked) throw ContentException(result.error);
    if (result is! ContentReady) {
      throw const ContentException(
        ContentError(code: ContentErrorCode.capability),
      );
    }
    final course = CalisthenicsCourse.parse(
      utf8.decode(
        await result.assets.read('content/courses/dbkb-transitions.v1.json'),
      ),
    );
    if (course.id != 'dbkb-supported-transitions') {
      throw const FormatException('Wrong DB/KB transitions course asset');
    }
    return course;
  }

  static Future<
    ({Map<String, CalisthenicsCourse> courses, MotionModelManifest manifest})
  >
  _loadFoundations(AssetBundle bundle) async {
    final result = await ContentBundleLoader(
      reader: FlutterBundleContentAssetReader(bundle: bundle),
      expectedAppId: 'com.yulalab.gravita',
      currentCoreContract: currentMotionContentContract,
      manifestPath: 'content/motion_content/foundations.manifest.json',
    ).load();
    if (result is ContentBlocked) throw ContentException(result.error);
    if (result is! ContentReady) {
      throw const ContentException(
        ContentError(code: ContentErrorCode.capability),
      );
    }
    final courses = <String, CalisthenicsCourse>{};
    for (final area in ['barbell', 'rings', 'hands']) {
      final course = CalisthenicsCourse.parse(
        utf8.decode(
          await result.assets.read('content/courses/$area-foundations.v1.json'),
        ),
      );
      final expected = area == 'hands'
          ? 'hand-support-foundations'
          : '$area-foundations';
      if (course.id != expected) {
        throw const FormatException('Wrong foundation course');
      }
      courses[area] = course;
    }
    final manifest = MotionModelManifest.parse(
      utf8.decode(
        await result.assets.read('content/models/gravita-observation.v1.json'),
      ),
    );
    for (final course in courses.values) {
      if (course.lessons.any(
        (lesson) => !manifest.tasks.containsKey(lesson.movementTaskId),
      )) {
        throw const FormatException('Missing foundation model task');
      }
    }
    return (
      courses: Map<String, CalisthenicsCourse>.unmodifiable(courses),
      manifest: manifest,
    );
  }

  CalisthenicsCourse? courseForArea(String area) => switch (area) {
    'bodyweight' => calisthenicsCourse,
    'dbkb' => dbkbCourse,
    _ => foundationCourses[area],
  };

  static Future<MovementConfig> _loadCatalog(
    AssetBundle bundle,
    Map<String, dynamic> movement,
    String catalogId,
  ) async {
    final String? wave = movement['wave'] as String?;
    if (wave == null) {
      throw StateError(
        'library.json: ${movement['id']} `wave` bildirmiyor — katalog adresi '
        'kurulamaz. Dalga beyanı zorunlu.',
      );
    }
    return MovementConfig.parse(
      await bundle.loadString(
        'content/catalog/${wave.toLowerCase()}/$catalogId.json',
      ),
    );
  }

  final MotionModelManifest observationManifest;
  final Map<String, CalisthenicsCourse> foundationCourses;
  final Map<String, dynamic> library;
  final CalisthenicsCourse calisthenicsCourse;
  final CalisthenicsCourse dbkbCourse;
  final CalisthenicsCourse dbkbHandlingCourse;
  final CalisthenicsCourse dbkbTransitionsCourse;

  FoundationCoverage get foundationCoverage => FoundationCoverage(
    catalogueIds: catalogue.movements.map((movement) => movement.id),
    startableCameraIds: catalogue.movements
        .where((movement) => startableConfigFor(movement.id) != null)
        .map((movement) => movement.id),
    practiceGuideIds: calisthenicsCourse.catalogueGuides
        .where((guide) => guide.kind != MovementGuideKind.readingOnly)
        .map((guide) => guide.movementId),
    readingGuideIds: calisthenicsCourse.catalogueGuides
        .where((guide) => guide.kind == MovementGuideKind.readingOnly)
        .map((guide) => guide.movementId),
  );

  static Future<CalisthenicsProgressStore> openCalisthenicsProgressStore({
    String? accountUserId,
    Directory? supportDirectory,
    String courseId = 'calisthenics-foundations',
  }) async {
    final epoch = AccountStoreEpochRegistry.capture(accountUserId);
    final support = supportDirectory ?? await getApplicationSupportDirectory();
    epoch.checkCurrent();
    return calisthenicsProgressStoreFor(
      support,
      accountUserId,
      epoch: epoch,
      courseId: courseId,
    );
  }

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
        .firstWhere(
          (Map<String, dynamic> e) => e['id'] == movementId,
          orElse: () => throw StateError(
            'library.json: `$movementId` diye bir hareket YOK',
          ),
        );
    final MovementConfig config = await _loadCatalog(
      _bundle,
      m,
      (m['catalogId'] ?? m['id']) as String,
    );
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
      final MovementConfig? c = startableConfigFor(m.id);
      if (c != null) return c;
    }
    return null;
  }

  /// A named movement can start only when the visible status and its loaded
  /// measurement contract both agree. Live movements have courses, so their
  /// configs are loaded during [load]; an unavailable config fails closed.
  MovementConfig? startableConfigFor(String movementId) {
    final MovementEntry? movement = catalogue.byId(movementId);
    if (movement == null || !movement.isLive) return null;
    final MovementConfig? config = _catalog[movement.catalogId];
    return config != null &&
            config.id == movement.id &&
            config.preconditionDerived
        ? config
        : null;
  }

  /// GRA-P1-003: `content/programs/foundation.v1.json` — bundle'dan.
  /// `ProgramBuilder`ın kendisi bunu BİLMEZ (parametre olarak alır); bu
  /// yalnız KABLOLAMA — `_loadCatalog`la AYNI ayrım (saf mantık / Flutter
  /// kablolaması).
  static Future<ProgramConfig> loadProgramConfig(
    AssetBundle bundle,
  ) async => ProgramConfig.fromJson(
    (jsonDecode(await bundle.loadString('content/programs/foundation.v1.json'))
            as Map)
        .cast<String, dynamic>(),
  );

  /// [ProgramBuilder]ın ihtiyaç duyduğu katalog alt kümesi — 31 hareketin
  /// HEPSİ için (yalnız kursu olanlar değil, `catalogFor` burada HER
  /// hareketi zorlu-yükler). `family`/`level`/`equipment` `library.json`dan
  /// (zaten bellekte); `isHold` TEK BAŞINA katalog dosyasını ister
  /// (`engine.type` — `library.json`a hiç KOPYALANMADI, G-079 dersi: aynı
  /// ölçümün iki evi olursa ayrışır).
  Future<List<ProgramCatalogEntry>> programCatalogEntries() async {
    final List<ProgramCatalogEntry> out = <ProgramCatalogEntry>[];
    for (final MovementEntry m in catalogue.movements) {
      final MovementConfig config = await catalogFor(m.id);
      out.add(
        ProgramCatalogEntry(
          id: m.id,
          family: m.family,
          // `level` `library.json`da YOKSA (O-070 dersi: eksik veri varsayılan
          // ALMAZ) program üretimi bu hareketi hiçbir seviyeye eşleyemez —
          // en KISITLAYICI varsayım ('intermediate', beginner girdisinde
          // ELENİR) seçildi, en olumlu (beginner) DEĞİL.
          level: m.level ?? 'intermediate',
          equipment: m.equipment.toSet(),
          isHold: config.engineType == EngineType.staticHold,
          isLive: m.isLive,
        ),
      );
    }
    return out;
  }

  /// DERS seansı geçmişi. `ProgressSummary` YALNIZ bunu okur.
  static Future<SessionStore> openSessionStore({String? accountUserId}) async {
    final epoch = AccountStoreEpochRegistry.capture(accountUserId);
    final Directory dir = accountDataDirectory(
      await getApplicationSupportDirectory(),
      accountUserId,
    );
    epoch.checkCurrent();
    return AccountSessionStore(
      File('${dir.path}/sessions.jsonl'),
      epoch: epoch,
    );
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
  /// ⛔ YOKLUK BEYANI (H-44, 2026-08-16): kurs sayfası inşa edilip
  /// `LiveSessionScreen`e İKİNCİ bir çağrı yeri eklendiği gün bu paragraf
  /// yalan söyler — o an serbest/ders ayrımı burada YENİDEN yazılmalı.
  /// Düzyazıya değil gerçek bir kapıya bağlı:
  /// `test/single_session_entry_point_test.dart` — `lib/`i tarar,
  /// `LiveSessionScreen(` inşa yerlerinin TAM olarak `gravita_app.dart:217`
  /// olduğunu doğrular; ikinci bir yer belirirse KIRMIZI yanar.
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

  static Future<SessionStore> openFreeSessionStore({
    String? accountUserId,
  }) async {
    final epoch = AccountStoreEpochRegistry.capture(accountUserId);
    final Directory dir = accountDataDirectory(
      await getApplicationSupportDirectory(),
      accountUserId,
    );
    epoch.checkCurrent();
    return AccountSessionStore(
      File('${dir.path}/free_sessions.jsonl'),
      epoch: epoch,
    );
  }

  /// Serbest seans kaydının hareket anahtarı. Gerçek tanım
  /// `live_session.dart`ta (kayıt kararıyla AYNI evde); burası yalnız
  /// okuma tarafının erişimi için delege ediyor — iki ayrı ön ek üretmek,
  /// kovayı yazanla okuyanı sessizce ayırırdı.
  static String freeSessionKey(String movementId) =>
      freeSessionKeyFor(movementId);
}
