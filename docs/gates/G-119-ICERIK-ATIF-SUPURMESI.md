# G-119 — İçerik-atıf süpürmesi: 12 sabotaj, 4 kaçak, 4'ü de kapatıldı

**Yetki:** koordinatör M-F-251 (M-F-248 aile sınıfı: *"içerik-atıfı bir
VAATTİR"*) · Choreia'nın 13-kırık-atıf vakası emsal.
**Sonuç:** 4 gerçek kırık-atıf sınıfı bulundu ve kapatıldı; kapılardan biri
**doğduğu anda canlı veride 2 kırık atıf yakaladı.**

---

## 1. Yöntem — sabotaj matrisi

Önce atıf envanteri çıkarıldı (kütüphane + katalog, tüm alanlar), sonra
başka bir şeye **referans veren** her alan tek tek bozuldu ve kapıların
ötüp ötmediği ölçüldü. Sabotaj **izole kopyada** koşuldu (`scratchpad`),
Dart tarafı gerçek ağaçta koşulup her seferinde `git checkout` ile geri
alındı (ağaç sonunda 0 değişiklik).

### ⚠️ İlk ölçütüm yanlış pozitif verdi — isimli

İlk matris yalnız `validate_*.py`'yi çağırıyordu ve **8 kaçak** raporladı.
Dart kapıları eklenince ikisi düştü:

| sabotaj | Python | Dart/kabuk |
|---|---|---|
| S4 `precondition.conditions[].metric` | sessiz | **motor 8 test kırıldı** |
| S12 `engine.signal.joint` | sessiz | **motor 9 test kırıldı** |
| S3 `library.wave ≠ katalog.wave` | sessiz | **kabuk 4 test kırıldı** |
| S11 `lesson.id` kurs önekiyle uyuşmuyor | sessiz | **motor 2 + kabuk 1** |

**Ders:** "kapı" yalnız doğrulayıcı betik değil; test süiti de kapıdır.
Yalnız betiği sorgulayan bir süpürme, kapsamı olduğundan dar ölçer — bu
defterdeki *dar kapı* deseninin (G-087) süpürme tarafındaki hâli.

---

## 2. Nihai tablo — 12 sabotaj

| # | atıf | yakalayan |
|---|---|---|
| S1 | `catalogId` → katalog dosyası | ✅ validate_library |
| S2 | `errorFocus[]` → `formErrors[].id` | ✅ K3 |
| S3 | `library.wave` ↔ katalog `wave` | ✅ kabuk testi |
| S4 | `precondition.conditions[].metric` | ✅ motor testi |
| S5 | `formErrors[].detect.metric` | ✅ validate_catalog |
| **S6** | **`formErrors[].perturbation.metric`** | **⛔ KAÇAK** |
| **S7** | **`lessons[].focus`** | **⛔ KAÇAK** |
| **S8** | **`gradedJoints[]` (KİLİTLİ derste)** | **⛔ KAÇAK** |
| S9 | katalog `courses[]` ↔ kütüphane | ✅ çelişki kapısı |
| **S10** | **`gateableMetrics[]` → metrics.json** | **⛔ KAÇAK** |
| S11 | `lesson.id` ↔ kurs öneki | ✅ motor + kabuk |
| S12 | `engine.signal.joint` | ✅ motor testi |

---

## 3. Dört kaçak — neden kaçtılar

**S6 — `perturbation.metric`.** `check_perturbation` `detect.metric`'i
metrics.json'a karşı doğruluyordu; **komşu alan aynı adı taşıyor
(`metric`) ve hiç okunmuyordu.** Fixture'ı bozan metrik budur: tanımsızsa
üretilecek fixture'ın neyi bozduğu bilinmez.

**S7 — `lessons[].focus`.** Hiçbir yerde doğrulanmıyordu. Oysa serbest metin
değil, katalog `gateableMetrics`ine (ya da formErrors'a işaret eden `form`)
**atıftır**. Uydurma bir odak yazılabiliyor ve ders "neyi ölçtüğünü" yanlış
beyan ederken kapı ötmüyordu.

**S8 — `gradedJoints` KİLİTLİ derste.** K7 yalnız **açık** dersleri
görüyordu. Kilitli bir dersin eklem beyanı çürük kalabilir ve **kilit
açıldığı gün çürük beyanla açılırdı.** Kilit bir muafiyet değil, geçici bir
kapıdır.

**S10 — `gateableMetrics`.** metrics.json'a atıf, ama okuyanı yoktu: tanımsız
bir metrik "kapıya alınabilir" diye beyan edilebiliyordu — *beyan var,
karşılığı yok*.

---

## 4. ⭐ Kapı doğduğu anda CANLI veride iki kırık atıf buldu

S10 kapısı eklenir eklenmez `validate_catalog` kırmızı yandı — sabotaj değil,
**gerçek içerik**:

```
❌ bodyweight_squat: gateableMetrics 'torso_angle'  metrics.json'da yok
❌ bodyweight_squat: gateableMetrics 'heel_lift'    metrics.json'da yok
```

Aynı dosyanın `formErrors` bölümü **doğru** adları kullanıyor
(`torso_angle_from_vertical`, `heel_rise_torso_norm`) — yani aynı metrikler
dosyada **iki farklı adla** yazılmış: biri kapılı, biri kapısız. S6'nın
deseninin birebir aynısı.

Düzeltildi (kaynak: dosyanın kendi doğru adları, icat yok).

---

## 5. Kapatma ve kanıt

| kapı | yer |
|---|---|
| S6 | `check_perturbation` → `perturbation.metric` metrics.json'da mı |
| S7 | `focus` ∈ `gateableMetrics` ∪ {`form`} |
| S8 | `gradedJoints` KİLİTLİ derste de tanınan eklem kümesinde mi |
| S10 | `check_gateable_metrics` (yeni) |

**Sabotaj yeniden koşuldu: 4/4 kapandı, taban mutasyonsuz TEMİZ.**
Self-test'e S7 ve S8 mutasyonları eklendi — **19/19 kapı ateşleniyor**
(17'den). Doğrulayıcı özeti: **12 değişmez (19 kapı dalı)**.

Kapılar: motor 128/128 · kabuk 40/40 · analyze temiz · validate_library
TEMİZ + self-test 19/19 · validate_catalog 0 hata · replay 8 ateşlenen/0 ölü.

---

## 6. Açık kalan

S6'da `perturbation.metric` **tanımlı** olmasını istiyorum ama
`detect.metric` ile **aynı olmasını** istemiyorum — farklı bir metriği
bozarak bir hatayı tetiklemek meşru olabilir (`via.joint` mekanizması).
Bu ikisinin ilişkisi ölçülmedi; bugün yalnız "tanımsız olamaz" kuralı var.
İlişki kuralı gerekirse ayrı bir ölçüm işidir.
