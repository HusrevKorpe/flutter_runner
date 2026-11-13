#!/bin/bash
# Builds build/FlutterRunner.app. Pass --install to copy it into /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN_DIR=$(swift build -c release --show-bin-path)
APP=build/FlutterRunner.app

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/FlutterRunner" "$APP/Contents/MacOS/FlutterRunner"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null

if [[ "${1:-}" == "--install" ]]; then
  rm -rf /Applications/FlutterRunner.app
  cp -R "$APP" /Applications/
  echo "Installed: /Applications/FlutterRunner.app"
else
  echo "Built: $APP"
fi
