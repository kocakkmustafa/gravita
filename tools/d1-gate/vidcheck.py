#!/usr/bin/env python3
"""Videoda ters-duruş ANINI etiketli bindirmeyle gözle doğrula (KOL=kırmızı, BACAK=mavi, BAŞ=sarı)."""
import os, sys
import cv2
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vid import run
from labeled import draw
from sheet import build

HERE = os.path.dirname(os.path.abspath(__file__))

path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "media/vid/Gymnastics_Australia_027.theora.ogv")
strat = sys.argv[2] if len(sys.argv) > 2 else "S3"
start, step, count = (int(x) for x in (sys.argv[3:6] if len(sys.argv) > 5 else (40, 6, 12)))

seqs, frames, _ = run(path, "full")
od = os.path.join(HERE, "out", "vidlabeled")
os.makedirs(od, exist_ok=True)
pairs = []
for j in range(count):
    k = start + j * step
    if k >= len(frames):
        break
    p = os.path.join(od, f"{strat}_{k:04d}.jpg")
    cv2.imwrite(p, draw(frames[k], seqs[strat][k], f"kare {k} {strat}"))
    pairs.append((p, f"kare {k}"))
print(build(pairs, os.path.join(HERE, "out", f"sheet_vid_{strat}.jpg"), cols=4, size=360))
