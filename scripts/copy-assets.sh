#!/usr/bin/env bash
# ======================================================
# OpenMT2 client - shared asset tree copier (T3.1)
# ======================================================
#
# Copies the platform-independent runtime data from bin/ and treecache/ into a
# distribution directory. Both build.sh (Linux) and build-windows.sh (Windows)
# use it so the two trees stay identical; only binaries, runtime libraries and
# the packer differ.
#
# Usage:
#   copy-assets.sh [--dist DIR] [--bin DIR] [--treecache DIR]
#
# The pack archives are NOT copied here: build.sh and build-windows.sh invoke
# scripts/pack-assets.sh to generate them from pack/Index.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$(basename "$SCRIPT_DIR")" = "scripts" ]; then
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
else
    PROJECT_ROOT="$SCRIPT_DIR"
fi
cd "$PROJECT_ROOT"

DIST_DIR="${OPENMT2_DIST_DIR:-$PROJECT_ROOT/dist}"
BIN_DIR="$PROJECT_ROOT/bin"
TREECACHE_DIR="$PROJECT_ROOT/treecache"

while (($#)); do
    case "$1" in
        --dist)      DIST_DIR="$2"; shift 2 ;;
        --bin)       BIN_DIR="$2"; shift 2 ;;
        --treecache) TREECACHE_DIR="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "copy-assets: unknown option: $1" >&2; exit 2 ;;
    esac
done

mkdir -p "$DIST_DIR"

if [ ! -d "$BIN_DIR" ]; then
    echo "WARNING: '$BIN_DIR' not found; skipping asset copy."
    exit 0
fi

find "$BIN_DIR" -maxdepth 1 -type f ! -iname "*.dll" ! -name ".gitignore" \
    -exec cp {} "$DIST_DIR/" \;

for dir in BGM lib mark miles screenshot upload; do
    mkdir -p "$DIST_DIR/$dir"
    if [ -d "$BIN_DIR/$dir" ]; then
        cp -r "$BIN_DIR/$dir/." "$DIST_DIR/$dir/"
        find "$DIST_DIR/$dir" -name ".gitignore" -delete 2>/dev/null || true
    fi
done

if [ -d "$TREECACHE_DIR" ]; then
    mkdir -p "$DIST_DIR/treecache"
    cp "$TREECACHE_DIR"/*.tree "$DIST_DIR/treecache/" 2>/dev/null || true
fi

echo "  - Copied shared assets from $BIN_DIR"
