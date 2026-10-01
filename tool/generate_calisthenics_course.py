#!/usr/bin/env python3
"""Original TR/EN authoring source. No source media or model training data."""
import argparse
import copy
import hashlib
import json
from pathlib import Path

def b(text):
    en,tr=text.split('|',1)
    return {'en':en,'tr':tr}

sources=[
('acsm2026','ACSM: 2026 resistance training guidance','https://acsm.org/resistance-training-guidelines-update-2026/'),
('who','WHO: Physical activity','https://www.who.int/initiatives/behealthy/physical-activity'),
('nhs_strength','NHS: Strength exercises','https://www.nhs.uk/live-well/exercise/strength-exercises/'),
('ace','ACE: Exercise library','https://www.acefitness.org/resources/everyone/exercise-library/'),
('ace_bird','ACE: Bird-dog','https://www.acefitness.org/resources/everyone/exercise-library/14/bird-dog/'),
('nasm_push','NASM: Push-up','https://www.nasm.org/resource-center/exercise-library/push-up'),
('nasm_pull','NASM: Pull-up','https://www.nasm.org/resource-center/exercise-library/pull-up'),
('nasm_plank','NASM: Plank','https://www.nasm.org/resource-center/exercise-library/plank'),
('nasm_dead','NASM: Dead bug','https://www.nasm.org/resource-center/exercise-library/dead-bug'),
('nasm_pike','NASM: Pike push-up','https://www.nasm.org/resource-center/exercise-library/pike-push-up'),
('acog','ACOG: Exercise during pregnancy','https://www.acog.org/womens-health/faqs/exercise-during-pregnancy'),
('nhs_pregnancy','NHS: Exercise in pregnancy','https://www.nhs.uk/pregnancy/keeping-well/exercise/'),
]
modules=[]
lesson_count=0
previous=None

def module(id,title,source_ids):
    modules.append({'id':id,'title':b(title),'lessons':[],'source_ids':source_ids})

def lesson(title,objective,steps,practice,checks,easier,stop,shot,kind='physical',extra=()):
    global lesson_count,previous
    lesson_count+=1
    id=f'cal-{lesson_count:02d}'
    assert len(steps)==3 and len(checks)==2
    prefix='Original adult demonstrator, neutral Gravita studio, full body and equipment visible; no copied instructor likeness or source footage. Technical coach review before release. Focus: |Özgün yetişkin model, nötr Gravita stüdyosu, beden ve ekipman kadrajda; eğitmen benzerliği veya kaynak görüntü kopyası yok. Yayından önce teknik eğitmen incelemesi. Odak: '
    en,tr=prefix.split('|'); se,st=shot.split('|')
    modules[-1]['lessons'].append({'id':id,'title':b(title),'objective':b(objective),'steps':[b(s) for s in steps],'practice':b(practice),'selfCheck':[b(c) for c in checks],'adaptation':b(easier),'stop':b(stop),'sourceIds':list(dict.fromkeys(modules[-1]['source_ids']+list(extra))),'prerequisites':[] if previous is None else [previous],'minutes':8 if kind=='physical' else 6,'practiceType':kind,'evidenceMode':'self_report','mediaBrief':{'en':en+se,'tr':tr+st}})
    previous=id

module('foundations','Build a repeatable foundation|Tekrarlanabilir temel kur',['acsm2026','who','nhs_strength'])
lesson('Your training space|Çalışma alanın','Prepare stable supports before loading them.|Yük vermeden önce destekleri hazırla.',[
'Clear a non-slip floor and enough room for a full reach; keep pets and loose objects outside it.|Kaymayan zemini ve tam uzanma alanını boşalt; evcil hayvan ve gevşek eşyaları dışarıda tut.',
'Use a chair without wheels against a wall; check the mat and your footwear for sliding.|Tekerleksiz sandalyeyi duvara daya; mat ve ayakkabının kaymasını kontrol et.',
'Pulling needs a purpose-built, correctly installed, load-rated bar; a table or door trim is not a substitute.|Çekiş için amaca uygun, doğru takılmış, taşıma sınırı bilinen bar gerekir; masa veya kapı pervazı yerine geçmez.'],
'Learning task: inspect the space once and describe where you will stand, sit and exit. Squat and pressing practice starts after their technique lessons.|Öğrenme görevi: alanı bir kez incele, duracağın, oturacağın ve çıkacağın yeri tarif et. Squat ve itiş pratiği teknik derslerinden sonra başlar.',
['Nothing moves when I gently test the support.|Desteği hafifçe kontrol ettiğimde oynamıyor.','I can exit the space without stepping over equipment.|Ekipmanın üzerinden geçmeden alandan çıkabiliyorum.'],
'Begin with seated learning and wall-based movements; equipment lessons can be studied without performing them.|Oturarak öğrenme ve duvar hareketleriyle başla; ekipman derslerini uygulamadan inceleyebilirsin.',
'Do not load a loose, damaged or unrated support.|Gevşek, hasarlı veya taşıma sınırı belirsiz desteğe yük verme.',
'Two separate scenes: first a stable wheel-free chair against a wall with all chair feet on the floor and no load-rating claim; then a purpose-built pulling bar with its correctly installed mount and actual manufacturer-marked load-rating label, only after a human technical check of that equipment and installation. Never fabricate a label or numeric rating, never use a chair label as proof for the bar, and withhold the bar scene if verification is unavailable; no improvised anchor.|İki ayrı sahne: önce duvara dayalı tekerleksiz sağlam sandalye ve zemine basan bütün ayakları, sandalye için taşıma sınırı iddiası olmadan; sonra yalnız ekipman ve kurulum insan teknik incelemesinden geçince amaca uygun çekiş barının doğru takılmış bağlantısı ve gerçek üretici taşıma sınırı etiketi. Etiket veya sayısal sınır uydurma, sandalye etiketini barın kanıtı sayma; doğrulama yoksa bar sahnesini yayımlama, doğaçlama bağlantı kullanma.',kind='learning_only')
lesson('Health and the right to adapt|Sağlık ve uyarlama hakkı','Recognize when a lesson needs individual advice.|Bir dersin ne zaman bireysel danışma gerektirdiğini tanı.',[
'Read the health notice before choosing a physical variant; pain is not a required training stimulus.|Fiziksel varyasyonu seçmeden sağlık notunu oku; ağrı gerekli bir antrenman uyaranı değildir.',
'For injury, surgery, pregnancy or a chronic condition, discuss suitable activities with your clinician or qualified professional.|Yaralanma, ameliyat, gebelik veya kronik durumda uygun etkinlikleri klinisyenin ya da yetkin uzmanla görüş.',
'During pregnancy do not use this course to begin fall-risk inversions; prolonged flat-on-back tasks need adaptation with your care team.|Gebelikte bu kursla düşme riski taşıyan ters duruşlara başlama; uzun sırtüstü görevler bakım ekibiyle uyarlanmalıdır.'],
'Write one personal question for a qualified professional and identify a supported alternative; this is a learning task, not a screening test.|Yetkin uzmana soracağın bir soruyu yaz ve destekli bir alternatif belirle; bu bir öğrenme görevi, sağlık taraması değildir.',
['I know how to pause rather than chase the next lesson.|Sonraki derse yetişmek yerine nasıl duracağımı biliyorum.','I have not treated a completed lesson as medical clearance.|Tamamlanan dersi tıbbi uygunluk izni saymadım.'],
'Read the course without physical practice while obtaining advice; no diagnostic answer is collected.|Danışma alırken fiziksel uygulama yapmadan kursu oku; tanısal yanıt toplanmaz.',
'Stop for chest pain, faintness or unusual breathlessness; seek appropriate care. Pregnancy bleeding, fluid leakage or painful contractions need prompt care-team advice.|Göğüs ağrısı, baygınlık hissi veya alışılmadık nefes darlığında dur ve uygun sağlık desteği al. Gebelikte kanama, sıvı sızıntısı veya ağrılı kasılma için bakım ekibine hemen danış.',
'Calm seated presenter and supported standing alternative; no pregnancy inversion demonstration.|Sakin oturan anlatıcı ve ayakta destekli alternatif; gebelikte ters duruş gösterimi yok.',kind='learning_only',extra=['acog','nhs_pregnancy'])
lesson('Breathing and effort|Nefes ve efor','Use subjective effort to choose a manageable task.|Yönetilebilir görev için öznel eforu kullan.',[
'First observe ordinary breathing while seated; later, in taught movements, keep breathing and allow an unforced exhale during effort.|Önce oturarak normal nefesi gözle; sonra öğretilen hareketlerde nefesi sürdür ve eforda zorlanmayan nefes ver.',
'Use a personal 0–10 effort scale, where 0 is rest and 10 is your maximum; an initial 3–5 is an option, not a medical limit.|0 dinlenme, 10 kendi en yüksek eforun olan 0–10 ölçeğini kullan; başlangıçta 3–5 bir seçenek, tıbbi sınır değildir.',
'End a set before breathing or coordination breaks down; keep several comfortable repetitions in reserve.|Nefes veya koordinasyon bozulmadan seti bitir; birkaç rahat tekrar daha yapabilecek pay bırak.'],
'Sit comfortably with feet supported and take 3 ordinary unforced breaths; describe rest on your effort scale. Do not hold your breath or test maximum effort.|Ayaklar destekli rahat otur ve zorlamadan 3 normal nefes al; efor ölçeğinde dinlenmeyi tarif et. Nefes tutma veya en yüksek eforu test etme.',
['I can describe my effort rather than guess a camera score.|Kamera puanı tahmin etmek yerine eforumu tarif edebiliyorum.','I did not hold or force my breathing.|Nefesimi tutmadım veya zorlamadım.'],
'Reduce repetitions or move to seated practice; during pregnancy use the care-team guidance and conversational effort.|Tekrarı azalt veya oturarak çalış; gebelikte bakım ekibinin önerisi ve konuşabilecek eforu kullan.',
'Stop if breathlessness is unusual for you, or dizziness or chest discomfort appears.|Sana alışılmadık nefes darlığı, baş dönmesi ya da göğüs rahatsızlığı olursa dur.',
'Seated natural breathing observation and effort-scale diagram; no physical press before its lesson.|Oturarak doğal nefes gözlemi ve efor ölçeği şeması; dersinden önce fiziksel itiş yok.',kind='learning_only')
lesson('Warm up the supports|Destekleri ısıt','Prepare wrists, shoulders and legs gradually.|Bilek, omuz ve bacakları kademeli hazırla.',[
'Begin with easy walking or seated marching rather than a cold maximal hold.|Soğuk en uzun tutuş yerine rahat yürüyüş veya oturarak adımlamayla başla.',
'Move shoulders and wrists gently in comfortable ranges; keep wrist loading light at a wall.|Omuz ve bileği rahat aralıkta nazikçe hareket ettir; bileğe duvarda hafif yük ver.',
'Keep this warm-up to familiar gentle movements; later add taught regressions, leaving energy for learning.|Bu ısınmayı tanıdık nazik hareketlerle sınırla; sonra öğretilen kolay yolları ekle ve öğrenmeye enerji bırak.'],
'Choose 2–4 minutes of familiar easy walking or seated marching; then 4 small comfortable shoulder circles each way and 4 unloaded wrist movements.|2–4 dakika tanıdık rahat yürüyüş veya oturarak adımlama seç; ardından iki yönde 4 küçük rahat omuz dairesi ve yüksüz 4 bilek hareketi yap.',
['The range stays comfortable without forcing the joint.|Eklem zorlanmadan hareket aralığı rahat kalıyor.','I feel prepared, not fatigued.|Yorgun değil, hazır hissediyorum.'],
'Use smaller seated circles and omit any uncomfortable weight bearing.|Oturarak küçük daireler kullan; rahatsız yük vermeyi çıkar.',
'Stop sharp wrist or shoulder pain; warming up does not make pain safe to ignore.|Keskin bilek veya omuz ağrısında dur; ısınmak ağrıyı yok sayma izni değildir.',
'Wide seated march, small shoulder circles and unloaded wrist close-up; no squat, pressing or forced stretching yet.|Geniş oturarak adım, küçük omuz daireleri ve yüksüz bilek yakın plan; henüz squat, itiş veya zorlanan esneme yok.')
lesson('Sets, rest and recovery|Set, dinlenme ve toparlanma','Separate practice quality from exhaustion.|Pratik kalitesini tükenmeden ayır.',[
'A set is a short group of repetitions or a hold, not a competition.|Set kısa tekrar grubu veya tutuş süresidir, yarış değildir.',
'Rest until breathing settles and you can reproduce the setup; 60–120 seconds is a starting option, longer is allowed.|Nefes sakinleşip kurulumu tekrarlayana kadar dinlen; başlangıç seçeneği 60–120 saniye, daha uzun olabilir.',
'Leave recovery between demanding strength sessions; distribute major movement groups across your week.|Zorlu kuvvet günleri arasında toparlanma bırak; temel hareket gruplarını haftaya dağıt.'],
'Learning task: write where you would place a rest between two future practice sets, and how you would decide to rest longer. No press is required before its technique lesson.|Öğrenme görevi: gelecekteki iki pratik seti arasına dinlenmeyi nereye koyacağını ve uzatmaya nasıl karar vereceğini yaz. Teknik dersinden önce itiş gerekli değil.',
['My plan allows breathing and control to return before another set.|Planım sonraki setten önce nefes ve kontrolün dönmesine izin veriyor.','My schedule includes easier or rest days.|Takvimimde kolay veya dinlenme günleri var.'],
'One short set is enough for a first exposure; study the rest plan if physical activity is not appropriate today.|İlk tanışmada tek kısa set yeterli; bugün fiziksel etkinlik uygun değilse dinlenme planını incele.',
'End the session when unusual fatigue prevents an easy setup; do not compensate with rushed repetitions.|Alışılmadık yorgunluk kolay kurulumu engelliyorsa seansı bitir; acele tekrarlarla telafi etme.',
'Planning diagram with two task blocks and seated rest between; no untaught physical sets.|İki görev bloğu ve arada oturarak dinlenmeli plan şeması; öğretilmeyen fiziksel set yok.',kind='learning_only')
lesson('A useful practice record|İşe yarayan pratik kaydı','Record observations before increasing difficulty.|Zorluğu artırmadan gözlemlerini kaydet.',[
'Seen means opened; practised means you tried the chosen task; completion is your own learning statement.|Görüldü açıldığı, pratik seçilen görevin denendiği, tamamlama kendi öğrenme bildirimin olduğu anlamına gelir.',
'Record the variant, repetitions or hold, effort and one observation in your own notes; the app stores only its progress states.|Varyasyon, tekrar veya tutuş, efor ve bir gözlemi kendi notuna yaz; uygulama yalnız ilerleme durumlarını saklar.',
'Use repeated controlled sessions to decide a small next change; reading alone never unlocks a camera skill.|Küçük sonraki değişimi tekrarlanan kontrollü seanslarla seç; yalnız okumak kamera becerisini açmaz.'],
'Learning task: make a blank log with variant, dose, effort and observation fields; record today’s space or breathing review, not an untaught movement.|Öğrenme görevi: varyasyon, doz, efor ve gözlem alanlı boş kayıt hazırla; öğretilmeyen hareket yerine bugünkü alan veya nefes incelemesini yaz.',
['My completion describes learning, not verified mastery.|Tamamlama kaydım doğrulanmış ustalık değil, öğrenmeyi anlatıyor.','I know which version of the course I am using.|Kursun hangi sürümünü kullandığımı biliyorum.'],
'Use the easier variant or a written learning task; do not invent a completed physical attempt.|Kolay varyasyon veya yazılı öğrenme görevi kullan; yapılmayan fiziksel denemeyi yapılmış sayma.',
'Pause progression if symptoms worsen between sessions; seek individual advice as appropriate.|Seanslar arasında belirtiler artarsa ilerlemeyi durdur; gerektiğinde bireysel danışma al.',
'Notebook beside stable chair; distinct Seen, Practised and Self-reported labels without certificate graphics.|Sabit sandalyenin yanında not defteri; sertifika görseli olmadan ayrı Görüldü, Pratik, Öz bildirim etiketleri.',kind='learning_only')

