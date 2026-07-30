#!/usr/bin/env python3
"""Kopyalama imzası ANATOMİK modda da duruyor mu? (M-F-172 hüküm 3)

G-078A kamera çerçevesinde ölçtü: push_up'ta |L−R| görünürlük düştükçe
KÜÇÜLÜYOR (kopyalama imzası POZİTİF), squat'ta BÜYÜYOR (dürüst ölçüm).
O turda "anatomik-mod karşılaştırması KOŞULMADI, zincirin o ayağı eksik"
diye açıkça şerh düşmüştüm — bu araç o ayağı kapatıyor.

MOCORE_ANATOMICAL kurucu-kalemi için asıl soru: anatomik projeksiyon
push_up↔squat AYRIMCILIĞINI koruyor mu, yoksa siliyor mu? Anatomik mod
kamera-yaw bilgisini tanım gereği kaldırır (M-F-53); eğer imza kamera
çerçevesine BAĞLIYSA anatomik modda kaybolur ve o zaman "anatomik moda
geçiş bu teşhis yeteneğini maliyet olarak alır" demek gerekir.

⚠️ SOL metrik tanımı İCAT EDİLMEDİ: Lissom metrik dosyasında yalnız `_right`
sürümleri var ama ikisi de `"mirror": true` beyanı taşıyor — yani tanım
kendisi aynalanabilir olduğunu söylüyor. Sol ikizi landmark ADLARINI
RIGHT_→LEFT_ çevirerek kuruyorum: AYNI formül, aynalanmış landmark kümesi.

SALT RAPOR — eşik yok, kapı yok, hüküm yok.
"""
import json
import pathlib
import sys

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT.parent.parent / "motion-core" / "lib" / "tools"
                      / "fixture_pipeline"))
from mocore import geometry as geo  # noqa: E402
from mocore import measures as mz  # noqa: E402

METRICS = (ROOT.parent.parent / "lissom" / "app" / "config" / "metrics"
           / "lissom-metrics.v1.json")
POOLS = {
    "push_up": pathlib.Path.home() / "motion-harvest/gravita/landmarks",
    "bodyweight_squat": (pathlib.Path.home()
                         / "motion-harvest/gravita-squat/landmarks-rep-sliced"),
}
# Lm indeksleri (BlazePose): omuz 11/12 · kalça 23/24 · diz 25/26 · ayak 27/28
SIDE_IDS = {"right": (12, 24, 26, 28), "left": (11, 23, 25, 27)}
EDGES = [0.0, 0.2, 0.4, 0.6, 0.8, 1.01]


def load_pair(metric_id: str):
    doc = json.loads(METRICS.read_text())
    src = next(m for m in doc["metrics"] if m["id"] == metric_id)
    if not src.get("mirror"):
        raise SystemExit(f"{metric_id} `mirror: true` taşımıyor — aynalanamaz")
    right = mz.MetricDef.from_dict(src)
    mirrored = dict(src)
    mirrored["id"] = metric_id.replace("_right", "_left")
    mirrored["points"] = [p.replace("RIGHT_", "LEFT_") for p in src["points"]]
    return right, mz.MetricDef.from_dict(mirrored)


def band(v: float) -> int:
    for i in range(len(EDGES) - 1):
        if EDGES[i] <= v < EDGES[i + 1]:
            return i
    return len(EDGES) - 2


def main() -> int:
    pairs = [load_pair("hip_flexion_right"), load_pair("knee_flexion_right")]
    report = {
        "$probe": "copying signature under camera vs ANATOMICAL frame "
                  "(M-F-172 hüküm 3) — REPORT ONLY",
        "$signature": "|L-R| SHRINKS as far-limb visibility DROPS => "
                      "manufactured agreement (model copies the unseen limb).",
        "$leftMetricNote": "Lissom dosyasında yalnız `_right` var; ikisi de "
                           "`mirror: true` beyanı taşıdığı için sol ikiz "
                           "landmark ADLARI RIGHT_→LEFT_ çevrilerek kuruldu — "
                           "aynı formül, aynalanmış küme. Formül İCAT EDİLMEDİ.",
        "$bands": EDGES,
        "movements": {},
    }

    for mv, d in POOLS.items():
        if not d.is_dir():
            continue
        acc = {m: {"sum": np.zeros(len(EDGES) - 1), "n": np.zeros(len(EDGES) - 1, int)}
               for m in ("camera", "anatomical")}
        for path in sorted(d.glob("*.json")):
            fx = json.loads(path.read_text())
            for fr in fx.get("frames", []):
                if not fr.get("detected") or not fr.get("world"):
                    continue
                lm, w = fr["lm"], fr["world"]
                if len(lm) != 33 or len(w) != 33:
                    continue
                xyz = np.array([[p[0], p[1], p[2]] for p in w], dtype=float)
                vis = np.array([p[3] for p in lm], dtype=float)
                frame = geo.Frame(xyz=xyz, visibility=vis,
                                  presence=np.ones(33), t_ms=float(fr["t"]))
                far = min(float(vis[list(SIDE_IDS["right"])].min()),
                          float(vis[list(SIDE_IDS["left"])].min()))
                bi = band(far)
                for mode, anat in (("camera", False), ("anatomical", True)):
                    for right, left in pairs:
                        a = mz.evaluate(right, frame, anatomical=anat)
                        b = mz.evaluate(left, frame, anatomical=anat)
                        if not (a.valid and b.valid):
                            continue
                        acc[mode]["sum"][bi] += abs(a.value - b.value)
                        acc[mode]["n"][bi] += 1

        print(f"\n=== {mv}")
        print(f"{'görünürlük bandı':20} {'KAMERA |L−R|':>14} {'n':>9} "
              f"{'ANATOMİK |L−R|':>16} {'n':>9}")
        out = []
        for i in range(len(EDGES) - 1):
            row = {"band": f"{EDGES[i]:.1f}-{min(EDGES[i+1],1.0):.1f}"}
            cells = []
            for mode in ("camera", "anatomical"):
                n = int(acc[mode]["n"][i])
                v = float(acc[mode]["sum"][i] / n) if n else None
                row[mode] = None if v is None else round(v, 2)
                row[f"{mode}Samples"] = n
                cells.append(f"{('—' if v is None else f'{v:.2f}'):>14} {n:>9}")
            out.append(row)
            print(f"{row['band']:20} {cells[0]} {cells[1]}")

        def trend(mode: str) -> str:
            filled = [r for r in out if (r[f"{mode}Samples"] or 0) >= 100
                      and r[mode] is not None]
            if len(filled) < 2:
                return "ölçülemedi"
            lo, hi = filled[0][mode], filled[-1][mode]
            return (f"{'KÜÇÜLÜYOR' if lo < hi else 'BÜYÜYOR'} "
                    f"({lo:.2f}° → {hi:.2f}°) → imza "
                    f"{'POZİTİF' if lo < hi else 'NEGATİF'}")

        cam, ana = trend("camera"), trend("anatomical")
        print(f"  KAMERA  : {cam}")
        print(f"  ANATOMİK: {ana}")
        report["movements"][mv] = {"bands": out, "cameraTrend": cam,
                                  "anatomicalTrend": ana}

    dest = ROOT / "content" / "harvest" / "anatomical-copying-signature.json"
    dest.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(f"\nyazıldı: {dest.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
