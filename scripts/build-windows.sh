#!/usr/bin/env bash
# ======================================================
# OpenMT2 client - Windows cross-build & packaging (T3.1)
# ======================================================
#
# Mirrors scripts/build.sh for the x86_64 MinGW-w64 target: the same asset
# tree and pack archives, plus the Windows binary and its runtime DLLs.
# Point OPENMT2_DIST_DIR somewhere else to build both distributions side by
# side.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$(basename "$SCRIPT_DIR")" = scripts ]; then
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
else
    PROJECT_ROOT="$SCRIPT_DIR"
fi
cd "$PROJECT_ROOT"

BUILD_DIR="${PROJECT_ROOT}/build/windows"
DIST_DIR="${OPENMT2_DIST_DIR:-${PROJECT_ROOT}/dist}"
CLEAN=false
SKIP_PACK=false
JOBS="$(nproc 2>/dev/null || echo 4)"
while (($#)); do
    case "$1" in
        --clean) CLEAN=true; shift ;;
        --skip-pack) SKIP_PACK=true; shift ;;
        -j|--jobs) JOBS="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $(basename "$0") [--clean] [--skip-pack] [-j|--jobs N]"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

if [ "$CLEAN" = true ]; then
    rm -rf "$BUILD_DIR"
fi

WIN64_PREFIX="${OPENMT2_WIN64_DEPS_PREFIX:-/opt/openmt2/win64}"
export PKG_CONFIG_LIBDIR="$WIN64_PREFIX/lib/pkgconfig:/usr/x86_64-w64-mingw32/lib/pkgconfig"

cmake -S "$PROJECT_ROOT" -B "$BUILD_DIR" -G Ninja \
    -DCMAKE_SYSTEM_NAME=Windows \
    -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
    -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
    -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
    -DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_ARCH_X86=OFF \
    -DOPENMT2_WIN64_DEPS_PREFIX="$WIN64_PREFIX" \
    -DCMAKE_FIND_ROOT_PATH="$WIN64_PREFIX;/usr/x86_64-w64-mingw32" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
cmake --build "$BUILD_DIR" --parallel "$JOBS"

mkdir -p "$DIST_DIR"
for pair in "metin2client:src/ui/metin2client.exe" "config:src/Config/config.exe"; do
    name="${pair%%:*}"
    path="${pair#*:}"
    if [ -f "$BUILD_DIR/$path" ]; then
        cp "$BUILD_DIR/$path" "$DIST_DIR/$name.exe"
        echo "  - Installed executable: $(basename "$DIST_DIR")/$name.exe"
    fi
done
if [ ! -f "$DIST_DIR/metin2client.exe" ]; then
    echo "ERROR: Windows executable '$BUILD_DIR/src/ui/metin2client.exe' not found after build" >&2
    exit 1
fi

for dll in python27.dll msvcr90.dll; do
    if [ -f "$WIN64_PREFIX/bin/$dll" ]; then
        cp "$WIN64_PREFIX/bin/$dll" "$DIST_DIR/"
        echo "  - Installed runtime library: $dll"
    else
        echo "WARNING: Windows runtime '$WIN64_PREFIX/bin/$dll' not found" >&2
    fi
done
MINGW_CXX="${MINGW_CXX:-x86_64-w64-mingw32-g++}"
for dll in libstdc++-6.dll libgcc_s_seh-1.dll; do
    if command -v "$MINGW_CXX" >/dev/null 2>&1; then
        dll_path="$("$MINGW_CXX" -print-file-name="$dll" 2>/dev/null || true)"
        if [ -n "$dll_path" ] && [ -f "$dll_path" ]; then
            cp "$dll_path" "$DIST_DIR/"
            echo "  - Installed runtime library: $dll"
        fi
    fi
done

if [ -d bin ]; then
    bash "$PROJECT_ROOT/scripts/copy-assets.sh" --dist "$DIST_DIR" --bin bin --treecache treecache
fi

mkdir -p "$DIST_DIR/pack"
if [ -d bin/pack ]; then
    [ ! -f bin/pack/Index ] || cp bin/pack/Index "$DIST_DIR/pack/"
    [ ! -f bin/pack/Index.dev ] || cp bin/pack/Index.dev "$DIST_DIR/pack/"
    cp bin/pack/*.rdch "$DIST_DIR/pack/" 2>/dev/null || true
fi

if [ "$SKIP_PACK" = false ] && [ -d bin/pack ]; then
    bash "$PROJECT_ROOT/scripts/pack-assets.sh" bin/pack "$DIST_DIR/pack" "${PACK_ARCHIVER:-zip}"
elif [ -d bin/pack ]; then
    cp bin/pack/*.zip "$DIST_DIR/pack/" 2>/dev/null || true
fi

echo "Windows client package assembled in $DIST_DIR"
