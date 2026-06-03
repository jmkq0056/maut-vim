#!/usr/bin/env bash
#
# Assemble a self-contained MautVim.app.
#
# The bundle ships:
#   Contents/MacOS/MautVim           launcher (opens Terminal running our nvim)
#   Contents/Resources/bin/*         nvim, yazi, rg, fd, fzf, lazygit (relocated)
#   Contents/Resources/lib/*         their non-system dylibs (via dylibbundler)
#   Contents/Resources/share/nvim    the Neovim runtime files
#   Contents/Resources/config        the MautVim nvim config + maut-sessions plugin
#   Contents/Resources/lazydata      pre-installed lazy.nvim plugins (offline first run)
#   Contents/Resources/mautvim.icns  reaper icon
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/MautVim.app"
VERSION="${1:-0.1.0}"
BUNDLE_ID="ai.maut.vim"

BREW_PREFIX="$(brew --prefix)"
BINARIES=(nvim yazi rg fd fzf lazygit)

echo "==> Building MautVim.app v$VERSION"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources/bin"
mkdir -p "$APP/Contents/Resources/lib"

RES="$APP/Contents/Resources"

# 1. nvim config + bundled plugin
echo "==> Copying config"
cp -R "$ROOT/nvim-config" "$RES/config"
# drop any lazy-lock copied accidentally; lock travels with lazydata instead
rm -f "$RES/config/lazy-lock.json"

# 2. pre-installed lazy plugins (so first launch is offline & instant)
LAZY_SRC="$HOME/.local/share/mautvim"
if [ -d "$LAZY_SRC/lazy" ]; then
  echo "==> Bundling pre-installed plugins from $LAZY_SRC"
  mkdir -p "$RES/lazydata"
  cp -R "$LAZY_SRC/lazy" "$RES/lazydata/lazy"
  # carry the lock so versions are pinned
  [ -f "$HOME/.config/mautvim/lazy-lock.json" ] && cp "$HOME/.config/mautvim/lazy-lock.json" "$RES/config/lazy-lock.json" || true
else
  echo "!! WARNING: no pre-installed plugins found at $LAZY_SRC/lazy"
  echo "   Run the headless install first; the app will fall back to cloning on first run."
fi

# 3. binaries
echo "==> Copying binaries"
for b in "${BINARIES[@]}"; do
  src="$(command -v "$b" || true)"
  if [ -z "$src" ]; then
    echo "!! WARNING: $b not found on PATH, skipping"
    continue
  fi
  cp -L "$src" "$RES/bin/$b"
  chmod +w "$RES/bin/$b"
done

# 4. Neovim runtime
# Homebrew's share/nvim is a symlink into ../Cellar; copy the RESOLVED directory
# (cp -RL) so the runtime isn't a dangling symlink inside the bundle.
echo "==> Copying Neovim runtime"
NVIM_SHARE="$(python3 -c "import os,sys;print(os.path.realpath(sys.argv[1]))" "$BREW_PREFIX/share/nvim" 2>/dev/null || echo "$BREW_PREFIX/share/nvim")"
if [ -d "$NVIM_SHARE" ]; then
  mkdir -p "$RES/share"
  cp -RL "$NVIM_SHARE" "$RES/share/nvim"
fi

# 5. relocate dylibs so the binaries are portable
echo "==> Relocating dylibs with dylibbundler"
for b in "${BINARIES[@]}"; do
  [ -f "$RES/bin/$b" ] || continue
  echo "    - $b"
  # </dev/null prevents an interactive prompt from hanging the build.
  dylibbundler -of -cd -b \
    -x "$RES/bin/$b" \
    -d "$RES/lib" \
    -p "@executable_path/../lib/" </dev/null || \
    echo "      (dylibbundler reported issues for $b; it may rely only on system libs)"
done

# 6. icon (MautVim's own icon — distinct from maut-code's reaper)
ICON_SRC="$ROOT/assets/mautvim.icns"
if [ -f "$ICON_SRC" ]; then
  cp "$ICON_SRC" "$RES/mautvim.icns"
else
  echo "!! icon not found at $ICON_SRC; app will use the default icon"
fi

# 6b. bundle the kitty terminal (self-contained .app) + config + Nerd Font.
# MautVim runs inside kitty so images, all key combos, and truecolor work —
# the system Terminal.app supports none of those well.
KITTY_APP="/Applications/kitty.app"
if [ -d "$KITTY_APP" ]; then
  echo "==> Merging kitty into MautVim.app (so it runs AS MautVim, one Dock icon)"
  # Put kitty's binaries alongside our launcher, and its frameworks/resources
  # under MautVim.app — kitty resolves resources relative to its executable, so
  # this makes MautVim.app the enclosing bundle (MautVim icon + identity).
  cp -R "$KITTY_APP/Contents/MacOS/." "$APP/Contents/MacOS/"
  if [ -d "$KITTY_APP/Contents/Frameworks" ]; then
    mkdir -p "$APP/Contents/Frameworks"
    cp -R "$KITTY_APP/Contents/Frameworks/." "$APP/Contents/Frameworks/"
  fi
  cp -R "$KITTY_APP/Contents/Resources/." "$RES/"
  cp "$ROOT/app/kitty.conf" "$RES/kitty.conf"
