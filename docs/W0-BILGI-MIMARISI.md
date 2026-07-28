# W0 — Bilgi Mimarisi (IA) Çatısı

**Tarih:** 2026-07-29 · **Faz:** W0 · **Otorite:** `GRAVITA-BLUEPRINT.md §3` + motion-core `30-URUN-BLUEPRINT-STANDARDI.md §2-3`
**Statü:** Oturum kararı (blueprint çerçevesinde; kurucuya soru yok — standart §4.6)

---

## 1. Sayfa hiyerarşisi

Standart §2'nin dört seviyesi Gravita'ya şöyle oturur:

```
Ana Sayfa  — bugünkü plan · devam eden kurs · hızlı başlat · son seans özeti
└── Kütüphane
    ├── Hareket-aile sayfaları (9):  İtiş · Çekiş · Bacak · Core · Omuz · Barbell · DB-KB · Plyo · Taşıma
    ├── Beceri Ağaçları (ayrı görsel skill-tree UI): Handstand · Planche · Lever · Pistol · L-sit
    └── "Neden yok?" (tek sayfa — content/catalog/exclusions.json'dan üretilir)
        └── HAREKET SAYFASI  (her hareket kendi sayfası — 120-180 adet)
            └── KURS SAYFASI (ders listesi + hedef + süre + ön-koşul)
                └── DERS/SEANS AKIŞI (öğret → dene → canlı analiz + sesli koç → özet → sonraki adım)
```

**Aile ≠ kas grubu.** Kullanıcı iki şekilde arar: "göğüs çalışmak istiyorum" (kas) ve "itiş hareketleri" (kalıp). Aile sayfası birincil navigasyon, kas grubu **filtre**dir (`muscleGroups` alanı zaten her harekette var). İki ayrı sayfa ağacı kurulmaz — ikinci ağaç bakım borcudur.

## 2. Hareket sayfası — zorunlu bloklar

Blueprint §3'ün her maddesi bir veri kaynağına bağlanır; **elle yazılan serbest metin yoktur**:

| Blok | Kaynak |
|---|---|
| Başlık + aile + seviye + ekipman | `name`, `family`, `level`, `equipment` |
| **Nasıl yapılır** — iskelet-avatar | Referans dizisi (katalog §6.4 T1); `provenance.referenceId` |
| **Form hataları** | `formErrors[]` — label + cue; kullanıcıya "neye dikkat edilir" listesi |
| **Dürüstlük kutusu** | ⭐ `measurementContract` + sınıf `userCopy` → **ÜRETİLİR** (§3) |
| Sınıf rozeti (A/B/D) | `class` → `movement-classes.json.userCopy.badge` |
| Kurslar / programlar | `courses[]` |
| Kişisel rep/form trendi | Yerel `Attempt` kayıtları (köken alanlarıyla — ADR-005/M-F-07) |
| Güvenlik uyarısı | `safety.warnings` — kırpılamaz |
| Beceri ağacı bağı | `skillGraphNode` (varsa) |

## 3. ⭐ Dürüstlük kutusu ÜRETİLİR, yazılmaz

**Karar:** "neler ölçülür / neler ölçülmez" kutusu hiçbir zaman elle yazılmaz; `measurementContract.measured` + `notMeasured` + sınıfın `userCopy`'sinden derlenir.

**Gerekçe:** 180 hareketin elle yazılmış metni, motorun gerçekte ölçtüğünden kaçınılmaz olarak ayrışır. Bu ayrışma sessizdir ve tam olarak LifeOS'un "Pro'ya paralı ama kırık Export" hatasının sınıfıdır. Üretilmiş kutuda drift **imkânsızdır**: motor bir metriği kapatırsa kutu aynı anda değişir.

**Sonuç:** bir metrik `measured`'dan çıkarılmadan UI'dan kaldırılamaz; nöbetçi betik (`tools/validate_catalog.py`) `measured` boşsa hata verir.

## 4. Arama davranışı (dar-app algısı yasağı)

- Kütüphane araması **kapsam-dışı terimleri de bulur**: "leg press" → sonuç boş dönmez, `exclusions.json`'daki ilgili bölüme düşer. Standart §2: kapsamın tamamı kullanıcıya baştan görünür.
- Henüz açılmamış dalga içerikleri "yakında" olarak listelenir; **sahte/boş kurs asla listelenmez**.
- Filtreler: seviye · ekipman · aile · süre · sınıf (A/B/D).

## 5. Beceri ağacı UI (Gravita-özel delta)

Skill-tree, hareket kataloğundan **ayrı** bir görselleştirmedir ama aynı düğümleri gösterir: `content/skill-graph/*.json` düğümleri ↔ `skillGraphNode` alanıyla katalog hareketlerine bağlanır.
- Kilitli düğüm, **neden kilitli** olduğunu gösterir (kriter + gereken + gözlenen — G4 tasarımı §4).
- **Aspirasyonel düğümler rozetsizdir** (blueprint §8): one-arm handstand, Manna, human flag rehberli ama ödüllendirilmez.
- Duvar-önce/güvenlik kapıları görsel olarak da kapı gibi görünür (atlanabilir bir öneri gibi değil).

## 6. 2-tık kuralı (standart §3) — Gravita yerleşimi

- Ana sayfa → aktif kurs: **1 dokunuş** (kart)
- Ana sayfa → hızlı başlat (son hareket): **1 dokunuş**
- Kütüphane → aile → hareket → seans: **3 dokunuş** (standart üst sınırı)
- Alt-tab: **Ana · Kütüphane · İlerleme · Profil**

## 7. Canlı seans ekranı (ürünün yıldızı)

Telefon uzakta ve kullanıcı çoğu harekette ekranı göremez (ters-duruşta hiç göremez) → **ses birincil, metin minimal**.
Ekranda yalnız: kamera + iskelet-avatar + tek düzeltme + rep/süre sayacı + analiz-güveni göstergesi.
**Düşük güvende cue YOK** — sessiz kalmak yanlış söylemekten üstündür (G-003).

## 8. W0 kapsamında ÜRETİLENLER

| Dosya | Ne |
|---|---|
| `content/schema/movement-classes.json` | A/B/C/D sınıf kuralları + iddia matrisi + dürüstlük kutusu sözleşmesi |
| `content/schema/movement.schema.json` | Hareket girdisi şeması (4 motor tipi) |
| `content/schema/metrics.json` | Ölçüm sözlüğü: birim + fiziksel aralık + gürültü bandı |
| `content/catalog/w1/*.json` | İlk 5 hareket (4 motor tipini de kanıtlıyor) |
| `content/catalog/exclusions.json` | "Neden yok?" sayfasının kaynağı |
| `tools/validate_catalog.py` | Nöbetçi betik — 9 değişmez, çıkış kodu CI'a bağlanabilir |
| bu dosya | IA çatısı |

## 9. Açık borçlar (DEFTER'e bağlı)

- Tüm eşik değerleri ve `noiseBand`'lar **provizyonel** — nihai değerler ≥3 eğitmen kaynağının varyansından türetilecek (katalog §6.0). G-014.
- `lumbar_flexion_proxy` derin fleksiyonda landmark jitter riski taşıyor → `pendingVerification` (blueprint §4.7).
- Sınıf B hareketleri henüz katalogda yok (W3) — B sınıfı denetimi (V5) ilk bench girdisiyle gerçek testine girecek.
