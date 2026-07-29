# Gravita — UI-BRIEF (claude.ai/design oturumu girdisi)

**Tarih:** 2026-07-29 · **Statü:** tasarım-girdisi (KOD DEĞİL) · **Otorite:** `docs/PRD.md` + `docs/W0-BILGI-MIMARISI.md` + `docs/GRAVITA-BLUEPRINT.md`
**Bu belge hiçbir yeni ürün kararı ÜRETMEZ** — var olan bağlayıcı kararları tasarımcının kullanabileceği biçime çevirir. Her madde bir kaynağa dayanır; dayanağı olmayan hiçbir ekran/durum uydurulmadı.

## 0. Dil — ✅ KARAR VERİLDİ (M-F-122 hüküm 2)

Gece paketi "TR+EN" istemişti; PRD §7 ise ürün dilini V1 için `en` olarak bağlıyordu. **Koordinatör hükmü: V1 = EN-ONLY KALIR** (PRD §7 bağlaması onaylandı). Gerekçe: global-first launch + sesli-koç yükü (TR = 61+ anahtar × ses satırları); i18n altyapısı yerinde durduğu için TR bir **v1.x İÇERİK işi**, mimari iş değil. Kurucu özetine görünür yazıldı; itiraz gelirse döner.

Bu yüzden:
- **Bu brief Türkçe** (iç doküman konvansiyonu),
- **içindeki tüm kullanıcı-görür metin İngilizce** (ürün dili),
- tasarım oturumu **tek dil** varsayabilir; ama metin uzunluğu esnekliği korunmalı (TR ~%20-30 daha uzun) ki v1.x çeviri turu yeniden-tasarım gerektirmesin.

## 1. Ürün tek cümlede (tasarımın çözmesi gereken şey)

> Telefonu sabitle, seçtiğin beceriyi dene; sistem hizanı cihaz üstünde analiz etsin, **tek** en önemli hatanı söylesin, ölçülebilir kriterle sonraki progresyonu açsın.

**Gravita bir fitness uygulaması DEĞİL.** Değer birimi "antrenman tamamlamak" değil **ölçülebilir beceri kazanımı**. Kuzey yıldızı: ilk serbest handstand'e ulaşan kullanıcı oranı + süresi.

**Tasarım için asıl sonuç:** ürünün yıldız ekranı, kullanıcının **BAKAMADIĞI** ekran (§5). Bu, alışıldık fitness-app tasarımını tersine çevirir — görsel şölen değil, sesin etrafında kurulmuş minimal bir yüzey.

## 2. Marka tonu

| Boyut | Karar | Kaynak |
|---|---|---|
| Karakter | Sakin, ölçen, iddia etmeyen bir antrenör. Tezahürat yok, "beast mode" yok. | PRD §6-7 |
| Dürüstlük | Ne ölçtüğünü VE ne ölçmediğini söyler. Emin olmadığında **susar**. | PRD §7, W0 §3 |
| Otorite kaynağı | Sayı ve kriter — motivasyon sloganı değil. Her kilit açma "hangi kriter / gereken / gözlenen" gösterir. | PRD §3.5 |
| Yasak dil | "profesyonel seviye" · "güvenli" · "sakatlanmazsın" · tork/kas-aktivasyon iddiası · her türlü tıbbi yorum | PRD §6 |
| Güvenlik dili | Kırpılamaz, atlanabilir öneri gibi görünmez — **kapı gibi görünür**. | W0 §5, PRD §9 |

Görsel yön: yerçekimi/hiza teması (isim: Gravita). Ağır, dengeli, merkez-eksen duygusu. Sıcak-abartılı spor paleti DEĞİL.

## 3. Ekran envanteri

Alt-tab (W0 §6): **Home · Library · Progress · Profile**

### 3.1 Onboarding (ilk açılış · 5 adım — PRD §3.1)

| # | Ekran | İçerik | Durumlar |
|---|---|---|---|
| O1 | **Value** | Ne YAPTIĞIMIZ + ne YAPMADIĞIMIZ yan yana. "Not medical. Not a substitute for a coach. We cannot stop you from falling." | tek durum |
| O2 | **Safety consent** | `safetyCopy.generalDisclaimer` + alan/zemin kuralı. **Açık onay olmadan devam YOK** (dismiss edilemez) | onay-bekliyor · onaylandı |
| O3 | **Profile** | yaş aralığı · boy/kilo (opsiyonel) · deneyim · hedef beceri · haftalık sıklık · **bilek/omuz/bel ağrısı** · duvar+zemin erişimi · cihaz | boş · kısmi · geçerli |
| O4 | **Pain branch** (koşullu) | Ağrı bildirildiyse: tıbbi değerlendirme sunmadığımız açıkça söylenir; ilgili dallar KİLİTLENİR, yalnız hazırlık düğümleri açılır | yalnız ağrı bildirildiyse görünür |
| O5 | **Camera permission** | Gerekçe metni: *"Video never leaves your device. Recording is off by default."* | isteniyor · **verildi** · **REDDEDİLDİ** (→ §6) |

