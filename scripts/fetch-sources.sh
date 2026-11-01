#!/usr/bin/env bash
# ======================================================
# OpenMT2 client - consolidated source fetcher (TB.3)
# ======================================================
#
# Clones the three consolidated repositories (neoeter, neoeter-python, client)
# into <root>/src/<name>. Replaces fetch-packages.sh for image builds and local
# checkouts. The repository list and its dependency order are defined below.
#
# Environment:
#   SRC_REF          branch/tag to check out (default: main)
#   SRC_ORG          GitHub organization (default: open-mt2)
#   SRC_DEPTH        clone depth (default: 1; 0 = full history)
#   GITHUB_TOKEN     optional token, used for private clones
#   SRC_CACHE_BUST   ignored by the script; changing it invalidates the Docker
#                    layer that runs the fetch

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(dirname "$SCRIPT_DIR")"

ROOT="${1:-${OPENMT2_ROOT:-$DEFAULT_ROOT}}"
SRC_REF="${SRC_REF:-main}"
SRC_ORG="${SRC_ORG:-open-mt2}"
SRC_DEPTH="${SRC_DEPTH:-1}"
SRC_DIR="$ROOT/src"

SOURCES=(
    neoeter=neoeter
    neoeter-python=neoeter-python
    client=client
)

log()  { printf '\033[1;34m[sources]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[sources]\033[0m %s\n' "$*" >&2; }

mkdir -p "$SRC_DIR"

base_url="https://github.com/${SRC_ORG}"
if [ -n "${GITHUB_TOKEN:-}" ]; then
    base_url="https://x-access-token:${GITHUB_TOKEN}@github.com/${SRC_ORG}"
fi

for source in "${SOURCES[@]}"; do
    repo="${source%%=*}"
    dir="${source#*=}"

    target="$SRC_DIR/$dir"
    url="$base_url/$repo.git"
    depth_args=()
    [ "$SRC_DEPTH" = "0" ] || depth_args=(--depth "$SRC_DEPTH")

    if [ -d "$target/.git" ]; then
        log "updating $repo -> src/$dir"
        git -C "$target" fetch --quiet --tags "${depth_args[@]}" origin "$SRC_REF"
        git -C "$target" checkout --quiet FETCH_HEAD
    else
        log "cloning $repo -> src/$dir"
        git clone --quiet "${depth_args[@]}" --branch "$SRC_REF" "$url" "$target"
    fi
done

log "sources ready under $SRC_DIR"
