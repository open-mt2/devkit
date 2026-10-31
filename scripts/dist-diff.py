#!/usr/bin/env python3
"""Compare the Linux and Windows client distributions (T3.1).

The two trees are assembled from the same ``bin/`` assets and the same
``pack/Index``-driven archives, so everything that is not a binary or a
runtime library must match byte for byte.

Expected differences
--------------------
* executables and the ``metin2`` symlink (Linux has no ``.exe`` suffix);
* Linux runtime libraries in ``runtime/`` and the CPython 2.7 stdlib overlay
  in ``lib/`` (``.py``/``.pyc``/``.pyo``/``.so``) added by #115;
* Windows runtime DLLs at the tree root (``python27.dll``, ``msvcr90.dll``,
  the MinGW C++ runtime, ...);
* transient files the client writes at runtime (``syserr.txt``, ``log.txt``).

Usage: dist-diff.py <dist-linux> <dist-windows> [--verbose]
Exit code 1 when an unexpected difference exists.
"""

from pathlib import Path
import sys

LINUX_ONLY_TOP = {"metin2client", "metin2", "config"}
LINUX_ONLY_DIRS = ("runtime/",)
TRANSIENT = {"syserr.txt", "log.txt", "ErrorLog.txt", "metin2.cfg", "mouse.cfg"}


def relative_files(root: Path):
    return {
        path.relative_to(root).as_posix(): path
        for path in root.rglob("*")
        if path.is_file()
    }


def is_expected_linux_only(rel: str) -> bool:
    if rel in TRANSIENT:
        return True
    if rel in LINUX_ONLY_TOP:
        return True
    if rel.startswith(LINUX_ONLY_DIRS):
        return True
    # #115 overlays the interpreter's stdlib into lib/ (including its data
    # files: tests, idlelib, encodings, ...). Both targets copy lib/ with the
    # same script before the overlay, so anything Linux-only there is runtime.
    return rel.startswith("lib/")


def is_expected_windows_only(rel: str) -> bool:
    if rel in TRANSIENT:
        return True
    if rel in {"metin2client.exe", "config.exe"}:
        return True
    # Windows runtime DLLs live at the tree root; Linux has none there.
    return "/" not in rel and rel.lower().endswith(".dll")


def main(argv):
    verbose = "--verbose" in argv
    args = [arg for arg in argv if arg != "--verbose"]
    if len(args) != 2:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2

    linux, windows = Path(args[0]), Path(args[1])
    for root in (linux, windows):
        if not root.is_dir():
            print(f"dist-diff: not a directory: {root}", file=sys.stderr)
            return 2

    linux_files = relative_files(linux)
    windows_files = relative_files(windows)

    expected = 0
    unexpected = []
    identical = 0

    for rel, linux_path in sorted(linux_files.items()):
        windows_path = windows_files.get(rel)
        if windows_path is None:
            if is_expected_linux_only(rel):
                expected += 1
                if verbose:
                    print(f"expected  linux-only   {rel}")
            else:
                unexpected.append(f"linux-only   {rel}")
        elif linux_path.read_bytes() != windows_path.read_bytes():
            unexpected.append(f"differs      {rel}")
        else:
            identical += 1

    for rel in sorted(windows_files.keys() - linux_files.keys()):
        if is_expected_windows_only(rel):
            expected += 1
            if verbose:
                print(f"expected  windows-only {rel}")
        else:
            unexpected.append(f"windows-only {rel}")

    print(
        f"{identical} identical files, {expected} expected platform differences, "
        f"{len(unexpected)} unexpected"
    )
    for line in unexpected:
        print(f"UNEXPECTED {line}")
    return 1 if unexpected else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
