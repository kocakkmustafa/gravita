#!/usr/bin/env python3
"""Build/check Gravita's closed v2k QA source projection from exact ops bytes."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

APP = Path(__file__).resolve().parents[1]
ROOT = Path(__file__).resolve().parents[4]
CONTRACT = ROOT / "ops/tools/motion_courses/contracts/v2k"
OUT = APP / "content/courses/calisthenics.media-source-pins.v2k.v1.json"
PINS = {
    "manifest": (CONTRACT / "production-manifest.json", "d887683c9a9b9bdb8d4ab7c51cdc5a5b4b4de6a918079e4cfd9cf543e9751e60"),
    "catalog": (CONTRACT / "source_pins_v1/source-pins.json", "791bfea8e1479307794bcf8799cf703a7a840bcd3058c1a0d7fdf065d32d8594"),
    "proof": (CONTRACT / "source-proof/SOURCE-PROOF-READBACK.json", "dec615e14881b86b7676e1157f63b8bf6269026d856e59f2ee3a65d7f97e512a"),
    "chain": (CONTRACT / "contract-chain-readback.json", "6705f8af3f3de94d43d76de2c3352070dcab482f768a2aa040384da702e9cf3b"),
    "course": (APP / "content/courses/calisthenics.v1.json", "15930d335f377c9f48e1c7285f1c44e25973b9cccb3167fa99cc9b8599889502"),
}
OUTPUT_SHA = "55a616756f126d0c95fc5127df1b76725c975111014571fcc7ebfd2c0a759843"
EQUIPMENT_HOLD = {"app": "gravita", "lessonId": "cal-01",
                  "sceneId": "gravita:cal-01:full_sequence-03",
                  "status": "HOLD_VERIFIED_EQUIPMENT"}


def require(ok: bool, detail: object) -> None:
    if not ok:
        raise ValueError(f"GRAVITA_V2K_QA_DRIFT:{detail}")


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True,
                      separators=(",", ":")).encode()


def encoded(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode()


def read(name: str) -> dict:
    path, expected = PINS[name]
    require(path.is_file() and not path.is_symlink(), (name, "FILE"))
    raw = path.read_bytes()
    require(sha(raw) == expected, (name, "SHA"))
    return json.loads(raw)


def identity(catalog: dict, lesson: dict, scene: dict, variant: dict) -> dict:
    return {
        "manifestSHA256": catalog["manifestSHA256"],
        "app": lesson["app"], "courseSourceSHA256": lesson["courseSourceSHA256"],
        "lessonId": lesson["lessonId"],
        "lessonCanonicalSHA256": lesson["lessonCanonicalSHA256"],
        "assetId": lesson["assetId"], "sceneId": scene["sceneId"],
        "variantStem": variant["stem"],
        "productionSpecSHA256": scene["productionSpecSHA256"],
        "sourceCueSHA256": scene["sourceCueSHA256"],
        "idempotencyKey": scene["idempotencyKey"],
        "productionState": scene["productionState"],
    }


def build() -> bytes:
    manifest, catalog, proof, chain, _ = [read(name) for name in PINS]
    require(catalog["kind"] == "MOTION_MEDIA_V2K_SOURCE_PINS_V1" and
            catalog["state"] == "CLOSED_PREPRODUCTION_SOURCE_MEMBERSHIP_ONLY" and
            catalog["manifestSHA256"] == PINS["manifest"][1] and
            catalog["sourceProofSHA256"] == PINS["proof"][1] and
            catalog["courseSourcePins"] == manifest["courseSourcePins"] and
            catalog["visible"] is catalog["releaseEligible"] is False and
            catalog["progressEffect"] == 0 and
            catalog["approvedProductionTrustRoot"] is False and
            catalog["counts"]["generatedMedia"] ==
            catalog["counts"]["qualifiedMedia"] == 0,
            "CATALOG_POLICY")
    require(manifest["counts"]["lessons"] == 263 and
            manifest["counts"]["modules"] == 46 and
            manifest["counts"]["scenes"] == 2020 and
            manifest["counts"]["filenameStems"] == 2456 and
            manifest["counts"]["generatedMedia"] ==
            manifest["counts"]["qualifiedMedia"] ==
            manifest["counts"]["educatorAccepted"] == 0 and
            manifest["releaseEligible"] is False and
            manifest["sourceProofReceiptSHA256"] == PINS["proof"][1] and
            proof["liveLissomCourseSHA256"] ==
            "be597ebcb4d9a3ae05410e2b33752b061bdc4ad1aea49896ae978733b7405a3c",
            "MANIFEST_PROOF_POLICY")
    for name, key in (("manifest", "manifest"), ("catalog", "sourcePins"),
                      ("proof", "proof")):
        path, expected = PINS[name]
        pin = chain["pins"][key]
        require(pin["path"] == str(path.relative_to(ROOT)) and
                pin["sha256"] == expected and pin["bytes"] == path.stat().st_size,
                ("CHAIN", name))
    require(chain["releaseEligible"] is False and
            chain["generatedMedia"] == chain["qualifiedMedia"] == 0,
            "CHAIN_POLICY")
    course_pin = catalog["courseSourcePins"]["gravita"]
    require(course_pin == {"path": "ventures/gravita/app/content/courses/calisthenics.v1.json",
                           "sha256": PINS["course"][1]}, "COURSE_PIN")
    holds = [row for row in catalog["holds"] if row["app"] == "gravita"]
    require(holds == [EQUIPMENT_HOLD], "EQUIPMENT_HOLD")
    records = {(r["app"], r["lessonId"]): r for r in manifest["lessonRecords"]}
    require(len(records) == 263, "MANIFEST_LESSON_SET")
    lessons = [r for r in catalog["lessons"] if r["app"] == "gravita"]
    require(len(lessons) == len({r["lessonId"] for r in lessons}) == 56,
            "LESSON_SET")
    seen_scenes: set[str] = set()
    seen_stems: set[str] = set()
    seen_pins: set[str] = set()
    held = 0
    for lesson in lessons:
        key = ("gravita", lesson["lessonId"])
        matching = records[key]
        require(all(lesson[field] == matching[field]
                    for field in ("app", "lessonId", "assetId",
                                  "courseSourceSHA256", "lessonCanonicalSHA256")) and
                lesson["courseSourceSHA256"] == PINS["course"][1] and
                lesson["membershipStatus"] == "SOURCE_PINNED_TEST_ONLY",
                ("LESSON", key))
        mscenes = {r["sceneId"]: r for r in matching["scenes"]}
        require(len(mscenes) == len(lesson["scenes"]), ("SCENE_SET", key))
        for scene in lesson["scenes"]:
            sid = scene["sceneId"]
            require(sid not in seen_scenes and sid in mscenes,
                    ("SCENE_ID", sid))
            seen_scenes.add(sid)
            source = mscenes[sid]
            require(all(scene[field] == source[field]
                        for field in ("productionSpecSHA256", "sourceCueSHA256",
                                      "idempotencyKey", "productionState")),
                    ("SCENE_SOURCE", sid))
            is_held = sid == EQUIPMENT_HOLD["sceneId"]
            held += is_held
            require(scene["productionState"] ==
                    ("HOLD_VERIFIED_EQUIPMENT" if is_held else
                     "PREPRODUCTION_UNGENERATED"), ("SCENE_HOLD", sid))
            require([v["stem"] for v in scene["variants"]] ==
                    source["format"]["filenameVariantsWithoutExtension"],
                    ("VARIANT_STEMS", sid))
            for variant in scene["variants"]:
                stem = variant["stem"]
                pin = sha(canonical(identity(catalog, lesson, scene, variant)))
                require(stem not in seen_stems and
                        pin not in seen_pins and
                        variant["sourcePinSHA256"] == pin,
                        ("VARIANT_PIN", stem))
                seen_stems.add(stem)
                seen_pins.add(pin)
    require((len(seen_scenes), len(seen_stems), len(seen_pins), held) ==
            (392, 392, 392, 1), "COUNTS_AND_HOLD")
    result = {
        "schemaVersion": 1, "kind": "GRAVITA_V2K_QA_SOURCE_PINS_V1",
        "sourceCatalogSHA256": PINS["catalog"][1],
        "manifestSHA256": PINS["manifest"][1],
        "sourceProofSHA256": PINS["proof"][1],
        "courseSourceSHA256": PINS["course"][1],
        "lessons": lessons,
        "visible": False, "releaseEligible": False, "progressEffect": 0,
        "state": "QA_SOURCE_MEMBERSHIP_ONLY_NO_MEDIA",
        "counts": {"lessons": 56, "scenes": 392, "variants": 392,
                   "heldScenes": 1, "mediaAccepted": 0},
        "holds": holds,
    }
    raw = encoded(result)
    require(sha(raw) == OUTPUT_SHA, "OUTPUT_SHA")
    return raw


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    raw = build()
    if args.check:
        require(OUT.is_file() and not OUT.is_symlink() and OUT.read_bytes() == raw,
                "OUTPUT_BYTES")
    else:
        require(not OUT.exists() and not OUT.is_symlink(), "OUTPUT_EXISTS")
        OUT.write_bytes(raw)
    print(json.dumps({"state": "PASS_GRAVITA_V2K_CLOSED_QA", "sha256": sha(raw),
                      "lessons": 56, "scenes": 392, "variants": 392,
                      "heldEquipmentScenes": 1, "acceptedMedia": 0}))


if __name__ == "__main__":
    main()
