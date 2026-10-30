#!/usr/bin/env python3
"""Per-module coverage ratchet for the OpenMT2 client (TA.7).

Two subcommands:

  collect  turn gcov JSON (``gcov -j``) into a module summary
  check    compare a summary with the committed baseline

The ratchet gates **covered line counts per module**, never an absolute
percentage target: a change is a regression only when a module that used to
exercise *n* lines now exercises fewer. Adding uncovered code therefore does
not turn CI red, while deleting tests, dropping a module or silently skipping
a package does.

Baseline files are plain text, one module per line:

    <module> <covered> <total> <percent>

with a trailing ``TOTAL`` line. ``percent`` is informational; comparisons use
``covered`` (gcov is deterministic for a fixed test set).

Exit codes: 0 ok, 1 regression, 2 usage or corrupt input.
"""

from __future__ import annotations

import argparse
import gzip
import json
import pathlib
import sys

SCHEMA = 1


class RatchetError(Exception):
    """Bad input (missing file, corrupt baseline, no gcov data)."""


def _module_of(source: str, root: pathlib.Path | None) -> str | None:
    """Return the package owning *source*, e.g. ``src/EterBase/x.cpp`` -> EterBase.

    Sources outside ``<root>/src`` fall back to the last ``/src/`` segment so a
    build directory produced in the image can still be inspected from a host
    checkout. Everything else is ignored.
    """
    path = pathlib.PurePosixPath(source)
    if root is not None:
        prefix = pathlib.PurePosixPath(str(root)) / "src"
        try:
            rel = path.relative_to(prefix)
        except ValueError:
            rel = None
        if rel is not None and len(rel.parts) > 1:
            return rel.parts[0]

    marker = "/src/"
    text = str(path)
    index = text.find(marker)
    if index == -1:
        return None
    rest = text[index + len(marker):].split("/")
    return rest[0] if len(rest) > 1 and rest[0] else None


def collect(build: pathlib.Path, root: pathlib.Path | None) -> tuple[dict[str, list[int]], dict[str, list[int]]]:
    """Aggregate gcov JSON into (per-module, per-file) line counts."""
    if not build.is_dir():
        raise RatchetError(f"build directory '{build}' not found")

    modules: dict[str, list[int]] = {}
    files: dict[str, list[int]] = {}
    json_files = sorted(build.rglob("*.gcov.json.gz"))
    if not json_files:
        raise RatchetError(
            f"no gcov JSON under '{build}'; run scripts/coverage.sh without --no-build"
        )

    for path in json_files:
        try:
            with gzip.open(path, "rt") as handle:
                data = json.load(handle)
        except (OSError, ValueError) as error:
            raise RatchetError(f"cannot read '{path}': {error}") from error

        for entry in data.get("files", []):
            source = entry.get("file", "")
            module = _module_of(source, root)
            if module is None:
                continue
            lines = [l for l in entry.get("lines", []) if isinstance(l.get("count"), int)]
            if not lines:
                continue
            total = len(lines)
            hit = sum(1 for line in lines if line["count"] > 0)
            for bucket, key in ((modules, module), (files, source)):
                old = bucket.get(key, [0, 0])
                bucket[key] = [old[0] + hit, old[1] + total]

    if not modules:
        raise RatchetError(
            "gcov data contains no sources under src/<Package>; check --root"
        )
    return modules, files


def _percent(hit: int, total: int) -> float:
    return hit / total * 100.0 if total else 0.0


