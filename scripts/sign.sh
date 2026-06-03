#!/usr/bin/env bash
#
# Code-sign MautVim.app.
#
# Usage:
#   ./scripts/sign.sh                 # auto-detect a Developer ID, else ad-hoc (-)
#   ./scripts/sign.sh "Developer ID Application: Your Name (TEAMID)"
#
# Ad-hoc signing (-) lets the app run locally and be shared, but recipients will
# see a Gatekeeper prompt (right-click → Open, or strip the quarantine attr).
# A real Developer ID enables notarization for a clean first-launch experience.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/MautVim.app"
[ -d "$APP" ] || { echo "No app at $APP — run build-app.sh first."; exit 1; }

IDENTITY="${1:-}"
if [ -z "$IDENTITY" ]; then
  IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | grep 'Developer ID Application' | head -1 | sed -E 's/.*"(.*)".*/\1/' || true)"
fi
if [ -z "$IDENTITY" ]; then
  echo "==> No Developer ID found; using ad-hoc signing (-)."
  IDENTITY="-"
fi
echo "==> Signing identity: $IDENTITY"

EXTRA=()
if [ "$IDENTITY" != "-" ]; then
  EXTRA=(--options runtime --timestamp)
else
  EXTRA=(--timestamp=none)
fi

sign() { codesign --force "${EXTRA[@]}" --sign "$IDENTITY" "$1"; }

# Sign the most deeply-nested Mach-O first, then work outward to the bundle.
echo "==> Signing bundled dylibs"
if [ -d "$APP/Contents/Resources/lib" ]; then
  find "$APP/Contents/Resources/lib" -type f \( -name '*.dylib' -o -name '*.so' \) -print0 \
    | while IFS= read -r -d '' f; do sign "$f"; done
fi

echo "==> Signing bundled binaries"
for b in nvim yazi rg fd fzf lazygit; do
  bin="$APP/Contents/Resources/bin/$b"
  [ -f "$bin" ] && sign "$bin"
done

# kitty's binaries + frameworks are merged into MautVim.app. Deep-sign the whole
# bundle so kitty, kitten, the frameworks, and all helpers are covered.
echo "==> Deep-signing the app bundle (covers kitty + frameworks)"
codesign --force --deep "${EXTRA[@]}" --sign "$IDENTITY" "$APP"

echo "==> Verifying"
codesign --verify --deep --strict --verbose=2 "$APP" || echo "(verify reported warnings — expected for ad-hoc)"
echo "==> Done."
