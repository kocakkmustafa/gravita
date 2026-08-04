#!/usr/bin/env python3
"""G-112/G-113 — A5: anatomik mod küme-çözülme testi.

Ön-kayıt: `docs/gates/G-112-A5-ON-KAYIT.md`. Eşikler/çapalar ORADA sabit.
PROBE: hüküm üretmez, dışlama önermez, yayımlı artefakta yazmaz.

Anatomik/planar farkı mocore'un KANONİK `mz.evaluate(..., anatomical=)`
kodundan gelir (yerel checkout, salt okuma). Metrik TANIMLARI burada kurulur.
"""
import json
import math
import os
import random
import sys
from pathlib import Path

MOCORE = Path.home() / "Documents/YULAlab-AI/ventures/motion-core/lib/tools/fixture_pipeline"
sys.path.insert(0, str(MOCORE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import numpy as np  # noqa: E402
from mocore import measures as mz, geometry as geo  # noqa: E402
from mode_naming_probe import auc, ovl, pct, HARVEST  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
N_PERM = 200
# L-197 süpürmesi: varsayılan STRICT (valid okunur). STRICT=0 eski kirli
# davranışı geri getirir — yalnız kontrollü karşılaştırma için.
STRICT = os.environ.get("A5_STRICT", "1") == "1"

# --- G-112 çapaları (ÖLÇÜLÜ, icat edilmedi) ---
ALT_SEP, ALT_OVL = 0.077, 0.40      # ayrışmayan bant (B3)
UST_SEP, UST_OVL = 0.30, 0.40       # ayrışan bant (B4 sınıfı)

METRICS = [
    # value_range: L-107 sınıfı fiziksel aralık beyanı (M-F-244 madde 3).
    # ÜÇ EKLEM AÇISI için sınır ANATOMİK: üç noktalı açı tanım gereği
    # [0,180]; bu bir eşik değil, geometrinin kendisi — icat edilmedi.
    mz.MetricDef(id="hip_flexion", kind="angle3",
                 points=("LEFT_SHOULDER", "LEFT_HIP", "LEFT_KNEE"),
                 plane="sagittal", frame_ref="proximal",
                 value_range=(0.0, 180.0)),
    mz.MetricDef(id="knee_flexion", kind="angle3",
                 points=("LEFT_HIP", "LEFT_KNEE", "LEFT_ANKLE"),
                 plane="sagittal", frame_ref="none",
                 value_range=(0.0, 180.0)),
    mz.MetricDef(id="trunk_tilt", kind="angle_vertical",
                 points=("LEFT_HIP", "LEFT_SHOULDER"),
                 plane="sagittal", frame_ref="gravityYaw",
                 value_range=(0.0, 180.0)),
    # POZİTİF KONTROL — anatomik çerçevede TANIM GEREĞİ sabitleşmeli (A9).
    # Oransal ölçü: omuz arası ÷ gövde — üst sınır 3,0 cömert ama sonlu
    # (gövde uzunluğu ~0'a düşünce oran patlar; G-115'te 5,27 ölçüldü).
    mz.MetricDef(id="POSCTL_shoulder_foreshortening", kind="distance_norm",
                 points=("LEFT_SHOULDER", "RIGHT_SHOULDER"),
                 plane="frontal", frame_ref="camera",
                 value_range=(0.0, 3.0)),
]


def deepest_frame(path):
    """Dip karesi = diz açısının en küçük olduğu kare (G-110 ile aynı ölçüt)."""
    d = json.loads(path.read_text())
    best, best_k = None, 1e9
    for f in d["frames"]:
        if not f.get("detected") or not f.get("world"):
            continue
        p = f["world"]
        if len(p) < 33:
            continue
        a = np.array(p, dtype=float)
        v1, v2 = a[23] - a[25], a[27] - a[25]
        n1, n2 = np.linalg.norm(v1), np.linalg.norm(v2)
        if n1 < 1e-9 or n2 < 1e-9:
            continue
        k = math.degrees(math.acos(max(-1, min(1, float(v1 @ v2) / (n1 * n2)))))
        if k < best_k:
            best_k, best = k, (a, f)
    if best is None:
        return None
    a, f = best
    lmv = f.get("lm") or []
    vis = np.array([p[3] if len(p) > 3 else 1.0 for p in lmv], dtype=float) \
        if len(lmv) == 33 else np.ones(33)
    pres = np.array([p[4] if len(p) > 4 else 1.0 for p in lmv], dtype=float) \
        if len(lmv) == 33 else np.ones(33)
    return geo.Frame(xyz=a, visibility=vis, presence=pres, t_ms=float(f.get("t", 0)))


def main():
    a4 = json.loads(Path(sys.argv[1]).read_text())
    pub = json.loads((ROOT / "content/harvest/reference.bodyweight_squat.json").read_text())

    def contrib(art):
        r = art["result"]
        ids = {t["id"] for t in art["takes"]}
        for k in ("excludedOutlierIds", "excludedIneligibleIds",
                  "excludedUnattestedIds", "excludedNoMeasurableFrameIds"):
            ids -= set(r.get(k) or [])
        return ids

    A, B = contrib(pub), contrib(a4)
    ov = A & B
    A, B = A - ov, B - ov
    print(f"küme M-THENX={len(A)} · M-KBOGES={len(B)} (örtüşen {len(ov)} çıkarıldı)")
    print(f"valid kapısı: {'AÇIK (STRICT)' if STRICT else 'KAPALI (kirli — kontrol koşumu)'}")
    print(f"mocore: {MOCORE}\n")

    vals = {m.id: {"M-THENX": {False: [], True: []},
                   "M-KBOGES": {False: [], True: []}} for m in METRICS}
    invalid = {m.id: 0 for m in METRICS}
    unmeasurable = 0
    for label, ids in (("M-THENX", A), ("M-KBOGES", B)):
        for tid in sorted(ids):
            f = HARVEST / f"{tid}.full.json"
            if not f.exists():
                unmeasurable += 1
                continue
            fr = deepest_frame(f)
            if fr is None:
                unmeasurable += 1
                continue
            for m in METRICS:
                for anat in (False, True):
                    try:
                        r = mz.evaluate(m, fr, anatomical=anat)
                    except Exception:
                        continue
                    v = float(r.value)
                    # L-197: `evaluate` güven eşiği altında da DEĞER üretir ama
                    # `valid=False` döner ve çağıran taraf onu skora KATMAMALIDIR
                    # (doc'un kendi cümlesi). İlk yazışımda bu okunmuyordu;
                    # STRICT=0 ile eski (kirli) davranış kontrollü karşılaştırma
                    # için korunuyor — L-187 tarzı kirli↔temiz tablosu.
                    if STRICT and not r.valid:
                        invalid[m.id] += 1
                        continue
                    if math.isfinite(v):
                        vals[m.id][label][anat].append(v)
    if unmeasurable:
        print(f"⚠️  ölçülemeyen take: {unmeasurable} — payda küçüldü, "
              f"sessizce atlanmadı\n")

    rows = []
    for m in METRICS:
        for anat in (False, True):
            xs = vals[m.id]["M-THENX"][anat]
            ys = vals[m.id]["M-KBOGES"][anat]
            if len(xs) < 3 or len(ys) < 3:
                continue
            o, a = ovl(xs, ys), auc(xs, ys)
            sep = abs(a - 0.5)
            pool = xs + ys
            rng = random.Random(20260804)
            null = []
            for _ in range(N_PERM):
                rng.shuffle(pool)
                null.append(abs(auc(pool[:len(xs)], pool[len(xs):]) - 0.5))
            p = sum(1 for s in null if s >= sep) / len(null)
            if sep <= ALT_SEP and o >= ALT_OVL:
                band = "ALT (ayrışmayan)"
            elif sep >= UST_SEP and o <= UST_OVL:
                band = "ÜST (ayrışan)"
            else:
                band = "ARA"
            rows.append({
                "metric": m.id, "frameRef": m.frame_ref,
                "frameBasis": "anatomical" if anat else "camera",
                "n_thenx": len(xs), "n_kboges": len(ys),
                "OVL": round(o, 3), "AUC": round(a, 3),
                "separation": round(sep, 3), "permutation_p": round(p, 4),
                "thenx_p10_p50_p90": [round(pct(xs, q), 2) for q in (10, 50, 90)],
                "kboges_p10_p50_p90": [round(pct(ys, q), 2) for q in (10, 50, 90)],
                "band": band,
            })

    print(f"{'metrik':34}{'mod':12}{'OVL':>7}{'AUC':>7}{'ayrışma':>9}{'perm-p':>8}  bant")
    for r in rows:
        print(f"  {r['metric']:32}{r['frameBasis']:12}{r['OVL']:7.3f}"
              f"{r['AUC']:7.3f}{r['separation']:9.3f}{r['permutation_p']:8.4f}"
              f"  {r['band']}")

    # --- POZİTİF KONTROL: mod GERÇEKTEN bağlı mı? ---
    # ⚠️ G-112 ön-kaydındaki POSCTL tasarımı HATALIYDI: `camera` frame_ref'li
    # metrik anatomik moddan TANIM GEREĞİ etkilenmez (evaluate yalnız
    # gravityYaw/proximal/none dallarına girer), yani "çökmesi" beklenemezdi.
    # Doğru kontrol dolaylı ayrışma değil, HAM DEĞERİN kendisi: aynı karede
    # aynı metrik iki modda farklı sayı veriyor mu?
    print()
    print("POZİTİF KONTROL — ham değer kayması (mod bağlı mı?):")
    bound = []
    for m in METRICS:
        for label in ("M-THENX", "M-KBOGES"):
            c = vals[m.id][label][False]
            a = vals[m.id][label][True]
            n = min(len(c), len(a))
            if n < 3:
                continue
            shift = sum(abs(c[i] - a[i]) for i in range(n)) / n
            bound.append((m.id, m.frame_ref, label, shift))
            break
    for mid, fref, label, shift in bound:
        state = "DEĞİŞİYOR" if shift > 1e-9 else "SABİT (mod bu sınıfa dokunmuyor)"
        print(f"  {mid:32} frame_ref={fref:11} |Δ| ort={shift:8.4f}°  {state}")
    movers = [b for b in bound if b[3] > 1e-9]
    print()
    if movers:
        print(f"  ✅ {len(movers)}/{len(bound)} metrik iki modda FARKLI değer "
              f"veriyor → anatomik mod BAĞLI; bu metriklerin sonuçları okunabilir.")
        print("  ⚠️  SABİT kalanlar okunmaz: onlarda 'fark yok' bulgusu, modun "
              "o sınıfa dokunmadığının tekrarıdır (M-F-230).")
    else:
        print("  ⛔ HİÇBİR metrik değişmedi → mod BAĞLANMAMIŞ (M-F-230): "
              "A5 GEÇERSİZ")
    out_posctl = [{"metric": b[0], "frame_ref": b[1], "meanAbsShiftDeg": round(b[3], 5),
                   "modeBound": b[3] > 1e-9} for b in bound]

    out = {
        "$probe": "G-112 A5 anatomik küme-çözülme — PROBE, hüküm üretmez",
        "$mocore": str(MOCORE), "$harvest": str(HARVEST),
        "$anchors": {"ALT_SEP": ALT_SEP, "ALT_OVL": ALT_OVL,
                     "UST_SEP": UST_SEP, "UST_OVL": UST_OVL,
                     "$source": "G-112 ön-kayıt (B3/B4 ölçümleri), değiştirilmedi"},
        "clusters": {"M-THENX": len(A), "M-KBOGES": len(B),
                     "unmeasurable": unmeasurable},
        "strictValid": STRICT,
        "invalidDropped": invalid,
        "positiveControl": out_posctl,
        "$positiveControlNote": (
            "G-112 ön-kaydındaki POSCTL tasarımı hatalıydı: camera frame_ref'li "
            "metrik anatomik moddan tanım gereği etkilenmez. Doğru kontrol ham "
            "değer kaymasıdır (meanAbsShiftDeg)."),
        "rows": rows,
    }
    for a in sys.argv[2:]:
        if a.startswith("--out="):
            Path(a[6:]).write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n")
            print(f"\nyazıldı: {a[6:]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
