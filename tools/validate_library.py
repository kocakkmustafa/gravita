#!/usr/bin/env python3
"""Ders/kurs kütüphanesi (`content/library.json`) dürüstlük denetimi.

Ostinato `validate_library.py` / JabLab `library_test.dart`in ALTI kuralını
(kopyası değil, aynı gerekçeyle) uygular + Gravita'ya özel İKİ kural ekler.

İhlal = kullanıcıya verilmiş somut bir sözün çiğnenmesi → uyarı değil HATA.

Gravita'ya özel iki kural neden var:
  K7 (referans-notu kapısı): G-050/G-014 — taban-bağlı (floor) tolerans
     varyans-türetimli SAYILMAZ. Eğitmenlerin ne kadar ayrıştığı ölçülmemişken
     form notu vermek, varsayılan bir sayıyı hüküm olarak sunmaktır.
  K8 (kimlik ön koşulu kapısı): G-043 — kimlik ön koşulu yoksa rep FSM'i
     hareketi değil salınımı sayar. ⚠️ Bu kural `engine.precondition.status`
     beyanının ÜRÜN tarafındaki İLK tüketicisidir: o beyanı bugüne dek yalnız
     hasat araçları (`harvest_reps`, `build_reference`) okuyordu, ürün hiç
     sormuyordu — beşinci canlılık sorusu (G-059).

`--self-test`: sekiz kuralın her birini KASITLI ihlalle sınar. Hiç ateşlenmemiş
bir kapıya güvenmek, bu defterde defalarca avlanan desenin ta kendisidir
(G-037/G-052) — o yüzden kapılar burada ateşlenerek kanıtlanıyor.
"""
import copy
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB_PATH = ROOT / "content" / "library.json"
CATALOG_DIR = ROOT / "content" / "catalog" / "w1"


def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def check(lib, catalog_lookup):
    """Sekiz değişmezi uygular; ihlal listesi döner (boş = temiz)."""
    violations = []

    for m in lib["movements"]:
        mid = m["id"]
        cat = catalog_lookup(m.get("catalogId", mid))
        if cat is None:
            violations.append(f"{mid}: katalog girdisi YOK "
                              f"(content/catalog/w1/{m.get('catalogId', mid)}.json)")
            continue

        prov = cat.get("provenance", {})
        derived_joints = prov.get("derivedJoints", [])
        precondition = cat.get("engine", {}).get("precondition", {})
        pre_status = precondition.get("status")
        catalog_error_ids = {e["id"] for e in cat.get("formErrors", [])}
        catalog_courses = set(cat.get("courses", []))

        # K1: coming_soon harekette kurs OLAMAZ.
        if m.get("status") == "coming_soon" and m.get("courses"):
            violations.append(
                f"{mid}: coming_soon ama {len(m['courses'])} kurs listeliyor")

        # K4: honesty.notMeasured DOLU olmalı.
        if not m.get("honesty", {}).get("notMeasured"):
            violations.append(f"{mid}: honesty.notMeasured boş/yok")

        # K6: comingSoon maddeleri gerekçesiz olamaz.
        for item in m.get("comingSoonInThisMovement", []):
            if len(item.strip()) < 20:
                violations.append(
                    f"{mid}: comingSoonInThisMovement maddesi gerekçesiz "
                    f"görünüyor: '{item}'")

        if m.get("status") != "live":
            continue

        # K8: live hareket DERIVED ön koşul taşımak zorunda (G-043).
        if pre_status != "derived":
            violations.append(
                f"{mid}: status=live ama engine.precondition.status="
                f"'{pre_status}' (DERIVED olmalı) — kimlik ön koşulu yokken "
                f"rep FSM'i hareketi değil salınımı sayar (G-043)")

        # Katalog ile kütüphane kurs listesi ÇELİŞEMEZ (iki yönlü).
        lib_courses = {c["id"] for c in m.get("courses", [])}
        for extra in sorted(lib_courses - catalog_courses):
            violations.append(
                f"{mid}/{extra}: kütüphanede var, katalog courses[]'te YOK")
        for missing in sorted(catalog_courses - lib_courses):
            violations.append(
                f"{mid}/{missing}: katalog courses[]'te var, kütüphanede YOK")

        for c in m.get("courses", []):
            # K2: her kursun en az 1 dersi olmalı.
            if not c.get("lessons"):
                violations.append(f"{mid}/{c['id']}: boş kurs (0 ders)")
                continue

            for l in c["lessons"]:
                lid = l["id"]
                locked = l.get("status") == "locked"

                # K3: ders, katalogda olmayan formError'a atıf yapamaz.
                for eid in l.get("errorFocus", []):
                    if eid not in catalog_error_ids:
                        violations.append(
                            f"{lid}: var olmayan formError'a atıf: '{eid}' "
                            f"({mid} kataloğunda yok)")

                # K5: locked ders lockedReason taşımalı; tersi de tutarsız.
                if locked and not l.get("lockedReason"):
                    violations.append(f"{lid}: status=locked ama lockedReason yok")
                if not locked and l.get("lockedReason"):
                    violations.append(
                        f"{lid}: lockedReason var ama status=locked değil "
                        f"(tutarsız beyan)")

                # K7: referansa karşı form notu veren ders, hiçbir eklem
                # varyans-türetimli değilse AÇIK olamaz (G-050/G-014).
                if l.get("gradesFormAgainstReference") and not locked:
                    if not derived_joints:
                        violations.append(
                            f"{lid}: gradesFormAgainstReference=true ve AÇIK, "
                            f"ama {mid} provenance.derivedJoints BOŞ — tolerans "
                            f"tabandan geliyor, ölçümden değil (G-050/G-014)")

    return violations