module('lower','Lower-body control|Alt beden kontrolü',['nhs_strength','acsm2026','ace'])
lesson('Sit to stand|Otur-kalk','Learn a controlled squat entry from a chair.|Sandalyeyle kontrollü squat girişini öğren.',[
'Place a fixed chair against a wall and feet where you can stand without rocking.|Sabit sandalyeyi duvara daya; ayakları sallanmadan kalkabileceğin yere koy.',
'Lean from the hips enough to bring weight over the feet, then push the floor away to stand.|Ağırlığı ayakların üzerine almak için kalçadan yeterince eğil; zemini iterek kalk.',
'Sit back slowly, contacting the seat without dropping onto it.|Yavaşça geriye otur; koltuğa kendini bırakmadan dokun.'],
'Try 1 set of 3–5; if controlled, a second set after 60–120 seconds. Use hands on a stable support when needed.|1 set 3–5 dene; kontrollüyse 60–120 saniye sonra ikinci set. Gerektiğinde sabit destekten ellerle yardım al.',
['I do not bounce off the chair.|Sandalyeden sekmiyorum.','Both feet remain planted.|İki ayağım da zeminde kalıyor.'],
'Use a higher stable seat and hand assistance.|Daha yüksek sabit oturak ve el desteği kullan.',
'Stop knee or hip pain, loss of balance or chair movement.|Diz ya da kalça ağrısı, denge kaybı veya sandalye hareketinde dur.',
'Front and side chair sequence; show higher-seat regression and quiet seat contact.|Önden ve yandan sandalye dizisi; yüksek oturak kolay yolu ve yumuşak oturma teması.')
lesson('Squat: stance and depth|Squat: duruş ve derinlik','Choose a repeatable depth without a universal angle target.|Evrensel açı hedefi olmadan tekrarlanabilir derinlik seç.',[
'Start near a support; choose a comfortable foot width and toe direction for your body.|Desteğin yanında başla; bedenine rahat ayak genişliği ve parmak yönünü seç.',
'Bend hips and knees together; let knees follow the general direction of the toes rather than forcing them inward.|Kalça ve dizi birlikte bük; dizi içeri zorlamak yerine parmakların genel yönünde ilerlet.',
'Stop at the depth where feet, balance and trunk control remain steady, then stand smoothly.|Ayak, denge ve gövde kontrolünün korunduğu derinlikte dur; akıcı şekilde kalk.'],
'Practice 2 sets of 4–6 shallow squats with 90 seconds rest; gradually explore a little more depth only if comfortable.|90 saniye dinlenmeyle 2 set 4–6 sığ squat yap; yalnız rahatsa biraz daha derinliği kademeli dene.',
['My heels stay supported and I can pause briefly.|Topuklarım destekli kalıyor ve kısa durabiliyorum.','Depth is chosen for control, not a forced camera score.|Derinlik zorlanan kamera puanı için değil, kontrol için seçiliyor.'],
'Hold a fixed support or return to sit-to-stand.|Sabit destek tut veya otur-kalka dön.',
'Stop pinching joint pain, instability or a slipping foot.|Eklemde sıkışma ağrısı, dengesizlik veya ayak kaymasında dur.',
'Front/side shallow-to-comfortable squat; show feet and hips, no numerical depth overlay.|Önden/yandan sığdan rahat derinliğe squat; ayak ve kalça görünür, sayısal derinlik etiketi yok.')
lesson('Hip hinge to a wall|Duvara kalça menteşesi','Distinguish a hip hinge from a squat.|Kalça menteşesini squattan ayır.',[
'Stand a short distance in front of a wall with soft knees and hands on your hip creases.|Duvardan kısa mesafe önde, dizler yumuşak ve eller kalça kıvrımında dur.',
'Send the hips backwards to touch the wall; keep your head following your trunk instead of craning up.|Kalçayı duvara değmek için geriye gönder; baş gövdeyi izlesin, yukarı uzatma.',
'Return by standing tall through the feet without leaning backwards at the finish.|Ayaklardan destekle dikleş; bitişte geriye yaslanma.'],
'Perform 1–2 sets of 5 wall taps, rest 60–90 seconds; move only a little farther from the wall if control stays easy.|1–2 set 5 duvar dokunuşu yap, 60–90 saniye dinlen; kontrol kolaysa duvardan yalnız biraz uzaklaş.',
['I feel hips move back rather than knees travel far forward.|Dizlerin çok ileri gitmesinden çok kalçanın geriye gittiğini hissediyorum.','My finish is upright, not arched backwards.|Bitişim dik, geriye bükülü değil.'],
'Reduce the wall distance or rehearse seated hip folding.|Duvar mesafesini azalt veya oturarak kalçadan katlanmayı prova et.',
'Stop back pain, radiating symptoms or balance loss.|Bel ağrısı, yayılan belirti veya denge kaybında dur.',
'Side hip-wall tap with floor marker; compare two small controlled ranges.|Yandan kalça-duvar dokunuşu ve zemin işareti; iki küçük kontrollü aralık.')
lesson('Glute bridge|Kalça köprüsü','Extend the hips without chasing height.|Yükseklik kovalamadan kalçayı aç.',[
'Lie on a mat with knees bent and feet comfortable; keep shoulders supported.|Dizler bükülü, ayaklar rahat şekilde mata uzan; omuzları destekli tut.',
'Press through the feet and raise the hips only while the ribs and pelvis remain controlled.|Ayaklardan it ve kaburga ile leğen kontrolü korunurken kalçayı kaldır.',
'Lower slowly; avoid pushing the finish into the lower back.|Yavaş indir; bitişi bele zorlayarak yapma.'],
'Try 1–2 sets of 4–6 with 60–90 seconds rest; a small lift is sufficient for learning.|60–90 saniye dinlenmeyle 1–2 set 4–6 dene; öğrenmek için küçük kaldırış yeterli.',
['I do not increase height by arching the back.|Beli bükerek yüksekliği artırmıyorum.','Feet and shoulders do not slide.|Ayak ve omuzlar kaymıyor.'],
'Use standing hip extension with hand support if lying down is uncomfortable; pregnancy supine work needs care-team adaptation.|Uzanmak rahatsızsa el destekli ayakta kalça açma kullan; gebelikte sırtüstü çalışma bakım ekibiyle uyarlanmalıdır.',
'Stop back pain, dizziness when supine or persistent hamstring cramping.|Bel ağrısı, sırtüstü baş dönmesi veya süren arka bacak krampında dur.',
'Side small bridge and standing supported alternative; avoid lumbar overextension.|Yandan küçük köprü ve ayakta destekli alternatif; aşırı bel açılması yok.',extra=['nhs_pregnancy'])
lesson('Supported split squat|Destekli split squat','Control a staggered stance before stepping lunges.|Adımlı lunge öncesi ayrık duruşu kontrol et.',[
'Hold a fixed rail lightly; place feet on two tracks, not a tightrope.|Sabit korkuluğu hafif tut; ayakları ip üzeri gibi değil iki hat üzerine koy.',
'Bend both knees a little while keeping the front foot fully supported.|Ön ayağın tamamı destekliyken iki dizi biraz bük.',
'Rise through both legs without twisting; change sides after the set.|Dönmeden iki bacakla yüksel; setten sonra taraf değiştir.'],
'Begin with 1 set of 3–5 per side, 60–90 seconds rest; use a second set if both sides stay steady.|Taraf başına 1 set 3–5 ile başla, 60–90 saniye dinlen; iki taraf da dengeliyse ikinci set kullan.',
['I can keep a wide enough base for balance.|Denge için yeterli geniş tabanı koruyabiliyorum.','Front knee and foot turn together, not oppositely.|Ön diz ve ayak birlikte yönleniyor, ters değil.'],
'Make the bend shallower or use a seated leg task.|Bükülmeyi sığlaştır veya oturarak bacak görevi kullan.',
'Stop knee pain or needing to hang your bodyweight on the support.|Diz ağrısında veya beden ağırlığını desteğe asman gerektiğinde dur.',
'Front diagonal supported split squat; floor tracks visible and shallow regression.|Önden çapraz destekli split squat; zemin hatları ve sığ kolay yol görünür.')
lesson('Reverse lunge|Geri lunge','Add a controlled backward step.|Kontrollü geriye adım ekle.',[
'Start beside a stable support; take a short step back onto the ball of the foot.|Sabit desteğin yanında başla; ayağın önüne kısa geriye adım at.',
'Lower a small amount with the front foot planted and torso controlled.|Ön ayak sabit, gövde kontrollüyken biraz alçal.',
'Push the front floor away and bring the back foot forward without a hop.|Öndeki zemini it ve arkadaki ayağı sıçramadan öne getir.'],
'Practice 1–2 sets of 3–4 each side, resting 90 seconds; repeat the supported split squat if the step disrupts balance.|90 saniye dinlenerek taraf başına 1–2 set 3–4 yap; adım dengeyi bozuyorsa destekli split squatı yinele.',
['I place the back foot quietly.|Arka ayağı yumuşak yerleştiriyorum.','I return without bouncing or twisting.|Sekmeden ve dönmeden dönüyorum.'],
'Keep both feet in place and use the earlier split squat.|İki ayağı yerinde tut ve önceki split squatı kullan.',
'Stop if a knee buckles, a foot slips or pain changes your step.|Diz boşalır, ayak kayar veya ağrı adımı değiştirirse dur.',
'Side and front stepping sequence beside rail; no fast alternating lunge.|Korkuluk yanında yandan/önden adım dizisi; hızlı değişen lunge yok.')
lesson('Low step-up|Alçak basamağa çıkış','Step up without pushing mostly from the trailing foot.|İtişin çoğunu arkadaki ayaktan almadan basamağa çık.',[
'Use a low, non-slip purpose-built step and nearby rail; put the whole lead foot on it.|Alçak, kaymayan uygun basamak ve yakın korkuluk kullan; ön ayağın tamamını yerleştir.',
'Rise through the lead leg with light rail assistance, avoiding a bounce from the floor foot.|Zemindeki ayaktan sekmeden, hafif korkuluk desteğiyle ön bacak üzerinden yüksel.',
'Step down slowly to the same clear floor area before changing lead legs.|Ön bacağı değiştirmeden aynı boş zemin alanına yavaş in.'],
'Try 1 set of 3–5 each side; rest 90 seconds and optionally repeat. Choose a lower step before adding reps.|Taraf başına 1 set 3–5 dene; 90 saniye dinlen ve istersen yinele. Tekrar eklemeden önce daha alçak basamak seç.',
['The entire lead foot fits on the step.|Ön ayağın tamamı basamağa sığıyor.','I control the descent rather than dropping.|Kendimi bırakmadan inişi kontrol ediyorum.'],
'Practice floor weight shifts or sit-to-stand with support.|Zeminde ağırlık aktarımı veya destekli otur-kalk yap.',
'Stop unstable equipment, loss of balance or knee pain.|Oynayan ekipman, denge kaybı veya diz ağrısında dur.',
'Low step and rail fully visible; foot placement close-up and quiet descent.|Alçak basamak ve korkuluk tamamen görünür; ayak yerleşimi yakın plan ve yumuşak iniş.')
lesson('Calf raise|Baldır kaldırma','Use a controlled ankle rise and return.|Kontrollü ayak bileği yükselişi ve dönüşü kullan.',[
'Stand on level ground with both feet supported and fingertips on a fixed surface.|İki ayak destekli düz zeminde dur, parmak uçlarını sabit yüzeye koy.',
'Rise through the forefeet evenly; choose a height that does not roll the ankles outward.|Ayak önlerinden dengeli yüksel; bilekleri dışarı devirmeyen yüksekliği seç.',
'Lower both heels gently to the ground, not below an improvised ledge.|İki topuğu nazikçe zemine indir; doğaçlama kenarın altına sarkıtma.'],
'Perform 1–2 sets of 5–8, resting 60 seconds; stay with two legs before considering harder variants.|60 saniye dinlenerek 1–2 set 5–8 yap; zor varyasyon düşünmeden iki bacakla kal.',
['I avoid rocking onto the outer edge of the foot.|Ayağın dış kenarına devrilmiyorum.','The lowering remains quiet and controlled.|İniş yumuşak ve kontrollü kalıyor.'],
'Use seated heel raises or a smaller standing rise.|Oturarak topuk kaldır veya ayakta daha küçük yüksel.',
'Stop ankle pain, sudden calf pain or balance loss.|Bilek ağrısı, ani baldır ağrısı veya denge kaybında dur.',
'Front ankle detail and full-body support view; no ledge or one-leg challenge.|Önden bilek detayı ve tam beden destek görünümü; kenar veya tek bacak meydan okuması yok.')

