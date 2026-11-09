#!/usr/bin/env bash
# ======================================================
# OpenMT2 client - consolidated source fetcher (TB.3)
# ======================================================
#
# Clones or updates the three consolidated repositories (neoeter,
# neoeter-python, client) into <root>/src/<name>. Each repository can be pinned
# to its own branch, tag or full commit hash.
#
# Usage:
#   scripts/fetch-sources.sh [OPTIONS] [ROOT]
#
# Options:
#   --ref REPO=REF       Pin one repository (repeatable). REPO is one of
#                        neoeter, neoeter-python, client. REF is a branch, tag
#                        or full 40-character commit hash.
#   --write-lock FILE    Write the resolved commit hashes to FILE. Relative
#                        paths are resolved against ROOT.
#   --depth N            Clone depth (default: 1; 0 = full history)
#   --org ORG            GitHub organization (default: open-mt2)
#   -h, --help           Show this help
#
# Environment:
#   SRC_REF          default ref for every repository (default: main)
#   SRC_REF_<NAME>   per-repository default, e.g. SRC_REF_CLIENT,
#                    SRC_REF_NEOETER_PYTHON
#   SRC_ORG          GitHub organization (default: open-mt2)
#   SRC_DEPTH        clone depth (default: 1; 0 = full history)
#   GITHUB_TOKEN     optional token, used for private clones
#
# Precedence: --ref > SRC_REF_<NAME> > SRC_REF.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(dirname "$SCRIPT_DIR")"

SOURCES=(
    neoeter=neoeter
    neoeter-python=neoeter-python
    client=client
)

ROOT="${OPENMT2_ROOT:-$DEFAULT_ROOT}"
SRC_REF="${SRC_REF:-main}"
SRC_ORG="${SRC_ORG:-open-mt2}"
SRC_DEPTH="${SRC_DEPTH:-1}"
WRITE_LOCK=""
POSITIONAL_ROOT=""
REF_OVERRIDES=()

declare -A REQUESTED=()
declare -A RESOLVED=()

log()  { printf '\033[1;34m[sources]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[sources]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[sources] error:\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' \
        "${BASH_SOURCE[0]}"
}

is_known_repo() {
    local candidate="$1" source
    for source in "${SOURCES[@]}"; do
        [ "${source%%=*}" = "$candidate" ] && return 0
    done
    return 1
}

ref_for_repo() {
    local repo="$1" entry ref="" suffix env_name env_ref

    if [ "${#REF_OVERRIDES[@]}" -gt 0 ]; then
        for entry in "${REF_OVERRIDES[@]}"; do
            if [ "${entry%%=*}" = "$repo" ]; then
                ref="${entry#*=}"
            fi
        done
    fi
    if [ -n "$ref" ]; then
        printf '%s' "$ref"
        return 0
    fi

    suffix="$(printf '%s' "$repo" | tr '[:lower:]-' '[:upper:]_')"
    env_name="SRC_REF_${suffix}"
    env_ref="${!env_name:-}"
    if [ -n "$env_ref" ]; then
        printf '%s' "$env_ref"
    else
        printf '%s' "$SRC_REF"
    fi
}

looks_like_short_sha() {
    [[ "$1" =~ ^[0-9a-fA-F]{7,39}$ ]]
}

fetch_failed() {
    local repo="$1" ref="$2"
    if looks_like_short_sha "$ref"; then
        die "$repo: '$ref' looks like a short commit hash; use the full 40-character hash"
    fi
    die "$repo: could not fetch '$ref'"
}

fetch_and_checkout() {
    local target="$1" ref="$2" repo="$3"

    if ! git -C "$target" fetch --quiet --tags "${depth_args[@]}" origin "$ref"; then
        warn "$repo: direct fetch of '$ref' failed; retrying with full history"
        if [ -f "$target/.git/shallow" ]; then
            git -C "$target" fetch --quiet --tags --unshallow origin \
                || fetch_failed "$repo" "$ref"
        fi
        git -C "$target" fetch --quiet --tags origin "$ref" \
            || fetch_failed "$repo" "$ref"
    fi
    git -C "$target" checkout --quiet --detach FETCH_HEAD
}

