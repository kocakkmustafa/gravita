#!/usr/bin/env python3
"""hipKneeCoupling — REP-BAŞINA dağılım (koordinatör hükmü, 2026-08-12).

## Neden var

`hip_knee_coupling_canonical.py` eşiği (Pearson>=0,2) KANAL/EĞİTMEN
düzeyinde HAVUZLANMIŞ kare setleriyle doğruluyor (`n` = bir eğitmenin TÜM
derin-tekrar dilimlerinin BİRLEŞTİRİLMİŞ kare sayısı). `WindowCorrelation
Condition` (gravita_engine) o eşiği PENCERE-BAŞINA (tek rep) uyguluyor —
GERÇEK 30 klipte 27/30 kabul edildi, 3'ü havuzlanmış korelasyonu geçen
kanallardan (Calisthenicmovement×2, Tom Merrick×1) tek-rep gürültüsüyle
düştü. İki ölçüt AYNI DEĞİL: *"bir eşik, doğrulandığı ölçüm birimiyle
BİRLİKTE geçerlidir."*

Bu betik AYNI ölçütü (mocore.measures.evaluate(anatomical=True), aynı
Lissom metrik tanımları, aynı rep-fsm-kesilmiş girdi) REP-BAŞINA yeniden
koşturur — eşiği İCAT ETMEZ, dağılımın KENDİ yapısından bakar.

⛔ AİLE HÜKMÜ (2026-08-12): `ventures/motion-core/lib/tools`tan araç
KOŞULMAZ — kanonik `~/motion-worktrees/coordinator-main/tools/`. Bu betik
KANONİK `mocore`u import eder; `hip_knee_coupling_canonical.py`nin STALE
import'u (`ventures/motion-core/lib/tools/fixture_pipeline`) ayrı bir
bulgu olarak DEFTER'e düşüldü, burada DÜZELTİLMEDİ (kapsam dışı, kendi
turu).

Kullanım:
    python3 tools/hip_knee_coupling_per_rep.py
"""
import json
import pathlib
import sys

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
MOCORE_PIPELINE = (
    pathlib.Path.home() / "motion-worktrees" / "coordinator-main" / "tools"
    / "fixture_pipeline")
sys.path.insert(0, str(MOCORE_PIPELINE))
from mocore import geometry as geo  # noqa: E402
from mocore import measures as mz  # noqa: E402

LISSOM_METRICS = (ROOT.parent.parent / "lissom" / "app" / "config" / "metrics"
                  / "lissom-metrics.v1.json")
SQUAT_HARVEST = pathlib.Path.home() / "motion-harvest" / "gravita-squat"
SLICED = SQUAT_HARVEST / "landmarks-rep-sliced"
DECISIONS = ROOT / "content" / "harvest" / "decisions.bodyweight_squat.json"
IDENTITY_TRIAGE = ROOT / "content" / "harvest" / "identity-triage.bodyweight_squat.json"
THRESHOLD = 0.2  # kanal-düzeyinde doğrulanmış sayı — burada SINANIYOR, icat edilmiyor


def load_metric(metric_id):
    doc = json.loads(LISSOM_METRICS.read_text())
    for m in doc["metrics"]:
        if m["id"] == metric_id:
            return mz.MetricDef.from_dict(m)
    raise KeyError(metric_id)


def pearson(xs, ys):
    if len(xs) < 3:
        return float("nan")
    xs, ys = np.array(xs), np.array(ys)
    if xs.std() < 1e-9 or ys.std() < 1e-9:
        return float("nan")
    return float(np.corrcoef(xs, ys)[0, 1])


