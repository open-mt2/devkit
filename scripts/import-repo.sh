#!/usr/bin/env bash
# ======================================================
# OpenMT2 - history-preserving repository import (TB.1/TB.2)
# ======================================================
#
# Merges the pkg_* repositories listed in a consolidated repository's
# layout.map into it, rewriting every old path under the new location. Pure
# moves: no file content is changed, every old commit is preserved (with a new
# hash, as filter-repo must rewrite the tree).
#
# Usage:
#   scripts/import-repo.sh --target ../neoeter [--map ../neoeter/layout.map]
#                          [--branch main] [--source <dir>] [--dry-run]
#                          [--tag-final]
#
# layout.map format:
#   <github-repository>=<old-source-directory>=<path/in/target>
#
# Requirements:
#   - git-filter-repo (apt install git-filter-repo, or pipx install git-filter-repo)
#   - network access to github.com (or --source pointing at full clones)
#
# The target must be a git repository with a clean worktree. The script does not
# push; review the result, run the build checks, then push.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

TARGET=""
MAP=""
BRANCH="main"
SOURCE="$ROOT/src"
DRY_RUN=0
TAG_FINAL=0

log()  { printf '\033[1;34m[import]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[import]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[import] error:\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' \
        "${BASH_SOURCE[0]}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --target)    TARGET="$2"; shift 2 ;;
        --map)       MAP="$2"; shift 2 ;;
        --branch)    BRANCH="$2"; shift 2 ;;
        --source)    SOURCE="$2"; shift 2 ;;
        --dry-run)   DRY_RUN=1; shift ;;
        --tag-final) TAG_FINAL=1; shift ;;
        -h|--help)   usage; exit 0 ;;
        *)           die "unknown argument: $1" ;;
    esac
done

[ -n "$TARGET" ] || die "--target is required"
TARGET="$(cd "$TARGET" && pwd)"
[ -d "$TARGET/.git" ] || die "$TARGET is not a git repository"
[ -z "$(git -C "$TARGET" status --porcelain)" ] || die "$TARGET has uncommitted changes"

MAP="${MAP:-$TARGET/layout.map}"
[ -f "$MAP" ] || die "layout map not found: $MAP"

command -v git >/dev/null 2>&1 || die "git not found"

if [ "$DRY_RUN" -eq 0 ]; then
    command -v git-filter-repo >/dev/null 2>&1 ||
        die "git-filter-repo not found (apt install git-filter-repo, or pipx install git-filter-repo)"
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/openmt2-import-XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

log "target: $TARGET"
log "map:    $MAP"
log "work:   $WORK"

count_entries=0
count_merged=0

while IFS= read -r line; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | tr -d '[:space:]')"
    [ -z "$line" ] && continue

    IFS='=' read -r repo srcdir dest <<< "$line"
    [ -n "$repo" ] && [ -n "$srcdir" ] && [ -n "$dest" ] ||
        die "malformed layout line: $line"
    count_entries=$((count_entries + 1))

    log "--- $repo ($srcdir) -> $dest"

    if [ "$DRY_RUN" -eq 1 ]; then
        printf '    clone %s, filter-repo --to-subdirectory-filter %s, merge %s/%s\n' \
            "$repo" "$dest" "$repo" "$BRANCH"
        continue
    fi

    if git -C "$TARGET" cat-file -e "HEAD:$dest" 2>/dev/null; then
        warn "$dest already exists in $TARGET; skipping $repo (move it out first to redo)"
        continue
    fi

    url="https://github.com/open-mt2/${repo}.git"
    if [ -d "$SOURCE/$srcdir/.git" ]; then
        origin="$(git -C "$SOURCE/$srcdir" remote get-url origin 2>/dev/null || true)"
        [ -n "$origin" ] && url="$origin"
    fi

    clone="$WORK/$repo"
    log "cloning $url"
    if ! git clone --quiet "$url" "$clone"; then
        die "could not clone $repo; check credentials or pass --source with full clones"
    fi

    if [ -f "$clone/.git/shallow" ]; then
        log "unshallowing $repo"
        git -C "$clone" fetch --quiet --unshallow --tags origin
    fi

    if [ "$TAG_FINAL" -eq 1 ]; then
        if [ -d "$SOURCE/$srcdir/.git" ]; then
            git -C "$SOURCE/$srcdir" tag -f final origin/main >/dev/null 2>&1 ||
                git -C "$SOURCE/$srcdir" tag -f final
            log "tagged $SOURCE/$srcdir as final (push it with: git push origin final)"
        fi
    fi
    log "rewriting paths"
    git -C "$clone" filter-repo --force --to-subdirectory-filter "$dest"

    branch="$BRANCH"
    if ! git -C "$clone" rev-parse --verify --quiet "refs/heads/$branch" >/dev/null; then
        branch="$(git -C "$clone" for-each-ref --format='%(refname:short)' refs/heads | head -n1)"
        [ -n "$branch" ] || die "$repo has no branch to merge"
        warn "$repo has no '$BRANCH'; using '$branch'"
    fi

    log "merging $repo/$branch"
    git -C "$TARGET" fetch --quiet "$clone" "refs/heads/$branch"
    git -C "$TARGET" merge --allow-unrelated-histories --no-edit FETCH_HEAD ||
        die "merge of $repo failed; resolve it in $TARGET and re-run"
    count_merged=$((count_merged + 1))

    if [ "$TAG_FINAL" -eq 1 ]; then
        if [ -d "$SOURCE/$srcdir/.git" ]; then
            git -C "$SOURCE/$srcdir" tag -f final >/dev/null
            log "tagged $SOURCE/$srcdir as final (push it with: git push origin final)"
        fi
    fi
done < "$MAP"

[ "$count_entries" -gt 0 ] || die "no entries in $MAP"

if [ "$DRY_RUN" -eq 1 ]; then
    log "dry run: $count_entries repositories would be imported"
    exit 0
fi

log "imported $count_merged/$count_entries repositories into $TARGET"
log "next:"
printf '    1. review:  git -C %s log --oneline --graph | head\n' "$TARGET"
printf '    2. sources: docker run ... openmt2/client --skip-pack\n'
printf '    3. update the devkit wiring (TB.3) before pushing\n'
