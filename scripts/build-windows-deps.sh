#!/usr/bin/env bash
# ======================================================
# Cross-build the Windows (x86_64-w64-mingw32) dependency set (T2.3)
# ======================================================
# Builds zlib, lzo2, libzip and SDL2 from pinned sources into a prefix that
# the Windows toolchain file and build-windows.sh point CMake/pkg-config at.
# libjpeg is intentionally absent: T2.2 replaced it with stb_image_write.
#
# Usage:
#   scripts/build-windows-deps.sh [--prefix DIR] [--work DIR] [-j N]
#
# The dockerfile runs this once per image build; the result is baked into
# /opt/openmt2/win64.

set -euo pipefail

PREFIX="/opt/openmt2/win64"
WORK="/tmp/openmt2-win64-deps"
JOBS="$(nproc 2>/dev/null || echo 4)"

while (($#)); do
    case "$1" in
        --prefix) PREFIX="$2"; shift 2 ;;
        --work) WORK="$2"; shift 2 ;;
        -j|--jobs) JOBS="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

TARGET=x86_64-w64-mingw32
CC="${TARGET}-gcc"
CXX="${TARGET}-g++"
RC="${TARGET}-windres"
AR="${TARGET}-ar"
RANLIB="${TARGET}-ranlib"

for tool in "$CC" "$CXX" "$RC" "$AR" "$RANLIB" cmake ninja make; do
    command -v "$tool" >/dev/null || { echo "missing tool: $tool" >&2; exit 1; }
done

mkdir -p "$WORK" "$PREFIX"
cd "$WORK"

fetch() {
    local url="$1" file="$2" sha="$3"
    if [ ! -f "$file" ]; then
        echo "[deps] downloading $file"
        curl -fsSL --retry 3 --max-time 300 -o "$file" "$url"
    fi
    echo "$sha  $file" | sha256sum -c - >/dev/null
}

# --- zlib -------------------------------------------------------------------
fetch "https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz" \
      "zlib-1.3.1.tar.gz" \
      "9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23"
rm -rf zlib-1.3.1 && tar xf zlib-1.3.1.tar.gz
# zlib's CMake always builds a DLL too; its win32 Makefile gives a clean libz.a.
( cd zlib-1.3.1 && \
  make -f win32/Makefile.gcc -j"$JOBS" libz.a \
      CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="-O2" >/dev/null && \
  install -Dm644 libz.a "$PREFIX/lib/libz.a" && \
  install -Dm644 zlib.h "$PREFIX/include/zlib.h" && \
  install -Dm644 zconf.h "$PREFIX/include/zconf.h" )
mkdir -p "$PREFIX/lib/pkgconfig"
cat > "$PREFIX/lib/pkgconfig/zlib.pc" <<PC
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: zlib
Description: zlib compression library
Version: 1.3.1
Libs: -L\${libdir} -lz
Cflags: -I\${includedir}
PC

# --- lzo2 -------------------------------------------------------------------
fetch "https://www.oberhumer.com/opensource/lzo/download/lzo-2.10.tar.gz" \
      "lzo-2.10.tar.gz" \
      "c0f892943208266f9b6543b3ae308fab6284c5c90e627931446fb49b4221a072"
rm -rf lzo-2.10 && tar xf lzo-2.10.tar.gz
( cd lzo-2.10 && \
  ./configure --host="$TARGET" --prefix="$PREFIX" \
      --disable-shared --enable-static \
      CC="$CC" AR="$AR" RANLIB="$RANLIB" >/dev/null && \
  make -j"$JOBS" >/dev/null && \
  make install >/dev/null )

# --- libzip -----------------------------------------------------------------
fetch "https://libzip.org/download/libzip-1.10.1.tar.gz" \
      "libzip-1.10.1.tar.gz" \
      "9669ae5dfe3ac5b3897536dc8466a874c8cf2c0e3b1fdd08d75b273884299363"
rm -rf libzip-1.10.1 && tar xf libzip-1.10.1.tar.gz
cmake -S libzip-1.10.1 -B build-libzip -G Ninja \
    -DCMAKE_SYSTEM_NAME=Windows \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_RC_COMPILER="$RC" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DBUILD_SHARED_LIBS=OFF \
    -DZLIB_LIBRARY="$PREFIX/lib/libz.a" \
    -DZLIB_INCLUDE_DIR="$PREFIX/include" \
    -DENABLE_BZIP2=OFF -DENABLE_LZMA=OFF -DENABLE_ZSTD=OFF -DENABLE_OPENSSL=OFF \
    -DBUILD_DOC=OFF -DBUILD_EXAMPLES=OFF -DBUILD_TOOLS=OFF -DBUILD_REGRESS=OFF >/dev/null
cmake --build build-libzip --parallel "$JOBS" >/dev/null
cmake --install build-libzip >/dev/null

# --- SDL2 -------------------------------------------------------------------
fetch "https://github.com/libsdl-org/SDL/releases/download/release-2.30.9/SDL2-2.30.9.tar.gz" \
      "SDL2-2.30.9.tar.gz" \
      "24b574f71c87a763f50704bbb630cbe38298d544a1f890f099a4696b1d6beba4"
rm -rf SDL2-2.30.9 && tar xf SDL2-2.30.9.tar.gz
cmake -S SDL2-2.30.9 -B build-sdl2 -G Ninja \
    -DCMAKE_SYSTEM_NAME=Windows \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_RC_COMPILER="$RC" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DSDL_SHARED=OFF -DSDL_STATIC=ON -DSDL_TEST=OFF -DSDL_TESTS=OFF >/dev/null
cmake --build build-sdl2 --parallel "$JOBS" >/dev/null
cmake --install build-sdl2 >/dev/null

# --- miniaudio (header-only; built as a static library) ---------------------
MINIAUDIO_VERSION=0.11.25
fetch "https://raw.githubusercontent.com/mackron/miniaudio/${MINIAUDIO_VERSION}/miniaudio.h" \
      "miniaudio.h" \
      "ac7af4de748b7e26b777f37e01cee313a308a7296a3eb080e2906b320cc55c89"
install -Dm644 miniaudio.h "$PREFIX/include/miniaudio/miniaudio.h"
printf '#define MINIAUDIO_IMPLEMENTATION\n#include <miniaudio/miniaudio.h>\n' > miniaudio_impl.c
"$CC" -O2 -I"$PREFIX/include" -c miniaudio_impl.c -o miniaudio_impl.o
"$AR" rcs "$PREFIX/lib/libminiaudio.a" miniaudio_impl.o
cat > "$PREFIX/lib/pkgconfig/miniaudio.pc" <<PC
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: miniaudio
Description: Single-file audio playback and capture library
Version: ${MINIAUDIO_VERSION}
Cflags: -I\${includedir}
Libs: -L\${libdir} -lminiaudio
Libs.private: -lwinmm -lole32 -luuid -loleaut32
PC

echo "[deps] installed into $PREFIX:"
find "$PREFIX" -name '*.a' -printf '  %P\n' | sort
