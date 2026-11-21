#!/usr/bin/env bash
# ======================================================
# OpenMT2 client - pack manifest injection
# ======================================================
#
# Writes the boot manifest into a pack. The script host refuses to boot a pack
# that does not name its host, and the fetched asset tree predates that
# requirement, so the build adds the file instead of asking every maintainer to
# edit the assets by hand.
#
# Usage: inject-pack-manifest.sh [--bin DIR] [--pack NAME] [--host NAME]
#                                [--entry FILE] [--archive FILE]
#
# Options:
#   --bin DIR      Unpacked pack tree. Default: bin/pack
#   --pack NAME    Pack that receives the manifest. Default: root
#   --host NAME    Script host named in the manifest. Default: python
#   --entry FILE   Entry point the host runs after registration. Default: system.py
#   --archive FILE Also add the manifest to this zip archive, for a package
#                  assembled from prebuilt archives.
#
# An existing manifest is left untouched. A maintainer who edits one owns it,
# and the build only fills the gap in the fetched assets.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$(basename "$SCRIPT_DIR")" = "scripts" ]; then
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
else
    PROJECT_ROOT="$SCRIPT_DIR"
fi
CALLER_DIR="$PWD"
cd "$PROJECT_ROOT"

BIN_DIR="$PROJECT_ROOT/bin/pack"
PACK_NAME="root"
HOST="python"
ENTRY="system.py"
ARCHIVES=()

while (($#)); do
    case "$1" in
        --bin)
            BIN_DIR="$2"
            shift 2
            ;;
        --pack)
            PACK_NAME="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        --entry)
            ENTRY="$2"
            shift 2
            ;;
        --archive)
            ARCHIVES+=("$2")
            shift 2
            ;;
        -h|--help)
            awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' \
                "$SCRIPT_DIR/inject-pack-manifest.sh"
            exit 0
            ;;
        *)
            echo "inject-pack-manifest: unknown option: $1" >&2
            exit 2
            ;;
    esac
done

resolve_path() {
    case "$1" in
        /*) printf '%s' "$1" ;;
        *) printf '%s/%s' "$CALLER_DIR" "$1" ;;
    esac
}

BIN_DIR="$(resolve_path "$BIN_DIR")"

RESOLVED_ARCHIVES=()
for archive in "${ARCHIVES[@]}"; do
    RESOLVED_ARCHIVES+=("$(resolve_path "$archive")")
done
ARCHIVES=("${RESOLVED_ARCHIVES[@]}")

manifest_text() {
    printf 'version=1\nname=%s\nhost=%s\nentry=%s\n' "$PACK_NAME" "$HOST" "$ENTRY"
}

staging=""
cleanup() {
    if [ -n "$staging" ]; then
        rm -rf "$staging"
    fi
}
trap cleanup EXIT

inject_archive() {
    local archive="$1"
    if [ ! -f "$archive" ]; then
        echo "inject-pack-manifest: '$archive' not found; skipping" >&2
        return 0
    fi
    if ! command -v zip >/dev/null 2>&1; then
        echo "inject-pack-manifest: 'zip' is required to update '$archive'" >&2
        return 1
    fi

    staging="$(mktemp -d)"
    manifest_text > "$staging/manifest"
    (cd "$staging" && zip -q -X "$archive" manifest)
    rm -rf "$staging"
    staging=""
    echo "inject-pack-manifest: added manifest to $(basename "$archive")"
}

pack_dir=""
if [ -d "$BIN_DIR" ]; then
    pack_dir="$(find "$BIN_DIR" -mindepth 1 -maxdepth 1 -type d -iname "$PACK_NAME" -print \
        | LC_ALL=C sort | head -n 1)"
fi

if [ -n "$pack_dir" ]; then
    manifest="$pack_dir/manifest"
    if [ -f "$manifest" ]; then
        echo "inject-pack-manifest: kept $(basename "$pack_dir")/manifest"
    else
        manifest_text > "$manifest"
        echo "inject-pack-manifest: wrote $(basename "$pack_dir")/manifest"
    fi
else
    archive="$(find "$BIN_DIR" -mindepth 1 -maxdepth 1 -type f -iname "$PACK_NAME.zip" -print \
        2>/dev/null | LC_ALL=C sort | head -n 1)"
    if [ -n "$archive" ]; then
        ARCHIVES+=("$archive")
    else
        echo "inject-pack-manifest: no '$PACK_NAME' directory or archive under '$BIN_DIR'" >&2
    fi
fi

for archive in "${ARCHIVES[@]}"; do
    inject_archive "$archive"
done
