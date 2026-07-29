#!/usr/bin/env python3
"""Hasat kuyruğu keşfi — Gravita (M-F-32).

Sayım birimi **EĞİTMEN**, video değil. Bir kanaldan on video almak "on kaynak"
değildir: eğitmenler-arası varyans toleransın kendisi olduğu için (katalog
§6.0) aynı kişinin tekrarları o varyansı ÜRETMEZ, yalnız hacim şişirir.

Hedef: teknik başına ~5 bağımsız eğitmen (≥3 × triyaj-hayatta-kalma ~%60).

Video kimlikleri UYDURULMAZ: `yt-dlp` aramasıyla çözülür ve provenance
(sorgu, kanal, süre, keşif tarihi) kaydedilir. Ham medya repoya girmez
(M-F-26) — burada üretilen yalnız kuyruk + provenance özetidir.
"""
import json
import pathlib
import subprocess
import sys
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Katalog §6.2 Gravita havuzu. Kanal adı, aramanın eğitmen çapasıdır.
POOLS = [
    "GMB Fitness",
    "FitnessFAQs",
    "Tom Merrick",
    "THENX",
    "Tapp Brothers",
    "Antranik",
    # Verim pilotu için genişletilmiş havuz (M-F-38): eğitmen hedefini ölçülen
    # verimle ölçeklemek için daha çok BAĞIMSIZ eğitmen gerekiyor.
    "Calisthenic Movement",
    "Kboges",
    "Bodyweight Warrior",
    "Squat University",
    "Jeff Nippard",
    "Minus The Gym",
]

# Hareket → arama çekirdeği + ALAKA süzgeci.
#
# ⚠️ Süzgeç şart: ilk pilotta "kanal başına en uzun video" sezgisi push-up için
# 5 eğitmenin 3'ünde YANLIŞ hareketi seçti — mobilite rutini, HANDSTAND push-up
# ve HİNDU push-up. Üçü de bizim kataloğumuzda AYRI hareket. O kuyrukla
# üretilen "şınav referansı", handstand push-up'ların ortalaması olurdu ve
# ondan türetilen tolerans anlamsız çıkardı (katalog §6.0: tolerans =
# eğitmenler-arası varyans; yanlış hareketin varyansı toleransı değil GÜRÜLTÜYÜ
# ölçer).
MOVEMENTS = {
    "push_up": {
        "core": "push up technique tutorial",
        "require": [["push"], ["up", "ups"]],
        # Bunlar kataloğumuzda ayrı hareket ya da ayrı varyant:
        "reject": ["handstand", "hindu", "archer", "one arm", "one-arm", "pike",
                   "planche", "diamond", "decline", "incline", "clap", "wide grip"],
    },
    "pull_up": {
        "core": "pull up technique tutorial",
        "require": [["pull"], ["up", "ups"]],
        "reject": ["muscle up", "muscle-up", "archer", "one arm", "one-arm",
                   "typewriter", "weighted", "chin up", "chin-up", "commando"],
    },
    "bodyweight_squat": {
        "core": "bodyweight squat technique tutorial",
        "require": [["squat", "squats"]],
        "reject": ["pistol", "barbell", "back squat", "front squat", "jump",
                   "sissy", "shrimp", "bulgarian", "goblet", "hack"],
    },
    "plank": {
        "core": "plank technique tutorial",
        "require": [["plank"]],
        "reject": ["side plank", "reverse", "plank to", "walk", "challenge"],
    },
    "dip": {
        "core": "dip technique tutorial",
        "require": [["dip", "dips"]],
        "reject": ["ring", "korean", "russian", "weighted", "bench dip"],
    },
}

MIN_DURATION_S = 90      # triyaj kuralı (M-O-02): kısa klip faz taşımıyor
MAX_DURATION_S = 1800    # 30 dk üstü genelde ders/vlog, tek teknik değil
PER_QUERY = 4


def search(query, n=PER_QUERY):
    """Gerçek adayları çözer. Ağ hatası sessizce boş liste DÖNDÜRMEZ."""
    cmd = [
        "yt-dlp", "--flat-playlist", "--no-warnings", "--ignore-config",
        "--print", "%(id)s\t%(channel)s\t%(duration)s\t%(title)s",
        f"ytsearch{n}:{query}",
    ]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired:
        print(f"  ⏱  zaman aşımı: {query}", file=sys.stderr)
        return []
    if out.returncode != 0:
        print(f"  ! arama başarısız ({out.returncode}): {query}", file=sys.stderr)
        return []
    rows = []
    for line in out.stdout.strip().splitlines():
        parts = line.split("\t")
        if len(parts) < 4:
            continue
        vid, channel, dur, title = parts[0], parts[1], parts[2], parts[3]
        try:
            dur = int(float(dur))
        except (ValueError, TypeError):
            continue
        rows.append({"id": vid, "channel": channel, "duration_s": dur, "title": title})
    return rows


