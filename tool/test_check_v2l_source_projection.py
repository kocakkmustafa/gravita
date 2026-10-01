#!/usr/bin/env python3
"""Independent app-local source gate and same-byte symlink adversaries."""

from __future__ import annotations

import copy
import hashlib
import json
import os
import tempfile
import unittest
from pathlib import Path

import check_v2l_source_projection as checker


INPUTS = (checker.COURSE, checker.SLICE, checker.PROJECTION, checker.PUBSPEC)


def app_bytes() -> dict[str, bytes]:
    root_fd = os.open(checker.APP_ROOT, checker.ROOT_FLAGS)
    try:
        return {path: checker._read_input(root_fd, path, 512 * 1024)
                for path in INPUTS}
    finally:
        os.close(root_fd)


def fixture(root: Path, raw: dict[str, bytes]) -> Path:
    app = root / "app"
    for path, data in raw.items():
        target = app / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    return app


class SourceProjectionCheckTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.raw = app_bytes()

    def test_live_app_passes_from_its_own_assets(self) -> None:
        checker.check_app()

    def test_same_byte_outside_directory_symlink_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            app = fixture(root, self.raw)
            outside = fixture(root / "outside", self.raw)
            (app / "content/courses").rename(app / "content/courses.saved")
            (app / "content/courses").symlink_to(outside / "content/courses",
                                                  target_is_directory=True)
            # A path-based SHA checker would accept this outside clone.
            for path, expected in ((checker.COURSE, checker.PIN.course_sha256),
                                   (checker.SLICE, checker.PIN.slice_sha256),
                                   (checker.PROJECTION, checker.PIN.projection_sha256)):
                self.assertEqual(hashlib.sha256((app / path).read_bytes()).hexdigest(),
                                 expected)
            with self.assertRaisesRegex(checker.CheckError,
                                        "APP_INPUT_UNSAFE_OR_MISSING"):
                checker.check_app(app)

    def test_same_byte_outside_swap_after_root_open_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            app = fixture(root, self.raw)
            outside = fixture(root / "outside", self.raw)
            original_read = checker._read_input
            swapped = False

            def swap_before_first_child(root_fd: int, relative: str,
                                        limit: int) -> bytes:
                nonlocal swapped
                if not swapped:
                    swapped = True
                    (app / "content/courses").rename(app / "content/courses.saved")
                    (app / "content/courses").symlink_to(
                        outside / "content/courses", target_is_directory=True)
                    # The attack carries exact approved bytes outside app root.
                    self.assertEqual(hashlib.sha256(
                        (app / checker.COURSE).read_bytes()).hexdigest(),
                        checker.PIN.course_sha256)
                return original_read(root_fd, relative, limit)

            checker._read_input = swap_before_first_child
            try:
                with self.assertRaisesRegex(checker.CheckError,
                                            "APP_INPUT_UNSAFE_OR_MISSING"):
                    checker.check_app(app)
            finally:
                checker._read_input = original_read
            self.assertTrue(swapped)

    def test_same_byte_outside_leaf_symlinks_are_rejected(self) -> None:
        for path in INPUTS:
            with self.subTest(path=path), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                app = fixture(root, self.raw)
                outside = root / "outside.bin"
                outside.write_bytes(self.raw[path])
                (app / path).unlink()
                (app / path).symlink_to(outside)
                self.assertEqual((app / path).read_bytes(), self.raw[path])
                with self.assertRaisesRegex(checker.CheckError,
                                            "APP_INPUT_UNSAFE_OR_MISSING"):
                    checker.check_app(app)

    def test_one_hold_cannot_disappear_or_become_playable(self) -> None:
        course = json.loads(self.raw[checker.COURSE])
        source_slice = json.loads(self.raw[checker.SLICE])
        projection = json.loads(self.raw[checker.PROJECTION])
        checker.validate_semantics(course, source_slice, projection)

        missing = copy.deepcopy(source_slice)
        missing["holds"] = []
        with self.assertRaisesRegex(checker.CheckError, "SOURCE_HOLD_RECORD"):
            checker.validate_semantics(course, missing, projection)

        unheld_row = copy.deepcopy(projection)
        next(row for row in unheld_row["rows"] if row[0] == checker.HELD_PIN)[10] = False
        with self.assertRaisesRegex(checker.CheckError, "SOURCE_PROJECTION_ROWS"):
            checker.validate_semantics(course, source_slice, unheld_row)

        playable = copy.deepcopy(source_slice)
        scene = next(scene for lesson in playable["lessons"] for scene in lesson["scenes"]
                     if scene["sceneId"] == checker.HELD_SCENE)
        scene["productionState"] = "PREPRODUCTION_UNGENERATED"
        with self.assertRaisesRegex(checker.CheckError, "SOURCE_HOLD_STATE"):
            checker.validate_semantics(course, playable, projection)

        playable_flag = copy.deepcopy(source_slice)
        scene = next(scene for lesson in playable_flag["lessons"]
                     for scene in lesson["scenes"]
                     if scene["sceneId"] == checker.HELD_SCENE)
        scene["releaseEligible"] = True
        with self.assertRaisesRegex(checker.CheckError, "SOURCE_SCENE_ID"):
            checker.validate_semantics(course, playable_flag, projection)

    def test_course_drift_and_projection_reordering_fail(self) -> None:
        course = json.loads(self.raw[checker.COURSE])
        source_slice = json.loads(self.raw[checker.SLICE])
        projection = json.loads(self.raw[checker.PROJECTION])
        drifted = copy.deepcopy(course)
        drifted["modules"][0]["lessons"][0]["id"] = "cal-999"
        with self.assertRaisesRegex(checker.CheckError, "SOURCE_COURSE_LESSON_BINDING"):
            checker.validate_semantics(drifted, source_slice, projection)
        reordered = copy.deepcopy(projection)
        reordered["rows"][0], reordered["rows"][1] = (reordered["rows"][1],
                                                         reordered["rows"][0])
        with self.assertRaisesRegex(checker.CheckError, "SOURCE_PROJECTION_ROWS"):
            checker.validate_semantics(course, source_slice, reordered)

    def test_variant_identity_is_recomputed_without_workspace_ops(self) -> None:
        course = json.loads(self.raw[checker.COURSE])
        source_slice = json.loads(self.raw[checker.SLICE])
        projection = json.loads(self.raw[checker.PROJECTION])
        source_slice["lessons"][0]["scenes"][0]["sourceCueSHA256"] = "0" * 64
        with self.assertRaisesRegex(checker.CheckError, "SOURCE_VARIANT_IDENTITY"):
            checker.validate_semantics(course, source_slice, projection)

    def test_lesson_digest_binds_live_course_even_after_consistent_rehash(self) -> None:
        course = json.loads(self.raw[checker.COURSE])
        source_slice = json.loads(self.raw[checker.SLICE])
        projection = json.loads(self.raw[checker.PROJECTION])
        live_lesson = next(item for module in course["modules"]
                           for item in module["lessons"] if item["id"] == "cal-02")
        wrong_digest = "0" * 64
        self.assertNotEqual(checker._sha(checker._canonical(live_lesson)), wrong_digest)
        source_lesson = next(item for item in source_slice["lessons"]
                             if item["lessonId"] == "cal-02")
        source_lesson["lessonCanonicalSHA256"] = wrong_digest

        changed_pins: dict[str, str] = {}
        for scene in source_lesson["scenes"]:
            for variant in scene["variants"]:
                old_pin = variant["sourcePinSHA256"]
                identity = {
                    "manifestSHA256": checker.PIN.source_manifest_sha256,
                    "app": "gravita",
                    "courseSourceSHA256": checker.PIN.course_sha256,
                    "lessonId": "cal-02",
                    "lessonCanonicalSHA256": wrong_digest,
                    "assetId": source_lesson["assetId"],
                    "sceneId": scene["sceneId"],
                    "variantStem": variant["stem"],
                    "productionSpecSHA256": scene["productionSpecSHA256"],
                    "sourceCueSHA256": scene["sourceCueSHA256"],
                    "idempotencyKey": scene["idempotencyKey"],
                    "productionState": scene["productionState"],
                }
                new_pin = checker._sha(checker._canonical(identity))
                variant["sourcePinSHA256"] = new_pin
                changed_pins[old_pin] = new_pin
        self.assertEqual(len(changed_pins), 7)
        for row in projection["rows"]:
            if row[0] in changed_pins:
                row[0] = changed_pins[row[0]]
                row[6] = wrong_digest
        projection["rows"].sort(key=lambda row: row[0])

        with self.assertRaisesRegex(checker.CheckError, "SOURCE_LESSON_CANONICAL"):
            checker.validate_semantics(course, source_slice, projection)

        changed_body = copy.deepcopy(course)
        live_lesson = next(item for module in changed_body["modules"]
                           for item in module["lessons"] if item["id"] == "cal-02")
        live_lesson["objective"]["en"] += " Changed body."
        original_slice = json.loads(self.raw[checker.SLICE])
        original_projection = json.loads(self.raw[checker.PROJECTION])
        with self.assertRaisesRegex(checker.CheckError, "SOURCE_LESSON_CANONICAL"):
            checker.validate_semantics(changed_body, original_slice,
                                       original_projection)


if __name__ == "__main__":
    unittest.main()
