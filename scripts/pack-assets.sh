#!/usr/bin/env bash
# ======================================================
# OpenMT2 client - pack archive builder
# ======================================================
#
# Turns the unpacked asset directories in bin/pack/ into the zip archives that
# the client registers from pack/Index.
#
# Usage: pack-assets.sh <bin/pack> <dist/pack> [zip|7z|7za] [entry ...]
#
# Without entry arguments every Index entry is packed. With entry arguments
# only those archives are rebuilt; names are matched against Index
# case-insensitively and an unknown name is an error.
#
# The asset tree comes from a Windows checkout, so it is case-insensitive in
# practice. On a case-sensitive filesystem two directories that differ only by
# case (for example ETC/ and etc/) must be merged into the archive named by
# Index; otherwise the files in the non-Index spelling are invisible to the
# client. Directories that Index does not mention are not packed.

set -euo pipefail

SOURCE="${1:?usage: pack-assets.sh <bin/pack> <dist/pack> [archiver] [entry ...]}"
DEST="${2:?usage: pack-assets.sh <bin/pack> <dist/pack> [archiver] [entry ...]}"
ARCHIVER="${3:-zip}"
if (($# > 3)); then
    shift 3
    SELECTED=("$@")
else
    SELECTED=()
fi

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
    local src="$1" out="$2" tmp="$2.tmp"
    rm -f "$tmp"
    case "$ARCHIVER" in
        7z|7za)
            (cd "$src" && "$ARCHIVER" a -tzip -mx=1 -bd -bso0 -bsp0 "$tmp" ./*)
            ;;
        zip)
            (cd "$src" && zip -1 -r -q "$tmp" .)
            ;;
    esac
    mv -f "$tmp" "$out"
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
            return 1
        fi
        log "$name: copying prebuilt archive $(basename "${archives[0]}")"
        cp "${archives[0]}" "$DEST/$name.zip.tmp"
        mv -f "$DEST/$name.zip.tmp" "$DEST/$name.zip"
        return 0
    fi

    if [ "${#matches[@]}" -eq 1 ]; then
        log "$name: packing $(basename "${matches[0]}")"
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
    archive_dir "$stage" "$DEST/$name.zip"
    rm -rf "$stage"
    STAGE=""
}

INDEX_KEYS=()
INDEX_NAMES=()
INDEX_CONTAINERS=()

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

load_index() {
    local name container rest
    while IFS=$'\t ' read -r name container rest; do
        name="${name%$'\r'}"
        container="${container%$'\r'}"
        [ -n "$name" ] || continue
        [ "${name:0:1}" = "#" ] && continue
        INDEX_KEYS+=("$(lower "$name")")
        INDEX_NAMES+=("$name")
        INDEX_CONTAINERS+=("$container")
    done < "$SOURCE/Index"
}

key_index() {
    local want="$1" i
    for ((i = 0; i < ${#INDEX_KEYS[@]}; i++)); do
        if [ "${INDEX_KEYS[i]}" = "$want" ]; then
            printf '%s' "$i"
            return 0
        fi
    done
    return 1
}

count=0
status=0

pack_at() {
    local i="$1" name container
    name="${INDEX_NAMES[i]}"
    container="${INDEX_CONTAINERS[i]}"
    if [ "$container" != "ZIP" ]; then
        warn "Index entry '$name' uses container '$container'; only ZIP is packed"
        return 0
    fi
    pack_entry "$name" || return 1
    count=$((count + 1))
}

load_index

missing=()
if [ "${#SELECTED[@]}" -gt 0 ]; then
    for requested in "${SELECTED[@]}"; do
        if index="$(key_index "$(lower "$requested")")"; then
            pack_at "$index" || status=1
        else
            missing+=("$requested")
        fi
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        for requested in "${missing[@]}"; do
            warn "no Index entry matches '$requested'"
        done
        status=1
    fi
else
    for ((i = 0; i < ${#INDEX_KEYS[@]}; i++)); do
        pack_at "$i" || true
    done
fi

log "pack archives: $count"
exit "$status"
