#!/usr/bin/env bash
# Assembles the website into a folder ready for GitHub Pages.
#
#   ./Scripts/build_site.sh            # → dist/site
#   ./Scripts/build_site.sh _site      # → _site (used by .github/workflows/pages.yml)
#
# The pages live in website/. The app icon and CHANGELOG.md are copied in so the
# release notes page always shows the same notes as the GitHub releases.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/dist/site}"

rm -rf "$OUT"
mkdir -p "$OUT"
cp -R "$ROOT/website/." "$OUT/"
cp "$ROOT/docs/images/icon.png" "$OUT/assets/icon.png"
cp "$ROOT/CHANGELOG.md" "$OUT/CHANGELOG.md"
touch "$OUT/.nojekyll"

echo "Website assembled in $OUT"
