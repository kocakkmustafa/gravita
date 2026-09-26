/// ⚖️ GEZİLEBİLİRLİK SÖZLEŞMESİ — **TEK EV** (aile hükmü, 2026-08-12).
///
/// Ölçüm **ikiye bölündü** ((c) hükmü) çünkü soğuk açılıştan yürümek,
/// boyamadan **sonra** bir gerçek-zaman turu açmayı zorunlu kılıyor ve o tur
/// ölçülmüş `google_fonts` tuzağını tetikliyor. Bölmenin **kabul edilmiş**
/// bedeli: okuma yeri dağılıyor.
///
/// ⛔ **İKİ KISIT, ikisi de aile ölçümünden:**
/// **① Denklem İKİ KAPI ARASINDA kurulur, her kapının içinde değil:**
/// `aday = (kabuk yürüyüşü) ⊎ (soğuk açılış yürüyüşü) ⊎ varılamayan`.
/// Aksi hâlde her kapı kendi içinde tutar ve **ikisi birden eksik olabilir**.
/// **② Kanonik sayı TEK yerde:** `reachability_test.dart`. Bu dosya sayı
/// tutmaz; **envanteri** ve **bölmenin beklenen payını** tutar.
library;

import 'dart:io';
import 'package:gravita/app/camera_release_policy.dart';

/// Aday envanteri — **DESENDEN türetilir** (sözleşme ②a). Desen `koddan`
/// okur; elle liste `hafızadan`.
///
/// 🔴 **DÜZELTME (G-198):** bu satır önce *"elle liste YOK"* diyordu ve
/// sözleşmenin **(e) maddesini ihlal ediyordu**. (e) elle kümenin
/// SİLİNMESİNİ değil **RÜTBESİNİN DÜŞÜRÜLMESİNİ** ister: kaynak olmaktan
/// çıkar, **türetimin POZİTİF KONTROLÜ** olarak kalır. Taban artık
/// [kKnownFloor]'da; silinmedi, gerekçesiyle düzeltildi.
///
/// 🔴 `Flow` ölçümle eklendi: eski desen `OnboardingFlow`u **hiç aday
/// yapmıyordu**, oysa gerçek bir kullanıcı hedefi (kendi kapısı var).
/// ⚠️ `View` EKLENMEDİ — `ProgressView` bir hedef değil, `ProgressTab`
/// içinde çizilen görünüm; deseni gevşetmek envanteri şişirirdi.
Set<String> declaredScreens() {
  final RegExp cls = RegExp(
    r'^class\s+(\w+(?:Screen|Page|Tab|Flow))\s+extends\s+(?:Stateless|Stateful)Widget',
    multiLine: true,
  );
  final Set<String> out = <String>{};
  for (final File f in _appSources()) {
    for (final RegExpMatch m in cls.allMatches(f.readAsStringSync())) {
      out.add(m.group(1)!);
    }
  }
  return out;
}

/// Kaynak dosya kümesi — **ÖZYİNELEMELİ** (G-198).
///
/// ⚠️ Eskiden `listSync()` özyinelemesizdi. Ölçüldü (2026-08-13): bugün
/// `lib/` altında **yalnız `lib/app`** var, alt klasör **yok** ⇒ bu değişiklik
/// bugünün sayısını **değiştirmiyor**. Ama `lib/app/` altına bir klasör açıldığı
/// gün envanter **sessizce** eksilirdi ve hiçbir kapı ötmezdi.
/// > *Bugün etkisiz bir nöbetçi, yarın sessiz bir kayıptan ucuzdur.*
Iterable<File> _appSources() => Directory('lib/app')
    .listSync(recursive: true)
    .whereType<File>()
    .where((File f) => f.path.endsWith('.dart'));

/// **KANAL-2 — YAPI: MONTAJ NOKTASI** (sözleşme (a): *iki bağımsız türetimin
/// uzlaşması*).
///
/// ⛔ **Ostinato'nun `Scaffold(` kanalı BU AĞACA GEÇMİYOR — kopyalanmadı,
/// ÖLÇÜLDÜ** (G-198). O kanal burada **15** sınıf buluyor; altısı hedef değil:
/// `GravitaShell` · `GravitaRoot` (kabuk/kök kapsayıcı) ve `_CameraStep` ·
/// `_SafetyStep` · `_ValueStep` · `_StepScaffold` (onboarding'in **özel**
/// adımları — `ProgressView` gibi, hedef değil içeride çizilen görünüm).
/// Kopyalansaydı kapı **doğar doğmaz** altı hayaletle kırmızı olurdu.
/// > *Sözleşme kanalın ADINI değil, ağaçta ÖLÇÜLMESİNİ ister — Choreia'nın
/// > ödediği bedel (M-F-580 sınıfı) bu hatta da geçerli çıktı.*
///
/// Bu ağacın çalışan kanalı **montaj noktası**: bir sınıf ya kabuğun
/// `IndexedStack`ine sekme gövdesi olarak monte edilir ya da bir
/// `MaterialPageRoute(builder:)` içinde itilir. İkisi de **kullanıcı hedefi**
/// anlamını taşır; `Scaffold` ise yalnız *"tam ekran çiziyorum"* der.
Set<String> mountedScreens() {
  final RegExp pushed = RegExp(r'builder:\s*\(_\)\s*=>\s*([A-Z]\w*)\s*\(');
  final RegExp shellBlock = RegExp(
    r'IndexedStack\([\s\S]*?children:\s*<Widget>\[([\s\S]*?)\n\s*\],',
  );
  final RegExp child = RegExp(r'^\s+([A-Z]\w*)\s*\(', multiLine: true);

  final Set<String> out = <String>{};
  for (final File f in _appSources()) {
    final String src = f.readAsStringSync();
    for (final RegExpMatch m in pushed.allMatches(src)) {
      out.add(m.group(1)!);
    }
    for (final RegExpMatch b in shellBlock.allMatches(src)) {
      for (final RegExpMatch c in child.allMatches(b.group(1)!)) {
        out.add(c.group(1)!);
      }
    }
  }
  return out;
}

