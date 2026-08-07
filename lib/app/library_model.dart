/// Kütüphane yüzeyinin OKUDUĞU tipler — `library.json` + `exclusions.page.json`.
///
/// ## Neden motorda değil kabukta
///
/// Bu tiplerin taşıdığı her alan SUNUM alanıdır (ad, ekipman, rozet, gerekçe
/// metni). Motor (`gravita_engine`) ölçüm katmanıdır ve kullanıcı metni
/// ÜRETMEZ (`progress_strings.dart` dosya yorumu aynı sınırı çiziyor).
/// `MovementConfig`'e `equipment`/`level`/`aliases` eklemek o sınırı delerdi.
///
/// ## Neden alanlar `library.json`'da, katalogda DEĞİL okunuyor
///
/// Kütüphane girdileri `tools/promote_library.py` tarafından katalogdan
/// ÜRETİLİR ve `--check` drift'i mekanik yakalar. Yani buradaki veri
/// katalogla aynı, ama TEK dosyadan okunuyor: 31 hareketi listelemek için 31
/// katalog dosyası açmak, bir liste ekranını içerik yükleyicisine
/// bağımlı kılardı.
library;

import 'dart:convert';

/// Bir hareketin kullanıcıya görünen durumu.
///
/// İki değer var, üçüncüsü YOK: `locked` bir hareket durumu değil DERS
/// durumudur. Hareket ya girilebilir (`live`) ya da henüz değil
/// (`comingSoon`) — ve ikincisi bir EKSİKLİK değil, isimli bir ölçüm
/// kuyruğudur.
enum MovementStatus {
  live,
  comingSoon;

  static MovementStatus parse(String? raw) =>
      raw == 'live' ? MovementStatus.live : MovementStatus.comingSoon;
}

/// Dürüstlük kutusunun VERİSİ — metni değil.
///
/// ⭐ W0 §3: bu kutu hiçbir zaman elle yazılmaz. Widget tarafı da kendi
/// cümlesini KURMAZ; yalnız bu iki listeyi çizer. Böylece motor bir metriği
/// kapattığında kutu aynı anda değişir — drift İMKÂNSIZ, "unutulmadı" değil.
///
/// [measured] BOŞ olabilir ve bu bugün BASKIN hâldir (31 hareketin 30'u).
/// Boşluk bir hata hâli değildir: "henüz hiçbir şey ölçmüyoruz" tam olarak
/// söylenmesi gereken şeydir.
final class HonestyBox {
  const HonestyBox({
    required this.measured,
    required this.notMeasured,
    this.waitingOnMeasurement = const <String>[],
    this.scoring,
  });

  factory HonestyBox.fromJson(Map<String, dynamic> j) => HonestyBox(
        measured: _strings(j['measured']),
        notMeasured: _strings(j['notMeasured']),
        waitingOnMeasurement: _strings(j['waitingOnMeasurement']),
        scoring: j['scoring'] as String?,
      );

  final List<String> measured;

  /// **KALICI** sınırlar — tek kamera bunları ASLA göremez (kuvvet, kas
  /// aktivasyonu, ekipman). Kapanmazlar; kod da ölçüm de kapatmaz.
  final List<String> notMeasured;

  /// ⭐ **KUYRUK** — bugün ölçülmemiş ama bir gün kapanabilir.
  ///
  /// İki listenin AYRI olması, M-F-287'nin bir katman ötesi: sınırın
  /// SINIFINI yazmak yetmiyor, hangi KUYRUĞA gittiğini de yazmak gerekiyor.
  /// *"Henüz ölçmedik"* ile *"tek kamera bunu göremez"* aynı cümle değil —
  /// biri bir gün kapanır, öteki asla. Tek listede toplandıklarında kullanıcı
  /// ürünü yanlış anlıyordu: kalıcı sınır "yakında" sanılıyor, kuyruk da
  /// umutsuz görünüyordu.
  final List<String> waitingOnMeasurement;

