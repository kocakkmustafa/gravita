# G4 — Beceri Grafı Motoru: Tasarım Kararı

**Tarih:** 2026-07-26 · **Statü:** Oturum kararı (gece modu; kurucu retrospektif onayı)
**Girdiler:** `gravita-plan.md §10` · `gravita-roadmap.md §3-4` · **`gates/G1-D1-RAPOR.md`** (ölçülmüş kısıtlar) · `20-URETIM-SURECI.md`
**Çıktı:** `content/skill-graph/handstand.v1.json` (içerik paketi) + bu doküman (motor sözleşmesi)

---

## 1. Temel karar: motor beceri-BAĞIMSIZ, beceri içerik-PAKET

Başlangıç promptunun bağlayıcı direktifi: *"skill-graph motoru BECERİ-BAĞIMSIZ (handstand bir içerik; L-sit/pistol/planche kod değişimi istemesin)"*.

| | Motorda (kod) | Pakette (versiyonlu JSON config) |
|---|---|---|
| Ne | Graf yürütme, kriter değerlendirme, kilit/açma, ilerleme durumu, güvenlik zorlaması | Düğümler, ön-koşullar, açma kriterleri, drill'ler, sesli cue metinleri, güvenlik notları |
| Kim değiştirir | Mühendislik | **Uzman-düzenlenebilir** (calisthenics uzmanı, `movement-science-advisor`) — kod bilgisi gerekmez |
| Sürümleme | semver (motor) | `packVersion` + `schemaVersion`; her `Attempt` kaydına yazılır |

