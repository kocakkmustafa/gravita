# Yayın Envanteri — Gravita

**Tarih:** 2026-08-07 · **Yöntem:** JabLab J-124 (aile ilki), koordinatör aktarımı
**Ölçülen sürüm:** `main = 8294eff` → düzeltmeler sonrası

---

## Soru neden BU biçimde soruluyor

Envanterin sorusu **kullanıcı tarafından** sorulur:

> *"Bir kullanıcı bugün bu uygulamayı açsa, hangi yüzey onu YANLIŞ bilgilendirir?"*

**Neden "ne eksik?" diye sorulmuyor:** eksik merceği **fazlalığı göremez.**
Aşağıdaki dört kalemin hiçbiri "eksik" değildi — hepsi VARDI ve **fazla ya da
yanlış** şey söylüyordu. J-124'ün kendi bulgusu da öyleydi: `unlock` sözcüğü
tüm depoda yalnız bir cümlede geçiyordu — üretici yoktu ama **beyan onu
anlatıyordu.**

**En pahalı biçim:** *doğru sonucu yanlış gerekçeyle söylemek.* Sonuç doğru
olduğu için hiçbir davranış testi ötmez; yalnız kullanıcı-tarafı soru bulur.

**Kanıt sütunu zorunludur.** "Nasıl biliyorum" yazılamıyorsa satır envantere
girmez.

---

## Bulgular

| # | Yüzey | Kullanıcı ne YANLIŞ öğreniyordu | Kanıt (nasıl biliyorum) | Sınıf | Durum |
|---|---|---|---|---|---|
| 1 | **Progress** | Gerçek bir seans yaptıktan sonra bile **"Not started"**. Ekran, kullanıcının hiç çalışmadığını söylüyordu. | Kabuktaki tek `.append(` **serbest** kovaya yazıyor (`live_session_screen.dart:217` → `openFreeSessionStore`); `ProgressTab` yalnız **ders** kovasını okuyordu (`gravita_app.dart:212` → `openSessionStore`). İki dosya, tek okuyucu. | doğru sonuç ✗ — **düpedüz yanlış** | ✅ düzeltildi |
| 2 | **Library + Movement page rozeti** | `MEASURING` → *"uygulama beni ölçüyor"*. Gerçek TAM TERSİ: ölçülmemiş olan **ürünün kendisi**, kullanıcı değil. | Rozet 30/31 harekette çiziliyor; o hareketlerin **hiçbirinde motor koşmuyor** (`precondition.status = pending`, replay fixture yok). Ölçüm yapılmıyor — ölçüm **bekleniyor**. | **doğru sonuç, yanlış gerekçe** | ✅ `CLOSED` |
| 3 | **Home** | *"One movement has everything it needs **to be coached**"* — koçlanacağını sanıyordu. | Aynı hareketin sayfası tersini söylüyor: *"during a live session no cue appears on screen, so nothing actually tells you"* (`push_up.comingSoonInThisMovement`). **İki yüzey çelişiyordu ve daha görünür olanı yanlıştı.** | J-113 şekli | ✅ yalnız sayma iddiası |
| 4 | **Movement page sınıf rozeti** | `FORM COACHING` — 30/31 harekette hiçbir şey koşmazken form koçluğu vaat ediyor. | `classBadge`, `movement-classes.json.userCopy.badge`'den geliyor ve **kameranın ne görebildiğini** tarif ediyor, ürünün ne teslim ettiğini değil (`§principle`). Yanındaki açıklayıcı satır çerçeveyi koruyor (*"everything the camera needs is visible from the side"*) ama **pill tek başına** okunuyor. | doğru sonuç, yanlış gerekçe | ⏸️ **koordinatör** — sınıf sözlüğü içerik-şeması kararı, tek taraflı değiştirmedim |

---

## Ölçülüp TEMİZ çıkanlar (kayıt için — envanter yalnız kusuru saymaz)

| Yüzey | Sorulan | Kanıt |
|---|---|---|
| **"Neden yok?"** | Gerekçeler ürünün gerçek kararı mı, süs mü? | 7 bölümün 7'si `exclusions.json`'dan **üretiliyor**; iç Türkçe alanlar (`internalRule_tr`, `reconsiderIf`) shipped asset'te YOK (test asset üzerinden doğruluyor). |
| **Profile — "verin bu cihazda"** | Doğru mu? | Seanslar artık gerçekten yazılıyor ve yalnız uygulama dizinine; ağ yolu yok. |
| **Movement page trend** | Seans yaptıktan sonra dolacak mı? | İKİ kovayı da okuyor (`movement_page.dart:83-84`) — hareket düzeyi soru, ders trendi değil. |
| **Seans düğmesi** | Ölü buton mu? | İKİ bağımsız iddia birlikte: kütüphane `live` **VE** kataloğun ön koşulu `derived`. Biri ayrışırsa buton kaybolur. |
| **Dürüstlük kutusu `measured`** | Her iddianın kabukta yolu var mı? | `_surfacedClaims` kayıt defteri + anahtarın canlı ekranda gerçekten var olduğu doğrulaması (O-040 kapısı). |

---

## Envanterin kendi sınırı

Bu envanter **yüzeyde okunan cümleyi** ölçer. Ölçmediği iki şey:

1. **Cihazda gerçekten ne olduğu** — canlı seans yolu simülatörde uçtan uca
   koşmadı (sim'de kamera yok). Yani "seans kaydediliyor" iddiası **saf Dart
   davranış testi** düzeyinde doğrulandı, cihaz düzeyinde değil.
2. **Ayırt edilebilirlik** — kontrast kapısı görünürlüğü kapatır, iki rengin
   ayırt edilip edilemediğini ölçmez (WCAG luminans ölçer). O göz işi.
