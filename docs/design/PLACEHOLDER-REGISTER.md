# PLACEHOLDER-REGISTER — Gravita

> Format (koordinatör brief'i, M-F-282): `// PLACEHOLDER(<kategori>): <eksik> —
> unblocked by: <ne bekliyor>` (`asset`·`copy`·`data`·`flow`), koddan
> üretilecek bir kapı: `unblocked by` yoksa FAIL.

## Bu turda (2026-08-06 giydirme): SIFIR placeholder

`lib/app/theme.dart`, `progress_view.dart`, `live_session_screen.dart`,
`content_failure_screen.dart` — dördü de **var olan, gerçek içerikli**
ekranları giydirdi (`ProgressSummary`/`LessonProgress`/`LiveState`/
`ContentFailure`, hepsi gerçek `library.json` + motor verisi). Hiçbiri eksik
bir asset/kopya/veri yerine geçici bir dolgu koymadı — bu yüzden koda
`// PLACEHOLDER(...)` yorumu EKLENMEDİ. `grep -r "PLACEHOLDER(" lib/` boş
döner; bu doğru ve beklenen sonuç, atlanmış bir adım değil.

**Not — `LiveSessionScreen`'in koyu kamera-alanı bir placeholder DEĞİL:**
`motion_camera`'nın kendi sözleşmesi ("Dart tarafı asla görüntü görmez")
kamera önizlemesini MİMARİ olarak imkânsız kılıyor — bu "henüz eklenmedi,
sonra eklenecek" değil, "hiçbir zaman eklenemez" durumu. Placeholder kaydı
*"unblocked by"* varsayar; burada açacak bir kilit yok, o yüzden kayda
girmiyor. Bkz. `DESIGN-AHEAD-OF-CODE.md` §2.4.

## İleriye dönük — 8 eksik yüzey inşa edilirse beklenen placeholder'lar

Bunlar KOD DEĞİL, bir sonraki turun ne bulacağının tahmini envanteri:

| Kategori | Eksik | unblocked by (tahmin) |
|---|---|---|
| `asset` | Movement page referans görüntü/klip (30/31 hareket) | hasat + provenance ATTESTED |
| `asset` | Figür illüstrasyonu (DESIGN-PANEL-PROMPT §1, "denge/hiza temalı") + AI-ifşa rozeti | kurucu görsel yönü onayı |
| `data` | 30 hareketin `honesty.measured` boş, `notMeasured` içeriği var ama Movement page'i besleyecek tam saha (`comingSoonInThisMovement` vb.) yalnız 2 hareket için dolu | içerik ekibi / hasat turu |
| `data` | Skill tree — 5 ağaçtan yalnız Handstand'ın veri şekli biliniyor (Planche/Lever/Pistol/L-sit `content/skill-graph/*.json`'da tanımlı mı, doğrulanmadı) | ölçüm |
| `flow` | Onboarding/Kalibrasyon/İlk-değerlendirme — design panelinde de yok (bkz. DESIGN-AHEAD-OF-CODE §1.3) | yeni design-panel turu |
| `flow` | Attempt summary ekranı — hangi veri modelinden besleneceği (motor `LiveSessionRunner` çıktısı 7 bileşeni zaten taşıyor mu?) ölçülmedi | ölçüm |

Bu tablo bir SÖZ değil — bir sonraki oturumun İLK işi (bu round'un kendi
başlangıcındaki IA-delta ölçümü gibi) bunu doğrulayıp güncellemeli.