def write_summary(path: pathlib.Path, modules: dict[str, list[int]], header: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = sorted(modules.items())
    hit = sum(v[0] for _, v in rows)
    total = sum(v[1] for _, v in rows)
    with path.open("w") as handle:
        handle.write(f"# {header}\n")
        handle.write(f"# schema: {SCHEMA}\n")
        for name, (module_hit, module_total) in rows:
            handle.write(
                f"{name} {module_hit} {module_total} {_percent(module_hit, module_total):.1f}\n"
            )
        handle.write(f"TOTAL {hit} {total} {_percent(hit, total):.1f}\n")


def write_files(path: pathlib.Path, files: dict[str, list[int]], header: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = sorted(files.items(), key=lambda item: (item[1][0] / item[1][1] if item[1][1] else 0.0, item[0]))
    with path.open("w") as handle:
        handle.write(f"# {header}\n")
        for source, (hit, total) in rows:
            handle.write(f"{_percent(hit, total):6.1f}% {hit:6d}/{total:<6d} {source}\n")


def read_summary(path: pathlib.Path) -> dict[str, list[int]]:
    if not path.is_file():
        raise RatchetError(f"baseline '{path}' not found")
    modules: dict[str, list[int]] = {}
    for number, raw in enumerate(path.read_text().splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) != 4:
            raise RatchetError(f"{path}:{number}: expected '<module> <hit> <total> <percent>'")
        name, hit, total = parts[0], parts[1], parts[2]
        try:
            modules[name] = [int(hit), int(total)]
            float(parts[3].rstrip("%"))
        except ValueError as error:
            raise RatchetError(f"{path}:{number}: {error}") from error
    if "TOTAL" not in modules:
        raise RatchetError(f"{path}: no TOTAL line; not a coverage baseline")
    return modules


def compare(current: dict[str, list[int]], baseline: dict[str, list[int]]) -> tuple[list[str], list[str], list[str]]:
    """Return (regressions, new modules, removed modules)."""
    regressions: list[str] = []
    added: list[str] = []
    removed: list[str] = []

    for name, (base_hit, _base_total) in sorted(baseline.items()):
        if name == "TOTAL":
            continue
        if name not in current:
            removed.append(name)
            regressions.append(
                f"{name}: missing from this run (baseline {base_hit} covered lines)"
            )
            continue
        hit, total = current[name]
        if hit < base_hit:
            regressions.append(
                f"{name}: covered lines {hit} < {base_hit} ({hit - base_hit:+d})"
            )

    for name in sorted(current):
        if name == "TOTAL" or name in baseline:
            continue
        added.append(name)

    return regressions, added, removed


def _report_rows(current: dict[str, list[int]], baseline: dict[str, list[int]]) -> None:
    rows = [name for name in baseline if name != "TOTAL"]
    for name in sorted(rows):
        base_hit = baseline[name][0]
        if name in current:
            hit, total = current[name]
            state = "regressed" if hit < base_hit else f"baseline {base_hit}"
            print(
                f"  {name:<16} {_percent(hit, total):5.1f}% {hit:6d}/{total:<6d} lines  ({state})"
            )
        else:
            print(f"  {name:<16} {'-':>5} {'missing':>13}  (baseline {base_hit})")


def command_collect(args: argparse.Namespace) -> int:
    build = pathlib.Path(args.build)
    root = pathlib.Path(args.root).resolve() if args.root else None
    modules, files = collect(build, root)
    write_summary(pathlib.Path(args.out), modules, f"OpenMT2 coverage per module - {build}")
    if args.files:
        write_files(pathlib.Path(args.files), files, f"OpenMT2 coverage per file - {build}")
    hit = sum(v[0] for v in modules.values())
    total = sum(v[1] for v in modules.values())
    print(f"[coverage] {len(modules)} modules, {hit}/{total} lines ({_percent(hit, total):.1f}%)")
    return 0


def command_check(args: argparse.Namespace) -> int:
    current_path = pathlib.Path(args.current)
    baseline_path = pathlib.Path(args.baseline)
    current = read_summary(current_path)
    baseline: dict[str, list[int]] = {}
    if baseline_path.exists():
        baseline = read_summary(baseline_path)
    elif not args.update:
        raise RatchetError(
            f"baseline '{baseline_path}' not found; record one with scripts/coverage.sh --update"
        )

    regressions, added, _removed = compare(current, baseline)

    if baseline:
        _report_rows(current, baseline)
    for name in added:
        print(f"  {name:<16} new module, no baseline yet")

    hit, total = current["TOTAL"]
    print(f"[coverage] {len(current) - 1} modules, {hit}/{total} lines ({_percent(hit, total):.1f}%)")

    if regressions:
        for message in regressions:
            print(f"FAIL  {message}", file=sys.stderr)
        if args.update and args.force:
            write_summary(
                baseline_path,
                {k: v for k, v in current.items() if k != "TOTAL"},
                "OpenMT2 coverage baseline (TA.7) - accepted regressions",
            )
            print(f"[coverage] baseline rewritten at '{baseline_path}' (--force)")
            return 0
        if args.update:
            print(
                "error: refusing to rewrite the baseline after a failing check; "
                "review the regressions and pass --force to accept them",
                file=sys.stderr,
            )
            return 1
        return 1

    if args.update:
        write_summary(
            baseline_path,
            {k: v for k, v in current.items() if k != "TOTAL"},
            "OpenMT2 coverage baseline (TA.7)",
        )
        print(f"[coverage] baseline written to '{baseline_path}'")
        return 0

    print("[coverage] OK: no per-module regression")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="coverage-ratchet",
        description="Turn gcov data into a per-module summary and gate regressions.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    collect_parser = sub.add_parser("collect", help="aggregate gcov JSON")
    collect_parser.add_argument("--build", required=True)
    collect_parser.add_argument("--root", default=None,
                                help="source root containing src/<Package> (default: detect)")
    collect_parser.add_argument("--out", required=True, help="module summary to write")
    collect_parser.add_argument("--files", default=None, help="per-file report to write")
    collect_parser.set_defaults(func=command_collect)

    check_parser = sub.add_parser("check", help="compare a summary with the baseline")
    check_parser.add_argument("--current", required=True)
    check_parser.add_argument("--baseline", required=True)
    check_parser.add_argument("--update", action="store_true", help="rewrite the baseline")
    check_parser.add_argument("--force", action="store_true",
                              help="with --update, accept recorded regressions")
    check_parser.set_defaults(func=command_check)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except RatchetError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
