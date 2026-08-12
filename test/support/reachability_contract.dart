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

/// Aday envanteri — **DESENDEN türetilir, elle liste YOK** (sözleşme ②a).
/// Desen `koddan` okur; elle liste `hafızadan`.
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
