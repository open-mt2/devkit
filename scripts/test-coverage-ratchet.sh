#!/usr/bin/env bash
# ======================================================
# Coverage ratchet self-test (TA.7)
# ======================================================
#
# Exercises scripts/coverage-ratchet.py without a build tree: gcov JSON is
# synthesised, summaries are written by hand, and the exit codes are asserted.
#
# Usage: scripts/test-coverage-ratchet.sh
#
# The ratchet gates covered line counts per module. These cases pin the
# contract: a regression fails, new uncovered code does not, a missing module
# does, and a corrupt baseline is an error rather than a silent pass.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
TOOL="$SCRIPT_DIR/coverage-ratchet.py"

[ -f "$TOOL" ] || { echo "error: $TOOL not found" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/coverage-ratchet.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); printf 'PASS  %s\n' "$1"; }
fail() { FAILED=$((FAILED + 1)); printf 'FAIL  %s\n' "$1" >&2; }

# expect <name> <expected exit> <command...>
expect() {
    local name="$1" want="$2"
    shift 2
    "$@" >"$WORK/stdout" 2>"$WORK/stderr"
    local got=$?
    if [ "$got" -eq "$want" ]; then
        pass "$name"
    else
        fail "$name (exit $got, expected $want)"
        sed 's/^/      /' "$WORK/stdout" "$WORK/stderr" >&2
    fi
}

# expect_output <name> <needle>  (reads the last captured stdout/stderr)
expect_output() {
    local name="$1" needle="$2"
    if grep -qF -- "$needle" "$WORK/stdout" "$WORK/stderr"; then
        pass "$name"
    else
        fail "$name (output does not contain '$needle')"
        sed 's/^/      /' "$WORK/stdout" "$WORK/stderr" >&2
    fi
}

write_summary() {
    # write_summary <path> <module:covered:total>...
    local path="$1"
    shift
    {
        echo "# synthetic coverage summary"
        echo "# schema: 1"
        local item name covered total
        for item in "$@"; do
            name="${item%%:*}"
            covered="$(printf '%s' "$item" | cut -d: -f2)"
            total="$(printf '%s' "$item" | cut -d: -f3)"
            echo "$name $covered $total 0.0"
        done
    } >"$path"
}

# --- collect: gcov JSON -> per-module summary ------------------------------

REPO="$WORK/repo"
BUILD="$REPO/build"
mkdir -p "$BUILD" "$REPO/src/Alpha" "$REPO/src/Beta"

python3 - "$BUILD" <<'PY'
import gzip
import json
import pathlib
import sys

build = pathlib.Path(sys.argv[1])
payload = {
    "files": [
        {
            "file": "/nonexistent/src/Alpha/a.cpp",
            "lines": [
                {"line_number": 1, "count": 1},
                {"line_number": 2, "count": 0},
                {"line_number": 3, "count": 1},
            ],
        },
        {
            "file": "/nonexistent/src/Alpha/b.cpp",
            "lines": [{"line_number": 1, "count": 1}, {"line_number": 2, "count": 1}],
        },
        {
            "file": "/nonexistent/src/Beta/c.cpp",
            "lines": [{"line_number": 1, "count": 0}],
        },
        {
            "file": "/nonexistent/third_party/d.cpp",
            "lines": [{"line_number": 1, "count": 1}],
        },
    ]
}
with gzip.open(build / "fixture.gcov.json.gz", "wt") as handle:
    json.dump(payload, handle)
PY

expect "collect exits 0" 0 \
    python3 "$TOOL" collect --build "$BUILD" --root "$REPO" \
        --out "$WORK/current.txt" --files "$WORK/files.txt"

expect_output "collect reports 2 modules" "2 modules, 4/6 lines (66.7%)"

if grep -qx "Alpha 4 5 80.0" "$WORK/current.txt" &&
    grep -qx "Beta 0 1 0.0" "$WORK/current.txt" &&
    grep -qx "TOTAL 4 6 66.7" "$WORK/current.txt"; then
    pass "collect aggregates per module and writes TOTAL"
else
    fail "collect aggregates per module and writes TOTAL"
    sed 's/^/      /' "$WORK/current.txt" >&2
fi

if grep -q "third_party" "$WORK/files.txt"; then
    fail "collect ignores sources outside src/<Package>"
else
    pass "collect ignores sources outside src/<Package>"
fi

# --- collect: no gcov data is an error, not an empty baseline ---------------

expect "collect with no gcov data exits 2" 2 \
    python3 "$TOOL" collect --build "$WORK/empty-build" --out "$WORK/none.txt"
