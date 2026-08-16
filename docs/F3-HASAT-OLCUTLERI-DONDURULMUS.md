# F3 Faz-0 — Hasat Uygunluk Ölçütleri, DONDURULMUŞ

> **Bu dosya, harvest turu-1'in HİÇBİR aday hareketinin video/transkript içeriğine
> BAKILMADAN yazıldı.** Yazarı (Gravita hattı, 2026-08-16) bu ölçütleri yazana kadar
> yalnız ŞUNLARI okudu: `tools/harvest_queue.py`, `tools/validate_reference_model.py`,
> `tools/sync_provenance.py`, `tools/promote_library.py`, `tools/build_replay_fixture.py`,
> `tools/reclassify_eligibility.py`, `content/schema/movement.schema.json`,
> `content/harvest/reference.push_up.json` / `reference.bodyweight_squat.json` (yalnız
> ALAN ADLARI/SAYILAR — video kimlikleri/transkript metni değil), ve `docs/gates/`
> altındaki ZATEN TAMAMLANMIŞ push_up/bodyweight_squat gate raporları. **6-10 yeni aday
> hareketin (bkz. §7) hiçbir video/transkriptine bakılmadı.**
>
> **Neden bu sıra önemli (D11, motion-core `YAYIN-YOLU-00-ORKESTRATOR.md`):**
>
> > *"Taban kuralları GEVŞETİLMEZ (≥3 bağımsız eğitmen, eşikler aday görülmeden).
> > Hasat edilemeyen kalem dürüst-kilitli kalır ve V1 bunu blokaj saymaz."*
>
> Bu, hasadın dürüstlüğünün karara bağlandığı TEK andır — bir kez aday görüldükten sonra
> "ölçütü adaya göre ayarlama" isteği artık ölçülemez hâle gelir. Bu dosya COMMIT'lendiği
> anda DONDU: bundan sonraki hiçbir değişiklik, "aday görüldükten sonra mı değişti"
> sorusunun cevabını git geçmişinden gizleyemez.

## 1 · ≥3 Bağımsız Eğitmen Kuralı — tam tanım

**Taban: her hareket için EN AZ 3 bağımsız eğitmen, referans inşasına GERÇEKTEN
katkı vermiş olmalı.** Bu sayı `content/schema/movement.schema.json:166`,
`docs/gravita-roadmap.md:106`, `docs/W0-BILGI-MIMARISI.md:89` ve ikisi de zaten canlı
olan `reference.push_up.json`/`reference.bodyweight_squat.json`'ın kendi
`gates.minSources: 3` alanında ZATEN kurulu — burada İCAT EDİLMİYOR, aktarılıyor.

**Sayım birimi EĞİTMEN'dir, video DEĞİL** (`tools/harvest_queue.py:4-6`'nın kendi
gerekçesi): *"Bir kanaldan on video almak 'on kaynak' değildir: eğitmenler-arası varyans
toleransın kendisi olduğu için aynı kişinin tekrarları o varyansı ÜRETMEZ, yalnız hacim
şişirir."* Bir eğitmenden en fazla 3 video havuzlanır (`VIDEOS_PER_INSTRUCTOR = 3`) ve
bunların hepsi TEK eğitmen birimi sayılır.

**⚠️ Ham sayı YETMEZ — her eğitmen KENDİ başına yeterlilik barını geçmeli.** Ölçülmüş
emsal (`docs/gates/M-F-38-PILOT-RAPORU.md:132`): push_up pilotunda 10 HAM aday eğitmen
vardı, yalnız 2'si kendi başına ≥3 temiz/kimlik-geçişli tekrar üretti — kapı **10'a
rağmen KAPALI kaldı**. Yani "3 kanal bulundu" yeterlilik iddiası TAŞIMAZ; her kanalın
KENDİSİ ≥3 temiz, kimlik-kapısından geçmiş tekrar üretmiş olmalı ki o kanal "eğitmen"
sayılsın.

