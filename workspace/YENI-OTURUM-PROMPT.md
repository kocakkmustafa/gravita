# ⏸️ BEKLEME MODU — DESIGN LİNKİ BEKLENİYOR (devir: 2026-08-05, koordinatör yazdı)

> **Bu blok en güncel talimattır ve altındaki her şeyden ÖNCELİKLİDİR.**
> Aşağıdaki eski bölüm (önceki oturumun devir promptu) teknik durum/sınırlar için
> GEÇERLİ — ama "kendi tasarımını sen yap" varsayımı **SÜPERSEDE** edildi (M-F-279).

## 🎨 Yeni model (kurucu kararı 2026-08-05)
Tasarımlar **TEK design-orkestrasyonu oturumunda** üretilir (Remotion + Claude design
paneli), sonra sana **tasarım linki + giydirme brief'i** olarak gelir. Her uygulama
KENDİ dilinde, birbirinden TAMAMEN FARKLI tasarlanacak.

**BU OTURUMDA YAPMAYACAKLARIN:**
- ❌ Tasarım kararı üretme (renk/tipografi/düzen/akış dili) — yön koordinatörden gelir.
- ❌ Kendi başına design turu başlatma, UI yeniden yazma, "cila" turu koşma.
- ❌ Kurucuya doğrudan tasarım sorusu sorma (M-F-77; koordinatörden geçer).

**BU OTURUMDA YAPACAKLARIN:**
1. Aşağıdaki okuma listesini bitir (bağlam kopukluğu olmasın).
2. Ağacı doğrula: `git -C ventures/gravita/app status` + `git -C ventures/gravita/app log -1` (**beyana değil ağaca güven**).
3. Kısa bir "hazırım" özeti yaz: okuduklarını + doğrulanan tepe commit'i + varsa
   ağaçta beklenmedik bir şey. **Sonra BEKLE.**
4. Giydirme brief'i gelince: tasarımı KENDİ yüzeyine uygula, dürüstlük sınırlarını
   ESNETMEDEN (aşağıda), kapılarını koştur, commit+push (kalıcı yetkin var).

## 📖 Okuma listesi (sırayla — bağlam bunlarda)
1. **Vault:** `knowledge/Yula Lab/20 Şirketler/Motion/🔄 Oturum Devri 2026-08-05 — Gravita Kamera Entegrasyonu.md` — senin son turunun kaydı.
2. **Vault:** `📊 Durum Panosu — Motion.md` → **08-05 "GÜNCEL DURUM BU BLOK"** (altı tarihsel).
3. **Vault:** `🔄 Oturum Devri 2026-08-05 — Orkestratör Kamera Dalgası Kapanışı → Design Orkestrasyonu Devri.md` — §4 yeni model + §5 kalan işler.
4. `ventures/gravita/workspace/DEFTER.md` + `PROGRESS.md` — **son bölüm** (kendi hükümlerin).
5. `ventures/motion-core/workspace/DEFTER.md` — **M-F-260 → M-F-279** (aile kuralları, bağlayıcı).
6. Bu dosyanın altındaki eski bölüm — teknik durum, ölçülmüş tuzaklar, bağlayıcı sınırlar.

## 📍 Senin durumun (2026-08-05, git-doğrulandı)
**Kamera entegrasyonu TAM** — main `79b95ec`, push 0/0, ağaç temiz, merge bekleyen dal yok. Çok-modluluk kanıtlı; motion_core 0.11.0 sealed-adopsiyon tamam. Kod tarafında bekleyen borç YOK.

**İlk işin:** okuma listesi + ağaç doğrulaması + 'hazırım' özeti, sonra BEKLE (tasarım linki gelecek).

## 🚧 Tasarımda da ESNEMEYEN sınırlar (giydirme sırasında geçerli)
- **K8:** kalibre edilmemiş sayısal skor YOK ("bant, nokta değil").
- **M-F-186:** vaat dili (`comingSoon`/"yakında") YASAK · engelli özellik İSİMLİ
  gerekçeyle görünür · `measurementOnly` beyanı **yüzeyin TEPESİNDE** (konum içeriğin parçası).
- **Dürüst hâller birinci sınıf ekrandır** (izin · kamera-yok · kimse-yok · kadraj-dışı) —
  tasarım bunları "artık" gibi ele alamaz; hâl-başına ayrı render yolu korunur.
- **Türetimli listeler elle yazılmaz** · ham `detail`/hata kodu yüzeye sızmaz.
- **Ekran kanıtı KAPIDIR:** "testler metnin VARLIĞINI sınar, DOĞRULUĞUNU sınamaz"
  (95 yeşil test yanlış-anatomi metnini görmedi — Lissom P0 dersi).
- Yeni ölçü/kapı/eşik tasarımı veya dürüstlük-metriği hükmü → **koordinatöre**.

