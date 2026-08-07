#!/usr/bin/env python3
"""Referans artefaktı, hangi POZ MODELİYLE üretildiğini YAZMAK ZORUNDA.

Choreia (C-198) ölçtü: referansları `heavy` varyantla hasat edilmiş, uygulaması
`full` ship ediyor → **kullanıcının ölçümü referansla kıyaslanamıyor**. Ve bu
sessiz bir kusur: her iki taraf da kendi içinde tutarlı görünür.

Bu hatta ölçüldü — uygulama `full` ✓, ama **hasat tarafında hiç kayıt yoktu.**
Üçüncü sonuç, ve Choreia'nın cümlesiyle en sinsisi:

> *"Kayıt bir yerde durup taşınmıyorsa, yokluğu kadar tehlikeli — çünkü
> «bilinmiyor» sanılıyor, oysa «bakılmadı»ydı."*

Eski iki artefakt `status: UNRECORDED` taşıyor: geriye dönük TAHMİN EDİLMEDİ,
çünkü tahmin kaydın yerine geçtiği anda "ölçüldü" sanılır. Muafiyet bir LİSTE
değil — `status` alanında okunan bir KOŞUL, yani yeni bir artefakt eskisinin
muafiyetine sığınamaz.

    python3 tools/validate_reference_model.py
    python3 tools/validate_reference_model.py --self-test
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HARVEST = ROOT / "content" / "harvest"
#: Uygulamanın ship ettiği varyant — `lib/app/pose_model.dart` ile AYNI olmalı.
APP_MODEL = "pose_landmarker_full/float16/1"


def check(docs):
    bad = []
    for name, d in docs.items():
        mp = d.get("modelProvenance")
        if not isinstance(mp, dict):
            bad.append(f"{name}: `modelProvenance` YOK — bu artefaktın hangi "
                       f"modelle üretildiği kayıtsız")
            continue
        status, mid = mp.get("status"), mp.get("modelId")
        if status == "UNRECORDED":
            if mid is not None:
                bad.append(f"{name}: UNRECORDED ama `modelId` dolu — durum ile "
                           f"içerik çelişiyor")
            continue
        if not mid:
            bad.append(f"{name}: `modelId` boş ve durum UNRECORDED değil")
        elif mid != APP_MODEL:
            bad.append(f"{name}: referans `{mid}` ile üretilmiş ama uygulama "
                       f"`{APP_MODEL}` ship ediyor — kullanıcının ölçümü "
                       f"referansla KIYASLANAMAZ")
    return bad


def load():
    return {p.name: json.loads(p.read_text(encoding="utf-8"))
            for p in sorted(HARVEST.glob("reference.*.json"))}


def self_test():
    import copy
    base = load()
    ok = True
    if check(copy.deepcopy(base)):
        print("   ⛔ TABAN KİRLİ")
        return 1
    print("   ✅ taban temiz")

    def mut_missing(d):
        next(iter(d.values())).pop("modelProvenance")

    def mut_mismatch(d):
        next(iter(d.values()))["modelProvenance"] = {
            "status": "RECORDED", "modelId": "pose_landmarker_heavy/float16/1"}

    def mut_lying_exemption(d):
        # ⭐ TERS İKİZ: muafiyeti "her şeye UNRECORDED yaz" diye kullanmak.
        # Durum UNRECORDED ama modelId dolu → çelişki, ötmeli.
        next(iter(d.values()))["modelProvenance"] = {
            "status": "UNRECORDED", "modelId": "pose_landmarker_heavy/float16/1"}

    for name, mut, expect in (
            ("kayıt YOK", mut_missing, "kayıtsız"),
            ("VARYANT UYUŞMUYOR (heavy≠full)", mut_mismatch, "KIYASLANAMAZ"),
            ("TERS İKİZ: sahte muafiyet", mut_lying_exemption, "çelişiyor")):
        d = copy.deepcopy(base)
        mut(d)
        found = check(d)
        hit = any(expect in v for v in found)
        print(f"   {'✅' if hit else '⛔'} {name}: "
              f"{'yakalandı' if hit else 'YAKALANMADI — SAHTE KAPI'}")
        ok = ok and hit
    return 0 if ok else 1


def main():
    if "--self-test" in sys.argv:
        return self_test()
    docs = load()
    if bad := check(docs):
        for b in bad:
            print(f"⛔ MODEL KAYDI: {b}")
        return 1
    unrec = sum(1 for d in docs.values()
                if d["modelProvenance"].get("status") == "UNRECORDED")
    print(f"✅ referans model kaydı TEMİZ — {len(docs)} artefakt "
          f"({unrec} KAYITSIZ, geriye dönük tahmin edilmedi) · "
          f"uygulama: {APP_MODEL}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
