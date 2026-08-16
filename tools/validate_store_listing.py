#!/usr/bin/env python3
"""Mağaza metnindeki hareket sayıları KATALOGLA UYUŞUYOR MU (H-58, 2026-08-16).

## Neden var

`docs/store/listing.json`nin `$readinessClaimWhy` alanı kendi bayatlama riskini
ADIYLA yazmıştı: *"Bu sayı hasat turu ilerledikçe DEĞİŞECEK... güncellenmezse bu
alan H-44 sınıfında bir yokluk/eskime beyanı olur."* Orkestratörün ölçtüğü gerçek
(H-58): `$`-önekli alanların SIFIR okuyucusu var — yazmak koruma değildir, kimse
okumazsa uyarı hiçbir şeyi durdurmaz.

Bu araç iki dosyadaki (`listing.json` İngilizce açıklama + `STORE-LISTING-
TASLAK.md`nin Türkçe kontrol listesi) sayıları `content/library.json`nin GERÇEK
sayımıyla karşılaştırır. Metni DÜZELTMEZ — yalnız UYUŞMAZSA kırmızı yanar; kararı
(sayıyı güncelle mi, cümleyi değiştir mi) her zaman bir insan/oturum verir.

    python3 tools/validate_store_listing.py            # gerçek dosyalarla
    python3 tools/validate_store_listing.py --self-test # sabotaj + pozitif ikiz
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LISTING = ROOT / "docs" / "store" / "listing.json"
TASLAK_MD = ROOT / "docs" / "store" / "STORE-LISTING-TASLAK.md"
LIBRARY = ROOT / "content" / "library.json"


def real_counts() -> tuple[int, int]:
    """Katalogdaki GERÇEK toplam ve canlı hareket sayısı — tahmin değil."""
    lib = json.loads(LIBRARY.read_text(encoding="utf-8"))
    movements = lib["movements"]
    total = len(movements)
    live = sum(1 for m in movements if m.get("status") == "live")
    return total, live


def claimed_from_listing_json(text: str) -> tuple[int, int] | None:
    m_total = re.search(r"covers (\d+) movements", text)
    m_live = re.search(r"Today, (\d+) of them", text)
    if not m_total or not m_live:
        return None
    return int(m_total.group(1)), int(m_live.group(1))


def claimed_from_taslak_md(text: str) -> tuple[int, int, int] | None:
    m = re.search(r"(\d+) hareket,\s*(\d+) açık,\s*(\d+) ölçüm bekliyor", text)
    if not m:
        return None
    return int(m.group(1)), int(m.group(2)), int(m.group(3))


def check(listing_text: str, taslak_text: str, real_total: int, real_live: int
          ) -> list[str]:
    """Saf fonksiyon — dosya okumaz, verilen metinleri gerçek sayılara karşı
    sınar. Öz-test bu fonksiyonu SAHTE metinle çağırır, gerçek dosyaya dokunmaz."""
    errors = []

    lj = claimed_from_listing_json(listing_text)
    if lj is None:
        errors.append(
            "⛔ listing.json'daki 'covers N movements'/'Today, N of them' "
            "deseni BULUNAMADI — metin değişmiş, kapı KÖRLEŞMİŞ olabilir. "
            "Deseni ya da bu aracı güncelle.")
    elif lj != (real_total, real_live):
        errors.append(
            f"⛔ listing.json: 'covers {lj[0]} movements' / 'Today, {lj[1]} "
            f"of them' diyor ama content/library.json GERÇEKTE "
            f"{real_total} toplam / {real_live} canlı. Hasat turu ilerledi, "
            f"metin ilerlemedi.")

    tk = claimed_from_taslak_md(taslak_text)
    if tk is None:
        errors.append(
            "⛔ STORE-LISTING-TASLAK.md'deki 'N hareket, N açık, N ölçüm "
            "bekliyor' deseni BULUNAMADI — metin değişmiş, kapı KÖRLEŞMİŞ "
            "olabilir. Deseni ya da bu aracı güncelle.")
    else:
        real_waiting = real_total - real_live
        if tk != (real_total, real_live, real_waiting):
            errors.append(
                f"⛔ STORE-LISTING-TASLAK.md: '{tk[0]} hareket, {tk[1]} açık, "
                f"{tk[2]} ölçüm bekliyor' diyor ama GERÇEKTE {real_total} "
                f"hareket, {real_live} açık, {real_waiting} ölçüm bekliyor.")

    return errors


def self_test() -> int:
    real_total, real_live = 31, 2  # sabit sahte katalog — dosyaya dokunmuyor

    # POZİTİF İKİZ: bugünkü gerçek metin gerçek sayılarla UYUŞMALI.
    ok_listing = "Gravita's library covers 31 movements across squats. Today, 2 of them are open."
    ok_taslak = "| 31 hareket, 2 açık, 29 ölçüm bekliyor | kaynak |"
    errs = check(ok_listing, ok_taslak, real_total, real_live)
    if errs:
        print("⛔ TERS İKİZ BAŞARISIZ: doğru metin YANLIŞLIKLA kırmızı yaktı:")
        for e in errs:
            print(f"   {e}")
        return 1
    print("✅ pozitif ikiz: doğru sayılar sessizce geçti")

    # SABOTAJ: hasat turu ilerlemiş ama metin GÜNCELLENMEMİŞ gibi davran.
    bad_listing = "Gravita's library covers 31 movements across squats. Today, 5 of them are open."
    errs = check(bad_listing, ok_taslak, real_total, real_live)
    if not errs or "listing.json" not in errs[0]:
        print("⛔ SABOTAJ YAKALANMADI: bayat 'Today, 5' sayısı kırmızı yakmadı.")
        return 1
    print(f"✅ sabotaj (listing.json sayısı bayat): yakalandı — {errs[0][:70]}…")

    bad_taslak = "| 31 hareket, 9 açık, 22 ölçüm bekliyor | kaynak |"
    errs = check(ok_listing, bad_taslak, real_total, real_live)
    if not errs or "TASLAK.md" not in errs[0]:
        print("⛔ SABOTAJ YAKALANMADI: bayat TASLAK.md satırı kırmızı yakmadı.")
        return 1
    print(f"✅ sabotaj (TASLAK.md satırı bayat): yakalandı — {errs[0][:70]}…")

    # VAKUM: desen kendisi kaybolursa (biri metni yeniden yazarsa) SESSİZCE
    # geçmemeli — kapı kör olduğunu SÖYLEMELİ.
    errs = check("Gravita counts your reps.", ok_taslak, real_total, real_live)
    if not errs or "BULUNAMADI" not in errs[0]:
        print("⛔ VAKUM YAKALANMADI: desensiz metin sessizce geçti (kapı kör "
              "olduğunu fark etmedi).")
        return 1
    print(f"✅ vakum (desen kayboldu): yakalandı — {errs[0][:70]}…")

    print("\n✅ 4/4 kapı ateşlendi (pozitif ikiz + 2 sabotaj + vakum)")
    return 0


def main() -> int:
    if "--self-test" in sys.argv:
        return self_test()

    if not LISTING.exists() or not TASLAK_MD.exists() or not LIBRARY.exists():
        print(f"⛔ beklenen dosya(lar) yok: {LISTING}, {TASLAK_MD}, {LIBRARY}")
        return 1

    real_total, real_live = real_counts()
    errors = check(LISTING.read_text(encoding="utf-8"),
                    TASLAK_MD.read_text(encoding="utf-8"),
                    real_total, real_live)
    if errors:
        for e in errors:
            print(e)
        return 1
    print(f"✅ mağaza metni katalogla UYUŞUYOR — {real_total} toplam / "
          f"{real_live} canlı / {real_total - real_live} bekliyor")
    return 0


if __name__ == "__main__":
    sys.exit(main())
