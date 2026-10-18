# Tarihsel ekran görüntüleri — 16 Ağustos 2026

**18 Ekim 2026: Bu set güncel mağaza gönderiminde kullanılamaz.** Aşağıdaki
31/2/29 katalog ve kamera anlatımı kendi tarihine aittir. Güncel 56 ders,
DB/KB yolları, üç ayrı temel kurs taslağı ve kapalı kamera/satış politikası
bu görüntülerden doğrulanamaz. PNG'ler değiştirilmeden tarihsel kanıt olarak
korundu. Güncel çekim/kabul koşulları [yayın kontrol paketindedir](../../RELEASE-REVIEW.tr.md).

## Çekimin kendi tarihindeki notları

2026-08-16, `gravita-hatti` (UDID `2F59E2DB-8F02-4D24-BAD6-8313576FAB98`) simülatöründe,
`flutter build ios --simulator --debug` ile TAZE derlenmiş build'den alındı. Status bar
`xcrun simctl status_bar override` ile temiz duruma getirildi (09:41, tam sinyal/batarya —
Apple'ın kendi mağaza-görüntüsü kuralı). `debugShowCheckedModeBanner: false` eklendi
(`lib/app/gravita_app.dart`) — kırmızı "DEBUG" şeridi kaldırıldı, mantık DEĞİŞMEDİ.

`attach`/`detach` ÇAĞRILMADI (`H-46`: panel paylaşımlı, cihaz-kapsamlı `screenshot`/`tap`
güvenli) — yalnız `launch` + `screenshot` (headless).

| Dosya | Ekran | Neden seçildi |
|---|---|---|
| `01-today-honest-scope.png` | Today sekmesi | "OPEN RIGHT NOW: 2" + "CLOSED MOVEMENTS: 29 of 31" — uygulamanın kapsam-dürüstlüğünü İLK bakışta gösteriyor |
| `02-library-scope.png` | Library sekmesi | Aynı sayı (`31 · 2 · 29`) tam liste bağlamında, `OPEN`/`CLOSED` + "measurements missing" etiketleriyle |
| `03-push-up-honesty-box.png` | Push-Up hareket detayı | "MEASURED / not built a demonstration" kutusu — `library_strings.dart`ın `howToReferenceNotDrawable`i (H-44'te falsification-link eklenen tam cümle) |
| `04-progress-measured-locked.png` | Progress sekmesi | "Locked... limits in our measurement, not in you" — form-derecelendirmeme kararının kullanıcıya nasıl anlatıldığı |

**Kamera izni simülatörde otomatik REDDEDİLDİ** (varsayılan simülatör davranışı) — bu
yüzden canlı kamera/seans ekranı BU SETTE YOK. Bu ret başka araç veya izin
komutuyla aşılmaz. Yeni kamera izni ancak kullanıcı tarafından açıkça
yetkilendirilmiş ayrı cihaz kabulünde ele alınır; bu ilk sürümün dersleri
kamera gerektirmez. Eski notta önerilen otomatik izin verme yolu kaldırıldı.
