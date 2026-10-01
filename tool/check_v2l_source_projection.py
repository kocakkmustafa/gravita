#!/usr/bin/env python3
"""Check Gravita's packaged v2l source identities without workspace tooling.

These are source-only production briefs, not videos, captions, or a playable
media catalogue. The production lesson widget remains LessonMediaSlot.empty.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import sys
from dataclasses import dataclass
from pathlib import Path


APP_ROOT = Path(__file__).absolute().parent.parent
COURSE = "content/courses/calisthenics.v1.json"
SLICE = "content/courses/gravita.source-slice.v1.json"
PROJECTION = "content/courses/gravita.source-projection.v1.json"
PUBSPEC = "pubspec.yaml"
HELD_SCENE = "gravita:cal-01:full_sequence-03"
HELD_PIN = "f1e81c25e8a665efb2bef9fc73a26f91906c8a196e97ac4c2df231b150cf4d9f"
HEX64 = re.compile(r"[0-9a-f]{64}\Z")
ROOT_FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW


@dataclass(frozen=True)
class SourcePin:
    course_sha256: str = "15930d335f377c9f48e1c7285f1c44e25973b9cccb3167fa99cc9b8599889502"
    slice_sha256: str = "97d1651db95f363b36045805d71fe3bd045ea3253b11198b04b3ee2409f90f38"
    projection_sha256: str = "d7686dd01c9a2b0d59d3c63a7af9c7a667416730c389ce7980e6bc30aaaca91f"
    source_catalog_sha256: str = "791bfea8e1479307794bcf8799cf703a7a840bcd3058c1a0d7fdf065d32d8594"
    source_manifest_sha256: str = "d887683c9a9b9bdb8d4ab7c51cdc5a5b4b4de6a918079e4cfd9cf543e9751e60"
    source_proof_sha256: str = "dec615e14881b86b7676e1157f63b8bf6269026d856e59f2ee3a65d7f97e512a"
    lessons: int = 56
    scenes: int = 392
    variants: int = 392
    held_variants: int = 1


PIN = SourcePin()


class CheckError(ValueError):
    pass


def require(condition: bool, code: str) -> None:
    if not condition:
        raise CheckError(code)


def _read_input(root_fd: int, relative: str, limit: int) -> bytes:
    """Open every component relative to the trusted app directory descriptor."""
    parts = relative.split("/")
    require(bool(parts) and all(part not in ("", ".", "..") for part in parts),
            "APP_INPUT_PATH")
    parent_fd = os.dup(root_fd)
    try:
        for part in parts[:-1]:
            next_fd = os.open(part, ROOT_FLAGS, dir_fd=parent_fd)
            os.close(parent_fd)
            parent_fd = next_fd
        file_fd = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK,
                          dir_fd=parent_fd)
        with os.fdopen(file_fd, "rb") as handle:
            info = os.fstat(handle.fileno())
            require(stat.S_ISREG(info.st_mode) and 0 < info.st_size <= limit,
                    "APP_INPUT_TYPE_OR_SIZE:" + relative)
            raw = handle.read(limit + 1)
            require(len(raw) == info.st_size, "APP_INPUT_CHANGED:" + relative)
            return raw
    except OSError as error:
        raise CheckError("APP_INPUT_UNSAFE_OR_MISSING:" + relative) from error
    finally:
        os.close(parent_fd)


def _decode_json(raw: bytes, label: str) -> dict:
    try:
        value = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise CheckError("INVALID_JSON:" + label) from error
    require(isinstance(value, dict), "INVALID_OBJECT:" + label)
    return value


def _sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _canonical(value: object) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True,
                      separators=(",", ":"), allow_nan=False).encode("utf-8")


def _hex(value: object) -> bool:
    return isinstance(value, str) and HEX64.fullmatch(value) is not None


def _safe_stem(value: object) -> bool:
    return (isinstance(value, str) and value.startswith("gravita/") and
            "\\" not in value and all(part not in ("", ".", "..")
                                     for part in value.split("/")))


def _declared_assets(pubspec: str) -> list[str]:
    lines = pubspec.splitlines()
    require(lines.count("flutter:") == 1 and lines.count("  assets:") == 1,
            "PUBSPEC_FLUTTER_OR_ASSETS")
    start = lines.index("flutter:")
    try:
        assets_start = lines.index("  assets:", start + 1)
    except ValueError as error:
        raise CheckError("PUBSPEC_ASSETS") from error
    assets: list[str] = []
    for line in lines[assets_start + 1:]:
        if line and not line.startswith((" ", "#")):
            break
        if line.startswith("  ") and not line.startswith("    ") and not line.lstrip().startswith("#"):
            break
        match = re.fullmatch(r"\s{4}-\s+(\S+)(?:\s+#.*)?", line)
        if match:
            assets.append(match.group(1))
    return assets


def _check_pubspec(raw: bytes) -> None:
    try:
        assets = _declared_assets(raw.decode("utf-8"))
    except UnicodeDecodeError as error:
        raise CheckError("PUBSPEC_ENCODING") from error
    for required in (COURSE, SLICE, PROJECTION, "content/motion_content/manifest.json"):
        require(assets.count(required) == 1, "PUBSPEC_EXACT_ASSET:" + required)
    require("content/courses/" not in assets and "content/media/" not in assets,
            "PUBSPEC_BROAD_MEDIA_ASSET")
    require(not any("media-source-pins" in asset for asset in assets),
            "PUBSPEC_QA_SOURCE_PINS")


def validate_semantics(course: dict, source_slice: dict, projection: dict,
                       pin: SourcePin = PIN) -> None:
    """Rebuild all projection rows from the app-owned slice and live course."""
    require(course.get("schemaVersion") == 1 and isinstance(course.get("modules"), list),
            "COURSE_SHAPE")
    course_lessons = [lesson for module in course["modules"]
                      for lesson in module.get("lessons", [])]
    course_ids = [lesson.get("id") for lesson in course_lessons]
    require(len(course_ids) == pin.lessons and len(set(course_ids)) == pin.lessons,
            "COURSE_LESSONS")
    for document, kind in ((source_slice, "MOTION_V2L_APP_SOURCE_SLICE_V1"),
                           (projection, "MOTION_V2L_APP_SOURCE_PROJECTION_V1")):
        require(document.get("schemaVersion") == 1 and document.get("kind") == kind and
                document.get("appId") == "gravita" and
                document.get("courseSourceSHA256") == pin.course_sha256 and
                document.get("sourceCatalogSHA256") == pin.source_catalog_sha256 and
                document.get("sourceManifestSHA256") == pin.source_manifest_sha256,
                "SOURCE_HEADER")
    require(set(source_slice) == {"schemaVersion", "kind", "appId",
                                  "sourceCatalogSHA256", "sourceManifestSHA256",
                                  "sourceProofSHA256", "courseSourceSHA256",
                                  "lessons", "holds"} and
            set(projection) == {"schemaVersion", "kind", "appId",
                                    "sourceCatalogSHA256", "sourceManifestSHA256",
                                    "courseSourceSHA256", "rows"},
            "SOURCE_UNEXPECTED_FIELDS")
    require(source_slice.get("sourceProofSHA256") == pin.source_proof_sha256,
            "SOURCE_PROOF")
    require(source_slice.get("holds") == [{"app": "gravita", "lessonId": "cal-01",
                                            "sceneId": HELD_SCENE,
                                            "status": "HOLD_VERIFIED_EQUIPMENT"}],
            "SOURCE_HOLD_RECORD")
    lessons = source_slice.get("lessons")
    require(isinstance(lessons, list) and len(lessons) == pin.lessons,
            "SOURCE_LESSON_COUNT")
    require([lesson.get("lessonId") for lesson in lessons] == course_ids,
            "SOURCE_COURSE_LESSON_BINDING")

    rows: list[list] = []
    seen_scenes: set[str] = set()
    seen_pins: set[str] = set()
    held_pins: set[str] = set()
    scene_count = 0
    variant_count = 0
    for lesson, live_lesson in zip(lessons, course_lessons):
        lesson_id = lesson["lessonId"]
        require(set(lesson) == {"app", "assetId", "courseSourceSHA256",
                                "lessonCanonicalSHA256", "lessonId",
                                "membershipStatus", "scenes"} and
                lesson.get("app") == "gravita" and
                lesson.get("courseSourceSHA256") == pin.course_sha256 and
                lesson.get("membershipStatus") == "SOURCE_PINNED_TEST_ONLY" and
                _hex(lesson.get("lessonCanonicalSHA256")) and
                isinstance(lesson.get("assetId"), str) and
                lesson["assetId"].startswith("gravita.") and
                isinstance(lesson.get("scenes"), list), "SOURCE_LESSON_POLICY")
        require(lesson["lessonCanonicalSHA256"] == _sha(_canonical(live_lesson)),
                "SOURCE_LESSON_CANONICAL")
        for order, scene in enumerate(lesson["scenes"]):
            scene_count += 1
            scene_id = scene.get("sceneId")
            require(set(scene) == {"idempotencyKey", "productionSpecSHA256",
                                   "productionState", "sceneId", "sourceCueSHA256",
                                   "variants"} and
                    isinstance(scene_id, str) and scene_id.startswith(f"gravita:{lesson_id}:") and
                    scene_id not in seen_scenes, "SOURCE_SCENE_ID")
            seen_scenes.add(scene_id)
            held = scene_id == HELD_SCENE
            require(scene.get("productionState") ==
                    ("HOLD_VERIFIED_EQUIPMENT" if held else "PREPRODUCTION_UNGENERATED"),
                    "SOURCE_HOLD_STATE")
            require(_hex(scene.get("productionSpecSHA256")) and
                    _hex(scene.get("sourceCueSHA256")) and
                    scene.get("idempotencyKey") == "motion-media-v1:" + scene["productionSpecSHA256"],
                    "SOURCE_SCENE_PIN")
            variants = scene.get("variants")
            require(isinstance(variants, list) and len(variants) == 1,
                    "SOURCE_VARIANT_COUNT")
            for variant in variants:
                variant_count += 1
                source_pin = variant.get("sourcePinSHA256")
                stem = variant.get("stem")
                require(set(variant) == {"sourcePinSHA256", "stem"} and
                        _hex(source_pin) and source_pin not in seen_pins and _safe_stem(stem),
                        "SOURCE_VARIANT_PIN_OR_PATH")
                identity = {
                    "manifestSHA256": pin.source_manifest_sha256,
                    "app": "gravita",
                    "courseSourceSHA256": pin.course_sha256,
                    "lessonId": lesson_id,
                    "lessonCanonicalSHA256": lesson["lessonCanonicalSHA256"],
                    "assetId": lesson["assetId"],
                    "sceneId": scene_id,
                    "variantStem": stem,
                    "productionSpecSHA256": scene["productionSpecSHA256"],
                    "sourceCueSHA256": scene["sourceCueSHA256"],
                    "idempotencyKey": scene["idempotencyKey"],
                    "productionState": scene["productionState"],
                }
                require(source_pin == _sha(_canonical(identity)),
                        "SOURCE_VARIANT_IDENTITY")
                seen_pins.add(source_pin)
                if held:
                    held_pins.add(source_pin)
                rows.append([source_pin, lesson_id, lesson["assetId"], scene_id,
                             order, stem, lesson["lessonCanonicalSHA256"],
                             scene["productionSpecSHA256"], scene["sourceCueSHA256"],
                             scene["idempotencyKey"], held])
    require(scene_count == pin.scenes and variant_count == pin.variants,
            "SOURCE_COUNTS")
    require(held_pins == {HELD_PIN} and len(held_pins) == pin.held_variants,
            "SOURCE_HELD_PIN")
    rows.sort(key=lambda row: row[0])
    require(projection.get("rows") == rows, "SOURCE_PROJECTION_ROWS")
    require(sum(row[10] is True for row in rows) == pin.held_variants,
            "SOURCE_PROJECTION_HOLD")


def check_app(app_root: Path = APP_ROOT, pin: SourcePin = PIN) -> None:
    try:
        root_fd = os.open(app_root, ROOT_FLAGS)
    except OSError as error:
        raise CheckError("APP_ROOT_UNSAFE_OR_MISSING") from error
    try:
        raw = {
            COURSE: _read_input(root_fd, COURSE, 512 * 1024),
            SLICE: _read_input(root_fd, SLICE, 512 * 1024),
            PROJECTION: _read_input(root_fd, PROJECTION, 512 * 1024),
            PUBSPEC: _read_input(root_fd, PUBSPEC, 64 * 1024),
        }
    finally:
        os.close(root_fd)
    for path, expected in ((COURSE, pin.course_sha256), (SLICE, pin.slice_sha256),
                           (PROJECTION, pin.projection_sha256)):
        require(_sha(raw[path]) == expected, "APP_BYTE_SHA:" + path)
    _check_pubspec(raw[PUBSPEC])
    validate_semantics(_decode_json(raw[COURSE], COURSE),
                       _decode_json(raw[SLICE], SLICE),
                       _decode_json(raw[PROJECTION], PROJECTION), pin)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", required=True)
    args = parser.parse_args()
    assert args.check
    try:
        check_app()
    except CheckError as error:
        print(f"FAIL_SOURCE_IDENTITY_RELEASE_CLOSED {error}", file=sys.stderr)
        return 1
    print("PASS_SOURCE_IDENTITY_ONLY_RELEASE_CLOSED "
          "gravita lessons=56 scenes=392 variants=392 held=1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
