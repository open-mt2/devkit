#!/usr/bin/env bash
# ======================================================
# OpenMT2 client - pack archive builder
# ======================================================
#
# Turns the unpacked asset directories in bin/pack/ into the zip archives that
# the client registers from pack/Index.
#
# Usage: pack-assets.sh <bin/pack> <dist/pack> [zip|7z|7za]
#
# The asset tree comes from a Windows checkout, so it is case-insensitive in
# practice. On a case-sensitive filesystem two directories that differ only by
# case (for example ETC/ and etc/) must be merged into the archive named by
# Index; otherwise the files in the non-Index spelling are invisible to the
# client. Directories that Index does not mention are not packed.

set -euo pipefail

SOURCE="${1:?usage: pack-assets.sh <bin/pack> <dist/pack> [archiver]}"
DEST="${2:?usage: pack-assets.sh <bin/pack> <dist/pack> [archiver]}"
ARCHIVER="${3:-zip}"

log() { printf '[pack] %s\n' "$*"; }
warn() { printf '[pack] warning: %s\n' "$*" >&2; }

if [ ! -f "$SOURCE/Index" ]; then
    warn "no Index in $SOURCE; nothing to pack"
    exit 1
fi

case "$ARCHIVER" in
    zip|7z|7za) ;;
    *)
        warn "unsupported archiver '$ARCHIVER'"
        exit 1
        ;;
esac

mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"
STAGE=""
cleanup() {
    if [ -n "$STAGE" ]; then
        rm -rf "$STAGE"
    fi
}
trap cleanup EXIT

archive_dir() {
    local src="$1" out="$2"
    case "$ARCHIVER" in
        7z|7za)
            (cd "$src" && "$ARCHIVER" a -tzip -mx=1 -bd -bso0 -bsp0 "$out" ./*)
            ;;
        zip)
            (cd "$src" && zip -1 -r -q "$out" .)
            ;;
    esac
}

pack_entry() {
    local name="$1"
    local -a matches=()
    local -a archives=()
    local stage

    mapfile -t matches < <(
        find "$SOURCE" -mindepth 1 -maxdepth 1 -type d -iname "$name" -print \
            | LC_ALL=C sort
    )

    if [ "${#matches[@]}" -eq 0 ]; then
        mapfile -t archives < <(
            find "$SOURCE" -mindepth 1 -maxdepth 1 -type f -iname "$name.zip" -print \
                | LC_ALL=C sort
        )
        if [ "${#archives[@]}" -eq 0 ]; then
            warn "Index entry '$name' has no matching directory or archive"
            return 0
        fi
        log "$name: copying prebuilt archive $(basename "${archives[0]}")"
        cp "${archives[0]}" "$DEST/$name.zip"
        return 0
    fi

    if [ "${#matches[@]}" -eq 1 ]; then
        log "$name: packing $(basename "${matches[0]}")"
        rm -f "$DEST/$name.zip"
        archive_dir "${matches[0]}" "$DEST/$name.zip"
        return 0
    fi

    stage="$(mktemp -d)"
    STAGE="$stage"
    local dir
    for dir in "${matches[@]}"; do
        log "$name: merging $(basename "$dir")"
        cp -a "$dir/." "$stage/"
    done
    rm -f "$DEST/$name.zip"
    archive_dir "$stage" "$DEST/$name.zip"
    rm -rf "$stage"
    STAGE=""
}

count=0
while IFS=$'\t ' read -r name container rest; do
    name="${name%$'\r'}"
    container="${container%$'\r'}"
    [ -n "$name" ] || continue
    [ "${name:0:1}" = "#" ] && continue
    if [ "$container" != "ZIP" ]; then
        warn "Index entry '$name' uses container '$container'; only ZIP is packed"
        continue
    fi
    pack_entry "$name"
    count=$((count + 1))
done < "$SOURCE/Index"

log "pack archives: $count"
