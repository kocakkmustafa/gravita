#!/usr/bin/env python3
"""G1/D1 ölçüm koşumu — MediaPipe Pose Landmarker, ters-duruş fizibilitesi.

Protokol: ventures/gravita/app/docs/gates/G1-D1-PROTOKOL.md
Stratejiler: S1 (giriş olduğu gibi) · S2 (giriş 180° döndürülmüş, landmark geri döndürülür)
Setler: INV (gerçek ters-duruş) · UPR (dik kontrol) · UPR-ROT (yazılımla döndürülmüş dik) · INV-ROT
"""
import json, os, sys, math
import cv2, numpy as np
import mediapipe as mp
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision

HERE = os.path.dirname(os.path.abspath(__file__))
CRIT = [11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28]  # omuz/dirsek/bilek/kalça/diz/ayak bileği
NAMES = {11: "L_sho", 12: "R_sho", 13: "L_elb", 14: "R_elb", 15: "L_wri", 16: "R_wri",
         23: "L_hip", 24: "R_hip", 25: "L_kne", 26: "R_kne", 27: "L_ank", 28: "R_ank"}
EDGES = [(11, 12), (11, 13), (13, 15), (12, 14), (14, 16), (11, 23), (12, 24), (23, 24),
         (23, 25), (25, 27), (24, 26), (26, 28), (0, 11), (0, 12), (27, 31), (28, 32)]
GATE = 0.5  # protokol §5 M4: min(kritik visibility) >= 0.5 -> hüküm verilebilir


def make_landmarker(model_path, mode="image"):
    base = mp_python.BaseOptions(model_asset_path=model_path)
    opts = vision.PoseLandmarkerOptions(
        base_options=base,
        running_mode=vision.RunningMode.IMAGE if mode == "image" else vision.RunningMode.VIDEO,
        num_poses=1,
        min_pose_detection_confidence=0.5,
        min_pose_presence_confidence=0.5,
        min_tracking_confidence=0.5,
        output_segmentation_masks=False,
    )
    return vision.PoseLandmarker.create_from_options(opts)


def to_mp(bgr):
    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    return mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)


def landmarks_to_rows(res):
    """MediaPipe sonucunu [(x,y,z,vis,pres)] listesine çevirir; poz yoksa None."""
    if not res.pose_landmarks:
        return None
    lms = res.pose_landmarks[0]
    return [(l.x, l.y, l.z, l.visibility, l.presence) for l in lms]


def rotate_back(rows):
    """180° döndürülmüş girişte bulunan landmark'ları orijinal kadraja taşır.
    180° in-plane rotasyon YANSIMA DEĞİLDİR -> sol/sağ semantiği korunur, indeks takası yok."""
    return [(1.0 - x, 1.0 - y, z, v, p) for (x, y, z, v, p) in rows]


def torso_len(rows):
    sm = ((rows[11][0] + rows[12][0]) / 2, (rows[11][1] + rows[12][1]) / 2)
    hm = ((rows[23][0] + rows[24][0]) / 2, (rows[23][1] + rows[24][1]) / 2)
    return math.dist(sm, hm)


def metrics(rows):
    if rows is None:
        return {"detected": False}
    vis = [rows[i][3] for i in CRIT]
    pres = [rows[i][4] for i in CRIT]
    return {
        "detected": True,
        "vis_crit": float(np.mean(vis)),
        "vis_crit_min": float(np.min(vis)),
        "pres_crit": float(np.mean(pres)),
        "gate_pass": bool(np.min(vis) >= GATE),
        "vis_by_lm": {NAMES[i]: round(rows[i][3], 4) for i in CRIT},
        "torso": round(torso_len(rows), 5),
    }


def agreement(a, b):
    """S1 ile S2 landmark uyuşması: gövde uzunluğuna normalize ortalama mesafe."""
    if a is None or b is None:
        return None
    t = max(torso_len(a), torso_len(b), 1e-6)
    d = [math.dist((a[i][0], a[i][1]), (b[i][0], b[i][1])) / t for i in CRIT]
    return {"mean_norm_dist": float(np.mean(d)), "max_norm_dist": float(np.max(d))}