/// **(e) ELLE KÜME — kaynak DEĞİL, türetimin POZİTİF KONTROLÜ.**
///
/// ⚠️ **ŞERH 1: bu küme bir ALT SINIRDIR, tam envanter DEĞİLDİR.**
/// ⚠️ **ŞERH 2: buraya ekleme yapmak envanter güncellemesi DEĞİL,
///    KONTROLÜN TABANINI yükseltmektir.**
///
/// **Gerekçe (JabLab M-F-575, aile bedeli):** türetim ilk hâlinde `_XState`
/// elemesiyle **her StatefulWidget ekranını** yok etmişti — ve *yakalayan şey
/// elle kümeydi.* Bu ağaçta o kusurun bedeli ölçüldü: aşağıdaki dokuz adın
/// **beşi** `StatefulWidget` (`LibraryScreen` · `ProgressTab` ·
/// `LiveSessionScreen` · `MovementPage` · `OnboardingFlow`) ⇒ aynı kusur
/// envanterin **yarısından fazlasını** sessizce düşürürdü.
///
/// **PROVENANS — desenden DEĞİL, iki bağımsız YAPISAL kanaldan okundu**
/// (2026-08-13, elle çevrildi ve **donduruldu**):
/// * sekme gövdeleri = `GravitaShell`in `IndexedStack.children`i
///   (`gravita_app.dart:181-189`) → 4
/// * rota hedefleri = `MaterialPageRoute(builder:)` çağrı yerleri
///   (`gravita_app.dart:216` · `profile_screen.dart:59` ·
///   `library_screen.dart:53,61` · `home_screen.dart:66`) → 3 ayrı sınıf
/// * envanter üyesi ama kullanıcı hedefi değil → 2
///
/// ⛔ **Tautoloji YASAK ve bu bilinerek kuruldu:** taban `declaredScreens()`
/// KOŞULARAK üretilmedi. Üretilseydi iki taraf aynı kaynağı okurdu ve kontrol
/// **hiçbir koşulda ötemezdi** — bu ağacın `G-999` sentinel tautolojisinde
/// (G-196) ödediği bedelin tam olarak aynısı.
/// > *Bir denetim iki tarafı aynı kaynaktan okuyorsa denetim değil TANIMDIR.*
///
/// 📌 **Kapsamı dürüstçe daraltan ölçüm:** dokuzun **ikisi**
/// (`OnboardingFlow` · `ContentFailureScreen`) (d)'nin denklemi tarafından
/// **zaten** pozitif kontrol ediliyor (`hesap == candidates`, bkz.
/// `reachability_test.dart:264-270`). ⇒ Bu tabanın **YENİ** kapsamı 9 değil
/// **7**. Yine de dokuzu birden duruyor: (d) bir gün gevşerse taban ayakta
/// kalır. *Bir kontrolün değeri, kapsamı abartılmadan yazıldığında ölçülür.*
const Set<String> kKnownFloor = <String>{
  // sekme gövdeleri (kabuk monte eder)
  'HomeScreen', 'LibraryScreen', 'ProgressTab', 'ProfileScreen',
  // rota hedefleri (kullanıcı basarak iter)
  'LiveSessionScreen', 'MovementPage', 'WhyNotHereScreen',
  // envanter üyesi, kullanıcı hedefi değil
  'OnboardingFlow', 'ContentFailureScreen',
};

/// **KAPI-2'nin payı** — soğuk açılışta yürünen yüzeyler.
///
/// Bu bir beyan değil bir **ölçüm sonucudur**: `onboarding_reach_test.dart`
/// soğuk açılıştan yürüyerek bunu **kanıtlar**; kanıtlayamazsa o kapı düşer.
/// Kapı-1 ise bu kümeyi **denklemde** kullanır — böylece hiçbir yüzey iki
/// kapının arasından düşmez.
const Set<String> kColdStartSurfaces = <String>{'OnboardingFlow'};

