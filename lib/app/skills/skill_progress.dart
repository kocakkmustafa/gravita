/// Beceri ağacı — TİPLİ ayrıştırma + deterministik açılma sözleşmesi
/// (GRA-P1-001).
///
/// ## Neden `lib/app/` içinde, `gravita_engine`de DEĞİL
///
/// Roadmap §6: "Program ve skill graph app content katmanında." Motor
/// (`gravita_engine`) ölçüm katmanıdır — poz/tekrar/tutuş. Beceri ağacı bir
/// İÇERİK yapısıdır (`content/skill-graph/*.json`), `movement_config.dart`nın
/// kardeşi değil `library_model.dart`nın kardeşidir.
///
/// ## Neden `nodes[]`in TAMAMI artık ayrıştırılıyor (`library_model.dart`nın
/// `SkillTree`sinden FARKLI)
///
/// `library_model.dart`daki `SkillTree` BİLEREK yalnız `packId`/`nodeCount`/
/// `thresholdsValidated`/`nodeIds` taşıyor — paket JSON'unun ÜRETİLMİŞ
/// özeti (`tools/build_skill_tree_index.py`), kütüphane LİSTESİ için yeterli.
/// Bu dosya AYRI bir amaç için VAR: gerçek bir beceri ağacı EKRANI (sıradaki
/// görev) düğümlerin başlığını, ön-koşulunu, güvenlik notlarını ve
/// alıştırmalarını GÖSTERMEK zorunda — bunlar `nodes[]`in İÇİNDE, üretilmiş
/// özette YOK. `handstand.v1.json`ın kendi `$falsifiedBy` notu şunu
/// doğruluyor: "kütüphane ekranı `nodes[]`i hiç ayrıştırmıyor, bu yüzden
/// taslak bir paket eşikleri SIZDIRAMAZ" — bu iddia bu dosya YAZILDIKTAN
/// SONRA da geçerli KALMALI, çünkü eşik SIZINTISINI önleyen şey konumun
/// (hangi dosyada) DEĞİL, aşağıdaki [SkillProgressEvaluator]'ın KENDİ
/// kuralıdır (bkz. sınıf yorumu).
library;

import 'dart:convert';

/// Bir düğümün ön-koşul-zinciri + güvenlik açısından NEREDE durduğu.
///
/// ⚠️ Dörtten YALNIZ biri `achieved` diyebilir ve o bile [SkillPack.
/// thresholdsValidated] `false` olduğu sürece ASLA dönmez — bkz.
/// [SkillProgressEvaluator.availabilityOf].
enum SkillNodeAvailability {
  /// Ön-koşul zinciri TAMAMLANMAMIŞ — düğüm henüz gösterilecek/başlanacak
  /// bir şey değil.
  locked,

  /// Ön-koşullar tamam ama düğüm `requiresExplicitAcknowledgement` taşıyor
  /// ve kullanıcı HENÜZ bunu onaylamadı (ör. boyun yükü uyarısı).
  blockedBySafetyAcknowledgement,

  /// Ön-koşullar (+ gereken onay) tamam — kullanıcının ŞU AN üzerinde
  /// çalıştığı düğüm budur. Paketin eşikleri henüz uzman-onaylı olmadığı
  /// için "başardın" iddiası YOK; alıştırma/ipucu içeriği dürüstçe gösterilir.
  pendingValidation,

  /// Ön-koşullar + onay tamam VE [SkillPack.thresholdsValidated] `true` VE
  /// çağıran bu düğümü tamamlanmış olarak İŞARETLEDİ. Bugünkü içerikte
  /// (ikisi de DRAFT) HİÇBİR düğüm bu hâle ULAŞAMAZ — sözleşme onu
  /// DESTEKLER, üretmez.
  achieved,
}

/// Tek bir beceri düğümü — `content/skill-graph/*.json`ın `nodes[]`
/// öğesinin TİPLİ karşılığı. Yalnız açılma mantığının okuduğu alanlar +
/// bir ekranın göstereceği İÇERİK alanları taşınır; `unlock.allOf`'un HAM
/// eşik değerleri BİLEREK taşınmaz (bkz. dosya başı yorumu — kullanıcıya
/// giden hiçbir yüzey taslak bir sayıyı görmemeli).
final class SkillNode {
  const SkillNode({
    required this.id,
    required this.title,
    required this.summary,
    required this.requires,
    required this.entry,
    required this.safetyGate,
    required this.requiresExplicitAcknowledgement,
    required this.safetyNotes,
    required this.cues,
    required this.drills,
    required this.milestone,
    this.branch,
  });

