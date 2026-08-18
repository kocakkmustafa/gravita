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
| GRA-P0-003 | CI workflow + privacy manifest + release signing fail-closed | 🔶 **KISMİ** — `ios/Runner/PrivacyInfo.xcprivacy` VAR + `test/privacy_manifest_test.dart` VAR + `android/app/build.gradle.kts`ta sessiz-düşme imza kapısı VAR; `.github/workflows/` YOK, `test/release_signing_test.dart` YOK | `find .github` boş sonuç · `grep signingConfig android/app/build.gradle.kts` (2026-08-19) | G-266 (kısa tarama, derinlemesine sıradaki tur) |
| GRA-P1-001 | Skill tree domain + progress UI | 🔶 KISMİ — `content/skill-graph/` + `packages/gravita_engine/test/skill_graph_test.dart` var, `lib/app/skills/` yok | `find lib/app/skills` boş (2026-08-19) | — |
| GRA-P1-002 | 20-movement paid foundation (push/pull/squat/hinge/core/carry/hold + ≥2 skill tree) | ❌ NOT STARTED — 2/31 hareket ölçüldü, 29'u `pending_harvest`; darboğaz bu makinede mediapipe/cv2 yok | `docs/PREP-REPLAY-FIXTURE-ENVANTERI-2026-08-19.md` | G-262 |
| GRA-P1-003 | Workout program (set/rest/RPE/deload) | ❌ NOT STARTED — `lib/app/program/` yok | — | — |
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
