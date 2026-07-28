# ADR-002 — Yapısal tutarlılık kontrolü (güven kapısına EK)

**Durum:** kabul (2026-07-26) · **Kanıt:** [`../gates/G1-D1-RAPOR.md`](../gates/G1-D1-RAPOR.md) §1 · **Defter:** G-003 · **Aile:** M-019

## Bağlam
Plan §7.4 tek emniyet mekanizması olarak **güven kapısını** öngörüyordu: kritik landmark güveni düşükse hüküm verme.

## Ölçüm ne buldu
Güven kapısı, ürünün en tehlikeli hata modunu **yakalayamıyor**. Eksen terslemesi vakalarında güven yüksekti (#21: 0,93; #53: 0,84). Yani güven eşiği ne kadar yükseltilirse yükseltilsin bu hata geçer.
→ **"Güven ≠ doğruluk"** artık bir sezgi değil, ölçülmüş bir olgu.

## Karar
Güven kapısının **yanına**, kural motorundan önce deterministik bir **yapısal denetim** konur. Üç sınıf kontrol:
1. **Faz-eksen uyumu:** beklenen beceri fazıyla vücut ekseni tutarlı mı (ters-duruşta baş kalçadan aşağıda, el-üstü duruşta bilekler omuzdan aşağıda).
2. **Kemik uzunluğu tutarlılığı:** üst kol ≉ uyluk; kişi sabitken kemik uzunlukları ani sıçramaz (uzuv takası tespiti).
3. **Kare-arası fiziksel imkânsızlık:** 25 fps'te gövde ekseni bir karede >120° dönemez.

**İhlalde: hüküm YOK.** Sıra: diğer yönelimde yeniden çıkarım (ADR-001 çift-geçiş) → hâlâ ihlal varsa deneme `UNANALYZABLE`. Kullanıcıya "analiz edemedim" + neden; **ilerleme düşmez.**

## Sonuçlar
- ✅ Kendinden emin yanlış koçluk riski yapısal olarak kapatılır — planın "yanlış-pozitif geri bildirim oranı" metriğinin (§14) tek gerçek savunması.
- Bu kontrol **beceri-bağımsızdır** → `motion-core`'a aittir (M-019), Gravita'ya değil. Lissom ters pozları, Choreia yer figürleri, JabLab eğilmeleri aynı kontrolden yararlanır.
- ⚠️ Koordinasyon borcu: `motion-core`'da paralel bir oturum `pose/confidence_gate.dart` yazıyor (M-017). Bu ADR o bileşene **ek gereksinim** getirir; çekirdeğe kim yazacak kurucu kararı bekliyor.
- Test borcu: PRD §11 — "yapısal denetim ihlalinde hüküm üretilmediği" fixture-replay ile testli olacak.

## Reddedilen alternatifler
- **Güven eşiğini yükseltmek:** ölçüm bunu çürüttü (hata yüksek güvende).
- **ML tabanlı "poz makul mü" sınıflandırıcısı:** açıklanamaz kara kutu; plan §15 "her teknik kararın neden verildiği loglanabilir olmalı" ilkesine aykırı, ayrıca eğitim verisi yok.
- **Kullanıcıya sormak ("doğru mu?"):** ters-duruşta ekranı görmüyor; ayrıca yükü kullanıcıya atmak.
