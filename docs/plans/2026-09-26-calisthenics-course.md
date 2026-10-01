# Gravita — ilk calisthenics kursu / 2026-09-26

## Yetki ve mevcut durum
Kurucunun onayladığı beş-kurs tasarımı ve özerk uygulama talimatı kapsamıdır. Yalnız bu app değişir. HEAD `a308f8f03295cc4c8c4bb545aa8155a30afc76e9`; başlangıç WIP `.github/workflows/checks.yml`, korunur. Commit/push, shared core, provider, Vault, imza, deploy ve simülatör yok.

## Önce model kanıtı
31 katalog hareketinde yalnız `bodyweight_squat`, `push_up` live; 29 coming_soon. Öğretim bunları açmaz. Üç engine fixture: squat 14,103,022 B, axis-swap 21,013 B, correct-frames 119,476 B. Harvest 19 JSON; push manifest 15 eğitmen/27 video/9 nitelikli eğitmen iddiası taşır. `standard-youtube` etiketi indirme, eğitim veya kişinin rızası kanıtı değildir. Yeni izinli kişi etiketli holdout bulunamadı; yeni eğitim yapılmaz ve gerçek insanlarda yeni doğruluk iddiası yok. August model-gate tarihsel örnek/cihaz koşullarını NOT_MET gösterir; eski 20/200 gibi eşikler yeni kabul protokolüne dönüştürülmez. Yeni kurs öz bildirimdir; kamera, ustalık, güvenlik veya klinik açı puanı üretmez.

## Tercih
Ölçüm kataloğuna ekleme, mevcut 8 haftalık ölçüm programını büyütme ve ayrı öğretim yolu seçenekleri incelendi. Ayrı sürümlü asset seçildi: geniş kapsamı ölçüm kanıtı gibi göstermeden öğretir, mevcut program sözleşmesini korur, her dersin kaynak ve uyarlamasını taşır.

## Ders sırası
56 ders / 10 modül: temeller 6; alt beden 8; itiş 7; çekiş 7; gövde 8; kondisyon 4; destek/kompresyon 5; ileri beceri bilgisi 4; programlama 3; bütünleştirme 4. Önceki ders önerilen önkoşul; bütün içerik okunabilir. Yeterlilik sertifikası veya garantili ileri beceri yok. Kişi kolay yolu kullanarak öğrenme görevini bitirebilir. Dört ileri ders `learning_only`, fiziksel deneme zorunlu değil.

## Kalıcılık ve UI
`content/courses/calisthenics.v1.json`, ayrı typed validator. Home ve Library görünür kart; Gravita Public Sans, mevcut cam kart/palet. Kurs ekranı toplam/modül ilerlemesi, önerilen sıradaki ders ve üç ayrı kayıt türü. Ders ekranı teknik adımlar, doz seçenekleri, öz denetim, kolay yol, durma işareti, kaynak URLleri ve önkoşul.
Dosya hesap UUID dizininde, misafir kökte; sürümlü ad. Seen/practised/selfReportedComplete ayrı tarih/sayaç. Dosya başına seri okuma-modifikasyon-yazma ve temp+rename. Hesap silmeden önce generation invalidation + eski yazıları bekleme; eski ekrandan yeniden doğma engellenir. Hesap değişimi UI belleğini sıfırlar; önceki sürüm toplamlarına katılmaz.

## Sağlık ve kaynaklar
Sağlık bilgisi geneldir; bireysel tedavi/rehab reçetesi veya uygunluk kararı yok. Gebelikte düşme riski taşıyan inversiyonlar önerilmez; uzun sırtüstü pozisyonlar için danışma ve ayakta/destekli alternatif. Yeni/artan ağrı, baş dönmesi, göğüs ağrısı, baygınlık veya alışılmadık nefes darlığında durma ve uygun sağlık desteği; gebelik uyarılarında bakım ekibi. RPE ve küçük başlangıç dozları özgün eğitim seçenekleri, evrensel klinik eşik değil.
Doğrulanan birincil kaynaklar: ACSM 2026 https://acsm.org/resistance-training-guidelines-update-2026/ ; WHO https://www.who.int/initiatives/behealthy/physical-activity ; NHS https://www.nhs.uk/live-well/exercise/strength-exercises/ ; ACE https://www.acefitness.org/resources/everyone/exercise-library/ ; ACOG https://www.acog.org/womens-health/faqs/exercise-during-pregnancy (web renderer hata; klinik sayfa arama içerik, FAQ HTTP doğrulaması); NHS https://www.nhs.uk/pregnancy/keeping-well/exercise/ ; NASM resmi push-up/pull-up/plank/dead-bug/pike-push-up sayfaları; ACE bird-dog.
Kaynaklar genel prensip ve teknik bağlam sağlar; bu özgün 56 dersin etkinliğini klinik olarak doğrulamaz. NASM sayfalarındaki mutlak açı/yaralanma önleme ifadeleri aktarılmaz. Tek beden için sabit squat derinliği veya dirsek açısı puanlanmaz.

## Katalog kapsam matrisi
- Çekirdek: squat, push_up, bird_dog, dead_bug, glute_bridge, lunge, calf_raise, step_up, plank, side_plank, hollow_hold, inverted_row, pull_up, dip hazırlığı, mountain_climber, düşük etkili burpee.
- İleri bilgi: wall_handstand, tuck_planche; front lever/muscle-up ek bilgi, kamera kapısı yok.
- Asılı gövde: hanging_leg_raise/toes_to_bar yerine başlangıç diz kaldırma + ekipmansız alternatif; tam bacak/ayak-bara hareketleri ileri beceri, zorunlu değil.
- Wall_sit/superman_hold ayrı zorunlu ders değil: squat ve kontrollü bird-dog/hinge ile temel işlev; her varyasyonun zorunlu olması öğrenme bütünlüğü şartı değil.
- Ağırlıklı farmer_carry, floor_press, kb_swing, romanian_deadlift, goblet_squat, db_curl, db_row, db_shoulder_press, lateral_raise ayrı ağırlık kursuna ait; çekirdeğe zorlanmaz. Mevcut katalog ve ölçüm statüleri aynen korunur.

## Medya ve depolama
Her derste özel TR/EN shot brief; toplu authoring manifest. AI medya henüz üretilmedi; eğitmen teknik incelemesi ardından demo, model eğitimi verisi değil. Telifli kaynak video kopyalanmaz. Geçici indirme yok; yalnız scratch/2026-09-26-motion-courses altında izinli olursa exact path/license/hash/cleanup receipt.

## Uygulama / kanıt
- [x] Yönerge, tema/hesap, model/fixture/license araştırması
- [x] 56 özgün TR/EN ders + manifest + validator
- [x] Atomik/seri hesap kapsamlı ilerleme ve silme yarışı
- [x] Home/Library, kurs/ders gerçek UI
- [x] Dosyadan yeniden okuma, hesap/sürüm, eşzamanlı/silme ve widget erişim testleri
- [x] Tam analiz, regresyon, diff ve katalog statü readback
- [x] Dated evidence/cleanup notu; cihaz/store/medya sınırları açık

Native smoke ayrı hazırlandı; SDK dev dependency ve lock yalnız bu amaçla eklendi. Bu ajanda build/boot koşulmadı; parent seri cihaz slotunda native sonuç ayrı kaydedilecek.
