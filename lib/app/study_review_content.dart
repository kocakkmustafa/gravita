// Authored reading/recall activities derived from the source references below.
// These do not promote physical instruction, media rights, scoring or mastery.
import 'localization/locale_catalog.dart';

final class StudyText {
  const StudyText(this.en, this.tr);
  final String en, tr;
  String inLanguage(String localeTag) =>
      resolveLocalized(localeTag, en, turkish: tr);
}

final class RecallLesson {
  const RecallLesson({
    required this.id,
    required this.title,
    required this.teaching,
    required this.question,
    required this.answer,
  });
  final String id;
  final StudyText title, teaching, question, answer;
}

final class StudyArea {
  const StudyArea({
    required this.id,
    required this.title,
    required this.boundary,
    required this.sourceRefs,
    required this.lessons,
  });
  final String id;
  final StudyText title, boundary;
  final List<String> sourceRefs;
  final List<RecallLesson> lessons;
}

const List<StudyArea> studyAreas = <StudyArea>[
  StudyArea(
    id: "bodyweight",
    title: StudyText(
      "Floor bodyweight strength",
      "Yerde vücut ağırlığı kuvveti",
    ),
    boundary: StudyText(
      "Reading and written recall only; no movement is needed. Demonstration, personal suitability and physical technique require separate review.",
      "Yalnız okuma ve yazılı hatırlama; hareket gerekmez. Gösterim, kişisel uygunluk ve fiziksel teknik ayrı inceleme gerektirir.",
    ),
    sourceRefs: <String>[
      "content/courses/calisthenics.v1.json#cal-01",
      "lib/app/foundation_coverage.dart",
    ],
    lessons: <RecallLesson>[
      RecallLesson(
        id: "bodyweight.1",
        title: StudyText(
          "Catalogue versus available observation",
          "Katalog ve kullanılabilir gözlem",
        ),
        teaching: StudyText(
          "A catalogue movement, a written guide and a startable camera contract are separate capabilities. A movement appearing in the library does not establish that a camera can assess it.",
          "Katalog hareketi, yazılı rehber ve başlatılabilir kamera sözleşmesi ayrı yeteneklerdir. Hareketin kütüphanede görünmesi kameranın onu değerlendirebildiğini kurmaz.",
        ),
        question: StudyText(
          "Can you infer camera assessment from a lesson link alone?",
          "Yalnız ders bağlantısından kamera değerlendirmesi çıkarabilir misin?",
        ),
        answer: StudyText(
          "No. Name the actual available guide or contract; leave absent observation unavailable.",
          "Hayır. Gerçek kullanılabilir rehberi veya sözleşmeyi adlandır; eksik gözlemi kullanılamaz bırak.",
        ),
      ),
      RecallLesson(
        id: "bodyweight.2",
        title: StudyText(
          "A repetition record has limits",
          "Tekrar kaydı sınırlıdır",
        ),
        teaching: StudyText(
          "Participation, counted repetitions and a skill judgement are different records. A tick or elapsed time cannot establish personal suitability or complete technique.",
          "Katılım, sayılan tekrarlar ve beceri hükmü farklı kayıtlardır. İşaret veya geçen süre kişisel uygunluk ya da tam teknik kuramaz.",
        ),
        question: StudyText(
          "The learner read a squat lesson. Is loaded or bodyweight performance now approved?",
          "Öğrenen squat dersi okudu. Yüklü veya vücut ağırlığı uygulaması artık onaylı mı?",
        ),
        answer: StudyText(
          "No. Report reading only. Execution, observed evidence and individual readiness remain separate.",
          "Hayır. Yalnız okumayı bildir. Uygulama, gözlenen kanıt ve bireysel hazırlık ayrı kalır.",
        ),
      ),
    ],
  ),
  StudyArea(
    id: "dbkb",
    title: StudyText("DB/KB foundations", "DB/KB temelleri"),
    boundary: StudyText(
      "Reading and written recall only; no movement is needed. Demonstration, personal suitability and physical technique require separate review.",
      "Yalnız okuma ve yazılı hatırlama; hareket gerekmez. Gösterim, kişisel uygunluk ve fiziksel teknik ayrı inceleme gerektirir.",
    ),
    sourceRefs: <String>[
      "content/courses/dbkb-written.v1.json#dbkb-01",
      "content/courses/dbkb-transitions.v1.json",
    ],
    lessons: <RecallLesson>[
      RecallLesson(
        id: "dbkb.1",
        title: StudyText(
          "Specify the equipment variant",
          "Ekipman sürümünü belirt",
        ),
        teaching: StudyText(
          "The written path distinguishes equipment literacy from loaded skill. The handling path specifies exact implements and start/end supports; a generic weight label cannot replace these prerequisites.",
          "Yazılı yol ekipman okuryazarlığını yüklü beceriden ayırır. Kullanım yolu kesin aletlerle başlangıç/bitiş desteklerini belirtir; genel ağırlık etiketi bu ön koşulların yerini alamaz.",
        ),
        question: StudyText(
          "The implement or its support is unknown. Which result can you report?",
          "Alet veya desteği bilinmiyor. Hangi sonucu bildirebilirsin?",
        ),
        answer: StudyText(
          "An unresolved equipment prerequisite. Keep loaded execution unattempted; prepare the exact equipment question.",
          "Çözülmemiş ekipman ön koşulu. Yüklü uygulamayı denenmedi bırak; kesin ekipman sorusunu hazırla.",
        ),
      ),
      RecallLesson(
        id: "dbkb.2",
        title: StudyText(
          "Supported start is a distinct transfer",
          "Destekli başlangıç ayrı geçiştir",
        ),
        teaching: StudyText(
          "The supported-start goblet variant begins on a fixed raised support. Its source explicitly excludes a floor-to-chest transfer and a kettlebell clean.",
          "Destekten başlayan goblet sürümü sabit yükseltilmiş destek üzerinde başlar. Kaynak yerden göğse aktarımı ve kettlebell clean’i açıkça dışlar.",
        ),
        question: StudyText(
          "Can reading this supported-start variant establish a floor clean?",
          "Bu destekli başlangıcı okumak yerden clean’i kurabilir mi?",
        ),
        answer: StudyText(
          "No. The start position and transfer differ. Name the exact variant; do not borrow acceptance for an excluded transition.",
          "Hayır. Başlangıç konumuyla aktarım farklıdır. Kesin sürümü adlandır; dışlanan geçişe kabul aktarma.",
        ),
      ),
    ],
  ),
  StudyArea(
    id: "barbell",
    title: StudyText(
      "Barbell: reading preparation",
      "Barbell: okuma hazırlığı",
    ),
    boundary: StudyText(
      "Equipment and evidence literacy only. No loaded instruction, complete barbell course, rack approval or individual suitability is established.",
      "Yalnız ekipman ve kanıt okuryazarlığıdır. Yüklü öğretim, tam barbell kursu, rack onayı veya bireysel uygunluk kurulmaz.",
    ),
    sourceRefs: <String>[
      "content/library.json",
      "content/courses/dbkb-written.v1.json",
    ],
    lessons: <RecallLesson>[
      RecallLesson(
        id: "barbell.1",
        title: StudyText(
          "Equipment context is part of a task",
          "Ekipman bağlamı görevin parçasıdır",
        ),
        teaching: StudyText(
          "A barbell catalogue entry is not interchangeable with a dumbbell/kettlebell handling guide. A written plan must name the implement and the required support before claiming which task it describes.",
          "Barbell katalog kaydı dumbbell/kettlebell kullanım rehberiyle değiştirilemez. Yazılı plan hangi görevi anlattığını iddia etmeden aleti ve gereken desteği adlandırmalıdır.",
        ),
        question: StudyText(
          "A DB/KB guide is the only taught source. Can it be relabelled a complete barbell setup?",
          "Tek öğretilmiş kaynak DB/KB rehberi. Tam barbell kurulumu diye yeniden adlandırılabilir mi?",
        ),
        answer: StudyText(
          "No. Mark barbell-specific setup and transitions untaught. Ask for the missing instruction rather than improvising loaded handling.",
          "Hayır. Barbell’e özgü kurulumla geçişleri öğretilmedi işaretle. Yüklü kullanım doğaçlamak yerine eksik öğretimi sor.",
        ),
      ),
      RecallLesson(
        id: "barbell.2",
        title: StudyText("Write an evidence request", "Kanıt isteği yaz"),
        teaching: StudyText(
          "A useful preparation separates the written task from equipment verification and observed performance. Neither a photo nor a reading tick verifies mechanical support or a loaded technique.",
          "Yararlı hazırlık yazılı görevi ekipman doğrulaması ve gözlenen uygulamadan ayırır. Fotoğraf veya okuma işareti mekanik desteği ya da yüklü tekniği doğrulamaz.",
        ),
        question: StudyText(
          "Write the missing evidence categories before any loaded-task claim.",
          "Yüklü görev iddiasından önce eksik kanıt kategorilerini yaz.",
        ),
        answer: StudyText(
          "Exact task instruction, suitable equipment/support verification, relevant demonstration and competent review of actual performance. This is a question list, not a new equipment approval.",
          "Kesin görev öğretimi, uygun ekipman/destek doğrulaması, ilgili gösterim ve gerçek uygulamanın yetkin incelemesi. Bu soru listesidir; yeni ekipman onayı değildir.",
        ),
      ),
    ],
  ),
  StudyArea(
    id: "rings",
    title: StudyText(
      "Bar/ring support and pulling: reading preparation",
      "Bar/halka destek ve çekiş: okuma hazırlığı",
    ),
    boundary: StudyText(
      "Written preparation only. Structural safety, mounting, loaded support/pulling and full-course teaching remain unverified.",
      "Yalnız yazılı hazırlık. Yapısal güvenlik, montaj, yüklü destek/çekiş ve tam kurs öğretimi doğrulanmamıştır.",
    ),
    sourceRefs: <String>[
      "content/library.json",
      "content/courses/calisthenics.v1.json",
    ],
    lessons: <RecallLesson>[
      RecallLesson(
        id: "rings.1",
        title: StudyText(
          "Do not substitute equipment evidence",
          "Ekipman kanıtını yerine koyma",
        ),
        teaching: StudyText(
          "A floor preparation and a bar/ring task have different support conditions. Seeing a bar or ring in a catalogue does not verify its attachment or the learner’s load-bearing task.",
          "Yer hazırlığı ile bar/halka görevinin destek koşulları farklıdır. Katalogda bar veya halka görmek bağlantısını ya da öğrenenin yük taşıyan görevini doğrulamaz.",
        ),
        question: StudyText(
          "The attachment cannot be verified. Does a completed floor lesson authorize hanging?",
          "Bağlantı doğrulanamıyor. Bitmiş yer dersi asılmaya izin verir mi?",
        ),
        answer: StudyText(
          "No. Keep the equipment and hanging task unverified/unattempted. Do not load it to test an unknown attachment.",
          "Hayır. Ekipmanı ve asılma görevini doğrulanmadı/denenmedi bırak. Bilinmeyen bağlantıyı sınamak için yükleme.",
        ),
      ),
      RecallLesson(
        id: "rings.2",
        title: StudyText(
          "Record one missing prerequisite",
          "Tek eksik ön koşulu kaydet",
        ),
        teaching: StudyText(
          "A preparation record should identify what is unknown rather than marking the entire support/pull domain learned. Equipment, instruction and physical evidence are separate prerequisites.",
          "Hazırlık kaydı bütün destek/çekiş alanını öğrenildi işaretlemek yerine bilinmeyeni belirlemelidir. Ekipman, öğretim ve fiziksel kanıt ayrı ön koşullardır.",
        ),
        question: StudyText(
          "What is more useful than “not ready”: a general label or an exact unanswered question?",
          "“Hazır değil”den hangisi daha yararlı: genel etiket mi, kesin cevapsız soru mu?",
        ),
        answer: StudyText(
          "An exact question, such as which task was taught and what verifies its support conditions. The question itself grants no physical permission.",
          "Öğretilmiş kesin görev ve destek koşullarını doğrulayan kanıt gibi kesin soru. Sorunun kendisi fiziksel izin vermez.",
        ),
      ),
    ],
  ),
  StudyArea(
    id: "hands",
    title: StudyText(
      "Hand balance and straight-arm preparation",
      "El desteğinde denge ve düz kol hazırlığı",
    ),
    boundary: StudyText(
      "Written preparation only. Inversion requires the existing orientation-aware S2 policy; no new inverted/loaded practice is instructed or approved.",
      "Yalnız yazılı hazırlık. Ters duruş mevcut yönelim-farkında S2 politikasını gerektirir; yeni ters/yüklü pratik öğretilmez veya onaylanmaz.",
    ),
    sourceRefs: <String>[
      "CLAUDE.md",
      "content/skill-graph/handstand.v1.json",
      "content/skill-graph/planche.v1.json",
    ],
    lessons: <RecallLesson>[
      RecallLesson(
        id: "hands.1",
        title: StudyText(
          "Orientation policy and confidence",
          "Yönelim politikası ve güven",
        ),
        teaching: StudyText(
          "For inverted movements the recorded safety boundary requires S2 orientation awareness. Plain S1 is forbidden for that class; a high confidence value alone does not resolve silent axis errors.",
          "Ters hareketlerde kayıtlı güvenlik sınırı S2 yönelim farkındalığı gerektirir. Bu sınıfta düz S1 yasaktır; yüksek güven değeri tek başına sessiz eksen hatalarını çözmez.",
        ),
        question: StudyText(
          "Does a high-confidence S1 observation authorize an inversion judgement?",
          "Yüksek güvenli S1 gözlemi ters duruş hükmüne izin verir mi?",
        ),
        answer: StudyText(
          "No. Keep the inversion policy unchanged. This reading task does not alter an engine, model or eligibility gate.",
          "Hayır. Ters duruş politikasını koru. Bu okuma görevi motoru, modeli veya uygunluk kapısını değiştirmez.",
        ),
      ),
      RecallLesson(
        id: "hands.2",
        title: StudyText(
          "Preparation count is not readiness",
          "Hazırlık sayısı hazır olma değildir",
        ),
        teaching: StudyText(
          "Handstand and planche graph entries contain preparation, prerequisites and measurement limits. A preparation session count is a record; it is not a personal wrist-load or balance approval.",
          "Handstand ve planche grafik kayıtlarında hazırlık, ön koşullar ve ölçüm sınırları vardır. Hazırlık oturumu sayısı kayıttır; kişisel bilek yükü veya denge onayı değildir.",
        ),
        question: StudyText(
          "A graph preparation counter is met. Which evidence cannot be inferred from that count?",
          "Grafik hazırlık sayacı karşılandı. O sayıdan hangi kanıt çıkarılamaz?",
        ),
        answer: StudyText(
          "Personal suitability, loaded technique and safe balance entry/exit. Keep these separate and ask for the missing qualified review.",
          "Kişisel uygunluk, yüklü teknik ve güvenli dengeye giriş/çıkış. Bunları ayrı tut ve eksik yetkin incelemeyi sor.",
        ),
      ),
    ],
  ),
];