## ⚙️ Kalıcı kurallar
- commit + push + merge **KALICI YETKİLİ**; `ventures/motion-core/lib` paylaşımlı ağacında
  **dal değiştirmek YASAK** (M-F-22).
- **iCloud-altı repoda `git add -A` yerine DOSYA-İSİMLİ add** (0-bayt `index.lock` riski, M-F-273);
  başkasının untracked dosyasına dokunma (M-016; `* 2.plist`-sınıfı iCloud artıkları dahil).
- **Bağlam sıkışırsa İSİMLİ DURDUR** — sessiz kalite düşüşü yerine isimli duruş (aile standardı).
- **Cihaz-kanıtı vaat edilmez:** iOS sim'de kamera YOK; gerçek-kamera canlılığı cihaz gününe
  ertelendi (kurucu, tek oturum). Hiçbir yüzey "cihazda kanıtlı" demez.

---
---

# YENİ OTURUM PROMPTU — Gravita (2026-08-05 mührü)

> **Kurucu:** aşağıdaki bloğu yeni Gravita oturumuna **AYNEN yapıştır.**
> Bu dosya devir kaynağının TEK adresidir; başka not taramaya gerek yok.

---

Gravita oturumuna başlıyoruz. Sen Yula Motion ailesinin **Gravita** (kuvvet &
beceri antrenmanı) hattını sürdüren oturumsun. Önceki vardiya 2026-08-05'te
mühürlendi. **Hiçbir şeyi baştan keşfetme — buradaki sayılar ölçülmüştür.**

## 0. İLK İŞ (sırayla, 5 dakika)

1. `cd ~/Documents/YULAlab-AI/ventures/gravita/app && git log --oneline -3`
   → beklenen tepe: **`79b95ec`** (G-121 merge). Farklıysa DUR ve söyle.
2. `git status` → **temiz**. Açık dal YOK, bekleyen merge YOK.
3. **Model dosyası git'te DEĞİL** — ilk iş:
   `./tool/fetch_pose_model.sh` (aile hattından kopyalar, SHA doğrular).
   Bu koşulmadan `flutter build` asset'i bulamaz.
4. Kapıları KOŞTUR (varsayma):
   ```
   cd packages/gravita_engine && dart analyze && dart test    # 128/128
   cd ../.. && flutter analyze && flutter test                # 61/61
   python3 tools/validate_library.py && python3 tools/validate_library.py --self-test
   python3 tools/validate_catalog.py
   cd packages/gravita_engine && dart run tool/replay_gate.dart  # 8 / 0 ÖLÜ
   ```
5. `workspace/DEFTER.md` sonundaki **VARDİYA MÜHRÜ**'nü oku (bir sayfa).

## 1. Ürün nerede

**Gravita bir UYGULAMA ve artık KAMERA BAĞLI.** push_up canlı yolu kod
olarak tam: kamera → poz → rep-FSM → dürüst yüzey. İki platformda derlendi.

| ne | durum |
|---|---|
| **push_up** | `live` · referans ATTESTED · rep + tempo + `partial_rom` CANLI |
| **canlı yol** | ✅ **BAĞLI** (G-120) — `LiveSessionRunner`, kamerasız test edilebilir |
| **push_up form dersi** | 🔒 KİLİTLİ — 9 eklem toleransının hiçbiri varyans-türetimli değil. **Kamera bunu AÇMADI ve açmaz**: kilit ölçüm eksikliğinden (G-094) |
| **bodyweight_squat** | `coming_soon` · hip+thigh derived, knee/shin/trunk FLOOR |
| kalan 29 hareket | katalogda var, ders katmanında yok |
| pin | **`f13bdc9`** = motion_core 0.11.0 + motion_camera 0.1.2 (tek commit) |

## 2. 🔴 AÇIK RELEASE-GATE — CİHAZ GÜNÜ

**Hiçbir beyan "cihazda kanıtlı" DEMEZ.** Ölçülmeyenler: fps · ısı · gerçek
landmark güveni · gerçek izin diyaloğu · saat alanı · kare düşme oranı.
iOS simülatöründe kamera **yoktur**; eldeki ekran kanıtı dürüst hâllerin
kanıtıdır, donanımın değil.

Cihaz günü ayrıca `identityGapShare` **p90 eşiğinin** ön koşulu: göz
doğrulamasıyla gerçek-tekrar ↔ birleştirilmiş-tekrar iki popülasyonu
birikince eşik p90'dan türetilir (ortalamadan DEĞİL). Damga bugün
**rapor-only** ve öyle kalmalı.

## 3. Değişmez kurallar (çiğnemeden önce sor)

- **Ölçmediğini söylemek ürünün kendisi.** `honesty` blokları
  `measurementContract`'ten TÜRER, elle yazılmaz.
- **Ölçümler, NOT DEĞİL.** `ProgressSummary.toJson()` anahtar kümesi teste
  ÇİVİLİ; skor/derece alanı eklemek testi ADIYLA kırar.
