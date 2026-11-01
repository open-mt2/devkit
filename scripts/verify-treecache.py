#!/usr/bin/env python3
"""Verify the bundled tree geometry cache (treecache/MANIFEST.json).

Checks every entry in the manifest against the files on disk (size + sha256)
and, when the client assets are present, that every `bin/pack/**/*.spt` has a
matching `<fnv1a32>.tree` entry.

Exit codes:
    0  cache is consistent (coverage gaps are warnings unless --strict)
    1  corrupt manifest or cache file
    2  coverage gap with --strict

Examples:
    python3 scripts/verify-treecache.py
    python3 scripts/verify-treecache.py --bin bin --strict
    python3 scripts/verify-treecache.py --treecache /workspace/treecache --quiet
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

MANIFEST_NAME = "MANIFEST.json"


def fnv1a32(path: Path) -> int:
    value = 2166136261
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            for byte in chunk:
                value ^= byte
                value = (value * 16777619) & 0xFFFFFFFF
    return value


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_args(argv: list[str]) -> argparse.Namespace:
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", type=Path, default=root,
                        help="workspace root (default: the devkit checkout)")
    parser.add_argument("--treecache", type=Path, default=None,
                        help="cache directory (default: <root>/treecache)")
    parser.add_argument("--bin", type=Path, default=None,
                        help="client assets directory (default: <root>/bin)")
    parser.add_argument("--strict", action="store_true",
                        help="fail when a .spt has no cache entry")
    parser.add_argument("--quiet", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root: Path = args.root.resolve()
    treecache: Path = (args.treecache or (root / "treecache")).resolve()
    bin_dir: Path = (args.bin or (root / "bin")).resolve()

    def note(message: str) -> None:
        if not args.quiet:
            print(message)

    manifest_path = treecache / MANIFEST_NAME
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except OSError as error:
        print(f"error: cannot read {manifest_path}: {error}", file=sys.stderr)
        return 1
    except ValueError as error:
        print(f"error: invalid {manifest_path}: {error}", file=sys.stderr)
        return 1

    entries = manifest.get("entries")
    if not isinstance(entries, list) or not entries:
        print(f"error: {manifest_path} has no entries", file=sys.stderr)
        return 1

    corrupt = []
    listed = set()
    for entry in entries:
        name = entry.get("file")
        if not isinstance(name, str) or not name:
            corrupt.append("manifest entry without a file name")
            continue
        listed.add(name)
        path = treecache / name
        if not path.is_file():
            corrupt.append(f"{name}: missing")
            continue
        size = path.stat().st_size
        if entry.get("bytes") is not None and size != entry["bytes"]:
            corrupt.append(f"{name}: size {size} != manifest {entry['bytes']}")
            continue
        expected = entry.get("sha256")
        if isinstance(expected, str) and sha256(path) != expected:
            corrupt.append(f"{name}: sha256 mismatch")

    for path in sorted(treecache.glob("*.tree")):
        if path.name not in listed:
            note(f"warning: {path.name} is not listed in {MANIFEST_NAME}")

    gaps = []
    stale = []
    pack_dir = bin_dir / "pack"
    if pack_dir.is_dir():
        for spt in sorted(pack_dir.rglob("*.spt")):
            name = f"{fnv1a32(spt):08x}.tree"
            if not (treecache / name).is_file():
                gaps.append(str(spt.relative_to(pack_dir)))
        present = {
            entry.get("spt") for entry in entries if isinstance(entry.get("spt"), str)
        }
        for path in sorted(pack_dir.rglob("*.spt")):
            rel = str(path.relative_to(pack_dir))
            if rel not in present:
                stale.append(rel)
        note(f"assets: {len(listed)} cache entries, "
             f"{sum(1 for _ in pack_dir.rglob('*.spt'))} .spt files")
    else:
        note(f"assets: {len(listed)} cache entries "
             f"(no {pack_dir}, skipping coverage check)")

    for item in corrupt:
        print(f"error: {item}", file=sys.stderr)
    if gaps:
        stream = sys.stderr if args.strict else sys.stdout
        label = "error" if args.strict else "warning"
        print(f"{label}: {len(gaps)} .spt file(s) have no cache entry; "
              "the client would fall back to procedural geometry:", file=stream)
        for item in gaps:
            print(f"  - {item}", file=stream)
    if stale:
        note(f"warning: {len(stale)} .spt file(s) are not listed in {MANIFEST_NAME} "
             "(cache may have been built from a different pack ref)")

    if corrupt:
        return 1
    if gaps and args.strict:
        return 2
    note("treecache: ok" if not gaps and not stale else "treecache: ok (with warnings)")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        sys.exit(130)
