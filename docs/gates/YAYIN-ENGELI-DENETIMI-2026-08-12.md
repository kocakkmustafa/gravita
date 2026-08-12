# 🚢 YAYIN ENGELİ DENETİMİ — Gravita (2026-08-12, G-189)

> Yöntem **icat edilmedi**: JabLab'ın `docs/gates/YAYIN-ENGELI-DENETIM-YONTEMI.md`
> (J-216) belgesindeki 12 kalem, Gravita ağacında koşuldu. Kalem numaraları o
> belgeyle **aynıdır** ki aile çapraz-taraması yapılabilsin.

**Ölçüm anı:** `b492dcd` · app 170/170 · engine 175/175 · python 13/13.

## ⓵² ARAÇ ZİNCİRİ — ÖN KOŞUL, önce koşuldu

`JAVA_HOME=…/temurin-17.jdk/Contents/Home ./gradlew :app:assembleDebug --dry-run`
→ **BUILD SUCCESSFUL** (4 görev). Varsayılan JDK ile → çıplak `25.0.2`.
Sistem JDK'sı **Temurin 25.0.2**; Gradle 8.14'ün Kotlin'i onu ayrıştıramıyor.

⭐ Bu, JabLab'ın ölçtüğü tablonun **birebir aynısı** — ve o belgenin uyardığı
yanlış-atıf tuzağı (`25.0.2` → "NDK sanmak") burada da mümkündü. **Depoya
hiçbir şey yazılmadı**; düzeltme çağrı başına.
→ Araç zinciri çalıştığı için ④ ve ⑤ hakkındaki cevaplar **ölçüm**, "ölçemedim"
değil.

## DENETİM TABLOSU

