# Kapı Envanteri — Gravita

**Tarih:** 2026-08-07 · **Yöntem:** JabLab J-126 (aile ilki), koordinatör aktarımı

---

## Neden bu envanter var

> **Kapı kurmak bir iş değil, İKİ iş: kapıyı kurmak ve KAPSAMINI YAZMAK.**
> İkincisi atlanınca kapı yeşil kalır ve o alanda kimse bakmaz —
> ***yeşil bir kapı, bakılmayan bir alan üretir.***

Bu, bu hattın kendi `G-129` bulgusunun genel hâli: *K7c kapısı kütüphane
büyüyünce SESSİZCE sahte oldu.* Orada **bir** kapıda bulundu; envanter
**hepsini** aynı soruya tabi tutuyor.

**Soru DIŞARIDAN sorulur:** ***"bu kapı neyi ÖLÇMÜYOR?"*** — *"ne ölçüyor"*
diye sorulursa kapsam boşluğu çıkmaz, çünkü kapı ölçtüğü şeyi zaten
söylüyor.

**Kanıt sütunu zorunlu:** kapsamı nasıl biliyorum · negatif ikizi var mı ·
sabotajla sınandı mı.

**Kör nokta sınıfı:** `algı` (görünürlük/okunabilirlik) · `kod` (yol kapı
dışında) · `ölçüm yöntemi` (kapı yanlış şeyi ölçüyor).

---

## Envanter — 22 kapı

### 🔴 Kapsam boşluğu BULUNAN

| Kapı | ÖLÇMÜYOR | Kanıt | Sınıf | Durum |
|---|---|---|---|---|
| **`validate_catalog.py`** | ~~Kendini~~ → şimdi **17 değişmezin 10'unu** ateşliyor. **Kalan 7'si (V3·V6·V10·V12·V13·V16·V17) HÂLÂ KANITSIZ.** | Envanter yazılırken ölçüldü: `self-test` **0** eşleşme, kardeşi `validate_library` 20 mutasyonla kendini kanıtlıyordu. Eklendi: taban-temiz kontrolü + 10 gerçek dosya mutasyonu. | ölçüm yöntemi | 🟡 **KISMİ** — 10/17, kalanı isimli |
| **Kontrast kapısı** | **Yerinde tanımlanmış rengi.** Kapı `GravitaColors` tokenlarını tarıyordu; `live_session_screen.dart` mühürlü zemini `const Color(0xFFFFF4F3)` diye YERİNDE tanımlıyordu → kapının dışındaydı. | Ölçtüm: zemin bugün güvenli (honestyText **9.29:1**) ama **hiç ölçülmüyordu.** J-126'nın birebir karşılığı. | kod | ✅ token'a terfi + **literal renk yasağı** kapısı |
| **Taşma süpürmesi** | ~~Sayfanın ilk ekranından sonrasını~~ · ~~Hareket sayfası dışındaki yüzeyleri~~ | `ListView` ekran-dışını mount etmez → layout etmez → taşma oluşmaz. Ve süpürme yalnız `MovementPage` pump ediyordu. | ölçüm yöntemi | ✅ 5 yüzey × 2 yükseklik; 110pt sabotajıyla sınandı |
| **K7c (kütüphane)** | ~~Fixture'ı konumla seçtiği için kütüphane büyüyünce hiçbir şeyi~~ | Self-test 20/20'den 19/20'ye düştü; fixture `bodyweight_squat`tan `farmer_carry`e kaydı. | ölçüm yöntemi | ✅ fixture özellikle seçiliyor |

### ✅ Kapsamı YAZILMIŞ ve sınanmış

