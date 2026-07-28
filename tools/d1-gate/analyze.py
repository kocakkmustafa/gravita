#!/usr/bin/env python3
"""G1/D1 metrik toplama — protokol §5/§8."""
import json, os, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
CRITN = ["L_sho", "R_sho", "L_elb", "R_elb", "L_wri", "R_wri",
         "L_hip", "R_hip", "L_kne", "R_kne", "L_ank", "R_ank"]


LCHAIN = ["L_sho", "L_elb", "L_wri", "L_hip", "L_kne", "L_ank"]
RCHAIN = ["R_sho", "R_elb", "R_wri", "R_hip", "R_ank", "R_kne"]


def side_gate(rec_s):
    """Ürün-gerçekçi kapı: kendine-kapanma nedeniyle uzak taraf zaten görünmez.
    Kural motoru GÖRÜNEN tarafın zincirini kullanır -> iyi tarafın min güveni."""
    if not rec_s.get("detected"):
        return None
    v = rec_s["vis_by_lm"]
    return max(min(v[k] for k in LCHAIN), min(v[k] for k in RCHAIN))


def weakest(rec_s):
    if not rec_s.get("detected"):
        return None
    v = rec_s["vis_by_lm"]
    return min(v, key=v.get)


def agg(recs, strat):
    n = len(recs)
    if n == 0:
        return None
    det = [r[strat]["detected"] for r in recs]
    d = [r for r in recs if r[strat]["detected"]]
    out = {"n": n, "detect_rate": round(float(np.mean(det)), 4)}
    if d:
        out["vis_crit"] = round(float(np.mean([r[strat]["vis_crit"] for r in d])), 4)
        out["vis_crit_median"] = round(float(np.median([r[strat]["vis_crit"] for r in d])), 4)
        out["vis_crit_min_mean"] = round(float(np.mean([r[strat]["vis_crit_min"] for r in d])), 4)
        # M4 tüm sete göre (algılanamayan = hüküm yok)
        out["gate_pass_rate"] = round(float(np.mean([r[strat].get("gate_pass", False) for r in recs])), 4)
        by = {k: round(float(np.mean([r[strat]["vis_by_lm"][k] for r in d])), 3) for k in CRITN}
        out["vis_by_lm"] = by
        sg = [side_gate(r[strat]) for r in d]
        out["side_gate_mean"] = round(float(np.mean(sg)), 4)
        # M4b tüm sete göre: algılanamayan kare = hüküm yok
        out["side_gate_rate"] = round(float(np.mean(
            [(side_gate(r[strat]) or 0) >= 0.5 for r in recs])), 4)
        wk = [weakest(r[strat]) for r in d]
        out["weakest_hist"] = {k: wk.count(k) for k in sorted(set(wk), key=lambda x: -wk.count(x))}
        out["pres_crit"] = round(float(np.mean([r[strat]["pres_crit"] for r in d])), 4)
    return out


def main(model="full", screen_file=None):
    recs = json.load(open(os.path.join(HERE, "out", model, "results.json")))
    if screen_file and os.path.exists(screen_file):
        sc = json.load(open(screen_file))
        ex = set(sc.get("exclude", []))
        rc = {int(k): v for k, v in sc.get("reclass", {}).items()}
        recs = [r for r in recs if r["i"] not in ex]
        for r in recs:
            if r["i"] in rc:
                r["bucket"] = rc[r["i"]]
        print(f"# Eleme sonrası: {len(recs)} görüntü ({len(ex)} elendi, {len(rc)} yeniden sınıflandı)\n")

    inv = [r for r in recs if r["bucket"] == "inv"]
    upr = [r for r in recs if r["bucket"] == "upr"]

    print(f"=== MODEL: {model} ===")
    rows = [
        ("UPR  · S1 (dik, düz infer)      ", agg(upr, "S1")),
        ("UPR  · S2 (dik girdi 180° döndürülmüş = UPR-ROT)", agg(upr, "S2")),
        ("INV  · S1 (ters-duruş, düz infer)", agg(inv, "S1")),
        ("INV  · S2 (ters-duruş 180° döndürülmüş = INV-ROT)", agg(inv, "S2")),
    ]
    print(f"{'set·strateji':<50} {'n':>4} {'detect':>7} {'vis_crit':>9} {'12li%':>7} {'yan_min':>8} {'YAN%':>6}")
    for name, a in rows:
        if not a:
            continue
        print(f"{name:<50} {a['n']:>4} {a['detect_rate']:>7.3f} {a.get('vis_crit',0):>9.3f} "
              f"{a.get('gate_pass_rate',0):>7.3f} {a.get('side_gate_mean',0):>8.3f} {a.get('side_gate_rate',0):>6.3f}")
    print("  (12li% = 12 kritik landmark'ın HEPSİ ≥0.5 · YAN% = görünen taraf zinciri ≥0.5 — ürün-gerçekçi kapı)")

    print("\n--- En zayıf kritik landmark dağılımı ---")
    for name, a in rows:
        if a and a.get("weakest_hist"):
            print(f"  {name.strip():<48} {a['weakest_hist']}")

    print("\n--- Kritik landmark kırılımı (ortalama visibility) ---")
    hdr = f"{'landmark':<9}" + "".join(f"{k:>10}" for k in ["UPR-S1", "UPR-ROT", "INV-S1", "INV-ROT"])
    print(hdr)
    a_us, a_ur, a_is, a_ir = agg(upr, "S1"), agg(upr, "S2"), agg(inv, "S1"), agg(inv, "S2")
    for k in CRITN:
        print(f"{k:<9}" + "".join(f"{(a or {}).get('vis_by_lm',{}).get(k,float('nan')):>10.3f}"
                                  for a in [a_us, a_ur, a_is, a_ir]))

    print("\n--- Confound ataması (protokol §8) ---")
    if a_us and a_ur and a_is and a_ir:
        base = a_us["vis_crit"]
        print(f"UPR-S1 (temel)                       : {base:.3f}")
        print(f"A etkisi (yönelim)  UPR-S1 → UPR-ROT : {base - a_ur['vis_crit']:+.3f}")
        print(f"B etkisi (poz)      UPR-S1 → INV-ROT : {base - a_ir['vis_crit']:+.3f}")
        print(f"A+B birlikte        UPR-S1 → INV-S1  : {base - a_is['vis_crit']:+.3f}")
        print(f"S2 kazancı (INV)    INV-S1 → INV-ROT : {a_ir['vis_crit'] - a_is['vis_crit']:+.3f}")

    print("\n--- S1↔S2 uyuşma (gövde-normalize landmark mesafesi, INV) ---")
    ag = [r["agree_S1_S2"]["mean_norm_dist"] for r in inv if r.get("agree_S1_S2")]
    if ag:
        ag = np.array(ag)
        print(f"n={len(ag)} · ortalama={ag.mean():.3f} · medyan={np.median(ag):.3f} · "
              f"<0.15 (uyumlu) oranı={float((ag<0.15).mean()):.3f} · >0.5 (çelişkili)={float((ag>0.5).mean()):.3f}")

    print("\n--- Ölçüm yapılamayan (poz bulunamayan) görüntüler ---")
    for r in recs:
        if not r["S1"]["detected"] or not r["S2"]["detected"]:
            print(f"  #{r['i']:>3} {r['bucket']} S1={r['S1']['detected']} S2={r['S2']['detected']}  {r['file'][:60]}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "full",
         sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "screen.json"))
