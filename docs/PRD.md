# Gravita — PRD (V1 Ürün Gereksinim Dokümanı)

**Tarih:** 2026-07-26 · **Faz:** G2 · **Statü:** Oturum kararı (gece modu; kurucu retrospektif onayı)
**Hiyerarşi:** `00-AILE-MIMARISI.md` > `20-URETIM-SURECI.md` > `10-ARAC-KATALOGU.md` > `gravita-roadmap.md` > **bu doküman** > `gravita-plan.md`
**Bağlayıcı girdi:** [`gates/G1-D1-RAPOR.md`](gates/G1-D1-RAPOR.md) — ölçülmüş kısıtlar. Bu PRD'nin hiçbir maddesi kapı bulgularıyla çelişemez.
**Mimari kararlar:** [`ADR/`](ADR/) · **Beceri grafı:** [`G4-BECERI-GRAFI-TASARIMI.md`](G4-BECERI-GRAFI-TASARIMI.md)
**Ürün dili: İNGİLİZCE** (i18n altyapısı baştan, V1 yalnız `en`). Bu doküman iç dokümandır → Türkçe.

---

## 1. Ürün tek cümlede

> Telefonu sabitle, seçtiğin beceriyi dene; sistem hizanı ve denemeni cihaz üstünde analiz etsin, **tek** en önemli hatanı söylesin, ölçülebilir kriterle bir sonraki progresyonu açsın.

**Gravita bir fitness uygulaması DEĞİLDİR.** Değer birimi "antrenman tamamlamak" değil, **ölçülebilir beceri kazanımı**dır. Kuzey Yıldızı: ilk başarılı serbest handstand'e ulaşan kullanıcı oranı ve süresi.

## 2. V1 kapsam sınırı (bağlayıcı)

**İÇİNDE:** handstand ana zinciri (`wrist_prep`→`shape_refinement`, 10 düğüm) + yardımcı dallar (crow, headstand ⚠️, hollow/arch) + ayrı beceri dalları (l_sit_prep, pistol_prep) · tek kişi · tek kamera · ekipmansız (duvar/mat serbest) · çevrimdışı çekirdek · cihaz-üstü analiz · sesli koçluk.

**DIŞINDA (plan §4 + bu PRD):** akrobatik/flip · planche/lever · bar/ring/paralette · çoklu kişi · giyilebilir sensör · gerçek-zamanlı LLM · sosyal ağ/yarışma/koç pazaryeri · sakatlık teşhisi · "düşmeni engelleriz" iddiası.

**⚠️ V1'de KAPSAM-DIŞI ilan edilen, plandan gelen özellikler** (D1 kapısı gereği — dürüstlük > vitrin, `20-URETIM-SURECI §5`):
| Plan maddesi | V1 durumu | Gerekçe |
|---|---|---|
| Kick-up kuvvet analizi (aşırı/yetersiz) — plan §7.2 | **Gösterilir, kapı DEĞİL** | G-006: hızlı fazda tespit kaybı ölçüldü |
| Kontrollü çıkış skoru — plan §8 | **Gösterilir, kapı DEĞİL** | G-006 |
| Baskın taraf bazlı kurallar | **YOK** | G-007: model sol/sağ etiketleri ters-duruşta güvenilmez |
| "Denge kaybı yönü" — plan §16 | **Kaba sınıf** (öne/arkaya/yana), derece iddiası yok | Vekil metrik sınırı |

## 3. Kullanıcı akışları

### 3.1 Onboarding (ilk açılış)
1. **Değer ekranı** — ne yaptığımız + ne YAPMADIĞIMIZ (tıbbi değil, koç yerine geçmez, düşmeyi engellemez).
2. **Güvenlik onayı** — `safetyCopy.generalDisclaimer` + alan/zemin kuralı; açık onay olmadan devam yok.
3. **Profil** (plan §5.1): yaş aralığı · boy/kilo (opsiyonel, normalizasyon için) · deneyim · hedef beceri · haftalık sıklık · **bilek/omuz/bel ağrısı var mı** · duvar+güvenli zemin erişimi · cihaz.
4. **Ağrı dalı:** ağrı bildirilirse → tıbbi değerlendirme sunmadığımız açıkça söylenir, ilgili dallar kilitlenir (motor zorlaması, G4 §3.2), yalnız hazırlık düğümleri açılır.
5. **Kamera izni** — gerekçe metni: *görüntü cihazdan çıkmaz, kayıt varsayılan KAPALI.*