module('push','Progressive pushing|Kademeli itiş',['nasm_push','acsm2026'])
lesson('Wall push-up|Duvar şınavı','Learn whole-body pressing at a light load.|Hafif yükte bütün beden itişini öğren.',[
'Place hands on a firm wall at comfortable chest height; step back a small distance.|Elleri sağlam duvarda rahat göğüs yüksekliğine koy; biraz geriye adım at.',
'Bend the elbows and bring your body toward the wall as one unit, keeping feet planted.|Ayaklar sabitken dirsekleri bük, bedeni tek parça duvara yaklaştır.',
'Press away smoothly without shrugging or forcing elbows wide.|Omuz silkmeden veya dirseği çok yana zorlamadan akıcı it.'],
'Try 2 sets of 4–6 with 60–90 seconds rest; move feet closer to reduce effort.|60–90 saniye dinlenmeyle 2 set 4–6 dene; eforu azaltmak için ayakları yaklaştır.',
['My hips travel with the shoulders.|Kalçam omuzlarla birlikte ilerliyor.','Hands remain comfortable and do not slip.|Eller rahat kalıyor ve kaymıyor.'],
'Stand closer or rehearse a seated forward press without loading the wrists.|Daha yakın dur veya bileğe yük vermeden oturarak öne itiş prova et.',
'Stop wrist, elbow or shoulder pain, not just after the target count.|Hedef sayıyı beklemeden bilek, dirsek veya omuz ağrısında dur.',
'Side wall press plus hand placement close-up; show closer-foot regression.|Yandan duvar itişi ve el yerleşimi yakın plan; yakın ayak kolay yolu.')
lesson('Incline push-up|Yükseltide şınav','Lower the support gradually while preserving control.|Kontrolü koruyarak desteği kademeli alçalt.',[
'Choose a fixed counter or rated bench that cannot tip or slide; test it before leaning.|Devrilmeyen/kaymayan sabit tezgâh veya uygun bank seç; eğilmeden kontrol et.',
'Keep trunk and legs together as elbows bend; allow a comfortable elbow path rather than a fixed angle.|Dirsekler bükülürken gövde ve bacak birlikte kalsın; sabit açı yerine rahat dirsek yolu kullan.',
'Press back to the starting line and reset your breath before repeating.|Başlangıç çizgisine it ve yinelemeden nefesi düzenle.'],
'Use 1–2 sets of 4–6 with 90 seconds rest. Keep the same height for several controlled sessions before lowering it.|90 saniye dinlenmeyle 1–2 set 4–6. Alçaltmadan önce birkaç kontrollü seans aynı yükseklikte kal.',
['Support stability was checked before the set.|Setten önce destek sağlamlığı kontrol edildi.','My trunk does not sag behind my shoulders.|Gövdem omuzların gerisinde sarkmıyor.'],
'Use a higher fixed support or the wall.|Daha yüksek sabit destek veya duvar kullan.',
'Stop support movement or pain during pressing.|İtişte destek oynarsa veya ağrı olursa dur.',
'Fixed bench side view with support feet visible; two stable heights without a stool.|Destek ayakları görünen sabit bank yandan; tabure olmadan iki sabit yükseklik.')
lesson('Knee-supported floor push|Diz destekli yerde şınav','Control a shorter body lever on the floor.|Yerde daha kısa beden kolunu kontrol et.',[
'Use a mat under the knees and hands in a comfortable position under or near the shoulders.|Diz altına mat, elleri omuz altı veya yakınında rahat yere koy.',
'Keep a connected line from knees through hips to shoulders as you lower.|Alçalırken diz-kalça-omuz bağlantılı çizgiyi koru.',
'Press back without sitting the hips onto the heels.|Kalçayı topuklara oturtmadan geri it.'],
'Try 1 set of 3–5, rest 90 seconds and optionally repeat; range can be small while learning.|1 set 3–5 dene, 90 saniye dinlen ve istersen yinele; öğrenirken aralık küçük olabilir.',
['My hips do not lead the push.|İtişi kalçam başlatmıyor.','I can breathe without compressing the wrists painfully.|Bileği ağrılı sıkıştırmadan nefes alabiliyorum.'],
'Choose incline push-ups instead if kneeling or floor access is uncomfortable.|Diz üstü veya yere erişim rahatsızsa yükseltide şınav seç.',
'Stop knee pressure pain, wrist pain or losing the body line.|Diz basınç ağrısı, bilek ağrısı veya beden çizgisi kaybında dur.',
'Side knee-to-shoulder line and padded knees; show small range and incline alternative.|Yandan diz-omuz çizgisi ve yastıklı diz; küçük aralık ve yükselti alternatifi.')
lesson('Controlled lowering|Kontrollü alçalma','Learn the descent without assuming the ascent is ready.|Yükseliş hazır sayılmadan inişi öğren.',[
'Use an incline you already control, or the floor only after comfortable supported presses.|Kontrol ettiğin yükseltiyi kullan; yerde yalnız rahat destekli itişlerden sonra çalış.',
'Lower for an easy count of two or three without collapsing; choose less range if needed.|Çökmeden rahat iki-üç sayımda alçal; gerekirse aralığı azalt.',
'Step or place the knees down to reset; this drill does not require a full floor press up.|Yenilenmek için adımla veya dizleri koy; bu çalışma tam yer şınavıyla yükselmeyi gerektirmez.'],
'Practice 1–2 sets of 2–3 descents with 90–120 seconds rest; keep reserve and avoid repeated slow failure.|90–120 saniye dinlenmeyle 1–2 set 2–3 iniş; pay bırak, tekrar tekrar yavaş tükenme yapma.',
['I choose the exit before starting.|Başlamadan çıkışı seçiyorum.','Every descent is controlled, not a drop.|Her iniş kontrollü, düşme değil.'],
'Return to ordinary wall presses; no eccentric-only drill is mandatory.|Normal duvar itişine dön; yalnız negatif çalışma zorunlu değil.',
'Stop a sudden drop, joint pain or next-session soreness that interferes with ordinary movement.|Ani düşüş, eklem ağrısı veya sonraki seansta günlük hareketi bozan ağrıda dur.',
'Side incline descent and explicit knee reset; no floor crash or maximum-effort count.|Yandan yükselti inişi ve belirgin dizle yenilenme; yere çökme veya en yüksek efor sayımı yok.')
lesson('Floor push-up option|Yerde şınav seçeneği','Combine the descent and press only when both stay controlled.|İniş ve itişi ikisi de kontrollüyken birleştir.',[
'From a supported plank choose a hand and foot spacing that feels stable; keep the floor clear.|Destekli planktan dengeli el ve ayak aralığını seç; zemini boş tut.',
'Lower the chest within a comfortable range with hips following shoulders.|Kalça omuzları izlerken göğsü rahat aralıkta indir.',
'Press the body back together; if the first repetition stalls, use the earlier incline rather than grind.|Bedeni birlikte geri it; ilk tekrar takılırsa zorlamak yerine önceki yükseltiyi kullan.'],
'Choose 1–2 sets of 1–4 controlled repetitions with 120 seconds rest; incline sets remain a valid course path.|120 saniye dinlenmeyle 1–2 set 1–4 kontrollü tekrar seç; yükselti setleri geçerli kurs yolu olmaya devam eder.',
['Shoulders and hips rise together.|Omuz ve kalça birlikte yükseliyor.','I stop before the next rep would lose control.|Sonraki tekrar kontrolü bozacaksa önceden duruyorum.'],
'Use a high incline or knee-supported variant without treating it as failure.|Başarısızlık saymadan yüksek yükselti veya diz desteği kullan.',
'Stop pain, wrist numbness or repeated trunk collapse.|Ağrı, bilekte uyuşma veya tekrarlanan gövde çökmesinde dur.',
'Full-body side floor press with one clean rep; matched incline regression, no score overlay.|Tek temiz tekrarlı tam beden yandan yer şınavı; eş yükselti kolay yolu, puan etiketi yok.')
lesson('Scapular support control|Kürek kemiği destek kontrolü','Move the shoulder girdle gently without bending the elbows.|Dirseği bükmeden omuz kuşağını nazikçe hareket ettir.',[
'Begin at a wall or high incline with straight but unforced arms.|Duvarda veya yüksek yükseltide düz ama zorlanmayan kollarla başla.',
'Allow a small movement of the chest between the shoulders, then gently push the surface away.|Göğsün omuzlar arasında küçük hareketine izin ver; sonra yüzeyi nazikçe it.',
'Keep the head and trunk quiet; this is small shoulder-blade movement, not a deep push-up.|Baş ve gövde sakin; bu derin şınav değil küçük kürek kemiği hareketi.'],
'Try 1–2 sets of 4 small movements, rest 60–90 seconds; increase control before changing height.|1–2 set 4 küçük hareket dene, 60–90 saniye dinlen; yükseklikten önce kontrolü artır.',
['My elbows stay nearly still.|Dirseklerim neredeyse sabit.','I do not thrust the head forward.|Başımı öne fırlatmıyorum.'],
'Practice standing shoulder-blade movement without hand loading.|Ele yük vermeden ayakta kürek kemiği hareketi yap.',
'Stop shoulder pinching, tingling or forced end-range.|Omuz sıkışması, karıncalanma veya zorlanan son aralıkta dur.',
'Rear-diagonal wall support close-up plus side trunk; small protraction/retraction only.|Arkadan çapraz duvar desteği yakın plan ve yandan gövde; yalnız küçük öne/geriye kürek hareketi.')
lesson('Dip preparation, feet supported|Ayak destekli dip hazırlığı','Learn support before a deep parallel-bar dip.|Derin paralel bar dipten önce desteği öğren.',[
'Use fixed rated parallel handles low enough to keep both feet down; do not use two loose chairs.|İki ayağı yerde tutacak kadar alçak sabit uygun paralel tutacak kullan; iki gevşek sandalye kullanma.',
'Hold lightly through the hands with shoulders comfortable, feet carrying most of the weight.|Omuzlar rahat, yükün çoğu ayakta olacak şekilde ellerden hafif destek al.',
'Explore only a tiny elbow bend and return; deep shoulder extension is not part of this preparation.|Yalnız çok küçük dirsek bükme ve dönüş dene; derin omuz geriye açılması bu hazırlığa ait değil.'],
'Choose 2 supported holds of 5–10 seconds or 3 tiny bends; rest 90 seconds. Without rated handles, study the setup and use wall presses.|2 destekli 5–10 saniye tutuş veya 3 küçük bükme seç; 90 saniye dinlen. Uygun tutacak yoksa kurulumu incele ve duvar itişi kullan.',
['Feet remain able to unload the arms immediately.|Ayaklar koldaki yükü hemen alabilecek durumda.','Shoulders do not sink into an uncomfortable depth.|Omuzlar rahatsız derinliğe çökmüyor.'],
'Keep all weight on the feet or repeat incline pressing; full dips are optional later with coaching.|Tüm yükü ayakta tut veya yükselti itişini yinele; tam dip daha sonra eğitmenle isteğe bağlı.',
'Stop front-shoulder pain, unstable handles or loss of foot support.|Ön omuz ağrısı, oynayan tutacak veya ayak desteği kaybında dur.',
'Rated low parallel handles and planted feet wide shot; tiny bend, no chair dip or deep range.|Uygun alçak paralel tutacak ve yerde ayak geniş plan; küçük bükme, sandalye dip veya derin aralık yok.',extra=['ace'])

module('pull','Pulling with reliable equipment|Güvenilir ekipmanla çekiş',['nasm_pull','acsm2026'])
lesson('Pulling equipment and exits|Çekiş ekipmanı ve çıkışlar','Choose an anchor and exit before leaving the ground.|Zeminden ayrılmadan bağlantı ve çıkışı seç.',[
'Read the manufacturer installation and load instructions for the bar or suspension system; ask qualified help if uncertain.|Bar veya askı sisteminin üretici montaj ve yük talimatını oku; belirsizse yetkin yardım al.',
'Inspect mounts, straps and handles; clear the floor and avoid swinging, jumping onto the bar or makeshift door trim.|Bağlantı, kayış ve tutacakları incele; zemini boşalt, sallanma, bara sıçrama veya doğaçlama pervazdan kaçın.',
'Use a stable access step and foot support that let you return immediately; rated equipment is a prerequisite, not a camera check.|Hemen dönebileceğin sabit erişim basamağı ve ayak desteği kullan; uygun ekipman kamera kontrolü değil önkoşuldur.'],
'Perform an unloaded inspection and rehearse the foot-supported entry/exit twice; do not hang to test unknown hardware.|Yüksüz kontrol yap, ayak destekli giriş/çıkışı iki kez prova et; bilinmeyen ekipmanı asılarak test etme.',
['I have verified the mounting instructions, not guessed from appearance.|Montaj talimatını doğruladım, görünüşten tahmin etmedim.','I can step down without jumping.|Sıçramadan inebiliyorum.'],
'Without suitable equipment, complete the learning task and use an unloaded seated pulling rehearsal; this does not replace resistance pulling.|Uygun ekipman yoksa öğrenme görevini ve yüksüz oturarak çekiş provasını yap; bu dirençli çekişin yerine geçmez.',
'Do not start if mounting, load rating or inspection is uncertain.|Montaj, taşıma sınırı veya kontrol belirsizse başlama.',
'Anchor rating and attachment detail, then wide access step and exit; no table/door improvisation.|Bağlantı taşıma etiketi ve detay, ardından geniş erişim basamağı ve çıkış; masa/kapı doğaçlaması yok.',kind='learning_only')
lesson('Bent-knee body row|Diz bükülü beden row','Learn horizontal pulling while feet stay supported.|Ayaklar destekliyken yatay çekişi öğren.',[
'Low bar: sit underneath, grip it, face upward and keep bent knees with feet planted before lightly raising hips. Suspension: face the rated anchor, grip handles, step feet forward slightly and lean back with both feet planted.|Alçak bar: altına otur, tut, yüz yukarı ve diz bükülü ayaklar basılıyken kalçayı hafif kaldır. Askı: uygun bağlantıya dön, tutacakları tut, ayakları biraz öne al ve iki ayak basılı geriye eğil.',
'For either setup, pull the chest toward the bar or handles with hips following shoulders; use a comfortable grip and keep foot assistance.|İki düzende de kalça omzu izlerken göğsü bar veya tutacağa çek; rahat tutuş ve ayak yardımını koru.',
'Lower slowly: at a low bar put hips back on the mat before releasing; with suspension step feet back to stand upright before releasing. Keep enough foot pressure to exit immediately.|Yavaş alçal: alçak barda bırakmadan kalçayı mata koy; askıda bırakmadan ayakları geriye alıp dikleş. Hemen çıkmak için yeterli ayak basıncı bırak.'],
'Try 1–2 sets of 3–5 with 90–120 seconds rest; a more upright suspension angle is easier.|90–120 saniye dinlenmeyle 1–2 set 3–5 dene; askıda daha dik açı daha kolaydır.',
['Hips do not sag behind the chest.|Kalça göğsün gerisinde sarkmıyor.','I do not jerk the first pull.|İlk çekişi ani yapmıyorum.'],
'Choose a more upright rated suspension row or study the movement if no equipment is available.|Daha dik uygun askı row seç; ekipman yoksa hareketi incele.',
'Stop grip slippage, shoulder pain or movement of the anchor.|Tutuş kayması, omuz ağrısı veya bağlantı hareketinde dur.',
'Low-bar side row with bent knees and feet in frame; upright suspension alternative.|Bükülü diz ve ayak kadrajıyla alçak bar yandan row; dik askı alternatifi.')
lesson('A longer row lever|Row kolunu uzatmak','Increase row demand by one small lever change.|Tek küçük kol değişimiyle row yükünü artır.',[
'First repeat the bent-knee row with stable breathing and an immediate foot exit.|Önce dengeli nefes ve hemen ayak çıkışıyla diz bükülü rowu yinele.',
'Move the feet a small amount farther out or make the body less upright, not both at once.|Ayakları biraz uzaklaştır veya bedeni daha yatay yap; ikisini aynı anda değil.',
'Keep the same chest-to-handle path and controlled return; a hard lever is optional.|Aynı göğüs-tutacak yolunu ve kontrollü dönüşü koru; zor kol isteğe bağlı.'],
'Compare 3 repetitions at the familiar lever with 2 at the slightly harder lever, resting 120 seconds; stay easier if control changes.|Tanıdık kolda 3 tekrar ile biraz zor kolda 2 tekrarı 120 saniye dinlenerek karşılaştır; kontrol değişirse kolayda kal.',
['I changed one variable only.|Yalnız bir değişken değiştirdim.','The return remains as controlled as the pull.|Dönüş çekiş kadar kontrollü kalıyor.'],
'Keep bent knees or a more upright body.|Dizleri bükülü veya bedeni daha dik tut.',
'Stop elbow/shoulder pain or inability to lower smoothly.|Dirsek/omuz ağrısı veya akıcı inememede dur.',
'Matched side shots of two modest lever lengths with same rated anchor; no maximum horizontal challenge.|Aynı uygun bağlantıda iki küçük kol farkının eş yandan planları; en zor yatay meydan okuma yok.')
lesson('Foot-supported hang|Ayak destekli asılma','Explore an overhead grip without a forced full hang.|Zorunlu tam asılma olmadan baş üstü tutuşu tanı.',[
'Use the inspected bar and a stable step that keeps both feet supported.|Kontrol edilen bar ve iki ayağı destekleyen sabit basamak kullan.',
'Grip comfortably and transfer only a small part of the weight to the arms; avoid forcing the shoulders into an end-range.|Rahat tut ve yükün yalnız küçük bölümünü kola aktar; omuzu son aralığa zorlama.',
'Return weight to the feet before releasing the hands.|Elleri bırakmadan yükü ayaklara geri ver.'],
'Try 2–3 supported holds of 5 seconds with 60–90 seconds rest; no free hang is required.|60–90 saniye dinlenmeyle 2–3 destekli 5 saniye tutuş dene; serbest asılma gerekli değil.',
['I can unload onto my feet at any moment.|Her an yükü ayağa alabiliyorum.','Grip and shoulder position remain comfortable.|Tutuş ve omuz konumu rahat kalıyor.'],
'Keep all weight on the feet and rehearse the grip, or remain with rows.|Tüm yükü ayakta tutup tutuşu prova et veya rowda kal.',
'Stop tingling, shoulder pain or unreliable foot support.|Karıncalanma, omuz ağrısı veya güvenilmez ayak desteğinde dur.',
'Wide overhead bar with feet firmly on rated step, close grip detail; no dangling beginner.|Uygun basamakta sağlam ayaklarla geniş baş üstü bar, tutuş detayı; boşta sallanan başlangıç modeli yok.')
lesson('Supported scapular pull|Destekli kürek çekişi','Explore a small shoulder-girdle action before vertical pulling.|Dikey çekişten önce küçük omuz kuşağı hareketini tanı.',[
'Keep feet supported in the previous hang setup and elbows nearly straight.|Önceki asılma düzeninde ayakları destekli, dirsekleri neredeyse düz tut.',
'Gently lift the chest a small amount by moving the shoulder girdle; do not turn it into a full pull-up.|Omuz kuşağıyla göğsü az yükselt; tam barfikse dönüştürme.',
'Release the small motion slowly while feet still share the load.|Ayaklar yükü paylaşırken küçük hareketi yavaş bırak.'],
'Use 1–2 sets of 3 small motions, resting 90 seconds; stop well before grip fatigue.|90 saniye dinlenerek 1–2 set 3 küçük hareket; tutuş yorgunluğundan çok önce bitir.',
['Elbows do not supply the movement by bending.|Dirsek bükülmesi hareketi üretmiyor.','I can distinguish a small shrug change from a pull-up.|Küçük omuz hareketini barfiksten ayırabiliyorum.'],
'Rehearse shoulder-blade motion standing with no overhead load.|Baş üstü yük olmadan ayakta kürek kemiği hareketini prova et.',
'Stop shoulder pinching or neck strain.|Omuz sıkışması veya boyun zorlanmasında dur.',
'Rear diagonal of tiny supported shoulder movement with elbow and feet in frame.|Dirsek ve ayak kadrajda, destekli küçük omuz hareketinin arkadan çapraz görüntüsü.')
lesson('Assisted vertical pull|Yardımlı dikey çekiş','Learn a controlled pull with reliable assistance.|Güvenilir yardımla kontrollü çekiş öğren.',[
'Prefer a correctly adjusted assisted machine or coached foot assistance on rated equipment; bands need inspected anchors and rebound awareness.|Doğru ayarlı yardım makinesi veya uygun ekipmanda eğitmenli ayak yardımını tercih et; bantta kontrol edilmiş bağlantı ve geri sıçrama farkındalığı gerekir.',
'Pull the chest upward without kicking or craning the chin; use a comfortable range.|Tekme veya çeneyi uzatmadan göğsü yukarı çek; rahat aralık kullan.',
'Return slowly with the assistance present throughout; do not drop into a free hang.|Yardım boyunca mevcutken yavaş dön; serbest asılmaya düşme.'],
'If equipment and guidance are available, try 1–2 sets of 2–4 with 120 seconds rest. Otherwise study the setup and repeat rows.|Ekipman ve rehberlik varsa 120 saniye dinlenerek 1–2 set 2–4 dene. Yoksa kurulumu incele ve rowu yinele.',
['Assistance is predictable through the whole range.|Yardım tüm aralık boyunca öngörülebilir.','I do not swing or reach the chin to fake height.|Yüksekliği taklit için sallanmıyorum veya çeneyi uzatmıyorum.'],
'Use more reliable assistance or retain the horizontal row.|Daha güvenilir yardım kullan veya yatay rowda kal.',
'Stop band damage/rebound risk, shoulder pain or lost assistance.|Bant hasarı/geri sıçrama riski, omuz ağrısı veya yardım kaybında dur.',
'Assisted machine demonstration with pin adjustment and controlled return; foot-supported alternative, no band snap.|Pim ayarı ve kontrollü dönüşle yardım makinesi; ayak destekli alternatif, bant sıçraması yok.')
lesson('Negative pull-up: optional|Negatif barfiks: isteğe bağlı','Understand the eccentric option and its exit before trying it.|Negatif seçeneği denemeden çıkışını anla.',[
'Only consider this after comfortable assisted pulls and reliable grip; use rated bar, a stable access step and qualified guidance if uncertain.|Yalnız rahat yardımlı çekiş ve güvenilir tutuş sonrası düşün; uygun bar, sabit erişim basamağı ve belirsizse yetkin rehber kullan.',
'Step into an assisted top position without jumping; keep the step reachable while lowering a short controlled distance.|Sıçramadan yardımlı üst konuma adımla; kısa kontrollü inerken basamak erişilebilir kalsın.',
'Put weight back on the feet before grip fades; a full unsupported descent is not required.|Tutuş azalmadan yükü ayağa geri ver; tam desteksiz iniş gerekli değil.'],
'Optional: 1 set of 1–3 short assisted descents with 120 seconds rest. The valid alternative is 3–5 easy rows plus a written exit plan.|İsteğe bağlı: 120 saniye dinlenmeyle 1 set 1–3 kısa yardımlı iniş. Geçerli alternatif 3–5 kolay row ve yazılı çıkış planı.',
['I can reach the step before releasing.|Bırakmadan basamağa erişebiliyorum.','No repetition ends in an uncontrolled drop.|Hiçbir tekrar kontrolsüz düşmeyle bitmiyor.'],
'Remain with assisted pulls or rows; eccentric soreness can be larger than the task feels.|Yardımlı çekiş veya rowda kal; negatif çalışma sonradan beklenenden fazla ağrı yapabilir.',
'Stop sudden descent, tendon/joint pain or grip loss; do not repeat to failure.|Ani iniş, tendon/eklem ağrısı veya tutuş kaybında dur; tükenene kadar yineleme.',
'Close stable step placement then short supported descent; label optional and retain feet in frame.|Sabit basamak yerleşimi yakın plan, kısa destekli iniş; isteğe bağlı etiketi ve ayaklar kadrajda.')