while [ $# -gt 0 ]; do
    case "$1" in
        --ref)
            [ $# -ge 2 ] || die "--ref requires REPO=REF"
            REF_OVERRIDES+=("$2")
            shift 2
            ;;
        --ref=*)
            REF_OVERRIDES+=("${1#*=}")
            shift
            ;;
        --write-lock)
            [ $# -ge 2 ] || die "--write-lock requires a file"
            WRITE_LOCK="$2"
            shift 2
            ;;
        --write-lock=*)
            WRITE_LOCK="${1#*=}"
            shift
            ;;
        --depth)
            [ $# -ge 2 ] || die "--depth requires a value"
            SRC_DEPTH="$2"
            shift 2
            ;;
        --depth=*)
            SRC_DEPTH="${1#*=}"
            shift
            ;;
        --org)
            [ $# -ge 2 ] || die "--org requires a value"
            SRC_ORG="$2"
            shift 2
            ;;
        --org=*)
            SRC_ORG="${1#*=}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            while [ $# -gt 0 ]; do
                [ -z "$POSITIONAL_ROOT" ] || die "unexpected argument: $1"
                POSITIONAL_ROOT="$1"
                shift
            done
            ;;
        -*)
            die "unknown option: $1"
            ;;
        *)
            [ -z "$POSITIONAL_ROOT" ] || die "unexpected argument: $1"
            POSITIONAL_ROOT="$1"
            shift
            ;;
    esac
done

[ -z "$POSITIONAL_ROOT" ] || ROOT="$POSITIONAL_ROOT"
[[ "$SRC_DEPTH" =~ ^[0-9]+$ ]] || die "invalid depth: $SRC_DEPTH"

if [ "${#REF_OVERRIDES[@]}" -gt 0 ]; then
    for entry in "${REF_OVERRIDES[@]}"; do
        case "$entry" in
            *=*) ;;
            *) die "--ref expects REPO=REF, got '$entry'" ;;
        esac
        repo="${entry%%=*}"
        ref="${entry#*=}"
        if [ -z "$repo" ] || [ -z "$ref" ] || ! is_known_repo "$repo"; then
            die "invalid --ref '$entry' (repositories: neoeter, neoeter-python, client)"
        fi
    done
fi

SRC_DIR="$ROOT/src"
mkdir -p "$SRC_DIR"

base_url="https://github.com/${SRC_ORG}"
if [ -n "${GITHUB_TOKEN:-}" ]; then
    base_url="https://x-access-token:${GITHUB_TOKEN}@github.com/${SRC_ORG}"
fi

depth_args=()
[ "$SRC_DEPTH" = "0" ] || depth_args=(--depth "$SRC_DEPTH")

for source in "${SOURCES[@]}"; do
    repo="${source%%=*}"
    dir="${source#*=}"

    target="$SRC_DIR/$dir"
    url="$base_url/$repo.git"
    ref="$(ref_for_repo "$repo")"
    REQUESTED["$repo"]="$ref"

    if [ -e "$target" ] && [ ! -d "$target/.git" ]; then
        die "$target exists but is not a git repository"
    fi

    if [ -d "$target/.git" ]; then
        log "updating $repo -> $ref"
        fetch_and_checkout "$target" "$ref" "$repo"
    elif [[ "$ref" =~ ^[0-9a-fA-F]{40}$ ]]; then
        log "fetching commit $repo@$ref"
        mkdir -p "$target"
        git -C "$target" init --quiet
        git -C "$target" remote add origin "$url"
        git -C "$target" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
        fetch_and_checkout "$target" "$ref" "$repo"
    else
        log "cloning $repo -> $ref"
        if ! git clone --quiet "${depth_args[@]}" --branch "$ref" "$url" "$target"; then
            rm -rf "$target"
            fetch_failed "$repo" "$ref"
        fi
    fi

    resolved="$(git -C "$target" rev-parse HEAD)"
    RESOLVED["$repo"]="$resolved"
    log "$repo at $resolved ($ref)"
done

if [ -n "$WRITE_LOCK" ]; then
    case "$WRITE_LOCK" in
        /*) lock_file="$WRITE_LOCK" ;;
        *)  lock_file="$ROOT/$WRITE_LOCK" ;;
    esac
    mkdir -p "$(dirname "$lock_file")"
    tmp_lock="$(mktemp "${lock_file}.XXXXXX")"
    {
        printf '# openmt2 sources lock\n'
        for source in "${SOURCES[@]}"; do
            repo="${source%%=*}"
            printf '# %s requested %s\n' "$repo" "${REQUESTED[$repo]:-}"
            printf '%s=%s\n' "$repo" "${RESOLVED[$repo]}"
        done
    } > "$tmp_lock"
    mv -f "$tmp_lock" "$lock_file"
    log "wrote source lock: $lock_file"
fi

log "sources ready under $SRC_DIR"