### 3.2 Kalibrasyon sihirbazı (analiz ÖNKOŞULU — geçmeden analiz yok)
Kontroller (plan §5.2): tek kişi · baş+eller+ayaklar kadrajda · kamera yüksekliği · mesafe · ışık · zemin uygunluğu · arka alan boş · duvar kullanılacaksa duvar kadrajda.
**D1 eklentisi (yeni):** kalibrasyon sırasında kullanıcı **dik** durur → sistem *nötr duruş referansını* ve **yönelim temel çizgisini** kaydeder. Bu, yönelim-farkında çıkarımın (ADR-001) başlangıç durumudur; ters-duruşu sıfırdan keşfetmek zorunda kalmayız.
Çıktı: `CalibrationProfile` (kamera geometrisi + nötr duruş + vücut oranları + ışık notu).

### 3.3 Başlangıç değerlendirmesi (assessment)
Plan §5.3 bataryası: omuz fleksiyon · bilek fonksiyonel · hollow hold · plank · duvar handstand girişi · crow tutuş · tek ayak denge.
- Model varyantı: **`heavy`** (tek deneme, fps toleranslı — katalog §1). ⚠️ Eşikler `full`den DEVRALINMAZ (G-008).
- **Tıbbi ölçüm olarak sunulmaz** — yalnız uygulama-içi başlangıç seviyesi.
- Çıktı: skill-graph'ta açık başlangıç düğümleri + paywall'ın önündeki ilk değer anı (ADR-006).

### 3.4 Beceri oturumu (çekirdek döngü)
```
güvenlik hatırlatması → kısa hazırlık → hareketin görsel anlatımı
→ 1. deneme → otomatik analiz → TEK ana hata → düzeltici drill
→ yeniden deneme → deneme karşılaştırması → seans özeti
```
- Kullanıcı **ekranı görmez** (baş aşağı) → akış **sesle** yürür; ekran ikincil.
- Deneme sonunda: skor bileşenleri + tek düzeltme + "analiz güveni" göstergesi.
- **Analiz edilemeyen deneme:** "Couldn't analyse that one" + neden (kadraj/ışık/çok kişi/kamera hareketi) + düzeltme önerisi. **İlerleme düşmez** (G4 §2).

### 3.5 Progresyon
Kilit açma yalnız `handstand.v1.json` kriterleriyle; her açma **gerekçeli** gösterilir (hangi kriter, gereken, gözlenen). Ders izlemek açma sağlamaz.

## 4. Analiz hattı (pipeline) — D1 yansıması

```
Kamera karesi (native: CameraX / AVCaptureVideoDataOutput)
  → ORIENTATION ESTIMATOR         ← beceri durumu + histerezis (ADR-001)
  → çıkarım (düz | 180° döndürülmüş) — MediaPipe Tasks, native
  → landmark'lar orijinal kadraja geri döndürülür
  → STRUCTURAL PLAUSIBILITY CHECK ← faz-eksen · kemik uzunluğu · fiziksel imkânsızlık (ADR-002)
  → güven kapısı (taraf-agnostik: görünen zincir — ADR-003)
  → temporal smoothing
  → vücut-oranı normalizasyonu (kalibrasyon referansına)
  → beceri durum makinesi (§5)
  → kural motoru (versiyonlu config)
  → skor + tek-hata önceliklendirme + cooldown
  → sesli/görsel geri bildirim   → yerel seans kaydı
```
**Kanal diyeti (katalog §2):** 30fps ham landmark Dart'a AKMAZ. Dart'a: durum geçişleri + skorlar + ~10-15fps desimasyonlu overlay. Tam döngü native'de döner.
**Gerçek-zamanlı LLM YOK** (plan §6.1) — zincir tamamen deterministik ve loglanabilir.

## 5. Inversion durum makinesi (spesifikasyon)

| Durum | Giriş koşulu | Beklenen yönelim | Notlar |
|---|---|---|---|
| `IDLE` | oturum açık, deneme yok | UPRIGHT | — |
| `SETUP` | kalibrasyon akışı | UPRIGHT | analiz kapalı |
| `READY` | kalibrasyon geçti | UPRIGHT | "go when you're ready" |
| `PREPARING` | kullanıcı başlangıç pozunda | UPRIGHT | alan/zemin son kontrol |
| `ENTRY` | gövde ekseni dönmeye başladı | **AMBIGUOUS → çift-geçiş** | ⚠️ tespit kaybı beklenir (G-006); metrik best-effort |
| `INVERTED_UNSTABLE` | eksen ters, hat oturmadı | INVERTED | henüz tutuş sayılmaz |
| `HOLDING` | eksen ters + hat kararlı + yapısal denetim geçti | INVERTED | **skorlanan tek faz** |
| `BALANCE_LOST` | hat sapması eşik üstü / hızlı değişim | INVERTED | denge kaybı yönü kaba sınıf |
| `EXITING` | eksen dikleşiyor | AMBIGUOUS → çift-geçiş | çıkış kontrolü best-effort |
| `COMPLETED` | dik + hareket durdu | UPRIGHT | deneme kaydı yazılır |
| `ABORTED` | kullanıcı iptal / güvenlik olayı | — | `SafetyEvent` |
| `UNANALYZABLE` | güven/yapısal denetim kalıcı ihlal | — | hüküm YOK, ilerleme etkilenmez |

