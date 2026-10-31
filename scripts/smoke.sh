#!/usr/bin/env bash
# ======================================================
# OpenMT2 client - boot smoke test (T3.2)
# ======================================================
#
# Boots the packaged client headlessly (Xvfb), waits for the login screen,
# captures a screenshot and fails on:
#   * a crash / early exit (non-zero status or dead process)
#   * a fatal boot error in syserr.txt (RunMain / Python launcher failures)
#   * a black screen (fewer than --min-colors distinct colours)
#
# Usage:
#   smoke.sh <linux|windows> [--dist DIR] [--settle SECONDS]
#            [--artifact DIR] [--home DIR] [--reference PNG] [--keep]
#
# Artifacts (screenshot + client log) land in smoke-artifacts/ (or --artifact).
# --home moves the Wine prefix/home directory (point it at a tmpfs when disk
# is tight); --reference compares the screenshot via render-diff.py.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$(basename "$SCRIPT_DIR")" = scripts ]; then
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
else
    PROJECT_ROOT="$SCRIPT_DIR"
fi
cd "$PROJECT_ROOT"

TARGET="${1:-}"
if [ "$TARGET" = "-h" ] || [ "$TARGET" = "--help" ]; then
    echo "usage: smoke.sh <linux|windows> [--dist DIR] [--settle SECONDS]"
    echo "                [--artifact DIR] [--home DIR] [--reference PNG] [--keep]"
    exit 0
fi
[ -n "$TARGET" ] && shift || true

DIST_DIR="${OPENMT2_DIST_DIR:-$PROJECT_ROOT/dist}"
ARTIFACT_DIR="${OPENMT2_SMOKE_ARTIFACT:-$PROJECT_ROOT/smoke-artifacts}"
HOME_DIR="${OPENMT2_SMOKE_HOME:-}"
SETTLE=""
MIN_COLORS=8
REFERENCE=""
KEEP=false
DISPLAY_NUM="${OPENMT2_SMOKE_DISPLAY:-:99}"

while (($#)); do
    case "$1" in
        --dist) DIST_DIR="$2"; shift 2 ;;
        --artifact) ARTIFACT_DIR="$2"; shift 2 ;;
        --home) HOME_DIR="$2"; shift 2 ;;
        --settle) SETTLE="$2"; shift 2 ;;
        --reference) REFERENCE="$2"; shift 2 ;;
        --min-colors) MIN_COLORS="$2"; shift 2 ;;
        --keep) KEEP=true; shift ;;
        -h|--help)
            sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "smoke: unknown option: $1" >&2; exit 2 ;;
    esac
done

case "$TARGET" in
    linux)
        BIN="metin2client"
        RUNNER=()
        SETTLE="${SETTLE:-25}"
        ;;
    windows)
        BIN="metin2client.exe"
        command -v wine >/dev/null 2>&1 || { echo "smoke: wine not found" >&2; exit 2; }
        RUNNER=(wine)
        SETTLE="${SETTLE:-35}"
        ;;    *)
        echo "usage: smoke.sh <linux|windows> [options]" >&2
        exit 2
        ;;
esac

[ -d "$DIST_DIR" ] || { echo "smoke: dist directory not found: $DIST_DIR" >&2; exit 2; }
[ -x "$DIST_DIR/$BIN" ] || { echo "smoke: $DIST_DIR/$BIN not found" >&2; exit 2; }

mkdir -p "$ARTIFACT_DIR"
ARTIFACT_DIR="$(cd "$ARTIFACT_DIR" && pwd)"
[ -n "$HOME_DIR" ] || HOME_DIR="$ARTIFACT_DIR/home"
mkdir -p "$HOME_DIR"
if [ "$TARGET" = windows ]; then
    export WINEPREFIX="$HOME_DIR/wineprefix"
fi
export HOME="$HOME_DIR"
export WINEDEBUG="${WINEDEBUG:--all}"

LOG="$ARTIFACT_DIR/client-$TARGET.log"
SHOT="$ARTIFACT_DIR/smoke-$TARGET.png"
SYSERR="$DIST_DIR/syserr.txt"
rm -f "$SYSERR" "$LOG" "$SHOT"

