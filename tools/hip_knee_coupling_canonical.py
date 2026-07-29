#!/usr/bin/env python3
"""hipKneeCoupling — KANONİK hesap (G-065/M-F-96 koordinatör mimari kararı).

Mimari: metrik HASAT ANINDA BİR KEZ, paylaşımlı `mocore` ile hesaplanır ve
fixture provenance'ına DAMGALANIR; tüketiciler sayıyı OKUR, yeniden
hesaplamaz. Gravita'nın kendi 2D-taraf-agnostik formülü (`hip_knee_coupling_
squat.dart`) bu yüzden EMEKLİ edildi (G-065: kamera-açısına kırılgan
çıktı — TappBrothers'ta 0,668 fark, formül-artefaktı).

Formül BİREBİR Lissom'un düzeltilmiş yolu: `mocore.measures.evaluate(...,
anatomical=True)` — hip_flexion `frameRef=proximal` (WORLD 3D, gövde-ekseni
sagittal izdüşümü), knee_flexion `frameRef=none` (WORLD 3D, izdüşümsüz,
menteşe eklem). Metrik TANIMLARI Lissom'un kendi config'inden OKUNUR
(`MetricDef.from_dict`) — elle kopyalanmaz, iki app aynı sözlüğü paylaşır.

⚠️ Metodolojik not: bu script mocore'un KENDİ güven kapısını kullanır
(`Measurement.valid`, `min_confidence` config'te — varsayılan 0,6);
Gravita'nın önceki Dart aracının FSM-tamamlanmış-tekrar ∩ StructuralValidator
penceresi (rep-FSM kesin sınırları) BURADA YOK. Bu bilinçli bir basitleştirme
— G-065'in mimari kararı "harvest-anında-bir-kez" ilkesini kuruyor, rep-FSM
pencereleme entegrasyonu (Dart↔Python) ayrı bir iş kalemi.
"""
import json
import pathlib
import sys

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
MOCORE_PIPELINE = (ROOT.parent.parent / "motion-core" / "lib" / "tools"
                   / "fixture_pipeline")
sys.path.insert(0, str(MOCORE_PIPELINE))
from mocore import geometry as geo  # noqa: E402
from mocore import measures as mz  # noqa: E402

LISSOM_METRICS = (ROOT.parent.parent / "lissom" / "app" / "config" / "metrics"
                  / "lissom-metrics.v1.json")
SQUAT_LANDMARKS = pathlib.Path.home() / "motion-harvest" / "gravita-squat" / "landmarks"
OUT = ROOT / "content" / "harvest" / "hip_knee_coupling.bodyweight_squat.json"


def load_metric(metric_id: str) -> mz.MetricDef:
    doc = json.loads(LISSOM_METRICS.read_text())
    for m in doc["metrics"]:
        if m["id"] == metric_id:
            return mz.MetricDef.from_dict(m)
    raise KeyError(f"{metric_id} lissom-metrics.v1.json'da yok")


def pearson(xs, ys):
    if len(xs) < 3:
        return float("nan")
    xs, ys = np.array(xs), np.array(ys)
    if xs.std() < 1e-9 or ys.std() < 1e-9:
        return float("nan")
    return float(np.corrcoef(xs, ys)[0, 1])


def main() -> int:
    hip_metric = load_metric("hip_flexion_right")
    knee_metric = load_metric("knee_flexion_right")

    by_channel: dict[str, dict[str, list]] = {}
    fixtures_by_channel: dict[str, list[pathlib.Path]] = {}

    for path in sorted(SQUAT_LANDMARKS.glob("*.json")):
        fx = json.loads(path.read_text())
        prov = fx.get("provenance") or {}
        channel = prov.get("channel") or "?"
        hips, knees = [], []
        for fr in fx.get("frames", []):
            if not fr.get("detected") or not fr.get("world"):
                continue
            lm_rows = fr["lm"]
            world_rows = fr["world"]
            if len(lm_rows) != 33 or len(world_rows) != 33:
                continue
            xyz = np.array([[p[0], p[1], p[2]] for p in world_rows], dtype=float)
            vis = np.array([p[3] for p in lm_rows], dtype=float)
            # v2 fixture 'presence' ayrı taşımıyor — Lissom sözleşmesi
            # visibility*presence'ın MİNİMUMUnu ister; presence yoksa 1.0
            # (aile kuralı: eksik kanal, olmayan bir kısıtlama İCAT ETMEZ).
            presence = np.ones(33, dtype=float)
            frame = geo.Frame(xyz=xyz, visibility=vis, presence=presence,
                               t_ms=float(fr["t"]))
            h = mz.evaluate(hip_metric, frame, anatomical=True)
            k = mz.evaluate(knee_metric, frame, anatomical=True)
            if h.valid and k.valid:
                hips.append(h.value)
                knees.append(k.value)
        if hips:
            acc = by_channel.setdefault(channel, {"hip": [], "knee": []})
            acc["hip"].extend(hips)
            acc["knee"].extend(knees)
            fixtures_by_channel.setdefault(channel, []).append(path)

    threshold = 0.2
    instructors = {}
    for channel, acc in sorted(by_channel.items()):
        r = pearson(acc["hip"], acc["knee"])
        gate = "pass" if (r == r and r >= threshold) else "fail"  # r==r: NaN guard
        instructors[channel] = {
            "n": len(acc["hip"]),
            "pearsonHipKnee": None if r != r else round(r, 3),
            "gate": gate,
        }
        # Damga: her fixture'ın KENDİ provenance'ına kanonik değeri yaz.
        for fpath in fixtures_by_channel[channel]:
            fx = json.loads(fpath.read_text())
            fx.setdefault("provenance", {})["hipKneeCoupling"] = {
                "pearsonHipKnee": instructors[channel]["pearsonHipKnee"],
                "n": instructors[channel]["n"],
                "method": "mocore.measures.evaluate(anatomical=True); "
                          "hip_flexion_right(frameRef=proximal)+"
                          "knee_flexion_right(frameRef=none), "
                          "lissom-metrics.v1.json",
                "computedBy": "tools/hip_knee_coupling_canonical.py (G-065/M-F-96)",
            }
            fpath.write_text(json.dumps(fx, indent=2, ensure_ascii=False) + "\n")

    out_doc = {
        "movement": "bodyweight_squat",
        "$doc": (
            "KANONİK hipKneeCoupling (G-065/M-F-96): mocore.measures.evaluate"
            "(anatomical=True) ile hasat-anında hesaplanır, her fixture'ın "
            "provenance'ına damgalanır. Gravita'nın önceki 2D-taraf-agnostik "
            "Dart formülü EMEKLİ edildi (kamera-açısına kırılgan çıktı, "
            "G-065 diferansiyel testi) — bkz. docs/gates/G-065/G-066."
        ),
        "gateThreshold": threshold,
        "method": "mocore.measures.evaluate(anatomical=True), "
                  "lissom-metrics.v1.json hip_flexion_right/knee_flexion_right",
        "instructors": instructors,
    }
    OUT.write_text(json.dumps(out_doc, indent=2, ensure_ascii=False) + "\n")
    passed = sum(1 for v in instructors.values() if v["gate"] == "pass")
    print(f"{passed}/{len(instructors)} eğitmen geçti (eşik {threshold})")
    for ch, v in instructors.items():
        print(f"  {ch}: n={v['n']} r={v['pearsonHipKnee']} -> {v['gate']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