def draw(bgr, rows, label=""):
    img = bgr.copy()
    h, w = img.shape[:2]
    if rows is not None:
        for a, b in EDGES:
            pa = (int(rows[a][0] * w), int(rows[a][1] * h))
            pb = (int(rows[b][0] * w), int(rows[b][1] * h))
            cv2.line(img, pa, pb, (0, 230, 255), max(2, w // 320))
        for i, (x, y, z, v, p) in enumerate(rows):
            c = (0, 255, 0) if v >= 0.5 else (0, 0, 255)
            r = max(3, w // 220) if i in CRIT else max(2, w // 400)
            cv2.circle(img, (int(x * w), int(y * h)), r, c, -1)
    else:
        cv2.putText(img, "NO POSE", (12, 44), cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 0, 255), 3)
    if label:
        cv2.rectangle(img, (0, 0), (w, 30), (0, 0, 0), -1)
        cv2.putText(img, label, (6, 22), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
    return img


def run(model_name="full"):
    model = os.path.join(HERE, "models", f"pose_landmarker_{model_name}.task")
    inv_path = os.path.join(HERE, "media", "veri-envanteri.json")
    items = json.load(open(inv_path))
    lm = make_landmarker(model, "image")
    outdir = os.path.join(HERE, "out", model_name)
    os.makedirs(os.path.join(outdir, "overlay"), exist_ok=True)
    results = []

    for idx, it in enumerate(items):
        p = it["path"]
        bgr = cv2.imread(p)
        if bgr is None:
            continue
        # uzun kenarı 900'e sabitle (protokol: koşullar sabit)
        h, w = bgr.shape[:2]
        s = 900.0 / max(h, w)
        if s < 1.0:
            bgr = cv2.resize(bgr, (int(w * s), int(h * s)), interpolation=cv2.INTER_AREA)
        rot = cv2.rotate(bgr, cv2.ROTATE_180)

        r_s1 = landmarks_to_rows(lm.detect(to_mp(bgr)))          # S1: olduğu gibi
        r_s2_raw = landmarks_to_rows(lm.detect(to_mp(rot)))      # S2: 180° girişte
        r_s2 = rotate_back(r_s2_raw) if r_s2_raw else None

        rec = {
            "i": idx, "bucket": it["bucket"], "title": it["title"], "file": os.path.basename(p),
            "license": it["license"], "source": it.get("descriptionurl"),
            "S1": metrics(r_s1), "S2": metrics(r_s2),
            "agree_S1_S2": agreement(r_s1, r_s2),
        }
        # ham landmark'lar (fixture şeması uyumlu türetilmiş veri)
        rec["_lm"] = {"S1": r_s1, "S2": r_s2}
        results.append(rec)

        tag = f"{idx:03d}_{it['bucket']}"
        cv2.imwrite(os.path.join(outdir, "overlay", f"{tag}_S1.jpg"),
                    draw(bgr, r_s1, f"#{idx} {it['bucket'].upper()} S1"))
        cv2.imwrite(os.path.join(outdir, "overlay", f"{tag}_S2.jpg"),
                    draw(bgr, r_s2, f"#{idx} {it['bucket'].upper()} S2(rot)"))
        # döndürülmüş SET kaydı (UPR-ROT / INV-ROT): döndürülmüş görüntüye S1 uygulamak
        # = orijinal görüntüye S2 uygulamak (sayısal olarak eş) -> ayrı koşum gerekmez.

    with open(os.path.join(outdir, "results.json"), "w") as f:
        json.dump(results, f, indent=1)
    print(f"{len(results)} görüntü ölçüldü -> {outdir}/results.json")
    return results


if __name__ == "__main__":
    run(sys.argv[1] if len(sys.argv) > 1 else "full")