- **Geçilemez kapı BEYAN EDİLİR** — kilitli ders yüzeyden düşmez, gerekçe
  içerikten aynen taşınır (motor kullanıcı metni üretmez).
- **Ölü buton YOK.** Canlı seans girişi yalnız `precondition.status ==
  derived` olan harekette çizilir (K8'in çalışma-zamanı ikizi).
- **Yokluk kapısının yanına varlık ikizi** (M-F-194) — 19/19 self-test.
- **Yeni ölçüm aracı DOĞUMDA süpürmelerden geçer**: `valid` okuma +
  `value_range` beyanı + pozitif ikiz. (Üç kez kendi yeni aracımda ihlal
  buldum; hızlı probe kodu hattın standardının altına sessizce düşüyor.)
- **commit/push/merge:** Motion ailesinde KALICI İZİNLİ. Tasarım kararları
  koordinatöre.

## 4. Bu vardiyanın gotcha'ları

### 📷 Kamera/platform (G-120)
- iOS deployment **14.0** şart (MediaPipe 0.10.21 pini).
- Podfile **`use_frameworks! :linkage => :static`** — MediaPipe statik
  xcframework dağıtıyor, dinamik linkleme reddediliyor.
- `pod install` **`LANG=en_US.UTF-8`** olmadan düşüyor (makine ortamı).
- Pin **TAM-40-SHA** olmalı; tag adı pub tarafında çözülmüyor.
- Model **git'te değil** — fetch betiği + SHA doğrulaması.

### 🧪 Test disiplini
- **"Testler yeşil ≠ gerçek dosya doğru"** — iki kez ısırdı: JSONL şema
  anahtarı `"v"` sanılan `"schemaVersion"` (G-117) ve sığ-tekrar dizisinin
  aslında derin olması (G-120). İkisini de **ekran/koşum** yakaladı.
- **FakeAsync tuzağı:** `testWidgets` gövdesi sahte saatli; gerçek G/Ç orada
  ASILIR (kırmızı olmaz). Panzehir `tester.runAsync`.
- **iCloud:** `flutter clean` → `rm -rf build` → symlink (`~/gravita_buildout`).
  Sıra bu; symlinkten sonra clean symlinki siler.

### 📐 Ölçüm dersleri
- **Pencere-içi yayılım = ölçümün KENDİ gürültüsü** (kadraj saniyeler içinde
  değişemez). Tek-take okumaları bu tabana karşı sınanmadan hüküm taşımaz.
- **Permütasyon testi kanal-sabitini YAKALAYAMAZ** — küme≈kanal iken
  perm-p=0 yalnız "etiket gürültüsü değil" der.
- **Kuyruk ayırır, medyan ayırmaz** — eşik kuyruk kuantilinden konur.

## 5. KUYRUK — hepsi kurucu-manuel ya da tetikli

| # | iş | tür |
|---|---|---|
| 1 | 📱 **cihaz günü** — release-gate (§2) | kurucu-manuel |
| 2 | 🎨 design turu (`docs/design/UI-BRIEF.md` girdisi hazır) | kurucu-manuel |
| 3 | 🎥 iki-telefon çekimi — squat mod sorusu buna PARK | kurucu-manuel |
| 4 | G-118 `deepest_frame` gürültü-yanlılığı | **tetikli**: çıktısına dayanan yeni iddia kurulmadan ÖNCE ölç |
| 5 | 📚 ders katmanı — 30/31 hareket `precondition: pending`; ders açmak ÖLÇÜM işi, kod değil | ölçüm |

## 6. Nerede ne yazılı

| ne | adres |
|---|---|
| bulgu defteri (G-001…G-120) | `workspace/DEFTER.md` (sonda VARDİYA MÜHRÜ) |
| tur günlüğü | `workspace/PROGRESS.md` |
| kapı yazımları | `app/docs/gates/G-*.md` |
| kamera turu | `app/docs/gates/G-120-KAMERA-ENTEGRASYONU.md` |
| UI girdisi | `app/docs/design/UI-BRIEF.md` |
| aile mimarisi (BAĞLAYICI) | `ventures/motion-core/lib/docs/00-AILE-MIMARISI.md` |

⚠️ `ventures/motion-core/lib` yerel checkout'u **başka bir dala pinli** —
orada dal DEĞİŞTİRME (M-F-22). Salt okuma için `git show <ref>:<yol>` kullan.

---

**Özet:** kod temiz, kapılar yeşil, kamera bağlı ve iki platformda
derleniyor. Eksik olan ölçüm değil **cihaz**: gerçek kamerada hiçbir şey
doğrulanmadı ve bu isimli bir release-gate. Kuyruğun tamamı kurucu-manuel
ya da tetikli — yeni oturum bir paket beklemeli, kendi başına iş açmamalı.
