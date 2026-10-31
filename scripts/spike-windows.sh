#!/usr/bin/env bash
# Diagnostic i686 probe, not the D10 64-bit shipping toolchain.
# Run inside the devkit image. Sources are read only; output goes under build/.
# A completed inventory exits zero even when packages fail. Setup errors fail.
set -euo pipefail
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
src=${1:-/workspace/src}
out=${2:-/workspace/build/windows-spike}
map=${SPIKE_MAP:-$script_dir/sources.map}
cmake=${SPIKE_CMAKE:-i686-w64-mingw32-cmake}
[[ -d "$src" && -f "$map" ]] || { echo 'Missing source directory or source map' >&2; exit 2; }
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
infrastructure_failure=0
if [[ -z "${SPIKE_CMAKE:-}" ]]; then
    for tool in i686-w64-mingw32-gcc i686-w64-mingw32-g++ ninja cmake; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            printf 'Missing required tool: %s\n' "$tool"
            infrastructure_failure=2
        fi
    done
fi
printf 'repository\tstatus\tlog\n'
while IFS='=' read -r repo dir; do
    repo="${repo%%#*}"; repo="${repo//[[:space:]]/}"
    dir="${dir//[[:space:]]/}"
    [[ -z "$repo" ]] && continue
    [[ -n "$dir" ]] || dir="$repo"
    log="$run/$dir.log"
    if [[ ! -f "$src/$dir/CMakeLists.txt" ]]; then
        status=source-missing
        infrastructure_failure=2
        echo "Missing $src/$dir/CMakeLists.txt" > "$log"
    elif ! command -v "$cmake" >/dev/null 2>&1; then
        status=tool-missing
        infrastructure_failure=2
        echo "Missing command: $cmake" > "$log"
    elif "${configure[@]}" -G Ninja -S "$src/$dir" -B "$run/$dir" -DOPENMT2_RENDERER=GL -DBUILD_TESTS=OFF -DBUILD_TESTING=OFF > "$log" 2>&1; then
        if cmake --build "$run/$dir" --parallel 2 -- -k 0 >> "$log" 2>&1; then
            status=build-passed
        else
            status=build-failed
        fi
    else
        status=configure-failed
    fi
    printf '%s\t%s\t%s\n' "$dir" "$status" "$log"
    if [[ -d "$src/$dir/.git" ]]; then
        git -C "$src/$dir" rev-parse HEAD
    fi
    cat "$log"
done < "$map"

exit "$infrastructure_failure"