module('core','Trunk control through changing levers|Değişen kollarda gövde kontrolü',['acsm2026','nasm_plank'])
lesson('Bird-dog, one limb first|Bird-dog, önce tek uzuv','Keep the trunk quiet as a limb moves.|Uzuv hareket ederken gövdeyi sakin tut.',[
'From padded hands and knees, place hands near shoulders and knees near hips.|Eller-dizler yastıklıyken elleri omuz, dizleri kalça yakınına koy.',
'Slide one leg back on the floor first; then reach the opposite arm only if trunk control remains easy.|Önce bir bacağı zeminde geri kaydır; gövde kontrolü kolaysa karşı kolu uzat.',
'Return quietly and change sides; height matters less than avoiding trunk rotation.|Yumuşak dön ve taraf değiştir; yükseklikten çok gövdenin dönmemesi önemlidir.'],
'Try 1–2 sets of 3 each side with 60 seconds rest; start with only a leg slide.|60 saniye dinlenmeyle taraf başına 1–2 set 3 dene; yalnız bacak kaydırmayla başla.',
['My hips do not roll as I reach.|Uzanırken kalçam dönmüyor.','I can keep breathing rather than brace maximally.|En sert sıkılma yerine nefes sürdürebiliyorum.'],
'Use standing hand-supported reaches if kneeling or wrist loading is uncomfortable.|Diz üstü veya bilek yükü rahatsızsa ayakta el destekli uzanma kullan.',
'Stop wrist/knee pain or back symptoms increasing during the reach.|Bilek/diz ağrısı veya uzanırken artan bel belirtisinde dur.',
'Rear diagonal trunk view and side leg slide; opposite reach stays low, no balancing objects.|Arkadan çapraz gövde ve yandan bacak kaydırma; karşı uzanma alçak, denge nesnesi yok.',extra=['ace_bird'])
lesson('Dead bug, short lever|Dead bug, kısa kol','Move a heel while controlling the rib-pelvis relationship.|Kaburga-leğen ilişkisini kontrol ederek topuğu hareket ettir.',[
'Lie comfortably on a mat with knees bent; begin with feet supported rather than both legs raised.|Dizler bükülü rahat uzan; iki bacağı havaya almak yerine ayak destekli başla.',
'Exhale gently as one heel slides away; keep the back in a comfortable, steady position without forcing it flat.|Bir topuk uzaklaşırken nazikçe nefes ver; beli zorla düzleştirmeden rahat sabit tut.',
'Return the heel and alternate; opposite arm reaching is a later option.|Topuğu geri getir ve değiştir; karşı kol uzatma daha sonraki seçenek.'],
'Practice 1–2 sets of 3–5 heel slides per side, resting 60 seconds; reduce the slide before raising the legs.|60 saniye dinlenerek taraf başına 1–2 set 3–5 topuk kaydır; bacağı kaldırmadan kaydırmayı küçült.',
['The range does not pull my trunk into an arch.|Aralık gövdemi bükülmeye çekmiyor.','I breathe without a maximal breath hold.|En sert nefes tutuşu olmadan nefes alıyorum.'],
'Use seated alternating foot lifts or standing reaches; pregnancy supine tasks require care-team adaptation, especially prolonged lying.|Oturarak sırayla ayak kaldır veya ayakta uzan; gebelikte özellikle uzun sırtüstü görev bakım ekibiyle uyarlanmalıdır.',
'Stop back pain or dizziness when lying down; do not continue an unsuitable supine position.|Bel ağrısı veya uzanırken baş dönmesinde dur; uygun olmayan sırtüstü konumu sürdürme.',
'Side short heel slide with rib/pelvis visible; seated alternative, no forced spine flattening.|Kaburga/leğen görünen yandan kısa topuk kaydırma; oturarak alternatif, zorla bel düzleştirme yok.',extra=['nasm_dead','nhs_pregnancy'])
lesson('Incline plank|Yükseltide plank','Build a comfortable support hold before the floor.|Yerden önce rahat destek tutuşu kur.',[
'Place hands or forearms on a fixed high surface and feet on non-slip ground.|El veya önkolları sabit yüksek yüzeye, ayakları kaymayan zemine koy.',
'Keep head, trunk and legs connected without forcing the pelvis into an exaggerated tuck.|Leğeni aşırı kıvırmadan baş, gövde ve bacağı bağlantılı tut.',
'Breathe through a short hold, then step closer before releasing support.|Kısa tutuşta nefes al; desteği bırakmadan yakına adımla.'],
'Try 2–3 holds of 5–10 seconds with 45–90 seconds rest; shorter comfortable holds are useful.|45–90 saniye dinlenmeyle 2–3 tutuş 5–10 saniye dene; daha kısa rahat tutuşlar işe yarar.',
['My support is stable.|Desteğim sabit.','I finish while breathing and posture remain manageable.|Nefes ve duruş yönetilebilirken bitiriyorum.'],
'Use the wall or stand closer; forearm contact can reduce hand pressure if comfortable.|Duvar kullan veya yakına gel; rahatsa önkol teması el basıncını azaltabilir.',
'Stop shoulder/wrist pain or breath holding that you cannot comfortably release.|Omuz/bilek ağrısı veya rahat bırakamadığın nefes tutuşunda dur.',
'Side high counter hold and wall regression; hands, feet and support base visible.|Yandan yüksek tezgâh tutuşu ve duvar kolay yolu; el, ayak ve destek tabanı görünür.')
lesson('Floor plank option|Yerde plank seçeneği','Choose a short floor hold without a duration contest.|Süre yarışına girmeden kısa yer tutuşu seç.',[
'Use padded forearms near shoulder level; start with knees down if needed.|Önkolu omuz yakınında yastıkla; gerekirse diz yerde başla.',
'Lift into a manageable knee or toe support while keeping the trunk from sagging.|Gövde sarkmadan yönetilebilir diz veya parmak desteğine yüksel.',
'End by putting knees down gently before the body collapses.|Beden çökmeden dizleri nazikçe koyarak bitir.'],
'Choose 2 holds of 5–15 seconds with 60–90 seconds rest; use shorter holds if breathing changes.|60–90 saniye dinlenmeyle 2 tutuş 5–15 saniye seç; nefes değişirse daha kısa tut.',
['I can speak a few comfortable words.|Rahat birkaç kelime söyleyebiliyorum.','I use a controlled exit rather than collapse.|Çöküş yerine kontrollü çıkış kullanıyorum.'],
'Return to incline plank; floor work is an option, not an achievement gate.|Yükseltide planka dön; yer çalışması seçenek, başarı kapısı değil.',
'Stop back, shoulder or elbow pain; numbness is not an endurance target.|Bel, omuz veya dirsek ağrısında dur; uyuşma dayanıklılık hedefi değildir.',
'Side forearm hold with knee-supported alternative and deliberate knee-down exit.|Diz destekli alternatif ve bilinçli dizle çıkışla yandan önkol tutuşu.')
lesson('Short-lever side support|Kısa kollu yan destek','Learn lateral support with bent knees.|Diz bükülü yan desteği öğren.',[
'Lie on your side with padded forearm and bent knees; position elbow near shoulder.|Yastıklı önkol ve bükülü dizle yan uzan; dirseği omuz yakınına koy.',
'Press the forearm and knees down to lift the hips slightly, keeping shoulders and pelvis facing the same direction.|Önkol ve dizi iterek kalçayı az kaldır; omuz ve leğen aynı yöne baksın.',
'Lower gently and turn through sitting rather than rolling quickly onto the other arm.|Nazik indir; diğer kola hızla yuvarlanmak yerine oturarak taraf değiştir.'],
'Try 2 holds of 5–8 seconds per side, resting 60 seconds; use one hold if this is new.|Taraf başına 2 tutuş 5–8 saniye dene, 60 saniye dinlen; yeniyse tek tutuş kullan.',
['I do not sink heavily onto the shoulder.|Omzuma ağır çökmüyorum.','My trunk does not rotate to extend the hold.|Süreyi uzatmak için gövdem dönmüyor.'],
'Use a standing side press against a wall or keep hips on the mat.|Duvarda ayakta yana itiş kullan veya kalçayı matta tut.',
'Stop shoulder compression pain or inability to lower gently.|Omuz basınç ağrısı veya nazik inememede dur.',
'Front diagonal knee-supported side hold with elbow cushion; wall alternative.|Dirsek yastıklı diz destekli yan tutuş önden çapraz; duvar alternatifi.')
lesson('Longer side-plank option|Uzun yan plank seçeneği','Change the support lever without chasing a long hold.|Uzun süre kovalamadan destek kolunu değiştir.',[
'First reproduce the short-lever side hold without shoulder or back discomfort.|Önce omuz veya bel rahatsızlığı olmadan kısa yan tutuşu yinele.',
'Extend the legs and stagger the feet for a broad base; keep the lower forearm supported.|Bacakları uzat ve geniş taban için ayakları şaşırt; alttaki önkol destekli kalsın.',
'Lift for a brief controlled hold; bend knees to exit as soon as control fades.|Kısa kontrollü tutuş için yüksel; kontrol azalınca diz bükerek çık.'],
'Choose 1–2 holds of 3–8 seconds per side with 90 seconds rest, or retain knee support.|90 saniye dinlenmeyle taraf başına 1–2 tutuş 3–8 saniye seç veya diz desteğinde kal.',
['I can keep a steady shoulder rather than hike it toward my ear.|Omzu kulağa çekmek yerine dengeli tutabiliyorum.','Both sides use a manageable variant.|İki taraf da yönetilebilir varyasyon kullanıyor.'],
'Bend one or both knees or return to wall side support.|Bir veya iki dizi bük ya da duvar yan desteğine dön.',
'Stop shoulder pain, dizziness or sudden loss of lateral support.|Omuz ağrısı, baş dönmesi veya ani yan destek kaybında dur.',
'Staggered feet detail and brief side hold; show knee exit, no elevated-foot variation.|Şaşırtılmış ayak detayı ve kısa yan tutuş; dizle çıkış, yükseltilmiş ayak varyasyonu yok.')
lesson('Tuck hollow preparation|Tuck hollow hazırlığı','Understand a short trunk lever before long hollow holds.|Uzun hollow tutuşundan önce kısa gövde kolunu anla.',[
'On a mat, keep knees bent and feet initially supported; choose a comfortable head position.|Matta diz bükülü, ayak başlangıçta destekli; rahat baş konumunu seç.',
'Gently organize ribs and pelvis, then lift one foot or a small part of the upper trunk only if comfortable.|Kaburga ve leğeni nazik düzenle; rahatsa bir ayağı veya üst gövdenin küçük bölümünü kaldır.',
'Return before neck strain or back arching; lifting arms overhead is not required.|Boyun zorlanması veya bel bükülmesinden önce dön; kolları baş üstüne kaldırmak gerekmez.'],
'Try 2 holds of 3–6 seconds with 60 seconds rest; the heel-slide alternative is equally valid.|60 saniye dinlenmeyle 2 tutuş 3–6 saniye dene; topuk kaydırma alternatifi aynı ölçüde geçerli.',
['My neck is comfortable rather than pulled forward.|Boynum öne çekilmek yerine rahat.','I reduce the lever when my back position changes.|Bel konumu değişince kolu kısaltıyorum.'],
'Use supported dead-bug heel slides or upright practice; adapt supine work with pregnancy care advice.|Destekli dead-bug topuk kaydırma veya dik çalışma kullan; gebelikte sırtüstü çalışmayı bakım önerisiyle uyarla.',
'Stop neck/back pain or supine dizziness; never use a painful lower-back press as a target.|Boyun/bel ağrısı veya sırtüstü baş dönmesinde dur; ağrılı bel bastırmayı hedef yapma.',
'Side bent-knee short lever with supported head alternative; no straight-leg maximal hollow.|Yandan bükülü diz kısa kol ve baş destekli alternatif; düz bacak en zor hollow yok.',extra=['nasm_dead','nhs_pregnancy'])
lesson('Hanging knee raise option|Asılı diz kaldırma seçeneği','Move knees without swinging when equipment and grip are ready.|Ekipman ve tutuş hazırsa sallanmadan dizleri hareket ettir.',[
'Use the inspected bar with a stable return step; attempt only after comfortable supported hanging and pulling.|Kontrol edilen bar ve sabit dönüş basamağı kullan; yalnız rahat destekli asılma ve çekiş sonrası dene.',
'Keep one foot firmly on the stable step while lifting only the other knee a small amount; do not throw the leg or remove both feet. Full leg raises and toes-to-bar are later skills.|Yalnız öteki dizi az kaldırırken bir ayağı sabit basamakta sağlam tut; bacağı fırlatma veya iki ayağı kaldırma. Tam bacak ve ayak-bara sonraki beceriler.',
'Fully replace the lifted foot on the step before changing sides; finish with both feet carrying the weight before releasing the bar.|Taraf değiştirmeden kaldırılan ayağı tam basamağa koy; barı bırakmadan iki ayak yükü taşıyarak bitir.'],
'Optional: 1–2 sets of 2–3 small lifts with 120 seconds rest. Without equipment or readiness, use 3–5 seated alternating knee lifts.|İsteğe bağlı: 120 saniye dinlenmeyle 1–2 set 2–3 küçük kaldırış. Ekipman/hazır oluş yoksa 3–5 oturarak sırayla diz kaldır.',
['I do not swing to gain height.|Yükseklik için sallanmıyorum.','My exit remains available throughout.|Çıkışım her an erişilebilir.'],
'Keep feet on support, or use seated marching; free hanging is never required for completion.|Ayakları destekli tut veya oturarak adımla; tamamlamak için serbest asılma gerekmez.',
'Stop grip loss, shoulder pain or swinging that you cannot settle.|Tutuş kaybı, omuz ağrısı veya durduramadığın sallanmada dur.',
'Wide single knee lift, opposite foot planted on stable step throughout; replace foot before switching, then seated option. Never both feet free.|Bir diz kaldır geniş plan; karşı ayak boyunca sabit basamakta. Değiştirmeden ayağı geri koy, sonra oturarak seçenek. İki ayak boşta asla değil.',extra=['nasm_pull'])

