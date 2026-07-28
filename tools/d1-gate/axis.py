#!/usr/bin/env python3
"""EKSEN TERSLİĞİ ölçümü — D1'in gerçek tehlike modu.

Bulgu: iskelet ŞEKLİ doğru çizilirken landmark ETİKETLERİ baş-ayak ekseninde
takas olabiliyor (kol zinciri bacağa, bacak zinciri kola oturuyor). Çizim
neredeyse simetrik olduğu için GÖZLE fark edilmez; ama kural motoru "dirsek
açısı" diye DİZ açısını ölçer -> kendinden emin ve tamamen yanlış koçluk.

Ters-duruş setinde YAPISAL DOĞRULUK (ground truth by construction):
  - baş kalçadan AŞAĞIDA olmalı (görüntü koordinatında nose.y > hip_mid.y)
  - el-üstü duruşlarda bilekler omuzdan AŞAĞIDA olmalı
"""
import json, os
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))


def mid(L, a, b, ax=1):
    return (L[a][ax] + L[b][ax]) / 2


def axis_flags(L):
    if L is None:
        return None
    nose_y = L[0][1]
    sho_y, hip_y = mid(L, 11, 12), mid(L, 23, 24)
    wri_y, ank_y = mid(L, 15, 16), mid(L, 27, 28)
    return {
        # ters-duruşta beklenen: baş kalçadan AŞAĞIDA (y büyük)
        "head_below_hips": bool(nose_y > hip_y),
        # ters-duruşta beklenen: ayak bilekleri kalçadan YUKARIDA (y küçük)
        "ankles_above_hips": bool(ank_y < hip_y),
        # el-üstü duruşta beklenen: bilekler omuzdan AŞAĞIDA
        "wrists_below_shoulders": bool(wri_y > sho_y),
        "torso_dir": float(sho_y - hip_y),
    }


def main(model="full"):
    sc = json.load(open(os.path.join(HERE, "screen.json")))
    ex, rc = set(sc["exclude"]), {int(k): v for k, v in sc["reclass"].items()}
    recs = [r for r in json.load(open(os.path.join(HERE, f"out/{model}/results.json"))) if r["i"] not in ex]
    for r in recs:
        if r["i"] in rc:
            r["bucket"] = rc[r["i"]]

    print("=== EKSEN TERSLİĞİ (yapısal doğruluk) ===\n")
    for bucket, expect in [("inv", True), ("upr", False)]:
        rows = [r for r in recs if r["bucket"] == bucket]
        print(f"--- {bucket.upper()} (n={len(rows)}) — beklenen: baş kalçadan "
              f"{'AŞAĞIDA' if expect else 'YUKARIDA'} ---")
        for strat in ["S1", "S2"]:
            ok = err = nod = 0
            bad = []
            for r in rows:
                f = axis_flags(r["_lm"][strat])
                if f is None:
                    nod += 1
                    continue
                good = f["head_below_hips"] == expect
                if good:
                    ok += 1
                else:
                    err += 1
                    bad.append(r["i"])
            n = ok + err
            print(f"  {strat}: doğru eksen {ok}/{n} = {ok/n:.1%}"
                  f"   EKSEN HATASI {err} ({err/n:.1%}) {bad}   pozsuz={nod}")
        print()

    print("--- Strateji birleşimi (INV): en az biri doğru eksen verdi mi? ---")
    rows = [r for r in recs if r["bucket"] == "inv"]
    both_ok = only1 = only2 = neither = 0
    disagree = []
    for r in rows:
        f1, f2 = axis_flags(r["_lm"]["S1"]), axis_flags(r["_lm"]["S2"])
        a = f1 and f1["head_below_hips"]
        b = f2 and f2["head_below_hips"]
        if a and b:
            both_ok += 1
        elif a:
            only1 += 1; disagree.append((r["i"], "yalnız S1"))
        elif b:
            only2 += 1; disagree.append((r["i"], "yalnız S2"))
        else:
            neither += 1; disagree.append((r["i"], "İKİSİ DE YANLIŞ"))
    n = len(rows)
    print(f"  ikisi de doğru : {both_ok}/{n} ({both_ok/n:.1%})")
    print(f"  yalnız S1      : {only1}")
    print(f"  yalnız S2      : {only2}")
    print(f"  ikisi de yanlış: {neither} ({neither/n:.1%})")
    print(f"  ayrışan kareler: {disagree}")


if __name__ == "__main__":
    import sys; main(sys.argv[1] if len(sys.argv)>1 else "full")