def rep_correlation(path, hip_metric, knee_metric):
    fx = json.loads(path.read_text())
    hips, knees = [], []
    for fr in fx.get("frames", []):
        if not fr.get("detected") or not fr.get("world"):
            continue
        lm_rows, world_rows = fr["lm"], fr["world"]
        if len(lm_rows) != 33 or len(world_rows) != 33:
            continue
        xyz = np.array([[p[0], p[1], p[2]] for p in world_rows], dtype=float)
        vis = np.array([p[3] for p in lm_rows], dtype=float)
        presence = np.ones(33, dtype=float)
        frame = geo.Frame(xyz=xyz, visibility=vis, presence=presence,
                           t_ms=float(fr["t"]))
        h = mz.evaluate(hip_metric, frame, anatomical=True)
        k = mz.evaluate(knee_metric, frame, anatomical=True)
        if h.valid and k.valid:
            hips.append(h.value)
            knees.append(k.value)
    return pearson(hips, knees), len(hips), (fx.get("provenance") or {}).get("channel")


def main():
    excluded = {e["takeId"] for e in
                json.loads(DECISIONS.read_text()).get("excludedVariantMismatch", [])}
    triage = json.loads(IDENTITY_TRIAGE.read_text())["instructors"]

    hip_metric = load_metric("hip_flexion_right")
    knee_metric = load_metric("knee_flexion_right")

    rows = []
    for path in sorted(SLICED.glob("*.json")):
        take_id = path.stem.removesuffix(".full")
        if take_id in excluded:
            continue
        r, n, channel = rep_correlation(path, hip_metric, knee_metric)
        chan_gate = (triage.get(channel) or {}).get("gate", "?")
        rows.append((take_id, channel, chan_gate, r, n))

    valid = [row for row in rows if row[3] == row[3]]  # NaN guard
    print(f"toplam dilim: {len(rows)} · geçerli-korelasyon: {len(valid)} "
          f"({len(rows) - len(valid)} NaN — <3 kare ya da sabit dizi)\n")

    rs = sorted(r for (_, _, _, r, _) in valid)
    import statistics
    print(f"REP-BAŞINA r dağılımı ({len(rs)} dilim):")
    print(f"  min={rs[0]:.3f}  p10={rs[int(len(rs)*.10)]:.3f}  "
          f"p25={rs[int(len(rs)*.25)]:.3f}  median={statistics.median(rs):.3f}  "
          f"p75={rs[int(len(rs)*.75)]:.3f}  p90={rs[int(len(rs)*.90)]:.3f}  "
          f"max={rs[-1]:.3f}")
    print(f"  mean={statistics.mean(rs):.3f}  stdev={statistics.stdev(rs):.3f}")

    above = sum(1 for r in rs if r >= THRESHOLD)
    print(f"\n{THRESHOLD} eşiğinin ÜSTÜNDE: {above}/{len(rs)} "
          f"({100*above/len(rs):.0f}%)")

    print(f"\nKANAL geçti/kaldı kırılımı (chan_gate = kanal-düzeyi hüküm, "
          f"identity-triage.bodyweight_squat.json'dan):")
    from collections import defaultdict
    by_gate = defaultdict(list)
    for (_, _, chan_gate, r, _) in valid:
        by_gate[chan_gate].append(r)
    for gate, vals in sorted(by_gate.items()):
        vals_sorted = sorted(vals)
        med = statistics.median(vals_sorted)
        below = sum(1 for v in vals_sorted if v < THRESHOLD)
        print(f"  kanal-gate={gate:5} n_dilim={len(vals):3} "
              f"median_r={med:.3f} min={vals_sorted[0]:.3f} max={vals_sorted[-1]:.3f} "
              f"eşik-ALTI={below}/{len(vals)}")

    print(f"\nEŞİĞİN ALTINDA KALAN dilimler (chan_gate=pass kanallardan, "
          f"yani 'gerçek squat ama tek-rep gürültüsü'):")
    for (take_id, channel, chan_gate, r, n) in sorted(valid, key=lambda x: x[3]):
        if r < THRESHOLD and chan_gate == "pass":
            print(f"  {take_id:28} channel={channel:22} r={r:.3f} n={n}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
