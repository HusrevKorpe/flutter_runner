#!/bin/bash
# Installs the latest Flutter Runner into /Applications:
#   curl -fsSL https://raw.githubusercontent.com/HusrevKorpe/flutter_runner/main/scripts/install.sh | bash
set -euo pipefail

URL="https://github.com/HusrevKorpe/flutter_runner/releases/latest/download/FlutterRunner.zip"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Flutter Runner indiriliyor…"
curl -fsSL "$URL" -o "$TMP/FlutterRunner.zip"
ditto -x -k "$TMP/FlutterRunner.zip" "$TMP"

pkill -x FlutterRunner 2>/dev/null || true
rm -rf /Applications/FlutterRunner.app
ditto "$TMP/FlutterRunner.app" /Applications/FlutterRunner.app
xattr -dr com.apple.quarantine /Applications/FlutterRunner.app 2>/dev/null || true

open /Applications/FlutterRunner.app
echo "Kuruldu. Menü çubuğundaki ▶︎ ikonuna tıkla."
