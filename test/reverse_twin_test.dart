import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravita/app/library_strings.dart';
import 'package:gravita/app/theme.dart';

/// ⭐ TERS NEGATİF İKİZLER — JabLab aktarımı (2026-08-07).
///
/// ## Normal ikizden farkı
///
/// Şimdiye kadarki bütün negatif ikizlerim *"düzeltme kaldırılırsa kırılır
/// mı"* diye soruyordu — yani kapının **dar kalmasını** koruyorlardı.
/// Ters ikiz öteki yönü kapatır: **kapı sonradan FAZLA GENİŞLETİLİRSE**
/// kırılır.
///
/// > **Kural: her dar kapı, DARLIĞINI koruyan bir ikiz taşımalı.**
///
/// ## Neden bu gece ödendi
///
/// Fazla geniş bir sınır bu gece bende **iki kez** ödendi ve ikisinde de
/// geri daraltan şey bir ölçüm değil, **fark etmekti**:
/// - *"kamera önizlemesi mimari olarak imkânsız"* (koordinatör daralttı)
/// - *"motor confidence ÖLÇMÜYOR"* (G-130, ben daralttım)
///
/// İkisi de bir kapıya değil bir CÜMLEYE aitti; ama aynı şey kapıya olursa
/// fark eden kimse olmayabilir — çünkü kapı **yeşil kalmaz, kırmızıya
/// döner** ve o an doğru refleks "kapıyı gevşet" gibi görünür.
/// **Ters ikiz, o anı önceden çiviler.**
///
/// Ayrıca bu, bu hattın kanıtlı sınıfının ÜÇÜNCÜ yönü: K7c ve
/// `validate_catalog` kapının **yanlış kapsamıyla** ilgiliydi; bu, kapının
/// **sonradan genişlemesiyle**.
void main() {
  group('öksüz-anahtar kapısı fazla genişlerse', () {
    test('İÇ KAYIT ön eki (`_` / `\$`) muafiyeti YAŞAMALI', () {
      // Biri bir gün *"tanımlanmamış her anahtar hata olsun"* derse,
      // `$comment` · `$curatedNote` · `_why_unlocked` kırmızıya döner ve o an
      // kapıyı gevşetme baskısı doğar. Bu ikiz, ön-ek sözleşmesinin
      // kaldırılamayacağını çiviliyor.
      //
      // Ön ek bir BEYANDIR: *"bunu kimse okumuyor ve okumamalı."* Kaldırmak,
      // beyanlı iç kaydı öksüz anahtarla aynı kovaya atmak olurdu — oysa
      // ikisi tam TERS şeyler: biri gerekçe defteri, öteki unutulmuş iddia.
      final String src = File('test/orphan_key_test.dart').readAsStringSync();
      expect(src.contains('declaredInternal'), isTrue,
          reason: 'İç-kayıt ön eki muafiyeti kaldırılmış — `\$comment` ve '
              '`_why_unlocked` artık öksüz sayılır ve kapıyı gevşetme '
              'baskısı doğar.');

      // Ve muafiyetin GERÇEKTEN gerekli olduğu: dosyada iç kayıt VAR.
      final Map<String, dynamic> lib =
          (jsonDecode(File('content/library.json').readAsStringSync()) as Map)
              .cast<String, dynamic>();
      expect(lib.keys.where((String k) => k.startsWith(r'$')), isNotEmpty,
          reason: 'İç kayıt kalmamış — muafiyet artık bir şey korumuyor, '
              've korumayan bir muafiyet kör noktadan başka bir şey değil.');
    });
  });

  group('dil nöbeti fazla genişlerse', () {
    test('DÜRÜST bekleme dili YAŞAMALI — "waiting"/"missing"/"closed"', () {
      // ⚠️ En gerçek risk bu. Nöbet vaat dilini yasaklıyor ("yet", "coming
      // soon"). Biri bir gün *"bekleme çağrıştıran her sözcüğü yasaklayalım"*
      // derse, ürünün EN DÜRÜST cümleleri ölür:
      //
      //   · "Waiting on a measurement"  → kuyruk başlığı (29 kez içerikte)
      //   · "3 measurements missing"    → kartın gerekçe satırı (91 kez)
      //   · "CLOSED"                    → rozet, üretilmiş blurb ile aynı söz
      //
      // Fark şu: *"yet"* bir ZAMAN vaat eder; *"waiting/missing/closed"* bir
      // DURUM bildirir. Kapı zamanı yasaklamalı, durumu değil — ve bu ikiz
      // o ayrımı mekanikleştiriyor.
      expect(LibraryStrings.honestyWaitingLabel.toLowerCase(),
          contains('waiting'));
      expect(LibraryStrings.blockerCount(3), contains('missing'));
      expect(LibraryStrings.queuedBadge.toUpperCase(), 'CLOSED');

      final String prose = jsonEncode(
          (jsonDecode(File('content/library.json').readAsStringSync()) as Map)
              .cast<String, dynamic>()['movements']).toLowerCase();
      for (final String honest in <String>['waiting', 'missing', 'closed']) {
        expect(prose.contains(honest), isTrue,
            reason: '"$honest" içerikten silinmiş — dil nöbeti fazla '
                'genişletilmiş olabilir. Vaat DEĞİL durum bildiren sözcükler '
                'yasaklanamaz, yoksa geriye söylenecek dürüst cümle kalmaz.');
      }
    });
  });

  group('literal-renk yasağı fazla genişlerse', () {
    test('`theme.dart` renk TANIMLAYABİLMELİ', () {
      // Kapı `lib/app/` içinde `theme.dart` DIŞINDA literal renk yasaklıyor.
      // Biri "hiçbir yerde literal renk olmasın" derse tek renk evi de
      // ölür ve renkler yine dağılır — kapının amacının TAM TERSİ.
      final String theme = File('lib/app/theme.dart').readAsStringSync();
      expect(RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)').hasMatch(theme), isTrue,
          reason: 'theme.dart renk tanımlamıyor — tek renk evi boşalmış.');
      expect(File('test/contrast_test.dart').readAsStringSync()
          .contains("endsWith('theme.dart')"), isTrue,
          reason: 'theme.dart muafiyeti kaldırılmış: kapı kendi renk evini '
              'de yasaklıyor.');
    });
  });

  group('`measured` kayıt defteri fazla daralırsa', () {
    test('KAYITLI bir iddia kabul EDİLMELİ — kapı ilerlemeyi engellemez', () {
      // Ters yön: kapı *"hiçbir `measured` iddiası olmasın"* diye
      // daraltılırsa ürün hiçbir zaman bir şey ölçtüğünü söyleyemez. Kapının
      // işi iddiayı YASAKLAMAK değil, YÜZEYSİZ iddiayı yasaklamak.
      final Map<String, dynamic> lib =
          (jsonDecode(File('content/library.json').readAsStringSync()) as Map)
              .cast<String, dynamic>();
      final Iterable<String> claims = (lib['movements'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .expand((Map<String, dynamic> m) =>
              (((m['honesty'] as Map)['measured'] as List<dynamic>?) ??
                      const <dynamic>[])
                  .cast<String>());
      expect(claims, isNotEmpty,
          reason: 'Hiçbir hareket bir şey ölçtüğünü söylemiyor — kapı fazla '
              'daraltılmış olabilir. Yüzeyi OLAN bir iddia yasak değildir.');
      expect(claims.every((String c) => c.trim().isNotEmpty), isTrue);
    });
  });

  group('kontrast kapısı fazla genişlerse', () {
    test('NON-TEXT tokeni metin eşiğine ZORLANMAMALI', () {
      // Biri *"her token 4.5'i geçsin"* derse `textTertiary` ya koyulaşır
      // (hiyerarşi ölür — ikon ile metin aynı ağırlığa gelir) ya da silinir
      // (ikon/kenarlık evsiz kalır). Kapı metin eşiğini METİNE uygulamalı.
      //
      // Bu ikizin normal hâli `contrast_test`te zaten var (token metin
      // eşiğini GEÇMEMELİ); buradaki, o testin KENDİSİNİN silinmesini
      // yakalıyor — yani ikizin ikizi.
      expect(
          File('test/contrast_test.dart')
              .readAsStringSync()
              .contains('textTertiary METİN eşiğini GEÇMEZ'),
          isTrue,
          reason: 'Non-text token ayrımı kaldırılmış: kontrast kapısı '
              'genişletilip hiyerarşi feda edilmiş olabilir.');
      // Ve ayrım GERÇEKTEN duruyor: iki token farklı.
      expect(GravitaColors.textTertiary == GravitaColors.textSecondary, isFalse);
    });
  });
}
