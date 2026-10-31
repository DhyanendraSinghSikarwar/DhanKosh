#!/usr/bin/env bash
# Renders the main screens (dark, dummy data) to PNGs: tools/screenshots.sh <out-dir> [name,name]
# Needs the Flutter SDK on PATH and Roboto/MaterialIcons under the SDK cache.
set -euo pipefail
out="${1:?usage: tools/screenshots.sh <out-dir> [only-names]}"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
cd "$(dirname "$0")/../app"
SHOTS_DIR="$out" SHOT_ONLY="${2:-}" flutter test test/screenshots
echo "Screens written to $out"
