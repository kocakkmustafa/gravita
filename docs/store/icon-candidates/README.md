# Güncel native simge — 2026-10-16

Yeni onay: **v19-refined-a**. Güncel master, platform envanteri,
boyutlar ve hashler [onaylı simge kaydında](../../design/icon/approved-2026-10-16/README.md).
15 iOS AppIcon ve 5 Android launcher PNG güncellendi. Aşağıdaki adaylar ve
mağaza dosyaları tarihsel kayıttır; yeni onaylı simgeyle mağaza görsellerinin
hazır olduğu anlamına gelmez. Native kurulum ve mağaza yüklemesi yapılmadı.

---

# Gravita mağaza simgesi adayı — 2026-09-23

Kurucu, siyah/kırmızı zeminli **tek el straddle handstand** görselinin ilk özenli yeniden çizimini seçti. Seçilen kaynak `one-hand-handstand-black-red-selected-reference-1254.png` dosyasıdır; sonraki daha sade çizim seçilen dosya değildir.

| Dosya | Kullanım |
|---|---|
| `one-hand-handstand-black-red-selected-reference-1254.png` | Seçilen, opak RGB kaynak görsel (1254 × 1254) |
| `one-hand-handstand-black-red-rounded-preview-1254.png` | Yalnız dört dış köşesi yaklaşık %9 yumuşatılmış, saydam köşeli görsel önizleme |
| `one-hand-handstand-black-red-App-Store-1024.png` | Kare ve opak 1024 × 1024 mağaza adayı |
| `one-hand-handstand-black-red-Google-Play-512.png` | Kare ve opak 512 × 512 mağaza adayı |

Yuvarlatılmış önizleme, seçilen kaynak görsele yalnız alfa maskesi uygulanarak oluşturuldu: opak kalan bütün pikseller kaynakla birebir aynıdır. Apple ve Google Play dış köşe maskesini kendileri uyguladığından mağaza adayları kare ve opak tutulur. Seçilen opak kaynak, iOS AppIcon kümesindeki 19 ikon kaydına (15 benzersiz PNG) ve Android mipmap kümesindeki 5 PNG dosyasına aktarıldı (2026-09-24); boyut/opaklık 24/24 ikon kaydı ve iOS 1024 kaynak-piksel eşleşmesi doğrulandı. Güncel binary kurulumu ve mağaza yüklemesi henüz doğrulanmadı.

## 2026-10-15 — Google Play dosya biçimi

Güncel `one-hand-handstand-black-red-Google-Play-512.png` dosyası, [Google Play ikon şartına](https://developer.android.com/distribute/google-play/resources/icon-design-specifications) uygun 512 × 512, 32-bit RGBA PNG olarak dışa aktarıldı; sRGB etiketi taşır. Önceki RGB pikselleri birebir korundu (fark 0); alfa kanalı her pikselde 255, görünüm opaktır. Kaynak çizim, App Store adayı ve native ikonlar değişmedi. Bu yerel dosya doğrulamasıdır; mağazaya yükleme kabulü değildir.
