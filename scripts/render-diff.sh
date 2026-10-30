#!/usr/bin/env bash
# ======================================================
# Perceptual PNG diff for render goldens (TA.4)
# ======================================================
# Compare two PNGs, or two directories of PNGs, and report per-scene
# similarity. Reused later by T3.2 (black-screen detection) and T5.4
# (backend comparison).
#
# Usage:
#   scripts/render-diff.sh [--threshold PCT] [--max-delta N] [--json] <a> <b>
#
# <a> is the reference (golden) side, <b> the freshly rendered side. Either
# both are PNG files or both are directories containing same-named PNGs.
#
# Examples:
#   scripts/render-diff.sh build/src/EterLib/tests/render-output \
#       src/EterLib/tests/golden/render
#   scripts/render-diff.sh --max-delta 0 a.png b.png

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "${SCRIPT_DIR}/render-diff.py" "$@"
