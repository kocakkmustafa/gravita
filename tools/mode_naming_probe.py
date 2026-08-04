#!/usr/bin/env python3
"""G-110/G-111 — iki squat modunu AYIRAN boyutu isimlendirme sondası.

Ön-kayıt: `docs/gates/G-110-MOD-ISIMLENDIRME-ON-KAYIT.md` (eşikler ORADA
sabitlendi, burada tekrar edilir ama DEĞİŞTİRİLMEZ).

PROBE'dur: hiçbir dışlama/varyant hükmü üretmez (M-F-47). Yayımlı hiçbir
artefakta yazmaz — çıktı stdout + `--out` JSON.
"""
import json
import math
import os
import random
import sys
from pathlib import Path

HARVEST = Path.home() / "motion-harvest/gravita-squat/landmarks-rep-sliced"
ROOT = Path(__file__).resolve().parent.parent

# --- ön-kayıttaki eşikler (G-110) — DEĞİŞTİRİLMEZ ---
OVL_SEP, AUC_SEP = 0.40, 0.30      # AYRIŞTIRICI
OVL_NULL, AUC_NULL = 0.70, 0.10    # AYRIŞTIRMAYAN
N_PERM = 200

# --- Fiziksel aralık beyanları (M-F-244 madde 3, L-107 sınıfı) ---
# G-115'te B4'te 5,27 ölçüldü: gövde uzunluğu ~0'a düşünce oran patlıyor.
# Aralık beyanı olmayan türetilmiş ölçü, izleme artefaktını sonuca sızdırır.
# Açılar için sınır ANATOMİK ([0,180] üç-noktalı açı tanımı), oranlar için
# cömert-ama-sonlu; ikisi de gerekçeli, icat değil.
VALUE_RANGE = {
    "B1_stance_width": (0.0, 4.0),         # ayak arası ÷ omuz arası
    "B2_depth_knee_deg": (0.0, 180.0),     # üç-noktalı açı tanımı
    "B3_hip_knee_ratio": (0.0, 5.0),       # açı ÷ açı
    "B4_shoulder_foreshortening": (0.05, 2.0),  # G-115'te türetildi
}

# MediaPipe landmark indeksleri
L_SH, R_SH, L_HIP, R_HIP = 11, 12, 23, 24
L_KNEE, R_KNEE, L_ANK, R_ANK = 25, 26, 27, 28


def dist(a, b, dims=2):
    return math.sqrt(sum((a[i] - b[i]) ** 2 for i in range(dims)))


def angle(a, b, c, dims=2):
    """b köşesindeki açı (derece), yalnız ilk `dims` boyut."""
    v1 = [a[i] - b[i] for i in range(dims)]
    v2 = [c[i] - b[i] for i in range(dims)]
    n1 = math.sqrt(sum(x * x for x in v1))
    n2 = math.sqrt(sum(x * x for x in v2))
    if n1 < 1e-9 or n2 < 1e-9:
        return float("nan")
    cos = max(-1.0, min(1.0, sum(v1[i] * v2[i] for i in range(dims)) / (n1 * n2)))
    return math.degrees(math.acos(cos))


def mid(a, b):
    return [(a[i] + b[i]) / 2 for i in range(3)]