module('conditioning','Controlled conditioning|Kontrollü kondisyon',['who','acsm2026'])
lesson('March and step-jack|Adımlama ve adımlı jack','Build rhythm without jumping.|Sıçramadan ritim kur.',[
'Begin with easy marching, seated or standing beside a support.|Oturarak veya destek yanında ayakta kolay adımlamayla başla.',
'If comfortable, step one foot sideways and return before changing sides; arm height is optional.|Rahatsa bir ayağı yana koyup dön, sonra değiştir; kol yüksekliği isteğe bağlı.',
'Keep a conversational effort and an easy stop; speed is not the goal.|Konuşabilecek efor ve kolay duruş koru; hız hedef değil.'],
'Try 2 rounds of 20–30 seconds with 60 seconds rest; reduce time or keep seated marching as needed.|60 saniye dinlenmeyle 2 tur 20–30 saniye dene; gerektiğinde süreyi azalt veya oturarak adımla.',
['I can stop without stumbling.|Tökezlemeden durabiliyorum.','Breathing remains familiar and manageable.|Nefes tanıdık ve yönetilebilir kalıyor.'],
'Use slower seated steps without arm movement.|Kol hareketi olmadan yavaş oturarak adım kullan.',
'Stop unusual breathlessness, chest pain or dizziness.|Alışılmadık nefes darlığı, göğüs ağrısı veya baş dönmesinde dur.',
'Wide low-impact side step and seated march; no jumping jack or breathless montage.|Geniş düşük etkili yan adım ve oturarak adım; sıçramalı jack veya nefessiz montaj yok.')
lesson('Slow incline mountain climber|Yavaş yükseltide mountain climber','Alternate a knee lift while support stays stable.|Destek sabitken sırayla diz kaldır.',[
'Use the same fixed incline as the push-up and check its stability.|Şınavdaki sabit yükseltiyi kullan ve sağlamlığını kontrol et.',
'Bring one knee forward slowly while the supporting foot and arms remain steady.|Destek ayak ve kol dengeliyken bir dizi yavaş öne getir.',
'Return the foot before switching; do not run the feet to beat a timer.|Değiştirmeden ayağı geri koy; sayacı yenmek için ayakları koşturma.'],
'Practice 1–2 sets of 3–5 each side with 60–90 seconds rest; use standing knee lifts if wrists dislike loading.|60–90 saniye dinlenmeyle taraf başına 1–2 set 3–5 yap; bilek yükü rahatsızsa ayakta diz kaldır.',
['My hips do not bounce with every step.|Her adımda kalçam zıplamıyor.','Hands and support remain secure.|El ve destek sağlam kalıyor.'],
'Use a higher support or standing supported marching.|Daha yüksek destek veya ayakta destekli adım kullan.',
'Stop wrist pain, unstable support or inability to keep a slow pace.|Bilek ağrısı, oynayan destek veya yavaş kalamamanda dur.',
'Side fixed incline with alternating slow knee lift; clear planted foot between switches.|Sabit yükseltide yandan yavaş sırayla diz kaldır; değişimler arasında belirgin basan ayak.',extra=['nasm_push'])
lesson('Step-back burpee, no jump|Geri adımlı burpee, sıçrama yok','Connect standing and incline support without impact.|Ayakta duruş ve yükselti desteğini darbesiz bağla.',[
'Use a fixed high bench; hinge and place hands before moving either foot.|Sabit yüksek bank kullan; ayak hareketinden önce kalçadan eğilip elleri koy.',
'Step one foot back then the other to a brief incline support; no push-up is required.|Bir ayağı sonra diğerini geriye koyarak kısa yükselti desteğine geç; şınav gerekmez.',
'Step forward in sequence and stand smoothly; omit jumping and racing.|Sırayla öne adımla ve akıcı kalk; sıçrama ve yarış çıkarılır.'],
'Try 1–2 sets of 2–4 slow cycles with 90 seconds rest; separate the hinge and steps if coordination is new.|90 saniye dinlenmeyle 1–2 set 2–4 yavaş döngü dene; koordinasyon yeniyse eğilme ve adımları ayır.',
['Hands are secure before feet move.|Ayak hareketinden önce eller sağlam.','I can pause at every stage.|Her bölümde durabiliyorum.'],
'Use wall touch plus a single backward step or simple sit-to-stand.|Duvara dokunma ve tek geriye adım veya basit otur-kalk kullan.',
'Stop dizziness when changing level, slipping or back/wrist pain.|Seviye değişiminde baş dönmesi, kayma veya bel/bilek ağrısında dur.',
'Wide fixed high bench full cycle, all contacts visible; no jump, push-up or speed edit.|Sabit yüksek bankta geniş tam döngü, tüm temaslar görünür; sıçrama, şınav veya hızlandırma yok.')
lesson('An easy circuit|Kolay devre','Combine familiar tasks without turning fatigue into proof.|Yorgunluğu kanıt saymadan tanıdık görevleri birleştir.',[
'Choose three familiar options: supported squat, wall push and easy march.|Üç tanıdık seçenek seç: destekli squat, duvar itişi, kolay adımlama.',
'Finish each task with control and take enough rest to reset before the next.|Her görevi kontrolle bitir; sonrakinden önce yenilenecek kadar dinlen.',
'Check how you feel after the round; more rounds are optional, not a completion requirement.|Tur sonrası hissini kontrol et; ek tur isteğe bağlı, tamamlama şartı değil.'],
'One round: 3–5 squats, 3–5 wall pushes, 20 seconds easy march; rest 60–120 seconds between tasks. Optionally repeat once.|Bir tur: 3–5 squat, 3–5 duvar itişi, 20 saniye kolay adım; görev arası 60–120 saniye dinlen. İstersen bir kez yinele.',
['Each movement uses a familiar regression.|Her hareket tanıdık kolay yol kullanıyor.','I do not skip rest to prove fitness.|Formumu kanıtlamak için dinlenmeyi atlamıyorum.'],
'Choose one task or seated versions and longer rests.|Tek görev veya oturarak varyasyonlar ve uzun dinlenme seç.',
'Stop if unusual fatigue alters balance, coordination or breathing.|Alışılmadık yorgunluk denge, koordinasyon veya nefesi değiştirirse dur.',
'Three quiet station shots separated by visible rest; no competitive timer or calorie claims.|Görünür dinlenmeyle ayrılmış üç sakin istasyon; yarış sayacı veya kalori iddiası yok.')

module('support','Support and compression preparation|Destek ve kompresyon hazırlığı',['acsm2026','nasm_push'])
lesson('Light wrist loading|Bileğe hafif yük','Explore tolerated hand support without forcing wrist extension.|Bileği zorla açmadan tolere edilen el desteğini tanı.',[
'Begin with palms on a wall; place fingers comfortably and spread contact across the hand.|Avuç duvarda başla; parmakları rahat yerleştir ve teması ele dağıt.',
'Lean a small amount toward the hands, then return; only use hands-and-knees if this is comfortable.|Ellere biraz eğil ve dön; yalnız rahatsa eller-dizlere geç.',
'Keep the movement small and unload before discomfort; more range is not inherently better.|Hareketi küçük tut, rahatsızlıktan önce yükü al; fazla aralık kendiliğinden daha iyi değil.'],
'Try 1–2 sets of 4 gentle wall leans with 45–60 seconds rest; do not stretch through pain.|45–60 saniye dinlenmeyle 1–2 set 4 nazik duvar eğilmesi dene; ağrının içinden esneme.',
['I can distribute contact without a sharp pressure point.|Keskin basınç noktası olmadan teması dağıtabiliyorum.','I unload smoothly rather than shake out pain.|Ağrıyı silkelemek yerine yükü akıcı alıyorum.'],
'Use forearm-supported tasks or study the setup; alternative handles must also be stable and suitable.|Önkol destekli görev veya kurulum incelemesi kullan; alternatif tutacak da sabit ve uygun olmalı.',
'Stop sharp pain, tingling or symptoms that persist after unloading.|Keskin ağrı, karıncalanma veya yük alınca süren belirtide dur.',
'Palm close-up at wall and small full-body lean; no forced wrist end-range.|Duvarda avuç yakın plan ve küçük tam beden eğilmesi; bilek son aralığı zorlanmıyor.')
lesson('Shoulder support and reach|Omuz desteği ve uzanma','Keep a comfortable shoulder support while changing hand pressure.|El basıncı değişirken rahat omuz desteğini koru.',[
'Use a high fixed incline and establish the earlier scapular support.|Yüksek sabit yükselti kullan ve önceki kürek desteğini kur.',
'Shift a small amount of weight between hands while both remain in contact.|İki el temaslıyken küçük miktar yükü eller arasında aktar.',
'Only if steady, lighten one hand briefly without fully lifting it; maintain an easy foot exit.|Yalnız dengeliyse bir eli tam kaldırmadan kısa hafiflet; kolay ayak çıkışı kalsın.'],
'Practice 1–2 sets of 3 weight shifts each side, resting 60–90 seconds; fully lifting a hand is not required.|60–90 saniye dinlenmeyle taraf başına 1–2 set 3 yük aktarımı yap; eli tam kaldırmak gerekmez.',
['I do not rotate the whole trunk to move pressure.|Basıncı değiştirmek için tüm gövdeyi döndürmüyorum.','The supporting shoulder stays comfortable.|Destek omuz rahat kalıyor.'],
'Use a wall and keep both hands equally loaded.|Duvar kullan ve iki eli eşit yükte tut.',
'Stop shoulder pain or wrist pressure increasing as you shift.|Aktarımda omuz ağrısı veya artan bilek basıncında dur.',
'High incline rear diagonal pressure shift with both hands contacting; wall regression.|İki el temaslı yüksek yükseltide arkadan çapraz yük aktarımı; duvar kolay yolu.')
lesson('Ground pike preparation|Zeminde pike hazırlığı','Recognize an overhead pressing direction while feet remain grounded.|Ayaklar yerdeyken baş üstü itiş yönünü tanı.',[
'After comfortable pressing and wrist/shoulder support, begin on padded hands and knees, hands near shoulders and knees near hips; curl toes onto non-slip ground.|Rahat itiş ve bilek/omuz desteği sonrası yastıklı eller-dizlerde başla; eller omuz, dizler kalça yakını; parmakları kaymayan zemine kıvır.',
'Press lightly through palms and toes to lift knees and hips only a little, knees remaining bent; keep both hands and feet grounded and the head unloaded.|Avuç ve parmaklardan hafif iterek diz ve kalçayı yalnız az kaldır, diz bükülü kalsın; iki el ve ayak yerde, baş yüksüz.',
'Pause briefly, then lower both knees to the mat before releasing hands. Do not press the head toward the floor; pike push-ups and elevated feet are later coached options.|Kısa dur, elleri bırakmadan iki dizi mata indir. Başı zemine itme; pike şınavı ve yükseltilmiş ayak sonra eğitmenli seçenek.'],
'Optional 2 holds of 3–5 seconds with 90 seconds rest, or review the diagram and repeat wall pressing.|İsteğe bağlı 90 saniye dinlenmeyle 2 tutuş 3–5 saniye veya şemayı incele ve duvar itişini yinele.',
['Hands and feet remain grounded with an easy exit.|Kolay çıkışla el ve ayak yerde kalıyor.','My head carries no bodyweight.|Başım beden ağırlığı taşımıyor.'],
'Use wall presses; pregnancy or balance/pressure concerns need individual advice rather than starting inverted practice.|Duvar itişi kullan; gebelik veya denge/basınç endişesinde ters çalışmaya başlamak yerine bireysel danışma gerekir.',
'Stop head pressure, dizziness, neck symptoms or wrist/shoulder pain.|Baş basıncı, baş dönmesi, boyun belirtisi veya bilek/omuz ağrısında dur.',
'Side hands-knees entry, toe placement, tiny bent-knee hip rise and knees-down exit; head never contacts floor. Wall press alternative.|Yandan eller-dizlerde giriş, parmak yerleşimi, küçük diz bükülü kalça yükselişi ve dizle çıkış; baş zemine değmez. Duvar itişi alternatifi.',extra=['nasm_pike','acog'])
lesson('Seated compression|Oturarak kompresyon','Lift a short leg lever without forcing a fold.|Katlanmayı zorlamadan kısa bacak kolunu kaldır.',[
'Sit on a mat or stable seat with a comfortable tall trunk; bend knees enough to avoid pulling the back.|Mat veya sabit oturakta rahat uzun gövdeyle otur; beli çekmeyecek kadar diz bük.',
'Keep hands supporting you beside the hips and lift one foot a small amount.|Elleri kalçanın yanında destekli tut ve bir ayağı az kaldır.',
'Lower quietly and alternate; straight legs and deep forward folding are optional later.|Yumuşak indir ve değiştir; düz bacak ve derin öne katlanma sonra isteğe bağlı.'],
'Use 1–2 sets of 3 lifts each side with 60 seconds rest; a brief unweighting counts as learning.|60 saniye dinlenmeyle taraf başına 1–2 set 3 kaldırış; kısa yük hafifletme öğrenme sayılır.',
['I do not hold my breath to force height.|Yüksekliği zorlamak için nefes tutmuyorum.','The trunk does not round painfully.|Gövde ağrılı yuvarlanmıyor.'],
'Use seated marching on a higher fixed seat and keep hands lightly supported.|Yüksek sabit oturakta adımla; elleri hafif destekli tut.',
'Stop hip pinching, back pain or pressure that prevents comfortable breathing.|Kalça sıkışması, bel ağrısı veya rahat nefesi engelleyen basınçta dur.',
'Front diagonal seated bent-knee single foot lift, hands visible; higher-seat option.|Eller görünen önden çapraz oturarak diz bükülü tek ayak kaldırış; yüksek oturak seçeneği.')
lesson('Foot-assisted L-sit preparation|Ayak yardımlı L-sit hazırlığı','Combine support and compression without a suspended hold.|Asılı tutuş olmadan destek ve kompresyonu birleştir.',[
'Use fixed rated low parallel handles, or study the setup if none are available.|Sabit uygun alçak paralel tutacak kullan; yoksa kurulumu incele.',
'Keep feet planted and hands beside the hips; push lightly to make the seat feel a little lighter.|Ayak yerde, el kalça yanında; oturuşu biraz hafifletmek için hafif it.',
'If comfortable, lift one heel briefly while the other foot remains loaded; do not chase straight suspended legs.|Rahatsa diğer ayak yüklüyken bir topuğu kısa kaldır; havada düz bacak kovalamama.'],
'Try 2–3 supported holds of 3–5 seconds with 90 seconds rest; alternatively combine 3 wall pushes and 3 seated knee lifts.|90 saniye dinlenmeyle 2–3 destekli 3–5 saniye tutuş dene; alternatif 3 duvar itişi ve 3 oturarak diz kaldır.',
['At least one foot can immediately take the load.|En az bir ayak yükü hemen alabilir.','The shoulders do not sink painfully.|Omuzlar ağrılı çökmüyor.'],
'Keep both feet down or retain seated compression without arm loading.|İki ayağı yerde tut veya kola yük vermeden oturarak kompresyonda kal.',
'Stop hand/shoulder pain, unstable handles or breath holding under strain.|El/omuz ağrısı, oynayan tutacak veya zorlanırken nefes tutmada dur.',
'Low rated handles, planted feet and one heel lift; never a floating L-sit hero shot.|Alçak uygun tutacak, basan ayak ve tek topuk kaldır; havada L-sit kahraman planı yok.')

