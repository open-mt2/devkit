#!/usr/bin/env bash
# ======================================================
# OpenMT2 client - SpeedTree geometry cache baker
# ======================================================
#
# Fetches https://github.com/open-mt2/speedtreebkr into tools/speedtree_baker,
# builds the 32-bit Windows dumper, and bakes bin/pack/**/*.spt into
# treecache/<fnv1a32>.tree. build.sh copies that cache into dist/treecache/.
#
# Usage:
#   scripts/bake-trees.sh                 # build (if needed) + incremental bake
#   scripts/bake-trees.sh --force         # full re-bake
#   scripts/bake-trees.sh --verify        # verify existing cache (no Wine)
#   scripts/bake-trees.sh --build-only    # only build speedtree_dumper.exe
#   scripts/bake-trees.sh --fetch-only    # only fetch the baker sources
#
# Any other option is forwarded to bake.py.
#
# Environment:
#   SPEEDTREE_REPO   repository URL (default: open-mt2/speedtreebkr)
#   SPEEDTREE_REF    branch/tag (default: main)
#   SPEEDTREE_UPDATE set to 1 to update an existing checkout
#   SPEEDTREE_DIR    checkout location (default: <root>/tools/speedtree_baker)
#   WINE_LIBS        Wine i386 import-library directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(dirname "$SCRIPT_DIR")"

ROOT="${OPENMT2_ROOT:-$DEFAULT_ROOT}"
SPEEDTREE_REPO="${SPEEDTREE_REPO:-https://github.com/open-mt2/speedtreebkr.git}"
SPEEDTREE_REF="${SPEEDTREE_REF:-main}"
TOOL_DIR="${SPEEDTREE_DIR:-$ROOT/tools/speedtree_baker}"

log()  { printf '\033[1;34m[speedtree]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[speedtree]\033[0m %s\n' "$*" >&2; }

fetch_baker() {
    if [ -d "$TOOL_DIR/.git" ]; then
        if [ "${SPEEDTREE_UPDATE:-0}" = "1" ]; then
            log "Updating speedtreebkr in $TOOL_DIR"
            git -C "$TOOL_DIR" fetch --depth 1 origin "$SPEEDTREE_REF"
            git -C "$TOOL_DIR" checkout -f FETCH_HEAD
        else
            log "Using existing speedtree baker in $TOOL_DIR"
        fi
    elif [ -f "$TOOL_DIR/build.sh" ]; then
        log "Using existing speedtree baker in $TOOL_DIR"
    else
        log "Cloning speedtreebkr into $TOOL_DIR"
        mkdir -p "$(dirname "$TOOL_DIR")"
        rm -rf "$TOOL_DIR"
        git clone --depth 1 --branch "$SPEEDTREE_REF" "$SPEEDTREE_REPO" "$TOOL_DIR"
    fi
}

patch_baker_toolchain() {
    local toolchain="$TOOL_DIR/cmake/i686-w64-windows-gnu.cmake"
    [ -f "$toolchain" ] || return 1
    if grep -q "OPENMT2_MINGW_LIBGCC" "$toolchain"; then
        return 0
    fi
    cat >> "$toolchain" <<'EOF'

if(DEFINED ENV{OPENMT2_MINGW_LIBGCC})
    set(CMAKE_C_STANDARD_LIBRARIES "$ENV{OPENMT2_MINGW_LIBGCC}" CACHE STRING "" FORCE)
    set(CMAKE_CXX_STANDARD_LIBRARIES "$ENV{OPENMT2_MINGW_LIBGCC}" CACHE STRING "" FORCE)
endif()
EOF
}

detect_mingw_libgcc() {
    local candidate
    for candidate in /usr/lib/gcc/i686-w64-mingw32/*-win32 /usr/lib/gcc/i686-w64-mingw32/*; do
        if [ -f "$candidate/libgcc.a" ]; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    return 1
}

detect_wine_libs() {
    if [ -n "${WINE_LIBS:-}" ]; then
        printf '%s' "$WINE_LIBS"
        return 0
    fi
    local candidate
    for candidate in \
        /usr/lib/wine/i386-windows \
        /usr/lib/i386-linux-gnu/wine/i386-windows \
        /usr/lib/i386-linux-gnu/wine; do
        if [ -f "$candidate/libkernel32.a" ]; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    return 1
}

build_baker() {
    if [ ! -f "$TOOL_DIR/build.sh" ]; then
        warn "speedtree baker sources not found in $TOOL_DIR"
        return 1
    fi
    local wine_libs
    if ! wine_libs="$(detect_wine_libs)"; then
        warn "Could not locate Wine's 32-bit import libraries."
        warn "Install wine32 + libwine-dev:i386 or set WINE_LIBS."
        return 1
    fi
    local mingw_libgcc
    if mingw_libgcc="$(detect_mingw_libgcc)"; then
        patch_baker_toolchain
        export OPENMT2_MINGW_LIBGCC="$mingw_libgcc/libgcc.a"
    else
        warn "MinGW libgcc not found; installing gcc-mingw-w64-i686 is recommended."
    fi
    log "Building speedtree_dumper.exe (WINE_LIBS=$wine_libs)"
    (cd "$TOOL_DIR" && WINE_LIBS="$wine_libs" ./build.sh)
}

fetch_only=0
build_only=0
forward=()
for argument in "$@"; do
    case "$argument" in
        --fetch-only) fetch_only=1 ;;
        --build-only) build_only=1 ;;
        -h|--help)
            awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' \
                "${BASH_SOURCE[0]}"
            exit 0
            ;;
        *) forward+=("$argument") ;;
    esac
done

fetch_baker
if [ "$fetch_only" -eq 1 ]; then
    exit 0
fi

if [ ! -f "$TOOL_DIR/build/speedtree_dumper.exe" ]; then
    build_baker
fi
if [ "$build_only" -eq 1 ]; then
    exit 0
fi

if [ ! -d "$ROOT/bin/pack" ]; then
    warn "No bin/pack directory found under $ROOT."
    warn "Run scripts/fetch-bin.sh first; nothing to bake."
    exit 1
fi

export WINEDEBUG="${WINEDEBUG:--all}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-mscoree,mshtml=}"
exec python3 "$TOOL_DIR/bake.py" "${forward[@]}"
