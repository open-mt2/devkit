#!/usr/bin/env bash
# ======================================================
# Fixed-function feature matrix (T1.8)
# ======================================================
# Generates docs/feature-matrix.md from the sources: every D3DRS_*,
# D3DTSS_*, D3DSAMP_*, D3DTS_* and FVF layout the client asks for, plus the
# shader calls that are no-ops on the GL path (D13).
#
# Usage:
#   scripts/feature-matrix.sh            # write the matrix
#   scripts/feature-matrix.sh --write    # same
#   scripts/feature-matrix.sh --check    # fail if the checked-in matrix is stale
#
# The generator is scripts/feature-matrix.py. Regenerate after touching render
# state, texture-stage state, sampler state, transform, FVF, light, material or
# shader call sites; T5.2 uses the checked-in result as its test plan.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT="$ROOT/docs/feature-matrix.md"

PYTHON="${PYTHON:-}"
if [ -z "$PYTHON" ]; then
    if command -v python3 >/dev/null 2>&1; then
        PYTHON=python3
    elif command -v python >/dev/null 2>&1; then
        PYTHON=python
    else
        echo "error: python3 (or python) is required" >&2
        exit 1
    fi
fi

generate() {
    "$PYTHON" "$SCRIPT_DIR/feature-matrix.py" --root "$ROOT" --output "$1"
}

case "${1:-}" in
    ""|--write|--update)
        generate "$OUTPUT"
        echo "wrote ${OUTPUT#"$ROOT/"}"
        ;;
    --check)
        TMP="$(mktemp)"
        trap 'rm -f "$TMP"' EXIT
        generate "$TMP"
        if diff -u "$OUTPUT" "$TMP" >&2; then
            echo "feature matrix is current"
        else
            echo "error: docs/feature-matrix.md is stale." >&2
            echo "       run scripts/feature-matrix.sh --write and review the diff." >&2
            exit 1
        fi
        ;;
    -h|--help)
        sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        ;;
    *)
        echo "error: unknown option '$1' (expected --write or --check)" >&2
        exit 1
        ;;
esac
