# G-122 — Hasat Turu-1: Hipotez Defteri

> **Amaç** (orkestratör şartı, `motion-core` M-F-651 zinciri, 2026-08-16): kapı-tasarımı
> aşamasında biriken HER sınanmamış varsayım burada adıyla durur. *"Tasarım aşamasında
> biriken her varsayım bir borçtur; yazılmazsa borç değil, sessiz bir önyargı hâline
> gelir."* Hasat açıldığında İLK ölçülecek şey bu liste, yeni tasarımlar değil.
>
> Biçim: her satır bir HAREKET, bıraktığı VARSAYIM, ve onu ÇÜRÜTECEK ÖLÇÜM. Bir varsayım
> gerçek footage'la test edilip DOĞRULANIRSA ya da ÇÜRÜTÜLÜRSE, satır KAPALI olarak
> işaretlenir — silinmez (bu defterin kendisi bir "iddia edilen ama hiç okunmayan"
> alan olmasın diye, `tools/defter_freshness.py`nin ailesindeki aynı disiplin).

## Açık Varsayımlar

| # | Hareket | Kapı tasarımı | Varsayım (sınanmamış) | Çürütecek ölçüm | Durum |
|---|---|---|---|---|---|
| H1 | `glute_bridge` | `torso_angle_from_vertical >= <ölçülecek>` | Ayaktaki derin bir kalça-menteşesi (bow/good-morning) gövdeyi ANLIK olarak yataya yaklaştırmaz — ya da yaklaştırsa bile ayrışma glute bridge'in SÜREKLİ yatay duruşundan yeterince net kalır. | Hasat turu-1'de gerçek glute bridge tekrarlarının `torso_angle_from_vertical` dağılımı ÖLÇÜLECEK; mümkünse bir KARŞIT örnek (ayakta eğilme footage'ı, hasat hedefi değil, yalnız negatif kontrol) ile karşılaştırılacak. İki dağılım net ayrışmıyorsa H1 ÇÜRÜR ve ikinci sinyal (bkz. G-121 §5, `knee_angle` üst-sınırı) gerekli hâle gelir. | AÇIK |
| H2 | `pull_up` | `shoulder_angle >= <ölçülecek>` | (a) Standing biceps curl sürekli düşük `shoulder_angle` taşır (kol yanda) — ayrışma net. (b) Standing overhead press'in ÜST noktası benzer YÜKSEK `shoulder_angle` üretebilir; pull-up'tan ayrımı motorun faz-YÖNÜ mantığına (`hang→top` dirsek KAPANIR, press muhtemelen TERS) bırakılıyor — bu bir ÇIKARIM, ÖLÇÜM değil. | Hasat turu-1'de gerçek pull-up + İKİ karşıt örnek (biceps curl, overhead press) ölçülecek. (b) doğrulanmazsa (faz-yönü tek başına yetmezse) ikinci kapı gerekir — aday: `hang` fazında `elbow_angle` alt sınırı (kolun gerçekten düz olması). | AÇIK |
| H3 | `dip` | **Aday YOK** — `torso_angle_from_vertical` ve `shoulder_angle` ikisi de akıl yürütmeyle ELENDİ (§2, G-124): dip'in "dikey gövde, kol yanda" konfigürasyonu standing bir kol hareketininkiyle GEOMETRİK OLARAK ÖRTÜŞÜYOR. Bu bir hipotez DEĞİL — "mevcut motor kelime dağarcığında ayırt edici bir sinyal olmayabilir" iddiası. | Hasat turu-1'de gerçek dip + standing triceps extension karşıt örneği, `torso_angle_from_vertical`+`shoulder_angle` BİRLİKTE ölçülecek. Örtüşme doğrulanırsa (beklenen), bu bir "eşik ölçümü" değil "yeni metrik gerekiyor" bulgusuna dönüşür — kod kuyruğuna taşınır (G-124 §5). Ucuz alternatif (ayak-görünürlüğü vekili) adı konuldu, ölçülmedi. | AÇIK — FARKLI SINIF |

*(Sıradaki tasarımlar burada eklenecek.)*

## Kapalı Varsayımlar

*(henüz yok — hiçbir hipotez gerçek ölçümle sınanmadı, hasat henüz açılmadı)*

---

**Bu dosya HER yeni kapı tasarımıyla güncellenir** (yeni satır) **ve hasat turu-1 fiilen
başladığında İLK sırayla işlenir** (her satır, o hareketin gerçek harcanan ölçümüyle
AÇIK/KAPALI olarak kapatılır — sessizce atlanmaz).
