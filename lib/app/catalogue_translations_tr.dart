import 'package:flutter/widgets.dart';
import 'app_locale.dart';

/// App-only display copy. Identity, measurement rules and course data stay
/// in their canonical source. Changed/unrecognised sources remain in English.
enum CatalogueTextKind { notMeasured, comingSoon, ruleLabel, ruleCue }

String catalogueText(
  BuildContext context,
  String movementId,
  CatalogueTextKind kind,
  String source,
) {
  final translated = _translations[kind]?[source];
  return translated != null && translated.movementIds.contains(movementId)
      ? localized(context, source, translated.turkish)
      : source;
}

typedef _Translation = ({String turkish, Set<String> movementIds});

// Reviewed exact source strings, including units and technical identifiers.
// Reading a rule cue does not validate the rule or approve physical technique.
const Map<CatalogueTextKind, Map<String, _Translation>> _translations = {
  CatalogueTextKind.notMeasured: {
    "The weights are not detected — load and distance are not measured": (
      turkish: "Ağırlıklar algılanmaz; yük ve mesafe ölçülmez",
      movementIds: {"farmer_carry"},
    ),
    "Grip endurance": (
      turkish: "Kavrama dayanıklılığı",
      movementIds: {"farmer_carry"},
    ),
    "Steps or pace": (
      turkish: "Adımlar veya tempo",
      movementIds: {"farmer_carry"},
    ),
    "Side-to-side hip rotation — hard to judge from a side view": (
      turkish:
          "Kalçanın iki yana dönmesi — yandan bakışta değerlendirmek zordur",
      movementIds: {"bird_dog"},
    ),
    "\"Toes to bar\" — the bar is not detected, so we judge range by your hip angle": (
      turkish:
          "\"Ayak parmaklarını bara kaldırma\" — bar algılanmadığı için hareket açıklığını kalça açına göre değerlendiriyoruz",
      movementIds: {"hanging_leg_raise"},
    ),
    "Grip or forearm fatigue": (
      turkish: "Kavrama veya ön kol yorgunluğu",
      movementIds: {"hanging_leg_raise"},
    ),
    "Which foot is which — we count drives, not sides": (
      turkish:
          "Hangi ayağın hangisi olduğu — tarafları değil, diz çekişlerini sayıyoruz",
      movementIds: {"mountain_climber"},
    ),
    "Ground contact time": (
      turkish: "Zeminle temas süresi",
      movementIds: {"mountain_climber"},
    ),
    "Muscle activation or how hard it feels": (
      turkish: "Kas aktivasyonu veya ne kadar zor hissettirdiği",
      movementIds: {"plank"},
    ),
    "Force through the forearms": (
      turkish: "Ön kollardan aktarılan kuvvet",
      movementIds: {"plank"},
    ),
    "Exact shoulder loading": (
      turkish: "Omuzdaki yüklenmenin tam miktarı",
      movementIds: {"side_plank"},
    ),
    "Whether your toes actually touched the bar — the bar is not detected": (
      turkish:
          "Ayak parmaklarının gerçekten bara değip değmediği — bar algılanmaz",
      movementIds: {"toes_to_bar"},
    ),
    "Kipping efficiency": (
      turkish: "Kipping verimliliği",
      movementIds: {"toes_to_bar"},
    ),
    "Form verdict — you press away from the camera, so depth and path can't be judged honestly": (
      turkish:
          "Form değerlendirmesi — itişi kameradan uzağa doğru yaptığın için derinlik ve hareket yolu dürüstçe değerlendirilemez",
      movementIds: {"floor_press"},
    ),
    "Range of motion": (
      turkish: "Hareket açıklığı",
      movementIds: {"floor_press"},
    ),
    "Whether your elbows flare": (
      turkish: "Dirseklerinin yana açılıp açılmadığı",
      movementIds: {"floor_press"},
    ),
    "Form verdict — the camera looks down the movement path, so depth and bar path can't be judged honestly": (
      turkish:
          "Form değerlendirmesi — kamera hareket doğrultusu boyunca baktığı için derinlik ve barın izlediği yol dürüstçe değerlendirilemez",
      movementIds: {"floor_press"},
    ),
    "The kettlebell itself is not detected — weight, path and height are not measured": (
      turkish:
          "Kettlebellin kendisi algılanmaz; ağırlığı, izlediği yol ve yüksekliği ölçülmez",
      movementIds: {"kb_swing"},
    ),
    "Grip or power output": (
      turkish: "Kavrama veya üretilen güç",
      movementIds: {"kb_swing"},
    ),
    "The dumbbells are not detected — load and bar path are not measured": (
      turkish: "Dambıllar algılanmaz; yük ve barın izlediği yol ölçülmez",
      movementIds: {"romanian_deadlift"},
    ),
    "Hamstring stretch or effort": (
      turkish: "Arka uyluk kaslarının gerilmesi veya harcanan efor",
      movementIds: {"romanian_deadlift"},
    ),
    "Glute activation — we see the shape, not the muscle": (
      turkish:
          "Kalça kaslarının aktivasyonu — kası değil, vücudun şeklini görüyoruz",
      movementIds: {"glute_bridge"},
    ),
    "The kettlebell is not detected — load is not measured": (
      turkish: "Kettlebell algılanmaz; yük ölçülmez",
      movementIds: {"goblet_squat"},
    ),
    "Weight distribution across the feet": (
      turkish: "Ağırlığın ayaklara dağılımı",
      movementIds: {"lunge"},
    ),
    "Which part of the calf is working": (
      turkish: "Baldır kaslarının hangi bölümünün çalıştığı",
      movementIds: {"calf_raise"},
    ),
    "Balance assistance from a wall": (
      turkish: "Duvardan alınan denge desteği",
      movementIds: {"calf_raise"},
    ),
    "Box height — the box is not detected": (
      turkish: "Kutu yüksekliği — kutu algılanmaz",
      movementIds: {"step_up"},
    ),
    "Whether you pushed off the trailing foot": (
      turkish: "Arkadaki ayağından itiş alıp almadığın",
      movementIds: {"step_up"},
    ),
    "The equipment itself — box height, rope, band tension or bar position are not detected": (
      turkish:
          "Ekipmanın kendisi — kutu yüksekliği, ip, bant gerilimi veya bar konumu algılanmaz",
      movementIds: {"step_up"},
    ),
    "Force through the feet": (
      turkish: "Ayaklardan aktarılan kuvvet",
      movementIds: {"wall_sit"},
    ),
    "Jump height — the jump is 1-2 frames at phone frame rates, so the rule would confirm it happened and how you landed, not how high": (
      turkish:
          "Sıçrama yüksekliği — telefonların kare hızlarında sıçrama 1-2 kare sürer; bu nedenle kural ne kadar yükseğe sıçradığını değil, sıçramanın gerçekleştiğini ve nasıl yere indiğini doğrulardı",
      movementIds: {"burpee"},
    ),
    "Power or force output": (
      turkish: "Üretilen güç veya kuvvet",
      movementIds: {"burpee"},
    ),
    "Whether your chest actually touched the floor (unless you pick the chest-to-floor variant, where the rule would look at elbow bend)": (
      turkish:
          "Göğsünün gerçekten zemine değip değmediği (göğsün zemine değdiği varyantı seçmediğin sürece; o varyantta kural dirsek bükülmesine bakardı)",
      movementIds: {"burpee"},
    ),
    "Which part of the biceps is working": (
      turkish: "Biseps kasının hangi bölümünün çalıştığı",
      movementIds: {"db_curl"},
    ),
    "The dumbbell is not detected — load is not measured": (
      turkish: "Dambıl algılanmaz; yük ölçülmez",
      movementIds: {"db_row"},
    ),
    "Scapular retraction quality": (
      turkish: "Kürek kemiklerinin geriye çekilmesinin niteliği",
      movementIds: {"db_row"},
    ),
    "\"Chest touched the bar\" — the bar is not detected": (
      turkish: "\"Göğsün bara değmesi\" — bar algılanmaz",
      movementIds: {"inverted_row"},
    ),
    "Grip width": (turkish: "Kavrama genişliği", movementIds: {"inverted_row"}),
    "\"Chin over bar\" — the bar itself is not detected, so we judge your range by your own body, not by the bar": (
      turkish:
          "\"Çenenin barın üstüne çıkması\" — barın kendisi algılanmadığı için hareket açıklığını bara göre değil, kendi vücuduna göre değerlendiriyoruz",
      movementIds: {"pull_up"},
    ),
    "Grip width or grip type": (
      turkish: "Kavrama genişliği veya kavrama türü",
      movementIds: {"pull_up"},
    ),
    "The bars themselves are not detected": (
      turkish: "Barların kendisi algılanmaz",
      movementIds: {"dip"},
    ),
    "How far your chest travels relative to the bars": (
      turkish: "Göğsünün barlara göre ne kadar yol aldığı",
      movementIds: {"dip"},
    ),
    "Shoulder joint stress": (
      turkish: "Omuz ekleminin maruz kaldığı zorlanma",
      movementIds: {"db_shoulder_press"},
    ),
    "Which part of the deltoid is working": (
      turkish: "Deltoid kasının hangi bölümünün çalıştığı",
      movementIds: {"lateral_raise"},
    ),
    "Wrist torque or how hard you are pressing — the camera cannot measure force": (
      turkish:
          "El bileğindeki tork veya ne kadar kuvvetle ittiğin — kamera kuvveti ölçemez",
      movementIds: {"wall_handstand"},
    ),
    "How close to the wall you are": (
      turkish: "Duvara ne kadar yakın olduğun",
      movementIds: {"wall_handstand"},
    ),
    "Shoulder flexibility": (
      turkish: "Omuz esnekliği",
      movementIds: {"wall_handstand"},
    ),
    "How much of your weight is on the hands — the camera cannot measure load": (
      turkish:
          "Vücut ağırlığının ne kadarının ellerinin üzerinde olduğu — kamera yükü ölçemez",
      movementIds: {"tuck_planche"},
    ),
    "Wrist strain": (
      turkish: "El bileğindeki zorlanma",
      movementIds: {"tuck_planche"},
    ),
    "Scapular position": (
      turkish: "Kürek kemiklerinin konumu",
      movementIds: {"tuck_planche"},
    ),
  },
  CatalogueTextKind.comingSoon: {
    "Tempo while the set is running — the engine measures each rep's down and up timing from the real turnaround point, not from a threshold crossing, and that is proven on recorded footage. The summary at the end of a session now shows you the median down and up, so this is no longer fully missing. What is still missing: nothing shows your tempo while you are actually moving, and there is no per-rep breakdown — only the median for the whole set.": (
      turkish:
          "Set sırasında tempo — motor, her tekrarın iniş ve çıkış süresini bir eşik geçişinden değil, hareketin gerçekten yön değiştirdiği noktadan ölçer; bu, kaydedilmiş görüntüler üzerinde kanıtlanmıştır. Seans sonundaki özet artık iniş ve çıkış sürelerinin ortancasını gösteriyor; dolayısıyla bu özellik artık bütünüyle eksik değil. Hâlâ eksik olanlar: hareket ederken temponu gösteren bir şey yok ve tekrar başına ayrıntı sunulmuyor; yalnızca tüm setin ortancası gösteriliyor.",
      movementIds: {"bodyweight_squat"},
    ),
    "Knee range of motion per rep — same situation: the engine computes it for every rep, and nothing in the app displays it.": (
      turkish:
          "Tekrar başına diz hareket açıklığı — durum aynı: motor bunu her tekrar için hesaplıyor, ancak uygulamada hiçbir yerde gösterilmiyor.",
      movementIds: {"bodyweight_squat"},
    ),
    "Being told a rep was too shallow — the shallow-depth rule fires correctly on recorded footage, but during a live session no cue appears on screen, so nothing actually tells you.": (
      turkish:
          "Bir tekrarda yeterince derine inmediğinin bildirilmesi — yetersiz derinlik kuralı kaydedilmiş görüntüler üzerinde doğru biçimde uyarı veriyor, ancak canlı seansta ekranda uyarı görünmediği için sana bunu bildiren bir şey yok.",
      movementIds: {"bodyweight_squat"},
    ),
    "Depth and lean grading (forward lean / heel lift / butt wink) — the rules fire correctly on real footage and the reference is now ATTESTED, but knee, shin and torso tolerances are not variance-derived, so we show the cue and never a score": (
      turkish:
          "Derinlik ve eğim puanlaması (öne eğilme / topuğun kalkması / kalçanın alta kıvrılması) — kurallar gerçek görüntüler üzerinde doğru biçimde uyarı veriyor ve referansın kaynağı artık doğrulanmış (ATTESTED), ancak diz, kaval ve gövde toleransları varyanstan türetilmiş değil; bu nedenle uyarıyı gösteriyoruz, hiçbir zaman puan vermiyoruz",
      movementIds: {"bodyweight_squat"},
    ),
    "Side-dependent cues (\"your left knee is...\") — the pose model's left/right labels are not trustworthy in this camera setup, so all rules stay side-agnostic": (
      turkish:
          "Tarafa özgü uyarılar (\"sol dizin...\") — bu kamera kurulumunda poz modelinin sol/sağ etiketleri güvenilir değil; bu nedenle tüm kurallar taraf belirtmeden çalışmaya devam ediyor",
      movementIds: {"bodyweight_squat"},
    ),
    "Weight distribution and load — a single camera cannot see either; this is a permanent limit, not a pending measurement": (
      turkish:
          "Ağırlık dağılımı ve yük — tek bir kamera ikisini de göremez; bu, bekleyen bir ölçüm değil, kalıcı bir sınırdır",
      movementIds: {"bodyweight_squat"},
    ),
    "Tempo while the set is running — the engine measures each rep's down and up timing from the real turnaround point. The end-of-set summary shows the median down and up; there is no live or per-rep tempo display.": (
      turkish:
          "Set sırasında tempo — motor, her tekrarın iniş ve çıkış süresini hareketin gerçekten yön değiştirdiği noktadan ölçer. Set sonu özeti iniş ve çıkış sürelerinin ortancasını gösterir; canlı veya tekrar başına tempo gösterimi yoktur.",
      movementIds: {"push_up"},
    ),
    "Elbow range of motion per rep — same situation: the engine computes it for every rep, and nothing in the app displays it.": (
      turkish:
          "Tekrar başına dirsek hareket açıklığı — durum aynı: motor bunu her tekrar için hesaplıyor, ancak uygulamada hiçbir yerde gösterilmiyor.",
      movementIds: {"push_up"},
    ),
    "Being told a rep was too shallow — the shallow-rep rule fires correctly on recorded footage (8 of 8 rules live in the replay gate), but during a live session no cue appears on screen, so nothing actually tells you.": (
      turkish:
          "Bir tekrarda yeterince derine inmediğinin bildirilmesi — yetersiz derinlikte tekrar kuralı kaydedilmiş görüntüler üzerinde doğru biçimde uyarı veriyor (tekrar oynatma doğrulamasında 8 kuralın 8'i de etkin), ancak canlı seansta ekranda uyarı görünmediği için sana bunu bildiren bir şey yok.",
      movementIds: {"push_up"},
    ),
    "Body-line grading (hip sag / pike / head drop / uneven press) — the rules fire correctly on real footage and the reference is now ATTESTED, but no joint tolerance is variance-derived (derivedJoints empty; all 9 floor-bound), so we show the cue and never a score": (
      turkish:
          "Vücut hattı puanlaması (kalçanın sarkması / kalçanın yukarı kalkması / başın düşmesi / eşit olmayan itiş) — kurallar gerçek görüntüler üzerinde doğru biçimde uyarı veriyor ve referansın kaynağı artık doğrulanmış (ATTESTED), ancak hiçbir eklem toleransı varyanstan türetilmiş değil (derivedJoints alanı boş; 9 toleransın tamamı varsayılan alt sınırda); bu nedenle uyarıyı gösteriyoruz, hiçbir zaman puan vermiyoruz",
      movementIds: {"push_up"},
    ),
    "Side-dependent cues (\"your left arm is...\") — the pose model's left/right labels are not trustworthy in this camera setup, so all rules stay side-agnostic": (
      turkish:
          "Tarafa özgü uyarılar (\"sol kolun...\") — bu kamera kurulumunda poz modelinin sol/sağ etiketleri güvenilir değil; bu nedenle tüm kurallar taraf belirtmeden çalışmaya devam ediyor",
      movementIds: {"push_up"},
    ),
    "Hand pressure and load — a single camera cannot see either; this is a permanent limit, not a pending measurement": (
      turkish:
          "Ellerdeki basınç ve yük — tek bir kamera ikisini de göremez; bu, bekleyen bir ölçüm değil, kalıcı bir sınırdır",
      movementIds: {"push_up"},
    ),
    "Hold timing and body-line tracking — this movement's rules are written to measure carry duration, torso upright over time, shoulder level symmetry and time until posture starts to break, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Duruş süresinin ölçümü ve vücut hattının takibi — bu hareketin kuralları taşıma süresini, gövdenin zaman içindeki dikliğini, omuzların yükseklik simetrisini ve duruşun bozulmaya başlamasına kadar geçen süreyi ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"farmer_carry"},
    ),
    "Rep counting and tempo — this movement's rules are written to measure rep count, tempo, extension range, alignment of the extended arm and leg with your torso and hold time at the top, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Tekrar sayımı ve tempo — bu hareketin kuralları tekrar sayısını, tempoyu, uzatma hareketinin açıklığını, uzatılan kol ve bacağın gövdeyle hizasını ve en üst konumdaki bekleme süresini ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"bird_dog"},
    ),
    "Rep counting and tempo — this movement's rules are written to measure rep count, tempo, limb extension range, lower-back contact (via pelvis angle proxy) and left/right timing symmetry, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Tekrar sayımı ve tempo — bu hareketin kuralları tekrar sayısını, tempoyu, kol ve bacakları uzatma hareketinin açıklığını, belin temas durumunu (pelvis açısı dolaylı gösterge olarak kullanılarak) ve sol/sağ zamanlama simetrisini ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"dead_bug"},
    ),
    "Rep counting and tempo — this movement's rules are written to measure rep count, tempo, hip range of motion, swing between reps and knee bend, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Tekrar sayımı ve tempo — bu hareketin kuralları tekrar sayısını, tempoyu, kalça hareket açıklığını, tekrarlar arasındaki sallanmayı ve diz bükülmesini ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"hanging_leg_raise"},
    ),
    "Hold timing and body-line tracking — this movement's rules are written to measure hold duration, lower-back position over time, leg height over time and time until form starts to break, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Duruş süresinin ölçümü ve vücut hattının takibi — bu hareketin kuralları duruş süresini, belin zaman içindeki konumunu, bacakların zaman içindeki yüksekliğini ve formun bozulmaya başlamasına kadar geçen süreyi ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"hollow_hold"},
    ),
    "Rep counting and tempo — this movement's rules are written to measure rep count, cadence (reps per minute), plank body line while you drive the knees and pace consistency, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Tekrar sayımı ve tempo — bu hareketin kuralları tekrar sayısını, ritmi (dakikadaki tekrar sayısı), dizlerini çekerken plank vücut hattını ve temponun tutarlılığını ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"mountain_climber"},
    ),
    "Hold timing and body-line tracking — this movement's rules are written to measure hold duration, body-line alignment over time, time until form starts to break and shoulder position over elbows, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Duruş süresinin ölçümü ve vücut hattının takibi — bu hareketin kuralları duruş süresini, vücut hattının zaman içindeki hizasını, formun bozulmaya başlamasına kadar geçen süreyi ve omuzların dirseklerin üzerindeki konumunu ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"plank"},
    ),
    "Hold timing and body-line tracking — this movement's rules are written to measure hold duration, hip height over time and time until form starts to break, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Duruş süresinin ölçümü ve vücut hattının takibi — bu hareketin kuralları duruş süresini, kalçanın zaman içindeki yüksekliğini ve formun bozulmaya başlamasına kadar geçen süreyi ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"side_plank"},
    ),
    "Hold timing and body-line tracking — this movement's rules are written to measure hold duration, lift height over time and time until you start to drop, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Duruş süresinin ölçümü ve vücut hattının takibi — bu hareketin kuralları duruş süresini, zaman içindeki kaldırma yüksekliğini ve alçalmaya başlamana kadar geçen süreyi ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"superman_hold"},
    ),
    "Rep counting and tempo — this movement's rules are written to measure rep count, tempo, hip range of motion and swing between reps, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Tekrar sayımı ve tempo — bu hareketin kuralları tekrar sayısını, tempoyu, kalça hareket açıklığını ve tekrarlar arasındaki sallanmayı ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"toes_to_bar"},
    ),
    "Rep counting and tempo — this movement's rules are written to measure rep count, tempo (down/up timing) and setup checklist before the set starts, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Tekrar sayımı ve tempo — bu hareketin kuralları tekrar sayısını, tempoyu (iniş/çıkış süreleri) ve set başlamadan önceki kurulum kontrol listesini ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"floor_press"},
    ),
    "Rep counting and tempo — this movement's rules are written to measure rep count, cadence (swings per minute), hip hinge depth, torso angle at the top and knee bend (hinge vs squat check), and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Tekrar sayımı ve tempo — bu hareketin kuralları tekrar sayısını, ritmi (dakikadaki savurma sayısı), kalçadan eğilme derinliğini, en üst konumdaki gövde açısını ve diz bükülmesini (kalçadan eğilme ile squat ayrımının kontrolü) ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"kb_swing"},
    ),
    "Rep counting and tempo — this movement's rules are written to measure rep count, tempo (eccentric emphasis), hinge depth, lower-back position through the range and knee bend consistency, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Tekrar sayımı ve tempo — bu hareketin kuralları tekrar sayısını, tempoyu (eksantrik evre vurgusu), kalçadan eğilme derinliğini, hareket açıklığı boyunca belin konumunu ve diz bükülmesinin tutarlılığını ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"romanian_deadlift"},
    ),
    "Rep counting and tempo — this movement's rules are written to measure rep count, tempo, hip extension range at the top, hold time at the top and lower-back position, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Tekrar sayımı ve tempo — bu hareketin kuralları tekrar sayısını, tempoyu, en üst konumdaki kalça ekstansiyonu aralığını, en üst konumdaki bekleme süresini ve belin konumunu ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"glute_bridge"},
    ),
    "Rep counting and tempo — this movement's rules are written to measure rep count, tempo, squat depth (knee angle), torso angle and heel lift, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Tekrar sayımı ve tempo — bu hareketin kuralları tekrar sayısını, tempoyu, squat derinliğini (diz açısı), gövde açısını ve topuğun kalkmasını ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"goblet_squat"},
    ),
    "Rep counting and tempo — this movement's rules are written to measure rep count, tempo, front-knee depth, torso angle and back-knee travel, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Tekrar sayımı ve tempo — bu hareketin kuralları tekrar sayısını, tempoyu, ön diz derinliğini, gövde açısını ve arka dizin hareket mesafesini ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"lunge"},
    ),
    "Rep counting and tempo — this movement's rules are written to measure rep count, tempo, ankle range of motion and pause at the top, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Tekrar sayımı ve tempo — bu hareketin kuralları tekrar sayısını, tempoyu, ayak bileği hareket açıklığını ve en üst konumdaki beklemeyi ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"calf_raise"},
    ),
    "Rep counting and tempo — this movement's rules are written to measure rep count, tempo, knee range of motion, torso angle and which leg leads (by frame position, not by model l/r labels), and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Tekrar sayımı ve tempo — bu hareketin kuralları tekrar sayısını, tempoyu, diz hareket açıklığını, gövde açısını ve hangi bacağın önde olduğunu (modelin sol/sağ etiketleriyle değil, görüntü karesindeki konumuyla) ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"step_up"},
    ),
    "Hold timing and body-line tracking — this movement's rules are written to measure hold duration, knee angle over time and time until you start to rise, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Duruş süresinin ölçümü ve vücut hattının takibi — bu hareketin kuralları duruş süresini, dizin zaman içindeki açısını ve yükselmeye başlamana kadar geçen süreyi ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"wall_sit"},
    ),
    "Phase-by-phase tracking — this movement's rules are written to measure rep count, phase timing (how long each part takes), plank-position body line, landing softness and pace consistency across the set, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Evre evre takip — bu hareketin kuralları tekrar sayısını, evre sürelerini (her bölümün ne kadar sürdüğü), plank konumundaki vücut hattını, yere inişin yumuşaklığını ve set boyunca temponun tutarlılığını ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"burpee"},
    ),
    "Rep counting and tempo — this movement's rules are written to measure rep count, tempo (up/down), elbow range of motion, torso sway (cheating check) and left/right symmetry, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Tekrar sayımı ve tempo — bu hareketin kuralları tekrar sayısını, tempoyu (çıkış/iniş), dirsek hareket açıklığını, gövde sallanmasını (hareketi kolaylaştırmak için gövdeden destek alma kontrolü) ve sol/sağ simetrisini ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"db_curl"},
    ),
    "Rep counting and tempo — this movement's rules are written to measure rep count, tempo, elbow range of motion, torso angle stability (no rotating up) and working-side chain, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Tekrar sayımı ve tempo — bu hareketin kuralları tekrar sayısını, tempoyu, dirsek hareket açıklığını, gövde açısının sabitliğini (yukarı doğru dönmeden) ve çalışan taraftaki zinciri ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"db_row"},
    ),
    "Rep counting and tempo — this movement's rules are written to measure rep count, tempo, elbow range of motion, body-line alignment and hip sag, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Tekrar sayımı ve tempo — bu hareketin kuralları tekrar sayısını, tempoyu, dirsek hareket açıklığını, vücut hattının hizasını ve kalçanın sarkmasını ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"inverted_row"},
    ),
    "Rep counting and tempo — this movement's rules are written to measure rep count, tempo (pull/lower), elbow range of motion, vertical travel relative to your own torso length and swing and body line, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Tekrar sayımı ve tempo — bu hareketin kuralları tekrar sayısını, tempoyu (çekiş/iniş), dirsek hareket açıklığını, kendi gövde uzunluğuna göre dikey hareket mesafesini, sallanmayı ve vücut hattını ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"pull_up"},
    ),
    "Rep counting and tempo — this movement's rules are written to measure rep count, tempo, elbow range of motion, torso lean and shoulder position at the bottom, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Tekrar sayımı ve tempo — bu hareketin kuralları tekrar sayısını, tempoyu, dirsek hareket açıklığını, gövde eğimini ve en alt konumdaki omuz konumunu ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"dip"},
    ),
    "Rep counting and tempo — this movement's rules are written to measure rep count, tempo, elbow range of motion, torso lean (arching check) and left/right symmetry, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Tekrar sayımı ve tempo — bu hareketin kuralları tekrar sayısını, tempoyu, dirsek hareket açıklığını, gövde eğimini (kavislenme kontrolü) ve sol/sağ simetrisini ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"db_shoulder_press"},
    ),
    "Rep counting and tempo — this movement's rules are written to measure rep count, tempo, how high you raise (abduction angle), left/right height symmetry and torso sway, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Tekrar sayımı ve tempo — bu hareketin kuralları tekrar sayısını, tempoyu, ne kadar yükseğe kaldırdığını (abdüksiyon açısı), sol/sağ yükseklik simetrisini ve gövde sallanmasını ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"lateral_raise"},
    ),
    "Hold timing and body-line tracking — this movement's rules are written to measure hold duration, body-line alignment while inverted, elbow straightness, time until form starts to break and analysis confidence, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage and harvesting a real instructor reference.": (
      turkish:
          "Duruş süresinin ölçümü ve vücut hattının takibi — bu hareketin kuralları duruş süresini, baş aşağı konumdayken vücut hattının hizasını, dirseklerin düzlüğünü, formun bozulmaya başlamasına kadar geçen süreyi ve analizin güven düzeyini ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak ve gerçek bir eğitmen referansı toplamak.",
      movementIds: {"wall_handstand"},
    ),
    "Hold timing and body-line tracking — this movement's rules are written to measure hold duration, shoulder lean past the wrists, elbow straightness and time until the lean collapses, and none of it runs today. What would open it: deriving an identity check from measurement, running its rules against real recorded footage, harvesting a real instructor reference and building the measurement its start condition depends on.": (
      turkish:
          "Duruş süresinin ölçümü ve vücut hattının takibi — bu hareketin kuralları duruş süresini, omuzların el bileklerinin önüne eğilmesini, dirseklerin düzlüğünü ve öne eğimin bozulmasına kadar geçen süreyi ölçmek için yazılmıştır; bugün bunların hiçbiri çalışmıyor. Açılması için gerekenler: yapılan hareketi doğrulayan bir kontrolü ölçümden türetmek, kurallarını kaydedilmiş gerçek görüntüler üzerinde çalıştırmak, gerçek bir eğitmen referansı toplamak ve başlangıç koşulunun bağlı olduğu ölçümü oluşturmak.",
      movementIds: {"tuck_planche"},
    ),
  },
  CatalogueTextKind.ruleLabel: {
    "Arching your back to reach higher": (
      turkish: "Daha yükseğe uzanmak için sırtı çukurlaştırmak",
      movementIds: {"bird_dog"},
    ),
    "Arm and leg off the body line": (
      turkish: "Kol ve bacağın vücut hizasından çıkması",
      movementIds: {"bird_dog"},
    ),
    "Not squatting deep enough": (
      turkish: "Squat sırasında yeterince aşağı inmemek",
      movementIds: {"bodyweight_squat", "goblet_squat"},
    ),
    "Chest dropping forward": (
      turkish: "Göğsün öne düşmesi",
      movementIds: {"bodyweight_squat", "lunge"},
    ),
    "Heels coming up": (
      turkish: "Topukların yerden kalkması",
      movementIds: {"bodyweight_squat", "goblet_squat"},
    ),
    "Lower back rounding at the bottom": (
      turkish: "Alt konumda belin yuvarlanması",
      movementIds: {"bodyweight_squat", "kb_swing"},
    ),
    "Landing with locked knees": (
      turkish: "Dizler kilitliyken yere inmek",
      movementIds: {"burpee"},
    ),
    "Hips sagging in the plank": (
      turkish: "Plank konumunda kalçanın aşağı sarkması",
      movementIds: {"burpee"},
    ),
    "Skipping part of the rep": (
      turkish: "Tekrarın bir bölümünü atlamak",
      movementIds: {"burpee"},
    ),
    "Pace dropping off": (turkish: "Temponun düşmesi", movementIds: {"burpee"}),
    "Not rising high enough": (
      turkish: "Yeterince yükseğe çıkmamak",
      movementIds: {"calf_raise"},
    ),
    "Bouncing through the reps": (
      turkish: "Tekrarları yaylanarak yapmak",
      movementIds: {"calf_raise"},
    ),
    "Lower back lifting off the floor": (
      turkish: "Belin yerden kalkması",
      movementIds: {"dead_bug"},
    ),
    "Moving too fast to control it": (
      turkish: "Kontrol edilemeyecek kadar hızlı hareket etmek",
      movementIds: {"dead_bug"},
    ),
    "Not going deep enough": (
      turkish: "Yeterince aşağı inmemek",
      movementIds: {"dip", "push_up"},
    ),
    "Leaning too far forward": (
      turkish: "Öne fazla eğilmek",
      movementIds: {"dip", "step_up"},
    ),
    "Shoulders rising at the bottom": (
      turkish: "Alt konumda omuzların yükselmesi",
      movementIds: {"dip"},
    ),
    "Not reaching full hip extension": (
      turkish: "Kalçayı tam doğrultmamak",
      movementIds: {"glute_bridge"},
    ),
    "Arching your back instead of extending your hips": (
      turkish: "Kalçayı doğrultmak yerine sırtı çukurlaştırmak",
      movementIds: {"glute_bridge"},
    ),
    "Not raising high enough": (
      turkish: "Yeterince yükseğe kaldırmamak",
      movementIds: {"hanging_leg_raise", "lateral_raise"},
    ),
    "Using swing to get up": (
      turkish: "Yukarı çıkmak için sallanmadan yararlanmak",
      movementIds: {"hanging_leg_raise"},
    ),
    "Knees bending a lot": (
      turkish: "Dizlerin çok bükülmesi",
      movementIds: {"hanging_leg_raise"},
    ),
    "Lower back lifting": (
      turkish: "Belin yukarı kalkması",
      movementIds: {"hollow_hold"},
    ),
    "Legs dropping": (
      turkish: "Bacakların düşmesi",
      movementIds: {"hollow_hold"},
    ),
    "Hips dropping": (
      turkish: "Kalçanın düşmesi",
      movementIds: {"inverted_row", "plank", "push_up"},
    ),
    "Not pulling far enough": (
      turkish: "Çekiş mesafesinin yetersiz kalması",
      movementIds: {"inverted_row", "db_row"},
    ),
    "Not lunging deep enough": (
      turkish: "Lunge sırasında yeterince aşağı inmemek",
      movementIds: {"lunge"},
    ),
    "Front knee sliding far past the toes": (
      turkish: "Öndeki dizin ayak parmaklarının çok ötesine kayması",
      movementIds: {"lunge"},
    ),
    "Hips riding high": (
      turkish: "Kalçanın yukarıda kalması",
      movementIds: {"mountain_climber"},
    ),
    "Knees not coming through": (
      turkish: "Dizlerin yeterince öne gelmemesi",
      movementIds: {"mountain_climber"},
    ),
    "Hips too high": (
      turkish: "Kalçanın fazla yukarıda olması",
      movementIds: {"plank", "push_up"},
    ),
    "Head hanging": (turkish: "Başın aşağı sarkması", movementIds: {"plank"}),
    "Not pulling high enough": (
      turkish: "Yeterince yükseğe çekmemek",
      movementIds: {"pull_up"},
    ),
    "Not reaching a full hang": (
      turkish: "Tam asılma konumuna gelmemek",
      movementIds: {"pull_up"},
    ),
    "Swinging to get up": (
      turkish: "Yukarı çıkmak için sallanmak",
      movementIds: {"pull_up"},
    ),
    "Shoulders up by your ears": (
      turkish: "Omuzların kulaklara kadar yükselmesi",
      movementIds: {"pull_up"},
    ),
    "Head dropping": (turkish: "Başın düşmesi", movementIds: {"push_up"}),
    "Pressing unevenly": (
      turkish: "İtişi eşit yapmamak",
      movementIds: {"push_up"},
    ),
    "Hips sinking": (
      turkish: "Kalçanın aşağı çökmesi",
      movementIds: {"side_plank"},
    ),
    "Pushing off the back foot": (
      turkish: "Arkadaki ayakla iterek yükselmek",
      movementIds: {"step_up"},
    ),
    "Cranking your neck back": (
      turkish: "Boynu zorlayarak geriye bükmek",
      movementIds: {"superman_hold"},
    ),
    "Not closing the hips enough": (
      turkish: "Kalça açısını yeterince kapatmamak",
      movementIds: {"toes_to_bar"},
    ),
    "Big swing between reps": (
      turkish: "Tekrarlar arasında fazla sallanmak",
      movementIds: {"toes_to_bar"},
    ),
    "Sitting too high": (
      turkish: "Fazla yukarıda oturmak",
      movementIds: {"wall_sit"},
    ),
    "Swinging your body to lift": (
      turkish: "Kaldırmak için vücudu sallamak",
      movementIds: {"db_curl"},
    ),
    "Not straightening at the bottom": (
      turkish: "Alt konumda kolları düzleştirmemek",
      movementIds: {"db_curl"},
    ),
    "Rotating your torso to pull": (
      turkish: "Çekmek için gövdeyi döndürmek",
      movementIds: {"db_row"},
    ),
    "Arching your back to press": (
      turkish: "İtmek için sırtı çukurlaştırmak",
      movementIds: {"db_shoulder_press"},
    ),
    "Not locking out overhead": (
      turkish: "Baş üstünde kolları tam düzleştirmemek",
      movementIds: {"db_shoulder_press"},
    ),
    "Leaning while walking": (
      turkish: "Yürürken eğilmek",
      movementIds: {"farmer_carry"},
    ),
    "Squatting instead of hinging": (
      turkish: "Kalçadan eğilmek yerine çömelmek",
      movementIds: {"kb_swing"},
    ),
    "Not standing all the way up": (
      turkish: "Tamamen doğrulmamak",
      movementIds: {"kb_swing"},
    ),
    "Using body swing to lift": (
      turkish: "Vücudu sallayarak kaldırmak",
      movementIds: {"lateral_raise"},
    ),
    "Lower back rounding": (
      turkish: "Belin yuvarlanması",
      movementIds: {"romanian_deadlift"},
    ),
    "Bending the knees too much": (
      turkish: "Dizleri fazla bükmek",
      movementIds: {"romanian_deadlift"},
    ),
    "Not hinging far enough": (
      turkish: "Kalçadan yeterince eğilmemek",
      movementIds: {"romanian_deadlift"},
    ),
    "Losing the forward lean": (
      turkish: "Öne eğimi kaybetmek",
      movementIds: {"tuck_planche"},
    ),
    "Elbows bending": (
      turkish: "Dirseklerin bükülmesi",
      movementIds: {"tuck_planche", "wall_handstand"},
    ),
    "Arching through the lower back": (
      turkish: "Belin çukurlaşması",
      movementIds: {"wall_handstand"},
    ),
  },
  CatalogueTextKind.ruleCue: {
    "Reach long, not high — keep your back flat.": (
      turkish: "Yükseğe değil, uzağa uzan — sırtını düz tut.",
      movementIds: {"bird_dog"},
    ),
    "Reach straight back and straight forward, in line with your body.": (
      turkish: "Vücudunla aynı hizada, dümdüz geriye ve dümdüz ileriye uzan.",
      movementIds: {"bird_dog"},
    ),
    "Sit down lower — aim for your thighs parallel to the floor.": (
      turkish: "Daha aşağı otur — uyluklarının yere paralel olmasını hedefle.",
      movementIds: {"bodyweight_squat"},
    ),
    "Chest up — sit back into your hips instead of leaning over.": (
      turkish:
          "Göğsünü dik tut — öne eğilmek yerine kalçanı geriye vererek otur.",
      movementIds: {"bodyweight_squat"},
    ),
    "Keep your heels down — take a slightly wider stance if you need to.": (
      turkish:
          "Topuklarını yerde tut — gerekirse ayaklarını biraz daha geniş aç.",
      movementIds: {"bodyweight_squat"},
    ),
    "Stop just above the depth where your lower back starts to round.": (
      turkish: "Belinin yuvarlanmaya başladığı derinliğin hemen üzerinde dur.",
      movementIds: {"bodyweight_squat"},
    ),
    "Land softly — bend your knees as you hit the floor.": (
      turkish: "Yumuşak bir iniş yap — yere temas ederken dizlerini bük.",
      movementIds: {"burpee"},
    ),
    "Hold a tight line when you kick your feet back.": (
      turkish: "Ayaklarını geriye attığında vücudunu sıkı ve aynı hizada tut.",
      movementIds: {"burpee"},
    ),
    "Full rep: chest down, feet in, jump up.": (
      turkish: "Tam tekrar: göğsünü indir, ayaklarını içeri çek, yukarı sıçra.",
      movementIds: {"burpee"},
    ),
    "Your pace is slowing — shorten the pause at the top.": (
      turkish: "Tempon yavaşlıyor — üst konumdaki beklemeyi kısalt.",
      movementIds: {"burpee"},
    ),
    "Push all the way up onto the balls of your feet.": (
      turkish: "Ayaklarının tarak kısmına basarak en üst noktaya kadar yüksel.",
      movementIds: {"calf_raise"},
    ),
    "Slow down — pause at the top of each rep.": (
      turkish: "Yavaşla — her tekrarın üst noktasında durakla.",
      movementIds: {"calf_raise"},
    ),
    "Press your lower back down — shorten the reach until you can hold it.": (
      turkish:
          "Belini aşağı bastır — bu konumu koruyabilene kadar uzanma mesafeni kısalt.",
      movementIds: {"dead_bug"},
    ),
    "Slow down — extend and return with control.": (
      turkish: "Yavaşla — kontrollü şekilde uzat ve geri getir.",
      movementIds: {"dead_bug"},
    ),
    "Lower until your upper arms are about parallel to the floor.": (
      turkish: "Üst kolların yaklaşık yere paralel olana kadar alçal.",
      movementIds: {"dip"},
    ),
    "Keep your chest more upright unless you're targeting chest on purpose.": (
      turkish:
          "Özellikle göğüs kaslarını hedeflemiyorsan göğsünü daha dik tut.",
      movementIds: {"dip"},
    ),
    "Push your shoulders down away from your ears at the bottom.": (
      turkish: "Alt konumda omuzlarını kulaklarından uzaklaştırarak aşağı it.",
      movementIds: {"dip"},
    ),
    "Squeeze your glutes and push your hips all the way up.": (
      turkish: "Kalça kaslarını sık ve kalçanı en üst noktaya kadar it.",
      movementIds: {"glute_bridge"},
    ),
    "Stop where your glutes do the work — don't arch your back to go higher.": (
      turkish:
          "İşi kalça kaslarının yaptığı noktada dur — daha yükseğe çıkmak için sırtını çukurlaştırma.",
      movementIds: {"glute_bridge"},
    ),
    "Bring your thighs up to at least parallel.": (
      turkish: "Uyluklarını en az paralel konuma kadar kaldır.",
      movementIds: {"hanging_leg_raise"},
    ),
    "Stop the swing — pause at the bottom before the next rep.": (
      turkish:
          "Sallanmayı durdur — sonraki tekrardan önce alt konumda durakla.",
      movementIds: {"hanging_leg_raise"},
    ),
    "Keep your legs straighter if you can, or switch to knee raises.": (
      turkish:
          "Yapabiliyorsan bacaklarını daha düz tut veya diz kaldırmaya geç.",
      movementIds: {"hanging_leg_raise"},
    ),
    "Press your lower back down — tuck your knees in if you need to.": (
      turkish: "Belini aşağı bastır — gerekirse dizlerini kendine çek.",
      movementIds: {"hollow_hold"},
    ),
    "Lift your legs back up.": (
      turkish: "Bacaklarını yeniden yukarı kaldır.",
      movementIds: {"hollow_hold"},
    ),
    "Squeeze your glutes — stay in one straight line.": (
      turkish: "Kalça kaslarını sık — vücudunu tek bir düz çizgi halinde tut.",
      movementIds: {"inverted_row"},
    ),
    "Pull until your elbows are well past your torso.": (
      turkish: "Dirseklerin gövdeni belirgin biçimde geçene kadar çek.",
      movementIds: {"inverted_row"},
    ),
    "Drop your back knee closer to the floor.": (
      turkish: "Arkadaki dizini yere daha fazla yaklaştır.",
      movementIds: {"lunge"},
    ),
    "Stay tall — think of your torso as a column.": (
      turkish: "Dik dur — gövdeni bir sütun gibi düşün.",
      movementIds: {"lunge"},
    ),
    "Take a slightly longer step so your shin stays more upright.": (
      turkish:
          "Kaval kemiğinin daha dik kalması için biraz daha uzun bir adım at.",
      movementIds: {"lunge"},
    ),
    "Drop your hips — hold the plank line while your knees drive.": (
      turkish: "Kalçanı indir — dizlerini çekerken plank hizasını koru.",
      movementIds: {"mountain_climber"},
    ),
    "Drive your knee further towards your chest.": (
      turkish: "Dizini göğsüne doğru daha fazla çek.",
      movementIds: {"mountain_climber"},
    ),
    "Squeeze your glutes and lift your hips back into line.": (
      turkish:
          "Kalça kaslarını sık ve kalçanı yeniden hizaya getirecek kadar kaldır.",
      movementIds: {"plank"},
    ),
    "Drop your hips until your body is one straight line.": (
      turkish: "Vücudun tek bir düz çizgi oluşturana kadar kalçanı indir.",
      movementIds: {"plank"},
    ),
    "Keep your neck long — look at the floor just ahead of your hands.": (
      turkish: "Boynunu uzun tut — ellerinin hemen ilerisindeki yere bak.",
      movementIds: {"plank"},
    ),
    "Pull until your elbows are fully bent — drive them down to your ribs.": (
      turkish:
          "Dirseklerin tamamen bükülene kadar çek — dirseklerini kaburgalarına doğru aşağı çek.",
      movementIds: {"pull_up"},
    ),
    "Straighten your arms at the bottom of every rep.": (
      turkish: "Her tekrarın alt noktasında kollarını düzleştir.",
      movementIds: {"pull_up"},
    ),
    "Stop the swing — squeeze your glutes and pull with your back.": (
      turkish: "Sallanmayı durdur — kalça kaslarını sık ve sırtınla çek.",
      movementIds: {"pull_up"},
    ),
    "Pull your shoulders down away from your ears before you bend your arms.": (
      turkish:
          "Kollarını bükmeden önce omuzlarını kulaklarından uzaklaştırarak aşağı çek.",
      movementIds: {"pull_up"},
    ),
    "Squeeze your glutes and keep a straight line from head to heels.": (
      turkish:
          "Kalça kaslarını sık ve başından topuklarına kadar vücudunu düz tut.",
      movementIds: {"push_up"},
    ),
    "Lower your hips until your body is one straight line.": (
      turkish: "Vücudun tek bir düz çizgi oluşturana kadar kalçanı alçalt.",
      movementIds: {"push_up"},
    ),
    "Go lower — bend your elbows until your chest is close to the floor.": (
      turkish: "Daha aşağı in — göğsün yere yaklaşana kadar dirseklerini bük.",
      movementIds: {"push_up"},
    ),
    "Look at the floor just ahead of your hands, not straight down.": (
      turkish: "Dümdüz aşağıya değil, ellerinin hemen ilerisindeki yere bak.",
      movementIds: {"push_up"},
    ),
    "Push evenly with both arms.": (
      turkish: "Her iki kolunla eşit şekilde it.",
      movementIds: {"push_up"},
    ),
    "Lift your hips back into a straight line.": (
      turkish: "Kalçanı yeniden düz bir hizaya gelecek şekilde kaldır.",
      movementIds: {"side_plank"},
    ),
    "Stand up through the front leg instead of throwing your chest forward.": (
      turkish:
          "Göğsünü öne atmak yerine öndeki bacağından güç alarak ayağa kalk.",
      movementIds: {"step_up"},
    ),
    "Let the top leg do the work — minimise the push from the bottom foot.": (
      turkish:
          "İşi üstteki bacağın yapsın — alttaki ayağınla yaptığın itişi en aza indir.",
      movementIds: {"step_up"},
    ),
    "Look at the floor — keep your neck in line with your spine.": (
      turkish: "Yere bak — boynunu omurganla aynı hizada tut.",
      movementIds: {"superman_hold"},
    ),
    "Bring your feet higher — close the hips fully.": (
      turkish: "Ayaklarını daha yükseğe getir — kalça açını tamamen kapat.",
      movementIds: {"toes_to_bar"},
    ),
    "Control the swing on the way down.": (
      turkish: "Aşağı inerken sallanmayı kontrol et.",
      movementIds: {"toes_to_bar"},
    ),
    "Slide down until your thighs are about parallel to the floor.": (
      turkish: "Uylukların yaklaşık yere paralel olana kadar aşağı kay.",
      movementIds: {"wall_sit"},
    ),
    "Stand still — let your arms do the work.": (
      turkish: "Sabit dur — işi kolların yapsın.",
      movementIds: {"db_curl"},
    ),
    "Straighten your arms fully at the bottom of every rep.": (
      turkish: "Her tekrarın alt noktasında kollarını tamamen düzleştir.",
      movementIds: {"db_curl"},
    ),
    "Keep your chest still — pull with your back, not by twisting.": (
      turkish: "Göğsünü sabit tut — gövdeni döndürerek değil, sırtınla çek.",
      movementIds: {"db_row"},
    ),
    "Pull your elbow past your ribs.": (
      turkish: "Dirseğini kaburgalarını geçecek kadar çek.",
      movementIds: {"db_row"},
    ),
    "Ribs down — press with your shoulders, not your lower back.": (
      turkish: "Kaburgalarını aşağıda tut — belinle değil, omuzlarınla it.",
      movementIds: {"db_shoulder_press"},
    ),
    "Press all the way until your arms are straight.": (
      turkish: "Kolların düz olana kadar sonuna kadar it.",
      movementIds: {"db_shoulder_press"},
    ),
    "Stand taller — ribs down, shoulders back.": (
      turkish: "Daha dik dur — kaburgaların aşağıda, omuzların geride olsun.",
      movementIds: {"farmer_carry"},
    ),
    "Sit lower — aim for thighs parallel.": (
      turkish: "Daha aşağı otur — uyluklarının paralel olmasını hedefle.",
      movementIds: {"goblet_squat"},
    ),
    "Keep your heels down — widen your stance if you need to.": (
      turkish: "Topuklarını yerde tut — gerekirse ayaklarını daha geniş aç.",
      movementIds: {"goblet_squat"},
    ),
    "Push your hips back instead of bending your knees.": (
      turkish: "Dizlerini bükmek yerine kalçanı geriye it.",
      movementIds: {"kb_swing"},
    ),
    "Snap your hips fully straight at the top.": (
      turkish: "Üst noktada kalçanı hızlı bir hareketle tamamen doğrult.",
      movementIds: {"kb_swing"},
    ),
    "Keep your chest proud — stop the hinge before your back rounds.": (
      turkish:
          "Göğsünü dik tut — sırtın yuvarlanmadan önce kalçadan eğilmeyi durdur.",
      movementIds: {"kb_swing"},
    ),
    "Stand still — let your shoulders do the work.": (
      turkish: "Sabit dur — işi omuzların yapsın.",
      movementIds: {"lateral_raise"},
    ),
    "Raise until your arms are about shoulder height.": (
      turkish: "Kolların yaklaşık omuz hizasına gelene kadar kaldır.",
      movementIds: {"lateral_raise"},
    ),
    "Stop the hinge where your back is still flat.": (
      turkish: "Kalçadan eğilmeyi sırtının hâlâ düz olduğu noktada durdur.",
      movementIds: {"romanian_deadlift"},
    ),
    "Keep your knees softly bent — push your hips back instead.": (
      turkish: "Dizlerini hafif bükülü tut — bunun yerine kalçanı geriye it.",
      movementIds: {"romanian_deadlift"},
    ),
    "Push your hips further back until you feel your hamstrings load.": (
      turkish:
          "Arka uyluk kaslarına yük bindiğini hissedene kadar kalçanı daha geriye it.",
      movementIds: {"romanian_deadlift"},
    ),
    "Push your shoulders further past your hands.": (
      turkish:
          "Omuzlarını, ellerinin hizasını daha da geçecek şekilde ileri it.",
      movementIds: {"tuck_planche"},
    ),
    "Lock your elbows — bent arms put the load on the joint.": (
      turkish: "Dirseklerini kilitle — bükülü kollar yükü ekleme bindirir.",
      movementIds: {"tuck_planche"},
    ),
    "Ribs down, squeeze your glutes — flatten the line.": (
      turkish:
          "Kaburgalarını aşağıda tut, kalça kaslarını sık — vücut hattını düzleştir.",
      movementIds: {"wall_handstand"},
    ),
    "Push the floor away — straighten your arms.": (
      turkish: "Zemini kendinden uzağa it — kollarını düzleştir.",
      movementIds: {"wall_handstand"},
    ),
  },
};
