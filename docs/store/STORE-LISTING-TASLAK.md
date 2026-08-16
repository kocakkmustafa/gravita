# Mağaza Liste Metni — TASLAK (D6, 2026-08-16)

**Makine-okur kaynak:** `docs/store/listing.json`. Bu dosya insan-okur bağlam; metnin
kendisi `listing.json`da, her cümlenin `$`-önekli bir gerekçe alanı var (H-44'ün "yokluk
beyanına bitişik falsification-link" ilkesiyle aynı disiplin — çürütecek/kaynaklayan şey
CÜMLENİN YANINDA durur, ayrı bir belgede değil).

**Gönderim KURUCU kalemi (B7).** Bu yalnız taslak — ASC/Play'e hiçbir şey yüklenmedi,
yüklenmeyecek. Orkestratör `PASS`ı olmadan submit yok.

## Neden bu kadar dar

Kütüphane 31 hareket listeliyor ama bugün yalnız **2**sinin (`bodyweight_squat`, `push_up`)
gerçek bir kimlik ön-koşulu var (`content/library.json`, `status: live`). Mağaza metni
kütüphanenin TAMAMINI değil, bugün ÇALIŞANI baz aldı — `LibraryStrings.libraryCount`'ın
kendi ekranda kullandığı "$total movements · $live open · rest waiting on a measurement"
deseniyle birebir aynı çerçeve.

## Kontrol listesi (her cümle bir kaynağa bağlı)

| İddia | Kaynak |
|---|---|
| Kamerayla, cihazda, hareket gerçekten yapılınca sayar | `lib/app/onboarding_strings.dart` `valueWhatWeDo` (G-213'te bir kez yalan söyleyip düzeltilmiş) |
| Form derecelendirmiyor, canlıda düzeltme yok | Aynı dizge, ikinci yarı |
| Tıbbi değil, koç yerine geçmez, düşmeyi engelleyemez | `valueWhatWeDont`, birebir |
| 31 hareket, 2 açık, 29 ölçüm bekliyor | `LibraryStrings.libraryCount` deseni + `content/library.json` (bu oturumda ölçüldü) |
| Ağa hiç çıkmıyor, video hiç yüklenmiyor | `tools/network_claim_audit.py` (SIFIR ağ-yetenekli paket, F2/G-227) + CLAUDE.md "ham video cihazda" |
| Hesap yok | `pubspec.yaml` grep — auth/firebase bağımlılığı sıfır |
| Sosyal paylaşım/UGC yok | `pubspec.yaml` grep — share/webview/url_launcher bağımlılığı sıfır |

## Ne YAZILMADI (bilerek)

- **Cihazda-kanıtlı hiçbir cümle** — bu taslak `lib/` + `content/library.json` okumasına
  dayanıyor, gerçek cihazda "description'daki her şey doğru render oluyor" turu AYRI bir
  kalem (D6'nın kapsamı: taslak + ekran görüntüsü, cihaz-üstü metin-doğrulaması değil).
- **"Coach"/"training plan"/kişisel antrenör dili** — `valueWhatWeDont`ün yasakladığı tam
  sınıf, description hiçbir yerde kullanmıyor.
- **`cameraPermissionRationale.ios`daki "yalnız push-up" darlığı DÜZELTİLMEDİ** — bu
  cümle bugün BAYAT (squat da canlı) ama `Info.plist`in kendi kalemi, D6/mağaza-metni
  kapsamı değil; `listing.json`da adıyla işaretli bırakıldı, sonraki bir turun H-44 sınıfı
  kalemi.

## Ekran görüntüleri

`docs/store/screenshots/gravita-hatti-iphone16/` — `gravita-hatti` simülatöründen (UDID
`2F59E2DB-8F02-4D24-BAD6-8313576FAB98`, iPhone 16), `mcp__Claude_Code_iOS_Simulator__control`
`screenshot` eylemiyle. `attach`/`detach` ÇAĞRILMADI (H-46: panel paylaşımlı, cihaz-kapsamlı
`screenshot` güvenli).
