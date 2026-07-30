# G-099 — İlerleme yüzeyi: VERİ katmanı tam + iki dalga-körlüğü kapatıldı

**Koordinatör hükmü M-F-168 (orta yol), paket kalem 3:** veri katmanı TAM ·
yapısal widget İNCE · görsel cila tasarım oturumuna. Üç kural: *"ölçümler, not
değil"* · *geçilemez-kapı beyanı* · *retroaktif kredi yok*.

## 1. Üç kural YORUM değil, ALAN/TİP oldu

`packages/gravita_engine/lib/src/progress_summary.dart` (+ 17 test).

| kural | nasıl yapısal kılındı |
|---|---|
| **ölçümler, not değil** | `toJson()` anahtar kümesi TESTE ÇİVİLİ. Skor/derece/seri/seviye alanı eklemek testi ADIYLA kırar. Yorumla yazılmış "skor koymayacağız" sözü ilk aceleci commit'te ölürdü. |
| **geçilemez kapı** | `LessonProgressState { locked, notStarted, inProgress }` — kilitli ya da hiç başlanmamış ders yüzeyden DÜŞMEZ; kilitliyse `lockedReason` içerikten AYNEN taşınır (motor kullanıcı metni üretmiyor). |
| **retroaktif kredi yok** | Sınıf **kaydın kendi** `lessonClass`'ından okunur, dersin bugünkü hâlinden değil. `withheldRetroactiveCredit` bunu ayrıca SAYAR — yüzey "bunlar notlanmadı" demek zorunda kalsın. |

Yanı sıra üç dürüstlük sınırı daha, hepsi ölçülmüş bir gerekçeyle:

- **Tek skaler "toplam birim" YOK.** 8 tekrar + 45 saniye toplanamaz →
  `unitTotals: {rep: 8, second: 45}`. `totalWorkedSeconds` tek skaler olarak
  MEŞRU (saniye her derste aynı birim).
- **`hasRecordsWhileLocked`** — ders açıkken çalışılıp sonra ölçüm geri
  çekilirse (G-070 sınıfı geri adım) geçmiş GİZLENMEZ, işaretlenir.
- **`orphanRecordLessonIds`** — yüzeyde karşılığı olmayan kayıt (ders yeniden
  adlandırıldı/kaldırıldı) toplamlara girmez ama ADIYLA raporlanır. Rig
  tarafındaki yetim-karantinası deseninin (G-095) ürün tarafına düşen hâli.

## 2. `unitLabel`in ÜRETİCİSİ yoktu — katalog oldu

Delta 1 `unitLabel`i kayıt-başına bir alan yaptı; ama **alanı DOLDURAN kimse
yoktu.** `library.json`da birim alanı YOK; birim `content/catalog/*/engine.type`
içinde. Elle yazılsaydı bir statik tutuş dersi yüzeyde "5 tekrar" diye
görünebilirdi.

`unitLabelForEngineType(EngineType)` — **kapsayıcı (exhaustive) switch**:
kataloğa yeni bir motor tipi eklenirse kod **DERLENMEZ**. Çalışma-zamanı
`throw`u ancak o hareket bir kez oynanınca patlar; sessiz varsayılan
(`?? 'rep'`) en kötüsü olurdu.

`test/progress_surface_content_test.dart` yüzey listesini **GERÇEK
`library.json` + katalogdan TÜRETİR** — elle kurulmuş liste bir gün içerikle
ayrışır ve bir ders sessizce düşer. Ayrıca bir **bayat-yokluk nöbeti** (M-F-165)
kuruldu: *bugün forma not veren AÇIK ders YOK* olgusu teste yazıldı; form notu
açıldığı gün test DÜŞER ve retroaktif kuralın gerçek geçmişle sınanmasını ister.

## 3. ⚠️ Yan bulgu: aynı **DALGA-KÖRLÜĞÜ** üç yerde

Kalem 3 sırasında delta belgemdeki motor-tipi sayımını (`14 repFsm + 5
staticHold + 1 multiPhaseFsm` = 20) doğrulamak istedim. **Yanlıştı: katalog 31
hareket** (W1: 20 · W2: 11). Kök neden tek ve üç yerde tekrarlıyordu — *W2
eklendi, okuyucular genişletilmedi:*

| yer | iddia | fiili kapsam | sonucu |
|---|---|---|---|
| `catalog_smoke_test.dart` | *"motor kataloğun TAMAMINI tüketebilmeli"* | `w1` (20/31) | iddia doğru olmadan geçiyordu |
| `tools/validate_library.py` | K1-K9 değişmezleri | `CATALOG_DIR = .../w1` | W2 hareketi kütüphaneye girdiği gün **YANLIŞ ihlal** ("katalog girdisi YOK") — sessiz geçiş değil, sahte alarm |
| `SESSION-STORE-DELTA.md` §2 | *"katalogda"* 14/5/1 | w1 sayıları | delta gerekçesi eksik sayıyla yazıldı |

Üçü de kapatıldı: smoke test artık `content/catalog/w*` tarıyor **+ dalga-körlüğü
nöbeti olarak hareket sayısı (31) çivilendi**; `validate_library.py`de
`load_catalogs()` dalga-bağımsız; delta belgesine düzeltme bloğu yazıldı.
`replay_gate`/`harvest_reps`/`build_reference` ZATEN iki dalgayı okuyordu —
sapma tam da bu yüzden görünmedi.

**Genişletmenin sonucu:** W2'nin 11 hareketi de sorunsuz yükleniyor (33/33 duman
testi). Gizli bir kusur yoktu — **ama iddia doğru olmadan geçiyordu**, ve ben
sayımı o kapıdan devraldım. Aile dersi: *bir kapı DOĞRU olup KAPSAMI dar
olabilir; dar kapının çıktısını ölçüm olarak alıntılamak hatayı çoğaltır.*

Delta 1'in SONUCU değişmedi, **GÜÇLENDİ**: saniye-birimli hareket 5 değil **8**
(hollow_hold · plank · side_plank · superman_hold · wall_sit · farmer_carry ·
tuck_planche · wall_handstand).

## 4. Kapılar

`dart analyze` temiz · **121/121 test** (105 → +16: 4 içerik-kablolama · 11 W2
duman · 1 dalga nöbeti) · `validate_library` TEMİZ + **--self-test 15/15** ·
`validate_catalog` 0 hata · replay 8 ateşlenen / **0 ÖLÜ**.

## 5. Koordinatöre — widget'ın SINIRI

M-F-168 "İNCE yapısal widget" dedi. **Gravita'da Flutter paketi YOK**
(`app/lib` yok, tek paket `packages/gravita_engine`, saf Dart). Widget yazmak
yeni bir yüzey paketi (`packages/gravita_ui`?) açmak demek — kapsam kararı,
tek taraflı vermiyorum. Veri katmanı bu karardan BAĞIMSIZ olarak tam ve testli;
widget geldiğinde yalnız `ProgressSummary`yi okuyacak.

İki açık soru:
1. **Widget nerede yaşayacak?** yeni `packages/gravita_ui` · yoksa app-shell
   oturumuna mı bırakılıyor?
2. **`staticHold` dejenerasyonu** (delta §2, hâlâ açık): `unitsMeasured ==
   workedSeconds`. Şimdilik `unitsDuplicateWorkedSeconds` bayrağıyla yüzeye
   *uyarı* olarak veriliyor; karar (kabul-et-ve-belgele vs türet) terfi
   hakemliğinde verilebilir. **Bu bayrak olmasaydı yüzey aynı sayıyı iki
   bağımsız olgu gibi gösterirdi** — ilk somut tüketici kalem 3 oldu.