  factory SkillNode.fromJson(Map<String, dynamic> j) => SkillNode(
        id: j['id'] as String,
        title: j['title'] as String,
        summary: j['summary'] as String?,
        requires: _strings(j['requires']),
        entry: j['entry'] == true,
        safetyGate: j['safetyGate'] == true,
        requiresExplicitAcknowledgement:
            j['requiresExplicitAcknowledgement'] == true,
        safetyNotes: _strings(j['safetyNotes']),
        cues: _strings(j['cues']),
        drills: ((j['drills'] as List<dynamic>?) ?? const <dynamic>[])
            .cast<Map<String, dynamic>>()
            .map((Map<String, dynamic> d) => SkillDrill.fromJson(d))
            .toList(growable: false),
        milestone: j['milestone'] == true,
        branch: j['branch'] as String?,
      );

  final String id;
  final String title;

  /// `null` = içerikte YOK (ör. `planche.v1.json`ın hiçbir düğümü bu alanı
  /// taşımıyor — `handstand.v1.json`dan FARKLI, iki paket ayrı yazıldı).
  /// Uydurulmuş bir özet YAZILMAZ; ekran alanı `null` ise satırı çizmez.
  final String? summary;
  final List<String> requires;
  final bool entry;
  final bool safetyGate;
  final bool requiresExplicitAcknowledgement;
  final List<String> safetyNotes;
  final List<String> cues;
  final List<SkillDrill> drills;
  final bool milestone;

  /// `null` = ana zincirin bir parçası. `"auxiliary"`/`"separate_skill"` =
  /// kimsenin ön-koşulu olmayan bilinçli bir yaprak dal (bkz.
  /// `packages/gravita_engine/test/skill_graph_test.dart`daki yetim-düğüm
  /// nöbeti — bu alan o testin AYIRT ETMEDİĞİ bir bilgi, yalnız GÖSTERİM
  /// için: bir ekran "ana yol" ile "isteğe bağlı dal"ı ayrı çizebilir).
  final String? branch;
}

final class SkillDrill {
  const SkillDrill(
      {required this.id, required this.title, required this.prescription});

  factory SkillDrill.fromJson(Map<String, dynamic> j) => SkillDrill(
        id: j['id'] as String,
        title: j['title'] as String,
        prescription: j['prescription'] as String,
      );

  final String id;
  final String title;
  final String prescription;
}

/// Bir paketin TAMAMI — `content/skill-graph/<pack>.v1.json`.
final class SkillPack {
  const SkillPack({
    required this.packId,
    required this.status,
    required this.nodes,
  });

  factory SkillPack.parse(String jsonText) {
    final Map<String, dynamic> j =
        (jsonDecode(jsonText) as Map).cast<String, dynamic>();
    return SkillPack(
      packId: j['packId'] as String,
      status: j['status'] as String,
      nodes: ((j['nodes'] as List<dynamic>?) ?? const <dynamic>[])
          .cast<Map<String, dynamic>>()
          .map((Map<String, dynamic> n) => SkillNode.fromJson(n))
          .toList(growable: false),
    );
  }

  final String packId;

  /// Ham `status` metni — insan-okur bir cümle (ör. "DRAFT — eşikler...").
  /// [thresholdsValidated] BUNDAN türetilir, elle ayrı bir bayrak TUTULMAZ
  /// (`tools/build_skill_tree_index.py::_is_draft()` ile AYNI sözleşme:
  /// tek kaynak metindir, iki yerde iki bayrak ayrışabilirdi).
  final String status;
  final List<SkillNode> nodes;

  /// `content/skill-graph/*.json`ın kendi sözleşmesi: `status` "DRAFT" ile
  /// BAŞLAMIYORSA eşikler uzman-onaylı sayılır. `tools/build_skill_tree_
  /// index.py`nin `_is_draft()` fonksiyonuyla AYNI kural — iki ayrı okuyucu
  /// aynı metni FARKLI yorumlarsa (ör. biri "draft" alt harfli arasa)
  /// sessizce ayrışırlardı.
  bool get thresholdsValidated => !status.trimLeft().startsWith('DRAFT');

