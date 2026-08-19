# Gravita — Evidence Ledger

Bu dosya `holding/plans/SOLO-KICKOFF-PROMPTLARI-2026-08-19.md` §1.1'in hükmüdür: roadmap
(`holding/plans/yula-ai-production-line-2026-08-18/22-GRAVITA-MASTER-ROADMAP.md`) görev/kanıt
kimlikleri ile gerçek doğrulama durumu arasındaki köprü. **İNDEKSTİR, tekrar değil** — kanıtın
tam metni `workspace/DEFTER.md`'nin ilgili `G-NNN` girdisindedir; bu tablo yalnız hangi görevin
hangi girdide doğrulandığını gösterir. Roadmap'teki baseline/durum satırları İDDİADIR, bu
tablodaki her satır ölçümle (gate koşumu, dosya okuma, `git` doğrulaması) desteklenir.

## Görev paketleri (roadmap §11)

| ID | İddia | Durum | Kanıt | DEFTER |
|---|---|---|---|---|
| GRA-P0-001 | Catalog/class truth: 31 hareketten yalnız squat+push_up `status:"live"`; 29'u dürüst `coming_soon` (class+honesty measured/notMeasured/waitingOnMeasurement/scoring ayrımı+comingSoonInThisMovement copy); movement card class/metric gösteriyor; store listing aynı manifestten (`content/library.json`) türer ve mekanik kapıyla sınanır | ✅ **VERIFIED** (önceki oturumlarda inşa edilmiş; bu oturumda tam gate koşumuyla doğrulandı, roadmap'in "henüz yapılmadı" varsayımı YANLIŞTI) | `tools/run_all_gates.sh`: app 222/222 · engine 175/175 · python 20/20 (üçü de yeşil, iki bağımsız tam koşum) | G-261, G-262(kısmen), G-265 |
| GRA-P0-002 | Squat/push-up real-device model gate: count/false-rep/phase/orientation/low-confidence fixtures + 42/42 orientation regresyonu + 20-kişi/200-rep holdout + fiziksel cihaz matrisi + eşik-altı hareket isimli fail gate üretir | ✅ **VERIFIED (kod tarafı)** + ⛔ **EXTERNAL_GATE (veri+cihaz)** — fixture/test kapsamı CANLI koşulup doğrulandı, 20-kişi eşiği hiçbir hareketle karşılanmıyor (en yüksek 15/9 nitelikli, push_up rep-identity), cihaz "Devices Offline" | `docs/evidence/production-line/model-gate.json` (ölçüm+eşik+engel adıyla) — `structural_false_reject_test.dart` canlı koşum: 66 kare (inv=42/upr=24), yanlış-red 4/66 (%6, eşik <%10) | G-266 |
| GRA-P0-003 | CI workflow + privacy manifest + release signing fail-closed | ✅ **KOD TARAFI VERIFIED** + 🔶 **CI Actions koşumu EVIDENCE_REQUIRED** (secret eklenince gözlemlenecek) — `.github/workflows/checks.yml` YAZILDI (3 job); `tools/validate_release_signing.py`+`test/release_signing_test.dart` YENİ (Gravita'nın gerçek 2-parçalı gradle yapısına göre, Lissom'dan kopyalanmadı); iki GERÇEK release build (checksum'li) başarılı; privacy manifest paketlemesi built `.app` içinde doğrulandı | `docs/evidence/production-line/release-gate.json` — `run_all_gates.sh`: app 224/224·engine 175/175·python 22/22; android `.aab` 76.4MB SHA `b89f175d…`; iOS `Runner.app` 46.2MB | G-267 |
| GRA-P1-001 | Skill tree domain + progress UI | ✅ **VERIFIED — TAMAMLANDI** — domain katmanı (`skill_progress.dart`, `SkillProgressEvaluator`) + gezilebilir UI (`SkillTreeScreen` tek-ağaç, `SkillTreesListScreen` hub, Home'dan gerçek dokunuşla erişilebilir). Zengin domain (`SkillNode` drills/cues/prereq) BİLEREK ekrana bağlanmadı — `content/skill-graph/*.json` `pubspec.yaml`de paketlenmiyor, `M-F-38` uzman-onayına EXTERNAL_GATE'li; UI yalnız zaten-paketli `SkillTree` özetini kullanır | `test/skill_progress_test.dart` 17/17 · `skill_graph_test.dart` yetim-düğüm testi (5/5) · `skill_tree_screen_test.dart`+`skill_trees_list_screen_test.dart` 12/12 · `reachability_test.dart` YEŞİL (yeni ekranlar gerçek dokunuş yürüyüşüyle doğrulandı) | G-268, G-269 |
| GRA-P1-002 | 20-movement paid foundation (push/pull/squat/hinge/core/carry/hold + ≥2 skill tree) | ✅ **KOD/ŞEMA TARAFI VERIFIED** — desen kapsamı 7/7 zaten dolu (ölçüldü), ≥2 skill tree zaten karşılanıyor; kabul kapısı (`test/paid_foundation_inventory_test.dart`) yazılı, öz-güncellenen skip ile · ⛔ **EXTERNAL_GATE (≥20 aktif eşiği)** — bugün 2/20, darboğaz bu makinede mediapipe/cv2 yok (4. kez ölçüldü: G-084/G-087/G-262/G-266) | `test/paid_foundation_inventory_test.dart`: 8/8 desen+skill-tree testi yeşil, 1 skip (dinamik EXTERNAL_GATE mesajı) | G-270 |
| GRA-P1-003 | Workout program (set/rest/RPE/deload) | 🔶 **DOMAIN KATMANI VERIFIED, ekran+kablolama NOT STARTED** — `lib/app/program/program_model.dart`+`program_builder.dart` yeni: deterministik 8-hafta üretici (katalog level/equipment süzgeci, canlı-öncelik, deload periyotlama, cezasız yeniden-sıralama). `lib/app/workout/workout_screen.dart` (Step 3/4 UI) + `content_repository.dart` kablolaması HENÜZ yok | `test/program_builder_test.dart` 16/16 — hem sentetik hem GERÇEK `content/library.json`+katalogla (24/40 seans, çökmeden) | G-271 |
| GRA-P1-004 | Feedback/storage/data rights (Drift DB, export/delete) | ❌ NOT STARTED — `lib/app/storage/` yok | — | — |
| GRA-P1-005 | IAP/store/beta/revenue | ❌ NOT STARTED — `lib/app/paywall/`, `lib/app/entitlements/` yok | — | — |
| GRA-P2-001 | W3/W4/W5, ≥120 hareket | ❌ NOT STARTED | — | — |

## Roadmap evidence tablosu (§16) — durum güncellemesi

| ID | İddia | Artefakt | State (roadmap'te) | Gerçek durum (bu oturum) |
|---|---|---|---|---|
| GRA-E-001 | Catalog/class baseline doğru | `baseline.json` (ayrı dosya yok; eşdeğeri `content/library.json`+`validate_catalog.py`+`validate_library.py`) | EVIDENCE_REQUIRED | ✅ VERIFIED — bkz. GRA-P0-001 satırı |
| GRA-E-002 | Squat/push-up model gate | `model-gate.json` (**artık VAR** — `docs/evidence/production-line/model-gate.json`) | EXTERNAL_GATE | ⛔ EXTERNAL_GATE (kod/fixture ✅ hazır; 20 kişi/200 rep + fiziksel cihaz gerçek dünya verisi gerekir) |
| GRA-E-003 | Device/orientation/thermal geçti | `device-matrix.json` (yok; en yakın karşılığı `docs/device-day/PAKET.md`) | EXTERNAL_GATE | ⛔ EXTERNAL_GATE — cihaz "Devices Offline" (G-259/DEFTER), kurucu tetiklemesi bekliyor |
| GRA-E-004 | 20-movement paid foundation | `paid-foundation.json` (yok) | EVIDENCE_REQUIRED | ❌ NOT STARTED (2/31 ölçülü) |
| GRA-E-005 | Skill tree/program/DB tamam | `platform-gate.json` (yok) | EVIDENCE_REQUIRED | 🔶 KISMİ (yalnız skill graph domain) |
| GRA-E-006 | IAP lifecycle geçti | `iap-gate.json` (yok) | EXTERNAL_GATE | ❌ NOT STARTED |
| GRA-E-007 | Store/beta/revenue geçti | `store-gate.json`, `beta-gate.json`, `revenue-gate.json` (yok) | EXTERNAL_GATE | ⛔ EXTERNAL_GATE |
| GRA-E-008 | 120–180 full vision tamam | `full-vision-inventory.json` (yok) | EVIDENCE_REQUIRED | ❌ NOT STARTED |

## Bilinen tanım sapması (karar gerektirmez, isimlendirilir)

Roadmap §4'ün A/B/C/D sınıf tanımı (doğrulama-durumu sınıfın İÇİNDE) ile repo şemasının
(`content/schema/movement-classes.json`, kurucu-onaylı, canlı uygulanan — yalnız KAMERA
GEOMETRİSİ) tanımı farklı eksenler ölçüyor. Sayısal sapma değil, tanımsal. Detay:
`docs/PREP-KATALOG-SINIFLANDIRMA-2026-08-19.md` §0, DEFTER `G-260`/`G-261`. Bu ledger repo
şemasını esas alır (canlı, uygulanan).

## Güncelleme kuralı

Yeni bir görev/kanıt doğrulandığında ya da durumu değiştiğinde: bu tablodaki satırı güncelle +
DEFTER'e ayrıntılı `G-NNN` girdisi yaz + ikisini çapraz-referansla. Roadmap dosyasının kendisi
DEĞİŞTİRİLMEZ (kanonik plan, `holding/`'de).
