#!/usr/bin/env bash
# ======================================================
# The Old Metin2 Project - Automated client build script
# Linux Build & Packaging Script
# ======================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The script lives in scripts/ in the packaging repository but is copied to the
# image root. Support both layouts so `./scripts/build.sh` uses the project
# root instead of building inside scripts/.
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

# Default configuration
BUILD_TYPE="Release"
BUILD_DIR="${PROJECT_ROOT}/build"
DIST_DIR="${OPENMT2_DIST_DIR:-${PROJECT_ROOT}/dist}"
PACK_ARCHIVES=true
CLEAN_BUILD=false
RUN_TESTS=false
NUM_JOBS="$(nproc 2>/dev/null || echo 4)"

# Help message
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -b, --build-type <TYPE>   CMake build type (Release, Debug, RelWithDebInfo). Default: Release
  -j, --jobs <N>            Number of parallel build jobs. Default: $NUM_JOBS
  -t, --test                Run CTest test suites after build
  --clean                   Remove existing build directory before configuring
  --skip-pack               Skip packing bin/pack/* zip archives (faster build for code iteration)
  -h, --help                Show this help message
EOF
}

# Parse command line arguments
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
        -t|--test)
            RUN_TESTS=true
            shift
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

# Check prerequisites
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

# Clean if requested
if [ "$CLEAN_BUILD" = true ] && [ -d "$BUILD_DIR" ]; then
    echo "Cleaning build directory: $BUILD_DIR"
    rm -rf "$BUILD_DIR"
fi

# Configure & Build
echo ""
echo "[2/5] Configuring and building client binaries..."
cmake -B "$BUILD_DIR" -G "$BUILD_GENERATOR" -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
cmake --build "$BUILD_DIR" --parallel "$NUM_JOBS"

# Optional tests
if [ "$RUN_TESTS" = true ]; then
    echo ""
    echo "[2b/5] Running CTest test suites..."
    ctest --test-dir "$BUILD_DIR" --output-on-failure
fi

# Assemble dist package
echo ""
echo "[3/5] Assembling client distribution directory in '$DIST_DIR'..."
if [ "$CLEAN_BUILD" = true ]; then
    rm -rf "$DIST_DIR"
fi
mkdir -p "$DIST_DIR"

# Copy main executables
METIN2_BIN="$BUILD_DIR/src/UserInterface/metin2client"
if [ -f "$METIN2_BIN" ]; then
    rm -f "$DIST_DIR/metin2client"
    cp "$METIN2_BIN" "$DIST_DIR/metin2client"
    chmod +x "$DIST_DIR/metin2client"
    # Create convenience symlink / wrapper
    ln -sf metin2client "$DIST_DIR/metin2"
    echo "  - Installed executable: dist/metin2client"
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

# Self-contained runtime (#115): the binary keeps a build-tree RUNPATH and
# links libzip/libpython from the image. Ship those two next to it and point
# RUNPATH at $ORIGIN/runtime (set in the root CMakeLists) so `dist/` runs
# outside the development image. BUNDLED_RUNTIME_LIBS overrides the set.
RUNTIME_DIR="$DIST_DIR/runtime"
BUNDLED_RUNTIME_LIBS="${BUNDLED_RUNTIME_LIBS:-libzip.so.4 libpython2.7.so.1.0}"
if [ -n "$BUNDLED_RUNTIME_LIBS" ]; then
    mkdir -p "$RUNTIME_DIR"
    for lib in $BUNDLED_RUNTIME_LIBS; do
        lib_path="$(ldconfig -p 2>/dev/null | awk -v name="$lib" '$1 == name { print $NF; exit }')"
        if [ -n "$lib_path" ] && [ -e "$lib_path" ]; then
            cp -L "$lib_path" "$RUNTIME_DIR/$lib"
            echo "  - Bundled runtime library: runtime/$lib"
        else
            echo "WARNING: runtime library '$lib' not found; dist/ will need it from the host"
        fi
    done
fi

# The interpreter is embedded with Python home "." (ScriptLib), so it reads
# its standard library from ./lib. The asset tree only carries the game-side
# subset; overlay the full CPython 2.7 stdlib and flatten lib-dynload (#115).
PYTHON27_BIN="${PYTHON27_BIN:-python2.7}"
if command -v "$PYTHON27_BIN" >/dev/null 2>&1; then
    PY_PREFIX="$("$PYTHON27_BIN" -c 'import sys; print(sys.prefix)' 2>/dev/null || true)"
    PY_STDLIB="$PY_PREFIX/lib/python2.7"
    if [ -n "$PY_PREFIX" ] && [ -d "$PY_STDLIB" ]; then
        mkdir -p "$DIST_DIR/lib"
        cp -r "$PY_STDLIB/." "$DIST_DIR/lib/"
        if [ -d "$DIST_DIR/lib/lib-dynload" ]; then
            find "$DIST_DIR/lib/lib-dynload" -maxdepth 1 -type f -name "*.so*" \
                -exec cp {} "$DIST_DIR/lib/" \;
            rm -rf "$DIST_DIR/lib/lib-dynload"
        fi
        echo "  - Overlaid CPython 2.7 stdlib from $PY_STDLIB"
    else
        echo "WARNING: CPython 2.7 stdlib not found under '$PY_PREFIX'; dist/lib stays asset-only"
    fi
else
    echo "WARNING: '$PYTHON27_BIN' not found; dist/lib stays asset-only"
fi

# Copy base asset directories from bin/
echo ""
echo "[4/5] Copying asset and runtime data from bin/..."
if [ -d "bin" ]; then
    bash "$SCRIPT_DIR/copy-assets.sh" --dist "$DIST_DIR" --bin bin --treecache treecache
    if [ -d "treecache" ]; then
        echo "  - Installed tree geometry cache: dist/treecache"
    fi

    # Pack metadata (Index/Index.dev/rdch) is copied by pack-assets.sh when the
    # archives are built; with --skip-pack copy it here so the dist stays valid.
    mkdir -p "$DIST_DIR/pack"
    if [ "$PACK_ARCHIVES" = false ] && [ -f "bin/pack/Index" ]; then
        cp "bin/pack/Index" "$DIST_DIR/pack/"
        [ ! -f "bin/pack/Index.dev" ] || cp "bin/pack/Index.dev" "$DIST_DIR/pack/"
        cp bin/pack/*.rdch "$DIST_DIR/pack/" 2>/dev/null || true
    fi
else
    echo "WARNING: 'bin/' directory not found. Skipping asset copy."
fi

# Build & copy pack archives
echo ""
if [ "$PACK_ARCHIVES" = true ] && [ -d "bin/pack" ]; then
    echo "[5/5] Compressing and installing pack archives into dist/pack/..."
    bash "$SCRIPT_DIR/pack-assets.sh" --source bin/pack --dest "$DIST_DIR/pack"
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
