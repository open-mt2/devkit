#!/usr/bin/env bash
# ======================================================
# OpenMT2 client - line coverage and per-module ratchet
# ======================================================
#
# Builds the tree with gcov instrumentation, runs every test, and reports line
# coverage per module (src/<Package>) and per source file. Uses gcov only: no
# extra dependency in the image.
#
# The ratchet (TA.7) compares covered line counts per module against
# golden/coverage-baseline.txt and fails only on a regression. It never sets an
# absolute percentage target, so adding uncovered code does not turn CI red
# while losing covered lines does.
#
# Usage:
#   scripts/coverage.sh                 # build, test, report
#   scripts/coverage.sh --no-build      # reuse an existing build directory
#   scripts/coverage.sh --check         # fail if any module regressed
#   scripts/coverage.sh --update        # rewrite the committed baseline
#   scripts/coverage.sh --update --force  # accept recorded regressions
#
# Environment:
#   BUILD_DIR          build directory (default: <root>/build-coverage)
#   COVERAGE_DIR       output directory (default: <root>/coverage)
#   COVERAGE_BASELINE  ratchet baseline (default: <root>/golden/coverage-baseline.txt)
#   JOBS               parallel build jobs (default: nproc)
#
# The script pins LC_ALL=C, OPENMT2_AUDIO_BACKEND=null and the llvmpipe
# renderer so the counts do not depend on the host's audio or GL devices.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
TOOL="$SCRIPT_DIR/coverage-ratchet.py"

BUILD="${BUILD_DIR:-$ROOT/build-coverage}"
OUT="${COVERAGE_DIR:-$ROOT/coverage}"
BASELINE="${COVERAGE_BASELINE:-$ROOT/golden/coverage-baseline.txt}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

build=1
mode=report
force=0
for argument in "$@"; do
    case "$argument" in
        --no-build) build=0 ;;
        --check)
            [ "$mode" = report ] || { echo "error: --check and --update are exclusive" >&2; exit 2; }
            mode=check
            ;;
        --update)
            [ "$mode" = report ] || { echo "error: --check and --update are exclusive" >&2; exit 2; }
            mode=update
            ;;
        --force) force=1 ;;
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

if [ "$force" = 1 ] && [ "$mode" != update ]; then
    echo "error: --force only applies to --update" >&2
    exit 2
fi

[ -f "$TOOL" ] || { echo "error: $TOOL not found" >&2; exit 2; }

# Pin the same deterministic environment as scripts/golden-check.sh. Without
# these, audio and GL probing depend on the host's devices and change which
# lines run (MilesLib varied by 31 covered lines between a workstation and CI).
export LC_ALL=C
export OPENMT2_AUDIO_BACKEND=null
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe

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

# Start from zero counters: stale .gcda files from an earlier run would report
# coverage for code this run never executed.
find "$BUILD" -name '*.gcda' -delete 2>/dev/null || true

echo "[coverage] running tests"
ctest --test-dir "$BUILD" --output-on-failure

mapfile -t gcda < <(find "$BUILD" -name '*.gcda' -print)
if [ "${#gcda[@]}" -eq 0 ]; then
    echo "[coverage] no .gcda files: nothing was instrumented" >&2
    exit 1
fi

echo "[coverage] collecting gcov data (${#gcda[@]} objects)"
mkdir -p "$OUT"
# gcov -j names its JSON after the source basename (Type.cpp.gcov.json.gz), so
# running it for every object in one directory lets same-named files overwrite
# each other (EterLib/Resource.cpp vs ScriptLib/Resource.cpp). Give every
# object its own directory instead: one JSON per translation unit.
find "$BUILD" -name '*.gcov.json.gz' -delete 2>/dev/null || true
rm -rf "$BUILD/gcov-json"
mkdir -p "$BUILD/gcov-json"
index=0
for object in "${gcda[@]}"; do
    index=$((index + 1))
    mkdir -p "$BUILD/gcov-json/$index"
    ( cd "$BUILD/gcov-json/$index" && gcov -j -b "$object" >/dev/null 2>&1 || true )
done

python3 "$TOOL" collect --build "$BUILD" --root "$ROOT" \
    --out "$OUT/summary.txt" --files "$OUT/files.txt"

echo "[coverage] 10 least covered files:"
sed -n '2,11p' "$OUT/files.txt" | sed 's/^/  /'
echo "[coverage] full report: $OUT/files.txt"

case "$mode" in
    report)
        ;;
    check)
        python3 "$TOOL" check --current "$OUT/summary.txt" --baseline "$BASELINE"
        ;;
    update)
        if [ "$force" = 1 ]; then
            python3 "$TOOL" check --current "$OUT/summary.txt" --baseline "$BASELINE" --update --force
        else
            python3 "$TOOL" check --current "$OUT/summary.txt" --baseline "$BASELINE" --update
        fi
        ;;
esac
