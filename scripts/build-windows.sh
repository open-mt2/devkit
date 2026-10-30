#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$(basename "$SCRIPT_DIR")" = scripts ]; then
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
else
    PROJECT_ROOT="$SCRIPT_DIR"
fi
cd "$PROJECT_ROOT"

BUILD_DIR="${PROJECT_ROOT}/build/windows"
DIST_DIR="${PROJECT_ROOT}/dist"
CLEAN=false
JOBS="$(nproc 2>/dev/null || echo 4)"
while (($#)); do
    case "$1" in
        --clean) CLEAN=true; shift ;;
        -j|--jobs) JOBS="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $(basename "$0") [--clean] [-j|--jobs N]"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

if [ "$CLEAN" = true ]; then
    rm -rf "$BUILD_DIR"
fi

export PKG_CONFIG_LIBDIR=/usr/x86_64-w64-mingw32/lib/pkgconfig
cmake --preset windows
cmake --build --preset windows --parallel "$JOBS"

mkdir -p "$DIST_DIR"
for pair in "metin2client:src/UserInterface/metin2client.exe" "config:src/Config/config.exe"; do
    name="${pair%%:*}"
    path="${pair#*:}"
    if [ -f "$BUILD_DIR/$path" ]; then
        cp "$BUILD_DIR/$path" "$DIST_DIR/$name.exe"
    fi
done
if [ ! -f "$DIST_DIR/metin2client.exe" ]; then
    echo "ERROR: Windows executable '$BUILD_DIR/src/UserInterface/metin2client.exe' not found after build" >&2
    exit 1
fi

# Keep asset layout shared with Linux; Windows runtime DLLs remain in bin/.
if [ -d bin ]; then
    find bin -maxdepth 1 -type f ! -iname '*.dll' ! -name '.gitignore' -exec cp {} "$DIST_DIR/" \;
    for dir in BGM lib mark miles screenshot upload; do
        mkdir -p "$DIST_DIR/$dir"
        if [ -d "bin/$dir" ]; then cp -r "bin/$dir/." "$DIST_DIR/$dir/"; fi
    done
    mkdir -p "$DIST_DIR/pack"
    [ ! -f bin/pack/Index ] || cp bin/pack/Index "$DIST_DIR/pack/"
    cp bin/pack/*.rdch "$DIST_DIR/pack/" 2>/dev/null || true
    cp bin/pack/*.zip "$DIST_DIR/pack/" 2>/dev/null || true
fi
if [ -d treecache ]; then
    mkdir -p "$DIST_DIR/treecache"
    cp treecache/*.tree "$DIST_DIR/treecache/" 2>/dev/null || true
fi

echo "Windows client package assembled in $DIST_DIR"
