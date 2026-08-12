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
      multiLine: true);
  final Set<String> out = <String>{};
  for (final FileSystemEntity f in Directory('lib/app').listSync()) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    for (final RegExpMatch m in cls.allMatches(f.readAsStringSync())) {
      out.add(m.group(1)!);
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

/// **Aday olup varılamayan** — KATI'ya girmez ama **kaybolmaz** (sözleşme ②c).
/// `ContentFailureScreen`: sistem gösterir, kullanıcı **basarak gitmez**.
const Set<String> kDeliberatelyUnreachable = <String>{'ContentFailureScreen'};
