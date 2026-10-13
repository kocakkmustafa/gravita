# SQLite release boundary — 2026-10-13

The shipped history and progress paths read `JsonlSessionStore` journals through
`ContentRepository`. The SQLite projection was never connected to `main.dart` or
those UI paths. Its persisted-v1, unsupported-future-schema and journal replay
tests remain under `test/support/storage/`; they are prototype tests, not a
shipping database migration guarantee.

`drift` is now a dev dependency and the unused `sqlite3_flutter_libs` plugin is
removed. Other resolved dependency versions, checksums and Motion revisions are
unchanged. No user database, journal or account directory is migrated or deleted.
The generated schema is preserved. SQLite remains available to the tests through
the locked `sqlite3` native hook.

Flutter 3.47.5's release hook runner sets `includeDevDependencies` to false;
debug/test runs include them. CI pins this exact SDK and enforces the committed
pub lock. A debug native-assets mapping containing SQLite is therefore expected
and is not evidence that a release contains it.

## Acceptance evidence

`test/shipping_storage_boundary_test.dart` rejects SQLite in the selected
production dependency graph. Existing privacy source tests still scan selected
Apple implementation bodies and generated Pods; their corpus is not weakened.

`tools/validate_shipping_sqlite_boundary.py` reads the actual newly built AAB or
iOS `.app`, requires its native-assets manifest and native binaries, and rejects
SQLite library/plugin paths, hook mappings and the public library-version entry
point even in a renamed binary. On iOS it also rejects `statfs`/`fstatfs` imports
in every packaged Mach-O. CI retains only the small proof receipts, with exact
commit, pub lock, Flutter/engine revision and binary hashes. These are unsigned
build checks; the gate does not grant complete privacy or store approval.

The protected historical 1.0.0+2 IPA still contains SQLite 3.53.4. Its official
raw native asset SHA-256 is
`f1bc69a4304a21e472c15f849c34ae46539483cfa7ce901f54175c6d6cc17991`;
all 11 file-backed sections match the signed SQLite framework. Its `statfs` and
`fstatfs` callers were identified statically, but their real runtime use was not
established. This source fix does not retroactively approve or alter that IPA.

## Required Reason decision

[Apple's Required Reason API guidance](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
requires accurate reasons for actual use and a manifest in the bundle containing
the relevant executable or dynamic library. A historical SQLite filesystem
locking path is insufficient evidence for inventing a DiskSpace reason in the
app manifest. Removing the uncalled shipping dependency removes that exposure
from a new release, subject to actual artifact readback. The app's existing
FileTimestamp/UserDefaults reasons remain unchanged. Historical package privacy
and future signed distribution acceptance remain separate checks.
