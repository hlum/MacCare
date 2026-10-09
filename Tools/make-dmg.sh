#!/usr/bin/env bash
# Builds MacCare-<version>.dmg from the Release app: the app plus an Applications shortcut.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=${1:-$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" build/Build/Products/Release/MacCare.app/Contents/Info.plist)}
APP=build/Build/Products/Release/MacCare.app
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/MacCare.app"
ln -s /Applications "$STAGE/Applications"
rm -f "build/MacCare-$VERSION.dmg"
hdiutil create -volname "MacCare" -srcfolder "$STAGE" -ov -format UDZO "build/MacCare-$VERSION.dmg" >/dev/null
rm -rf "$STAGE"
echo "build/MacCare-$VERSION.dmg"
