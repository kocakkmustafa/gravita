import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/live_strings.dart';
import 'package:gravita/app/onboarding_strings.dart';
import 'package:motion_camera/motion_camera.dart';

/// ⭐ G-213 — **İLK EKRANIN VAADİ, ÜRÜNÜN YAPTIĞIYLA AYNI MI?**
///
/// ## Kapattığı kusur
///
/// Onboarding'in ilk kartı — *her yeni kullanıcının gördüğü ilk cümle* —
/// şunu diyordu:
/// > *"Your phone camera **watches your form** and counts your reps…
/// > **When a rule fires, we tell you what to change.**"*
///
/// `G-212`de ölçüldü: kuralları değerlendiren API
/// (`RepEngine.correctionFor` / `topCorrection` / `repMetrics`) **üründe HİÇ
/// ÇAĞRILMIYOR**; tek çağıran çevrimdışı `tool/replay_gate.dart`. Canlı
/// seansta hiçbir kural ateşlenmiyor, kimseye bir şey söylenmiyor.
///
/// Aynı yalan **kamera izni gerekçesinde** de vardı: *"count reps **and check
/// your form**"*. Orası, kullanıcıya *"kameranı şunun için istiyorum"* denen
/// yerdir — yapılmayan bir işi oraya yazmak, izni **yanlış gerekçeyle**
/// almaktır.
///
/// > ***BİR ÜRÜNÜN İLK CÜMLESİ, EN ÇOK OKUNAN CÜMLESİDİR — ORADAKİ BİR VAAT,
/// > EN PAHALI VAATTİR.***
///
/// ## ⚠️ SINIF FARKI — ve neden süpürgem bunu KAÇIRDI
///
/// `G-210`/`G-212` **bayat YOKLUK** cümleleriydi: *"yok"* diyordu, sonradan
/// var olmuştu. Bu ise **yanlış VARLIK** cümlesi: *"var"* diyordu, hiç
/// olmamıştı.
/// `H-10`un görevini koşarken *"not saved · no cue · not available"* gibi
/// **yokluk** kalıpları taradım — ve bu sınıf o ağa **tanımı gereği**
/// takılmaz. Bulan şey süpürge değil, **uygulamayı açıp ilk ekranı okumak**
/// oldu.
/// > ***BİR SÜPÜRGE YALNIZ ARADIĞI SINIFI BULUR; "TEMİZ" DEDİĞİ ŞEY,
/// > TARADIĞI SINIFTIR — ÜRÜN DEĞİL.***
void main() {
  /// Ürünün BUGÜN yapmadığı, dolayısıyla hiçbir vitrin metninin vaat
  /// edemeyeceği işler. Liste dar ve ADLI — geniş bir yasak listesi
  /// kurmuyorum, yalnız ÖLÇÜLMÜŞ olanı yasaklıyorum (`G-212`).
  /// ⚠️ **LİSTE YALNIZ OLUMLU KALIPLAR İÇERİR — ve bu bedelle öğrenildi.**
  ///
  /// İlk hâlinde `'corrects you'` de buradaydı ve kapı **kendi düzeltmemi
  /// kırmızı yaktı**: dürüst cümle *"…and **nothing corrects you** while you
  /// train"* aynı alt dizgiyi taşıyor. Yani yasak listesi **olumsuzlamayı
  /// göremiyordu** ve *"bunu YAPMIYORUZ"* diyen bir cümleyi *"bunu vaat
  /// ediyoruz"* sandı.
  ///
  /// > ***BİR ALT DİZGİ YASAĞI, CÜMLENİN OLUMLU MU OLUMSUZ MU OLDUĞUNU
  /// > BİLMEZ — "X YOK" DİYEN CÜMLE DE "X" İÇERİR.***
  ///
  /// Bu, bütün gece kovaladığım dizgi-kapısı körlüğünün (`M-F-598` ailesi)
  /// **kendi testimde** çıkan hâlidir. Liste bu yüzden yalnız **olumlu
  /// biçimde kurulabilen** kalıpları taşıyor; olumsuz hâlin serbest olduğu
  /// aşağıda AYRICA sınanıyor ki kimse dürüst cümleyi "kapıyı geçsin diye"
  /// silmesin.
  const List<String> yapilmayanIsler = <String>[
    'tell you what to change',
    'check your form',
    'watches your form',
    'we correct you',
  ];

  test('onboarding ilk kartı, ürünün YAPMADIĞI bir şeyi vaat etmiyor', () {
    final String s = OnboardingStrings.valueWhatWeDo.toLowerCase();
    for (final String vaat in yapilmayanIsler) {
      expect(
        s,
        isNot(contains(vaat)),
        reason:
            'İlk ekran "$vaat" vaat ediyor ama G-212\'de ölçüldü: '
            'kural değerlendirmesi üründe hiç çağrılmıyor.',
      );
    }
  });

  test('kamera izni gerekçesi, yapılmayan bir işle GEREKÇELENDİRİLMİYOR', () {
    final String s = OnboardingStrings.cameraRationale.toLowerCase();
    for (final String vaat in yapilmayanIsler) {
      expect(
        s,
        isNot(contains(vaat)),
        reason:
            'İzin gerekçesi "$vaat" diyor. Yapılmayan bir işle izin '
            'istemek, izni yanlış gerekçeyle almaktır.',
      );
    }
  });

  /// ⭐ ÇAPRAZ TUTARLILIK — `H-10` sınıfı, iki AYRI YÜZEY arasında.
  ///
  /// Aynı iznin iki gerekçesi var: onboarding kartı ve kamera reddi ekranı.
  /// `onboarding_strings.dart`taki yorum *"iki yerde iki farklı gerekçe
  /// olmaz"* diyordu — ama bu YALNIZ ikinci cümleler için tutuyordu; birinci
  /// cümleler ayrışmıştı ve ayrışan yarı YANLIŞ olandı.
  test(
    'onboarding needs no camera while the engine permission copy stays scoped',
    () {
      final String onb = OnboardingStrings.cameraRationale.toLowerCase();
      final String ret = LiveStrings.failureBody(
        CameraFailure.permissionDenied,
      ).toLowerCase();

      expect(onb, contains('do not need camera access'));
      expect(onb, contains('unavailable in this release'));
      expect(ret, contains('count'));

      // …ve ikisi de saymanın ÖTESİNDE bir yetenek iddia etmez.
      for (final String vaat in yapilmayanIsler) {
        expect(
          ret,
          isNot(contains(vaat)),
          reason: 'Ret ekranı da aynı sınırda kalmalı.',
        );
      }
    },
  );

  /// ⭐ POZİTİF YÖN — yasak cümleyi silmek yetmez.
  ///
  /// Bu olmadan metni boşaltarak da geçilebilirdi: *"hiçbir şey vaat etme"*
  /// bir dürüstlük değil, bir sessizliktir. İlk ekran ürünün GERÇEKTEN
  /// yaptığını söylemek zorunda.
  test('ilk kart, ürünün GERÇEKTEN yaptığını söylüyor', () {
    final String s = OnboardingStrings.valueWhatWeDo.toLowerCase();
    expect(s, contains('56 calisthenics lessons as a guest'));
    expect(s, contains('save self-reported learning progress on this device'));
    expect(s, isNot(contains('camera counts')));
    expect(s, contains('does not grade'));
  });

  /// ⭐ OLUMSUZ HÂL SERBEST — ve bunu bir kapı KORUYOR.
  ///
  /// Yasak listesi bir kez `'corrects you'` içerdi ve dürüst cümleyi kırmızı
  /// yaktı. O yanlışın en olası "düzeltmesi" cümleyi SİLMEKTİ — yani kapıyı
  /// geçmek için dürüstlüğü atmak. Bu test onu imkânsız kılıyor: ürün
  /// düzeltmediğini SÖYLEMEK ZORUNDA.
  test(
    'düzeltmediğini SÖYLEYEN cümle korunuyor — sessizlik dürüstlük değil',
    () {
      final String s = OnboardingStrings.valueWhatWeDo.toLowerCase();
      expect(
        s,
        contains('live camera sessions are unavailable in this release'),
      );
      expect(s, contains('or verify your technique'));
    },
  );
}