| Kapı | Kapsamı | Kanıt |
|---|---|---|
| `validate_library.py` | 12 değişmez, **20 mutasyon dalı** | `--self-test` 20/20; sayaç türetimli (elle "19/19" yazılıydı, bayatlıyordu) |
| `promote_library.py --check` | **Türetimin kendisini** ölçer (yeniden üretip diff'ler) + kapsam (katalog↔kütüphane) | Terfi simülasyonu: `bodyweight_squat` canlı yapıldı → 24/24 yeşil |
| `build_exclusions_page` / `build_skill_tree_index` / `name_preconditions` `--check` | Üçü de **türetimi** ölçer | Kaynak değişince drift bildiriyor |
| O-040 `_surfacedClaims` | Her `measured` iddiası ↔ çizen yüzey anahtarı; **anahtarın ekranda varlığı da** | Sabotaj: yüzeysiz iddia eklendi → öttü |
| Dil nöbeti (vaat) | TÜM `library.json` + exclusions + 3 string dosyası (yorumlar hariç) | Kapsam bir kez YARIM'dı: `lockedReason` + string dosyaları taranmıyordu |
| Defter-kodu nöbeti | **curated DAHİL** (muafiyet yalnız drift'e) | Sabotaj: curated'a `G-999` → öttü |
| Kontrast — token kapsamı | `theme.dart`taki HER `static const Color` sınıflandırılmak zorunda | Kendi eklediğim 3 sabiti yakaladı |
| Kontrast — varsayılanlar | `GravitaType.mono/body/display` çıplak çağrısı | `google_fonts`a dokunmadan; yapısal bağ ayrıca denetleniyor |
| Kontrast — hiyerarşi | birincil ÷ sönük **≥2×** | açık 2.99× · koyu 2.20× |
| Sayı→kural dönüşümü | 7 sayıya-bağlı iddia kurala çevrildi | **İki yönlü**: büyüme yeşil + yüzeysiz iddia kırmızı |
| Kapsam-küçülme nöbeti | Kütüphane ↔ katalog dosya sayısı | G-129'un küçülme yönü |

---

## Cevaplanan üç soru (koordinatörün ①②③'ü)

**① *"K7c bir kez sessizce sahte oldu — hangi kapıda daha olabilir?"***
Aynı sınıf (fixture/kapsam veriyle kayar) tarandı. Bulunan: taşma süpürmesi
(yüzey kapsamı), kontrast (token kapsamı), dil nöbeti (dosya kapsamı) —
**üçü de düzeltildi.** Kalan risk `validate_catalog`: kapsamı geniş ama
**kendisi kanıtsız**, ve kütüphane 28 hareket daha büyüyecek.

**② *"Başka hangi kapı yalnız ilk N'i ölçüyor?"***
Taşma süpürmesi ölçüyordu (ilk ekran + tek yüzey) → düzeltildi. Diğerleri
tam küme geziyor (`_surfacedClaims`, dil, kontrast, kapsam).

**③ *"Hangi türetim kapısı yalnız çıktıyı ölçüyor?"***
Dört `--check` kapısı **türetimin kendisini** ölçüyor (yeniden üretip
diff'liyor) — çıktı değil. `validate_library` çıktıyı ölçüyor **ama kendini
20 mutasyonla kanıtlıyor.** **`validate_catalog` ikisini de yapmıyordu** —
envanterin bulduğu tek gerçek boşluk.

**Kapatıldı — ama TAMAMEN DEĞİL ve bu açıkça basılıyor:** 17 değişmezin
**10'u** gerçek dosya mutasyonuyla ateşlendi (+ taban-temiz kontrolü).
Kalan **7'si (V3·V6·V10·V12·V13·V16·V17) hâlâ kanıtsız** ve betiğin
çıktısı bunu her koşumda yazıyor — *"10/10 geçti"* demek, kapsamı kapsamaymış
gibi sunmak olurdu. Neden ateşlenmedikleri de isimli: perturbasyon aritmetiği
metrik sözlüğünü bozmayı gerektiriyor (V3/V6/V16) · yalnız belirli
motor/yönelim birleşimlerinde doğuyor, `push_up` tabanı o dalları girmiyor
(V10/V12) · dosya-ötesi, `check()` dışında (V13) · hasat artefaktı gerekiyor
(V17).

---

## Envanterin kendi sınırı

Bu envanter **kapsamı** ölçer, **doğruluğu** değil: bir kapı tam kapsamlı
olup yanlış şeyi ölçüyor olabilir. Onu ancak **sabotaj** yakalar, ve
sabotajla sınanmış kapılar yukarıda ayrıca işaretli — sınanmamış olanlar
için "kapsamı yazılmış" demek, "doğru" demek DEĞİLDİR.
