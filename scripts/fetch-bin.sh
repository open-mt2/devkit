#!/usr/bin/env bash
# ======================================================
# OpenMT2 client - runtime asset fetcher
# ======================================================
#
# Fetches the original client `bin/` tree (config files, fonts, music, packs,
# DLLs, ...) into <root>/bin. These files are required to assemble `dist/` but
# are not needed to compile the C++ sources.
#
# Sources, tried in order:
#   1. An existing non-empty <root>/bin (nothing to do).
#   2. BIN_LOCAL_SOURCE=<directory> (host checkout / mounted volume).
#   3. BIN_ARCHIVE_URL=<tar.gz|tgz|zip URL> downloaded and extracted.
#   4. A sparse git clone of BIN_REPO_URL (default: git.old-metin2.com).
#
# The old-metin2 Gitea instance may require authentication. Provide
# BIN_GIT_USERNAME / BIN_GIT_TOKEN (or GITEA_USER / GITEA_TOKEN) when needed.
# Failures are non-fatal unless BIN_REQUIRED=1, because compiling the client
# does not depend on the asset tree.
#
# Environment:
#   BIN_REQUIRED       fail instead of warning when no source is available
#   BIN_REPO_URL       git repository (default: old-metin2 client repo)
#   BIN_REF            branch/tag to clone (default: master)
#   BIN_LOCAL_SOURCE   local directory containing bin/
#   BIN_ARCHIVE_URL    archive containing bin/ (or its contents)
#   BIN_GIT_USERNAME   optional HTTP username
#   BIN_GIT_TOKEN      optional HTTP token/password
#   GITEA_USER         fallback HTTP username
#   GITEA_TOKEN        fallback HTTP token/password

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(dirname "$SCRIPT_DIR")"

ROOT="${1:-${OPENMT2_ROOT:-$DEFAULT_ROOT}}"
BIN_DIR="$ROOT/bin"
BIN_REPO_URL="${BIN_REPO_URL:-https://git.old-metin2.com/metin2/client.git}"
BIN_REF="${BIN_REF:-master}"

log()  { printf '\033[1;34m[bin]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[bin]\033[0m %s\n' "$*" >&2; }

have_bin() {
    [ -d "$BIN_DIR" ] \
        && [ -n "$(find "$BIN_DIR" -mindepth 1 ! -name .gitignore -print -quit 2>/dev/null)" ]
}

copy_bin_from() {
    local source="$1"
    if [ -d "$source/bin" ]; then
        source="$source/bin"
    fi
    if [ ! -d "$source" ]; then
        return 1
    fi
    log "Copying assets from $source"
    mkdir -p "$BIN_DIR"
    cp -a "$source/." "$BIN_DIR/"
}

finish() {
    if have_bin; then
        log "Client assets ready in $BIN_DIR ($(du -sh "$BIN_DIR" 2>/dev/null | cut -f1))"
        exit 0
    fi
    if [ "${BIN_REQUIRED:-0}" = "1" ]; then
        warn "No client assets could be fetched and BIN_REQUIRED=1."
        exit 1
    fi
    warn "No client assets fetched. The image can still compile the client,"
    warn "but dist/ will be missing BGM/lib/mark/miles/pack/screenshot/upload."
    warn "Mount a bin/ directory at $BIN_DIR or set BIN_LOCAL_SOURCE / BIN_ARCHIVE_URL."
    exit 0
}

if have_bin; then
    log "Using existing assets in $BIN_DIR"
    exit 0
fi

if [ -n "${BIN_LOCAL_SOURCE:-}" ]; then
    if copy_bin_from "$BIN_LOCAL_SOURCE"; then
        finish
    fi
    warn "BIN_LOCAL_SOURCE does not contain a bin/ directory: $BIN_LOCAL_SOURCE"
fi

if [ -n "${BIN_ARCHIVE_URL:-}" ]; then
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    archive="$tmp/assets"
    log "Downloading $BIN_ARCHIVE_URL"
    if curl -fL --retry 3 --connect-timeout 20 -o "$archive" "$BIN_ARCHIVE_URL"; then
        mkdir -p "$tmp/extracted"
        case "$BIN_ARCHIVE_URL" in
            *.zip) unzip -q "$archive" -d "$tmp/extracted" ;;
            *)     tar -xf "$archive" -C "$tmp/extracted" ;;
        esac
        if copy_bin_from "$tmp/extracted"; then
            finish
        fi
        if [ -n "$(find "$tmp/extracted" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
            log "Copying extracted archive contents"
            mkdir -p "$BIN_DIR"
            cp -a "$tmp/extracted/." "$BIN_DIR/"
            finish
        fi
    else
        warn "Download failed: $BIN_ARCHIVE_URL"
    fi
    rm -rf "$tmp"
    trap - EXIT
fi

clone_url="$BIN_REPO_URL"
if [ -n "${BIN_GIT_TOKEN:-${GITEA_TOKEN:-}}" ] && [[ "$clone_url" == https://* ]]; then
    token="${BIN_GIT_TOKEN:-${GITEA_TOKEN:-}}"
    user="${BIN_GIT_USERNAME:-${GITEA_USER:-git}}"
    clone_url="https://${user}:${token}@${clone_url#https://}"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
log "Fetching assets from $BIN_REPO_URL ($BIN_REF)"
if GIT_TERMINAL_PROMPT=0 git clone --depth 1 --filter=blob:none --sparse \
        --branch "$BIN_REF" "$clone_url" "$tmp/client" >/dev/null 2>&1 \
   && git -C "$tmp/client" sparse-checkout set bin >/dev/null 2>&1 \
   && [ -d "$tmp/client/bin" ]; then
    mkdir -p "$BIN_DIR"
    cp -a "$tmp/client/bin/." "$BIN_DIR/"
    finish
fi

warn "Could not fetch $BIN_REPO_URL (the repository may require credentials)."
finish
