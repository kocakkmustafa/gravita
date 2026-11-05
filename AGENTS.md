# YULAlab — yerel Codex girişi

Önce [ortak bağlam girişini](../../../AGENTS.md), ardından [bu reponun tek yerel ürün/güvenlik kaynağını](CLAUDE.md) oku. CLAUDE.md içindeki yerel bilgiler Codex ve Claude için aynıdır; teknik yöntemi model seçer, dosya işlem yetkisi üretmez.

Bu bölümler Codex ve diğer kod ajanları içindir; kısa tutulur, ayrıntı `README.md` ve `CLAUDE.md`'dedir.

## Yığın
- Flutter 3.47.5 (CI'da sabit) / Dart ^3.9 · motor ayrı paket: `packages/gravita_engine` (Flutter bağımlılığı yok).
- Durum yönetimi: yok (Riverpod/bloc yok); `ChangeNotifier`/`ValueNotifier`.
- Ortak çekirdek: `motion_*` paketleri `pubspec.yaml`'daki pinli git ref ile `motion-core`'dan gelir.
- Kurulum: `flutter pub get --enforce-lockfile` · motor: `(cd packages/gravita_engine && dart pub get --enforce-lockfile)`
- Analiz: `flutter analyze` · Test ve kapılar: `bash tools/run_all_gates.sh` (CI `.github/workflows/checks.yml` aynı betiği koşar; içinde `flutter test --concurrency=1`, motor `dart test`, içerik kapıları var; yerelde `build/` için `tools/setup_build_dir.sh`).

## Kurallar
- **Minimal diff:** yalnız istenen dosyalara dokun; biçimlendirme/yeniden adlandırma turu yapma.
- Yerelleştirme: ARB/`gen-l10n` yok. Metinler `content/locales/<dil>.json` (14 dil, `messages` altında `g_…` kimlikleri); çoğullar `content/locales/plurals/`, geçersiz kılmalar `display-overrides/`. İngilizce kaynaktır; eksik kimlik İngilizce'ye düşer. Okuma kodu `lib/app/localization/`.
- Testler: uygulama `test/*_test.dart`; bağımsız Dart girişleri `test/pure_dart/*_regression.dart` (`dart --enable-asserts`); motor `packages/gravita_engine/test/`; cihaz `integration_test/`. Yeni davranışa test ekle; mevcut testi silme ya da atlatma.
- Bitirmeden: `flutter analyze` ve ilgili testler temiz olmalı; çıktının son 5 satırını rapora koy.
- `CLAUDE.md` ile çelişirsen `CLAUDE.md` doğrudur (D1 yönelim şartı ve gerçek-zamanlı LLM yasağı dahil).

## Dokunulmaz
- Sır dosyaları (`.env*`, anahtarlar, `~/.secrets`), imzalama yapılandırması, fiyat/abonelik kimlikleri, Supabase şema/göç işleri — yalnız açık talimatla.
- Mağaza meta verisi ve sürüm numarası — yalnız açık talimatla.
- Motion Core pini (`pubspec.yaml`'daki git ref; tüm `motion_*` pinleri ve motor pini aynı tam SHA olmalı) — yalnız açık talimatla.
- Kamera özelliği kapalı kalır: `lib/app/camera_release_policy.dart` (`motionPaidCameraLaunchEnabled`) ve çekirdekteki `motionCameraCoachingAvailable` açılmaz.
- Burun Farkı ve Iron Bank.