def take_dims(path, space="world"):
    """Bir take'in dip karesindeki dört aday boyutu. z KULLANILMAZ (G-107)."""
    d = json.loads(path.read_text())
    frames = [f for f in d["frames"] if f.get("detected") and f.get(space)]
    if not frames:
        return None

    # Dip = diz açısının EN KÜÇÜK olduğu kare (en bükük).
    best, best_knee = None, 1e9
    for f in frames:
        p = f[space]
        if len(p) < 33:
            continue
        kn = []
        for hip, knee, ank in ((L_HIP, L_KNEE, L_ANK), (R_HIP, R_KNEE, R_ANK)):
            a = angle(p[hip], p[knee], p[ank])
            if not math.isnan(a):
                kn.append(a)
        if not kn:
            continue
        m = sum(kn) / len(kn)
        if m < best_knee:
            best_knee, best = m, p
    if best is None:
        return None

    p = best
    sh_w = dist(p[L_SH], p[R_SH])
    ank_w = dist(p[L_ANK], p[R_ANK])
    sh_mid, hip_mid = mid(p[L_SH], p[R_SH]), mid(p[L_HIP], p[R_HIP])
    torso = dist(sh_mid, hip_mid)

    hip_ang = []
    for sh, hip, knee in ((L_SH, L_HIP, L_KNEE), (R_SH, R_HIP, R_KNEE)):
        a = angle(p[sh], p[hip], p[knee])
        if not math.isnan(a):
            hip_ang.append(a)
    hip_f = sum(hip_ang) / len(hip_ang) if hip_ang else float("nan")

    out = {
        "B1_stance_width": ank_w / sh_w if sh_w > 1e-9 else float("nan"),
        "B2_depth_knee_deg": best_knee,
        "B3_hip_knee_ratio": hip_f / best_knee if best_knee > 1e-9 else float("nan"),
        "B4_shoulder_foreshortening": sh_w / torso if torso > 1e-9 else float("nan"),
    }
    clean = {}
    for k, v in out.items():
        if math.isnan(v):
            continue
        lo, hi = VALUE_RANGE.get(k, (float("-inf"), float("inf")))
        if not (lo <= v <= hi):
            continue  # aralık dışı = izleme artefaktı, sonuca KATILMAZ
        clean[k] = v
    return clean


def auc(xs, ys):
    """Mann-Whitney AUC: P(x>y) + 0.5*P(x==y). Dağılım varsayımı yok."""
    if not xs or not ys:
        return float("nan")
    gt = eq = 0
    for x in xs:
        for y in ys:
            if x > y:
                gt += 1
            elif x == y:
                eq += 1
    return (gt + 0.5 * eq) / (len(xs) * len(ys))


def ovl(xs, ys, bins=20):
    """Histogram kesişim alanı: 0=tam ayrık, 1=tam örtüşük."""
    if not xs or not ys:
        return float("nan")
    lo, hi = min(xs + ys), max(xs + ys)
    if hi - lo < 1e-12:
        return 1.0
    w = (hi - lo) / bins

    def hist(v):
        h = [0] * bins
        for x in v:
            h[min(bins - 1, int((x - lo) / w))] += 1
        return [c / len(v) for c in h]

    return sum(min(a, b) for a, b in zip(hist(xs), hist(ys)))


def pct(v, q):
    if not v:
        return float("nan")
    s = sorted(v)
    i = (len(s) - 1) * q / 100
    lo, hi = int(math.floor(i)), int(math.ceil(i))
    return s[lo] if lo == hi else s[lo] + (s[hi] - s[lo]) * (i - lo)


def verdict(o, a):
    sep = abs(a - 0.5)
    if o <= OVL_SEP and sep >= AUC_SEP:
        return "AYRIŞTIRICI"
    if o >= OVL_NULL or sep <= AUC_NULL:
        return "AYRIŞTIRMAYAN"
    return "BELİRSİZ"