module('literacy','Advanced skill literacy|İleri beceri bilgisi',['acsm2026','ace','acog','nhs_pregnancy'])
lesson('Wall handstand: understand the pathway|Duvar amudu: yolu anla','Identify prerequisites and fall-management needs.|Önkoşul ve düşme yönetimi ihtiyacını belirle.',[
'Inversion changes balance and head position; a wall does not remove fall or wrist/shoulder risks.|Ters duruş denge ve baş konumunu değiştirir; duvar düşme veya bilek/omuz riskini kaldırmaz.',
'Comfortable wrist loading, shoulder support, trunk control and a coached exit are prerequisites to assess with a qualified coach.|Rahat bilek yükü, omuz desteği, gövde kontrolü ve eğitmenli çıkış yetkin eğitmenle değerlendirilecek önkoşullardır.',
'Learn where the wall, clear floor and spotter would be; do not kick up alone from this lesson.|Duvar, boş zemin ve destekçinin yerini öğren; bu dersle tek başına yukarı tekmeleme.'],
'Learning only: sketch the space and list 3 questions for a qualified coach; no inversion attempt is required or recommended here.|Yalnız öğrenme: alanı çiz ve yetkin eğitmene 3 soru yaz; burada ters duruş denemesi gerekli veya önerilen değildir.',
['I can explain why a wall is not medical clearance.|Duvarın neden tıbbi uygunluk izni olmadığını açıklayabiliyorum.','I have identified a coached exit before physical progression.|Fiziksel ilerlemeden önce eğitmenli çıkışı belirledim.'],
'Continue wall presses and supported trunk work. During pregnancy avoid beginning fall-risk inversion practice through this course.|Duvar itişi ve destekli gövde çalışmasına devam et. Gebelikte bu kursla düşme riskli ters çalışmaya başlama.',
'Do not attempt alone; health concerns or symptoms need individual professional advice.|Tek başına deneme; sağlık endişesi veya belirtiler bireysel uzman danışması gerektirir.',
'Non-performing diagram of wall, mat, coach and exit arrows; no kick-up or pregnant inversion actor.|Duvar, mat, eğitmen ve çıkış oklarının uygulamasız şeması; tekmeleme veya gebe ters duruş modeli yok.',kind='learning_only')
lesson('Planche: leverage and patience|Planche: kol uzunluğu ve sabır','Understand straight-arm load without a solo attempt.|Tek başına denemeden düz kol yükünü anla.',[
'A planche places large demands on wrists and straight-arm shoulder support; it is not the next mandatory push-up.|Planche bilek ve düz kol omuz desteğine yüksek yük verir; sonraki zorunlu şınav değildir.',
'Use earlier supported pressing and small pressure shifts as foundations, not proof of planche readiness.|Önceki destekli itiş ve küçük basınç aktarımlarını temel kullan; planche hazır oluş kanıtı sayma.',
'A qualified coach should select progressions and assess equipment and exits; fixed readiness angles are not supplied.|Yetkin eğitmen ilerlemeyi seçip ekipman ve çıkışı değerlendirmeli; sabit hazır oluş açıları verilmez.'],
'Learning only: compare a supported wall press with a planche diagram and identify how the support lever changes; record one coach question.|Yalnız öğrenme: destekli duvar itişini planche şemasıyla karşılaştır, destek kolunun değişimini belirle; bir eğitmen sorusu yaz.',
['I can distinguish education from an instruction to attempt.|Bilgilendirmeyi deneme talimatından ayırabiliyorum.','I do not mark a diagram review as verified planche ability.|Şema incelemesini doğrulanmış planche yeteneği saymıyorum.'],
'Repeat comfortable wall/incline presses; a tuck planche is not necessary to finish the course.|Rahat duvar/yükselti itişini yinele; kursu bitirmek için tuck planche gerekmez.',
'Do not force straight-arm leaning into wrist or shoulder pain.|Düz kol eğilmesini bilek veya omuz ağrısına zorlamama.',
'Annotated static leverage diagram, contact points and coach icon; no physical planche attempt.|Açıklamalı sabit kol şeması, temas noktaları ve eğitmen simgesi; fiziksel planche denemesi yok.',kind='learning_only')
lesson('Front lever: pulling skill pathway|Front lever: çekiş becerisi yolu','Understand why hanging strength does not prove lever readiness.|Asılma kuvvetinin neden lever hazır oluşunu kanıtlamadığını anla.',[
'The front lever uses a long horizontal body lever and a reliable overhead anchor.|Front lever uzun yatay beden kolu ve güvenilir baş üstü bağlantı kullanır.',
'Rows, supported hanging and controlled pulling are foundations; none is a validated automatic readiness test.|Row, destekli asılma ve kontrollü çekiş temeldir; hiçbiri doğrulanmış otomatik hazır oluş testi değildir.',
'Further tucked-lever work needs a qualified coach and appropriate equipment; do not learn by dropping from a bar.|İleri tuck-lever çalışma yetkin eğitmen ve uygun ekipman ister; bardan düşerek öğrenme.'],
'Learning only: list anchor, grip and exit checks and describe why shortening a lever changes demand; no lever hold.|Yalnız öğrenme: bağlantı, tutuş ve çıkış kontrollerini yaz, kol kısaltmanın yükü neden değiştirdiğini anlat; lever tutuşu yok.',
['I know equipment inspection remains necessary at higher levels.|Üst seviyede de ekipman kontrolünün gerektiğini biliyorum.','I have not assumed course completion is lever clearance.|Kurs tamamlamayı lever izni saymadım.'],
'Retain foot-supported hangs or easy rows with reliable equipment.|Güvenilir ekipmanda ayak destekli asılma veya kolay rowda kal.',
'No solo lever attempt from this lesson; shoulder, elbow or grip symptoms need review.|Bu dersle tek başına lever denemesi yok; omuz, dirsek veya tutuş belirtileri inceleme gerektirir.',
'Static bar-and-body lever diagram and shorter lever comparison; no hanging transition stunt.|Sabit bar-beden kol şeması ve kısa kol karşılaştırması; asılı geçiş gösterisi yok.',kind='learning_only',extra=['nasm_pull'])
lesson('Muscle-up: transition literacy|Muscle-up: geçiş bilgisi','Separate pulling, transition and support requirements.|Çekiş, geçiş ve destek gereklerini ayır.',[
'A muscle-up joins a high pull, a transition and upper support; adding speed does not solve missing foundations.|Muscle-up yüksek çekiş, geçiş ve üst desteği bağlar; hız eklemek eksik temeli çözmez.',
'Controlled pulling and dip support need individual coaching before a transition plan; no kipping requirement is introduced.|Geçiş planından önce kontrollü çekiş ve dip desteği bireysel eğitmen ister; kipping şartı konmaz.',
'Equipment, height and a coached exit must match the skill; this course does not prescribe a bar turnover attempt.|Ekipman, yükseklik ve eğitmenli çıkış beceriye uymalı; bu kurs bardan aşma denemesi yazmaz.'],
'Learning only: label the three phases on a diagram and write which foundation you would revisit; no jumping or turnover practice.|Yalnız öğrenme: şemada üç bölümü etiketle ve döneceğin temeli yaz; sıçrama veya barı aşma pratiği yok.',
['I can name the transition as a separate learning problem.|Geçişi ayrı öğrenme sorunu olarak adlandırabiliyorum.','I choose coaching rather than compensating with momentum.|Momentumla telafi yerine eğitmen seçiyorum.'],
'Continue assisted pulling and foot-supported dip preparation.|Yardımlı çekiş ve ayak destekli dip hazırlığına devam et.',
'Do not attempt an unsupported transition alone; pain or unreliable equipment ends the pathway.|Tek başına desteksiz geçiş deneme; ağrı veya güvenilmez ekipman yolu durdurur.',
'Three labelled static panels for pull/transition/support with coach gate; no moving muscle-up demo.|Çekiş/geçiş/destek için üç etiketli sabit panel ve eğitmen kapısı; hareketli muscle-up demosu yok.',kind='learning_only',extra=['nasm_pull'])

module('programming','Build your own manageable practice|Yönetilebilir pratiğini kur',['acsm2026','who'])
lesson('Choose a regression honestly|Kolay yolu dürüstçe seç','Select the variant you can repeat today.|Bugün tekrarlayabileceğin varyasyonu seç.',[
'Begin with one easy trial repetition or short hold, not a maximum test.|En yüksek test yerine bir kolay deneme tekrarı veya kısa tutuşla başla.',
'Choose the variant whose breathing, exit and coordination remain manageable.|Nefes, çıkış ve koordinasyonu yönetilebilir varyasyonu seç.',
'Change one variable later: range, repetitions, support height or leverage; do not change all together.|Sonra tek değişken değiştir: aralık, tekrar, destek yüksekliği veya kol; hepsini birlikte değil.'],
'Compare 3 wall pushes with 3 familiar incline pushes after 90 seconds rest, or only study the options if needed; choose one for today.|90 saniye dinlenerek 3 duvar itişini 3 tanıdık yükselti itişiyle karşılaştır veya gerekirse yalnız seçenekleri incele; bugün için birini seç.',
['I choose based on control rather than the lesson number.|Ders numarasına değil kontrole göre seçiyorum.','I leave reserve instead of testing failure.|Tükenmeyi test etmek yerine pay bırakıyorum.'],
'Stay with the easiest familiar option, including supported or seated tasks.|Destekli veya oturarak görev dahil en kolay tanıdık seçenekte kal.',
'Stop progression when symptoms or repeated loss of control occur.|Belirti veya tekrarlanan kontrol kaybında ilerlemeyi durdur.',
'Split screen wall and incline at matching pace; neutral choice labels, no winner.|Eş tempoda duvar ve yükselti bölünmüş ekran; nötr seçim etiketleri, kazanan yok.')
lesson('A balanced week|Dengeli hafta','Plan movement groups and recovery rather than daily exhaustion.|Günlük tükenme yerine hareket grupları ve toparlanma planla.',[
'General adult guidance includes strength work for major muscle groups on at least two days weekly; individual needs can differ.|Genel yetişkin önerisi temel kas gruplarına haftada en az iki gün kuvvet çalışması içerir; bireysel ihtiyaç farklı olabilir.',
'Choose squat/hinge, push, reliable pull and trunk options, with light aerobic movement; do not force pulling without equipment.|Squat/hinge, itiş, güvenilir çekiş ve gövde seçeneğiyle hafif aerobik hareket seç; ekipmansız çekişi zorlama.',
'Leave recovery between demanding sessions and use easy practice or rest when control is not restored.|Zorlu seanslar arasında toparlanma bırak; kontrol dönmemişse kolay pratik veya dinlenme kullan.'],
'Write a sample two-day strength week separated by recovery, using 1–2 short sets per chosen task; this is a planning example, not a personalized prescription.|Arada toparlanma olan örnek iki günlük kuvvet haftası yaz; seçilen görevde 1–2 kısa set kullan. Bu plan örneği, kişiye özel reçete değil.',
['My week includes pulling only where reliable equipment is available.|Haftam yalnız güvenilir ekipman varsa çekiş içeriyor.','I can reduce volume without treating it as failure.|Hacmi azaltmayı başarısızlık saymıyorum.'],
'Plan shorter sessions or consult a professional about health-specific scheduling.|Kısa seans planla veya sağlık durumuna özel takvimi uzmanla görüş.',
'Do not schedule through worsening symptoms or poor recovery.|Artan belirtiler veya yetersiz toparlanmanın içinden takvim sürdürme.',
'Plain weekly cards with two example strength days and recovery spaces; no personalized health promise.|İki örnek kuvvet günü ve toparlanma boşluklu sade hafta kartları; kişiye özel sağlık vaadi yok.',kind='learning_only')
lesson('Progress, repeat or recover|İlerle, yinele veya toparlan','Decide the next session from repeated observations.|Sonraki seansı tekrarlanan gözlemlerle seç.',[
'Look for several sessions where the chosen range and exit remain controlled; a single good repetition is not a guarantee.|Seçilen aralık ve çıkışın kontrollü kaldığı birkaç seansa bak; tek iyi tekrar garanti değil.',
'If comfortable, add one or two repetitions or a small lever change; keep the other variables unchanged.|Rahatsa bir-iki tekrar veya küçük kol değişimi ekle; diğer değişkenleri sabit tut.',
'If fatigue or symptoms increase, repeat an easier task or recover instead; a course checklist is not a training deadline.|Yorgunluk veya belirti artarsa kolay görevi yinele veya toparlan; kurs listesi antrenman son tarihi değil.'],
'Write three next-session choices for your current squat or push: repeat, small increase, easier/rest; state what would lead to each.|Mevcut squat veya itiş için sonraki seansa üç seçim yaz: yinele, küçük artış, kolay/dinlenme; her birinin nedenini belirt.',
['I can name a reason to stay easier.|Kolayda kalmak için bir neden söyleyebiliyorum.','I do not confuse lesson completion with physiological readiness.|Ders tamamlamayı fizyolojik hazır oluşla karıştırmıyorum.'],
'Choose recovery and review one earlier lesson without physical practice.|Toparlanmayı seç ve fiziksel pratik olmadan önceki bir dersi incele.',
'Persistent or worsening pain needs individual review, not a harder progression.|Süren veya artan ağrı daha zor ilerleme değil bireysel inceleme ister.',
'Three neutral next-session choices beside a practice log; no automatic readiness gauge.|Pratik kaydının yanında üç nötr sonraki seans seçimi; otomatik hazır oluş göstergesi yok.',kind='learning_only')

