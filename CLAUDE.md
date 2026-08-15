# CLAUDE.md — Gravita

## 🟢 V0 KAPISI GEÇTİ (2026-07-26) — üretim kodu AÇIK
**H-31 (2026-08-16):** bu satır önceden *"kurucu demeden kod yazılmaz"* diyordu — 217 commit'lik
depoda hâlâ bu YANLIŞTI, her turun ilk okuduğu dosya bayat bir kilidi anlatıyordu. Düzeltildi.

**D1 — TERS-DURUŞ FİZİBİLİTESİ:** **🟢 ŞARTLI GEÇTİ**, kanıt [`docs/gates/G1-D1-RAPOR.md`](docs/gates/G1-D1-RAPOR.md)
(Defter `G-001`/`M-001`, 2026-07-26). Ölçülen: S2 (yönelim-farkında çıkarım) ile **42/42 doğru
eksen, 0/42 eksen hatası**; S1 (düz çıkarım) aynı sette **3/41 eksen hatası (%7,3)** — bu bant
üretime girmezdi. Şart aşağıda `Sert kurallar`a taşındı, kalıcıdır.

Hâlâ geçerli okuma sırası (yeni oturum → önce oku): `../VENTURE.md` + `../workspace/` dörtlüsü →
aile sözleşmesi (bağlayıcı, `ventures/motion-core/lib/docs/00-AILE-MIMARISI.md`, §1.1: sesli
antrenör-vaadi çekirdek, V1=sıra taban DEĞİL) → `docs/gravita-plan.md`.

## Sert kurallar
- **D1 şartı KALICI:** ters-duruş/baş-aşağı hareketlerde çıkarım **yalnızca S2 (yönelim-farkında)**
  mimariyle; düz S1 tek başına bu sınıfta YASAK (yukarıdaki ölçüm, eksen terslemesi sessiz ve
  güven-yüksek çıkıyor — güven eşiği bu hatayı yakalayamaz).
- Ortak altyapı motion-core'dan PİNLİ sürümle gelir; çekirdek kodu buraya KOPYALANMAZ, app mantığı çekirdeğe SIZMAZ.
- Gerçek-zamanlı LLM yok · ham video cihazda · düşük güvende hüküm yok · kural = versiyonlu config · replay-fixture'sız teknik eklenmez · tıbbi dil yasak (wellness).
- Danışmanlar: `motion-cv-engineer` + `movement-science-advisor`; submit öncesi `privacy-data-guardian` + `store-policy-officer`.
- Bundle ID: `com.yulalab.gravita` (rezerve, 2026-07-25).
