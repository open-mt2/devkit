#!/usr/bin/env bash
# ======================================================
# Pre-refactor golden check (TA.8)
# ======================================================
# Freeze and verify the deterministic artefacts the structural refactor
# (Wave B) and the platform work must preserve:
#
#   render.sha256        committed renderer PNG goldens
#   api.sha256           embedded Python API surfaces (TA.6)
#   ctest-tests.txt      the CTest inventory
#   transcripts/*.txt    pack, model and collision test output
#
# Usage:
#   scripts/golden-check.sh              # verify against golden/
#   scripts/golden-check.sh --update     # deliberately accept a new baseline
#
# Build the workspace first (e.g. openmt2/client -t --skip-pack). The script
# does not build; it uses $OPENMT2_BUILD_DIR (default: <repo>/build).
#
# To accept an API surface change, regenerate the package snapshot first:
#   OPENMT2_UPDATE_PYTHON_API=1 scripts/golden-check.sh --update
# To accept a renderer change, --update passes --update to test_render_golden.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
GOLDEN="$ROOT/golden"
BUILD_DIR="${OPENMT2_BUILD_DIR:-$ROOT/build}"

UPDATE=false
case "${1:-}" in
    "") ;;
    --update) UPDATE=true ;;
    -h|--help)
        sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        echo "error: unknown option '$1' (expected --update)" >&2
        exit 2
        ;;
esac

# Import-time Python setup and the pinned renderer environment.
export LC_ALL=C
export OPENMT2_AUDIO_BACKEND=null
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe

PASSED=0
FAILED=0
pass() { PASSED=$((PASSED + 1)); printf 'PASS  %s\n' "$1"; }
fail() { FAILED=$((FAILED + 1)); printf 'FAIL  %s\n' "$1" >&2; }
die() { printf 'error: %s\n' "$1" >&2; exit 2; }

[ -d "$BUILD_DIR" ] || die "build directory '$BUILD_DIR' not found; build the workspace first"
[ -f "$BUILD_DIR/CTestTestfile.cmake" ] ||
    die "'$BUILD_DIR' is not a configured CMake build directory"
[ -d "$GOLDEN" ] || die "golden directory '$GOLDEN' not found"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
write_manifest() {
    local manifest="$1"
    shift
    : > "$tmpdir/manifest"
    local path
    for path in "$@"; do
        [ -f "$ROOT/$path" ] || die "cannot snapshot missing file '$path'"
        (cd "$ROOT" && sha256sum "$path") >> "$tmpdir/manifest" ||
            die "sha256sum failed for '$path'"
    done
    sort -k2 "$tmpdir/manifest" > "$manifest"
}

check_manifest() {
    local label="$1"
    local manifest="$2"
    if [ ! -f "$manifest" ]; then
        fail "$label: missing manifest '$manifest'"
        return
    fi

    local expected actual path bad=0 count=0
    while IFS= read -r line; do
        case "$line" in
            ''|'#'*) continue ;;
        esac
        path="${line#*  }"
        expected="${line%%  *}"
        count=$((count + 1))
        actual="$(cd "$ROOT" && sha256sum "$path" 2>/dev/null | awk '{print $1}')"
        if [ -z "$actual" ]; then
            fail "$label: missing '$path'"
            bad=$((bad + 1))
        elif [ "$actual" != "$expected" ]; then
            fail "$label: '$path' changed (expected ${expected:0:12}, got ${actual:0:12})"
            bad=$((bad + 1))
        fi
    done < "$manifest"

    if [ "$count" -eq 0 ]; then
        fail "$label: empty manifest"
    elif [ "$bad" -eq 0 ]; then
        pass "$label ($count artefacts)"
    fi
}

run_binary() {
    local label="$1"
    local relative="$2"
    shift 2

    local binary="$BUILD_DIR/$relative"
    if [ ! -x "$binary" ]; then
        fail "$label: missing test binary '$relative'"
        return
    fi

    local output status
    output="$(cd "$BUILD_DIR" && "./$relative" "$@" 2>&1)"
    status=$?
    if [ "$status" -ne 0 ]; then
        printf '%s\n' "$output" >&2
        fail "$label (exit $status)"
    else
        pass "$label"
    fi
}

run_transcript() {
    local name="$1"
    shift
    local transcript="$GOLDEN/transcripts/$name.txt"
    local actual="$tmpdir/$name.txt"
    : > "$actual"

    local relative binary status
    for relative in "$@"; do
        printf '=== %s ===\n' "$relative" >> "$actual"
        binary="$BUILD_DIR/$relative"
        status=127
        if [ -x "$binary" ]; then
            (cd "$BUILD_DIR" && "./$relative" >> "$actual" 2>&1)
            status=$?
        else
            printf 'missing binary\n' >> "$actual"
        fi
        printf 'exit=%d\n' "$status" >> "$actual"
    done

    if grep -q '^exit=[1-9]' "$actual"; then
        sed 's/^/  /' "$actual" >&2
        fail "transcript $name: a test binary failed"
        return
    fi

    if [ "$UPDATE" = true ]; then
        mkdir -p "$GOLDEN/transcripts"
        cp "$actual" "$transcript"
        pass "transcript $name (updated)"
        return
    fi

    if [ ! -f "$transcript" ]; then
        fail "transcript $name: missing '$transcript'"
        return
    fi

    if diff -u "$transcript" "$actual" > "$tmpdir/$name.diff"; then
        pass "transcript $name"
    else
        sed 's/^/  /' "$tmpdir/$name.diff" >&2
        fail "transcript $name differs"
    fi
}