**Sonuç:** yeni beceri (L-sit, pistol, planche hazırlığı, hatta Lissom'un mobilite testleri) = **yeni JSON**, kod değişikliği yok. Bu, ürünün "vizyon tavansız" büyümesinin (00-AILE-MIMARISI §1.1) mühendislik karşılığıdır.

## 2. D1 kapısının içeriğe dayattığı kısıtlar (ölçülmüş — tartışmaya kapalı)

Kapı raporu (§1, §3.4) üç sert kısıt üretti. **Bunlar içerik tasarımının önkoşuludur:**

| Kapı bulgusu | İçerik kısıtı |
|---|---|
| **G-006** — hızlı fazda (kick-up/çıkış) tespit tamamen kayboluyor | **Açma kriteri YALNIZ tutuş-fazı metriklerinden kurulur.** Kick-up kalitesi gösterilir ama *kapı olamaz* (`gateable: false`) |
| **G-007** — model sol/sağ etiketleri ters-duruşta güvenilmez | Kriterler **taraf-agnostik**: "dirsek ekstansiyonu" = görünen taraf zincirinden; "sol dirsek" diye bir kriter YAZILAMAZ |
| **G-002/G-003** — hüküm ancak yönelim doğrulanmış + yapısal denetimden geçmiş karede verilir | Her kriterin yanında **zorunlu `analysis_confidence` eşiği**; düşük güvende deneme "ölçülemedi" sayılır, başarısız DEĞİL |

> **"Ölçülemedi" ≠ "başarısız".** Kullanıcı analiz edilemeyen bir denemeden dolayı ilerlemesini kaybetmez. Bu, plan §7.4'ün ("analiz edemedim demek yanlış hüküm vermekten üstündür") ilerleme sistemine yansımasıdır.

## 3. Motorun zorladığı değişmezler (içerik bunları KIRAMAZ)

Bu dört kural **koddadır**; hiçbir içerik paketi bunları atlayamaz — güvenlik ve dürüstlük içeriğe bırakılmaz:

1. **Güvenlik ön-koşulu zorlaması:** `safetyGate` taşıyan düğüm, ön-koşulları tamamlanmadan açılamaz (duvar-önce progresyonu, bilek/omuz hazırlığı). Roadmap §3: *"hiçbir faz bunları kırpamaz"*.
2. **Ağrı-durdurma üstünlüğü:** aktif ağrı bildirimi varsa ilgili dal **kilitlenir** ve oturum durdurulur — kriter listesinde yazsın yazmasın motor ekler.
3. **Analiz-güveni kapısı:** her açma değerlendirmesine otomatik `analysis_confidence ≥ eşik` şartı eklenir.
4. **Tekrarlanabilirlik:** tek seferlik başarı açma yapmaz — her kritik düğüm `repeat` penceresi ister (ör. 3 oturumda 2). Şans eseri bir denemeyle ileri beceriye geçiş = düşme riski.

## 4. Kriter dili (değerlendirilebilir, açıklanabilir)

Kriterler serbest metin değil, **yorumlanabilir yapı**dır — böylece her açma kararı kullanıcıya gerekçelendirilebilir (plan §15: *"her teknik kararın neden verildiği loglanabilir olmalı"*).

```jsonc
{ "metric": "hold_duration_s", "op": ">=", "value": 20,
  "aggregate": "best",            // best | median | mean
  "window": { "sessions": 3, "successesRequired": 2 } }
```

Motor her değerlendirmede kullanıcıya gösterilebilir bir **gerekçe nesnesi** üretir:
`{criterion, required, observed, met, evidenceAttemptIds}` → "Chest-to-wall 20 sn: en iyin 14 sn (3 oturumda 2 kez gerekiyor)".

**V1 metrik sözlüğü** (yalnız tutuş fazından, taraf-agnostik, D1-uyumlu):

| Metrik | Tanım | Kapı olabilir mi |
|---|---|---|
| `hold_duration_s` | Doğrulanmış ters-duruş durumunda kesintisiz süre | ✅ |
| `elbow_extension_pct` | Görünen taraf dirsek açısının düz-kola yakınlığı, tutuş medyanı | ✅ |
| `line_deviation_deg` | Omuz-kalça-ayak bileği hattının düşeyden sapması | ✅ |
| `lumbar_flexion_proxy` | Bel çukuru vekili (omuz-kalça-diz açısı) | ✅ |
| `sway_proxy` | Hat açısının tutuş boyunca varyansı — **denge kalitesi vekili** | ✅ |
| `analysis_confidence` | Güven kapısı + yapısal denetimden geçen kare oranı | ✅ (zorunlu) |
| `pain_reported` | Kullanıcı beyanı | ✅ (zorunlu, ters yönde) |
| `kickup_impulse` | Giriş kuvveti kestirimi | ❌ **gateable: false** (G-006) |
| `exit_control` | Çıkış kontrolü | ❌ **gateable: false** (G-006) |

⚠️ **`sway_proxy` dil disiplini (G-003 / roadmap §3):** kamera **tork ölçemez**. Bilek-stratejisi literatürü (Kerwin & Trewartha 2001) modelimizin *ilhamıdır*, ölçtüğümüz şey değil. İç dokümanda "vekil"; kullanıcı arayüzünde ve pazarlamada **tork/kas-aktivasyon iddiası YOK**.

## 5. Graf yapısı (V1 içeriği)

Ana zincir (roadmap §4/G0-3) + yardımcı dallar. Ok = ön-koşul.

```
wrist_prep ──┐
             ├─→ wall_plank ─→ wall_walk ─→ chest_to_wall ─→ heel_pulls ─→ kick_up_control ─→ freestanding ─→ shape_refinement
shoulder_flexion ─┘                              │
hollow_body ─────────────────────────────────────┤
                                                 └─→ (yardımcı) crow_pose ─→ headstand ⚠️boyun-yükü
arch_body ─→ (şekil bilinci)          l_sit_prep · pistol_prep  ← aynı motor, ayrı dallar (vizyon kanıtı)
```

- **Duvar-önce zorunluluğu:** `freestanding` düğümü `chest_to_wall` + `heel_pulls` olmadan AÇILMAZ (`safetyGate`).
- **`headstand` özel uyarı:** boyun yükü — plan §12 gereği belirgin uyarı + ayrı onay; ana zincirin ön-koşulu DEĞİL (isteğe bağlı dal).
- **`l_sit_prep` / `pistol_prep`:** V1'de kapsamda (plan §4) ve **motorun beceri-bağımsızlığının kanıtı** — handstand zincirine bağlı değiller.

## 6. Sesli koç bağı (G6'ya devir)

Ters-duruşta kullanıcı **ekranı göremez** (roadmap §3) → cue'lar baş-aşağı bağlama göre yazılır ve düğüm paketinde taşınır (`cues`). Katalog §5 hibrit mimarisi: sabit replikler voice-pack, dinamik sayılar sistem TTS. Cue metinleri **İngilizce** (ürün dili), i18n anahtarı olarak paketlenir.

## 7. Bu tasarımın açık borçları

| # | Borç | Sahip |
|---|---|---|
| D-1 | Kriter eşik DEĞERLERİ (20 sn, %80 vb.) plan/roadmap'ten devralındı — **fizyolojik doğrulama yapılmadı** | `movement-science-advisor` ilk geçiş → calisthenics uzmanı (manuel liste) |
| D-2 | Metriklerin gerçek ölçülebilirliği (özellikle `sway_proxy`, `lumbar_flexion_proxy`) **fixture'la kanıtlanmadı** | G3-G4 |
| D-3 | Motor, motion-core'un yönelim-farkında poz kaynağına bağımlı (G-002/M-019) — çekirdek paralel oturumda aktif geliştirmede | motion-core koordinasyonu |
| D-4 | `analysis_confidence` eşiği (paket taslağında 0.7) **kalibre edilmedi**; gerçek cihaz + kurucu çekimleriyle ayarlanacak | G3/G5 |
