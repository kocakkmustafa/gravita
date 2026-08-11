# Gravita

**Handstand & vücut becerileri koçu.**

Telefon kamerasıyla denemeni cihaz-üstü analiz eder, en önemli hatayı söyler, antrenörün yanındaymış gibi sesli yönlendirir, ölçülebilir progresyonla ilerletir.

Ortak ilke: on-device pose analizi + deterministik kural motoru — gerçek-zamanlı LLM yok, ham video cihazdan çıkmaz, düşük güvende hüküm yok, her karar açıklanabilir.

- 📋 Ürün planı: [`docs/gravita-plan.md`](docs/gravita-plan.md)
- 📐 Aile sözleşmesi (bağlayıcı): [motion-core → docs/00-AILE-MIMARISI.md](https://github.com/kocakkmustafa/motion-core/blob/main/docs/00-AILE-MIMARISI.md)
- 🧩 Ortak çekirdek: [motion-core](https://github.com/kocakkmustafa/motion-core) (pinli sürüm)

> ⚠️ Hazırlık aşaması — üretim kodu, kurucu "Gravita'a başlayalım" dediğinde V0 kapısıyla açılır.

## Kurulum (taze klon — üç TEK SEFERLİK adım)

```bash
flutter pub get
tool/fetch_pose_model.sh   # pinli MediaPipe modeli (9,4 MB, gitignored, SHA doğrulanır)
tools/setup_hooks.sh       # commit kapısını git'e bağlar (core.hooksPath)
```

Kurulumdan sonra düz `git commit` bile `tools/run_all_gates.sh`'ten otomatik geçer — `tools/gated_commit.sh`'i hatırlamak GEREKMEZ (bkz. `tools/hooks/pre-commit`). İlk iki adım atlanırsa `flutter test` ve `git commit` başarısız olur; bu KASITLI (G-122/koordinatör aktarımı, 2026-08-11) — kurulmamış bir kapı sessizce geçmemeli.

_Bu repo YULA AI Holding portföyünün parçasıdır._