  SkillNode? byId(String id) {
    for (final SkillNode n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }
}

/// [SkillPack] için DETERMİNİSTİK açılma değerlendiricisi (GRA-P1-001
/// Step 2/3).
///
/// ## ⭐ Merkezî kural — kod gövdesi bunu KANITLAR, yorum değil
///
/// `pack.thresholdsValidated == false` olduğu sürece [availabilityOf]
/// **HİÇBİR** düğüm için [SkillNodeAvailability.achieved] DÖNDÜRMEZ —
/// [completedNodeIds] çağıran tarafından (ör. gelecekteki bir hata, ya da
/// bir test) YANLIŞLIKLA "tamamlandı" diye işaretlenmiş olsa BİLE. Bu,
/// erken-açılmayı ENGELLEYEN tek satırdır (`_earlyUnlockGuard` altında,
/// AYRI adlandırılmış) ve `test/skill_progress_test.dart`taki sabotaj
/// nöbeti tam bunu sınıyor: girdi "her şey tamamlandı" dese bile çıktı
/// "achieved" OLAMAZ.
final class SkillProgressEvaluator {
  const SkillProgressEvaluator({
    required this.pack,
    this.completedNodeIds = const <String>{},
    this.acknowledgedSafetyNodeIds = const <String>{},
  });

  final SkillPack pack;

  /// Çağıranın "bu düğümün ön-koşul kriterleri karşılandı" dediği kümedir —
  /// BU SINIF bu kümeyi NASIL hesaplandığını BİLMEZ (oturum geçmişi, elle
  /// işaretleme, ne olursa olsun); yalnız onu [pack.thresholdsValidated] ile
  /// birlikte GÜVENLİ bir sonuca dönüştürür.
  final Set<String> completedNodeIds;

  /// Kullanıcının `requiresExplicitAcknowledgement` taşıyan düğümler için
  /// VERDİĞİ açık onayların kümesi.
  final Set<String> acknowledgedSafetyNodeIds;

  /// Bir düğümün ön-koşul ZİNCİRİNİN (yalnız doğrudan ebeveynleri değil,
  /// hepsi) [completedNodeIds] içinde olup olmadığı.
  bool _prerequisitesMet(SkillNode node) =>
      node.requires.every(completedNodeIds.contains);

  SkillNodeAvailability availabilityOf(String nodeId) {
    final SkillNode? node = pack.byId(nodeId);
    if (node == null) {
      throw ArgumentError.value(nodeId, 'nodeId', 'pakette yok: ${pack.packId}');
    }

    if (!_prerequisitesMet(node)) {
      return SkillNodeAvailability.locked;
    }
    if (node.requiresExplicitAcknowledgement &&
        !acknowledgedSafetyNodeIds.contains(node.id)) {
      return SkillNodeAvailability.blockedBySafetyAcknowledgement;
    }

    // ⭐ ERKEN-AÇILMA KORUMASI (adıyla) — bu satır olmadan aşağıdaki satır
    // `completedNodeIds.contains(node.id)` tek başına "achieved" dönerdi,
    // paketin eşikleri hâlâ taslak olsa BİLE. Bu sınıfın VAR OLMA sebebi
    // tam olarak bu satırın kendisidir.
    if (!pack.thresholdsValidated) {
      return SkillNodeAvailability.pendingValidation;
    }

    return completedNodeIds.contains(node.id)
        ? SkillNodeAvailability.achieved
        : SkillNodeAvailability.pendingValidation;
  }

  /// Kullanıcının ŞU AN üzerinde çalışabileceği düğümler — kilitli
  /// olmayan, güvenlik onayı bekleyen dahil (o hâlin KENDİSİ bir eylem
  /// ister: onayla). Sıralama paketteki sırayı korur (kararlı, kullanıcıya
  /// sürpriz yeniden-sıralama yapmaz).
  List<SkillNode> currentFocus() => pack.nodes
      .where((SkillNode n) => availabilityOf(n.id) != SkillNodeAvailability.locked)
      .where((SkillNode n) => !completedNodeIds.contains(n.id))
      .toList(growable: false);
}

List<String> _strings(dynamic raw) =>
    ((raw as List<dynamic>?) ?? const <dynamic>[]).cast<String>();
