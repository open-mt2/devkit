#!/usr/bin/env bash
# ======================================================
# The Old Metin2 Project - Automated client build script
# Linux Build & Packaging Script
# ======================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$(basename "$SCRIPT_DIR")" = "scripts" ]; then
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
else
    PROJECT_ROOT="$SCRIPT_DIR"
fi
cd "$PROJECT_ROOT"

echo "======================================================"
echo "The Old Metin2 Project - Automated client build script"
echo "Linux Build Environment"
echo "======================================================"

BUILD_TYPE="Release"
BUILD_DIR="${PROJECT_ROOT}/build"
DIST_DIR="${OPENMT2_DIST_DIR:-${PROJECT_ROOT}/dist}"
PACK_ARCHIVES=true
CLEAN_BUILD=false
NUM_JOBS="$(nproc 2>/dev/null || echo 4)"

BUNDLED_RUNTIME_LIBS="${BUNDLED_RUNTIME_LIBS:-libzip.so.4 libpython2.7.so.1.0}"

resolve_library() {
    local soname="$1" path=""
    path="$(ldconfig -p 2>/dev/null \
        | awk -v name="$soname" '$1 == name { print $NF; exit }')"
    if [ -z "$path" ] || [ ! -f "$path" ]; then
        path="$(ldd "${BUILD_DIR}/src/ui/metin2client" 2>/dev/null \
            | awk -v name="$soname" '$1 == name { print $3; exit }')"
    fi
    [ -n "$path" ] && [ -f "$path" ] && printf '%s\n' "$path"
}

install_runtime_libs() {
    local runtime="$DIST_DIR/runtime"
    local lib path installed=0

    mkdir -p "$runtime"
    for lib in $BUNDLED_RUNTIME_LIBS; do
        path="$(resolve_library "$lib")"
        if [ -z "$path" ]; then
            echo "  - WARNING: could not resolve $lib; the package will rely on the host"
            continue
        fi
        if [ "$(readlink -f "$path")" != "$(readlink -f "$runtime/$lib")" ]; then
            cp -Lf "$path" "$runtime/$lib"
        fi
        echo "  - Bundled runtime library: $runtime/$lib"
        installed=$((installed + 1))
    done

    if [ "$installed" -eq 0 ]; then
        echo "  - WARNING: no runtime libraries bundled"
    fi
}