def _self_test():
    """Sekiz kuralı kasıtlı ihlalle ateşle. Ateşlenmeyen kapı = sahte kapı."""
    base_lib = load(LIB_PATH)
    catalogs = {p.stem: load(p) for p in CATALOG_DIR.glob("*.json")}

    def lookup(cid):
        return copy.deepcopy(catalogs.get(cid))

    def live(lib):
        return next(m for m in lib["movements"] if m["status"] == "live")

    def soon(lib):
        return next(m for m in lib["movements"] if m["status"] == "coming_soon")

    def graded_lesson(lib):
        for c in live(lib)["courses"]:
            for l in c["lessons"]:
                if l.get("gradesFormAgainstReference"):
                    return l
        raise AssertionError("gradesFormAgainstReference dersi yok")

    def mut_k1(lib):
        soon(lib)["courses"] = [{"id": "fake", "lessons": [{"id": "fake.l"}]}]

    def mut_k2(lib):
        live(lib)["courses"][0]["lessons"] = []

    def mut_k3(lib):
        live(lib)["courses"][0]["lessons"][0]["errorFocus"] = ["no_such_error"]

    def mut_k4(lib):
        live(lib)["honesty"]["notMeasured"] = []

    def mut_k5(lib):
        graded_lesson(lib).pop("lockedReason")

    def mut_k6(lib):
        live(lib)["comingSoonInThisMovement"] = ["soon"]

    def mut_k7(lib):
        l = graded_lesson(lib)
        l.pop("status")
        l.pop("lockedReason")

    cases = [
        ("K1 coming_soon'da kurs", mut_k1, "coming_soon ama"),
        ("K2 boş kurs", mut_k2, "boş kurs"),
        ("K3 olmayan formError", mut_k3, "var olmayan formError"),
        ("K4 boş notMeasured", mut_k4, "notMeasured boş"),
        ("K5 gerekçesiz kilit", mut_k5, "lockedReason yok"),
        ("K6 gerekçesiz comingSoon", mut_k6, "gerekçesiz"),
        ("K7 dayanaksız form notu", mut_k7, "derivedJoints BOŞ"),
    ]

    ok = True
    # Temiz taban ÖNCE: mutasyonsuz kütüphane ihlalsiz olmalı, yoksa
    # aşağıdaki her testin "yakaladı" demesi anlamsızdır.
    if check(copy.deepcopy(base_lib), lookup):
        print("   ⛔ TABAN KİRLİ — mutasyonsuz kütüphane ihlal veriyor")
        return 1
    print("   ✅ taban temiz (mutasyonsuz kütüphane ihlalsiz)")

    for name, mutate, expect in cases:
        lib = copy.deepcopy(base_lib)
        mutate(lib)
        found = check(lib, lookup)
        hit = any(expect in v for v in found)
        print(f"   {'✅' if hit else '⛔'} {name}: "
              f"{'yakalandı' if hit else 'YAKALANMADI — SAHTE KAPI'}")
        ok = ok and hit

    # K8 katalog tarafından ihlal edilir (ön koşul pending), kütüphaneden değil:
    # canlı hareketin kataloğunu pending'e çevir.
    lib = copy.deepcopy(base_lib)
    live_id = live(lib)["catalogId"]

    def lookup_pending(cid):
        cat = copy.deepcopy(catalogs.get(cid))
        if cat is not None and cid == live_id:
            cat["engine"]["precondition"]["status"] = "pending"
        return cat

    found = check(lib, lookup_pending)
    hit = any("DERIVED olmalı" in v for v in found)
    print(f"   {'✅' if hit else '⛔'} K8 pending ön koşulla live: "
          f"{'yakalandı' if hit else 'YAKALANMADI — SAHTE KAPI'}")
    ok = ok and hit

    print("✅ 8/8 kapı ateşlendi" if ok else "⛔ bazı kapılar ateşlenmedi")
    return 0 if ok else 1


def main():
    if "--self-test" in sys.argv:
        print("kapı ateşleme sınaması (kasıtlı ihlaller):")
        return _self_test()

    lib = load(LIB_PATH)
    catalogs = {p.stem: load(p) for p in CATALOG_DIR.glob("*.json")}
    violations = check(lib, lambda cid: catalogs.get(cid))

    if violations:
        print(f"⛔ {len(violations)} DÜRÜSTLÜK İHLALİ:")
        for v in violations:
            print(f"   - {v}")
        return 1

    live = [m["id"] for m in lib["movements"] if m.get("status") == "live"]
    soon = [m["id"] for m in lib["movements"] if m.get("status") == "coming_soon"]
    lessons = sum(len(c.get("lessons", []))
                  for m in lib["movements"] for c in m.get("courses", []))
    locked = sum(1 for m in lib["movements"] for c in m.get("courses", [])
                 for l in c.get("lessons", []) if l.get("status") == "locked")
    print(f"✅ kütüphane denetimi TEMİZ — {len(lib['movements'])} hareket "
          f"({len(live)} canlı: {live} · {len(soon)} yakında: {soon}) · "
          f"{lessons} ders ({locked} kilitli, hepsi isimli gerekçeli) · "
          f"8 değişmez")
    return 0


if __name__ == "__main__":
    sys.exit(main())
