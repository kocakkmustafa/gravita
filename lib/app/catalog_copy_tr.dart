import 'package:flutter/material.dart';

import 'app_locale.dart';
import 'library_model.dart';
import 'library_strings.dart';

bool _isTurkish(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'tr';

/// Display copy is guarded by the shipped English source. A changed source
/// remains visible in English until its meaning is reviewed again.
String movementBlurb(BuildContext context, MovementEntry movement) {
  if (!_isTurkish(context)) return movement.blurb;
  if (movement.isLive) {
    final copy = _liveBlurbs[movement.id];
    return copy != null && movement.blurb == copy.english
        ? copy.turkish
        : movement.blurb;
  }
  final expected =
      '${movement.displayName} is in our catalogue and closed. '
      '${movement.blockedBy.length} measurements are missing before we would '
      'coach it — named below, in plain terms.';
  if (movement.blurb != expected) return movement.blurb;
  return '${catalogName(context, movement.id, movement.displayName)} katalogda '
      'yer alıyor ancak kullanıma kapalı. ${movement.blockedBy.length} ölçüm '
      'eksik; adları ve gerekçeleri aşağıda.';
}

typedef _LiveBlurb = ({String english, String turkish});

const Map<String, _LiveBlurb> _liveBlurbs = <String, _LiveBlurb>{
  'bodyweight_squat': (
    english:
        'Set your phone down side-on so it can see you from head to heels. '
        'We count your reps and time your tempo — the engine only counts a rep '
        'if your hip and knee moved together through it.',
    turkish:
        'Telefonu, baştan topuğa kadraja gireceğin şekilde yaklaşık yandan '
        'yerleştir. Tekrarlarını sayar ve temponu ölçeriz; kalça ve dizin o '
        'tekrarda birlikte hareket etmiyorsa tekrarı saymayız.',
  ),
  'push_up': (
    english:
        'Set your phone down side-on so it can see you from head to heels. '
        'We count verified push-up reps and show median down/up tempo after '
        'the set. A shallow-rep cue is not displayed during the set.',
    turkish:
        'Telefonu, baştan topuğa kadraja gireceğin şekilde yaklaşık yandan '
        'yerleştir. Doğrulanan şınav tekrarlarını sayar ve set sonunda '
        'iniş/çıkış temposunun ortancasını gösteririz. Set sırasında sığ '
        'tekrar uyarısı gösterilmez.',
  ),
};

/// The movement id and complete generated source must both match. If the
/// measurement contract changes, its revised English copy stays visible
/// until the translation is reviewed against that new contract.
String liveHonestyCopy(BuildContext context, String movementId, String source) {
  if (!_isTurkish(context)) return source;
  return _liveHonestyCopy[movementId]?[source] ?? source;
}

const String _scoringSource =
    'None of this is a score. We count and time what is listed above — no '
    'number grades your form, on this movement or any other in Gravita. Form '
    'grading stays shut until joint tolerances come from measured disagreement '
    'between real instructors rather than from our default floor.';
const String _scoringTurkish =
    'Bunların hiçbiri puan değildir. Yukarıda belirtilenleri sayar ve '
    'zamanlarız; hiçbir sayı bu harekette veya Gravita’daki başka bir harekette '
    'formunuza puan vermez. Eklem toleransları varsayılan alt sınırımız yerine '
    'gerçek eğitmenler arasındaki ölçülmüş farklardan türetilene kadar form '
    'puanlaması kapalı kalır.';

const Map<String, Map<String, String>>
_liveHonestyCopy = <String, Map<String, String>>{
  'bodyweight_squat': <String, String>{
    'Rep count — the engine only counts a rep if your hip and knee moved '
            'together through it (identity gate, hip-knee correlation >= 0.2, '
            "derived from 16 instructors' measured footage). Coordinate-system "
            'limit on that same gate, named plainly: the threshold was validated '
            'against 3D, gravity-aligned landmarks, where it separates real squat '
            'reps cleanly (95% of 227 real clips passed). Our engine only has '
            'access to flatter, camera-perspective landmarks — on that signal, '
            'real footage passes about 90% of the time (27 of 30 clips) instead '
            'of 95%. The 5-point gap is the cost of a camera-only signal, not a '
            'flaw in the idea: we chose the conservative direction, so the '
            'failure mode is a real rep going uncounted, never a fake one counted.':
        'Tekrar sayısı — motor, kalça ve diz tekrar boyunca birlikte hareket '
        'ederse tekrarı sayar (kimlik kapısı; kalça-diz korelasyonu >= 0,2; '
        '16 eğitmenin ölçülmüş görüntülerinden türetildi). Aynı kapının '
        'koordinat sistemi sınırı: eşik, 3B ve yerçekimiyle hizalı eklem '
        'noktalarıyla doğrulandı; bu veride gerçek squat tekrarlarını net '
        'ayırıyor (227 gerçek klibin %95’i geçti). Motorumuz yalnız kameranın '
        'perspektifine bağlı, daha düz eklem noktalarına erişiyor. Bu sinyalde '
        'gerçek görüntülerin yaklaşık %90’ı (30 klibin 27’si) eşiği geçiyor; '
        '%95’i değil. Beş puanlık fark yalnız kamera sinyalinin bedeli; '
        'ihtiyatlı yönü seçtik: gerçek bir tekrar sayılmayabilir, sahte bir '
        'tekrar sayılmaz.',
    'Left/right comparisons are off the table — for squats AND push-ups. '
            'Measured left-right joint difference is 32.0 degrees for squats and '
            '14.7 degrees for push-ups; neither reference is mirror-agnostic, so '
            'we make no side-specific claim from either (rule 7). We previously '
            'reported 5.2 degrees for push-ups and treated it as evidence of '
            'symmetry — that was wrong twice over: the number averaged '
            'differences that cancelled out instead of measuring how big they '
            'are, and the small difference itself came from the model copying '
            'the limb it cannot see rather than from real symmetry.':
        'Sol/sağ karşılaştırmaları hem squat hem şınav için kapsam dışı. '
        'Ölçülen sol-sağ eklem farkı squat için 32,0 derece, şınav için '
        '14,7 derece; iki referans da ayna yönünden bağımsız değil. Bu '
        'nedenle hiçbirinde belirli bir tarafa ilişkin iddiada bulunmuyoruz '
        '(kural 7). Daha önce şınav için 5,2 derece bildirdik ve bunu '
        'simetri kanıtı saydık; bu iki yönden yanlıştı: farkların '
        'büyüklüğünü ölçmek yerine birbirini götüren farkların ortalamasını '
        'aldık. Ayrıca küçük farkın nedeni gerçek simetri değil, modelin '
        'göremediği uzvu kopyalamasıydı.',
    'Knee tracking side-to-side (valgus) — needs a front-facing camera. '
            'Permanent limit for this setup.':
        'Dizin yanlara kaçışını (valgus) izlemek için önden bakan kamera '
        'gerekir. Bu kurulumun kalıcı sınırıdır.',
    'Weight distribution across the foot, force, or load — a single camera '
            'cannot see these.':
        'Ayağın üzerindeki ağırlık dağılımını, kuvveti veya yükü tek kamera '
        'göremez.',
    'How your form compares to instructors. We now have an ATTESTED '
            'reference from 5 instructors (25 takes) and hip/thigh tolerances '
            'come from their measured spread — but knee, shin and torso are '
            'still at our default floor. Until that changes we count and time '
            'your reps, we do not grade your depth or lean against a reference.':
        'Formunuzun eğitmenlerle karşılaştırması. Beş eğitmenden (25 çekim) '
        'doğrulanmış bir referansımız var ve kalça/uyluk toleransları '
        'ölçülmüş dağılımlarından geliyor. Ancak diz, kaval ve gövde '
        'toleransları hâlâ varsayılan alt sınırımızda. Bu değişene kadar '
        'tekrarlarınızı sayıp zamanlarız; derinliğinize veya eğiminize '
        'referansa göre puan vermeyiz.',
    _scoringSource: _scoringTurkish,
  },
  'push_up': <String, String>{
    'Rep count — the engine refuses to count unless your torso is actually '
            'horizontal (identity gate)':
        'Tekrar sayısı — gövdeniz gerçekten yatay değilse motor tekrarı '
        'saymaz (kimlik kapısı)',
    'Force or load': 'Kuvvet veya yük',
    'Muscle activation': 'Kas aktivasyonu',
    'Hand pressure distribution': 'Eldeki basınç dağılımı',
    'How your form compares to instructors. We now have an ATTESTED '
            'reference from 5 instructors (36 takes) — but not one of the 9 '
            'joint tolerances came out of their measured disagreement; all 9 '
            'still sit at our default floor. Until that changes we count and '
            'time your reps, we do not grade your shape against a reference.':
        'Formunuzun eğitmenlerle karşılaştırması. Beş eğitmenden (36 çekim) '
        'doğrulanmış bir referansımız var; ancak dokuz eklem toleransından '
        'hiçbiri eğitmenler arasındaki ölçülmüş farklardan türetilmedi. '
        'Dokuzunun tamamı hâlâ varsayılan alt sınırımızda. Bu değişene '
        'kadar tekrarlarınızı sayıp zamanlarız; beden şeklinize referansa '
        'göre puan vermeyiz.',
    'Which side is doing more work. We cannot tell your left from your '
            'right reliably in this camera setup, and our own reference '
            'confirms it: left-right joint difference measures 14.7 degrees, '
            'and it collapses to about 13 degrees exactly when the far limb '
            'becomes invisible to the model (it reads ~37 degrees when the '
            'model can see both). A small left-right difference here is the '
            'model guessing, not you being symmetric.':
        'Hangi tarafın daha çok çalıştığı. Bu kamera kurulumunda solunuzu '
        'sağınızdan güvenilir biçimde ayıramıyoruz; kendi referansımız da '
        'bunu doğruluyor: sol-sağ eklem farkı 14,7 derece ölçülüyor, uzaktaki '
        'uzuv model tarafından görünmez olduğunda yaklaşık 13 dereceye '
        'düşüyor (model iki tarafı da görebildiğinde yaklaşık 37 derece). '
        'Buradaki küçük sol-sağ farkı sizin simetrik olduğunuzu değil, '
        'modelin tahmin yürüttüğünü gösterir.',
    _scoringSource: _scoringTurkish,
  },
};

const Map<String, String> _safetyWarnings = <String, String>{
  'Stop at the depth you can control with a neutral spine.':
      'Omurganı nötr tutabildiğin derinlikte dur.',
  'Stop if you feel sharp shoulder or wrist pain — that is different from muscular effort.':
      'Omzunda veya bileğinde keskin ağrı hissedersen dur; bu kas eforundan farklıdır.',
  'If your lower back lifts, reduce the range rather than pushing through.':
      'Belin yerden kalkıyorsa zorlamak yerine hareket aralığını azalt.',
  "If your lower back lifts, tuck your knees — a smaller shape you can hold beats a big one you can't.":
      'Belin yerden kalkıyorsa dizlerini bük; koruyabildiğin küçük bir pozisyon, '
      'koruyamadığın geniş bir pozisyondan iyidir.',
  'Stop if your lower back starts to ache — end the hold rather than pushing through.':
      'Belin ağrımaya başlarsa tutuşu bitir; ağrıya rağmen sürdürme.',
  'Stop if your lower back pinches — a small lift you can hold is the goal.':
      'Belinde sıkışma hissedersen dur; hedef, koruyabildiğin küçük bir yükseliştir.',
  'Ballistic movement — stop if your lower back complains rather than pushing through.':
      'Bu hızlı ve patlayıcı bir harekettir; belinde rahatsızlık olursa zorlamak yerine dur.',
  'Reduce range before adding load if your back rounds.':
      'Sırtın yuvarlanıyorsa ağırlığı artırmadan önce hareket aralığını azalt.',
  'Stop if your front knee complains — shorten the range before adding reps.':
      'Öndeki dizinde rahatsızlık olursa dur; tekrar eklemeden önce hareket aralığını kısalt.',
  "Use a box height you can control — step down, don't jump down.":
      'Kontrol edebildiğin bir yükselti kullan; aşağı atlama, adım atarak in.',
  'High-impact movement. Land softly and stop if your knees or lower back complain.':
      'Bu yüksek darbeli bir harekettir. Yumuşak iniş yap; dizinde veya belinde '
      'rahatsızlık olursa dur.',
  'Build up gradually — sudden high volume is a common shoulder and elbow irritant.':
      'Yavaş yavaş artır; birden yüksek tekrar sayısına çıkmak omuz ve dirseği '
      'rahatsız edebilir.',
  'Dips load the shoulder at end range — build depth gradually and stop at pinching pain.':
      'Dip hareketi en alt noktada omza yük bindirir; derinliği aşamalı artır '
      've sıkışma hissedersen dur.',
  'Falling is a real risk. Clear the space, use a wall, and come down the way you went up.':
      'Düşme riski gerçektir. Alanı boşalt, duvar kullan ve çıktığın yoldan geri in.',
  'Build wrist tolerance before long holds.':
      'Uzun süreli tutuşlardan önce bileklerini aşamalı olarak alıştır.',
  'High wrist and elbow load. Build the lean gradually; stop at joint pain.':
      'Bilek ve dirsek yükü yüksektir. Öne eğilmeyi aşamalı artır; eklem ağrısında dur.',
};

String safetyWarning(BuildContext context, String source) =>
    _isTurkish(context) ? _safetyWarnings[source] ?? source : source;

String exclusionPageTitle(BuildContext context, ExclusionsPage page) =>
    _isTurkish(context) && page.title == "What's not in Gravita — and why"
    ? 'Gravita’da neler yok — ve neden'
    : page.title;

String exclusionPageIntro(BuildContext context, ExclusionsPage page) =>
    _isTurkish(context) &&
        page.intro ==
            "We'd rather do fewer movements properly than list hundreds we can't actually coach. Here's what we left out and the honest reason."
    ? 'Gerçekte destekleyemediğimiz yüzlerce hareketi listelemek yerine '
          'kapsamı sınırlı tutuyoruz. Kapsam dışında bıraktıklarımız ve '
          'gerekçeleri burada.'
    : page.intro;

typedef _ExclusionCopy = ({
  String title,
  String titleTr,
  String reason,
  String reasonTr,
});

const Map<String, _ExclusionCopy> _exclusionCopy = <String, _ExclusionCopy>{
  'machines': (
    title: 'Gym machines',
    titleTr: 'Spor salonu makineleri',
    reason:
        'Machines already fix the path your body travels, so there is very '
        'little form left for a camera to judge — and the frame usually hides '
        'your torso behind the machine. We would be guessing, so we don\'t '
        'include them.',
    reasonTr:
        'Makineler hareket yolunu büyük ölçüde belirler; kameranın '
        'değerlendirebileceği beden hareketi sınırlı kalır. Makine çoğu zaman '
        'gövdeyi de kapatır. Tahminde bulunmak yerine bu hareketleri kapsam '
        'dışında tutuyoruz.',
  ),
  'flips_aerials': (
    title: 'Flips, aerials and tumbling',
    titleTr: 'Taklalar ve havada yapılan hareketler',
    reason:
        'These carry a real risk of a catastrophic fall. An app that cannot '
        'spot you should not be the thing that tells you you\'re ready.',
    reasonTr:
        'Bu hareketlerde ağır sonuçlu düşme riski vardır. Sizi fiziksel olarak '
        'koruyamayan bir uygulama, hazır olduğunuzu söylememelidir.',
  ),
  'one_rep_max': (
    title: 'One-rep max and strength testing',
    titleTr: 'Tek tekrar maksimumu ve kuvvet testleri',
    reason:
        'A camera cannot measure force. On the movements that are open we '
        'count your reps and track them over time, and you can compare those '
        'numbers to published strength standards — but we will never tell you '
        'we measured your strength.',
    reasonTr:
        'Kamera kuvveti ölçemez. Açık hareketlerde tekrarları sayıp zaman '
        'içinde izleriz; bu sayıları yayımlanmış kuvvet standartlarıyla '
        'karşılaştırabilirsiniz. Ancak kuvvetinizi ölçtüğümüzü söylemeyiz.',
  ),
  'medical': (
    title: 'Injury diagnosis and rehab prescriptions',
    titleTr: 'Yaralanma tanısı ve rehabilitasyon önerileri',
    reason:
        'Gravita is a movement-practice tool, not a medical service. If '
        'something hurts, we tell you to stop — we don\'t tell you why.',
    reasonTr:
        'Gravita hareket çalışması içindir; tıbbi hizmet değildir. '
        'Bir şey ağrıyorsa durmanızı söyleriz, nedenini teşhis etmeyiz.',
  ),
  'multi_person': (
    title: 'Training with a partner in frame',
    titleTr: 'Karede birden fazla kişiyle çalışma',
    reason:
        'We analyse one person per session. A second body in the frame '
        'makes the analysis unreliable, so we ask you to clear the frame '
        'instead of quietly guessing which skeleton is yours.',
    reasonTr:
        'Her oturumda bir kişiyi analiz ederiz. Karede ikinci bir kişi '
        'olduğunda analiz güvenilir olmaz; hangi iskeletin size ait olduğunu '
        'tahmin etmek yerine karenin boşaltılmasını isteriz.',
  ),
  'equipment_tracking': (
    title: 'Tracking the equipment itself',
    titleTr: 'Ekipmanın kendisini takip etme',
    reason:
        'We coach your body, not your gear. Even where these movements '
        'were open, we would watch your position and count your reps — we '
        'would not detect the box, the rope or the bar.',
    reasonTr:
        'Odak noktamız ekipman değil, bedenin hareketidir. Bu hareketler '
        'açık olsa bile duruşu izleyip tekrar sayardık; yükseltiyi, ipi veya '
        'barı algılamazdık.',
  ),
  'bench_form': (
    title: 'Form scoring on bench press (and similar lying pressing)',
    titleTr: 'Bench press ve benzeri yatarak itişlerde form puanlama',
    reason:
        'You lie down and press away from the camera, so the phone is '
        'looking straight down the path of the movement. Depth and bar path '
        'can\'t be judged honestly from that angle. Each movement page names '
        'exactly what we do and do not measure there.',
    reasonTr:
        'Yatarak kameradan uzağa doğru itersiniz; telefon hareket yoluna '
        'doğrudan bakar. Bu açıdan derinlik ve bar yolu güvenilir biçimde '
        'değerlendirilemez. Her hareket sayfasında neyi ölçüp neyi '
        'ölçmediğimizi açıkça belirtiyoruz.',
  ),
};

String exclusionSectionTitle(BuildContext context, ExclusionSection section) {
  final copy = _exclusionCopy[section.id];
  return _isTurkish(context) && copy?.title == section.title
      ? copy!.titleTr
      : section.title;
}

String exclusionSectionReason(BuildContext context, ExclusionSection section) {
  final copy = _exclusionCopy[section.id];
  return _isTurkish(context) && copy?.reason == section.userReason
      ? copy!.reasonTr
      : section.userReason;
}

const Map<String, String> _exclusionExamples = <String, String>{
  'Leg press': 'Leg press',
  'Lat pulldown': 'Lat pulldown',
  'Chest press machine': 'Göğüs itiş makinesi',
  'Leg extension': 'Bacak açma makinesi',
  'Cable crossover': 'Kablo çapraz çekişi',
  'Smith machine': 'Smith makinesi',
  'Pec deck': 'Göğüs açış makinesi',
  'Seated row machine': 'Oturarak kürek makinesi',
  'Hack squat': 'Hack squat',
  'Leg curl': 'Bacak bükme makinesi',
  'Backflip': 'Geri takla',
  'Frontflip': 'Öne takla',
  'Aerial cartwheel': 'Havada çember',
  'Back handspring': 'Geri elli takla',
  'Round-off': 'Rondat',
  '1RM squat test': 'Tek tekrar maksimum squat testi',
  'Max deadlift': 'Maksimum deadlift',
  'Estimated strength score': 'Tahmini kuvvet puanı',
  'Diagnosing pain': 'Ağrı tanısı',
  'Post-surgery protocols': 'Ameliyat sonrası protokoller',
  'Physio treatment plans': 'Fizyoterapi planları',
  'Partner workouts': 'Eşli çalışmalar',
  'Group classes': 'Grup dersleri',
  'Spotter in the frame': 'Karede yardımcı kişi',
  'Box height in box jumps': 'Kutu atlayışında yükselti yüksekliği',
  'Rope in jump rope': 'İp atlamada ipin kendisi',
  'Band tension': 'Direnç bandı gerginliği',
  'Ab-wheel distance': 'Karın tekerleği mesafesi',
  'Bar position in muscle-ups': 'Muscle-up sırasında barın konumu',
  'Barbell bench press': 'Halterle bench press',
  'Dumbbell bench press': 'Dambılla bench press',
  'Incline press': 'Eğimli sehpada press',
};

String exclusionExample(BuildContext context, String source) =>
    _isTurkish(context) ? _exclusionExamples[source] ?? source : source;

String exclusionClassLine(BuildContext context, String? limitClass) {
  if (!_isTurkish(context)) return LibraryStrings.limitClassLine(limitClass);
  return switch (limitClass) {
    null => '',
    'authority' =>
      'Bu, teknolojinin sınırı değil; bilerek çizdiğimiz bir sınır. '
          'Daha iyi teknoloji bunu değiştirmez.',
    'equipment' => 'Bu, sahip olmanızı beklemediğimiz ek donanım gerektirir.',
    'capability' => 'Tek telefon kamerası gerekenleri göremez.',
    _ => LibraryStrings.limitClassLine(limitClass),
  };
}
