#!/bin/bash
# Prints the release notes for a version: its CHANGELOG.md section followed by
# install instructions. Used by .github/workflows/release.yml.
#
#   ./Scripts/release_notes.sh 1.2.3
#
# NOTARIZED=1 switches the install note to the notarized wording.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:?usage: release_notes.sh <version>}"
REPO_URL="https://github.com/${GITHUB_REPOSITORY:-thienduc12311/Great-display}"

# Everything between "## [VERSION]" and the next "## [" heading.
SECTION="$(awk -v v="${VERSION}" '
    /^## \[/ {
        if (found) exit
        if (index($0, "## [" v "]") == 1) { found = 1; next }
    }
    found { print }
' CHANGELOG.md | sed -e '/./,$!d')"

if [[ -z "${SECTION//[[:space:]]/}" ]]; then
    echo "warning: CHANGELOG.md has no section for ${VERSION}" >&2
    SECTION="See the full list of changes below."
fi

cat <<EOF
${SECTION}

## Install

1. Download **GreatDisplay-${VERSION}.dmg** below.
2. Open it and drag **GreatDisplay** into **Applications**.
3. Launch Great Display. It lives in the menu bar (no Dock icon).
EOF

if [[ "${NOTARIZED:-}" == "1" ]]; then
    cat <<'EOF'

This build is signed with a Developer ID and notarized by Apple.
EOF
else
    cat <<'EOF'

> **First launch:** this build is not notarized by Apple, so macOS blocks the
> first launch. Open **System Settings → Privacy & Security**, scroll down and
> click **Open Anyway** next to the Great Display message. Alternatively run:
>
> ```sh
> xattr -dr com.apple.quarantine /Applications/GreatDisplay.app
> ```
EOF
fi

cat <<EOF

Requires macOS 14 Sonoma or later. Universal binary (Apple Silicon and Intel).
Verify the download against \`SHA256SUMS.txt\`:

\`\`\`sh
shasum -a 256 -c SHA256SUMS.txt
\`\`\`

Full changelog: [CHANGELOG.md](${REPO_URL}/blob/main/CHANGELOG.md)
EOF
