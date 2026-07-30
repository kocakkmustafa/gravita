# Dürüst hata ekranı — Gravita delta sözleşmesi (İKİNCİ tüketici)

**Tarih:** 2026-07-30 · **Statü:** UYARLANDI (sıfırdan yazılmadı)
**Kaynak desen:** JabLab `6601b1b` / J-079 — `lib/app/content_failure.dart` (80
satır) + `content_failure_screen.dart` (125 satır) + iki test dosyası, üçü de
okundu.

Koordinatör talimatı (M-F-193/194): *"Hata ekranını SIFIRDAN YAZMA… ONDAN
UYARLA + delta kaydet: sen İKİNCİ tüketicisin, shell_candidate terfisinin
girdisi olacak (SessionStore süreci aynen)."*

## 1. Aynen alınan kararlar (delta YOK)

JabLab'ın dördü Gravita'da da tartışmasız geçerli:

- **Sınıflandırma METİNDEN değil TİPTEN.** Hata mesajından sınıf çıkarmak
  ("mesajda `wave` geçiyorsa…") tam o sessiz-kırılma sınıfı: metin bir gün
  değişir, sınıflandırma sessizce yanlışa döner, hiçbir test görmez.
- **"Try again" YALNIZ `unreadable`da.** Bütünlük hatasında aynı asset aynı
  sonucu verir; oradaki retry kullanıcıyı boşa uğraştıran bir nezaket jesti.
- **"Yine de devam et" HİÇ YOK.** Doğrulamanın bloklama sebebi tam olarak
  kısmi/sahte bir kütüphane göstermemek; kaçış kapısı onu süse çevirir.
- **Geliştirici ayrıntısı gizlenmedi, İKİNCİLLEŞTİRİLDİ.** Kullanıcıya
  `StateError` gövdesi göstermek dürüstlük değil, sorumluluğu ona devretmek.

`ContentFailureKind` (`integrity` · `unreadable`), `ContentIntegrityException`
ve `ContentFailure.from()`un bilinmeyen-tip→`unreadable` kuralı bit-bit aynı
gerekçelerle taşındı.

## 2. ⭐ DELTA 1 — `HistoryFailure`: geçmiş okunamadı, İÇERİK SAĞLAM

JabLab'ın modelinde karşılığı YOK. Gravita'da olmak **zorunda**, çünkü
olmadığında **kodum yalan söylüyordu**:

`ProgressSummary` kayıt listesi boş gelince her dersi `notStarted` gösteriyor ve
yüzey **"Not started"** yazıyor. Depo okunamadığında (izin hatası,
`path_provider` başarısız, dosya bozuk) bu cümle *"hiç çalışmadın"* demektir —
kullanıcının aylarca birikmiş işini yok saymak. Ve bu yol GERÇEKTİ: kabuğun ilk
hâli `openSessionStore()` hatasını hiç ele almıyordu.

**Sözleşme:**

| | içerik hatası | geçmiş hatası |
|---|---|---|
| bloklar mı | **EVET** — kefil olamadığımız kütüphaneyi göstermeyiz | **HAYIR** — dersler sağlam, açılabilir |
| ekran | `ContentFailureScreen` (tipli) | ilerleme yüzeyi + **beyan** |
| sayı gösterir mi | — | **HAYIR** — bilmediğimizi sıfır yazmayız |
| retry | yalnız `unreadable` | yeniden kurulum önerilir (metinde) |

Ölçüm bölümü, geçmiş okunamazken satır/sayı yerine tek bir cümle gösteriyor
(`ProgressStrings.historyUnavailable`) ve o cümle **"nothing below is a count of
your work"** diyor. Kilitli-ders bölümü DEĞİŞMEZ: o bilgi içerikten gelir,
geçmişten değil.

**Bu neden bir aile deltası (yalnız Gravita meselesi değil):** her app'in
ilerleme yüzeyi "hiç yapmadın" ile "bilmiyorum"u ayırmak zorunda. JabLab'ın
`RecordedSummary`si de boş geçmişi `null` ile ifade ediyor — ama boş-geçmiş ile
okunamayan-geçmiş aynı `null`a düşüyor. Terfi turunda bu ayrımın ortak katmana
girmesini öneriyorum.

## 3. DELTA 2 (küçük) — bütünlük kapısının YERİ farklı

JabLab bütünlük doğrulamasını **çalışma zamanında** yapıyor
(`ContentIntegrityException` fırlatan bir doğrulayıcı var). Gravita'nın K1–K9
değişmezleri **derleme zamanında** koşuyor (`tools/validate_library.py` +
`test/shell_contract_test.dart`), yani bozuk içerik normalde uygulamaya hiç
GİRMEZ.

Yine de `integrity` sınıfı Gravita'da da CANLI: `ContentRepository` eksik `wave`
beyanını, `MovementConfig.parse` bozuk config'i `StateError`/`ArgumentError` ile
bildiriyor ve ikisi de "dosya okundu, içeriği tutmuyor" sınıfıdır.
`ContentIntegrityException` tipi de KORUNDU — çalışma-zamanı doğrulayıcısı
eklenirse (ör. referans artefaktları paketlenmeye başlayınca) yeri hazır.

## 4. Testler ve iki kendi hatam

12 test (`test/content_failure_test.dart`) + 3 kablolama testi
(`shell_end_to_end_test.dart`). M-F-194 uygulandı: her "X yok" kapısının yanında
"X var" ikizi var (retry-yok ↔ retry-var · beyan-yok ↔ beyan-var ·
hata-ekranı-yok ↔ hata-ekranı-var).

⚠️ **Kayda geçen iki hatam:**

1. **Ayrıntı katlanmış `ExpansionTile` içinde: açılmadan widget ağacında YOK.**
   İlk testim bunu bilmeden aradı ve "Bad state: No element" ile düştü. İki
   yanlış sonuç mümkündü: benim gibi düşmek, ya da daha kötüsü `findsNothing`
   yazıp *"ayrıntı gizlenmiş"* diye YANLIŞ bir dürüstlük iddiası kurmak.
   Doğrusu: AÇ ve ULAŞILDIĞINI kanıtla — *"gizlenmedi, ikincilleştirildi"*
   ancak erişilebilirse doğrudur.
2. **Kablolama testimin ilk hâli ürünün kablolamasını değil KENDİ TAKLİDİNİ
   sınıyordu** (`_ProbeScreen` adında, yükleme yolunun kopyası). Sildim; artık
   GERÇEK `ProgressScreen` pump ediliyor. Bu mümkün oldu çünkü geçmiş hatası
   artık ölümcül değil — yani delta 1, kendi testini de mümkün kıldı.
   Ve `pumpAndSettle()` orada KULLANILAMIYOR (gerçek asset G/Ç + sahte saat =
   sonsuz yükleyici): FakeAsync tuzağının bu turdaki üçüncü görünüşü.

## 5. Bu belgenin sınırı

Ekran GERÇEK bir cihazda gösterilmedi — yalnız widget testleriyle. Bozuk-içerik
yolu sentetik (`_BrokenBundle`); gerçek bir bozuk kurulum denenmedi. `integrity`
sınıfının kullanıcıya görünen hâli de simülatörde görülmedi: bugün onu
tetiklemek için içeriği kasıtlı bozmak gerekir ve yayımlı içeriğe dokunmuyorum.
