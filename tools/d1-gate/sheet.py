#!/usr/bin/env python3
"""Kontakt sayfası üretici — gözle eleme (§4 veri geçerliliği) ve M5 (§5 elle denetim) için."""
import json, os, sys
import cv2, numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))


def tile(img, size, label):
    h, w = img.shape[:2]
    s = min(size / w, size / h)
    img = cv2.resize(img, (max(1, int(w * s)), max(1, int(h * s))))
    canvas = np.full((size, size, 3), 30, np.uint8)
    y, x = (size - img.shape[0]) // 2, (size - img.shape[1]) // 2
    canvas[y:y + img.shape[0], x:x + img.shape[1]] = img
    cv2.rectangle(canvas, (0, 0), (size, 26), (0, 0, 0), -1)
    cv2.putText(canvas, label, (5, 19), cv2.FONT_HERSHEY_SIMPLEX, 0.62, (60, 255, 255), 2)
    cv2.rectangle(canvas, (0, 0), (size - 1, size - 1), (90, 90, 90), 1)
    return canvas


def build(paths_labels, out, cols=5, size=280):
    tiles = []
    for p, lab in paths_labels:
        img = cv2.imread(p)
        if img is None:
            img = np.full((size, size, 3), 60, np.uint8)
        tiles.append(tile(img, size, lab))
    rows = []
    for i in range(0, len(tiles), cols):
        chunk = tiles[i:i + cols]
        while len(chunk) < cols:
            chunk.append(np.full((size, size, 3), 30, np.uint8))
        rows.append(np.hstack(chunk))
    cv2.imwrite(out, np.vstack(rows))
    return out


def raw_sheets(per=25, cols=5, size=280):
    items = json.load(open(os.path.join(HERE, "media", "veri-envanteri.json")))
    outs = []
    for start in range(0, len(items), per):
        chunk = items[start:start + per]
        pl = [(it["path"], f"#{start + j} {it['bucket']}") for j, it in enumerate(chunk)]
        o = os.path.join(HERE, "out", f"sheet_raw_{start:03d}.jpg")
        build(pl, o, cols, size)
        outs.append(o)
    return outs


def overlay_sheets(model="full", bucket="inv", strat="S1", idxs=None, per=6, cols=3, size=460):
    recs = json.load(open(os.path.join(HERE, "out", model, "results.json")))
    recs = [r for r in recs if r["bucket"] == bucket and (idxs is None or r["i"] in idxs)]
    od = os.path.join(HERE, "out", model, "overlay")
    outs = []
    for start in range(0, len(recs), per):
        chunk = recs[start:start + per]
        pl = []
        for r in chunk:
            f = f"{r['i']:03d}_{r['bucket']}_{strat}.jpg"
            v = r[strat].get("vis_crit")
            pl.append((os.path.join(od, f), f"#{r['i']} {strat} vis={v:.2f}" if v else f"#{r['i']} {strat} YOK"))
        o = os.path.join(HERE, "out", f"sheet_{bucket}_{strat}_{start:03d}.jpg")
        build(pl, o, cols, size)
        outs.append(o)
    return outs


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "raw"
    if mode == "raw":
        print("\n".join(raw_sheets()))
    else:
        idxs = json.loads(sys.argv[4]) if len(sys.argv) > 4 else None
        print("\n".join(overlay_sheets("full", sys.argv[2], sys.argv[3], idxs)))