module('integration','Independent practice and review|Bağımsız pratik ve değerlendirme',['acsm2026','who','nhs_strength'])
lesson('Lower body and push review|Alt beden ve itiş değerlendirmesi','Apply the setup and control checks to two familiar tasks.|Kurulum ve kontrol denetimini iki tanıdık göreve uygula.',[
'Choose a comfortable sit-to-stand or squat and a wall or incline push-up.|Rahat otur-kalk veya squat ve duvar/yükselti şınavı seç.',
'Check support, foot/hand contact, breath and exit before each set.|Her setten önce destek, ayak/el teması, nefes ve çıkışı kontrol et.',
'After each set describe one control observation and keep the next set no harder if unsure.|Her set sonrası bir kontrol gözlemi anlat; belirsizse sonraki seti zorlaştırma.'],
'One or two rounds of 3–6 squats and 3–6 pushes, resting 90–120 seconds between tasks; use your easier variant.|Görev arasında 90–120 saniye dinlenerek bir-iki tur 3–6 squat ve 3–6 itiş; kendi kolay varyasyonunu kullan.',
['My squat uses an individually comfortable depth.|Squatım kişisel rahat derinliği kullanıyor.','My push keeps hips and shoulders connected.|İtişim kalça ve omzu bağlantılı tutuyor.'],
'Use supported sit-to-stand and wall pressing, or review without exertion.|Destekli otur-kalk ve duvar itişi veya efor olmadan inceleme kullan.',
'Stop changing joint pain or fatigue that alters your exit.|Değişen eklem ağrısı veya çıkışı bozan yorgunlukta dur.',
'Matched squat and wall-press control shots with support audit; no before/after physique claim.|Destek kontrolüyle eş squat ve duvar itişi planları; önce/sonra fizik görünümü iddiası yok.')
lesson('Pull and trunk review|Çekiş ve gövde değerlendirmesi','Keep equipment limits visible while combining pulling and trunk work.|Çekiş ve gövdeyi birleştirirken ekipman sınırını görünür tut.',[
'Use the reliable row setup if available; otherwise review its checks instead of improvising equipment.|Varsa güvenilir row düzenini kullan; yoksa doğaçlama ekipman yerine kontrollerini incele.',
'Choose bird-dog or incline plank at a comfortable support level.|Rahat destek seviyesinde bird-dog veya yükseltide plank seç.',
'Rest between tasks and check whether grip or shoulder fatigue changes the trunk task.|Görev arasında dinlen; tutuş/omuz yorgunluğu gövde görevini değiştiriyor mu kontrol et.'],
'If equipped, 1–2 sets of 3–5 easy rows and 3 bird-dogs each side or 5–10 seconds incline plank, with 90–120 seconds rest.|Ekipman varsa 90–120 saniye dinlenerek 1–2 set 3–5 kolay row ve taraf başına 3 bird-dog veya 5–10 saniye yükseltide plank.',
['I retained a foot-supported exit during pulling.|Çekişte ayak destekli çıkışı korudum.','Trunk control remains steady after the pull.|Çekiş sonrası gövde kontrolü dengeli kalıyor.'],
'Study the row and use a standing supported trunk task; do not label unloaded rehearsal as strength-equivalent pulling.|Rowu incele ve ayakta destekli gövde görevi kullan; yüksüz provayı eş kuvvetli çekiş sayma.',
'Stop grip failure, anchor movement or shoulder/back pain.|Tutuş tükenmesi, bağlantı hareketi veya omuz/bel ağrısında dur.',
'Rated row setup, then supported bird-dog or incline plank; no improvised-table row.|Uygun row düzeni, ardından destekli bird-dog veya yükseltide plank; doğaçlama masa row yok.',extra=['nasm_pull','ace_bird'])
lesson('Design your own short session|Kendi kısa seansını tasarla','Choose a workable sequence with explicit rest and alternatives.|Açık dinlenme ve alternatifle uygulanabilir sıra seç.',[
'Begin with an easy warm-up, then choose one lower, one push, one available pull and one trunk task.|Kolay ısınmayla başla; bir alt beden, bir itiş, bir mevcut çekiş ve bir gövde görevi seç.',
'Use familiar small doses and rests; omit unavailable equipment work and note the gap honestly.|Tanıdık küçük doz ve dinlenme kullan; olmayan ekipman çalışmasını çıkar ve boşluğu dürüst yaz.',
'Finish with easy walking or seated movement and one observation for next time.|Rahat yürüyüş/oturarak hareket ve sonraki sefere bir gözlemle bitir.'],
'Write a 10–20 minute example with 1 short set per task and 60–120 seconds rest, then optionally rehearse only the first two tasks.|Görev başına 1 kısa set ve 60–120 saniye dinlenmeyle 10–20 dakikalık örnek yaz; istersen yalnız ilk iki görevi prova et.',
['I included an easier option for every task.|Her göreve kolay seçenek ekledim.','My plan has no forced inversion or maximum test.|Planımda zorunlu ters duruş veya en yüksek test yok.'],
'Build a seated/support-based session or discuss a tailored plan with a qualified professional.|Oturarak/destekli seans kur veya yetkin uzmanla uyarlanmış plan görüş.',
'Stop if symptoms appear during rehearsal; editing the plan is part of learning.|Provada belirti varsa dur; planı değiştirmek öğrenmenin parçası.',
'Original session worksheet with warm-up, four options, rest and exit notes; no automated medical plan.|Isınma, dört seçenek, dinlenme ve çıkış notlu özgün seans sayfası; otomatik tıbbi plan yok.')
lesson('A repeatable independent practice|Tekrarlanabilir bağımsız pratik','Finish with a repeatable plan and clear limits.|Tekrarlanabilir plan ve açık sınırlarla bitir.',[
'Revisit your chosen variants and explain their setup, one control cue and one easier path without the lesson text.|Ders metni olmadan seçtiğin varyasyonun kurulumu, bir kontrol ipucu ve bir kolay yolunu anlat.',
'If appropriate today, perform the familiar short session without adding a new skill or intensity.|Bugün uygunsa yeni beceri/yoğunluk eklemeden tanıdık kısa seansı yap.',
'Choose what to repeat next week and what needs a coach; completion records your learning, not professional mastery.|Gelecek hafta yineleyeceğini ve eğitmen gerekeni seç; tamamlama profesyonel ustalık değil öğrenme kaydıdır.'],
'Use your previous plan once with its rests, or complete a written walkthrough if physical practice is unsuitable; record the appropriate progress state.|Önceki planını dinlenmeleriyle bir kez kullan veya fiziksel pratik uygun değilse yazılı yürüt; uygun ilerleme durumunu kaydet.',
['I can explain my regressions and stop signs.|Kolay yollarımı ve durma işaretlerini açıklayabiliyorum.','I know this course did not certify inversions, force, angles or medical safety.|Bu kursun ters duruş, kuvvet, açı veya tıbbi güvenliği onaylamadığını biliyorum.'],
'Repeat earlier modules at the same supported level; completing the reading does not oblige harder practice.|Önceki modülleri aynı destekli seviyede yinele; okumayı bitirmek zor pratiği zorunlu yapmaz.',
'Stop new or worsening symptoms and seek appropriate advice; a finished checklist does not override them.|Yeni/artan belirtilerde dur ve uygun danışma al; tamamlanan liste bunları geçersiz kılmaz.',
'Calm repeat session and personal next-week notebook; no certificate, elite badge or guaranteed transformation.|Sakin yineleme seansı ve kişisel gelecek hafta notu; sertifika, elit rozet veya garantili dönüşüm yok.')

for m in modules:
    del m['source_ids']
assert lesson_count==56 and [len(m['lessons']) for m in modules]==[6,8,7,7,8,4,5,4,3,4]
course={'schemaVersion':1,'id':'calisthenics-foundations','version':'1.0.0','title':b('Calisthenics: a complete foundation|Calisthenics: bütünlüklü temel'), 'description':b('56 original lessons from supported basics to independent practice, with intermediate options and advanced skill literacy. Follow your own pace; adaptations remain valid.|Destekli temelden bağımsız pratiğe 56 özgün ders; orta seviye seçenekler ve ileri beceri bilgisi. Kendi hızında ilerle; uyarlamalar geçerlidir.'), 'evidenceMode':'self_report','healthNotice':b('General education for adults, not personalized treatment or medical clearance. For injury, pregnancy or a chronic condition, consult a clinician or qualified professional about appropriate activity. Avoid beginning fall-risk inversions during pregnancy; adapt prolonged supine tasks with your care team. Stop for new or worsening pain, dizziness, chest discomfort, faintness or unusual breathlessness and seek appropriate help. Progress is self-reported; camera mastery scoring is not part of this course.|Yetişkinler için genel eğitim; kişiye özel tedavi veya tıbbi uygunluk izni değildir. Yaralanma, gebelik veya kronik durumda uygun etkinliği klinisyen ya da yetkin uzmanla görüş. Gebelikte düşme riskli ters duruşlara başlamaktan kaçın; uzun sırtüstü görevleri bakım ekibiyle uyarla. Yeni/artan ağrı, baş dönmesi, göğüs rahatsızlığı, baygınlık hissi veya alışılmadık nefes darlığında dur ve uygun yardım al. İlerleme öz bildirimdir; kamera ustalık puanı bu kursa dahil değildir.'),'sources':[{'id':id,'title':title,'url':url} for id,title,url in sources],'modules':modules}
# Explicit teaching links. Preparations are not equivalent full-skill practice,
# and advanced reading remains separate from physical or camera capability.
course['catalogueGuides'] = [
    {'movementId': movement, 'kind': kind,
     'lessonIds': [f'cal-{number:02d}' for number in numbers]}
    for movement, kind, numbers in [
        ('bodyweight_squat', 'practice', [8]),
        ('push_up', 'practice', [15, 16, 17, 18, 19, 20]),
        ('bird_dog', 'practice', [29]),
        ('dead_bug', 'practice', [30]),
        ('hanging_leg_raise', 'preparation', [36]),
        ('hollow_hold', 'preparation', [35]),
        ('mountain_climber', 'preparation', [38]),
        ('plank', 'practice', [31, 32]),
        ('side_plank', 'practice', [33, 34]),
        ('glute_bridge', 'practice', [10]),
        ('lunge', 'practice', [11, 12]),
        ('calf_raise', 'practice', [14]),
        ('step_up', 'practice', [13]),
        ('burpee', 'preparation', [39]),
        ('inverted_row', 'practice', [23, 24]),
        ('pull_up', 'preparation', [25, 26, 27, 28]),
        ('dip', 'preparation', [21]),
        ('wall_handstand', 'readingOnly', [46]),
        ('tuck_planche', 'readingOnly', [47]),
    ]
]
root=Path(__file__).resolve().parents[1]
# The original authoring script still owns the lesson skeleton and media
# briefs. The reviewed v8d layer owns later pedagogy/source edits. Applying it
# keeps the course comparison independent of the shipped JSON. The reviewed
# Historical v8d output had noncanonical whitespace. Keep its exact byte SHA
# as a parent pin; v8g renders a new canonical course asset below.
baseline=json.dumps(course,ensure_ascii=False,indent=2)+'\n'
v8d_path=root/'content/courses/calisthenics.v8d-overlay.json'
overlay=json.loads(v8d_path.read_text(encoding='utf-8'))
if overlay.get('schemaVersion') != 1 or overlay.get('editorialLayer') != 'v8d':
    raise ValueError('Unsupported calisthenics editorial layer')
if hashlib.sha256(baseline.encode('utf-8')).hexdigest() != overlay['baselineSha256']:
    raise ValueError('Calisthenics authoring baseline changed; review and repin the v8d layer')
lesson_by_id={item['id']:item for module in modules for item in module['lessons']}
changes=overlay['lessonOverrides']
if set(changes) != set(lesson_by_id):
    raise ValueError('Calisthenics editorial layer must name all 56 current lessons')
allowed={'objective','steps','practice','selfCheck','sourceIds'}
for lesson_id, fields in changes.items():
    if not fields or not set(fields) <= allowed:
        raise ValueError(f'Unexpected editorial fields for {lesson_id}')
    lesson_by_id[lesson_id].update(fields)
course['description']=overlay['description']
course['sources']=overlay['sources']

# v8d is immutable historical evidence. v8g applies only two instruction
# corrections, with a digest of the complete v8d semantic parent. The old
# reviewed JSON had a few noncanonical indentation lines, so its historical
# byte SHA and its reproducible semantic SHA are intentionally distinct.
v8g=json.loads((root/'content/courses/calisthenics.v8g-overlay.json').read_text(encoding='utf-8'))
if v8g.get('schemaVersion') != 1 or v8g.get('editorialLayer') != 'v8g':
    raise ValueError('Unsupported calisthenics v8g editorial layer')
if hashlib.sha256(v8d_path.read_bytes()).hexdigest() != v8g['parentOverlaySha256']:
    raise ValueError('Historical v8d overlay changed')
if v8g['parentCourseSha256'] != overlay['courseSha256']:
    raise ValueError('Historical reviewed course SHA changed')
