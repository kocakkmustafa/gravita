#!/usr/bin/env python3
"""Read an actual release artifact; reject the unused SQLite native runtime.

This is a scoped packaging gate, not an App Store privacy approval. Debug/test
native assets intentionally retain SQLite for the projection compatibility tests.
"""
import argparse
import hashlib
import json
import re
import subprocess
import zipfile
from pathlib import Path

SQLITE_NAME = re.compile(r"(^|/)(?:lib)?sqlite3(?:\.|/)|sqlite3_flutter_libs", re.I)
MACHO = {b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xcf", b"\xca\xfe\xba\xbe"}


def inspect_entries(entries):
    """Validate bytes from the built bundle, never a generated cache path."""
    manifests, binaries = {}, {}
    for name, data in entries:
        if SQLITE_NAME.search(name):
            raise ValueError(f"SQLite shipping file: {name}")
        if name.endswith("/NativeAssetsManifest.json"):
            manifest = json.loads(data)
            if not isinstance(manifest.get("native-assets"), dict):
                raise ValueError(f"Invalid native assets manifest: {name}")
            if "sqlite3" in json.dumps(manifest).lower():
                raise ValueError(f"SQLite shipping native asset: {name}")
            manifests[name] = manifest
        if data[:4] in MACHO or data.startswith(b"\x7fELF"):
            # Check the SQLite public entry point as well as library filenames.
            if b"sqlite3_libversion" in data:
                raise ValueError(f"SQLite entry point in shipping binary: {name}")
            binaries[name] = hashlib.sha256(data).hexdigest()
    if len(manifests) != 1:
        raise ValueError(f"Expected one built native-assets manifest, got {len(manifests)}")
    if not binaries:
        raise ValueError("No shipping native binaries were inspected")
    return {"native_asset_manifests": manifests, "binary_sha256": binaries}


def inspect_artifact(platform, artifact):
    if platform == "android":
        with zipfile.ZipFile(artifact) as archive:
            result = inspect_entries(
                (name, archive.read(name)) for name in archive.namelist()
                if not name.endswith("/")
            )
        result["artifact_sha256"] = hashlib.sha256(artifact.read_bytes()).hexdigest()
    else:
        if not artifact.is_dir() or artifact.suffix != ".app":
            raise ValueError("Expected the built iOS .app directory")
        result = inspect_entries(
            (str(path.relative_to(artifact)), path.read_bytes())
            for path in sorted(artifact.rglob("*")) if path.is_file()
        )
        imports = {}
        for name in result["binary_sha256"]:
            output = subprocess.run(
                ["xcrun", "nm", "-u", str(artifact / name)],
                check=True, capture_output=True, text=True,
            ).stdout
            hits = sorted(set(re.findall(r"\b_(?:f?statfs)(?:\$\w+)?\b", output)))
            if hits:
                raise ValueError(f"DiskSpace imports in {name}: {hits}")
            imports[name] = hits
        result["disk_space_imports"] = imports
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=("android", "ios"), required=True)
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--receipt", type=Path)
    args = parser.parse_args()
    result = inspect_artifact(args.platform, args.artifact)
    sdk = json.loads(subprocess.check_output(
        ["flutter", "--version", "--machine"], text=True,
    ))
    if sdk["frameworkVersion"] != "3.47.5":
        raise ValueError(f"Unverified release SDK: {sdk['frameworkVersion']}")
    result["source_commit"] = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], text=True,
    ).strip()
    result["pubspec_lock_sha256"] = hashlib.sha256(Path("pubspec.lock").read_bytes()).hexdigest()
    result["flutter"] = {key: sdk[key] for key in (
        "frameworkVersion", "frameworkRevision", "engineRevision", "dartSdkVersion"
    )}
    result.update({"status": "PASS", "platform": args.platform,
                   "scope": "SQLite release absence; iOS statfs/fstatfs imports"})
    if args.receipt:
        args.receipt.write_text(json.dumps(result, indent=2) + "\n")
    print(f"PASS: {args.platform}, {len(result['binary_sha256'])} binaries, "
          "no SQLite shipping native asset")


if __name__ == "__main__":
    main()
