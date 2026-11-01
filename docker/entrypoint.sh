#!/usr/bin/env bash
# ======================================================
# OpenMT2 client development image entrypoint
# ======================================================
#
# With no arguments the usage is shown. Run `build` (or pass build.sh
# options) to compile the client.
#
# Commands:
#   build [build.sh options]   Compile and assemble dist/
#   windows [options]          Cross-build Windows client and assemble dist/
#   shell                      Open an interactive shell
#   bake [bake.py options]     Build/run the SpeedTree geometry baker
#   fetch                      Refresh pkg_* sources and bin/ assets
#   help                       Show this help
#
# Any other first argument is treated as a build.sh option, e.g.
#   docker run ... openmt2/client --clean --skip-pack

set -euo pipefail

WORKSPACE="${OPENMT2_WORKSPACE:-/workspace}"
cd "$WORKSPACE"

find_script() {
    local name="$1"
    if [ -x "./$name" ]; then
        printf './%s' "$name"
    elif [ -x "./scripts/$name" ]; then
        printf './scripts/%s' "$name"
    fi
}

require_script() {
    local name="$1" path
    path="$(find_script "$name")"
    if [ -z "$path" ]; then
        echo "error: $name not found in $WORKSPACE or $WORKSPACE/scripts" >&2
        exit 1
    fi
    printf '%s' "$path"
}

usage() {
    awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' \
        "${BASH_SOURCE[0]}"
}

case "${1:-}" in
    "")
        usage
        ;;
    build)
        shift
        exec "$(require_script build.sh)" "$@"
        ;;
    windows)
        shift
        exec "$(require_script build-windows.sh)" "$@"
        ;;
    shell|bash|sh)
        shift
        exec "${@:-bash}"
        ;;
    bake)
        shift
        exec "$(require_script bake-trees.sh)" "$@"
        ;;
    fetch)
        shift
        "$(require_script fetch-sources.sh)" "$@"
        exec "$(require_script fetch-bin.sh)" "$@"
        ;;
    help|-h|--help)
        usage
        ;;
    *)
        exec "$(require_script build.sh)" "$@"
        ;;
esac