parent_semantic=json.dumps(course,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode('utf-8')
if hashlib.sha256(parent_semantic).hexdigest() != v8g['parentSemanticSha256']:
    raise ValueError('Historical v8d course semantics changed')
if course['version'] != v8g['courseVersion'] or course['version'] != '1.0.0':
    raise ValueError('This editorial correction must preserve progress version 1.0.0')
expected_fields={
    'cal-04': {'steps','practice','mediaBrief'},
    'cal-24': {'steps','practice','selfCheck','mediaBrief'},
}
changes=v8g['lessonOverrides']
if set(changes) != set(expected_fields):
    raise ValueError('v8g may change only cal-04 and cal-24')
for lesson_id, fields in changes.items():
    if set(fields) != expected_fields[lesson_id]:
        raise ValueError(f'Unexpected v8g fields for {lesson_id}')
    prior=lesson_by_id[lesson_id]
    if len(fields['steps']) != len(prior['steps']):
        raise ValueError(f'v8g changed the lesson step count for {lesson_id}')
    if 'selfCheck' in fields and len(fields['selfCheck']) != len(prior['selfCheck']):
        raise ValueError(f'v8g changed the self-check count for {lesson_id}')
    prior.update(copy.deepcopy(fields))
added_sources=v8g['addedSources']
if [item['id'] for item in added_sources] != ['nhs_warmup','ace_trx_angle','trx_low_row']:
    raise ValueError('Unexpected v8g source registry addition')
if {item['id'] for item in course['sources']} & {item['id'] for item in added_sources}:
    raise ValueError('v8g source id already exists')
course['sources'].extend(copy.deepcopy(added_sources))
source_adds=v8g['lessonSourceAdds']
if source_adds != {'cal-04':['nhs_warmup'],'cal-24':['ace_trx_angle','trx_low_row']}:
    raise ValueError('Unexpected v8g lesson source additions')
for lesson_id, ids in source_adds.items():
    lesson_by_id[lesson_id]['sourceIds'].extend(ids)
rendered_course=json.dumps(course,ensure_ascii=False,indent=2)+'\n'
if hashlib.sha256(rendered_course.encode('utf-8')).hexdigest() != v8g['courseSha256']:
    raise ValueError('v8g course SHA does not match the reviewed output')

# v8h only attributes exact movement branches to original publisher pages.
# Preserve the v8g lesson bodies and teaching dose: these URLs are teaching
# references, never camera labels, equipment certificates or load thresholds.
v8h=json.loads((root/'content/courses/calisthenics.v8h-overlay.json').read_text(encoding='utf-8'))
if v8h.get('schemaVersion') != 1 or v8h.get('editorialLayer') != 'v8h':
    raise ValueError('Unsupported calisthenics v8h source layer')
if hashlib.sha256((root/'content/courses/calisthenics.v8g-overlay.json').read_bytes()).hexdigest() != v8h['parentOverlaySha256']:
    raise ValueError('Historical v8g overlay changed')
if hashlib.sha256(rendered_course.encode('utf-8')).hexdigest() != v8h['parentCourseSha256']:
    raise ValueError('v8h source layer is not bound to the reviewed v8g course')
if course['version'] != v8h['courseVersion'] or course['version'] != '1.0.0':
    raise ValueError('Source attribution must preserve progress version 1.0.0')
added_sources=v8h['addedSources']
if [item['id'] for item in added_sources] != [
    'ace_wrist_shoulder_options','nhs_seated_leg_march',
    'tjc_fixed_bar_row','barbend_fixed_bar_row',
]:
    raise ValueError('Unexpected v8h source registry addition')
if {item['id'] for item in course['sources']} & {item['id'] for item in added_sources}:
    raise ValueError('v8h source id already exists')
if any(not item['url'].startswith('https://') for item in added_sources):
    raise ValueError('v8h source URL must use HTTPS')
source_adds=v8h['lessonSourceAdds']
if source_adds != {
    'cal-04':['ace_wrist_shoulder_options','nhs_seated_leg_march'],
    'cal-24':['tjc_fixed_bar_row','barbend_fixed_bar_row'],
}:
    raise ValueError('v8h may bind only verified warm-up and fixed-bar branches')
if not {'ace_trx_angle','trx_low_row'} <= set(lesson_by_id['cal-24']['sourceIds']):
    raise ValueError('v8h must preserve separate suspension sources')
course['sources'].extend(copy.deepcopy(added_sources))
for lesson_id, ids in source_adds.items():
    lesson_by_id[lesson_id]['sourceIds'].extend(ids)
rendered_course=json.dumps(course,ensure_ascii=False,indent=2)+'\n'
if hashlib.sha256(rendered_course.encode('utf-8')).hexdigest() != v8h['courseSha256']:
    raise ValueError('v8h course SHA does not match the reviewed source attribution')

# v8i adds only the five directly inspected, narrow teaching citations. They
# do not assert a tested load, camera event, clinical clearance or media grant.
v8i=json.loads((root/'content/courses/calisthenics.v8i-overlay.json').read_text(encoding='utf-8'))
if v8i.get('schemaVersion') != 1 or v8i.get('editorialLayer') != 'v8i':
    raise ValueError('Unsupported calisthenics v8i source layer')
if hashlib.sha256((root/'content/courses/calisthenics.v8h-overlay.json').read_bytes()).hexdigest() != v8i['parentOverlaySha256']:
    raise ValueError('Historical v8h overlay changed')
if hashlib.sha256(rendered_course.encode('utf-8')).hexdigest() != v8i['parentCourseSha256']:
    raise ValueError('v8i source layer is not bound to the reviewed v8h course')
if course['version'] != v8i['courseVersion'] or course['version'] != '1.0.0':
    raise ValueError('v8i source attribution must preserve progress version 1.0.0')
added_sources=v8i['addedSources']
if [item['id'] for item in added_sources] != [
    'psv_level_ground_calf_raise',
    'mckenzie_standing_bar_dip_proposal',
    'henderson_supported_scapular_pull',
    'torbay_nhs_heel_slide',
    'cleveland_step_supported_burpee',
]:
    raise ValueError('Unexpected v8i source registry addition')
if {item['id'] for item in course['sources']} & {item['id'] for item in added_sources}:
    raise ValueError('v8i source id already exists')
if any(not item['url'].startswith('https://') for item in added_sources):
    raise ValueError('v8i source URL must use HTTPS')
source_adds=v8i['lessonSourceAdds']
if source_adds != {
    'cal-14':['psv_level_ground_calf_raise'],
    'cal-21':['mckenzie_standing_bar_dip_proposal'],
    'cal-26':['henderson_supported_scapular_pull'],
    'cal-30':['torbay_nhs_heel_slide'],
    'cal-39':['cleveland_step_supported_burpee'],
}:
    raise ValueError('v8i may bind only five verified teaching claims')
course['sources'].extend(copy.deepcopy(added_sources))
for lesson_id, ids in source_adds.items():
    lesson_by_id[lesson_id]['sourceIds'].extend(ids)
rendered_course=json.dumps(course,ensure_ascii=False,indent=2)+'\n'
if hashlib.sha256(rendered_course.encode('utf-8')).hexdigest() != v8i['courseSha256']:
    raise ValueError('v8i course SHA does not match the reviewed source attribution')
attribution=json.loads((root/'tool/calisthenics_source_attribution.v1.json').read_text(encoding='utf-8'))
if attribution.get('schemaVersion') != 1 or attribution['parentCourseSha256'] != v8i['parentCourseSha256'] or attribution['courseSha256'] != v8i['courseSha256']:
    raise ValueError('v8i narrow attribution contract is not pinned to this course')
if attribution['sourceResearchManifestSha256'] != '43fad359a41f456b6742d2bc2d54ce645943276afd1745da01146a11a9bac301':
    raise ValueError('v8i source research provenance changed')
if any(attribution[key] != 0 for key in ['generatedMediaCount','acceptedExpertLabelCount','qualifiedModelCount']):
    raise ValueError('Teaching citations are not accepted media, labels, or models')
if set(attribution['sources']) != {s['id'] for s in added_sources}:
    raise ValueError('v8i source attribution must cover exactly the five new sources')
expected_lesson_by_source={ids[0]:lesson_id for lesson_id,ids in source_adds.items()}
for source in added_sources:
    claim=attribution['sources'][source['id']]
    if (claim['lessonId'] != expected_lesson_by_source[source['id']]
            or any(claim[key] != source[key] for key in ['url','supports','doesNotSupport'])
            or not claim['locator'] or not claim['rights']
            or claim['realPersonErrorLabel'] is not False
            or claim['modelTrainingRightsVerified'] is not False
            or claim['automaticFormVerdictSupported'] is not False):
        raise ValueError(f'Unsupported or unscoped v8i attribution: {source["id"]}')

# v8j adds three original articles to four matching lesson variants. The
# Harvard push-up article is one document and publisher, even though it covers
# both a wall and a kneeling branch. The ACE hollowing lead stays unbound:
# its pelvic-floor/core protocol is not taught in cal-35.
v8j=json.loads((root/'content/courses/calisthenics.v8j-overlay.json').read_text(encoding='utf-8'))
if v8j.get('schemaVersion') != 1 or v8j.get('editorialLayer') != 'v8j':
    raise ValueError('Unsupported calisthenics v8j source layer')
if hashlib.sha256((root/'content/courses/calisthenics.v8i-overlay.json').read_bytes()).hexdigest() != v8j['parentOverlaySha256']:
    raise ValueError('Historical v8i overlay changed')
if hashlib.sha256(rendered_course.encode('utf-8')).hexdigest() != v8j['parentCourseSha256']:
    raise ValueError('v8j source layer is not bound to the reviewed v8i course')
if course['version'] != v8j['courseVersion'] or course['version'] != '1.0.0':
    raise ValueError('v8j source attribution must preserve progress version 1.0.0')
added_sources=v8j['addedSources']
if [item['id'] for item in added_sources] != [
    'strongfirst_wall_hinge',
    'harvard_wall_kneeling_pushups',
    'harvard_forearm_plank_options',
]:
    raise ValueError('Unexpected v8j source registry addition')
if {item['id'] for item in course['sources']} & {item['id'] for item in added_sources}:
    raise ValueError('v8j source id already exists')
if any(not item['url'].startswith('https://') or not item['supports'] or not item['doesNotSupport'] for item in added_sources):
    raise ValueError('v8j sources require scoped HTTPS citations')
source_adds=v8j['lessonSourceAdds']
if source_adds != {
    'cal-09':['strongfirst_wall_hinge'],
    'cal-15':['harvard_wall_kneeling_pushups'],
    'cal-17':['harvard_wall_kneeling_pushups'],
    'cal-32':['harvard_forearm_plank_options'],
}:
    raise ValueError('v8j may bind only four verified teaching branches')
course['sources'].extend(copy.deepcopy(added_sources))
for lesson_id, ids in source_adds.items():
    if set(ids) & set(lesson_by_id[lesson_id]['sourceIds']):
        raise ValueError(f'v8j duplicate citation on {lesson_id}')
    lesson_by_id[lesson_id]['sourceIds'].extend(ids)
rendered_course=json.dumps(course,ensure_ascii=False,indent=2)+'\n'
if hashlib.sha256(rendered_course.encode('utf-8')).hexdigest() != v8j['courseSha256']:
    raise ValueError('v8j course SHA does not match the reviewed source attribution')
attribution_v2=json.loads((root/'tool/calisthenics_source_attribution.v2.json').read_text(encoding='utf-8'))
if (attribution_v2.get('schemaVersion') != 2
        or attribution_v2['sourceResearchManifestSha256'] != 'dec2b43795a06b456bfb6b64f3645d836574a8d4ada8b41b09d959d4a2e8ebb6'
        or attribution_v2['parentCourseSha256'] != v8j['parentCourseSha256']
        or attribution_v2['courseSha256'] != v8j['courseSha256']):
    raise ValueError('v8j narrow attribution contract is not pinned to this course')
if any(attribution_v2[key] != 0 for key in ['generatedMediaCount','acceptedExpertLabelCount','qualifiedModelCount']):
    raise ValueError('v8j citations are not accepted media, labels, or models')
if attribution_v2['heldCandidateLessonId'] != 'cal-35' or attribution_v2['heldCandidateUrl'] != 'https://www.acefitness.org/resources/everyone/exercise-library/121/supine-hollowing-with-lower-extremity-movements/':
    raise ValueError('ACE hollowing prerequisite hold must remain explicit')
if set(attribution_v2['sources']) != {s['id'] for s in added_sources}:
    raise ValueError('v8j attribution must cover the three added original articles')
for source in added_sources:
    claim=attribution_v2['sources'][source['id']]
    lessons=[lesson for lesson,ids in source_adds.items() if source['id'] in ids]
    if (claim['lessonIds'] != lessons
            or any(claim[key] != source[key] for key in ['url','supports','doesNotSupport'])
            or not claim['locator'] or not claim['rights']
            or claim['realPersonErrorLabel'] is not False
            or claim['modelTrainingRightsVerified'] is not False
            or claim['automaticFormVerdictSupported'] is not False):
        raise ValueError(f'Unsupported or unscoped v8j attribution: {source["id"]}')

# v8k scopes three existing teaching citations and binds only four exact
# branches. The Harvard URL is reused for cal-40's wall station, not counted
# as another document. G391's historical shoulder_reach remains NO_CALL.
v8k=json.loads((root/'content/courses/calisthenics.v8k-overlay.json').read_text(encoding='utf-8'))
if set(v8k) != {
    'schemaVersion','editorialLayer','parentOverlaySha256','parentCourseSha256',
    'courseVersion','courseSha256','existingSourceScopes','addedSources',
    'lessonSourceAdds',
} or v8k['schemaVersion'] != 1 or v8k['editorialLayer'] != 'v8k':
    raise ValueError('Unsupported calisthenics v8k source layer')
if hashlib.sha256((root/'content/courses/calisthenics.v8j-overlay.json').read_bytes()).hexdigest() != v8k['parentOverlaySha256']:
    raise ValueError('Historical v8j overlay changed')
if hashlib.sha256(rendered_course.encode('utf-8')).hexdigest() != v8k['parentCourseSha256']:
    raise ValueError('v8k source layer is not bound to the reviewed v8j course')
if course['version'] != v8k['courseVersion'] or course['version'] != '1.0.0':
    raise ValueError('v8k source attribution must preserve progress version 1.0.0')
scope_updates=v8k['existingSourceScopes']
if set(scope_updates) != {
    'ace_wrist_shoulder_options','nhs_seated_leg_march','barbend_fixed_bar_row',
}:
    raise ValueError('v8k may scope only the three reviewed existing sources')
sources_by_id={item['id']:item for item in course['sources']}
for source_id, fields in scope_updates.items():
    if set(fields) not in ({'supports','doesNotSupport'},
                           {'title','supports','doesNotSupport'}):
        raise ValueError(f'Unexpected existing source fields for {source_id}')
    for field in ('supports','doesNotSupport'):
        if set(fields[field]) != {'en','tr'} or any(not fields[field][lang].strip() for lang in ('en','tr')):
            raise ValueError(f'Invalid v8k source scope for {source_id}')
    sources_by_id[source_id].update(copy.deepcopy(fields))
new_sources=v8k['addedSources']
if [item['id'] for item in new_sources] != [
    'trx_anchor_low_row','hybrid_assisted_bar_hang','worcs_nhs_wall_four_point_wrist',
]:
    raise ValueError('Unexpected v8k source registry addition')
if set(s['id'] for s in new_sources) & set(sources_by_id):
    raise ValueError('v8k source id already exists')
for source in new_sources:
    if set(source) != {'id','title','url','supports','doesNotSupport'} or not source['url'].startswith('https://'):
        raise ValueError(f'Invalid v8k source record: {source["id"]}')
    for field in ('supports','doesNotSupport'):
        if set(source[field]) != {'en','tr'} or any(not source[field][lang].strip() for lang in ('en','tr')):
            raise ValueError(f'Invalid v8k source scope: {source["id"]}')
source_adds=v8k['lessonSourceAdds']
if source_adds != {
    'cal-24':['trx_anchor_low_row'],
    'cal-25':['hybrid_assisted_bar_hang'],
    'cal-40':['harvard_wall_kneeling_pushups'],
    'cal-41':['worcs_nhs_wall_four_point_wrist'],
}:
    raise ValueError('v8k may bind only four exact teaching branches')
course['sources'].extend(copy.deepcopy(new_sources))
for lesson_id, ids in source_adds.items():
    if set(ids) & set(lesson_by_id[lesson_id]['sourceIds']):
        raise ValueError(f'v8k duplicate citation on {lesson_id}')
    lesson_by_id[lesson_id]['sourceIds'].extend(ids)
rendered_course=json.dumps(course,ensure_ascii=False,indent=2)+'\n'
actual_sha=hashlib.sha256(rendered_course.encode('utf-8')).hexdigest()
if actual_sha != v8k['courseSha256']:
    raise ValueError(f'v8k course SHA does not match scoped attribution: {actual_sha}')
manifest={'schemaVersion':1,'courseId':course['id'],'courseVersion':course['version'],'status':'brief_only_not_generated_or_coach_reviewed','trainingData':False,'lessons':[{'moduleId':m['id'],'lessonId':l['id'],'practiceType':l['practiceType'],'mediaBrief':l['mediaBrief']} for m in modules for l in m['lessons']]}
parser=argparse.ArgumentParser(); parser.add_argument('--check',action='store_true');args=parser.parse_args()
for path,rendered in [
    ('content/courses/calisthenics.v1.json',rendered_course),
    ('content/courses/calisthenics.media-briefs.v1.json',json.dumps(manifest,ensure_ascii=False,indent=2)+'\n'),
]:
    target=root/path
    if args.check:
        assert target.read_text(encoding='utf-8')==rendered, f'Stale generated asset: {path}'
    else:
        target.write_text(rendered,encoding='utf-8')
print('56 lessons / 10 modules; original bilingual content and brief manifest verified')
