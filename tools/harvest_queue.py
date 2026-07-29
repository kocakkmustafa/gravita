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
import math
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
    # JENERİK aramalar: isimli havuz kapalı bir kümedir ve 10 üyesi ÖLÇÜLDÜ —
    # aynı havuzu tekrar taramak yeni eğitmen getirmez, yalnız aynı 5'i geri
    # verir (G-045'in ikinci yüzü). Ön-eleme artık ucuz ve indirmeden çalıştığı
    # için havuzu geniş tutup elemeyi triyaja bırakmak doğru sıra.
    "",
    "physical therapist",
    "strength coach",
    "beginner",
    "form check",
    "how to",
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


#: Kimlik kapısı SONRASI ≥3 temiz tekrar veren eğitmen oranı — ÖLÇÜLDÜ.
#: push_up: duruş bandını geçen 5 eğitmenin 2'si nitelendi (G-043 sonrası).
#: %95 Wilson aralığı 0,12-0,77 (n=5) — bu bir TAHMİN değil, kademe boyutu.
#: Ölçülmemiş hareket muhafazakâr varsayılanı alır.
YIELD_RATE = {"push_up": 0.18}
DEFAULT_YIELD_RATE = 0.20

#: Kanal başına kaç video alınacağı. M-F-32'nin sayım birimi EĞİTMENDİR, video
#: değil — "kanal başına tek aday" kuralı bir eğitmeni birden çok kaynak
#: saymamak içindi, ona tek şans vermek için değil. ÖLÇÜLDÜ (G-049): kimlik
#: kapısı sonrası tekrar/eğitmen dağılımı [0,0,0,1,1,1,1,2,2,3,4], medyan 1 —
#: tutorial'lar zaten az tekrar gösterir. Aynı eğitmenin 2-3 videosunu HAVUZLAMAK
#: (tekrarlar toplanır, eğitmen yine TEK birim sayılır) 28 yeni eğitmen
#: aramaktan çok daha ucuz ve M-F-32/38 ile tutarlı.
VIDEOS_PER_INSTRUCTOR = 3


def build(movements=None, target_qualified=5):
    """M-F-32'nin '~5 bağımsız eğitmen' hedefi NİTELENEN eğitmen sayısıdır.

    Bu hedefi KEŞİF aşamasında uygulamak ölçülmüş bir hataydı (G-045): 5 eğitmen
    bulup durduk, kimlik kapısından yalnız 2'si geçti ve M-F-38 kapalı kaldı.
    Keşif hedefi, ölçülen nitelenme oranıyla ŞİŞİRİLİR.
    """
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
        rate = YIELD_RATE.get(mid, DEFAULT_YIELD_RATE)
        target_instructors = math.ceil(target_qualified / rate)
        print(f"\n=== {mid} ===")
        print(f"  hedef: {target_qualified} NİTELENEN × 1/{rate:.2f} "
              f"= {target_instructors} aday eğitmen aranacak")
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
                # Aynı eğitmenin videoları AYNI birime yazılır (M-F-32) ama
                # birden çoğu alınır: tekrarlar havuzlanınca eğitmen M-F-38'in
                # ≥3 temiz tekrar eşiğine ulaşabilir (G-049). Kısa olan önce —
                # uzun video genelde derleme/vlog, tek teknik değil.
                row = dict(row, query=q, url=f"https://www.youtube.com/watch?v={row['id']}")
                vids = by_channel.setdefault(ch, [])
                if row["id"] not in {v["id"] for v in vids}:
                    vids.append(row)
                    vids.sort(key=lambda v: v["duration_s"])
                    del vids[VIDEOS_PER_INSTRUCTOR:]
            if len(by_channel) >= target_instructors:
                break
        picked = [v for vids in by_channel.values() for v in vids]
        result["movements"][mid] = {
            "searchCore": core,
            "rejectedForRelevance": rejected,
            "instructorCount": len(by_channel),
            "videoCount": len(picked),
            "videosPerInstructor": VIDEOS_PER_INSTRUCTOR,
            "targetQualified": target_qualified,
            "assumedYieldRate": rate,
            "discoveryTarget": target_instructors,
            # "Yeter" hükmü ancak ÇIKARIMDAN sonra verilebilir; keşif sayısı
            # yeterlilik iddiası TAŞIMAZ (G-045).
            "meetsTarget": None,
            "candidates": picked,
        }
        for r in picked:
            print(f"  {r['channel'][:30]:<32} {r['duration_s']:>5}s  {r['title'][:52]}")
        flag = "✓" if len(by_channel) >= target_instructors else "~"
        print(f"  → {len(by_channel)}/{target_instructors} bağımsız eğitmen {flag}  "
              f"({len(picked)} video · beklenen nitelenen ≈ "
              f"{len(by_channel) * rate:.1f})")

    return result


if __name__ == "__main__":
    only = sys.argv[1:] or None
    movs = {k: v for k, v in MOVEMENTS.items() if not only or k in only}
    data = build(movs)

    out_dir = ROOT / "content" / "harvest"
    out_dir.mkdir(parents=True, exist_ok=True)
    queue_path = out_dir / "queue.gravita.json"
    # Kısmi koşum kuyruğun TAMAMINI ezmemeli (G-046): `harvest_queue.py push_up`
    # çağrısı bodyweight_squat'ı sessizce siliyordu. Yalnız KOŞULAN hareketler
    # güncellenir, geri kalanı korunur.
    if queue_path.exists():
        prev = json.loads(queue_path.read_text())
        merged = dict(prev.get("movements", {}))
        merged.update(data["movements"])
        data["movements"] = merged
    queue_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")

    # Rig'in beklediği düz URL listesi — ham kütüphaneye yazılır, repoya DEĞİL.
    lib = pathlib.Path.home() / "motion-harvest" / "gravita"
    lib.mkdir(parents=True, exist_ok=True)
    urls = [c["url"] for m in data["movements"].values() for c in m["candidates"]]
    (lib / "queue.txt").write_text("\n".join(urls) + "\n")

    total = sum(m["instructorCount"] for m in data["movements"].values())
    # `meetsTarget` artık None (yeterlilik ancak ÇIKARIMDAN sonra bilinir) —
    # sade bir `not m[...]` her hareketi "eksik" ilan ediyordu. Keşif aşamasının
    # söyleyebileceği tek şey, keşif hedefinin tutup tutmadığıdır.
    short = [k for k, m in data["movements"].items()
             if m.get("discoveryTarget") is not None
             and m["instructorCount"] < m["discoveryTarget"]]
    print(f"\n{total} aday / {len(data['movements'])} hareket")
    print(f"kuyruk: {lib/'queue.txt'} · provenance: {out_dir/'queue.gravita.json'}")
    if short:
        print(f"⚠️  keşif hedefine ulaşamayan: {short} — ek tarama gerek")