install_python_stdlib() {
    command -v python2.7 >/dev/null 2>&1 || {
        echo "  - WARNING: python2.7 not found; dist/lib may be incomplete"
        return 0
    }

    local stdlib
    stdlib="$(python2.7 -c 'import sys; print(sys.prefix + "/lib/python2.7")')"
    if [ ! -d "$stdlib" ]; then
        echo "  - WARNING: CPython 2.7 stdlib not found at $stdlib"
        return 0
    fi

    echo "  - Installing CPython 2.7 stdlib from $stdlib"
    mkdir -p "$DIST_DIR/lib"
    (
        cd "$stdlib"
        find . -mindepth 1 -maxdepth 1 ! -name lib-dynload \
            -exec cp -a {} "$DIST_DIR/lib/" \;
    )
    if [ -d "$stdlib/lib-dynload" ]; then
        cp -a "$stdlib/lib-dynload"/. "$DIST_DIR/lib/" 2>/dev/null || true
    fi
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -b, --build-type <TYPE>   CMake build type (Release, Debug, RelWithDebInfo). Default: Release
  -j, --jobs <N>            Number of parallel build jobs. Default: $NUM_JOBS
  --clean                   Remove existing build directory before configuring
  --skip-pack               Skip packing bin/pack/* zip archives (faster build for code iteration)
  -h, --help                Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--build-type)
            BUILD_TYPE="$2"
            shift 2
            ;;
        -j|--jobs)
            NUM_JOBS="$2"
            shift 2
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --skip-pack)
            PACK_ARCHIVES=false
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

echo "[1/5] Checking dependencies..."
if ! command -v cmake >/dev/null 2>&1; then
    echo "ERROR: 'cmake' is not installed or not in PATH."
    exit 1
fi

BUILD_GENERATOR="Unix Makefiles"
if command -v ninja >/dev/null 2>&1; then
    BUILD_GENERATOR="Ninja"
fi

ARCHIVER=""
if command -v 7z >/dev/null 2>&1; then
    ARCHIVER="7z"
elif command -v 7za >/dev/null 2>&1; then
    ARCHIVER="7za"
elif command -v zip >/dev/null 2>&1; then
    ARCHIVER="zip"
else
    echo "WARNING: Neither '7z', '7za', nor 'zip' was found. Packing archives will be disabled."
    PACK_ARCHIVES=false
fi

echo "  - CMake Generator: $BUILD_GENERATOR"
echo "  - Build Type:      $BUILD_TYPE"
echo "  - Parallel Jobs:   $NUM_JOBS"
echo "  - Pack Archiver:   ${ARCHIVER:-None}"

if [ "$CLEAN_BUILD" = true ] && [ -d "$BUILD_DIR" ]; then
    echo "Cleaning build directory: $BUILD_DIR"
    rm -rf "$BUILD_DIR"
fi

echo ""
echo "[2/5] Configuring and building client binaries..."
cmake -B "$BUILD_DIR" -G "$BUILD_GENERATOR" -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
cmake --build "$BUILD_DIR" --parallel "$NUM_JOBS"

echo ""
echo "[3/5] Assembling client distribution directory in '$DIST_DIR'..."
if [ "$CLEAN_BUILD" = true ]; then
    rm -rf "$DIST_DIR"
fi
mkdir -p "$DIST_DIR"

METIN2_BIN="$BUILD_DIR/src/ui/metin2client"
if [ -f "$METIN2_BIN" ]; then
    rm -f "$DIST_DIR/metin2client"
    cp "$METIN2_BIN" "$DIST_DIR/metin2client"
    chmod +x "$DIST_DIR/metin2client"
    ln -sf metin2client "$DIST_DIR/metin2"
    echo "  - Installed executable: dist/metin2client"
    install_runtime_libs
else
    echo "ERROR: Executable '$METIN2_BIN' not found after build!"
    exit 1
fi

CONFIG_BIN="$BUILD_DIR/src/Config/config"
if [ -f "$CONFIG_BIN" ]; then
    cp "$CONFIG_BIN" "$DIST_DIR/config"
    chmod +x "$DIST_DIR/config"
    echo "  - Installed configuration utility: dist/config"
fi

echo ""
echo "[4/5] Copying asset and runtime data from bin/..."
if [ -d "bin" ]; then
    bash "$PROJECT_ROOT/scripts/copy-assets.sh" --dist "$DIST_DIR" --bin bin --treecache treecache
    if [ -d "treecache" ]; then
        echo "  - Installed tree geometry cache: dist/treecache"
    fi

    mkdir -p "$DIST_DIR/pack"
    if [ -f "bin/pack/Index" ]; then
        cp "bin/pack/Index" "$DIST_DIR/pack/"
    fi
    cp bin/pack/*.rdch "$DIST_DIR/pack/" 2>/dev/null || true
else
    echo "WARNING: 'bin/' directory not found. Skipping asset copy."
fi

install_python_stdlib

echo ""
if [ "$PACK_ARCHIVES" = true ] && [ -d "bin/pack" ]; then
    echo "[5/5] Compressing and installing pack archives into dist/pack/..."

    PACK_HELPER="$PROJECT_ROOT/scripts/pack-assets.sh"
    if [ ! -x "$PACK_HELPER" ]; then
        echo "ERROR: pack-assets.sh not found!" >&2
        exit 1
    fi

    rm -f "$DIST_DIR/pack"/*.zip
    "$PACK_HELPER" "bin/pack" "$DIST_DIR/pack" "$ARCHIVER"
else
    echo "[5/5] Skipping pack archives creation (--skip-pack: preserving existing archives in dist/pack/)."
    mkdir -p "${DIST_DIR}/pack"
    if [ -d "bin/pack" ]; then
        cp bin/pack/*.zip "${DIST_DIR}/pack/" 2>/dev/null || true
    fi
fi

echo ""
echo "======================================================"
echo "Client package successfully assembled!"
echo "Location: ${DIST_DIR}"
echo ""
echo "To run the client:"
echo "  cd dist && ./metin2client"
echo "======================================================"
