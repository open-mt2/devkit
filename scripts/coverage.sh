#!/usr/bin/env bash
# ======================================================
# OpenMT2 client - line coverage for the CTest suites
# ======================================================
#
# Builds the tree with gcov instrumentation, runs every test, and reports line
# coverage per source file. Uses gcov only: no extra dependency in the image.
#
# Usage:
#   scripts/coverage.sh                 # build, test, report
#   scripts/coverage.sh --no-build      # reuse an existing build directory
#   scripts/coverage.sh --check         # fail if below the recorded baseline
#
# Environment:
#   BUILD_DIR       build directory (default: <root>/build-coverage)
#   COVERAGE_DIR    output directory (default: <root>/coverage)
#   JOBS            parallel build jobs (default: nproc)
#   MIN_COVERAGE    absolute floor for --check, in percent (default: 0)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

BUILD="${BUILD_DIR:-$ROOT/build-coverage}"
OUT="${COVERAGE_DIR:-$ROOT/coverage}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"
MIN_COVERAGE="${MIN_COVERAGE:-0}"

build=1
check=0
for argument in "$@"; do
    case "$argument" in
        --no-build) build=0 ;;
        --check) check=1 ;;
        -h|--help)
            awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"
            exit 0
            ;;
        *)
            echo "unknown option: $argument" >&2
            exit 2
            ;;
    esac
done

if [ "$build" = 1 ]; then
    echo "[coverage] configuring $BUILD"
    cmake -S "$ROOT" -B "$BUILD" -G Ninja \
        -DCMAKE_BUILD_TYPE=Debug \
        -DCMAKE_C_FLAGS="--coverage -O0" \
        -DCMAKE_CXX_FLAGS="--coverage -O0" \
        -DCMAKE_EXE_LINKER_FLAGS="--coverage" >/dev/null

    echo "[coverage] building with $JOBS jobs"
    cmake --build "$BUILD" --parallel "$JOBS" >/dev/null
fi

echo "[coverage] running tests"
ctest --test-dir "$BUILD" --output-on-failure

mapfile -t gcda < <(find "$BUILD" -name '*.gcda' -print)
if [ "${#gcda[@]}" -eq 0 ]; then
    echo "[coverage] no .gcda files: nothing was instrumented" >&2
    exit 1
fi

echo "[coverage] collecting gcov data (${#gcda[@]} objects)"
mkdir -p "$OUT"
( cd "$BUILD" && gcov -j -b "${gcda[@]}" >/dev/null 2>&1 || true )

python3 - "$BUILD" "$OUT" "$MIN_COVERAGE" "$check" <<'PY'
import gzip
import json
import pathlib
import sys

build, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
minimum, check = float(sys.argv[3]), sys.argv[4] == "1"

files = {}
for path in build.rglob("*.gcov.json.gz"):
    try:
        data = json.load(gzip.open(path, "rt"))
    except Exception:
        continue
    for entry in data.get("files", []):
        source = entry.get("file", "")
        # Keep only project sources: drop system headers and the build tree.
        if not source.startswith(str(build.parent)) or source.startswith(str(build) + "/"):
            continue
        lines = [l for l in entry.get("lines", []) if isinstance(l.get("count"), int)]
        if not lines:
            continue
        total = len(lines)
        hit = sum(1 for l in lines if l["count"] > 0)
        old = files.get(source, (0, 0))
        files[source] = (old[0] + hit, old[1] + total)

if not files:
    print("[coverage] no gcov JSON produced", file=sys.stderr)
    sys.exit(1)

rows = [(hit / total * 100.0, hit, total, src) for src, (hit, total) in files.items()]
rows.sort()
hit = sum(r[1] for r in rows)
total = sum(r[2] for r in rows)
pct = hit / total * 100.0 if total else 0.0

summary = out / "summary.txt"
with summary.open("w") as fh:
    fh.write(f"TOTAL {pct:.1f}% ({hit}/{total} lines)\n")
    for file_pct, file_hit, file_total, src in rows:
        fh.write(f"{file_pct:6.1f}% {file_hit:6d}/{file_total:<6d} {src}\n")

print(f"[coverage] total {pct:.1f}% ({hit}/{total} lines)")
print(f"[coverage] 10 least covered files:")
for file_pct, file_hit, file_total, src in rows[:10]:
    print(f"  {file_pct:6.1f}%  {src}")
print(f"[coverage] full report: {summary}")

baseline = out / "baseline.txt"
if check:
    floor = minimum
    if baseline.exists():
        try:
            floor = max(floor, float(baseline.read_text().split()[1].rstrip("%")))
        except Exception:
            pass
    if pct + 1e-9 < floor:
        print(f"[coverage] FAIL: {pct:.1f}% < {floor:.1f}%", file=sys.stderr)
        sys.exit(1)
    print(f"[coverage] OK: {pct:.1f}% >= {floor:.1f}%")
else:
    baseline.write_text(f"TOTAL {pct:.1f}%\n")
PY