/// **KÖK VARIŞ — beyanlı, ÇAPALI** (sözleşme (b), G-200).
///
/// KATI sayısındaki `+1` eskiden **çıplak bir sabitti** (`routes.length + 1`):
/// kabuk bir rotadır ama hiçbir şey onun *"kök olarak varıldığını"* ölçmüyordu.
/// Artık kök varış **`NavigatorObserver` olayından** geliyor (`previous == null`
/// olan `didPush`) ve bu kümeye **çapalanıyor**.
///
/// > ***Ostinato'nun hükmü (M-F-582): ÜÇÜNCÜ bir kök varış BEYAN değil
/// > BULGUDUR*** — beyansız kök varış kırmızıdır, sessizce sayıya eklenmez.
///
/// ⚠️ `GravitaShell` **aday envanterinde DEĞİL** (ad deseni `Shell` taşımaz) ve
/// bu bilerek böyle: kabuk bir *hedef* değil, dört sekmeyi taşıyan **kap**.
/// Envantere alınsaydı GEVŞEK sayısı hatlar arası karşılaştırmayı bozacak
/// şekilde şişerdi. Kap olması onu **rota olmaktan** çıkarmıyor — bu yüzden
/// KATI'da sayılır, GEVŞEK'te sayılmaz.
const Set<String> kRootArrivals = <String>{'GravitaShell'};

/// **Aday olup varılamayan** — KATI'ya girmez ama **kaybolmaz** (sözleşme ②c).
/// `ContentFailureScreen`: sistem gösterir, kullanıcı **basarak gitmez**.
///
/// ⚠️ Bu satır **sebebi TAŞIMAZ, İDDİA EDER** — sebep [derivedExclusionReasons]
/// tarafından her koşumda **kaynaktan türetilir** (G-200).
const Set<String> kDeliberatelyUnreachable = <String>{
  'ContentFailureScreen',
  if (!motionPaidCameraLaunchEnabled) 'LiveSessionScreen',
};

/// **(c) DIŞLAMA SEBEBİ — düzyazı değil, HER KOŞUMDA KAYNAKTAN türetilir.**
///
/// Sözleşme (c) iki şeyi birden yasaklıyor: **sebepsiz dışlama** ve — daha
/// beteri — **yanlış sebep**. Ostinato *"üçü de kamera arkasında"* demişti,
/// ölçüm bir ekranda **kamera izi olmadığını** gösterdi (M-F-586).
/// > ***YANLIŞ BİR SEBEP, SEBEPSİZLİKTEN DAHA KÖTÜDÜR: DENETİMİ DOĞRULANMIŞ
/// > GÖSTERİR.***
///
/// Türetim iki soruyu **koddan** sorar ve üç sonuçtan birini döner:
/// * sınıf bir **montaj noktasında** görünüyor mu ([mountedScreens]) →
///   görünüyorsa dışlama sebebi **çürümüştür** (kullanıcı basarak varabiliyor)
/// * hiç **inşa** ediliyor mu → edilmiyorsa bu bir dışlama kalemi değil
///   **ölü kod** kalemidir (ayrı kusur, ayrı kova)
/// * ikisi de değilse sebep ayakta: **yalnız sistem dalından** inşa ediliyor,
///   ve inşa yerleri **dosya:satır** olarak raporlanır.
Map<String, String> derivedExclusionReasons() {
  final Set<String> mounts = mountedScreens();
  final Map<String, String> out = <String, String>{};

  for (final String cls in kDeliberatelyUnreachable) {
    if (cls == 'LiveSessionScreen' && !motionPaidCameraLaunchEnabled) {
      final launch = File('lib/app/gravita_app.dart').readAsStringSync();
      if (launch.contains('if (!motionPaidCameraLaunchEnabled) return;')) {
        out[cls] =
            'shared first-release policy closes camera launch before route construction';
        continue;
      }
    }
    final RegExp decl = RegExp('^class\\s+$cls\\b', multiLine: true);
    final List<String> sites = <String>[];

    for (final File f in _appSources()) {
      final String src = f.readAsStringSync();
      // Sınıfı BİLDİREN dosya atlanır — kendi yapıcısı inşa yeri değildir.
      if (decl.hasMatch(src)) continue;
      final List<String> lines = src.split('\n');
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('$cls(')) {
          sites.add('${f.uri.pathSegments.last}:${i + 1}');
        }
      }
    }

    if (mounts.contains(cls)) {
      out[cls] =
          '⛔ SEBEP ÇÜRÜDÜ: montaj noktasında görünüyor — kullanıcı '
          'basarak varabiliyor, bu bir dışlama kalemi DEĞİL';
    } else if (sites.isEmpty) {
      out[cls] =
          '⛔ SEBEP ÇÜRÜDÜ: hiçbir yerde inşa edilmiyor — bu dışlama '
          'değil ÖLÜ KOD kalemi (ayrı kova, ayrı karar)';
    } else {
      out[cls] = 'yalnız sistem dalından inşa ediliyor (${sites.join(' · ')})';
    }
  }
  return out;
}
