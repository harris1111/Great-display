#!/bin/bash
# Packages dist/GreatDisplay.app into a drag-to-install DMG and a ZIP, and
# writes SHA-256 checksums. Run Scripts/build_app.sh first.
#
#   VERSION=1.2.3 ./Scripts/package_release.sh
#
# Output (in dist/):
#   GreatDisplay-<version>.dmg
#   GreatDisplay-<version>.zip
#   SHA256SUMS.txt
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="GreatDisplay"
APP="dist/${APP_NAME}.app"

if [[ ! -d "${APP}" ]]; then
    echo "error: ${APP} not found; run Scripts/build_app.sh first" >&2
    exit 1
fi

VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP}/Contents/Info.plist")}"
DMG="dist/${APP_NAME}-${VERSION}.dmg"
ZIP="dist/${APP_NAME}-${VERSION}.zip"

echo "==> Packaging ${APP_NAME} ${VERSION}"

echo "    zip: ${ZIP}"
rm -f "${ZIP}"
# ditto keeps extended attributes, symlinks and the code signature intact.
ditto -c -k --sequesterRsrc --keepParent "${APP}" "${ZIP}"

echo "    dmg: ${DMG}"
STAGING="$(mktemp -d)"
trap 'rm -rf "${STAGING}"' EXIT
ditto "${APP}" "${STAGING}/${APP_NAME}.app"
ln -s /Applications "${STAGING}/Applications"
rm -f "${DMG}"
hdiutil create \
    -volname "Great Display ${VERSION}" \
    -srcfolder "${STAGING}" \
    -fs HFS+ \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov "${DMG}" >/dev/null

if [[ -n "${SIGN_IDENTITY:-}" && "${SIGN_IDENTITY}" != "-" ]]; then
    echo "    signing dmg with ${SIGN_IDENTITY}"
    codesign --force --timestamp --sign "${SIGN_IDENTITY}" "${DMG}"
fi

(cd dist && shasum -a 256 "$(basename "${DMG}")" "$(basename "${ZIP}")" > SHA256SUMS.txt)

echo "==> Packaged"
cat dist/SHA256SUMS.txt