  /// ⭐ TESPİT/KOÇLUK ↔ PUANLAMA ayrımı — ÜRETİLİR (`promote_library.py`).
  ///
  /// J-113 aktarımı: *"ölçülenler"* başlığı İKİ AYRI iddiayı topluyor —
  /// *"tespit edip koçluyoruz"* ile *"puanlıyoruz"* — ve kullanıcı ikincisini
  /// okuyor. Ölçüldü: Gravita'da 30/31 hareket ipucu veren 71 kural taşıyor
  /// ama **bugün puanlayan ders 0**. Sınıf VAR ve BASKIN; eksik olan ADIYDI.
  ///
  /// `null` ise [measured] zaten boştur: ölçülen hiçbir şey yokken "bu bir
  /// puan değil" demek, olmayan bir şeyi nitelemek olurdu.
  final String? scoring;

  /// Bugünün baskın hâli: hiçbir şey ölçülmüyor. Ekran bunu ONURLU bir hâl
  /// olarak çizer — boş/hata gibi değil.
  bool get measuresNothing => measured.isEmpty;
}

/// Kütüphanedeki tek hareket.
final class MovementEntry {
  const MovementEntry({
    required this.id,
    required this.displayName,
    required this.family,
    required this.level,
    required this.movementClass,
    required this.status,
    required this.catalogId,
    required this.equipment,
    required this.muscleGroups,
    required this.aliases,
    required this.classBadge,
    required this.safetyWarnings,
    required this.referenceSources,
    required this.blurb,
    required this.honesty,
    required this.comingSoon,
    required this.blockedBy,
    required this.courseCount,
    required this.lessonIds,
    this.skillGraphNode,
  });

