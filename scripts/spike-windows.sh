#!/usr/bin/env bash
# Diagnostic i686 probe, not the D10 64-bit shipping toolchain.
# Run inside the devkit image. Sources are read only; output goes under build/.
# A completed inventory exits zero even when packages fail. Setup errors fail.
set -euo pipefail
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
src=${1:-/workspace/src}
out=${2:-/workspace/build/windows-spike}
map=${SPIKE_MAP:-$script_dir/packages.map}
cmake=${SPIKE_CMAKE:-i686-w64-mingw32-cmake}
[[ -d "$src" && -f "$map" ]] || { echo 'Missing source directory or package map' >&2; exit 2; }
mkdir -p "$out"
# A fresh directory avoids stale configure results without deleting earlier evidence.
run=$(mktemp -d "$out/run.XXXXXX")
printf 'Diagnostic target: i686; shipping target remains x86_64 (D10)\n'
# pkg-config has its own search rules, independent of CMake root modes.
export PKG_CONFIG_LIBDIR=${SPIKE_PKG_CONFIG_LIBDIR:-/usr/i686-w64-mingw32/lib/pkgconfig}
export PKG_CONFIG_PATH=
configure=("$cmake")
if [[ -z "${SPIKE_CMAKE:-}" ]] && ! command -v "$cmake" >/dev/null 2>&1; then
    cmake=cmake
    configure=(cmake -DCMAKE_SYSTEM_NAME=Windows
        -DCMAKE_C_COMPILER=i686-w64-mingw32-gcc
        -DCMAKE_CXX_COMPILER=i686-w64-mingw32-g++
        -DCMAKE_FIND_ROOT_PATH=/usr/i686-w64-mingw32
        -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER
        -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
        -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY)
    echo 'i686-w64-mingw32-cmake absent; using explicit MinGW CMake arguments'
fi
printf 'Configure command: %s; renderer: GL\nLogs: %s\n' "$cmake" "$run"
printf 'package\tstatus\tlog\n'
while IFS='=' read -r repo package; do
    [[ "$repo" == pkg_* ]] || continue
    log="$run/$package.log"
    if [[ ! -f "$src/$package/CMakeLists.txt" ]]; then
        status=source-missing
        echo "Missing $src/$package/CMakeLists.txt" > "$log"
    elif ! command -v "$cmake" >/dev/null 2>&1; then
        status=tool-missing
        echo "Missing command: $cmake" > "$log"
    elif "${configure[@]}" -S "$src/$package" -B "$run/$package" -DOPENMT2_RENDERER=GL -DBUILD_TESTS=OFF -DBUILD_TESTING=OFF > "$log" 2>&1; then
        if cmake --build "$run/$package" --parallel 2 >> "$log" 2>&1; then
            status=build-passed
        else
            status=build-failed
        fi
    else
        status=configure-failed
    fi
    printf '%s\t%s\t%s\n' "$package" "$status" "$log"
    if [[ -d "$src/$package/.git" ]]; then
        git -C "$src/$package" rev-parse HEAD
    fi
    cat "$log"
done < "$map"