collect_inventory() {
    (cd "$BUILD_DIR" && ctest -N 2>/dev/null) |
        sed -n 's/^ *Test *#[0-9][0-9]*: //p' |
        sort
}

# ---------------------------------------------------------------------------
# Update or check
# ---------------------------------------------------------------------------
mkdir -p "$GOLDEN/transcripts"

if [ "$UPDATE" = true ]; then
    echo "[update] regenerating golden manifests and transcripts"
    [ "${OPENMT2_UPDATE_PYTHON_API:-}" = "1" ] ||
        echo "[update] keeping Python API snapshots (set OPENMT2_UPDATE_PYTHON_API=1 to rewrite them)"

    run_binary "render goldens (updated)" src/EterLib/tests/test_render_golden --update
    run_binary "Python API: ScriptLib" src/ScriptLib/tests/test_python_scriptlib_api \
        "$ROOT/src/ScriptLib/tests/data/python_api_scriptlib.txt"
    run_binary "Python API: EterPythonLib" src/EterPythonLib/tests/test_python_eterpythonlib_api \
        "$ROOT/src/EterPythonLib/tests/data/python_api_eterpythonlib.txt"
    run_binary "Python API: client" src/UserInterface/tests/test_python_client_api \
        "$ROOT/src/UserInterface/tests/data/python_api_client.txt"
    [ "$FAILED" -eq 0 ] || die "refusing to refresh goldens after a failing check"

    shopt -s nullglob
    render_files=("$ROOT"/src/EterLib/tests/golden/render/*.png)
    shopt -u nullglob
    [ "${#render_files[@]}" -gt 0 ] || die "no render goldens found"
    render_relative=()
    for file in "${render_files[@]}"; do
        render_relative+=("${file#"$ROOT"/}")
    done
    write_manifest "$GOLDEN/render.sha256" "${render_relative[@]}"
    write_manifest "$GOLDEN/api.sha256" \
        "src/ScriptLib/tests/data/python_api_scriptlib.txt" \
        "src/EterPythonLib/tests/data/python_api_eterpythonlib.txt" \
        "src/UserInterface/tests/data/python_api_client.txt"

    run_transcript pack \
        src/EterPack/tests/test_pack_formats \
        src/EterPack/tests/test_eterpack
    run_transcript model \
        src/EterGrnLib/tests/test_gr2_reader \
        src/EterGrnLib/tests/test_grn_reference
    run_transcript collision \
        src/EterLib/tests/test_detector \
        src/EterLib/tests/test_grpmath
    run_transcript packet \
        src/UserInterface/tests/test_packet

    collect_inventory > "$GOLDEN/ctest-tests.txt"
    inventory_total="$(cd "$BUILD_DIR" && ctest -N 2>/dev/null | sed -n 's/^Total Tests: //p')"
    [ "$(wc -l < "$GOLDEN/ctest-tests.txt")" = "$inventory_total" ] ||
        die "CTest inventory parse mismatch ($(wc -l < "$GOLDEN/ctest-tests.txt")/$inventory_total)"
    pass "CTest inventory (updated)"
else
    echo "[check] verifying pre-refactor goldens"

    check_manifest "render hashes" "$GOLDEN/render.sha256"
    check_manifest "Python API hashes" "$GOLDEN/api.sha256"

    run_binary "render goldens" src/EterLib/tests/test_render_golden
    run_binary "Python API: ScriptLib" src/ScriptLib/tests/test_python_scriptlib_api \
        "$ROOT/src/ScriptLib/tests/data/python_api_scriptlib.txt"
    run_binary "Python API: EterPythonLib" src/EterPythonLib/tests/test_python_eterpythonlib_api \
        "$ROOT/src/EterPythonLib/tests/data/python_api_eterpythonlib.txt"
    run_binary "Python API: client" src/UserInterface/tests/test_python_client_api \
        "$ROOT/src/UserInterface/tests/data/python_api_client.txt"

    run_transcript pack \
        src/EterPack/tests/test_pack_formats \
        src/EterPack/tests/test_eterpack
    run_transcript model \
        src/EterGrnLib/tests/test_gr2_reader \
        src/EterGrnLib/tests/test_grn_reference
    run_transcript collision \
        src/EterLib/tests/test_detector \
        src/EterLib/tests/test_grpmath
    run_transcript packet \
        src/UserInterface/tests/test_packet

    collect_inventory > "$tmpdir/ctest-tests.txt"
    inventory_total="$(cd "$BUILD_DIR" && ctest -N 2>/dev/null | sed -n 's/^Total Tests: //p')"
    if [ "$(wc -l < "$tmpdir/ctest-tests.txt")" != "$inventory_total" ]; then
        fail "CTest inventory parse mismatch ($(wc -l < "$tmpdir/ctest-tests.txt")/$inventory_total)"
    elif diff -u "$GOLDEN/ctest-tests.txt" "$tmpdir/ctest-tests.txt" > "$tmpdir/ctest.diff"; then
        pass "CTest inventory ($(wc -l < "$tmpdir/ctest-tests.txt") tests)"
    else
        sed 's/^/  /' "$tmpdir/ctest.diff" >&2
        fail "CTest inventory changed"
    fi
fi

printf '\n%d checks passed, %d failed\n' "$PASSED" "$FAILED"
[ "$FAILED" -eq 0 ]