**Keşif hedefi (arama durma noktası), yeterlilik iddiası DEĞİL** —
`tools/harvest_queue.py:182`'nin kendi disiplini: `hedef_eğitmen = ceil(5 / verim_oranı)`.
Bilinmeyen (ilk kez hasat edilen) bir hareket için varsayılan verim oranı **0.20**
(`DEFAULT_YIELD_RATE`, `tools/harvest_queue.py:147`) — yani yaklaşık **25 aday eğitmen**
aranacak ki ≥5'i (≥3 taban + tampon) gerçekten yeterlilik barını geçsin. Bu sayı bir
TAVAN değil BAŞLANGIÇ noktasıdır; gerçek verim ölçüldükçe ayarlanır (aşağıda §5).

## 2 · Uygunluk Tanımı — bir ADAYIN (video/eğitmen) geçmesi gereken katmanlar

Sıra önemli; her katman bir öncekini GEÇMİŞ adayları filtreler (`tools/harvest_queue.py`
→ triyaj profili → kimlik/yapısal kapı → `reclassify_eligibility.py` → insan/koordinatör
istisna kararı → referans inşası):

1. **Süre penceresi:** 90–1800 saniye (`MIN_DURATION_S`/`MAX_DURATION_S`,
   `tools/harvest_queue.py:92-93`). Kısa: faz içeriği yok. Uzun: derleme/vlog riski.
2. **Konu alaka filtresi:** başlık/açıklama düzeyinde require/reject anahtar kelime
   taraması (movement-özel, `harvest_queue.py:60-90` deseni). Ölçülmüş bulgu
   (`docs/G3-HASAT-PILOTU-RAPORU.md`, "Bulgu H-1"): filtresiz aramada adayların
   **3/5'i** yanlış varyanttı (örn. "push-up" aramasında handstand push-up/Hindu
   push-up/mobilite rutini çıkmıştı) — bu katman İSTEĞE BAĞLI değil.
