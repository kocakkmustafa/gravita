# Cihaz günü PAKETİ — Gravita (2026-08-16)

**Bu, `RECIPE.md`nin YERİNE geçmiyor** — reçete adım adım YÜRÜYÜŞÜ anlatır
(hâlâ tek doğru kaynak, tekrarlanmıyor burada). Bu dosya reçeteye ekli,
TARİHLİ bir **hazır mı** anlık görüntüsü: kurucu bugün oturursa gerçekten
çalışır mı, tahmin değil ölçümle.

## ✅ Durum: HAZIR (bir kusur bulundu VE düzeltildi, aşağıda tam anlatım)

## Bugünün taze ölçümü — ve içinde bulunan gerçek kusur

`tools/device_day_preflight.py`yi bu paketi yazarken YENİDEN çalıştırdım
(RECIPE.md'deki not saatler önceydi — bir paket "o zaman temizdi" değil
"ŞİMDİ temiz mi" sorusuna cevap vermeli). Sonuç ilk seferde **⛔ 1 SORUN**:

```
⛔ [cihaz] 00008120-001804D83E13C01E profildeki 0 cihaz arasında YOK.
```

**Bu YANLIŞ ALARMDI, gerçek bir regresyon değil — ama sebebi gerçek ve
ilginç:** `com.yulalab.gravita` için artık İKİ profil var —

| Profil | Oluşturma | `ProvisionedDevices` |
|---|---|---|
| `iOS Team Store Provisioning Profile` | 2026-08-16T03:47:34Z (yayın provası turuyla aynı pencerede) | **0** (App Store profili, TASARIM GEREĞİ boş) |
| `iOS Team Provisioning Profile` | 2026-08-13T21:58:30Z | **4** cihaz, kurucunun UDID'si İÇİNDE |

Eski `find_gravita_profile()` "aynı app-id'liler arasında EN YENİ
`CreationDate`" kuralıyla seçiyordu — yayın provası turu bir App Store
DAĞITIM profili ürettiği için o artık "en yeni," ve betik onu seçip
(devices'ı boş olduğu için) yanlışlıkla "cihaz kayıtlı değil" diyordu.
**Gerçek durum baştan beri temizdi** — geliştirme profili (ikinci satır)
hâlâ geçerli (bitiş 2027-08-13) ve cihaz onun içinde.

## Düzeltme — YAZILDI, DOĞRULANDI, UYGULANDI (`G-253`)

`tools/device_day_preflight.py`nin düzeltilmiş hâli bu turda yazıldı,
DOĞRULANDI (önce/sonra bizzat çalıştırıldı: eski kod `⛔ 1 SORUN`, yeni kod
`✅ ÖN-UÇUŞ TEMİZ`) ve `G-253` olarak commit'lendi: adayları önce
`ProvisionedDevices` TAŞIYANLARA daraltıyor (bir Store profili ne kadar
yeni olursa olsun cihaza doğrudan kurulum için kategorik olarak
kullanılamaz), yalnız o alt kümede en yeniyi seçiyor. Cihaz-kapsamlı profil
hiç yoksa bunu ayrı ve daha kötü bir durum olarak raporluyor (sessizce
"profil yok"a düşmüyor).

**Bu paketin yazıldığı anda canlı dosyada tekrar çalıştırıldı** (son ölçüm):

```
✅ [imza] 4 geçerli codesign kimliği bulundu.
✅ [profil] bulundu (cihaz-kapsamlı): iOS Team Provisioning Profile:
   com.yulalab.gravita (bitiş 2027-08-13 21:58:30)
✅ [cihaz] 00008120-001804D83E13C01E PROFİLDE KAYITLI — kurulum tazeleme
   GEREKTİRMEMELİ.
✅ ÖN-UÇUŞ TEMİZ — kuruluma geçilebilir.
```

**Aile boyutu:** bu kusur şemadan (Ostinato O-160, `find_ostinato_profile()`
BİREBİR aynı mantık) miras. Orkestratör CANLI doğruladı: Ostinato'nun kendi
Store profili de var (16 Ağustos 03:35:48, `ProvisionedDevices` 0) — yani
Ostinato'nun düzeltilmemiş betiği ŞU AN koşulsa aynı yanlış alarmı üretir
(varsayımsal değil, ölçülmüş). Gerekçe orkestratör tarafından
`PROFIL-GOLGELEME-DUZELTMESI.md` (`M-F-677`) olarak köprüye yazıldı ve
Ostinato'ya iletildi — kendi deposuna uygulamak onların kararı.

## Kaynaklar

- Yürüyüş tablosu + ön-uçuş komutu: `RECIPE.md` (bu paketin ekli olduğu
  dosya, İÇERİĞİ burada TEKRARLANMADI)
- Düzeltilmiş ön-uçuş betiği: `tools/device_day_preflight.py` (`G-253`)
- İmza/kurulum dersi: `feedback-ios-cihaz-kurulum-imza.md` (`H-9`)
- Aile-geneli tuzaklar: `motion-core/workspace/CIHAZ-GUNU-AILE-RECETESI.md`
