#!/usr/bin/env python3
"""Paket 1b (M-F-131 hüküm 4): squat'ın 32,26° sol-sağ farkı KAMERA AÇISININ
eseri mi?

Hipotez: squat İKİ-TARAFLI SİMETRİK bir harekettir; referansta ölçülen 32,26°
sol-sağ farkı (push_up: 5,16°) gerçek bir asimetri değil, yandan çekimde
gövdenin kameraya göre dönmesinden doğan 2B-İZDÜŞÜM artefaktı olabilir
(G-061'in kneeAngleAsymmetry bulgusunun referans düzeyindeki karşılığı).

Yöntem: kaynak-başına iki nicelik ölçülüp KORELE edilir.
  1. `shoulder_line_foreshortening` — mocore'un KENDİ metriği (Lissom
     `lissom-metrics.v1.json`'dan BİREBİR okunur, kod kopyalanmaz).
     Frontal düzleme izdüşen omuz genişliği / gövde uzunluğu. Gövde kameradan
     UZAĞA döndükçe KÜÇÜLÜR. `frameRef: "camera"` → `anatomical=False` ile
     çağrılmak ZORUNDA: anatomik mod tam bu bilgiyi tanım gereği siler
     (M-F-53), o modda metrik sabitlenir/ölür.
  2. Kaynak-başına ortalama |sol-sağ| eklem farkı — Dart tarafında kanonik
     `ReferenceCli.prepareTake` ile ölçüldü (`per_source_mirror_diff.dart`).

Korelasyon NEGATİF çıkarsa (daha fazla ön-kısalma → daha fazla sol-sağ farkı)
32° projeksiyon artefaktı olarak açıklanır. Bu durumda ölçüm yalnız squat'ı
değil **MOCORE_ANATOMICAL varsayılan-çevirme** kurucu-kaleminin kanıt
zincirini de besler (M-F-56).

⚠️ Metriğin kendi uyarısı (config'de yazılı): transvers-düzlem rotasyonu tek
kameradan güvenilir biçimde geri çıkarılamaz — bu DOLAYLI bir vekildir, açı
değil. Nitel bant olarak okunur.
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
SLICED = (pathlib.Path.home() / "motion-harvest" / "gravita-squat"
          / "landmarks-rep-sliced")
MIRROR_IN = ROOT / "content" / "harvest" / "mirror-diff-by-source.bodyweight_squat.json"
OUT = ROOT / "content" / "harvest" / "camera-angle.bodyweight_squat.json"


def load_metric(metric_id: str) -> mz.MetricDef:
    doc = json.loads(LISSOM_METRICS.read_text())
    for m in doc["metrics"]:
        if m["id"] == metric_id:
            return mz.MetricDef.from_dict(m)
    raise KeyError(f"{metric_id} lissom-metrics.v1.json'da yok")


def pearson(xs, ys):
    if len(xs) < 3:
        return float("nan")
    xs, ys = np.asarray(xs, float), np.asarray(ys, float)
    if xs.std() < 1e-9 or ys.std() < 1e-9:
        return float("nan")
    return float(np.corrcoef(xs, ys)[0, 1])


def main() -> int:
    metric = load_metric("shoulder_line_foreshortening")
    if metric.frame_ref != "camera":
        print(f"⛔ beklenmeyen frameRef: {metric.frame_ref} (camera olmalı) — "
              "anatomik modda bu metrik ölür, ölçüm anlamsızlaşır")
        return 1

    by_channel: dict[str, list[float]] = {}
    takes: dict[str, int] = {}

    for path in sorted(SLICED.glob("*.json")):
        fx = json.loads(path.read_text())
        channel = (fx.get("provenance") or {}).get("channel") or "?"
        vals = []
        for fr in fx.get("frames", []):
            if not fr.get("detected") or not fr.get("world"):
                continue
            lm_rows, world_rows = fr["lm"], fr["world"]
            if len(lm_rows) != 33 or len(world_rows) != 33:
                continue
            xyz = np.array([[p[0], p[1], p[2]] for p in world_rows], dtype=float)
            vis = np.array([p[3] for p in lm_rows], dtype=float)
            frame = geo.Frame(xyz=xyz, visibility=vis,
                              presence=np.ones(33, dtype=float),
                              t_ms=float(fr["t"]))
            # anatomical=False ZORUNLU: metrik KAMERA çerçevesinde tanımlı.
            m = mz.evaluate(metric, frame, anatomical=False)
            if m.valid:
                vals.append(m.value)
        if vals:
            by_channel.setdefault(channel, []).extend(vals)
            takes[channel] = takes.get(channel, 0) + 1

    mirror = json.loads(MIRROR_IN.read_text())["sources"]

    rows = []
    for ch in sorted(by_channel):
        fs = float(np.mean(by_channel[ch]))
        md = mirror.get(ch, {}).get("meanLeftRightDiffDeg")
        rows.append({
            "channel": ch,
            "takes": takes[ch],
            "frames": len(by_channel[ch]),
            "shoulderLineForeshortening": round(fs, 4),
            "meanLeftRightDiffDeg": md,
        })

    paired = [(r["shoulderLineForeshortening"], r["meanLeftRightDiffDeg"])
              for r in rows if r["meanLeftRightDiffDeg"] is not None]
    r_val = pearson([p[0] for p in paired], [p[1] for p in paired])

    print(f"{'kaynak':24} {'take':>5} {'kare':>7} "
          f"{'ön-kısalma':>11} {'sol-sağ°':>9}")
    for r in rows:
        md = r["meanLeftRightDiffDeg"]
        print(f"{r['channel'][:24]:24} {r['takes']:5} {r['frames']:7} "
              f"{r['shoulderLineForeshortening']:11.4f} "
              f"{(f'{md:.2f}' if md is not None else '—'):>9}")

    print(f"\nbaseline (config): {metric.baseline}  "
          f"(1,0'a yakın = kameraya DÖNÜK · küçük = yana DÖNMÜŞ)")
    print(f"pearson(ön-kısalma, sol-sağ farkı) = {r_val:.3f}  (n={len(paired)})")

    # Hüküm VERMİYORUM — yön ve güç raporlanır, yorum koordinatörde.
    if np.isnan(r_val):
        verdict = "ölçülemedi (varyans yok ya da n<3)"
    elif r_val <= -0.5:
        verdict = ("GÜÇLÜ NEGATİF — ön-kısalma arttıkça (omuz çizgisi "
                   "daraldıkça) sol-sağ farkı BÜYÜYOR: 32°'nin izdüşüm "
                   "artefaktı olduğu hipotezini DESTEKLER")
    elif r_val <= -0.3:
        verdict = ("ORTA NEGATİF — hipotezle aynı yönde ama zayıf; n küçük, "
                   "tek başına hüküm taşımaz")
    elif r_val >= 0.3:
        verdict = ("POZİTİF — hipotezin TERSİ yönde; 32° kamera açısıyla "
                   "açıklanamıyor, başka bir sebep aranmalı")
    else:
        verdict = ("İLİŞKİ YOK (|r|<0,3) — kamera açısı bu farkı açıklamıyor; "
                   "32° başka bir mekanizmadan geliyor")
    print(f"okuma: {verdict}")

    out = {
        "$measurement": "per-source shoulder_line_foreshortening (mocore, "
                        "camera frame) vs per-source mean |left-right| joint "
                        "angle difference (canonical ReferenceCli.prepareTake)",
        "$why": "Squat referansı meanLeftRightDiffDeg=32,26° verdi (push_up "
                "5,16°). Squat iki-taraflı simetrik; bu büyüklük 2B izdüşüm "
                "artefaktı olabilir (M-F-131 hüküm 4).",
        "$metricSource": "lissom-metrics.v1.json → shoulder_line_foreshortening "
                         "(kind=distance_norm, plane=frontal, frameRef=camera)",
        "$anatomicalMode": False,
        "$anatomicalNote": "anatomical=False ZORUNLU: anatomik projeksiyon "
                           "kamera-yaw bilgisini tanım gereği siler (M-F-53), "
                           "o modda bu metrik ölür (A9 ölü-metrik kapısı).",
        "$metricCaveat": "Config'in kendi uyarısı: transvers rotasyon tek "
                         "kameradan güvenilir geri çıkarılamaz — DOLAYLI vekil, "
                         "açı değil; nitel bant olarak okunur.",
        "$thinEvidence": (f"n={len(paired)} kaynak — korelasyon istatistiksel "
                          f"olarak ZAYIF güçte; yön göstergesi olarak okunmalı, "
                          f"kesin hüküm olarak DEĞİL."),
        "pearsonForeshorteningVsMirrorDiff": (None if np.isnan(r_val)
                                              else round(r_val, 3)),
        "reading": verdict,
        "sources": rows,
    }
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n")
    print(f"\nyazıldı: {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
