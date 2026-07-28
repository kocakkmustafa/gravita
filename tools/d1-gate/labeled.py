#!/usr/bin/env python3
"""Etiketli bindirme — eksen terslemesini GÖRÜNÜR kılar.
Kol zinciri KIRMIZI · bacak zinciri MAVİ · baş SARI halka.
İskelet şekli doğru ama renkler yer değiştirmişse = eksen terslemesi."""
import json, os, sys
import cv2

HERE = os.path.dirname(os.path.abspath(__file__))
ARM = [(11, 13), (13, 15), (12, 14), (14, 16)]          # kırmızı
LEG = [(23, 25), (25, 27), (24, 26), (26, 28)]          # mavi
TRUNK = [(11, 12), (23, 24), (11, 23), (12, 24)]        # beyaz


def draw(bgr, L, title):
    img = bgr.copy()
    h, w = img.shape[:2]
    th = max(3, w // 200)
    if L:
        for a, b in TRUNK:
            cv2.line(img, (int(L[a][0]*w), int(L[a][1]*h)), (int(L[b][0]*w), int(L[b][1]*h)), (255, 255, 255), th)
        for a, b in ARM:
            cv2.line(img, (int(L[a][0]*w), int(L[a][1]*h)), (int(L[b][0]*w), int(L[b][1]*h)), (60, 60, 255), th + 1)
        for a, b in LEG:
            cv2.line(img, (int(L[a][0]*w), int(L[a][1]*h)), (int(L[b][0]*w), int(L[b][1]*h)), (255, 160, 40), th + 1)
        for i, c, r in [(15, (60, 60, 255), 3), (16, (60, 60, 255), 3),
                        (27, (255, 160, 40), 3), (28, (255, 160, 40), 3)]:
            cv2.circle(img, (int(L[i][0]*w), int(L[i][1]*h)), th * r, c, -1)
        cv2.circle(img, (int(L[0][0]*w), int(L[0][1]*h)), th * 4, (0, 255, 255), th)
    else:
        cv2.putText(img, "POZ YOK", (14, 60), cv2.FONT_HERSHEY_SIMPLEX, 1.4, (0, 0, 255), 4)
    cv2.rectangle(img, (0, 0), (w, 34), (0, 0, 0), -1)
    cv2.putText(img, title, (6, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
    return img


if __name__ == "__main__":
    sys.path.insert(0, HERE)
    from sheet import build
    idxs = json.loads(sys.argv[1]) if len(sys.argv) > 1 else [21, 53, 9]
    recs = {r["i"]: r for r in json.load(open(os.path.join(HERE, "out/full/results.json")))}
    items = {i: it for i, it in enumerate(json.load(open(os.path.join(HERE, "media/veri-envanteri.json"))))}
    od = os.path.join(HERE, "out", "labeled")
    os.makedirs(od, exist_ok=True)
    pairs = []
    for i in idxs:
        bgr = cv2.imread(items[i]["path"])
        h, w = bgr.shape[:2]
        s = 900.0 / max(h, w)
        if s < 1.0:
            bgr = cv2.resize(bgr, (int(w*s), int(h*s)), interpolation=cv2.INTER_AREA)
        for strat, lab in [("S1", "S1 duz infer"), ("S2", "S2 180-dondurulmus")]:
            p = os.path.join(od, f"{i:03d}_{strat}.jpg")
            cv2.imwrite(p, draw(bgr, recs[i]["_lm"][strat], f"#{i} {lab}  (KOL=kirmizi  BACAK=mavi  BAS=sari)"))
            pairs.append((p, f"#{i} {strat}"))
    print(build(pairs, os.path.join(HERE, "out", "sheet_labeled.jpg"), cols=2, size=520))
