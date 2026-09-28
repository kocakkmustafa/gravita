# Gravita — LOOP (iş kuyruğu + oturum protokolü)

## 2026-09-28 güncel kuyruk
1. PR #1'e taşınan 56 derslik Calisthenics kaynağında Actions bütçe engeli kalkınca son başta yararlı CI al.
2. App-local içerik okuyucusu kaynak ve odaklı test düzeyinde hazır; üretim manifesti, ekipman etiketli gösterim, altyazı ve gerçek cihaz oynatma kabulünü tamamla.
3. Kişi-ayrık uzman hareket hatası ve güvenli hazırlık verisi olmadan tam-kurs form modeli fit veya otomatik güvenli-form hükmü yok; held Squat ZIP/once-failed deneyler korunur.
4. Kurucu bütün dersleri en son toplu fiziksel test eder; mağaza kapıları ayrıdır.


## Oturum açılışı
1. `../VENTURE.md` + PROGRESS son mühür + DEFTER açık maddeler OKU.
2. 🔓 **Kod kilidi 2026-07-26'da AÇILDI** (kurucu tetiği). G1/D1 kapısı **şartlı geçti** — ters-duruş hattında üretim kodu yalnız **ADR-001** (yönelim-farkında çıkarım) mimarisiyle yazılır.
3. Karar bağlamı sırayla: `app/docs/gates/G1-D1-RAPOR.md` → `app/docs/PRD.md` → `app/docs/ADR/` → `app/docs/G4-BECERI-GRAFI-TASARIMI.md`.
4. Kapanışta `/oturum-kapanisi` skill'i.

## Kuyruk (2026-07-26 gece sonu itibarıyla)

### ⛔ Blokajlı (kurucu kararı / kurucu eli)
- **G3 fixture kütüphanesi** ← kurucu çekimi: `app/docs/G3-CEKIM-LISTESI.md`. A+B grupları (~60-75 dk) yeter.
- **D1 yeniden ölçümü (`G1-D1-RAPOR-v2`)** ← aynı çekim; borç G-009 (vekil ortam + temsili olmayan kadraj) bu olmadan kapanmaz.
- **G4 motor inşası** ← ~~M-017~~ **ÇÖZÜLDÜ: kurucu kararı "Dart kanonik, Python yalnız video→fixture çıkarma aracı"** (kaynak: Lissom devir notu §3, 2026-07-26). Yani Gravita'nın motoru `motion-core/packages/motion_core` (Dart, 84/84 test) çekirdeğini TÜKETİR; ölçüm/fixture işi Python hattında kalır.
  **Kalan gerçek blokaj = G-010:** ADR-002'nin *faz-eksen uyumu* kontrolü ve ADR-001'in (yönelim anahtarlaması) kendisi çekirdekte YOK; `StructuralValidator.check(PoseFrame)` bağlam almıyor. Bunları **kim yazacak** kararı gerekiyor (çekirdeğe yazma yetkisi tanımlı değil).

### ▶️ Hemen yapılabilir (kapıya ve çekime bağımsız)
1. **G0 rakip elle-doğrulaması (M-015)** — AI Handstand (Android; en yakın rakip, iOS boşluğu iddiasının teyidi) · Calisthenics AI iOS'ta dene · fiyatları store ekran görüntüsüyle teyit. **Konumlandırma iddiaları bu tur olmadan G10'a girmez.**
2. **Bilim dosyası (roadmap G0-2)** — 2025 sistematik derleme + Kerwin & Trewartha 2001 tam okuma + arXiv 1902.04250 elle okuma → vekil-metriklerin literatür dayanağı. **Dil disiplini: tork/kas-aktivasyon iddiası YOK.**
3. **`movement-science-advisor` ilk geçişi** — `content/skill-graph/handstand.v1.json` eşiklerinin fizyolojik denetimi (borç D-1). Çıktı: revize eşikler + gerekçe. Uzman (insan) doğrulaması manuel listede kalır.
4. **Sesli cue seti taslağı (G6 öncüsü)** — ters-duruş bağlamlı, **ekran görülmeden** çalışan cue dili (EN); katalog §5 bölümlemesi (sabit replik → voice-pack / dinamik sayı → sistem TTS).
5. **Fixture şeması dönüştürücüsü** — `tools/d1-gate/` çıktısını katalog §6 aile şemasına çeviren adaptör (çekim gelmeden yazılabilir, geldiğinde hazır olur).
6. **G-006 nöbetçi betiği** — "kick-up/çıkış metrikleri hiçbir açma kriterinde kullanılmıyor" kontrolü (PRD §11 kabul kriteri); içerik paketi üzerinde koşan basit doğrulayıcı. *(Not: DAG + gateable kontrolü commit sırasında elle koşuldu, betikleşmesi kaldı.)*

### 🔜 Sonra
G5 iskelet uygulama (Impeller/kamera benchmark İLK iş) · G6 içerik · G7 UI (Claude Design) · G8 sertleştirme · G9 monetizasyon+uyum (ADR-006 → kurucu fiyatı) · G10 ASO/lansman.

## Sert kurallar (bu ürün)
- Motor kodu **fixture-replay testsiz** yazılmaz · düşük güvende **hüküm yok** · gerçek-zamanlı LLM yok · ham video cihazda kalır.
- **Güvenlik kırpılmaz:** duvar-önce progresyon · bilek/omuz hazırlık kapıları · ağrı-durdurma · headstand boyun-yükü uyarısı + açık onay.
- Kick-up/çıkış metrikleri **hiçbir açma kriterinde kullanılmaz** (G-006).
- Kurallar **taraf-agnostik** (G-007) · her denemeye **köken alanları** (ADR-005) · eşikler **model varyantı başına** (G-008).
- Ham medya repoya **commit edilmez**; yalnız türetilmiş landmark/metrik.
- ⚠️ Paylaşımlı ağaç: motion-core'da yabancı commit'siz iş varsa **DOKUNMA, ÖNCE SOR** (M-016). Defter ID'si eklerken çakışma kontrol et (M-019/M-020 bu yüzden taşındı).
