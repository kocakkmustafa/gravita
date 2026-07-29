#!/usr/bin/env python3
"""S3/S4 — VIDEO (tracking) modu ölçümü, dik→ters geçişli gerçek klipte.

Videoda statik "baş kalçadan aşağıda" değişmezi KULLANILAMAZ (gövde ekseni sürekli dönüyor).
Yerine GROUND-TRUTH GEREKTİRMEYEN fiziksel imkânsızlık ölçütü:
  - Gövde ekseni saniyede >3000° dönemez -> böyle bir sıçrama = ETİKET TERSLEMESİ.
    (Eşik °/SANİYE cinsindendir; kare-farkı dt ile normalize edilir. Kare-başına
     sabit bir eşik gizlice fps'e bağlıdır: 120°/kare 25fps'te 3000°/s demektir
     ama 60fps'te 7200°/s'ye karşılık gelir ve GERÇEK bir eksen terslemesini
     KAÇIRIR; düşük fps'te ise sahte-pozitif üretir. Kod fps'i zaten okuyordu,
     eşiği ölçeklemiyordu.)
  - Kemik uzunlukları (üst kol / uyluk) kişi sabitken ani sıçrayamaz -> uzuv takası tespiti.

Stratejiler: S1 (IMAGE/kare-kare düz) · S2 (IMAGE/kare-kare 180°) · S3 (VIDEO/tracking düz) · S4 (VIDEO/tracking 180°)
"""
import json, math, os, sys
import cv2, numpy as np
import mediapipe as mp
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision

HERE = os.path.dirname(os.path.abspath(__file__))
#: Fiziksel imkânsızlık eşiği, °/SANİYE. 120°/kare @ 25fps = 3000°/s.
#: Aile sözleşmesi 60-DSP-SOZLESMESI §1: zamana bağlı eşikler kare-başına
#: DEĞİL saniye-başına ifade edilir; aksi hâlde eşik örnekleme hızına gizlice
#: bağlanır ve aynı kod farklı fps'te farklı şey ölçer.
FLIP_DEG_PER_S = 3000.0


def mk(model, video):
    return vision.PoseLandmarker.create_from_options(vision.PoseLandmarkerOptions(
        base_options=mp_python.BaseOptions(model_asset_path=model),
        running_mode=vision.RunningMode.VIDEO if video else vision.RunningMode.IMAGE,
        num_poses=1, min_pose_detection_confidence=0.5,
        min_pose_presence_confidence=0.5, min_tracking_confidence=0.5))


def rows_of(res):
    if not res.pose_landmarks:
        return None
    return [(l.x, l.y, l.z, l.visibility, l.presence) for l in res.pose_landmarks[0]]


def back(rows):
    return None if rows is None else [(1 - x, 1 - y, z, v, p) for x, y, z, v, p in rows]


def torso_vec(L):
    sx, sy = (L[11][0] + L[12][0]) / 2, (L[11][1] + L[12][1]) / 2
    hx, hy = (L[23][0] + L[24][0]) / 2, (L[23][1] + L[24][1]) / 2
    dx, dy = hx - sx, hy - sy
    n = math.hypot(dx, dy) or 1e-9
    return dx / n, dy / n


def ang(a, b):
    d = max(-1.0, min(1.0, a[0] * b[0] + a[1] * b[1]))
    return math.degrees(math.acos(d))


def seg(L, a, b):
    return math.dist((L[a][0], L[a][1]), (L[b][0], L[b][1]))


def run(path, model_name="full", max_frames=400):
    model = os.path.join(HERE, "models", f"pose_landmarker_{model_name}.task")
    cap = cv2.VideoCapture(path)
    fps = cap.get(cv2.CAP_PROP_FPS) or 25.0
    frames = []
    while len(frames) < max_frames:
        ok, f = cap.read()
        if not ok:
            break
        h, w = f.shape[:2]
        s = 720.0 / max(h, w)
        frames.append(cv2.resize(f, (int(w * s), int(h * s)), interpolation=cv2.INTER_AREA))
    cap.release()

    def to_mp(b):
        return mp.Image(image_format=mp.ImageFormat.SRGB, data=cv2.cvtColor(b, cv2.COLOR_BGR2RGB))

    seqs = {}
    for name, video, rot in [("S1", False, False), ("S2", False, True),
                             ("S3", True, False), ("S4", True, True)]:
        lm = mk(model, video)
        out = []
        for k, f in enumerate(frames):
            img = cv2.rotate(f, cv2.ROTATE_180) if rot else f
            r = lm.detect_for_video(to_mp(img), int(k * 1000 / fps)) if video else lm.detect(to_mp(img))
            rr = rows_of(r)
            out.append(back(rr) if (rot and rr) else rr)
        seqs[name] = out
        lm.close()

    n = len(frames)
    print(f"\n=== {os.path.basename(path)} · {n} kare @ {fps:.0f}fps · model={model_name} ===")
    print(f"{'strateji':<34} {'kare':>5} {'algı%':>7} {'EKSEN SIÇRAMASI':>16} {'ort_vis':>8} {'kol_uzn_CV':>11}")
    summary = {}
    for name, label in [("S1", "IMAGE kare-kare, düz"), ("S2", "IMAGE kare-kare, 180°"),
                        ("S3", "VIDEO tracking, düz"), ("S4", "VIDEO tracking, 180°")]:
        S = seqs[name]
        det = [s is not None for s in S]
        flips = 0
        pairs = 0
        prev = None
        prev_k = None
        arms = []
        vis = []
        for k, s in enumerate(S):
            if s is None:
                prev = None
                prev_k = None
                continue
            v = torso_vec(s)
            vis.append(np.mean([s[i][3] for i in (11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28)]))
            arms.append((seg(s, 11, 13) + seg(s, 12, 14)) / 2)
            if prev is not None:
                pairs += 1
                # dt indeks farkından: kayıp kare sonrası prev sıfırlandığı için
                # bugün hep 1/fps, ama açıkça hesaplanır — ileride kare atlama
                # eklenirse eşik sessizce yanlışa dönmesin.
                dt = (k - prev_k) / fps
                if ang(prev, v) > FLIP_DEG_PER_S * dt:
                    flips += 1
            prev = v
            prev_k = k
        cv_arm = float(np.std(arms) / (np.mean(arms) or 1)) if arms else float("nan")
        summary[name] = {"detect": float(np.mean(det)), "flips": flips, "pairs": pairs,
                         "vis": float(np.mean(vis)) if vis else None, "arm_cv": cv_arm}
        print(f"{label:<34} {n:>5} {np.mean(det):>7.3f} {flips:>7}/{pairs:<8} "
              f"{(np.mean(vis) if vis else 0):>8.3f} {cv_arm:>11.3f}")
    return seqs, frames, summary


if __name__ == "__main__":
    p = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "media/vid/Gymnastics_Australia_027.theora.ogv")
    seqs, frames, s = run(p, sys.argv[2] if len(sys.argv) > 2 else "full")
    json.dump(s, open(os.path.join(HERE, "out", f"vid_{os.path.basename(p)}.json"), "w"), indent=1)
