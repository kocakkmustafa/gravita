# G-117 — SessionStore 0.10.0 adopsiyonu: geçmiş yüzeyi İKİLİ'den ÜÇ hâle

**Yetki:** koordinatör M-F-247 · **pin:** `motion_core-v0.10.0` (`4708652`)
**Kapılar:** motor 128/128 · kabuk **40/40** (33→40) · analyze temiz ·
validate_library TEMİZ + self-test 17/17 · validate_catalog 0 hata
**Simülatör:** üç hâl ekranda ayrıştı (üç ekran görüntüsü, §4).

---

## 1. Neden üç hâl — ikili model neyi taşıyamıyordu

Çekirdek `unreadableRecords()` zorunlu üye olunca *"okundu ama bir kısmı
kayıp"* ÖLÇÜLEBİLİR oldu. İkili model (`ok` / `unavailable`) bu durumu iki
şekilde de yanlış anlatıyor:

* `ok` demek → eksikliği gizler, kısmi sayıyı **tam sayım** gibi sunar;
* `unavailable` demek → okunabilmiş **gerçek** işi çöpe atar.

Üçüncü hâl bu "doğru ama eksik"i taşımak için var: **sayı gösterilir, tabanın
tam olmadığı söylenir.**

`HistoryStatus` sealed hiyerarşisi (`HistoryOk` · `HistoryPartial(n)` ·
`HistoryUnavailable(detail)`). `HistoryPartial` **assert ile n>0** — sıfırlı
"kısmi" beyan yalan olurdu, hâl o zaman `HistoryOk`'tur.

**İki beyan ayrı cümledir ve ayrı widget anahtarı taşır**
(`historyPartialKey` ≠ `historyFailureKey`): uç değer kısmi dalı susturamaz,
ikisi farklı olgu.

---

## 2. Pin ve sözleşme nöbeti

Pin bump `0.9.0 → 0.10.0` (kabuk + motor). **Mevcut pin testleri kırılmadı** —
sürüm-agnostik yazılmışlar (`^motion_core-v\d+\.\d+\.\d+$` + kabuk↔motor
eşitliği, J-071). Silinmedi, **üstüne kondu**:

Yeni nöbet — *"pin bump tek başına adopsiyon değildir"*: `unreadableRecords()`
üründe **tüketiliyor** mu, ve yüzey `HistoryPartial` üzerinde **dallanıyor**
mu. Bu ikisi olmadan pin yükselir, sözleşme okunmaz ve kısmi geçmiş sessizce
"tam" görünür — defterdeki *"okuyanı olmayan beyan"* sınıfının aynası.

---

## 3. Testler (33 → 40)

**Widget düzeyi (3 yeni):** kısmi hâlde beyan görünür **ve sayı düşmez** ·
**pozitif ikiz** — kayıp yokken beyan görünmez · beyan **kayıp sayısını**
söyler ("bir şeyler eksik" demez).

**Gerçek dosya düzeyi (3 yeni)** — JabLab 1+3 deseni, `tester.runAsync`
içinde (FakeAsync tuzağı, G-100):
* 1 sağlam + 3 bozuk satır (sözdizimi · bilinmeyen sürüm · eksik alan) →
  `recent()` **1 kayıt**, `unreadableRecords()` **3**. Sağlam satır okundu:
  kayıp, okunabileni götürmüyor.
* **pozitif ikiz** — tamamen sağlam dosyada kayıp **0** (bu olmadan üstteki
  test, sayaç her zaman 3 dönse de geçerdi).
* dosya **hiç yoksa** kayıp **0** — ilk açılış "kayıp geçmiş" değildir.

---

## 4. Simülatör kanıtı — üç hâl ekranda

| hâl | üretim yolu | ekranda |
|---|---|---|
| **ok** | temiz depo | `g117-hal-1-ok.png` — "Not started", beyan YOK |
| **partial** | gerçek depoya 1 sağlam + 3 bozuk satır | `g117-hal-2-partial.png` — *"…a floor, not a full count: **3 saved sessions** could not be read back…"* + **"6 reps" · "1 min 35 s worked" · "1 session"** |
| **unavailable** | `chmod 000` (izin hatası) | `g117-hal-3-unavailable.png` — *"We could not read your training history… nothing below is a count of your work."*, **sayı YOK, "Not started" YOK** |

### ⚠️ Simülatör turu benim bir hatamı yakaladı (testler yeşilken)

İlk enjeksiyonumda satırları `{"schemaVersion":2,…}` diye yazdım; **gerçek
şema anahtarı `"v"`.** Ekran o turda *"4 saved sessions could not be read
back"* dedi ve "Not started" gösterdi — yani **sağlam sandığım satır da
kayıptı.**

Testlerim bunu göremezdi çünkü orada satırları `store.append()` (gerçek
yazıcı) üretiyor. G-100'ün dersi aynen tekrarladı: *widget testi yeşil ≠
gerçek dosya doğru.* Ekran, yanlış olanın **benim enjeksiyonum** olduğunu
gösterdi — ürün doğru davranıyordu (4 çözülemeyen satır → 4).

---

## 5. 🔎 Çekirdeğe not — `sessions.jsonl` bir DİZİNSE sessizce "boş geçmiş"

HAL-3'ü ilk denerken dosyayı **dizin** yaptım. Beklenen `unavailable`;
gerçekleşen: ekran **"Not started"** dedi.

Sebep: `_readAll()` `if (!await _file.exists())` ile başlıyor ve `File.exists()`
bir dizin için **false** döner → *"dosya yok = ilk açılış, kayıp 0"* dalına
giriliyor. Yani **var olan ama okunamayan bir yol, hiç yazılmamış gibi**
okunuyor.

**Gerçekçiliği düşük** (bozuk kurulum / senkronizasyon artefaktı) ve bu bir
**çekirdek davranışı**, kabuğun değil — o yüzden burada düzeltmedim, isimli
not olarak koordinatöre gidiyor. İzin hatası yolu (chmod) doğru çalışıyor.

---

## 6. Delta farkları (shell-terfi hakemliği #3 için)

* **`HistoryStatus` sealed hiyerarşi** — JabLab'ın modelinde karşılığı yok;
  Gravita'da `HistoryFailure` zaten bir deltaydı (G-102), 0.10.0 onu üç hâle
  çıkardı.
* **Ayrı widget anahtarı** her hâl için: yüzey testleri hâlleri birbirinin
  yerine geçiremiyor.
* **`assert(n>0)`** kısmi hâlde: sıfırlı kısmi beyan tip düzeyinde imkânsız.
* **Sözleşme nöbeti kaynak metninde**: pin bump'ın tüketiciyi de getirdiğini
  test çiviliyor.
