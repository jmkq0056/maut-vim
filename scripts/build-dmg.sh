#!/usr/bin/env bash
#
# Package the (already-built, already-signed) MautVim.app into a distributable DMG.
#
# Usage: ./scripts/build-dmg.sh [version]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/MautVim.app"
VERSION="${1:-0.1.0}"
DMG="$DIST/MautVim-$VERSION.dmg"

[ -d "$APP" ] || { echo "No app at $APP — run build-app.sh first."; exit 1; }
rm -f "$DMG"

STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/MautVim.app"

echo "==> Creating $DMG"
ICON_ARGS=()
if create-dmg --help >/dev/null 2>&1; then
  set +e
  create-dmg \
    --volname "MautVim $VERSION" \
    --window-pos 200 120 \
    --window-size 540 360 \
    --icon-size 100 \
    --icon "MautVim.app" 140 180 \
    --app-drop-link 400 180 \
    --no-internet-enable \
    "$DMG" "$STAGE"
  rc=$?
  set -e
  # create-dmg can exit non-zero from cosmetic AppleScript steps yet still
  # produce a valid DMG — fall back to a plain image if it didn't.
  if [ ! -f "$DMG" ]; then
    echo "==> create-dmg failed (rc=$rc); falling back to hdiutil"
    hdiutil create -volname "MautVim $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
  fi
else
  hdiutil create -volname "MautVim $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
fi

rm -rf "$STAGE"

# Sign the DMG itself (matches the app's identity; ad-hoc if none).
IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
  | grep 'Developer ID Application' | head -1 | sed -E 's/.*"(.*)".*/\1/' || true)"
[ -z "$IDENTITY" ] && IDENTITY="-"
echo "==> Signing DMG with: $IDENTITY"
codesign --force --sign "$IDENTITY" "$DMG" || true

echo "==> Done: $DMG"
shasum -a 256 "$DMG" | tee "$DMG.sha256"
du -sh "$DMG"
