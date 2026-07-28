# Gravita — Ürün Yol Haritası (G0→G10)

**Tarih:** 2026-07-26 · **Statü:** Kurucu-onaylı çerçeve; oturumlar bu haritayı işler, sapmalar DEFTER'e.
**Hiyerarşi:** `00-AILE-MIMARISI.md` (D1 = P0 kapı!) > `20-URETIM-SURECI.md` > `10-ARAC-KATALOGU.md` > bu dosya > `gravita-plan.md`.
**Ürün dili: İNGİLİZCE.** Aile sırası **3** (ters-duruş riski nedeniyle Lissom/JabLab'dan sonra önerildi; kurucu tetiği sırayı ezer).

> ⚡ **REVİZYON 2026-07-26 (kurucu direktifi — KURUCUSUZ VERİ FABRİKASI + GENİŞ KÜTÜPHANE, M-F-13..16):** Bu haritadaki "kurucu çekimi / fixture çekim listesi kurucuya" varsayımları KALDIRILDI — kurucu çekim YAPMAZ. Birincil veri = kamu-video hasadı + sentetik (katalog §6.2; ücretli klip İPTAL — M-F-17); doğrulama = §6.3 merdiveni; öğretim görselleri = §6.4 katmanlı AI-eğitmen hattı (T1 = iskelet-sürümlü uygulama-içi avatar, $0 ve form-garantili). Kurucudan yalnız onay/kapı kararları + EN SONDA (G8'de, deneme amaçlı) cihaz-benchmark'ı beklenir — erken fazlar benchmark'ı BEKLEMEZ. **Geniş kütüphane:** Handstand + crow/headstand/hollow/L-sit/pistol + planche/lever GENİŞ hasat (GMB/FitnessFAQs/Merrick/THENX/Antranik; planche-lever ek tarama); G3 fixture'ları kamu-video + Unity-Perception sentetik ters-duruş setiyle; kasıtlı-hata örnekleri referansın kontrollü bozulmasından (M-C-03). Sorularını bu çerçevede kendin karara bağla — kurucuya soru YOK.

## 1. Kimlik ve Kuzey Yıldızı

**Gravita: Skills & Strength** — telefonu sabitle, handstand/beceri denemeni yap; sistem hizanı ve denemeni analiz etsin, EN önemli tek hatanı söylesin, doğru progresyonu açsın. Genel fitness app'i DEĞİL: ölçülebilir beceri kazanımı.
**Kuzey Yıldızı:** ilk başarılı serbest handstand'e (veya hedef becerinin ölçülebilir kriterine) ulaşan kullanıcı oranı + süresi. İkincil: kalibrasyon tamamlama ≥%90, yanlış-pozitif geri bildirim oranı, D7/D30 beceri devamlılığı.
**Vizyon (tavansız):** vücut becerileri koçu ailesi — handstand V1 motoru; L-sit/pistol/planche hazırlıkları aynı skill-graph motorunda.

## 2. Konumlandırma ve rakip boşluğu (kanıtlı)

| Rakip | Ne yapıyor | Boşluk |
|---|---|---|
| **AI Handstand** (Android) | Gerçek-zamanlı on-device pose + sesli cue — EN YAKIN rakip | Android-only görünüyor (iOS boşluğu!), tek-beceri dar kapsam; ELLE İNCELE (G0) |
| Calisthenics AI / Titans Grip ($19.99/ay) | Video YÜKLE → 0-100 form skoru + AI chat | Async upload; muhtemelen cloud (bizim on-device farkımız); gerçek-zamanlı seans koçluğu yok |
| Stickd ($4/ay) | Yarışma jimnastiği rutin skorlama (Code of Points) | Kulüp/hakem nişi; hobi handstand değil — kural-motoru-karşı-standart deseni İLHAM |
| Movement Athlete / GMB / Handstand Factory / Thenx | Progresyon programları, kamera YOK | Ölçmeden progresyon; Handstand Factory 1:1 koçluk €300/ay = fiyat-değer kanıtımız |
**Konumlandırma (EN):** *"Real-time skill coaching for handstands & bodyweight skills — voice cues during the hold, on-device, with progressions you unlock by measurable criteria."* iOS'ta first-mover şansı hâlâ açık görünüyor (G0'da teyit).

## 3. Teknik mimari kararları

- **D1 mutlak önkoşul:** MediaPipe dik-insan ağırlıklı eğitilmiş; ters-duruşta landmark güveni İSPATSIZ (resmî doküman YOK — araştırma taraması boş döndü). Model merdiveni (katalog §1): (a) düz infer ölçümü, (b) **180° döndürme hilesi** (en ucuz; BlazePose'un rotasyon-normalize eden detector mimarisi lehimize yapısal argüman), (c) RTMPose alternatifi, (d) landmark-üstü rotasyon-dayanıklı düzeltici (VIRA-GCN deseni). Karar verisi = G1.
- Bilimsel çekirdek: **bilek stratejisi** (Kerwin & Trewartha 2001; 2025 sistematik derleme) — denge kalitesi = düzeltmenin bilekte mi kalça/omuzda mı olduğu. Kamera TORK ÖLÇEMEZ → vekil metrik: omuz-kalça-ayak hattı salınım/açı-varyans profili. İç dokümanda "yaklaşıklık" olarak etiketli; pazarlamada tork iddiası YOK.
- State-machine: IDLE→PREPARING→KICK_UP→INVERSION→HOLDING→BALANCE_LOST→EXITING→COMPLETED (plan §7.1); duvar/serbest varyantları; kick-up güç analizi (aşırı/yetersiz).
- Skill-graph progresyonu: ölçülebilir kriterle kilit açma (ör. chest-to-wall 20sn + dirsek stabilite ≥%80 + 3 oturumda 2 başarılı + ağrı bildirimi yok) — kriterler uzman-düzenlenebilir config.
- **Güvenlik üstün:** düşme gerçek risk — alan/zemin kontrolü, duvar-önce progresyon, headstand boyun-yükü uyarısı, ağrı-durdurma; hiçbir faz bunları kırpamaz.
- Assessment modu heavy varyant; canlı mod full; sesli koç ters-duruşta EKSTRA kritik (ekran görülmüyor!) — cue tasarımı baş-aşağı bağlama göre ("shift fingertip pressure" tarzı, EN).

## 4. Faz planı

### G0 — Derin araştırma & bilgi kütüphanesi
1. AI Handstand'i Android cihazda ELLE incele (akış, cue seti, fiyat, on-device doğrulama); Calisthenics AI'yi iOS'ta dene; fiyatları store'dan teyit.
2. Bilim dosyası: 2025 sistematik derleme + Kerwin & Trewartha tam okuma; arXiv 1902.04250 (ekstrem hareket pose güveni) PDF'ini elle oku (ajan makine-okuyamadı); vekil-metrik tanımları.
3. Müfredat kütüphanesi: handstand progresyon sentezi (GymnasticBodies/Handstand Factory/r-bwf RR YALNIZ yapısal ilham — kopya yok): Wrist Prep→Shoulder Flexion→Hollow→Wall Plank→Wall Walk→Chest-to-Wall→Heel Pulls→Kick-Up→Freestanding→Shape Refinement + yardımcı beceriler (crow, headstand, hollow/arch, L-sit/pistol hazırlık). Her düğüme: kriter + drill + güvenlik notu. `movement-science-advisor` ilk geçiş.
4. Ters-duruş görüntü kaynakları envanteri (açık video, kendi çekim planı, Unity Perception sentetik hattı).

### G1 — V0 fizibilite kapısı (D1 — P0, KOD ÖNCESİ ZORUNLU)
1. Çekim listesi (kurucuya): duvar handstand (yüz/sırt dönük) + serbest deneme + kick-up + çıkış × {2-3 kişi, 2 ışık, 2 kıyafet} + crow/headstand; mümkünse farklı cihazlarda.
2. Ölçüm matrisi: aynı kliplerde (a) düz MediaPipe full/heavy, (b) 180°-döndürülmüş giriş — landmark güven ortalamaları, kritik nokta (bilek/omuz/kalça/ayak bileği) isabeti, kimlik karışması (sol/sağ flip) oranı.
3. Eşik önerisi + model merdiveni kararı taslağı; gerekirse RTMPose aynı kliplerde karşılaştırma.
4. Sentetik tamamlayıcı: Unity Perception ile handstand-poz seti üretim fizibilite notu (gerçek çekim yetmezse).
**Kapı çıktısı (kurucuya):** ters-duruş güvenilirlik raporu + seçilen model stratejisi. **Eşik altı kalırsa kod başlamaz** — alternatif strateji onayı beklenir.

### G2 — PRD + teknik tasarım
Akışlar (onboarding+güvenlik→kalibrasyon→başlangıç değerlendirmesi (plan §5.3)→beceri seçimi→ders→deneme→analiz→tek-hata→drill→yeniden deneme→karşılaştırma→özet), veri modeli (plan §11), skill-graph şeması, inversion-state-machine spesifikasyonları, D1 stratejisinin mimari yansıması (ör. döndürme hilesi pipeline'ı: inversion şüphesi→çift-geçiş infer→birleştirme).

### G3 — Veri & fixture kütüphanesi
Fixture'lar: doğru handstand + aşırı bel çukuru (banana) + bükülü dirsek + yetersiz/aşırı kick-up + denge kaybı yönleri + kadraj-dışı + düşük güven + kamera hareketi (plan §13). Kaynak: kurucu çekimleri (birincil) + Unity Perception sentetik nadir pozlar + InfiniteRep (yardımcı beceriler). Replay harness motion-core'dan pinli.

### G4 — Motor inşası
Inversion tespiti (D1 stratejisiyle) → handstand state-machine → hiza/denge metrikleri (omuz-kalça-ayak hattı, dirsek, bel, kick-up profili, salınım-vekili) → tek-hata önceliklendirme (güvenlik>imkânsızlaştıran>denge>büyük hiza>küçük form — plan §9) → skill-graph kilit motoru → skor bileşenleri (hizalama/kontrol/tutuş/giriş/çıkış/tutarlılık/analiz-güveni).
**Kapı:** fixture-replay yeşil; "en az 5 güvenilir hata" fixture kanıtlı; düşük-güvende hüküm-yokluğu testli.

### G5 — İskelet uygulama (alpha, İngilizce)
Tüm akışlar cilasız; canlı deneme ekranı (overlay + süre + sesli cue); deneme karşılaştırması; skill-graph görünümü. Impeller benchmark; `mobile-runtime-tester` sweep; "telefonu yere koy, ekranı görme" senaryosunda sesli-akış testi.

### G6 — İçerik üretimi
Skill-graph config'leri + drill kütüphanesi + ders anlatımları (EN) · sesli koç replikleri (~400-600 satır; ters-duruş-bağlamlı cue dili) → aile voice-pack hattı (harcama onayı) · güvenlik metinleri (plan §12) · başarı-anı tasarımı (`game-design-architect`: ilk 5sn tutuş kutlaması vb. — `motion-interaction-designer` mikro-anlar). Calisthenics uzman doğrulaması manuel listeye.

### G7 — UI giydirme (Claude Design)
"Beceri atölyesi" estetiği: skill-graph = vitrin ekranı; deneme-karşılaştırma görselleştirmesi. Token sistemi + polish turu; dark/light + %200 font.

### G8 — Sertleştirme
Cihaz matrisi (fps/ısı; heavy-varyant assessment maliyeti) · a11y · crash+analytics (kalibrasyon başarı, analiz-edilemeyen deneme oranı, yanlış-pozitif proxy) · offline kanıtı · izinli-video-kayıt akışının gizlilik denetimi (varsayılan KAPALI).

### G9 — Monetizasyon + uyum
Paywall: ilk değerlendirme + ilk beceri yolu ücretsiz → tam skill-graph + geçmiş + karşılaştırma abonelik (assessment-kapılı desen). Koridor katalog §8 → öneri → kurucu. IAP sandbox + Opus doğrulama. Uyum: privacy + store-policy turları; "sakatlanmazsın/güvenli" DEMEYİZ (plan §8); çocuk-gözetim dili.

### G10 — Pazarlama & lansman
ASO: "handstand, calisthenics, skill training, bodyweight" seti; ekran görüntüsü anlatısı: kur→dene→tek düzeltme→progresyon aç→ilk handstand. Reklam kreatifi: gerçek ilk-handstand hikâyesi (build-in-public malzemesi — `build-in-public-storyteller`). iOS-first mesaj fırsatı (AI Handstand Android-only ise). Submission kurucu.

## 5. Riskler / DEFTER tohumları
G-001 (mevcut): D1 ters-duruş. Yeni: G-002 AI Handstand rekabet takibi (iOS'a gelirse fark stratejisi) · G-003 vekil-metrik geçerliliği (tork ölçemeyiz — dil disiplini) · G-004 düşme güvenliği iletişimi (hukuki dil) · G-005 sentetik-veri hattı bakım maliyeti.

## 6. Manuel / kurucu görevleri
Handstand fixture çekimleri (kendi denemelerin + çevrenden gönüllü) · AI Handstand için Android cihaz erişimi · calisthenics uzman doğrulaması · voice-pack harcaması · fiyat onayı · submission · domain (getgravita.app $9.99 — M-006).

## 7. Oturum örgütlenmesi
Fable/high; `motion-cv-engineer` D1 sahibi (İLK durak); fan-out sonnet; riskli sınıf Opus; /loop. Başlangıç promptu: vault `🚀 Başlangıç Promptu — Gravita`.

---

## 8. DALGA PLANI (blueprint M-F-18 sonrası — kapsam otoritesi `GRAVITA-BLUEPRINT.md`)

G0→G10 faz modeli korunur; **kapsam artık dalga-bazlı işlenir** (standart §4.2: her dalga için G3→G6 döngüsü, platform katmanı bir kez G5'te).

| Dalga | Kapsam | Motor gereksinimi | Durum |
|---|---|---|---|
| **W0** | Borç kapatma + IA çatısı + sınıf-kuralları config şeması | — | ✅ **BİTTİ** (2026-07-29) |
| **W1** | Kitle-pazar bodyweight + core (şınav/barfiks/dip/squat/lunge/plank/burpee + core seti) | rep-FSM jeneriği ✅ · statik-tutuş motoru ⏳ · çok-faz FSM ⏳ | 🟠 **20 hareket şemalandı · RepEngine çalışıyor (37/37 test)** — kalan: statik-tutuş + çok-faz motorları, perturbasyon üreteci, hasat pilotu |
| **W2** | DB/KB kütüphanesi + amiral beceriler (handstand ağacı, planche ağacı) | tempo/eksantrik · KB kadans (RhythmEngine) · **inversiyon hattı (D1 çözümü)** | ⏳ |
| **W3** | Barbell bileşikleri + FSM klasikleri (TGU, Nordic) + **bench = sınıf B** | çok-faz FSM derinleşmesi · **bar/kenar tespiti R&D başlar** | ⏳ |
| **W4** | Bar becerileri + genişletilmiş calisthenics + pliometrik | bar tespiti (veya fallback) · checkpoint koçluğu | ⏳ |
| **W5** | Rings + köprü + aspirasyonel + doğrulama-bekleyenler | salınım-toleranslı smoothing · derin-fleksiyon doğrulaması | ⏳ |

### W0 çıktıları (kanıt)
`content/schema/{movement-classes,movement.schema,metrics}.json` · `content/catalog/w1/*.json` (5) · `content/catalog/exclusions.json` · `tools/validate_catalog.py` (9 değişmez, ✅ 0 hata) · `docs/W0-BILGI-MIMARISI.md`

### W1 görev kuyruğu
1. Kalan ≈15 hareketin şemalanması (dip, lunge, dead bug, bird dog, hollow, side plank, hanging leg raise, mountain climber, glute bridge, superman, wall sit, calf raise, step-up, toes-to-bar, inverted row).
2. **Hasat hattı** (katalog §6.2): hareket-başına ≥3 bağımsız eğitmen → referans çıkarımı → **tolerans kaynak varyansından** (G-014 kapanışı).
3. Perturbasyon üreteci: referanstan kasıtlı-hata fixture'ları (M-C-03) — betik zaten genlik şartını zorluyor.
4. Rep-FSM + statik-tutuş motoru: fixture-replay testli (kod, motion-core'u TÜKETİR — çekirdeğe yazılmaz, M-F-03).
5. Kurs/program config'leri + sesli koç replikleri (EN).

### Değişen varsayımlar (M-F-13..18)
- ❌ Kurucu çekimi — `docs/G3-CEKIM-LISTESI.md` artık **opsiyonel şablon**; birincil hat kamu-video hasadı + Unity sentetik.
- ❌ Kurucu-bekleyen cihaz benchmark'ı erken fazlarda — **G8'e ötelendi**, eşikler "cihazda doğrulanacak" etiketiyle taşınır.
- ✅ Skor gösterimi **bant** (M-F-04/K8) — sayısal skor kalibrasyon kapısı sonrası.
- ✅ motion-core sahibi **koordinatör oturum** (M-F-03) — çekirdek API ihtiyaçları DEFTER'e yazılır, core'a doğrudan yazılmaz.