cleanup() {
    [ -n "${CLIENT_PID:-}" ] && kill "$CLIENT_PID" 2>/dev/null || true
    [ -n "${XVFB_PID:-}" ] && kill "$XVFB_PID" 2>/dev/null || true
    wait 2>/dev/null || true
    # The Wine prefix is ~1 GB; keep only the screenshot and the log.
    if [ "$KEEP" = false ] && [ -n "${HOME_DIR:-}" ]; then
        case "$HOME_DIR" in
            "$ARTIFACT_DIR"/*|/tmp/*) rm -rf "$HOME_DIR" 2>/dev/null || true ;;
        esac
    fi
}
trap cleanup EXIT

if ! command -v Xvfb >/dev/null 2>&1; then
    echo "smoke: Xvfb not found" >&2
    exit 2
fi
Xvfb "$DISPLAY_NUM" -screen 0 1280x1024x24 >/dev/null 2>&1 &
XVFB_PID=$!
export DISPLAY="$DISPLAY_NUM"
sleep 2
if ! kill -0 "$XVFB_PID" 2>/dev/null; then
    echo "smoke: Xvfb failed to start on $DISPLAY_NUM" >&2
    exit 1
fi

if [ "$TARGET" = windows ] && [ ! -f "$WINEPREFIX/system.reg" ]; then
    # First run: let Wine finish creating/updating the prefix before the
    # client starts, otherwise the loader races the prefix update.
    wineboot -u >>"$LOG" 2>&1 || true
    wineserver -w 2>/dev/null || true
fi

echo "smoke: launching $DIST_DIR/$BIN (target=$TARGET, settle=${SETTLE}s)"
(
    cd "$DIST_DIR"
    exec "${RUNNER[@]}" "./$BIN"
) >>"$LOG" 2>&1 &
CLIENT_PID=$!

sleep 2
if ! kill -0 "$CLIENT_PID" 2>/dev/null; then
    wait "$CLIENT_PID" || STATUS=$?
    echo "smoke: FAIL — client exited immediately (status ${STATUS:-?})" >&2
    tail -20 "$LOG" >&2 || true
    exit 1
fi

sleep "$SETTLE"

if ! kill -0 "$CLIENT_PID" 2>/dev/null; then
    wait "$CLIENT_PID" || STATUS=$?
    echo "smoke: FAIL — client died within ${SETTLE}s (status ${STATUS:-?})" >&2
    [ -f "$SYSERR" ] && tail -20 "$SYSERR" >&2
    exit 1
fi

echo "smoke: client alive after ${SETTLE}s"

if [ -f "$SYSERR" ] && grep -Eq "RunMain Error|Failed to initialize Python|FATAL ERROR" "$SYSERR"; then
    echo "smoke: FAIL — fatal boot error in syserr.txt" >&2
    grep -E "RunMain Error|Failed to initialize Python|FATAL ERROR" "$SYSERR" >&2
    exit 1
fi

if command -v import >/dev/null 2>&1; then
    import -display "$DISPLAY" -window root "$SHOT" 2>/dev/null || true
fi
if [ -f "$SHOT" ]; then
    COLORS="$(convert "$SHOT" -format '%k' info: 2>/dev/null || echo 0)"
    echo "smoke: screenshot $SHOT (${COLORS} colours)"
    if [ "${COLORS:-0}" -lt "$MIN_COLORS" ]; then
        echo "smoke: FAIL — black/blank screen (${COLORS} colours < ${MIN_COLORS})" >&2
        exit 1
    fi
else
    echo "smoke: WARNING — no screenshot tool (ImageMagick 'import' missing); black-screen check skipped" >&2
fi

if [ -n "$REFERENCE" ]; then
    if [ ! -f "$REFERENCE" ]; then
        echo "smoke: reference not found: $REFERENCE" >&2
        exit 2
    fi
    if [ -f "$SHOT" ]; then
        echo "smoke: comparing with $REFERENCE"
        python3 "$SCRIPT_DIR/render-diff.py" --threshold 80 --max-delta 12 "$REFERENCE" "$SHOT" \
            || { echo "smoke: FAIL — screenshot differs from reference" >&2; exit 1; }
    fi
fi

kill "$CLIENT_PID" 2>/dev/null || true
echo "smoke: PASS ($TARGET)"