### 3.2 Calibration wizard (analiz ÖNKOŞULU — PRD §3.2)

Geçmeden analiz YOK. Kontroller: tek kişi · baş+eller+ayaklar kadrajda · kamera yüksekliği · mesafe · ışık · zemin · arka alan boş · (duvar kullanılacaksa) duvar kadrajda.
**D1 eklentisi:** kullanıcı **dik** durur → nötr duruş + yönelim temel çizgisi kaydedilir.

Durumlar: `checking` (canlı kamera + hangi kontrolün kaldığı) · `failing` (hangi kontrol, nasıl düzeltilir — tek tek) · `passed` → `CalibrationProfile`.
⚠️ Bu ekran **canlı kamera** gösterir ama **hüküm vermez**. Tasarım "analiz başladı" izlenimi vermemeli.

### 3.3 Initial assessment (PRD §3.3)

Batarya: omuz fleksiyon · bilek fonksiyonel · hollow hold · plank · duvar handstand girişi · crow tutuş · tek ayak denge.
- **Tıbbi ölçüm olarak sunulmaz** — "uygulama-içi başlangıç seviyesi".
- Çıktı: skill-graph'ta açık başlangıç düğümleri + **paywall öncesi ilk değer anı** (ADR-006).

Durumlar: giriş · sıradaki test · test-atlandı · sonuç özeti · **analiz edilemedi** (§6).

### 3.4 Home