def main():
    pub = json.loads((ROOT / "content/harvest/reference.bodyweight_squat.json").read_text())
    a4_path = sys.argv[1] if len(sys.argv) > 1 else None
    if not a4_path:
        print("kullanım: mode_naming_probe.py <a4_artefakt.json> [--out=...]")
        return 2
    a4 = json.loads(Path(a4_path).read_text())

    def contrib(art):
        r = art["result"]
        allids = {t["id"] for t in art["takes"]}
        for k in ("excludedOutlierIds", "excludedIneligibleIds",
                  "excludedUnattestedIds", "excludedNoMeasurableFrameIds"):
            allids -= set(r.get(k) or [])
        return allids

    m_thenx, m_kboges = contrib(pub), contrib(a4)
    overlap = m_thenx & m_kboges
    m_thenx, m_kboges = m_thenx - overlap, m_kboges - overlap
    print(f"küme M-THENX={len(m_thenx)} · M-KBOGES={len(m_kboges)} "
          f"· çıkarılan örtüşen={len(overlap)}")

    space = os.environ.get("PROBE_SPACE", "world")
    print(f"uzay: {space} (z kullanılmıyor)\n")

    vals = {"M-THENX": {}, "M-KBOGES": {}}
    missing = 0
    for label, ids in (("M-THENX", m_thenx), ("M-KBOGES", m_kboges)):
        for tid in sorted(ids):
            # take id -> dosya adı: "<Kanal>_w<N>_r<M>" -> aynı ad + .full.json
            f = HARVEST / f"{tid}.full.json"
            if not f.exists():
                missing += 1
                continue
            dims = take_dims(f, space)
            if not dims:
                missing += 1
                continue
            for k, v in dims.items():
                vals[label].setdefault(k, []).append(v)
    if missing:
        print(f"⚠️  ölçülemeyen take: {missing} (dosya yok / kare yok) — "
              f"payda bu kadar küçüldü, sessizce atlanmadı\n")

    rows = []
    for dim in sorted(set(vals["M-THENX"]) | set(vals["M-KBOGES"])):
        xs, ys = vals["M-THENX"].get(dim, []), vals["M-KBOGES"].get(dim, [])
        if len(xs) < 3 or len(ys) < 3:
            continue
        o, a = ovl(xs, ys), auc(xs, ys)

        # permütasyon kontrolü — etiketler karıştırılır (M-F-230)
        pool = xs + ys
        rng = random.Random(20260804)
        null_sep = []
        for _ in range(N_PERM):
            rng.shuffle(pool)
            null_sep.append(abs(auc(pool[:len(xs)], pool[len(xs):]) - 0.5))
        real_sep = abs(a - 0.5)
        p = sum(1 for s in null_sep if s >= real_sep) / len(null_sep)

        rows.append({
            "dimension": dim, "n_thenx": len(xs), "n_kboges": len(ys),
            "OVL": round(o, 3), "AUC": round(a, 3),
            "separation": round(real_sep, 3),
            "permutation_p": round(p, 4),
            "perm_mean_separation": round(sum(null_sep) / len(null_sep), 3),
            "thenx_p10_p50_p90": [round(pct(xs, q), 3) for q in (10, 50, 90)],
            "kboges_p10_p50_p90": [round(pct(ys, q), 3) for q in (10, 50, 90)],
            "verdict": verdict(o, a),
        })

    print(f"{'boyut':30}{'OVL':>7}{'AUC':>7}{'ayrışma':>9}{'perm-p':>8}  hüküm")
    for r in rows:
        print(f"  {r['dimension']:28}{r['OVL']:7.3f}{r['AUC']:7.3f}"
              f"{r['separation']:9.3f}{r['permutation_p']:8.4f}  {r['verdict']}")
    print()
    for r in rows:
        print(f"  {r['dimension']:28} THENX p10/50/90={r['thenx_p10_p50_p90']} "
              f"· KBOGES={r['kboges_p10_p50_p90']}")

    out = {
        "$probe": "G-110 mod isimlendirme — PROBE, hüküm üretmez (M-F-47)",
        "$frameBasis": "camera",
        "$space": space,
        "$harvest": str(HARVEST),
        "$thresholds": {"OVL_SEP": OVL_SEP, "AUC_SEP": AUC_SEP,
                        "OVL_NULL": OVL_NULL, "AUC_NULL": AUC_NULL,
                        "$source": "G-110 ön-kayıt, değiştirilmedi"},
        "clusters": {"M-THENX": len(m_thenx), "M-KBOGES": len(m_kboges),
                     "overlapRemoved": len(overlap), "unmeasurable": missing},
        "dimensions": rows,
    }
    for a in sys.argv[2:]:
        if a.startswith("--out="):
            Path(a[6:]).write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n")
            print(f"\nyazıldı: {a[6:]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
