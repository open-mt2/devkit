#!/usr/bin/env bash
# ======================================================
# Vendor the Windows Python 2.7 runtime (T2.4, decision D3)
# ======================================================
# Installs the official PSF 2.7.18 amd64 distribution into the Windows
# dependency prefix:
#
#   bin/python27.dll, bin/msvcr90.dll     runtime DLLs (shipped in dist/)
#   python/Lib, python/DLLs               standard library + extension modules
#   include/python2.7/Python.h            headers for the cross build
#   lib/libpython27.a                     MinGW import lib generated with dlltool
#
# The import lib is generated from the DLL exports because the MSI only ships
# the MSVC python27.lib.
#
# Usage: scripts/fetch-windows-python.sh [--prefix DIR] [--work DIR]

set -euo pipefail

PREFIX="/opt/openmt2/win64"
WORK="/tmp/openmt2-win64-python"
VERSION="2.7.18"
MSI="python-${VERSION}.amd64.msi"
URL="https://www.python.org/ftp/python/${VERSION}/${MSI}"
SHA256="b74a3afa1e0bf2a6fc566a7b70d15c9bfabba3756fb077797d16fffa27800c05"
TARGET="x86_64-w64-mingw32"

while (($#)); do
    case "$1" in
        --prefix) PREFIX="$2"; shift 2 ;;
        --work) WORK="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

for tool in "$TARGET-objdump" "$TARGET-dlltool" msiextract curl; do
    command -v "$tool" >/dev/null || { echo "missing tool: $tool (install msitools)" >&2; exit 1; }
done

mkdir -p "$WORK" "$PREFIX/bin" "$PREFIX/lib" "$PREFIX/include/python2.7" "$PREFIX/python"
cd "$WORK"

if [ ! -f "$MSI" ]; then
    echo "[python27] downloading $MSI"
    curl -fsSL --retry 3 --max-time 600 -o "$MSI" "$URL"
fi
echo "$SHA256  $MSI" | sha256sum -c - >/dev/null

rm -rf extracted
msiextract -C extracted "$MSI" >/dev/null

SRC="$WORK/extracted"
[ -f "$SRC/python27.dll" ] || { echo "python27.dll missing from $MSI" >&2; exit 1; }

install -Dm755 "$SRC/python27.dll" "$PREFIX/bin/python27.dll"
if [ -f "$SRC/msvcr90.dll" ]; then
    install -Dm755 "$SRC/msvcr90.dll" "$PREFIX/bin/msvcr90.dll"
fi
rm -rf "$PREFIX/python/Lib" "$PREFIX/python/DLLs"
cp -r "$SRC/Lib" "$PREFIX/python/Lib"
cp -r "$SRC/DLLs" "$PREFIX/python/DLLs"
cp -r "$SRC/include/." "$PREFIX/include/python2.7/"

# Generate the MinGW import lib from the DLL exports.
"$TARGET-objdump" -p "$SRC/python27.dll" \
    | sed -n '/\[Ordinal\/Name Pointer\] Table/,$p' \
    | grep -oE '\] [A-Za-z_][A-Za-z0-9_@]*$' \
    | sed 's/^] //' \
    | grep -vx 'Table' > python27.exports
{
    echo "LIBRARY python27.dll"
    echo "EXPORTS"
    sed 's/^/  /' python27.exports
} > python27.def
"$TARGET-dlltool" -d python27.def -l "$PREFIX/lib/libpython27.a"

echo "[python27] installed $VERSION into $PREFIX"
echo "  $(wc -l < python27.exports) exports -> lib/libpython27.a"
echo "  python27.dll: $($TARGET-objdump -f "$PREFIX/bin/python27.dll" | awk -F': ' '/file format/{print $2}')"
