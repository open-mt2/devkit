#!/usr/bin/env bash
# ======================================================
# OpenMT2 client - pack archive builder (#115)
# ======================================================
#
# Packs the unpacked asset directories under bin/pack/ into the archives the
# client reads at runtime.
#
# The archive list and its spelling come from `pack/Index`, never from the
# directory names: the index is what the client loads, and a case-sensitive
# filesystem can hold case variants of one archive (`ETC/` and `etc/`). Every
# directory that matches an index entry case-insensitively is merged into the
# single archive named by the index, and unindexed directories are ignored.
#
# Usage:
#   pack-assets.sh [--source DIR] [--dest DIR] [--index FILE]
#                  [--archiver zip|7z] [--quiet]
#
# Environment:
#   PACK_ARCHIVER   overrides the archiver (zip or 7z/7za)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$(basename "$SCRIPT_DIR")" = "scripts" ]; then
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
else
    PROJECT_ROOT="$SCRIPT_DIR"
fi
cd "$PROJECT_ROOT"

SOURCE="bin/pack"
DEST="dist/pack"
INDEX=""
ARCHIVER="${PACK_ARCHIVER:-}"
QUIET=false

usage() {
    sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while (($#)); do
    case "$1" in
        --source) SOURCE="$2"; shift 2 ;;
        --dest)   DEST="$2"; shift 2 ;;
        --index)  INDEX="$2"; shift 2 ;;
        --archiver) ARCHIVER="$2"; shift 2 ;;
        --quiet)  QUIET=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "pack-assets: unknown option: $1" >&2; exit 2 ;;
    esac
done

log() { [ "$QUIET" = true ] || printf '%s\n' "$*"; }
warn() { printf 'pack-assets: warning: %s\n' "$*" >&2; }

if [ ! -d "$SOURCE" ]; then
    echo "pack-assets: source directory not found: $SOURCE" >&2
    exit 1
fi
SOURCE="$(cd "$SOURCE" && pwd)"
[ -n "$INDEX" ] || INDEX="$SOURCE/Index"
if [ ! -f "$INDEX" ]; then
    echo "pack-assets: pack index not found: $INDEX" >&2
    exit 1
fi

if [ -z "$ARCHIVER" ]; then
    if command -v zip >/dev/null 2>&1; then
        ARCHIVER=zip
    elif command -v 7z >/dev/null 2>&1; then
        ARCHIVER=7z
    elif command -v 7za >/dev/null 2>&1; then
        ARCHIVER=7za
    else
        echo "pack-assets: no zip archiver (zip/7z/7za) found" >&2
        exit 1
    fi
fi
case "$ARCHIVER" in
    zip|7z|7za|7zz) ;;
    *) echo "pack-assets: unsupported archiver: $ARCHIVER" >&2; exit 2 ;;
esac

mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"

# Directory names under bin/pack, one per line.
mapfile -t PACK_DIRS < <(find "$SOURCE" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort)

pack_dir() { # <source-dir> <archive>
    [ -n "$(ls -A "$SOURCE/$1")" ] || return 0
    case "$ARCHIVER" in
        zip)
            ( cd "$SOURCE/$1" && zip -1 -r -q "$2" . )
            ;;
        7z*)
            ( cd "$SOURCE/$1" && "$ARCHIVER" a -tzip -mx=1 -bd -bso0 -bsp0 "$2" ./* >/dev/null )
            ;;
    esac
}

packed=0
merged=0
missing=0
while IFS= read -r line || [ -n "$line" ]; do
    # Strip comments and surrounding whitespace; the first field is the name.
    line="${line%%#*}"
    line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "$line" ] || continue
    name="${line%%[[:space:]]*}"
    [ -n "$name" ] || continue

    matches=()
    for dir in "${PACK_DIRS[@]}"; do
        if [ "${dir,,}" = "${name,,}" ]; then
            matches+=("$dir")
        fi
    done

    if [ "${#matches[@]}" -eq 0 ]; then
        warn "index entry '$name' has no directory under $SOURCE; skipped"
        missing=$((missing + 1))
        continue
    fi
    if [ "${#matches[@]}" -gt 1 ]; then
        merged=$((merged + 1))
        log "  - Merging ${matches[*]} into ${name}.zip"
    else
        log "  - Packing ${matches[0]} -> ${name}.zip"
    fi

    archive="$DEST/$name.zip"
    rm -f "$archive"
    # Pack the index-named directory last so it wins any duplicate entry.
    for dir in "${matches[@]}"; do
        [ "$dir" = "$name" ] && continue
        pack_dir "$dir" "$archive"
    done
    for dir in "${matches[@]}"; do
        [ "$dir" = "$name" ] || continue
        pack_dir "$dir" "$archive"
    done
    if [ ! -f "$archive" ]; then
        warn "index entry '$name' produced an empty archive; left out"
        missing=$((missing + 1))
        continue
    fi
    packed=$((packed + 1))
done < "$INDEX"

# Metadata lives next to the archives and is read by the client directly.
for meta in Index Index.dev; do
    [ -f "$SOURCE/$meta" ] && cp "$SOURCE/$meta" "$DEST/"
done
cp "$SOURCE"/*.rdch "$DEST/" 2>/dev/null || true

log "Packed $packed archives into $DEST (merged $merged case variants, $missing skipped)"
