import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/gravita_app.dart';
import 'package:gravita/app/home_screen.dart';
import 'package:gravita/app/library_screen.dart';
import 'package:gravita/app/onboarding_store.dart';
import 'package:gravita/app/profile_screen.dart';
import 'package:gravita/app/progress_view.dart';
import 'package:gravita_engine/gravita_engine.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/launch_harness.dart';

/// **SEANS DÜĞMESİ, SEKMELERİN SON SATIRINI YUTUYOR MU?**
///
/// ## Neden var — simülatörde görüldü, 177 test yeşilken (G-203)
///
/// Kabuğun seans düğmesi `centerFloat` ile içeriğin ÜSTÜNDE yüzüyor. Bir
/// listenin sonunda düğme kadar boşluk ayrılmazsa **son kart hiçbir kaydırma
/// konumunda temize çıkmaz** — kullanıcı onu asla tam göremez.
///
/// Ölçüldü: `home` · `library` · `profile` zaten **96** ayırıyordu,
/// `progress` **40**. Yani kural biliniyordu ve **bir yerde uygulanmamıştı**
/// — en sinsi kusur biçimi, çünkü üç doğru örnek onu *"böyle yapılıyor"*
/// diye örtüyor.
///
/// > ***BİR KURALIN ÜÇ YERDE DOĞRU UYGULANMASI, DÖRDÜNCÜDE UYGULANDIĞINI
/// > SÖYLEMEZ — ve çoğunluğun doğruluğu, azınlığı GÖRÜNMEZ KILAR.***
///
/// ## Pay SİHİRLİ SAYI DEĞİL — düğmenin kendi geometrisinden TÜRETİLİYOR
///
/// `96` yazsaydım, düğme büyüdüğü gün kapı **sessizce yetersiz** kalırdı:
/// yeşil, ama koruduğu şey artık yetmiyor.
///
/// > ***SABİT YAZILMIŞ BİR PAY, ÖLÇTÜĞÜ ŞEY DEĞİŞTİĞİNDE SESSİZCE YANLIŞ
/// > OLUR — bir eşik, kaynağından türetilmediği sürece bir TAHMİNDİR.***
///
/// ## ⛔ KAPSAM — bu kapının ÖLÇMEDİĞİ (bilerek)
///
/// *Ayrılan pay*ı ölçer, *son kartın gerçekten göründüğünü* değil. İkisi
/// aynı şey değildir (liste kaydırılabilir olmayabilir, içerik kısa olabilir).
/// Daha güçlüsü kurulabilir; bu kapı o iddiayı **taşımıyor** ve taşıdığını
/// söylemiyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('kabuk sekmelerinin HEPSİ seans düğmesi kadar pay ayırıyor',
      (WidgetTester tester) async {
    final Directory tmp = Directory.systemTemp.createTempSync('fab_clearance');
    // ⚠️ `deleteSync` — `addTearDown` geri çağrıları da SAHTE SAATLİ bölgede
    // koşuyor ve `await delete` süiti asıyor (FakeAsync tuzağının dördüncü
    // görünüşü, `shell_end_to_end_test` ile aynı gerekçe).
    addTearDown(() => tmp.deleteSync(recursive: true));
    final PathProviderPlatform defaultProvider = PathProviderPlatform.instance;
    addTearDown(() => PathProviderPlatform.instance = defaultProvider);

    await realIo(
        tester,
        () => OnboardingStore.forFile(File('${tmp.path}/onboarding.json'))
            .markComplete());

    // GERÇEK TELEFON ÖLÇÜSÜ. Harness'ın 1200×4000 varsayılanı bu soruyu
    // ölçemez: geniş/uzun bir ekranda listeler kaydırılabilir bile olmaz ve
    // örtülme HİÇ doğmaz — *bir kusuru göremeyen ölçü, kusurun yokluğunu
    // kanıtlamaz.*
    await bootGravitaRoot(tester,
        supportPath: tmp.path,
        restoreTo: defaultProvider,
        size: const Size(375, 812));

    expect(find.byType(GravitaShell), findsOneWidget);

    // ⚠️ `ProgressTab` geçmişini ASENKRON yüklüyor; oturmadan `ProgressView`
    // ağaçta YOKTUR ve *"sekme inşa edilmemiş"* diye okunur.
    // > ***BİR ÖLÇÜMÜN ZAMANLAMASI DA KAPSAMININ PARÇASIDIR: erken bakan
    // > göz, "yok" ile "henüz yok"u ayırt edemez.***
    //
    // 🔴 AMA ÇÖZÜM `runAsync` DEĞİL — ve bunu bir kırmızı öğretti. Boyanmış
    // ekranda gerçek-zaman turu açmak `google_fonts`u uyandırıyor,
    // `fonts.gstatic.com` reddi **sahipsiz zone hatası** olarak testi
    // düşürüyor (`takeException` bunu göremez; harness'ın §② şerhi).
    // Harness'ın döngüsü zaten `CircularProgressIndicator` ekranda OLDUĞU
    // SÜRECE gerçek tur açıyor — `ProgressTab`ın kendi yükleyicisi de o
    // koşula dâhil, yani sekme **boot sırasında** oturuyor. Burada tek
    // gereken sahte-saatli birkaç kare.
    // > ***BİR PANZEHİRİ TEKRAR YAZMADAN ÖNCE, ZATEN UYGULANMIŞ OLUP
    // > OLMADIĞINI ÖLÇ — ikinci ev, birincinin korumasını da bozar.***
    //
    // 🪤 VE HARNESS'IN DÖNGÜSÜ BU SEKMEYİ OTURTAMIYOR — iki katman ölçüldü:
    // ① döngü `find.byType(CircularProgressIndicator)` diyor, `find`ın
    //    varsayılanı OFFSTAGE'i atlıyor ⇒ `ProgressTab`ın offstage yükleyicisi
    //    sayılmıyor, döngü erken çıkıyor (aynı varsayılan bu dosyada İKİNCİ
    //    kez ısırdı) · ② sekmeyi öne alıp sahte-saatli kare atmak da yetmiyor:
    //    `path_provider` GERÇEK bir tur istiyor, ve boyanmış ekranda gerçek
    //    tur açmak **B5 duvarıdır** (`fonts.gstatic.com` → sahipsiz zone).
    //
    // ⇒ ÖLÇÜM BÖLÜNDÜ (bu hattın M-F-578 kuralı: *bir ölçümü bölmek,
    //   parçaların birbirini TANIMASINI gerektirir*). Kabukta ölçülen
    //   **pay eşiği**, aşağıda tek başına pump edilen `ProgressView`e
    //   TAŞINIYOR — çünkü `padding` widget'ın KENDİ özelliği, nasıl
    //   barındırıldığından bağımsız.
    //   ⚠️ Bölmenin BEDELİ adıyla: `ProgressView`in kabuk içindeki gerçek
    //   dikdörtgeni bu testte ölçülmüyor; eşik **kardeş sekmeden** alınıyor
    //   (aynı görüş alanı). Bu bir varsayım değil, ölçülmüş bir eşitlik:
    //   dört sekme de aynı `IndexedStack` gövdesinde duruyor.
    final Finder fab = find.byKey(GravitaShell.startSessionKey);
    expect(fab, findsOneWidget,
        reason: 'VAKUM: seans düğmesi çizilmemiş — pay iddiası anlamsız. '
            '(Düğme nöbetli: canlı yol yoksa ÇİZİLMEZ, ve o durumda bu '
            'kapının ölçeceği bir şey yoktur.)');
    final Rect fabRect = tester.getRect(fab);

    // 🔴 REFERANS DÜZELTİLDİ — ilk türetim EKRANIN altını almıştı ve
    // **dört sekmeyi birden** kusurlu ilan etti (gereken 152, hepsi 96/40).
    // Oysa liste ekranın altına kadar UZANMIYOR: `bottomNavigationBar`
    // altta bir bant tutuyor ve listenin kendi dikdörtgeni orada bitiyor.
    // Yanlış referansla ölçseydim ÜÇ DOĞRU sekmeyi "düzeltecektim".
    //
    // > ***BİR PAYI YANLIŞ REFERANSA GÖRE ÖLÇMEK, DOĞRU OLANI DA KUSURLU
    // > İLAN EDER — ve bir kapının yanlış pozitifi, ürünü kusura DOĞRU
    // > iter.***
    //
    // Doğru referans her sekme için AYRI: o listenin kendi alt kenarı.

    // `IndexedStack` dört sekmeyi de İNŞA EDİYOR ⇒ dördü de tek geçişte
    // ölçülebiliyor; sekmeye tıklamak bu soru için gerekli değil.
    // ⚠️ `skipOffstage: false` ZORUNLU — ve bu bir ölçümün ürünü:
    // `IndexedStack` seçili olmayan sekmeleri **offstage** tutar, `find`ın
    // varsayılanı ise onları ATLAR. İlk yazışımda `Library` *"inşa
    // edilmemiş"* göründü; oysa inşa edilmişti, ARACIN kapsamı dışındaydı.
    // > ***BİR ARACIN VARSAYILANI, ÖLÇTÜĞÜN ŞEYİN SINIRINI SESSİZCE
    // > ÇİZER*** — "bulunamadı", "yok" değildir.
    final Map<String, Finder> sekmeler = <String, Finder>{
      'Today': find.byType(HomeScreen, skipOffstage: false),
      'Library': find.byType(LibraryScreen, skipOffstage: false),
      'Profile': find.byType(ProfileScreen, skipOffstage: false),
    };

    final List<String> eksik = <String>[];
    double? esik; // kardeş sekmeden taşınan pay eşiği (bkz. bölme şerhi)
    for (final MapEntry<String, Finder> e in sekmeler.entries) {
      expect(e.value, findsOneWidget, reason: '${e.key} sekmesi inşa edilmemiş');
      final Finder liste = find.descendant(
          of: e.value,
          matching: find.byType(ListView, skipOffstage: false),
          matchRoot: false,
          skipOffstage: false);
      expect(liste, findsWidgets, reason: '${e.key}: kaydırılabilir liste yok');
      final ListView lv = tester.widget<ListView>(liste.first);
      final EdgeInsets pad = (lv.padding ?? EdgeInsets.zero) as EdgeInsets;
      // Bu listenin görüş alanının altı ile düğmenin üstü arasındaki bant.
      final double gerekenPay =
          tester.getRect(liste.first).bottom - fabRect.top;
      // Düğme bu listenin üstünde hiç durmuyorsa (bant ≤ 0) ölçülecek bir
      // örtülme yoktur — sıfır pay da GEÇERLİ bir cevaptır.
      if (gerekenPay <= 0) continue;
      esik = gerekenPay;
      if (pad.bottom < gerekenPay) {
        eksik.add('${e.key}: pay ${pad.bottom} < gereken '
            '${gerekenPay.toStringAsFixed(1)}');
      }
    }

    // ── BÖLMENİN İKİNCİ YARISI: `ProgressView` tek başına ─────────────────
    //
    // ⚠️ VAKUM: kabuk yarısı hiç eşik üretmediyse aşağıdaki kontrol
    // *"karşılaştıracak sayı yok"* diye SESSİZCE atlanırdı — ve bölünmüş bir
    // ölçümde en kolay kaybolan şey, ikinci parçanın hiç koşmamasıdır.
    expect(esik, isNotNull,
        reason: 'VAKUM: kabuk yarısı hiçbir sekmede pay eşiği üretmedi; '
            'ikinci yarı karşılaştırılacak sayıyı bulamaz');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProgressView(
          summary: ProgressSummary.build(
            lessonSurfaces: const <LessonSurface>[
              LessonSurface(
                id: 'fx.reps',
                displayName: 'Reps that count',
                movementName: 'Fixture Movement',
                unitLabel: 'rep',
                gradedToday: false,
              ),
            ],
            records: const <SessionRecord>[],
          ),
        ),
      ),
    ));
    await tester.pump();

    final Finder progressListe = find.descendant(
        of: find.byType(ProgressView),
        matching: find.byType(ListView, skipOffstage: false),
        matchRoot: false,
        skipOffstage: false);
    expect(progressListe, findsWidgets, reason: 'Progress: liste yok');
    final ListView plv = tester.widget<ListView>(progressListe.first);
    final EdgeInsets ppad = (plv.padding ?? EdgeInsets.zero) as EdgeInsets;
    if (ppad.bottom < esik!) {
      eksik.add('Progress: pay ${ppad.bottom} < gereken '
          '${esik.toStringAsFixed(1)} (kardeş sekmeden taşındı)');
    }

    expect(eksik, isEmpty,
        reason: 'Seans düğmesi bu sekme(ler)in son satırını kalıcı olarak '
            'örtüyor — kullanıcı onu hiçbir kaydırma konumunda tam göremez');
  });
}
