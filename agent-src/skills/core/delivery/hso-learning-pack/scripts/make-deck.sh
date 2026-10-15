#!/usr/bin/env bash
# Render a Marp markdown file to a HSO-themed PPTX.
#
# Usage:
#   ./make-deck.sh <input.md> [<output.pptx>]
#
# Examples:
#   ./make-deck.sh example-exec-deck.md
#   ./make-deck.sh my-deck.md ~/Desktop/my-deck.pptx
#
# Requires: Node (for npx), Edge or Chrome on the Windows side (for PPTX export
# via puppeteer). On WSL, defaults to Edge at the standard install path.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Theme lives in the skill's themes/ dir; override with HSO_THEME_CSS env var.
THEME="${HSO_THEME_CSS:-$SCRIPT_DIR/../themes/hso-theme.css}"
[[ -f "$THEME" ]] || THEME="$SCRIPT_DIR/hso-theme.css"  # fallback for legacy layout

INPUT="${1:-}"
if [[ -z "$INPUT" ]]; then
  echo "usage: $0 <input.md> [<output.pptx>]" >&2
  exit 1
fi

# default output: same name as input, .pptx extension, alongside the input
OUTPUT="${2:-${INPUT%.md}.pptx}"

# Browser path — Edge on Windows by default. Override with BROWSER_PATH env var.
DEFAULT_EDGE='/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'
BROWSER_PATH="${BROWSER_PATH:-$DEFAULT_EDGE}"

if [[ ! -x "$BROWSER_PATH" && ! -f "$BROWSER_PATH" ]]; then
  echo "browser not found at: $BROWSER_PATH" >&2
  echo "set BROWSER_PATH env var to point at chrome.exe / msedge.exe" >&2
  exit 1
fi

echo "rendering: $INPUT -> $OUTPUT"
npx --yes @marp-team/marp-cli@latest \
  --theme-set "$THEME" \
  --html \
  --allow-local-files \
  --browser edge \
  --browser-path "$BROWSER_PATH" \
  --pptx \
  -o "$OUTPUT" \
  "$INPUT"

echo "done."
