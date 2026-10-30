#!/usr/bin/env bash
# ======================================================
# OpenMT2 client - package source fetcher
# ======================================================
#
# Clones every pkg_* repository from the OpenMT2 organization into
# <root>/src/<Package>, which is the layout expected by the root
# CMakeLists.txt produced for the build image.
#
# The canonical mapping/order lives in packages.map next to this script. Any
# pkg_* repository that is not listed there is still cloned (with a derived
# directory name) so new packages are picked up automatically.
#
# Environment:
#   PKG_REF       branch/tag to check out (default: main). Accepts the special
#                 value "default" to use each repository's default branch.
#   PKG_ORG       GitHub organization (default: open-mt2)
#   GITHUB_TOKEN  optional token, avoids the anonymous API rate limit
#   GITHUB_API    API endpoint (default: https://api.github.com)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(dirname "$SCRIPT_DIR")"

ROOT="${1:-${OPENMT2_ROOT:-$DEFAULT_ROOT}}"
PKG_REF="${PKG_REF:-main}"
PKG_ORG="${PKG_ORG:-open-mt2}"
GITHUB_API="${GITHUB_API:-https://api.github.com}"
MAP_FILE="${MAP_FILE:-$SCRIPT_DIR/packages.map}"
SRC_DIR="$ROOT/src"

log()  { printf '\033[1;34m[packages]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[packages]\033[0m %s\n' "$*" >&2; }

mkdir -p "$SRC_DIR"

declare -A DIR_BY_REPO=()
ORDERED_REPOS=()
if [ -f "$MAP_FILE" ]; then
    while IFS='=' read -r repo dir; do
        repo="${repo%%#*}"
        repo="${repo//[[:space:]]/}"
        dir="${dir//[[:space:]]/}"
        [ -z "$repo" ] && continue
        DIR_BY_REPO["$repo"]="$dir"
        ORDERED_REPOS+=("$repo")
    done < "$MAP_FILE"
fi

# Turn "pkg_some_name" into "SomeName" for repositories that are not listed in
# packages.map. This is only a best-effort fallback; add an explicit mapping
# when a package needs a specific spelling (e.g. EterGrnLib).
derive_dir_name() {
    local repo="$1"
    local suffix="${repo#pkg_}"
    local part result=""
    IFS='_' read -ra parts <<< "$suffix"
    for part in "${parts[@]}"; do
        result+="${part^}"
    done
    printf '%s' "$result"
}

list_pkg_repositories() {
    GITHUB_API="$GITHUB_API" PKG_ORG="$PKG_ORG" GITHUB_TOKEN="${GITHUB_TOKEN:-}" \
        python3 - <<'PY'
import json
import os
import sys
import urllib.request

api = os.environ["GITHUB_API"].rstrip("/")
org = os.environ["PKG_ORG"]
token = os.environ.get("GITHUB_TOKEN", "")
page = 1
found = []
while True:
    request = urllib.request.Request(
        f"{api}/orgs/{org}/repos?per_page=100&page={page}",
        headers={"Accept": "application/vnd.github+json"},
    )
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.load(response)
    if not isinstance(payload, list) or not payload:
        break
    found.extend(repo["name"] for repo in payload if repo.get("name", "").startswith("pkg_"))
    if len(payload) < 100:
        break
    page += 1
for name in found:
    print(name)
PY
}

repos=()
if discovery="$(list_pkg_repositories 2>/dev/null)"; then
    while IFS= read -r repo; do
        [ -n "$repo" ] && repos+=("$repo")
    done <<< "$discovery"
fi

if [ "${#repos[@]}" -eq 0 ]; then
    warn "Could not query $GITHUB_API; falling back to packages.map."
    repos=("${ORDERED_REPOS[@]}")
fi

# Keep packages.map order first (CMake dependency order), then append unknown
# repositories alphabetically.
ordered=()
for repo in "${ORDERED_REPOS[@]}"; do
    for found in "${repos[@]}"; do
        if [ "$found" = "$repo" ]; then
            ordered+=("$repo")
            break
        fi
    done
done
mapfile -t extras < <(printf '%s\n' "${repos[@]}" | sort)
for repo in "${extras[@]}"; do
    [ -z "$repo" ] && continue
    skip=0
    for known in "${ORDERED_REPOS[@]}"; do
        [ "$repo" = "$known" ] && skip=1 && break
    done
    [ "$skip" -eq 0 ] && ordered+=("$repo")
done

if [ "${#ordered[@]}" -eq 0 ]; then
    warn "No pkg_* repositories found; nothing to clone."
    exit 0
fi

log "Fetching ${#ordered[@]} package repositories (ref: $PKG_REF) into $SRC_DIR"

for repo in "${ordered[@]}"; do
    dir="${DIR_BY_REPO[$repo]:-}"
    if [ -z "$dir" ]; then
        dir="$(derive_dir_name "$repo")"
        warn "$repo is not listed in packages.map; using src/$dir"
    fi
    target="$SRC_DIR/$dir"
    url="https://github.com/$PKG_ORG/$repo.git"

    if [ -d "$target/.git" ]; then
        log "Updating $repo -> src/$dir"
        if [ "$PKG_REF" = "default" ]; then
            git -C "$target" fetch --depth 1 origin
            git -C "$target" reset --hard FETCH_HEAD
        else
            git -C "$target" fetch --depth 1 origin "$PKG_REF"
            git -C "$target" checkout -f FETCH_HEAD
        fi
    else
        rm -rf "$target"
        log "Cloning $repo -> src/$dir"
        if [ "$PKG_REF" = "default" ]; then
            git clone --depth 1 "$url" "$target"
        else
            git clone --depth 1 --branch "$PKG_REF" "$url" "$target"
        fi
    fi
done

log "Package sources ready under $SRC_DIR"
