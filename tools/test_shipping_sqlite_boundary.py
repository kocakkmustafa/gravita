import json
import unittest

from validate_shipping_sqlite_boundary import inspect_entries


class ShippingBoundaryTest(unittest.TestCase):
    def entries(self, manifest=None, binary=b"\x7fELFplain native code"):
        return [
            ("base/assets/flutter_assets/NativeAssetsManifest.json", json.dumps(
                manifest or {"native-assets": {"android_arm64": {}}}
            ).encode()),
            ("base/lib/arm64-v8a/libapp.so", binary),
        ]

    def test_empty_release_mapping_and_real_binary_pass(self):
        self.assertEqual(len(inspect_entries(self.entries())["binary_sha256"]), 1)

    def test_missing_built_manifest_fails(self):
        with self.assertRaisesRegex(ValueError, "Expected one"):
            inspect_entries(self.entries()[1:])

    def test_sqlite_hook_mapping_fails(self):
        with self.assertRaisesRegex(ValueError, "native asset"):
            inspect_entries(self.entries({"native-assets": {"android_arm64": {
                "package:sqlite3/src/ffi/libsqlite3.g.dart": ["absolute", "renamed.so"]
            }}}))

    def test_plugin_or_library_filename_fails(self):
        with self.assertRaisesRegex(ValueError, "shipping file"):
            inspect_entries(self.entries() + [("Frameworks/sqlite3.framework/sqlite3", b"x")])

    def test_renamed_sqlite_binary_fails(self):
        with self.assertRaisesRegex(ValueError, "entry point"):
            inspect_entries(self.entries(binary=b"\x7fELFsqlite3_libversion\x00"))


if __name__ == "__main__":
    unittest.main()