expect_output "collect with no gcov data explains why" "build directory"

mkdir -p "$WORK/no-json"
expect "collect without JSON exits 2" 2 \
    python3 "$TOOL" collect --build "$WORK/no-json" --out "$WORK/none.txt"
expect_output "collect without JSON points at coverage.sh" "coverage.sh"

# --- check: the ratchet contract -------------------------------------------

BASELINE="$WORK/baseline.txt"
write_summary "$BASELINE" Alpha:40:50 Beta:5:5
echo "TOTAL 45 55 0.0" >>"$BASELINE"

write_summary "$WORK/same.txt" Alpha:40:50 Beta:5:5
echo "TOTAL 45 55 0.0" >>"$WORK/same.txt"
expect "identical run passes" 0 \
    python3 "$TOOL" check --current "$WORK/same.txt" --baseline "$BASELINE"
expect_output "identical run is explicit" "OK: no per-module regression"

# Covered lines dropped in one module -> failure naming the module.
write_summary "$WORK/regressed.txt" Alpha:38:50 Beta:5:5
echo "TOTAL 43 55 0.0" >>"$WORK/regressed.txt"
expect "per-module regression exits 1" 1 \
    python3 "$TOOL" check --current "$WORK/regressed.txt" --baseline "$BASELINE"
expect_output "regression names the module and delta" "Alpha: covered lines 38 < 40 (-2)"

# New uncovered code dilutes the percentage but keeps every covered line:
# that is not a regression and must pass.
write_summary "$WORK/grown.txt" Alpha:40:80 Beta:5:5
echo "TOTAL 45 85 0.0" >>"$WORK/grown.txt"
expect "uncovered growth passes (no absolute target)" 0 \
    python3 "$TOOL" check --current "$WORK/grown.txt" --baseline "$BASELINE"

# A module that disappears from the measurement is a regression.
write_summary "$WORK/missing.txt" Alpha:40:50
echo "TOTAL 40 50 0.0" >>"$WORK/missing.txt"
expect "missing module exits 1" 1 \
    python3 "$TOOL" check --current "$WORK/missing.txt" --baseline "$BASELINE"
expect_output "missing module is reported" "Beta: missing from this run"

# A genuinely new module is reported but not a failure (Wave B will add names).
write_summary "$WORK/new.txt" Alpha:40:50 Beta:5:5 Gamma:2:4
echo "TOTAL 47 59 0.0" >>"$WORK/new.txt"
expect "new module passes" 0 \
    python3 "$TOOL" check --current "$WORK/new.txt" --baseline "$BASELINE"
expect_output "new module is announced" "new module, no baseline yet"

# --- check: corrupt or absent baseline must not silently pass --------------

printf 'Alpha nope 50\nTOTAL 1 2 0.0\n' >"$WORK/corrupt.txt"
expect "corrupt baseline exits 2" 2 \
    python3 "$TOOL" check --current "$WORK/same.txt" --baseline "$WORK/corrupt.txt"
expect_output "corrupt baseline names the line" "expected '<module> <hit> <total> <percent>'"

expect "missing baseline exits 2" 2 \
    python3 "$TOOL" check --current "$WORK/same.txt" --baseline "$WORK/absent.txt"
expect_output "missing baseline points at --update" "record one with scripts/coverage.sh --update"

# --- update: deliberate, and refused while the check is red ----------------

cp "$BASELINE" "$WORK/update.txt"
expect "--update refuses a failing check" 1 \
    python3 "$TOOL" check --current "$WORK/regressed.txt" --baseline "$WORK/update.txt" --update
expect_output "refusal explains --force" "pass --force to accept them"

if cmp -s "$BASELINE" "$WORK/update.txt"; then
    pass "--update refusal leaves the baseline untouched"
else
    fail "--update refusal leaves the baseline untouched"
fi

expect "--update --force records the regression" 0 \
    python3 "$TOOL" check --current "$WORK/regressed.txt" --baseline "$WORK/update.txt" --update --force
expect "--force baseline then passes" 0 \
    python3 "$TOOL" check --current "$WORK/regressed.txt" --baseline "$WORK/update.txt"

expect "--update on a green check writes the baseline" 0 \
    python3 "$TOOL" check --current "$WORK/new.txt" --baseline "$WORK/green-update.txt" --update
expect "--update makes the new run the baseline" 0 \
    python3 "$TOOL" check --current "$WORK/new.txt" --baseline "$WORK/green-update.txt"

# --- result ----------------------------------------------------------------

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
