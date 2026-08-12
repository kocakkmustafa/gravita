#!/usr/bin/env python3
"""DEFTER TAZELİĞİ — `git log`taki her `G-NNN` deftere geçmiş mi?

## Neden var (G-194, 2026-08-12)

Bugün iki hatta **59 kayıt** kaybı ölçüldü: iş yapıldı, commit'lendi, rapor
edildi — **deftere geçmedi.** Sınıfı JabLab buldu:

    Bir işin YAPILMIŞ olması, KAYDEDİLMİŞ olması değildir.

JabLab'ın yakalama yöntemi *"yeni kaydı yazarken bir önceki numaranın
çapasını ara"* — ucuz ve doğru, **ama kusurun EN AĞIR hâlinde KÖR:** çapa
ancak *sıradaki kaydı yazarken* aranır; **hiç kayıt yazmadığın anı** görmez.
Gravita'nın gediği tam oydu (G-188'den sonra beş kayıt hiç yazılmadı) ve
Ostinato'nun ~50 kayıtlık, beş günlük sessizliğinde de çalışmazdı.

> ***Bir yöntem, kusurun en hafif hâlinde çalışıp en ağır hâlinde kör
> olabilir.***

Bu kapının ölçütü **alışkanlık-bağımsız**: kaynağı kayıt yazma huyu değil,
**commit'in kendisi**.

## Üç tuzak, üçü de tasarıma gömülü

1. **SENTİNEL/SABOTAJ KARIŞMASI.** Depoda `G-999` gibi kasıtlı sahte kayıtlar
   var (curated fikstürleri). Koordinatörün taraması onu *"en yüksek kayıt"*
   sandı. Bu kapı **yalnız commit BAŞLIKLARINI** okur — depo içeriğini değil —
   yani sentinel girdiye **yapısal olarak** karışamaz. Öz-test bunu kanıtlar.
2. **SÖZÜNÜ ETMEK ≠ KAYIT OLMAK.** Bir commit gövdesi *"G-182'nin ölçümü"*
   diyebilir; bu, o commit'in G-182 olduğu anlamına gelmez. Bu yüzden yalnız
   **başlığın BAŞINDAKİ** `G-NNN:` deseni sayılır — commit'in KENDİ iddiası.
   (*"Bir kavramdan söz eden cümle, o kavramın bölümü değildir."*)
3. **PAYDA.** Çıktı her zaman **kaç commit tarandı / kaç numara bulundu**
   yazar. Bugün ölçüldü ki bir özetin sayısı, kaçta kaç üstünden çıktığını
   söylemiyorsa **güven yanılsaması** üretir.

⚠️ DEFTER depo DIŞINDA (`../workspace/DEFTER.md`). Bulunamazsa bu kapı
**gürültüyle düşer** — bulunamayan bir dosya üzerinden *"gedik yok"*
raporlamak ölçüm değil körlüktür.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFTER = ROOT.parent / "workspace" / "DEFTER.md"

#: Commit'in KENDİ iddiası: başlığın BAŞINDA `G-NNN`.
_SUBJECT = re.compile(r"^(G-\d+)\b")
#: Defterdeki gerçek kayıt — İKİ BİÇİM, ve bunu ölçüm öğretti.
#:
#: ⚠️ İlk yazımım yalnız `### G-NNN` başlığını tanıyordu ve **47 yanlış
#: pozitif** üretti: defterin ESKİ bölümü kayıtları **tablo satırı** olarak
#: tutuyor (`| G-043 | görev | …`), yeni bölüm ise prose başlığı. Yani
#: ölçütüm defterin **tek biçimini** tanıyordu.
#: → *Bir kapının kapsamı, ölçtüğü şeyin BÜTÜN biçimlerini tanımalıdır;
#:   tek biçim tanıyan bir kapı, ötekini "eksik" diye raporlar.*
#: Kapı doğduğu anda kendi kusurunu bildirdi — çünkü öz-test önce
#: "taban temiz mi" diye soruyor.
_ENTRY = re.compile(r"^(?:### |\| )(G-\d+)\b", re.M)


def commit_ids(limit: int = 400) -> tuple[list[str], int]:
    out = subprocess.run(
        ["git", "-C", str(ROOT), "log", f"-{limit}", "--format=%s"],
        capture_output=True, text=True, check=True).stdout.splitlines()
    ids = [m.group(1) for line in out if (m := _SUBJECT.match(line.strip()))]
    return ids, len(out)


def defter_ids() -> list[str]:
    if not DEFTER.exists():
        raise SystemExit(
            f"⛔ DEFTER BULUNAMADI ({DEFTER}) — bulunamayan bir dosya "
            f"üzerinden 'gedik yok' raporlamak ölçüm değil KÖRLÜKTÜR.")
    return _ENTRY.findall(DEFTER.read_text(encoding="utf-8"))


def gap() -> tuple[list[str], int, int, int]:
    ids, scanned = commit_ids()
    recorded = set(defter_ids())
    missing = sorted({i for i in ids if i not in recorded},
                     key=lambda s: int(s.split("-")[1]))
    return missing, scanned, len(set(ids)), len(recorded)


def run() -> int:
    missing, scanned, claimed, recorded = gap()
    print(f"   taranan commit {scanned} · commit'in İDDİA ettiği kayıt "
          f"{claimed} · defterde {recorded}")
    if missing:
        print(f"⛔ DEFTER GEDİĞİ — {len(missing)} kayıt commit'te VAR, "
              f"defterde YOK: {', '.join(missing)}")
        print("   Bir işin YAPILMIŞ olması, KAYDEDİLMİŞ olması değildir.")
        return 1
    print("✅ defter TAZE — commit'in iddia ettiği her kayıt defterde")
    return 0


def _self_test() -> int:
    ok = True
    fired = 0

    missing, scanned, claimed, recorded = gap()
    if missing:
        print(f"   ⛔ TABAN KİRLİ — bugün zaten gedik var: {missing}")
        return 1
    print(f"   ✅ taban temiz (gedik 0, {claimed} numara / {scanned} commit)")

    # ① SUSMASI GEREKENDE SUSUYOR — yukarıda ölçüldü, taban temiz.

    # ② ÖTMESİ GEREKENDE ÖTÜYOR: defterden bir kaydı GEÇİCİ olarak düşür.
    ids, _ = commit_ids()
    if not ids:
        print("   ⛔ commit taraması BOŞ — kapı hiçbir şey ölçemez")
        return 1
    victim = ids[0]
    text = DEFTER.read_text(encoding="utf-8")
    hidden = text.replace(f"### {victim} ", f"### xx-{victim[2:]} ", 1) \
                .replace(f"| {victim} ", f"| xx-{victim[2:]} ", 1)
    hit = victim not in _ENTRY.findall(hidden)
    print(f"   {'✅' if hit else '⛔'} gedik saptama ({victim} gizlendi): "
          f"{'yakalandı' if hit else 'YAKALANMADI — SAHTE KAPI'}")
    ok = ok and hit
    fired += 1

    # ③ SENTİNEL KARIŞMIYOR: depoda G-999 VAR ama commit başlıklarında YOK.
    sentinel_in_repo = subprocess.run(
        ["git", "-C", str(ROOT), "grep", "-l", "G-999"],
        capture_output=True, text=True).stdout.strip()
    clean = "G-999" not in ids
    print(f"   {'✅' if (sentinel_in_repo and clean) else '⛔'} sentinel "
          f"karışmıyor (depoda {'VAR' if sentinel_in_repo else 'YOK'}, "
          f"girdide {'YOK' if clean else 'VAR'})")
    ok = ok and bool(sentinel_in_repo) and clean
    fired += 1

    # ④ SÖZÜNÜ ETMEK ≠ KAYIT: gövdede geçen numara girdiye GİRMEMELİ.
    body_only = _SUBJECT.match("G-182'nin ölçümüyle ilgili not")
    mention = _SUBJECT.match("bkz. G-182 — bu commit ONUN DEĞİL")
    hit4 = body_only is not None and mention is None
    print(f"   {'✅' if hit4 else '⛔'} 'sözünü etmek ≠ kayıt': "
          f"{'ayrım çalışıyor' if hit4 else 'AYRIM YOK'}")
    ok = ok and hit4
    fired += 1

    print(f"✅ {fired}/{fired} kapı ateşlendi" if ok
          else "⛔ defter tazeliği öz-testi DÜŞTÜ")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(_self_test() if "--self-test" in sys.argv else run())
