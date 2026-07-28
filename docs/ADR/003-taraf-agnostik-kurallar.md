# ADR-003 — Kural motoru modelin sol/sağ etiketine güvenmez

**Durum:** kabul (2026-07-26) · **Kanıt:** [`../gates/G1-D1-RAPOR.md`](../gates/G1-D1-RAPOR.md) §4.3 · **Defter:** G-007

## Bağlam
Plan, "baskın taraf" bilgisini onboarding'de topluyor (§5.1) ve ölçümlerde dirsek/omuz/diz gibi taraflı landmark'lara dayanıyor (§7.2). MediaPipe 33 landmark'ı `LEFT_*` / `RIGHT_*` olarak etiketler.

## Ölçüm ne buldu
- Ters-duruşta bir görüntüde (#22) düz ve döndürülmüş çıkarım arasında **sol/sağ kimlik takası** oldu: iskelet aynı, etiketler yer değiştirmiş.
- Ayrıca kritik landmark güvenleri **taraf başına asimetrik**: kendine-kapanma nedeniyle yan görünümde uzak taraf zaten görünmez. 12 landmark'ın hepsini isteyen kapı, **dik** insanlarda bile yalnız %32 geçiyor (kapı raporu §5.1). Bu bir hata değil, doğru davranış.

## Karar
1. Kurallar **taraf-agnostik** yazılır. `left_elbow_angle` gibi bir kriter **YASAK**; `elbow_extension_pct` (görünen taraf zincirinden) kullanılır.
2. Taraf seçimi **geometrik/istatistikseldir**: güveni yüksek olan zincir ("görünen taraf") seçilir; iki zincir de güvenliyse ortalanır veya kameraya yakın olan tercih edilir.
3. Güven kapısı, 12 landmark'ın min'i değil **görünen taraf zincirinin** min'i üzerinden çalışır.
4. Onboarding'deki "baskın taraf" bilgisi V1'de **kural girdisi değildir** — yalnız içerik/cue kişiselleştirmesi için saklanır (ör. "step with your stronger leg").

## Sonuçlar
- ✅ Ürün-gerçekçi kapı oranı: yan-zincir tanımıyla ters-duruşta 0,929 (12'li tanımla 0,405 — ürünü imkânsız kılardı).
- Simetri asimetrisi ölçülemez hale gelir: "sol dirsek sağdan bükülü" tipi geri bildirim V1'de **YOK**. Kabul edilen kayıp; yanlış taraf söylemek, söylememekten kötüdür.
- İçerik paketi bu kuralı ihlal edemez (motorda zorlanır — G4 §3).

## Reddedilen alternatifler
- **Modelin etiketlerine güvenmek:** ölçüm çürüttü.
- **Yönelimden sol/sağ türetmek:** yönelim biliniyor olsa da kameraya göre taraf hâlâ belirsiz (kullanıcı kameraya sırtı/yüzü dönük olabilir); ek kalibrasyon sorusu gerektirir, kazanç V1 için değmez.
