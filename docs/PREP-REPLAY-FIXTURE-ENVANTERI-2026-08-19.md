# PREP — Replay Fixture Kaynağı Envanteri (2026-08-19)

**Oturum:** GRAVITA (PREP lane) · **Soru:** kayıtlı pose stream var mı, yoksa fixture üretim planı ne?

## 1. Cevap: kısmen VAR (2/31 hareket), kapsamlı ve tekrarlanabilir bir pipeline üzerinden

Gravita'nın kendine ait bir "replay fixture üretim aracı yok" durumu DEĞİL — motion-core ailesinin paylaşımlı `harvest_rig`'i üzerinden **squat ve push_up için zaten çalışan, ölçülmüş, 6 aşamalı bir hat var.** Sorun envanterin YOKLUĞU değil, bu hattın yalnız 2/31 harekette çalıştırılmış olması.

## 2. Mevcut varlık envanteri (ölçüldü)

### 2.1 Repo İÇİNDE (git-tracked, `content/harvest/`)
19 dosya: `reference.push_up.json` · `reference.bodyweight_squat.json` (ATTESTED referanslar) · `reps.push_up.json` · `identity-triage.bodyweight_squat.json` · `hip_knee_coupling.bodyweight_squat.json` · `camera-angle.bodyweight_squat.json` · `mirror-diff-by-source.bodyweight_squat.json` · `decisions.bodyweight_squat.json` (adıyla dışlanan take kayıtları) · `triage-profile.gravita.v1/v2.json` · `anatomical-copying-signature.json` · `barbell-distortion.json` · `copying-signature.json` · `fallback-liveness.json` · `min-phase-report.json` · `park.bodyweight_squat.json` · `queue.gravita.json` · `queue.yield-pilot.json`. **Hiçbiri diğer 29 hareket için yok.**