def relevant(title, spec):
    """Başlık gerçekten BU hareketi mi anlatıyor?

    Aramanın döndürdüğü ilk sonuç "ilgili" değil "popüler"dir. Alaka
    denetlenmezse kuyruk dolar ama referans bozulur.
    """
    t = title.lower()
    for bad in spec["reject"]:
        if bad in t:
            return False, f"varyant/başka hareket: '{bad}'"
    for group in spec["require"]:
        if not any(tok in t for tok in group):
            return False, f"başlıkta yok: {group}"
    return True, ""


def build(movements=None, target_instructors=5):
    movements = movements or MOVEMENTS
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    result = {
        "schemaVersion": 1,
        "app": "gravita",
        "rule": "M-F-32: sayım birimi EĞİTMEN; hedef ~5 bağımsız eğitmen/teknik",
        "discoveredAt": now,
        "tool": subprocess.run(["yt-dlp", "--version"], capture_output=True,
                               text=True).stdout.strip(),
        "filters": {"min_duration_s": MIN_DURATION_S, "max_duration_s": MAX_DURATION_S},
        "movements": {},
    }

    for mid, spec in movements.items():
        core = spec["core"]
        print(f"\n=== {mid} ===")
        by_channel = {}
        rejected = []
        for pool in POOLS:
            q = f"{pool} {core}"
            for row in search(q):
                if not (MIN_DURATION_S <= row["duration_s"] <= MAX_DURATION_S):
                    continue
                ok, why = relevant(row["title"], spec)
                if not ok:
                    rejected.append({"title": row["title"], "channel": row["channel"],
                                     "reason": why})
                    continue
                ch = row["channel"]
                # Kanal başına TEK aday: aynı eğitmenin 4 videosu 4 kaynak
                # değildir (M-F-32). Alaka eşitse kısa olan tercih edilir —
                # uzun video genelde derleme/vlog, tek teknik değil.
                if ch not in by_channel or row["duration_s"] < by_channel[ch]["duration_s"]:
                    row = dict(row, query=q, url=f"https://www.youtube.com/watch?v={row['id']}")
                    by_channel[ch] = row
            if len(by_channel) >= target_instructors:
                break
        picked = list(by_channel.values())
        result["movements"][mid] = {
            "searchCore": core,
            "rejectedForRelevance": rejected,
            "instructorCount": len(picked),
            "meetsTarget": len(picked) >= 3,   # triyaj sonrası ≥3 kalmalı
            "candidates": picked,
        }
        for r in picked:
            print(f"  {r['channel'][:30]:<32} {r['duration_s']:>5}s  {r['title'][:52]}")
        flag = "✓" if len(picked) >= target_instructors else ("~" if len(picked) >= 3 else "✗")
        print(f"  → {len(picked)} bağımsız eğitmen {flag}")

    return result


if __name__ == "__main__":
    only = sys.argv[1:] or None
    movs = {k: v for k, v in MOVEMENTS.items() if not only or k in only}
    data = build(movs)

    out_dir = ROOT / "content" / "harvest"
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "queue.gravita.json").write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n")

    # Rig'in beklediği düz URL listesi — ham kütüphaneye yazılır, repoya DEĞİL.
    lib = pathlib.Path.home() / "motion-harvest" / "gravita"
    lib.mkdir(parents=True, exist_ok=True)
    urls = [c["url"] for m in data["movements"].values() for c in m["candidates"]]
    (lib / "queue.txt").write_text("\n".join(urls) + "\n")

    total = sum(m["instructorCount"] for m in data["movements"].values())
    short = [k for k, m in data["movements"].items() if not m["meetsTarget"]]
    print(f"\n{total} aday / {len(data['movements'])} hareket")
    print(f"kuyruk: {lib/'queue.txt'} · provenance: {out_dir/'queue.gravita.json'}")
    if short:
        print(f"⚠️  ≥3 eğitmen bulunamayan: {short} — ek tarama gerek")
