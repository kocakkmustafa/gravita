# GRAVITA — Tam Kapsam Blueprint (oturumun kapsam otoritesi)

**Tarih:** 2026-07-28 · **Statü:** KURUCU-ONAYLI (revizyonlu: fitness'ın profesyonel-önerili hareketleri + genişletilmiş calisthenics EKLENDİ). Ortak omurga: motion-core `docs/30-URUN-BLUEPRINT-STANDARDI.md` (ÖNCE onu oku).
**Nihai ürün:** "Skills & Strength" — form koçluğu + rep sayma + beceri ağaçları: bodyweight'ten barbell'e, temel hareketten elit beceriye, HER hareket kendi sayfasında kurslarıyla; **~120-180 hareketlik küratörlü, poz-izlenebilir kütüphane** (Fitbod/Jefit'in 1.400-1.600'lük log-kataloğu taklit edilmez — onlar form-koçluğu YAPMIYOR; bizim farkımız her harekette gerçek form analizi).

---

## 1. HAREKET-SINIFI KURALLARI (katalog buna göre ölçeklenir — tek tek hareket tartışılmaz)

| Sınıf | Kural | Sonuç |
|---|---|---|
| A | Açık-zincir, dik/ayakta, tek-düzlem baskın, uzuv/bar yolu yan-45° kameradan görünür | ✅ TAM form koçu |
| B | Sırtüstü/yüzüstü VEYA hareket kameranın derinlik eksenini kesiyor (ör. bench press) | ⚠️ rep+tempo+kurulum koçluğu — "form notu" İDDİA EDİLMEZ |
| C | Makine-kılavuzlu (yol makinece sabit; gövde makinece kapalı) | ❌ KAPSAM DIŞI — makine formu zaten zorluyor + oklüzyon ("Neden yok?" sayfası) |
| D | Prop/nesne takibi gerektirir (kutu yüksekliği, ip, ab-wheel mesafesi, bant gerginliği) | ⚠️ vücut-mekaniği koçlanır; prop-metriği "R&D" etiketli ayrı iş |

## 2. TAM KAPSAM — 5 dalga

**W1 — Kitle-pazar bodyweight + core (✅ en yüksek talep, en düşük risk):** şınav ailesi, barfiks, dip, squat, lunge, plank (süre+form-kırılma), burpee (çok-faz FSM); core: dead bug, bird dog, hollow, side plank, hanging leg raise/toes-to-bar, mountain climber, glute bridge, superman, wall sit, calf raise, step-up.
**W2 — DB/KB kütüphanesi + amiral beceriler:** curl, lateral/front raise, shoulder press, DB row, RDL, goblet squat, lunges, floor press, farmer carry (yürüme-kadraj yönergesi), **KB swing (✅ + RhythmEngine tempo-senkron sinerjisi!)**, goblet clean; beceri: **handstand ağacı** (duvar→serbest→HSPU) + **planche ağacı** (tuck→straddle→full).
**W3 — Barbell bileşikleri + FSM klasikleri:** back/front squat ✅, deadlift (konvansiyonel ✅; sumo ⚠️ frontal-düzlem kamera yönergesi), OHP ✅, bent-over row ✅, hip thrust ✅, **bench press = SINIF B (adlandırılmış istisna: rep+tempo+kurulum; form notu yok — pazarlamada da böyle)**; **Turkish get-up (5-7 fazlı FSM — rakiplerin hiç denemediği vitrin özelliği)**, Nordic curl ✅ (eksantrik-tempo koçluğu), KB snatch ⚠️ (blur doğrulama sonrası).
**W4 — Bar becerileri + genişletilmiş calisthenics + pliometrik:** front/back lever, muscle-up (**bar/kenar tespiti R&D + faz-checkpoint** — patlayıcı geçiş kare kare skorlanmaz, dürüst dil), archer/typewriter şınav-barfiks, pseudo-planche şınav, tek-kol şınav progresyonu, commando pull-up, dragon flag, elbow lever, skin-the-cat (FSM), front-lever row, wall walk, crab/bear crawl, pistol squat; plyo: jump squat ✅, broad jump (✅ mekanik; mesafe ⚠️), clap push-up ✅, box jump (⚠️ kutu tespit edilmez — iniş-mekaniği koçlanır), jump rope (ip takılmaz — **zıplama kadansı RhythmEngine'le ✅**, ip-tekniği değil).
**W5 — Rings + köprü + aspirasyonel + doğrulama-bekleyenler:** ring temelleri (salınım-toleranslı smoothing), bridge/backbend (drop-back = duvar-destekli varsayılan + sert uyarı), crow→handstand geçişi; **aspirasyonel (ROZETSİZ, rehberli):** one-arm handstand, Manna, human flag (dikey direk gereksinimi açık yazılır); sissy/shrimp squat (⚠️ derin-fleksiyon landmark doğrulaması geçerse ✅'a terfi).

**❌ Kapsam-dışı ("Neden yok?"):** TÜM makine egzersizleri (sınıf C — blanket kural, destek/pazarlama da vaat etmez) · flips/aerials (felaket-düşüş sorumluluğu) · gerçek 1RM/kuvvet ölçümü (kamera kuvvet ölçemez — StrengthLevel tablolarına logla-karşılaştır sunulabilir, "ölçtük" denmez).

## 3. Bilgi mimarisi (standart §2'nin Gravita örneği)
Kütüphane → **Kas grubu / Hareket-aile sayfaları** (İtiş · Çekiş · Bacak · Core · Omuz · Beceri Ağaçları · Barbell · DB/KB · Plyo) → **Hareket sayfası** (her hareket: nasıl yapılır [iskelet-avatar] + form hataları + kurslar/programlar + kişisel rep/form-trend grafiği + sınıf-etiketi dürüstlük kutusu [A/B/D]) → Seans akışı. Beceri ağaçları ayrı görsel skill-tree UI (kilit-açma kriterli). Program sayfaları: hazır programlar (Full-body başlangıç, PPL, KB-only, ev-bodyweight...) rule-engine'le kişiselleştirilir.

## 4. Motor iş listesi
1. Rep-sayacı FSM çatısı (aşağı→yukarı faz + açı eşikleri; hareket-başına config — sınıf-A jeneriği).
2. Statik-tutuş motoru (plank/hollow/lever: süre + form-kırılma tespiti).
3. Çok-faz FSM (burpee, TGU, skin-the-cat — pose state-machine modülü üstüne).
4. Tempo/eksantrik koçluğu (Nordic, RDL) — RhythmEngine bağı; KB-swing kadans modu.
5. İnversiyon hattı (D1 çözümü: yönelim-farkında çıkarım + StructuralValidator) — handstand/HSPU/wall-walk.
6. **Bar/kenar tespiti R&D** (W4 kapısı: kapı-barfiks demiri gerçek ev koşullarında prototip; başarısızsa lever/muscle-up "bar-görünür kadraj yönergesi + gövde-tek analiz" fallback'iyle).
7. Derin-fleksiyon doğrulama turu (sissy/shrimp/ATG: gerçek görüntüde landmark jitter ölçümü — ✅/⚠️ kararı kanıtla).

## 5. İçerik hattı
Kaynak havuzu: GMB, FitnessFAQs, Tom Merrick, THENX, Antranik (beceriler) + NSCA/ACSM/ACE teknik standartları + StrengthLevel standart tabloları (kural-motoru referansı; 793k+ veri noktalı squat standardı gibi) → hareket-başına ≥3 kaynak konsensüsü → form-hata taksonomisi (perturbasyon) → kurs/program config'leri → voice-pack (EN; rep sayımı + tek-düzeltme) → iskelet-avatar. Doğrulama: MM-Fit/InfiniteRep + kendi sentetik (Unity: ters-duruş + derin-fleksiyon pozları) — §6.3.

## 6. Görev backlog'u (dalga-bazlı)
**W0:** Mevcut G-serisi borçları kapat (G4 motor→G5 iskelet) + IA çatısı (tüm aile sayfaları) + platform katmanı + sınıf-kuralları config şeması.
**W1→W5:** yukarıdaki dalga içerikleri; her dalga = hasat→referans→config→ders→sweep→DEFTER→vault döngüsü. Bar-tespiti R&D W3 sırasında paralel başlar (W4'ü bloklamasın).
**Kapanış:** kapsam-tamamlama turu (ölü sayfa 0, her hareket sayfası dolu, A/B/D etiketleri doğru).

## 7. Gravita-özel platform deltaları
Skill-tree UI · rep-PR geçmişi + StrengthLevel-karşılaştırma (log-bazlı, iddiasız) · seans oluşturucu (kullanıcı programı) · Lissom "calisthenics hazırlık" deep-link · HealthKit "Strength Training" yazımı · Live Activity set-arası sayaç.

## 8. Dürüstlük/güvenlik (Gravita-özel)
Bench/B-sınıfı hareketlerde "form notu" verilmez (UI'da sınıf-etiketi) · kuvvet/1RM ölçüm iddiası yok · elit beceriler rozetsiz · drop-back/headstand/OAHS sert güvenlik uyarıları · derin-fleksiyon hareketleri doğrulama öncesi ⚠️ etiketli · makine-yokluğu açık anlatılır.

## 9. Manuel-sona listesi (kurucu)
Calisthenics/S&C uzman turu (dalga-sonu) · cihaz-benchmark (G8) · fiyat onayı · voice-pack bütçesi · submission.
