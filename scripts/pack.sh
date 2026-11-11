#!/usr/bin/env bash
# ======================================================
# OpenMT2 client - manual pack archive helper
# ======================================================
#
# Repacks archives in dist/pack/ from the unpacked asset directories in
# bin/pack/ without running a full build.
#
# Usage: pack.sh [--bin DIR] [--dist DIR] [--archiver zip|7z|7za] [entry ...]
#
# Without entry names every archive listed in bin/pack/Index is regenerated.
# With entry names only those archives are replaced. Names are matched against
# Index case-insensitively, so ETC and etc both select the ETC archive.
#
# Examples:
#   pack.sh              regenerate every archive in dist/pack/
#   pack.sh ETC          repack bin/pack/ETC into dist/pack/ETC.zip
#   pack.sh bgm sound    repack two archives

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$(basename "$SCRIPT_DIR")" = "scripts" ]; then
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
else
    PROJECT_ROOT="$SCRIPT_DIR"
fi
cd "$PROJECT_ROOT"

BIN_DIR="$PROJECT_ROOT/bin/pack"
DIST_ROOT="${OPENMT2_DIST_DIR:-$PROJECT_ROOT/dist}"
ARCHIVER=""
ENTRIES=()

while (($#)); do
    case "$1" in
        --bin)
            BIN_DIR="$2"
            shift 2
            ;;
        --dist)
            DIST_ROOT="$2"
            shift 2
            ;;
        --archiver)
            ARCHIVER="$2"
            shift 2
            ;;
        -h|--help)
            awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' \
                "${BASH_SOURCE[0]}"
            exit 0
            ;;
        --)
            shift
            ENTRIES+=("$@")
            break
            ;;
        -*)
            echo "pack: unknown option: $1" >&2
            exit 2
            ;;
        *)
            ENTRIES+=("$1")
            shift
            ;;
    esac
done

if [ -z "$ARCHIVER" ]; then
    if command -v 7z >/dev/null 2>&1; then
        ARCHIVER="7z"
    elif command -v 7za >/dev/null 2>&1; then
        ARCHIVER="7za"
    elif command -v zip >/dev/null 2>&1; then
        ARCHIVER="zip"
    else
        echo "pack: neither '7z', '7za', nor 'zip' is installed" >&2
        exit 1
    fi
fi

if [ ! -d "$BIN_DIR" ]; then
    echo "pack: '$BIN_DIR' not found; fetch the assets first" >&2
    exit 1
fi

HELPER="$PROJECT_ROOT/scripts/pack-assets.sh"
if [ ! -x "$HELPER" ]; then
    echo "pack: pack-assets.sh not found in $PROJECT_ROOT/scripts" >&2
    exit 1
fi

PACK_DIR="$DIST_ROOT/pack"
echo "OpenMT2 pack: $BIN_DIR -> $PACK_DIR"

if [ "${#ENTRIES[@]}" -eq 0 ]; then
    bash "$HELPER" "$BIN_DIR" "$PACK_DIR" "$ARCHIVER"
else
    bash "$HELPER" "$BIN_DIR" "$PACK_DIR" "$ARCHIVER" "${ENTRIES[@]}"
fi
