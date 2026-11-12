#!/bin/bash
# CI helper: switch to the newest Xcode installed on the runner.
# Set XCODE_PATH to pin a specific one.
set -euo pipefail

XCODE="${XCODE_PATH:-$(ls -d /Applications/Xcode_*.app 2>/dev/null | sort -V | tail -1)}"
if [[ -z "${XCODE}" ]]; then
    XCODE=/Applications/Xcode.app
fi
echo "Using ${XCODE}"
sudo xcode-select -s "${XCODE}/Contents/Developer"
echo "DEVELOPER_DIR=${XCODE}/Contents/Developer" >> "${GITHUB_ENV:-/dev/null}"
xcodebuild -version
swift --version