| # | katman | Gravita'da durum | sınıf |
|---|---|---|---|
| 1 | ağ | ✅ **KAPALI** — bölme 63/63, öz-test 6/6, sabotaj kontrollü (G-188) | hat-yereli |
| 2 | kalıcılık | ✅ **KAPALI** — diske yazan 3 yer sayıldı; landmark hiçbirinde yok (G-184) | hat-yereli |
| 3 | izin metni | ✅ **KAPALI** — iddia YANLIŞTI, ölçülüp düzeltildi (G-184) | hat-yereli |
| 4 | platform eşiği | ✅ **KAPALI** — `targetSdk=36` · `compileSdk=36` (Flutter varsayılanından çözüldü). Play'in 31 Ağu 2026 eşiğini karşılıyor | hat-yereli |
| 5 | imza | 🔴 **AÇIK** — release **debug anahtarıyla** imzalanıyor; şablon TODO'su duruyor. `key.properties` YOK, keystore YOK | **İKİYE BÖLÜNDÜ** ↓ |
| 5a | ” yapılandırma + sessiz-düşme kapısı | ✅ **KAPALI** (`131934f`) — üç yönde ölçüldü (öter · susar · ürünü engellemez) + **KİMLİK katmanı**: `-PallowDebugSigning=true` ile gerçek `assembleRelease` koşuldu ve APK sertifikası okundu → **`CN=Android Debug`**. Uyarı metni artık çıkarım değil ÖLÇÜM (Ostinato'nun katmanı) | **hat-yereli** |
| 5b | ” keystore (sır) | 🔴 **AÇIK** — erişim/sır | **kurucu** |
| 6 | gizlilik manifesti | ✅ **KAPALI** (`c3ccf41`) — ölçüm (5 kategori, pinli çekirdek dahil, hepsi 0) + **paketleme** (4 pbxproj çapası, `plutil -lint` OK) | hat-yereli |
| 7 | ikon | 🔴 **AÇIK** — şablon varsayılanı. Tahmin değil **kimlik**: `ic_launcher.png` md5 `13e9c72e…` = Flutter şablonununkiyle **birebir aynı**; ikon yollarına dokunan tek commit kabuk kurulumu | kurucu |
| 8 | mağaza iddiaları | ⚪ **UYGULANAMAZ** (bugün) — mağaza listesi metni YOK. **Listeden düşmüyor** | hat-yereli (içerik) · kurucu (onay) |
| 9 | otomatik yayın (`AFTER_APPROVAL`) | 🔴 **AÇIK — ve bu satır DÜZELTİLDİ (2026-08-12 akşam).** İlk yazdığım hâli *"ASC app kaydı YOK, uygulanamaz"* diyordu; **yanlıştı.** Koordinatörün aile ölçümü: **beş uygulamanın beşi de `releaseType: AFTER_APPROVAL`**, Gravita dahil (**app id 6794714365**) → onay gelir gelmez **otomatik yayın**. Yani kalem uygulanamaz değil **canlı**. 🪤 Kendi denetimimin kör noktası: ASC'yi **depodan** aradım (`grep com.yulalab.gravita`) ve bulamayınca *"kayıt yok"* dedim — ***bir kaydın DEPODA olmaması, MAĞAZADA olmaması demek değildir.*** Erişim gerektiren bir kalemi erişimsiz ölçmeye çalışmak, "yok" cevabını üretir | kurucu |
| 10 | cihaz kanıtı | 🔴 **AÇIK** — `docs/gates/kanit/` 11 dosya taşıyor ama **cihaz kanıtı 0**. Ekranın kendi başlığı da bunu yazıyor: *"Bu ekran cihazda DOĞRULANMADI"* | kurucu |
| 11 | sürüm | ⚪ **KARAR** — `0.1.0+1`, yani "ön sürüm" **beyanı**. Ölçüm değil, karar | kurucu |
| 12 | araç zinciri | ✅ teşhis KAPALI / 🔴 kalıcı çözüm AÇIK | hat-yereli (teşhis) · **kurucu** (makine geneli) |

## DAĞILIM

* ~~hat-yereli AÇIK: 2~~ → **KAPANDI**: ⑤a (`131934f`) · ⑥ (`c3ccf41`)
* **çekirdek: 0** — hiçbir kalem çekirdek turu gerektirmiyor
* **kurucu AÇIK: 6** → ⑤b keystore · ⑦ ikon · **⑨ `AFTER_APPROVAL` (otomatik yayın — CANLI)** ·
  ⑩ cihaz kanıtı · ⑪ sürüm kararı · ⑫ makine-geneli JDK
* kapalı: ①②③④ **⑤a ⑥** + ⑫-teşhis · uygulanamaz-ama-listede: ⑧
* **hat-yereli AÇIK: 0** (⑤a `131934f` · ⑥ `c3ccf41` ile kapandı)

## YÖNTEMİN BANA GÖSTERDİĞİ — kalem tek tek kapatmak DENETİM DEĞİLDİR

Bugün altı kalemi tek tek kapattım (③④ · `lockedReason` · plist · kalıcı-ret ·
navigasyon · `google_fonts`) ve hepsi gerçek işti. Ama **sistematik denetimi
hiç koşmamıştım**, ve koşunca **hiç bakmadığım üç kalem** çıktı:

* **⑤ imza** — release'in debug anahtarıyla imzalanması, şablondan gelen ve bu
  yüzden **arka plana karışan** bir kusur.
* **⑥ `PrivacyInfo.xcprivacy`** — hiç aklıma gelmemişti.
* **⑦ ikon** — "elbette şablon" diye **varsayacaktım**; md5 karşılaştırması onu
  varsayım olmaktan çıkardı.

> ***Kendi seçtiğin kalemleri kapatmak, listeyi kimin yazdığını sormadan
> denetim yapmaktır.*** Yöntemin değeri, benim bakmayacağım yerleri
> göstermesiydi — ve üçü de şablon kaynaklıydı, yani tam olarak yöntemin
> *"aynılık kusuru arka plana çevirir"* uyarısının hedefi.

## SINIR

Bu belge **bir hattın** denetimi. Şablon kalemleri (④⑤⑥⑦⑧) aile düzeyinde
çapraz-taranmadan *"bende yok"* bir bulgu değil **arka plan** olabilir — o adım
koordinatöre ait (yöntem, Adım N).