  factory MovementEntry.fromJson(Map<String, dynamic> j) {
    final List<dynamic> courses =
        (j['courses'] as List<dynamic>?) ?? const <dynamic>[];
    return MovementEntry(
      id: j['id'] as String,
      displayName: j['displayName'] as String,
      family: (j['family'] as String?) ?? 'other',
      level: (j['level'] as String?) ?? 'beginner',
      movementClass: (j['class'] as String?) ?? 'A',
      status: MovementStatus.parse(j['status'] as String?),
      catalogId: (j['catalogId'] ?? j['id']) as String,
      equipment: _strings(j['equipment']),
      muscleGroups: _strings(j['muscleGroups']),
      aliases: _strings(j['aliases']),
      classBadge: j['classBadge'] as String?,
      safetyWarnings: _strings(j['safetyWarnings']),
      referenceSources: (j['referenceSources'] as num?)?.toInt() ?? 0,
      blurb: (j['blurb'] as String?) ?? '',
      honesty:
          HonestyBox.fromJson((j['honesty'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{}),
      comingSoon: _strings(j['comingSoonInThisMovement']),
      blockedBy: _strings(j['blockedBy']),
      skillGraphNode: j['skillGraphNode'] as String?,
      courseCount: courses.length,
      // Ders KİMLİKLERİ taşınır, yalnız sayısı değil: hareket sayfası
      // "bu harekete ait seans" filtresini bu kümeyle kuruyor. `LessonSurface`
      // hareketi taşımıyor (motorda `movementId` alanı YOK) ve ders
      // kimliğinden hareketi TAHMİN etmek — ör. önekten çıkarmak — uydurulmuş
      // bir eşleştirme olurdu. Kimlik zaten burada, türetmeye gerek yok.
      lessonIds: courses
          .expand<String>((dynamic c) =>
              (((c as Map)['lessons'] as List<dynamic>?) ?? const <dynamic>[])
                  .map<String>((dynamic l) => (l as Map)['id'] as String))
          .toList(growable: false),
    );
  }

  final String id;
  final String displayName;
  final String family;
  final String level;

  /// A/B/D — hareketin ZORLUĞU değil, KAMERANIN NE GÖREBİLDİĞİ
  /// (`movement-classes.json` §principle).
  final String movementClass;
  final MovementStatus status;
  final String catalogId;
  final List<String> equipment;
  final List<String> muscleGroups;
  final List<String> aliases;
  final String? classBadge;
  final List<String> safetyWarnings;

  /// Hasat edilmiş EĞİTMEN sayısı (`provenance.sources`).
  ///
  /// ⚠️ Yüzeyin *"referans yok"* cümlesini KOŞULLU kurması için var. O cümle
  /// koşulsuzdu ve `push_up`ta sayfanın iki bloğu çelişiyordu: üstte
  /// *"hiç kayıtlı eğitmen referansımız yok"*, altta *"5 eğitmen, 36 çekim
  /// ATTESTED"*. Cümle yazıldığında doğruydu — sonra hasat geldi.
  final int referenceSources;
  final String blurb;
  final HonestyBox honesty;

  /// Henüz açılmamış olanlar — her maddesi kendi gerekçesini TAŞIR
  /// (kütüphane kapısı K6 boş gerekçeyi reddediyor).
  final List<String> comingSoon;

  /// Makineyle doğrulanan bloker anahtarları. Kullanıcıya HAM gösterilmez —
  /// sayısı ve varlığı gösterilir, cümlesi `honesty.notMeasured`'da zaten var.
  final List<String> blockedBy;
  final String? skillGraphNode;
  final int courseCount;

  /// Bu harekete ait ders kimlikleri — seans kaydı eşleştirmesi için.
  final List<String> lessonIds;

  int get lessonCount => lessonIds.length;

  bool get isLive => status == MovementStatus.live;

  /// Aramada eşleşecek sözcükler — ad + takma adlar + kas grupları + ekipman.
  /// Ekran kendi sözlüğünü kurmaz (iki sözlük ayrışır, arama sessizce körelir).
  Iterable<String> get searchTerms sync* {
    yield displayName.toLowerCase();
    for (final String a in aliases) {
      yield a.toLowerCase();
    }
    for (final String m in muscleGroups) {
      yield m.toLowerCase();
    }
    for (final String e in equipment) {
      yield e.toLowerCase();
    }
    yield family.toLowerCase();
  }
}

/// "Neden yok?" sayfasının tek bölümü — `exclusions.json`'dan ÜRETİLİR.
final class ExclusionSection {
  const ExclusionSection({
    required this.id,
    required this.title,
    required this.examples,
    required this.userReason,
    required this.searchTerms,
    required this.limitClass,
    this.movementClass,
  });

  factory ExclusionSection.fromJson(Map<String, dynamic> j) => ExclusionSection(
        id: j['id'] as String,
        title: j['title'] as String,
        examples: _strings(j['examples']),
        userReason: j['userReason'] as String,
        searchTerms: _strings(j['searchTerms']),
        limitClass: (j['limitClass'] as String?) ?? 'capability',
        movementClass: j['movementClass'] as String?,
      );

  final String id;
  final String title;
  final List<String> examples;
  final String userReason;

  /// Arama sözcükleri ÜRETİM ADIMINDA hesaplanır
  /// (`tools/build_exclusions_page.py`), burada değil: aynı sözlüğün iki
  /// evi olursa ayrışır.
  final List<String> searchTerms;

  /// ⭐ Sınırın SINIFI — `authority` · `capability` · `equipment` (J-153).
  ///
  /// *"Kamera bunu göremiyor"* örtük bir **VAAT** taşır: *"daha iyi teknoloji
  /// bunu çözer."* Oysa kalemlerin **3'ü** öyle değil — **mükemmel bir
  /// kamerayla da o hükmü vermeyiz**, çünkü bu bir veri sorunu değil bir
  /// **YETKİ** kararı (felaket-düşüş sorumluluğu · tıbbi sınır · "gövdeyi
  /// koçlarız, ekipmanı değil").
  ///
  /// Sınıf olmadan yedi kalem tek çerçevede okunuyor ve **hiçbir cümle yalan
  /// söylemeden sayfa yanlış anlaşılıyor** — çerçeve, kümenin kendisi
  /// hakkında bir iddiadır ve hiçbir öğesinde yazılı değildir.
  final String limitClass;
  final String? movementClass;
}

final class ExclusionsPage {
  const ExclusionsPage({
    required this.title,
    required this.intro,
    required this.sections,
  });

  factory ExclusionsPage.parse(String jsonText) {
    final Map<String, dynamic> j =
        (jsonDecode(jsonText) as Map).cast<String, dynamic>();
    return ExclusionsPage(
      title: j['pageTitle'] as String,
      intro: j['pageIntro'] as String,
      sections: ((j['sections'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic s) =>
              ExclusionSection.fromJson((s as Map).cast<String, dynamic>()))
          .toList(growable: false),
    );
  }

  final String title;
  final String intro;
  final List<ExclusionSection> sections;

  /// Sorguya değen bölümler. Boş sorgu HİÇBİR bölümü döndürmez — kapsam-dışı
  /// sayfası aramanın DÜŞTÜĞÜ yer, varsayılan yeri değil.
  List<ExclusionSection> matching(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return const <ExclusionSection>[];
    return sections
        .where((ExclusionSection s) =>
            s.searchTerms.any((String t) => t.contains(q) || q.contains(t)))
        .toList(growable: false);
  }
}

/// Bir aramanın SONUCU — iki ayrı olgu, tek tip.
///
/// ⚠️ Bu tipin varlık sebebi W0 §4: *"leg press" arayan kullanıcı boş sonuç
/// DEĞİL, ilgili "Neden yok?" bölümünü görür.* Eğer arama yalnız
/// `List<MovementEntry>` dönseydi, "boş liste" ile "kapsam dışı" aynı hâle
/// çökerdi ve ekran ikisini ayıramazdı — dar-app algısı tam oradan doğar.
final class LibrarySearchResult {
  const LibrarySearchResult({
    required this.query,
    required this.movements,
    required this.exclusions,
  });

  final String query;
  final List<MovementEntry> movements;
  final List<ExclusionSection> exclusions;

  bool get hasQuery => query.trim().isNotEmpty;

  /// GERÇEK boşluk: ne hareket ne de kapsam-dışı gerekçe eşleşti. Bu hâl de
  /// bir cümledir ("bu bizde hiç geçmiyor"), sessiz boş liste değil.
  bool get isEmpty => movements.isEmpty && exclusions.isEmpty;
}

/// Bir beceri-ağacı paketinin ÖZETİ — `tools/build_skill_tree_index.py`.
///
/// Paketin `nodes[]`i BİLEREK burada yok: doğrulanmamış eşik değerleri
/// taşıyor ve onları ekrana taşımak, ölçülmemiş bir sayıyı kapı gibi
/// göstermeye davet olurdu.
final class SkillTree {
  const SkillTree({
    required this.packId,
    required this.displayName,
    required this.nodeCount,
    required this.thresholdsValidated,
    required this.nodeIds,
  });

  factory SkillTree.fromJson(Map<String, dynamic> j) => SkillTree(
        packId: j['packId'] as String,
        displayName: j['displayName'] as String,
        nodeCount: (j['nodeCount'] as num?)?.toInt() ?? 0,
        nodeIds: _strings(j['nodeIds']),
        thresholdsValidated: (j['thresholdsValidated'] as bool?) ?? false,
      );

  final String packId;
  final String displayName;
  final int nodeCount;

  /// Bu pakette geçen düğüm kimlikleri — hareket → AĞAÇ eşlemesi için.
  final List<String> nodeIds;

  /// ⭐ Ekranın "ağacı ÇİZME" kararı buna dayanır — bir yorum satırına değil.
  /// Paketlerin `status` alanı DRAFT dediği sürece `false`; doğrulama geçişi
  /// yapıldığı gün bu alan `true` olur ve ekran kendiliğinden değişir.
  final bool thresholdsValidated;
}

final class SkillTreeIndex {
  const SkillTreeIndex(this.trees);

  factory SkillTreeIndex.parse(String jsonText) => SkillTreeIndex(
        (((jsonDecode(jsonText) as Map).cast<String, dynamic>()['trees']
                    as List<dynamic>?) ??
                const <dynamic>[])
            .map((dynamic t) =>
                SkillTree.fromJson((t as Map).cast<String, dynamic>()))
            .toList(growable: false),
      );

  final List<SkillTree> trees;

  /// Bir düğüm kimliğinin ait olduğu ağaç — `null` ise hiçbir pakette yok.
  ///
  /// ⚠️ Bu eşleme, hareket sayfasının kullanıcıya **HAM DÜĞÜM KİMLİĞİ**
  /// (`hollow_body`) göstermesini bitirdi: kullanıcı bir iç anahtarı değil
  /// ait olduğu PROGRESYONU merak eder, ve zaten çizilmeyen bir ağacın
  /// düğüm adı ona hiçbir şey söylemiyordu.
  SkillTree? treeFor(String nodeId) {
    for (final SkillTree t in trees) {
      if (t.nodeIds.contains(nodeId)) return t;
    }
    return null;
  }

  List<SkillTree> get drafted =>
      trees.where((SkillTree t) => !t.thresholdsValidated).toList(growable: false);

  /// `Handstand and Planche` — adlar VERİDEN, elle yazılmaz.
  String get draftedNames {
    final List<String> names =
        drafted.map((SkillTree t) => t.displayName).toList(growable: false);
    if (names.isEmpty) return '';
    if (names.length == 1) return names.single;
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }
}

/// Kütüphanenin tamamı — hareketler + kapsam-dışı sayfası + beceri ağaçları.
final class LibraryCatalogue {
  const LibraryCatalogue({
    required this.movements,
    required this.exclusions,
    required this.skillTrees,
  });

  final List<MovementEntry> movements;
  final ExclusionsPage exclusions;
  final SkillTreeIndex skillTrees;

  /// Aile sırası `movement-classes` gibi bir otoriteden gelmiyor; W0 §1'in
  /// listelediği sıra. Tanınmayan bir aile SESSİZCE düşmez, sona eklenir —
  /// yeni bir katalog ailesi eklendiğinde kütüphaneden kaybolması, bu
  /// defterin "yapısal kaldırma yokluk iddiasını vakum-doğru yapar" dersinin
  /// tam da ekran hâli olurdu.
  static const List<String> familyOrder = <String>[
    'push', 'pull', 'legs', 'core', 'shoulders', 'dbkb', 'skill', 'plyo',
    'carry',
  ];

  static const Map<String, String> familyLabels = <String, String>{
    'push': 'Push',
    'pull': 'Pull',
    'legs': 'Legs',
    'core': 'Core',
    'shoulders': 'Shoulders',
    'dbkb': 'Dumbbell & kettlebell',
    'skill': 'Skills',
    'plyo': 'Plyometrics',
    'carry': 'Carries',
  };

  static String labelFor(String family) =>
      familyLabels[family] ?? _titleCase(family);

  /// Aileler, W0 sırasında; her ailenin içinde canlılar önce.
  List<({String family, String label, List<MovementEntry> movements})>
      get families {
    final Map<String, List<MovementEntry>> byFamily =
        <String, List<MovementEntry>>{};
    for (final MovementEntry m in movements) {
      byFamily.putIfAbsent(m.family, () => <MovementEntry>[]).add(m);
    }
    final List<String> ordered = <String>[
      ...familyOrder.where(byFamily.containsKey),
      ...byFamily.keys.where((String f) => !familyOrder.contains(f)).toList()
        ..sort(),
    ];
    return ordered.map((String f) {
      final List<MovementEntry> ms = byFamily[f]!
        ..sort((MovementEntry a, MovementEntry b) {
          if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
          return a.displayName.compareTo(b.displayName);
        });
      return (family: f, label: labelFor(f), movements: ms);
    }).toList(growable: false);
  }

  int get liveCount => movements.where((MovementEntry m) => m.isLive).length;

  MovementEntry? byId(String id) {
    for (final MovementEntry m in movements) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Arama — hareketler VE kapsam-dışı bölümler birlikte.
  LibrarySearchResult search(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return LibrarySearchResult(
          query: query,
          movements: movements,
          exclusions: const <ExclusionSection>[]);
    }
    return LibrarySearchResult(
      query: query,
      movements: movements
          .where((MovementEntry m) =>
              m.searchTerms.any((String t) => t.contains(q)))
          .toList(growable: false),
      exclusions: exclusions.matching(q),
    );
  }
}

List<String> _strings(dynamic raw) =>
    ((raw as List<dynamic>?) ?? const <dynamic>[]).cast<String>();

String _titleCase(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