else
  echo "!! kitty.app not found at $KITTY_APP — install with 'brew install --cask kitty'"
  echo "   The launcher will fall back to Terminal.app."
fi

echo "==> Bundling Nerd Font"
mkdir -p "$RES/fonts"
for variant in Regular Bold Italic BoldItalic; do
  src="$HOME/Library/Fonts/JetBrainsMonoNerdFont-$variant.ttf"
  [ -f "$src" ] && cp "$src" "$RES/fonts/"
done

# 6c. ImageMagick policy so inline PDF/image preview (snacks.image) works.
echo "==> Bundling ImageMagick policy"
mkdir -p "$RES/imagemagick"
cp "$ROOT/app/imagemagick-policy.xml" "$RES/imagemagick/policy.xml"

# 7. internal launch script
cat > "$RES/bin/mautvim" <<'LAUNCH'
#!/bin/bash
# Internal launcher: seed config/plugins into an isolated NVIM_APPNAME, then run nvim.
set -e
RES="$(cd "$(dirname "$0")/.." && pwd)"        # .../Contents/Resources
# Bundled bins first, then the user's local bin (claude CLI lives there) and
# Homebrew dirs so the `claude` command and preview tools (magick, gs, pdftoppm)
# are found. LaunchServices gives a minimal PATH, so we add these explicitly.
export PATH="$RES/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
export NVIM_APPNAME="mautvim"
export VIMRUNTIME="$RES/share/nvim/runtime"
# Use MautVim's permissive ImageMagick policy (system policy untouched).
export MAGICK_CONFIGURE_PATH="$RES/imagemagick"

CONFIG_DIR="$HOME/.config/mautvim"
DATA_DIR="$HOME/.local/share/mautvim"

# Always refresh the config (cheap, keeps the app's config authoritative)…
mkdir -p "$CONFIG_DIR"
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete --exclude 'lazy-lock.json' "$RES/config/" "$CONFIG_DIR/"
else
  cp -R "$RES/config/." "$CONFIG_DIR/"
fi
[ -f "$RES/config/lazy-lock.json" ] && cp "$RES/config/lazy-lock.json" "$CONFIG_DIR/lazy-lock.json" || true

# …but only seed plugins if the user doesn't already have them (don't clobber updates).
if [ ! -d "$DATA_DIR/lazy" ] && [ -d "$RES/lazydata/lazy" ]; then
  mkdir -p "$DATA_DIR"
  cp -R "$RES/lazydata/lazy" "$DATA_DIR/lazy"
fi

if [ ! -x "$RES/bin/nvim" ]; then
  echo "MautVim: bundled nvim missing; falling back to PATH nvim"
  exec nvim "$@"
fi
exec "$RES/bin/nvim" "$@"
LAUNCH
chmod +x "$RES/bin/mautvim"

# 8. app launcher (the bundle's main executable):
#    install bundled font -> ask for a folder -> launch nvim inside bundled kitty.
cat > "$APP/Contents/MacOS/MautVim" <<'MAIN'
#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
RES="$(cd "$HERE/../Resources" && pwd)"
KITTY="$HERE/kitty"   # kitty merged into MautVim.app/Contents/MacOS — runs AS MautVim
LAUNCH="$RES/bin/mautvim"

# Install the bundled Nerd Font on first run so icons render everywhere.
if [ -d "$RES/fonts" ]; then
  mkdir -p "$HOME/Library/Fonts"
  for f in "$RES/fonts/"*.ttf; do
    [ -e "$f" ] || continue
    dest="$HOME/Library/Fonts/$(basename "$f")"
    [ -f "$dest" ] || cp "$f" "$dest"
  done
fi

# No forced folder dialog — MautVim opens to a welcome screen that lists recent
# projects (press a number) with an "Open Folder…" action when you want to browse.
if [ -x "$KITTY" ]; then
  exec "$KITTY" --start-as fullscreen --directory "$HOME" --config "$RES/kitty.conf" --title "MautVim" "$LAUNCH"
else
  # Fallback if kitty wasn't bundled: system Terminal.
  /usr/bin/osascript <<OSA
tell application "Terminal"
  activate
  do script "clear; exec '$LAUNCH'"
end tell
OSA
fi
MAIN
chmod +x "$APP/Contents/MacOS/MautVim"

# 9. Info.plist
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>MautVim</string>
  <key>CFBundleDisplayName</key><string>MautVim</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleExecutable</key><string>MautVim</string>
  <key>CFBundleIconFile</key><string>mautvim</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "==> Done: $APP"
du -sh "$APP" 2>/dev/null || true