### 2.2 Repo İÇİNDE (`packages/gravita_engine/test/fixtures/`)
Yalnız **3 dosya**: `bodyweight_squat_reps.json` (gerçek footage'tan dilimlenmiş, `bodyweight_squat_replay_test.dart`ın tükettiği) · `d1_axis_swap.json` + `d1_correct_frames.json` (D1 yönelim-kapısı sentetik/karma testleri, hareket-spesifik değil, mimari testi). **push_up için ayrı bir `*_replay_test.dart` fixture dosyası YOK** — push_up'ın replay kanıtı `packages/gravita_engine/tool/replay_gate.dart` aracı üzerinden `content/harvest/reps.push_up.json`ı tüketiyor (farklı katman, Dart-unit-test fixture'ı değil). İki hareket iki farklı replay-kanıt yolunu kullanıyor; bu ayrım gelecekte kafa karıştırabilir, isimlendiriliyor.

### 2.3 Repo DIŞINDA (`~/motion-harvest/`, git'e HİÇ girmiyor, `.gitignore` kapsamında değil çünkü zaten repo dışı)
Aile-paylaşımlı dizin (`choreia/ · gravita/ · gravita-squat/ · jablab/ · lissom/ · ostinato/` alt klasörleri — **Gravita'ya özel değil, motion-core ailesinin ortak harvest alanı**):
- `~/motion-harvest/gravita/` — push_up: `raw/` (ham video) + `landmarks/` (çıkarılmış poz) + `manifests/` (35 manifest) + `raw-orphaned/` (9 karantina dosyası, DEFTER G-093).
- `~/motion-harvest/gravita-squat/` — squat: `raw/` (63 öğe) + `landmarks/` (29 dizin) + `landmarks-rep-sliced/` (**236 dizin** — rep-FSM'in kendi fixture'larına önceden kestiği dilimler) + `manifests/` (31) + `signature-index.json`. DEFTER G-106'ya göre landmarks tek başına **674 MB**.
- **Toplam 64 manifest** (35 push_up + 29 squat) — DEFTER G-057/5575-5576 satırlarında doğrulandı.

**Sonuç:** gerçek, ölçülmüş, saatlerce sürmüş bir hasat var — ama SIFIRI diğer 29 hareket için. Bu iş "yeniden icat" değil "tekrar" gerektiriyor.

## 3. Kanıtlanmış 6 aşamalı pipeline (squat+push_up'ta ölçüldü, tekrarlanabilir)

1. **Keşif** (`content/harvest/queue.<app>.json`): YouTube kanal/video aday listesi, `rejectedForRelevance` filtresiyle (varyant/alakasız başlık elenir) — kural **M-F-32**: sayım birimi EĞİTMEN, hedef ~5 bağımsız eğitmen/teknik. Push_up: 18 eğitmen/32 video aday havuzundan hedeflendi; squat aynı ölçekte.
2. **Ham hasat** (repo dışı, `~/motion-harvest/<app>/raw/`): video indirme + manifest (kaynak/lisans/süre kaydı).
3. **Landmark çıkarma** (`tools/harvest_rig`, motion-core paylaşımlı aracı, **cv2+mediapipe GEREKTİRİR** — bu makinede kurulu DEĞİL, DEFTER'de defalarca not edilmiş: "bu makinede cv2 yok").
4. **Kimlik/uygunluk triyajı** (`identity-triage.*.json`, `decisions.*.json`): hangi take'ler referansa girebilir, hangileri adıyla dışlanır (ör. squat'ta 6 barbell take'i dışlandı — G-091).
5. **Rep-FSM dilimleme** (`landmarks-rep-sliced/`) + **kanonik referans inşası** (`reference.*.json`, ATTESTED/PROVISIONAL durumu, min 3 kaynak/3 take kapısı).
6. **Replay gate entegrasyonu** (`tool/replay_gate.dart` + `test/fixtures/*_reps.json`): gerçek footage'a karşı motor davranışı doğrulanır, `engine.precondition.status` `pending`→`derived`e yalnız bu kapıdan geçince döner.

**Kritik darboğaz — isimlendiriliyor:** Aşama 3 (landmark çıkarma) bu makinede ÇALIŞAMIYOR (cv2/mediapipe yok, DEFTER'de G-084/G-087/G-077 dahil çok sayıda kayıt). Yani PREP oturumu aşama 1'i (keşif/kuyruk hazırlığı) yapabilir, aşama 3+ mediapipe'lı bir ortam (muhtemelen ayrı bir makine/CI runner) gerektiriyor — bu WRITE-lane/harvest-lane işi bile değil, **ortam kapısı**.

## 4. Diğer 29 hareket için fixture üretim planı (taslak, orkestratör onayına)

### 4.1 Hemen yapılabilir (PREP-uyumlu, bu makinede, ortam-bağımsız)
- **Keşif kuyruğu genişletme:** `queue.gravita.json`'daki `push_up`/`bodyweight_squat` şablonunun AYNISI (searchCore + rejectedForRelevance + instructorCount/videoCount hedefleri) §5'teki öncelik sırasına göre ilk dalga hareketler için hazırlanabilir — bu tamamen metin/araştırma işi, mediapipe gerektirmez. **Bunu bu PREP oturumunda yapmadım** (görev tanımım "envanter + plan", "kuyruk üretimi" değildi) ama sıradaki READY iş olarak öneriyorum.
- **`--movement` provenance eksikliği** (DEFTER G-057, hâlâ AÇIK): rig aracı hangi fixture'ın hangi hareket için hasat edildiğini provenance'a YAZMIYOR — bugünkü geçici çözüm (ayrı dizin: `gravita-squat` vs `gravita`) 29 yeni hareketle ÖLÇEKLENMEZ (29 ayrı dizin sürdürülebilir değil). Bu, harvest ölçeklenmeden ÖNCE motion-core tarafında çözülmesi gereken bir kalıcı-düzeltme — Motion Orchestration'a/motion-core oturumuna iletilmeye değer, Gravita'nın kendi başına çözebileceği bir şey değil (paylaşımlı araç).

### 4.2 Ortam gerektiren (mediapipe'lı makine/CI — kurucu/orkestratör kapısı)
- Aşama 3-6'nın 29 hareket için tekrarı. Ölçek tahmini: push_up+squat ~64 manifest için saatler süren bir hasat turu gerekti (çok sayıda DEFTER turu) — 29 hareket × benzer ölçek, PREP'in tahmin edebileceğinden büyük bir iş; gerçek süre kestirimi ilk 2-3 hareketin ölçülmüş turundan sonra güvenilir olur, şimdiden uydurulmuyor.
- **Disk/kaynak paylaşımı uyarısı:** `~/motion-harvest/` beş Motion ürününün ORTAK alanı. Gravita'nın büyük ölçekli yeni hasadı diğer dört ürünün (choreia/jablab/lissom/ostinato) aynı anda süren işleriyle disk/CPU çakışabilir — Motion Orchestration §4 WIP tablosundaki "Prep lane: 2" sınırı muhtemelen bunun için var; harvest turu başlatmadan önce orkestratörle zamanlama koordinasyonu öneriliyor.

## 5. Öneri: hangi hareketler önce hasat edilsin

`PREP-KATALOG-SINIFLANDIRMA-2026-08-19.md` §5 ile aynı öncelik mantığı: `class:A` + `side/side45` kamera + `passiveExecutionPossible:false` kesişimi ilk dalga (pipeline'ı en az yeni değişkenle tekrarlar); `front`/`walking_frame` kamera ve `multiPhaseFsm` motoru olan 4 hareket (side_plank, lateral_raise, farmer_carry, burpee) ikinci dalga.

## 6. Kapsam dışı bırakılan
Hiçbir video indirilmedi, hiçbir harvest komutu çalıştırılmadı, `content/harvest/` veya `~/motion-harvest/` içine yazma yapılmadı — bu rapor salt-okuma envanteri + plandır.
