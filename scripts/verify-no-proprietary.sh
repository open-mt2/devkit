#!/usr/bin/env bash
# ======================================================
# OpenMT2 devkit - refuse to publish proprietary content
# ======================================================
#
# The original client `bin/` tree, the `pack/` archives and the assembled
# `dist/` are licensed content fetched or built by the image consumer; they
# must never be baked into an image pushed to a public registry.
#
# `treecache/` is intentionally excluded from this check: the baked tree
# geometry is vendored in the devkit (treecache/README.md) so that normal
# builds do not need the SpeedTree toolchain, Wine or clang/lld.
#
# Usage:
#   scripts/verify-no-proprietary.sh [workspace-root]
#
# Exits 1 and lists every offending path when something is found.

set -euo pipefail

ROOT="${1:-${OPENMT2_WORKSPACE:-/workspace}}"

if [ ! -d "$ROOT" ]; then
    echo "error: workspace not found: $ROOT" >&2
    exit 1
fi

failures=()

nonempty_dir() {
    local dir="$1"
    [ -d "$dir" ] || return 1
    [ -n "$(find "$dir" -mindepth 1 ! -name .gitignore -print -quit 2>/dev/null)" ]
}

check_dir() {
    local dir="$1" label="$2"
    if nonempty_dir "$dir"; then
        failures+=("${dir#"$ROOT"/} ($label)")
    fi
}

check_dir "$ROOT/bin" "original client assets"
check_dir "$ROOT/dist" "packaged client"

while IFS= read -r -d '' path; do
    failures+=("${path#"$ROOT"/} (pack archive)")
done < <(
    find "$ROOT" -name .git -prune -o -type f \
        \( -name '*.zip' -o -name '*.rdch' -o -name Index \) \
        -path '*/pack/*' -print0 2>/dev/null
)

if [ "${#failures[@]}" -eq 0 ]; then
    echo "[verify] no proprietary client assets found in $ROOT"
    exit 0
fi

echo "error: refusing to publish proprietary client content from $ROOT:" >&2
for failure in "${failures[@]}"; do
    echo "  - $failure" >&2
done
echo "hint: build with WITH_BIN=0 and keep bin/, dist/ and pack archives" >&2
echo "      out of the image." >&2
exit 1
