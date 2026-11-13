#!/bin/bash
# Publishes a new version to GitHub Releases; installed apps pick it up.
#   scripts/release.sh 0.2.0 "Ne değişti (opsiyonel)"
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?Kullanım: scripts/release.sh <sürüm> [notlar]}"
NOTES="${2:-}"
REPO="HusrevKorpe/flutter_runner"
PLIST="Resources/Info.plist"
ZIP="build/FlutterRunner.zip"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Sürüm X.Y.Z biçiminde olmalı"; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "Commit edilmemiş değişiklik var"; exit 1; }
git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null && { echo "v$VERSION zaten var"; exit 1; }

TOKEN=$(printf "protocol=https\nhost=github.com\n\n" | git credential-osxkeychain get | sed -n 's/^password=//p')
LOGIN=$(curl -fsS -H "Authorization: Bearer $TOKEN" https://api.github.com/user | python3 -c "import sys,json; print(json.load(sys.stdin)['login'])")
[[ "$LOGIN" == "HusrevKorpe" ]] || { echo "Anahtar zincirindeki GitHub hesabı HusrevKorpe değil: $LOGIN"; exit 1; }

BUILD=$(( $(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PLIST") + 1 ))
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $VERSION" -c "Set CFBundleVersion $BUILD" "$PLIST"

./scripts/build_app.sh
rm -f "$ZIP"
ditto -c -k --keepParent build/FlutterRunner.app "$ZIP"

git commit -qam "chore: release v$VERSION"
git tag "v$VERSION"
git push -q origin HEAD:main "v$VERSION"

RELEASE_ID=$(VERSION="$VERSION" NOTES="$NOTES" python3 -c '
import json, os
print(json.dumps({"tag_name": "v" + os.environ["VERSION"], "name": "v" + os.environ["VERSION"], "body": os.environ["NOTES"]}))' |
  curl -fsS -X POST -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO/releases" -d @- |
  python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

curl -fsS -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/zip" \
  --data-binary @"$ZIP" \
  "https://uploads.github.com/repos/$REPO/releases/$RELEASE_ID/assets?name=FlutterRunner.zip" >/dev/null

echo "Yayınlandı: https://github.com/$REPO/releases/tag/v$VERSION"