Bugünkü plan · devam eden kurs (1 dokunuş) · hızlı başlat (son hareket, 1 dokunuş) · son seans özeti.
Durumlar: **ilk-kullanım** (kurs yok → assessment'a yönlendirir) · normal · yalnız-geçmiş (aktif kurs yok).

### 3.5 Library (W0 §1)

`Library → 9 hareket-ailesi` (İtiş · Çekiş · Bacak · Core · Omuz · Barbell · DB-KB · Plyo · Taşıma) · `5 beceri ağacı` (Handstand · Planche · Lever · Pistol · L-sit) · **"Why isn't X here?"** (tek sayfa, `exclusions.json`'dan üretilir).

**Arama kritik kısıt (W0 §4):** kapsam-dışı terim **boş dönmez** — "leg press" `exclusions.json`'ın ilgili bölümüne düşer. Dar-app algısı yasağı. Filtreler: seviye · ekipman · aile · süre · sınıf (A/B/D).
Açılmamış dalga içerikleri **"coming soon"**; **sahte/boş kurs ASLA listelenmez**.

Durumlar: boş-arama · sonuç-yok→exclusions'a düşme · filtreli · yükleniyor.

### 3.6 Movement page (120-180 sayfa — W0 §2)

9 zorunlu blok, **hepsi veri-kaynaklı, elle serbest metin YOK**: başlık+aile+seviye+ekipman · **nasıl yapılır (iskelet-avatar, referans dizisinden)** · form hataları (`formErrors[]`) · ⭐ **dürüstlük kutusu (ÜRETİLİR)** · sınıf rozeti (A/B/D) · kurslar · kişisel rep/form trendi · **güvenlik uyarısı (kırpılamaz)** · beceri ağacı bağı.

⭐ **Dürüstlük kutusu tasarımın en hassas bileşeni (W0 §3):** "neler ölçülür / neler ölçülmez" kutusu **hiçbir zaman elle yazılmaz**, `measurementContract`'ten derlenir. Tasarım bunu ikinci-sınıf bir dipnot gibi göstermemeli — ürünün karakteri bu. Ama **uzunluğu değişkendir** (hareket başına farklı sayıda madde) → esnek yükseklik şart.

Durumlar: referans-var (iskelet-avatar oynar) · **referans-YOK** (`provenance.status: pending_harvest` → "how it's measured" bloğu dürüstçe eksik gösterilir, sahte avatar YOK) · trend-verisi-yok (ilk kullanım).

### 3.7 Course page

Ders listesi + hedef + süre + ön-koşul. Kilitli ders **isimli gerekçe** gösterir.
Durumlar: kilitli (gerekçeli) · açık · devam-eden · tamamlanmış.

### 3.8 ⭐ Live session (ürünün yıldızı — W0 §7, PRD §3.4)

**Telefon uzakta; kullanıcı çoğu harekette ekranı göremez, ters-duruşta HİÇ göremez → ses birincil, metin minimal.**

Ekranda **YALNIZ**: kamera · iskelet-avatar · **tek** düzeltme · rep/süre sayacı · **analiz-güveni göstergesi**.
Akış (sesle yürür): `güvenlik hatırlatması → kısa hazırlık → görsel anlatım → 1. deneme → analiz → TEK ana hata → düzeltici drill → yeniden deneme → karşılaştırma → seans özeti`

**Bağlayıcı kısıtlar (tasarım bunları ihlal edemez):**
- **Aynı anda EN FAZLA BİR düzeltme.** Öncelik: güvenlik > hareketi imkânsızlaştıran > denge > büyük hiza > küçük form > optimizasyon.
- **Düşük güvende cue YOK** — sessizlik, yanlış söylemekten üstün. Tasarım "boşluk" gibi görünen bu anı **kasıtlı** göstermeli (bozuk değil).
- Cooldown: aynı uyarı tanımlı süre geçmeden tekrarlanmaz.
- Cue dili baş-aşağı bağlama uygun (ör. *"Shift the pressure into your fingertips"*).

Durum makinesi ekranda kaba karşılığıyla görünür (PRD §5, 12 durum): `IDLE · SETUP · READY · PREPARING · ENTRY · INVERTED_UNSTABLE · HOLDING(skorlanan tek faz) · BALANCE_LOST · EXITING · COMPLETED · ABORTED · UNANALYZABLE`.

### 3.9 Attempt/session summary

Skor **bileşenleri ayrı** — **tek genel skor YOK** (PRD §6, yanıltıcı olduğu için kaldırıldı):
`Alignment · Control · Hold · Entry (best-effort) · Exit (best-effort) · Consistency · **Analysis confidence**`

⚠️ Tasarım bu 7 bileşeni tek bir yüzdeye/yıldıza **toplamamalı** — bu, ürünün açıkça reddettiği şey. `best-effort` etiketli ikisi görsel olarak da daha zayıf ağırlıkta durmalı (kapı değil, gösterim).

Durumlar: analiz-tamam · **analiz edilemedi** (§6) · kısmi (bazı bileşen ölçülemedi → o bileşen "not measured", 0 DEĞİL).

### 3.10 Progress (tab) + Skill tree (W0 §5)

Skill-tree, hareket kataloğundan ayrı bir görselleştirme ama aynı düğümleri gösterir.
- **Kilitli düğüm NEDEN kilitli gösterir**: kriter + gereken + gözlenen.
- **Aspirasyonel düğümler ROZETSİZ** (one-arm handstand, Manna, human flag — rehberli ama ödüllendirilmez).
- Duvar-önce/güvenlik kapıları **görsel olarak kapı gibi** (atlanabilir öneri gibi değil).
- Ders izlemek kilit AÇMAZ — yalnız ölçülen kriter açar.

### 3.11 Profile / Settings

Profil düzenleme · **camera & privacy** (ham video varsayılan kaydedilmez; açık izinle yerel kayıt) · ses/cue ayarları · dil (V1: yalnız `en`) · güvenlik onayı tekrar okuma · veri silme · yasal.

## 4. Akış diyagramı (metin)

```
İLK AÇILIŞ
O1 Value → O2 Safety consent ──(onay yok)──▶ [devam YOK, tekrar sor]
                 │ onay
                 ▼
           O3 Profile ──(ağrı bildirildi)──▶ O4 Pain branch ──▶ [ilgili dallar KİLİTLİ]
                 │                                                      │
                 ▼                                                      ▼
        O5 Camera permission ──(REDDEDİLDİ)──▶ [Library + Progress salt-okunur;
                 │ verildi                       analiz YOK; §6 izin-reddi durumu]
                 ▼
        Calibration wizard ──(fail)──▶ [hangi kontrol + nasıl düzeltilir] ──┐
                 │ passed                                                   │
                 ▼                                                     (yeniden dene)
        Initial assessment ──▶ Skill tree'de açık başlangıç düğümleri
                 │                        └──▶ ilk değer anı ──▶ [paywall: ADR-006]
                 ▼
               HOME

DÖNGÜ (her oturum)
HOME ──1 dokunuş──▶ aktif kurs ──▶ Course page ──▶ DERS/SEANS
HOME ──1 dokunuş──▶ hızlı başlat (son hareket) ──▶ DERS/SEANS
Library ──▶ aile ──▶ Movement page ──▶ Course ──▶ DERS/SEANS   (3 dokunuş, üst sınır)

DERS/SEANS AKIŞI
güvenlik hatırlatması → hazırlık → görsel anlatım
   → deneme (LIVE SESSION: ses birincil)
        ├─ analiz OK ──▶ TEK ana hata ──▶ düzeltici drill ──▶ yeniden deneme
        │                                                          │
        │                                    ┌─────────────────────┘
        │                                    ▼
        └─ UNANALYZABLE ──▶ "Couldn't analyse that one" + neden
                              (kadraj/ışık/çok kişi/kamera hareketi)
                              ⚠️ İLERLEME DÜŞMEZ, hüküm YOK
   → deneme karşılaştırması → SEANS ÖZETİ (7 ayrı bileşen)
        → kriter karşılandıysa ──▶ progresyon açılır (gerekçe gösterilir)
        → karşılanmadıysa ──▶ hangi kriter / gereken / gözlenen
```

## 5. Her ekranın zorunlu durumları (kontrol listesi)

Tasarım oturumunun **hepsini** üretmesi gerekenler:

| Durum | Nerede kritik | Kural |
|---|---|---|
| **Boş** | Home (ilk kullanım) · Progress (deneme yok) · Movement trend | Sahte veri/placeholder grafik YOK. "Henüz ölçüm yok" dürüst. |
| **Yükleniyor** | Library · Movement page · Calibration · analiz sonrası | Analiz gecikmesi bütçeli (<150ms görsel, <500ms sesli) — uzun spinner tasarımı gerekmez, ama analiz-sonrası kısa bir "measuring" hâli var. |
| **Hata** | Analiz · kamera · içerik yükleme | Neden + düzeltme önerisi ZORUNLU. "Something went wrong" tek başına yasak. |
| **İzin reddi** | Kamera (O5) | Uygulama ÖLMEZ: Library + Progress + Profile salt-okunur çalışır, analiz kapalı, tek net CTA ile izin tekrar istenir. |
| **Ölçülemedi** | Live session · Attempt summary | **En önemli özel durum:** hüküm YOK, ilerleme DÜŞMEZ. Bir "başarısızlık" gibi tasarlanmamalı — nötr bir "bunu ölçemedim" hâli. |
| **Düşük güven** | Live session | Cue YOK. Analiz-güveni göstergesi düşük. Bu **kasıtlı sessizlik** olarak okunmalı. |
| **Kilitli** | Course · Skill tree | Gerekçeli (kriter/gereken/gözlenen). Güvenlik kilidi kapı gibi, atlanabilir öneri gibi değil. |
| **Referans yok** | Movement page | `pending_harvest` → "nasıl yapılır" bloğu dürüstçe eksik. Sahte iskelet-avatar YOK. |
| **Kısmi ölçüm** | Attempt summary | Ölçülemeyen bileşen "not measured" — **0 veya boş çubuk DEĞİL**. |

## 6. Tasarımın ihlal ETMEMESİ gereken 8 ölçülmüş kısıt

Bunların hepsi ölçüme veya bağlayıcı karara dayanıyor; "daha güzel olur" gerekçesiyle değiştirilemez:

1. **Tek genel skor yok** — 7 bileşen ayrı (PRD §6).
2. **Aynı anda tek düzeltme** — öncelik sırası sabit (PRD §7).
3. **Düşük güvende cue yok** — sessizlik tasarlanmalı (G-003).
4. **Ölçülemedi ≠ başarısızlık** — ilerleme düşmez (G4 §2).
5. **Dürüstlük kutusu üretilir, yazılmaz** — esnek yükseklik (W0 §3).
6. **Güvenlik kapıları kırpılamaz/atlanamaz** (PRD §9).
7. **Aspirasyonel düğümler rozetsiz** (blueprint §8).
8. **Ses birincil, ekran ikincil** — canlı seansta ekran 5 öğeyle sınırlı (W0 §7).

## 7. Açık kalemler (tasarım oturumu ÖNCESİ kurucu kararı)

*(Dil kalemi KAPANDI — bkz. §0, M-F-122 hüküm 2.)*

1. **Fiyat/paywall nihai konumu** — ADR-006 "değerlendirme-kapılı" diyor, fiyat kurucuda (PRD §12.1).
2. **İzinli video kaydı V1'de olsun mu** (öneri: EVET, varsayılan kapalı) — UI'da kayıt kontrolü olacak mı belirler (PRD §12.2).
3. **Store adı** `Gravita: Skills & Strength` sabit mi (PRD §12.4) — store görselleri buna bağlı.

## 8. Kaynaklar

`docs/PRD.md` (akışlar, durum makinesi, skorlama, yasak dil) · `docs/W0-BILGI-MIMARISI.md` (IA, sayfa hiyerarşisi, dürüstlük kutusu, canlı ekran) · `docs/GRAVITA-BLUEPRINT.md` · `docs/G4-BECERI-GRAFI-TASARIMI.md` (kilit gerekçeleri) · `docs/ADR/001-006` · `docs/gates/G1-D1-RAPOR.md` (ölçülmüş kısıtlar) · `content/skill-graph/*.json` · `content/schema/movement-classes.json`