3. **Triyaj eşikleri** (§4'te tam liste) — gerçek kabul kapısı `min_usable_window_s`
   (≥5s sürekli kullanılabilir pencere, ≈2 tekrar); diğer triyaj alanları (keskinlik,
   tam-gövde oranı) ÜCÜZ ÖN-FİLTRE, asıl karar değil (ölçüldü, `triage-profile.gravita.
   v1.json`'ın kendi notları).
4. **Hareket-ÖZEL yapısal/kimlik kapısı** — bu, HER YENİ HAREKET İÇİN AYRI TASARLANMASI
   gereken tek katman (§6). push_up'ta gövde-dikey açısı ≥60°; squat'ta kalça-diz Pearson
   korelasyonu ≥0.2. Amaç aynı: *"görüntüde bir vücut var" ile "hareket GERÇEKTEN
   yapılıyor"u ayırmak* — hiçbir yeni hareket bu katman TASARLANMADAN hasat turuna
   giremez.
5. **İkinci-kişi/pasif-icra taraması** — bkz. §6, AÇIK RİSK olarak işaretli.
6. **Varyant tutarlılığı** — aynı hareket adı altında FARKLI bir tekniğin (örn. yüklü vs
   yüksüz versiyon) karışmadığının İNSAN GÖZÜYLE doğrulanması (§3).
7. **Referans inşası eşikleri** — `minTakes: 3`, `minSources: 3`,
   `clusterToleranceDeg: 14.0`, `minVisibleShare: 0.6` (§4).

## 3 · Dışlama (Exclusion) Kriterleri — adıyla

- **Varyant uyuşmazlığı** (`decisions.<hareket>.json`'ın kurulu deseni): yanlış teknik
  varyantı (örn. ağırlıklı versiyon yüksüz havuzuna) karıştı. **Metin taramalı zayıf
  işaret TEK BAŞINA otomatik ret ÜRETMEZ** — her aday, ret kararından önce İNSAN
  GÖZÜYLE kare doğrulaması gerektirir (ölçülmüş emsal: `docs/gates/G-089-...md`, bir
  ağırlıklı-squat klibi düzeltme öncesi referansın DTW hizalama medoidi seçilmişti —
  gövde-eğim ölçümünü 8,2° kaydırmıştı). Dışlanan tekrarlar SİLİNMEZ, ETİKETLENİR
  (gelecekte o varyantın kendi referansı için malzeme kalır).
- **Yanlış hedef/alaka dışı içerik** — §2 madde 2'nin filtrelediği sınıf.
- **Fiziksel olarak imkânsız ölçüm okuması** — `value_range` sınırları dışı (izleme
  artefaktı, referansa hiç girmez).
- **Ayna yanlış-pozitifi** — salon aynasındaki yansıma, görünürlük-paritesi sezgisiyle
  gerçek ikinci kişiden AYIRT EDİLEMEZ; yalnız görsel/geometrik (sol-sağ ters çevirme)
  doğrulamayla çözülür (`docs/gates/G-087-...md`).
- **Kapatılmış, YENİDEN DENENMEYECEK hipotezler** (adıyla, tekrar tekrar sınanmasın
  diye): küme toleransını 14°'den 28-30°'ye genişletmek DENENDİ ve ölçülerek etkisiz
  bulundu (`docs/gates/G-106-...md:73-81`) — düşük verimin çözümü DEĞİL. Kamera açısı/
  kısalma açıklaması da aykırı-değer oranı için REDDEDİLDİ (aynı belge, Pearson +0,34,
  ters işaret).

## 4 · Sayısal Eşikler — tek tablo, kaynağıyla

| Eşik | Değer | Kaynak (zaten kurulu) |
|---|---|---|
| Minimum bağımsız eğitmen | **≥3** | `movement.schema.json:166`, ikisi de canlı referansın `gates.minSources` |
| Referans inşası `minTakes` | **3** | `reference.push_up.json`/`reference.bodyweight_squat.json` `gates.minTakes` |
| Eğitmen başına havuzlanan video | **3** (tavan) | `harvest_queue.py:156` |
| Video süre penceresi | **90–1800 sn** | `harvest_queue.py:92-93` |
| Sorgu başına sonuç | **4** | `harvest_queue.py:94` |
| Varsayılan verim oranı (yeni hareket) | **0,20** | `harvest_queue.py:147` |
| Keşif hedefi formülü | **⌈5 / verim⌉** eğitmen | `harvest_queue.py:159,182` |
| Küme toleransı | **14,0°** | canlı referansların `gates.clusterToleranceDeg`; 28-30° DENENDİ+REDDEDİLDİ |
| Min görünürlük payı | **0,6** | canlı referansların `gates.minVisibleShare` |
| Min kullanılabilir sürekli pencere | **5,0 sn** (≈2 tekrar) | `triage-profile.gravita.v1.json` `min_usable_window_s` — ASIL kabul kapısı |
| Min video süresi (triyaj) | **90,0 sn** | aynı dosya `min_duration_s` |
| Min tam-gövde-kare oranı | **0,03** | aynı dosya — UCUZ ön-filtre, asıl karar değil |
| Min üst-gövde oranı | **0 (devre dışı)** | aynı dosya — Gravita için içerikle KORELE OLMADIĞI ölçüldü (G-030), kasıtlı sıfır |
| v2 min postür oranı | **0,25, AÇIKÇA GEÇİCİ** | `triage-profile.gravita.v2.json:12,19` — hayatta kalan aday sayısını MAKSİMİZE etmek için AYARLANMAYACAK, adıyla yazılı |
| Model kimliği (yeni referanslar) | `pose_landmarker_full/float16/1`, `status: RECORDED` | `validate_reference_model.py:29` — push_up/squat'ın UNRECORDED muafiyeti YENİ hareketlere GEÇMEZ |

## 5 · Gevşetme Koşulları — D11'in taban maddesi

**Taban GEVŞEMEZ:** ≥3 bağımsız eğitmen · `minTakes:3`/`minSources:3` · küme toleransı
14° · kimlik/yapısal kapı (movement-özel de olsa, HİÇBİR hareket bu kapı OLMADAN
canlıya çıkmaz). Bu üçü D11'in kendi lafzıyla sabittir; bir aday havuzu yetersiz
çıkarsa çözüm eşiği DÜŞÜRMEK değildir.

**Gevşeyebilecek olan yalnız KEŞİF STRATEJİSİdir**, eşikler değil:
- Verim oranı (0,20) GERÇEK ölçümle güncellenebilir (movement başına ayrı ölçülür,
  push_up'ın kendi 0,18'i emsal).
- Arama sorgu havuzu/anahtar kelimeleri genişletilebilir.
- Keşif hedefi (⌈5/verim⌉) yükseltilebilir — bu bir eşik DEĞİL, ne kadar ARANACAĞI.

**Hasat edilemeyen kalem DÜRÜST-KİLİTLİ kalır, V1'i BLOKE ETMEZ** (D11'in ikinci
maddesi, birebir): bir hareket ≥3 eğitmen barını geçemezse, o hareket bu turda
`content/catalog/`de `pending_harvest`/kilitli kalır, "Neden yok?" sayfasında adıyla
görünür — ürün buna rağmen yayınlanır, o TEK hareket beklenmez.

## 6 · Açık Riskler — burada KARARA BAĞLANMADI, adıyla bırakıldı

1. **⛔ Lisans/telif politikası YOK.** Araştırma dört kaynakta (`docs/`, `tools/`,
   motion-core defter) taradı — YouTube kaynak videoları için telif/lisans/ticari-
   içerik kuralı HİÇBİR YERDE yazılı değil (`docs/G3-CEKIM-LISTESI.md`'deki onam
   protokolü FARKLI bir hat: kurucunun/gönüllülerin KENDİ çekimleri, YouTube eğitmen
   hasadı değil). Bu "lisans riski" — Gravita'nın kendi `CLAUDE.md`sinde kurucuya giden
   BEŞ kalemden biri. **Kendiliğimden bir politika İCAT ETMİYORUM; orkestratöre/kurucuya
   iletiyorum, harvest turu-1 başlamadan önce netleşmeli.**
2. **⛔ İkinci-kişi/pasif-icra otomatik güvencesi EKSİK.** `passiveExecutionPossible`
   şeması push_up/squat için `false` (yapısal olarak aktif, otomatik istisna) —
   ama bu istisna diğer tüm hareketler için BLOKE (gerekçe: tek-kişilik poz modeli
   ikinci bir iskeleti tespit EDEMEZ; `docs/gates/G-087-...md` gerçek bir örnek
   buldu — bir eğitmen bir çubuğu doğrudan bir müşterinin omurgasına bastırıyordu).
   **Panzehir bu turda: her hareket-özel yapısal kapı tasarımına (§2 madde 4) EK
   olarak, referansa giren HER tekrar penceresi ikinci-kişi/temas açısından İNSAN
   GÖZÜYLE taranacak** (otomatik tespit gelene kadar). Bu bir gevşetme değil —
   otomasyonun eksik olduğu yerde insan doğrulamasının ZORUNLU olduğunun adıyla
   yazılmasıdır.
3. **📌 "Daha fazla eğitmen = daha iyi kümelenme" VARSAYIMI DEĞİL.** Squat'ın kendi
   ölçümü (`docs/gates/G-106-...md`): 12 kaynak/227 tekrar havuzdayken bile %89
   dışlanıyor — sebep hacim eksikliği değil, olası ÇOK-MODLULUK (meşru duruş/derinlik/
   gövde-eğimi varyantlarının TEK havuzda karışması). Yeni hareketlerden BENZER
   varyant-zenginliği taşıyanlar (örn. lunge: ileri/geri/yürüyen — hepsi meşru ama
   FARKLI) için triyaj TASARIMINDA bu ayrımı ÖNCEDEN düşünmek gerekir; "yetersiz
   yakınsama = daha çok hasat et" refleksi ÖLÇÜLMEDEN uygulanmayacak.

## 7 · Aday Hareket Adları (İSİM listesi — hiçbir görüntüye bakılmadı)

Yol haritasının kendi önerisi (`YAYIN-YOLU-GRAVITA.md` F3): squat/push ailesine komşu,
yüksek hacimli eğitmen içeriği beklenen adaylar — **lunge · glute_bridge · plank ·
pull_up · dip · row** (+ 29 A′ kalemin geri kalanından tamamlayıcı 0-4 tane, hasat
turu-1 sırasında ölçülecek). Bu SADECE hareket TÜRÜ isimleridir; hiçbirinin video/
eğitmen adayı henüz aranmadı/görülmedi. Kesin seçim, her adayın §2 madde 4'teki
kendi yapısal kapısı TASARLANABİLİR mi sorusuna göre hasat turu-1'in kendisinde
netleşecek.

---

**Bu dosya DONDU.** Bundan sonraki her değişiklik ayrı bir commit'te, GEREKÇESİYLE
yapılmalı — "aday görüldü, eşik uymadı" bir gerekçe DEĞİLDİR (D11).