**Yönelim histerezisi:** durum değişimi tek kareyle tetiklenmez (N kare üst üste tutarlılık). Amaç: gürültünün çıkarım yönelimini oynatmasını engellemek.

## 6. Skorlama (plan §8 + D1 kısıtı)

Tek genel skor **yoktur** — yanıltıcıdır. Ayrı gösterilir: `Alignment` · `Control` · `Hold` · `Entry (best-effort)` · `Exit (best-effort)` · `Consistency` · **`Analysis confidence`**.
Yasak çıktılar: "profesyonel seviye", "güvenli", "sakatlanmazsın", tork/kas-aktivasyon iddiası, tıbbi yorum.

## 7. Geri bildirim motoru

**Aynı anda EN FAZLA BİR düzeltme.** Öncelik (plan §9): güvenlik > hareketi imkânsızlaştıran > denge > büyük hiza > küçük form > optimizasyon.
Cooldown: aynı uyarı, tanımlı süre geçmeden tekrarlanmaz. Cue dili baş-aşağı bağlama göre (ör. *"Shift the pressure into your fingertips"*), İngilizce, içerik paketinde.
**Düşük güvende cue YOK** — sessiz kalmak, yanlış söylemekten üstündür.

## 8. Veri modeli (plan §11 + D1 alanları)

`UserProfile` · `DeviceProfile` · `CalibrationProfile` · `Skill` · `SkillProgression` · `Lesson` · `Drill` · `Attempt` · `AttemptMetric` · `DetectedIssue` · `FeedbackEvent` · `Session` · `SafetyEvent` · `PoseSummary`

**Her `Attempt` kaydına zorunlu (ADR-005):** `modelVariant` · `modelVersion` (+SHA) · `ruleSetVersion` · `packVersion` · **`orientationStrategy`** (düz/döndürülmüş/çift-geçiş) · `analysisConfidence` · `structuralCheckOutcome`.
Gerekçe: eşik/model değişince eski kayıtlar yeniden yorumlanabilir kalmalı; aksi halde "gelişme" iddiası model değişiminin gürültüsü olabilir (00-AILE-MIMARISI §7).

**Ham video varsayılan KAYDEDİLMEZ.** Açık izinle performans videosu yerelde saklanabilir; bulut yok.

## 9. Gizlilik & güvenlik

- Cihaz-üstü işleme · yüz tanıma yok · ham video çıkmaz üçlüsü her beyanda açık (00-AILE-MIMARISI §5).
- Güvenlik üstünlüğü: alan/zemin kontrolü · duvar-önce progresyon · ağrı-durdurma · ileri beceri kilidi · headstand boyun-yükü uyarısı + açık onay. **Hiçbir faz bunları kırpamaz.**

## 10. Performans hedefleri (ölçülecek, taahhüt DEĞİL)

| Hedef | Değer | Not |
|---|---|---|
| Analiz fps | ≥20, tercih 24-30 | `full` canlı |
| Görsel geri bildirim gecikmesi | <150 ms | |
| Sesli karar gecikmesi | <500 ms | katalog §5 bütçesi |
| **Çift-geçiş maliyeti** | **ÖLÇÜLECEK** | yalnız `ENTRY`/`EXITING` penceresinde; G5 benchmark |
| Isı/pil | kademeli düşürme (çözünürlük→fps→varyant) | katalog §2 |

## 11. V1 kabul kriterleri (plan §16 + D1 eklentileri)

Mevcut liste korunur, **üç madde eklenir:**
- [ ] Ters-duruşta **eksen terslemesi sıfır** — fixture-replay testli (G-002/G-003 kanıtı, gerçek cihazda)
- [ ] Yapısal denetim ihlalinde **hüküm üretilmediği** testli
- [ ] Kick-up/çıkış metriklerinin **hiçbir açma kriterinde kullanılmadığı** betikle doğrulanmış (G-006 nöbetçisi)

## 12. Açık kararlar (kurucu)

1. Fiyat/paywall nihai (koridor katalog §8; öneri G9'da) — **kurucu**
2. İzinli video kaydı V1'de olsun mu? (öneri: **EVET, varsayılan kapalı** — ilerleme hissi + build-in-public malzemesi; gizlilik denetimi G8)
3. Assessment `heavy` maliyeti kabul edilebilir mi (G5 ölçümünden sonra)
4. Store adı `Gravita: Skills & Strength` sabit mi (ASC 6794714365'te kayıtlı)
