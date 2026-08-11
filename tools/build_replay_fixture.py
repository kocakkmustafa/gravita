#!/usr/bin/env python3
"""Ham hasat landmark verisini gerçek bir REPLAY FIXTURE'a dönüştürür.

## Neden var (K14/koordinatör hükmü, 2026-08-11)

`push_up` LIVE ama `replayFixture:missing` taşıyordu (K14): kanıt vardı
(gravita_engine'in 18 sentetik-perturbasyon testi) ama `test/fixtures/`te
DOSYA biçiminde değildi — ve o kanıt SENTETİKTİ (`SyntheticPoseBuilder`),
GERÇEK karelerden değil. Bu betik ilk GERÇEK, kökeni izlenebilir replay
fixture'ı üretiyor: `~/motion-harvest/`teki ham landmark hasadından, D1
fixture'ının (`test/fixtures/d1_correct_frames.json`) biçimini izleyerek.

## Kapsam (koordinatör sınırı, 2026-08-11)

Bu fixture REP-FSM DAVRANIŞINI doğrular (gerçek tekrar sayımı, faz
geçişleri) — `engine.precondition` TÜRETİMİNİ DEĞİL. Squat'ın kimlik
ön-koşulu (kalça-diz korelasyonu) AYRI bir motor işi (çekirdek kuyruğu);
bu fixture o karardan BAĞIMSIZ, RepEngine bugünkü (precondition boş)
config'iyle çalışır.

## Kaynak seçimi — İCAT edilmedi, MEVCUT kararlardan okundu

`content/harvest/decisions.<hareket>.json`teki `excludedVariantMismatch`
(yanlış varyant, ör. barbell squat) dışlanır. `content/harvest/
identity-triage.<hareket>.json`teki `gate` alanı `"pass"` OLMAYAN kanallar
(fail/noSignal) dışlanır — bu ikisi koordinatör/insan kararıyla ZATEN
verilmiş, burada yeniden tartışılmıyor.

Kullanım:
    python3 tools/build_replay_fixture.py --movement bodyweight_squat \
        --per-channel 3 --out packages/gravita_engine/test/fixtures/bodyweight_squat_reps.json
"""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HARVEST_ROOT = Path.home() / "motion-harvest"


def load(p):
    return json.loads(Path(p).read_text(encoding="utf-8"))


def excluded_take_ids(movement):
    p = ROOT / "content" / "harvest" / f"decisions.{movement}.json"
    if not p.exists():
        return set()
    d = load(p)
    return {e["takeId"] for e in d.get("excludedVariantMismatch", [])}


def passing_channels(movement):
    p = ROOT / "content" / "harvest" / f"identity-triage.{movement}.json"
    if not p.exists():
        return None  # bilinmiyor -> hiçbir kanal filtrelenmez
    d = load(p)
    return {ch for ch, v in d["instructors"].items() if v.get("gate") == "pass"}


def channel_of(filename):
    # "Jeff_Nippard_w19_r0.full.json" -> "Jeff Nippard" (alt çizgi -> boşluk,
    # kanal-adı alanı ölçüldü: identity-triage anahtarları BOŞLUKLU).
    stem = re.sub(r"_w\d+_r\d+\.full\.json$", "", filename)
    return stem.replace("_", " ").replace("  ", " ").strip()


def convert_frame(raw_frame, i, take_id, frame_size):
    return {
        "i": i,
        "takeId": take_id,
        "landmarks": raw_frame["lm"],
        "frameSize": frame_size,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--movement", required=True)
    ap.add_argument("--harvest-dir", default=None,
                     help="varsayılan: ~/motion-harvest/gravita-<movement kısaltması>")
    ap.add_argument("--per-channel", type=int, default=3)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    harvest_dir = Path(args.harvest_dir) if args.harvest_dir else (
        HARVEST_ROOT / f"gravita-{args.movement.replace('bodyweight_', '')}")
    slice_dir = harvest_dir / "landmarks-rep-sliced"
    if not slice_dir.is_dir():
        raise SystemExit(f"⛔ ORTAM YOK: {slice_dir} yok — ham hasat bu makinede değil")

    excluded = excluded_take_ids(args.movement)
    passing = passing_channels(args.movement)

    by_channel = {}
    for f in sorted(slice_dir.glob("*.full.json")):
        take_id = f.name.removesuffix(".full.json")
        if take_id in excluded:
            continue
        ch = channel_of(f.name)
        if passing is not None and ch not in passing:
            continue
        by_channel.setdefault(ch, []).append(f)

    selected = []
    for ch, files in sorted(by_channel.items()):
        selected.extend(files[: args.per_channel])

    if not selected:
        raise SystemExit("⛔ 0 take seçildi — filtre çok mu dar?")

    reps = []
    channels_used = set()
    for f in selected:
        take_id = f.name.removesuffix(".full.json")
        d = load(f)
        meta = d.get("recordingMeta", {})
        res = meta.get("resolution", "0x0")
        w, h = (int(x) for x in res.split("x"))
        ch = channel_of(f.name)
        channels_used.add(ch)
        frames = [
            {"lm": fr["lm"], "t": fr["t"]}
            for fr in d["frames"] if fr.get("detected")
        ]
        reps.append({
            "takeId": take_id,
            "channel": ch,
            "sourceUrl": d.get("provenance", {}).get("sourceUrl"),
            "fps": meta.get("fps"),
            "frameSize": {"width": w, "height": h},
            "frameCount": len(frames),
            "frames": frames,
        })

    fixture = {
        "schemaVersion": 1,
        "fixtureId": f"gravita.replay.{args.movement}",
        "purpose_tr": (
            "GERÇEK kayıttan kesilmiş, kökeni izlenebilir tekrar dilimleri "
            "(K14 kapanışı). Her `rep` `tool/slice_deep_reps_squat.dart` "
            "tarafından ZATEN tek-tekrar olarak doğrulanmış bir dilimdir; "
            "bu fixture RepEngine'in AYNI dilimde AYNI sonucu (1 tekrar) "
            "ürettiğini sınar. Kapsam DAR: rep-FSM davranışı, "
            "precondition TÜRETİMİ değil (ayrı motor işi, koordinatör kuyruğu)."
        ),
        "landmarkFormat": ["x", "y", "z", "visibility", "presence"],
        "sourceHarvestDir": str(slice_dir),
        "channelsUsed": sorted(channels_used),
        "excludedTakeIds": sorted(excluded),
        "repCount": len(reps),
        "reps": reps,
    }

    out = ROOT / args.out
    out.write_text(json.dumps(fixture, ensure_ascii=False, indent=2) + "\n",
                    encoding="utf-8")
    print(f"✅ {len(reps)} gerçek tekrar dilimi ({len(channels_used)} kanal) "
          f"-> {out.relative_to(ROOT)}")
    print(f"   kanallar: {sorted(channels_used)}")


if __name__ == "__main__":
    main()
