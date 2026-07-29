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

Sayının dayanağı — `windowBasis` (G-066/M-F-101):
  confidence-gate — girdi HAM fixture'lar; yalnız mocore'un kendi frame-başı
                    güven kapısı uygulanır. Kimlik-KAPILAMASI için
                    PROVISIONAL sayılır (rep-FSM doğrulaması YOK — bir video
                    hiç squat içermese bile görünür/net kareleri varsa sayı
                    üretir). Triyaj-bilgisi olarak serbest.
  rep-fsm         — girdi `tool/slice_deep_reps_squat.dart`'ın kestiği
                    fixture'lar (ürünün rep-FSM'i formErrors.shallow_depth
                    eşiğini geçen TEKRARLARI önceden seçti). Kimlik-KAPILAMASI
                    için GEÇERLİ sayılır — Python'a FSM portu YOK, iki aracın
                    SIRALAMASI (önce Dart keser, sonra bu script işler) yeterli.

Kullanım:
  python hip_knee_coupling_canonical.py --dir landmarks --window-basis confidence-gate
  python hip_knee_coupling_canonical.py --dir landmarks-rep-sliced --window-basis rep-fsm
"""
import argparse
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
SQUAT_HARVEST = pathlib.Path.home() / "motion-harvest" / "gravita-squat"
RAW_LANDMARKS = SQUAT_HARVEST / "landmarks"
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


def all_channels(directory: pathlib.Path) -> set[str]:
    out = set()
    for path in directory.glob("*.json"):
        fx = json.loads(path.read_text())
        out.add((fx.get("provenance") or {}).get("channel") or "?")
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=str(RAW_LANDMARKS),
                    help="işlenecek fixture dizini (ham veya rep-dilimli)")
    ap.add_argument("--window-basis", choices=["confidence-gate", "rep-fsm"],
                    required=True)
    ap.add_argument("--stamp", action="store_true",
                    help="her fixture'ın provenance'ına damga yaz")
    args = ap.parse_args()
    src_dir = pathlib.Path(args.dir).expanduser()

    hip_metric = load_metric("hip_flexion_right")
    knee_metric = load_metric("knee_flexion_right")

    by_channel: dict[str, dict[str, list]] = {}
    fixtures_by_channel: dict[str, list[pathlib.Path]] = {}

    for path in sorted(src_dir.glob("*.json")):
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
            "windowBasis": args.window_basis,
        }
        if args.stamp:
            for fpath in fixtures_by_channel[channel]:
                fx = json.loads(fpath.read_text())
                fx.setdefault("provenance", {})["hipKneeCoupling"] = {
                    "pearsonHipKnee": instructors[channel]["pearsonHipKnee"],
                    "n": instructors[channel]["n"],
                    "windowBasis": args.window_basis,
                    "method": "mocore.measures.evaluate(anatomical=True); "
                              "hip_flexion_right(frameRef=proximal)+"
                              "knee_flexion_right(frameRef=none), "
                              "lissom-metrics.v1.json",
                    "computedBy": "tools/hip_knee_coupling_canonical.py (G-065/M-F-96/G-066)",
                }
                fpath.write_text(json.dumps(fx, indent=2, ensure_ascii=False) + "\n")

    # Roster HAM dizinden gelir (rep-dilimli dizinde sıfır-dilimli eğitmen
    # hiç dosya bırakmaz — "yok" ile "veri yok" karışmasın diye tam roster
    # ayrı taşınır).
    roster = all_channels(RAW_LANDMARKS)
    no_signal = sorted(roster - set(instructors))
    for ch in no_signal:
        instructors[ch] = {"n": 0, "pearsonHipKnee": None, "gate": "noSignal",
                            "windowBasis": args.window_basis}

    if args.window_basis == "rep-fsm":
        out_doc = {
            "movement": "bodyweight_squat",
            "$doc": (
                "KANONİK hipKneeCoupling, windowBasis=rep-fsm (G-066/M-F-101): "
                "girdi tool/slice_deep_reps_squat.dart'ın kestiği DERİN-TEKRAR "
                "fixture'ları — ürünün kendi rep-FSM'i formErrors.shallow_depth "
                "eşiğini (rom_bottom_angle≤110°) geçen tekrarları önceden seçti. "
                "Kimlik-KAPILAMASI için GEÇERLİ sayı budur. FSM hiç tamamlanmış "
                "derin tekrar üretmeyen eğitmen (School of Calisthenics, Vast "
                "Fitness Academy, Minus The Gym) dürüstçe noSignal — dilim "
                "üretilmediği için bu script'e hiç girmediler (G-043 disiplini: "
                "'ölçemedim' demek, yanlış ölçmekten üstündür)."
            ),
            "gateThreshold": threshold,
            "windowBasis": "rep-fsm",
            "method": "mocore.measures.evaluate(anatomical=True) + "
                      "tool/slice_deep_reps_squat.dart (rep-FSM ön-kesici), "
                      "lissom-metrics.v1.json hip_flexion_right/knee_flexion_right",
            "instructors": instructors,
        }
        OUT.write_text(json.dumps(out_doc, indent=2, ensure_ascii=False) + "\n")
        print(f"YAZILDI: {OUT} (windowBasis=rep-fsm, kimlik-kapılama kaynağı)")

    passed = sum(1 for v in instructors.values() if v["gate"] == "pass")
    total = len(instructors)
    print(f"[{args.window_basis}] {passed}/{total} eğitmen geçti (eşik {threshold})")
    for ch, v in sorted(instructors.items()):
        print(f"  {ch}: n={v['n']} r={v['pearsonHipKnee']} -> {v['gate']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
