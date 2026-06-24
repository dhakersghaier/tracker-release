#!/usr/bin/env bash
# Install TimeTracker on macOS (unsigned build — strips Gatekeeper quarantine).
# Usage: curl -fsSL "https://raw.githubusercontent.com/dhakersghaier/tracker-release/main/install-macos.sh" | bash
set -euo pipefail

# Stable URL — file on main branch (see dhakersghaier/tracker-release).
DMG_URL="${TT_DMG_URL:-https://raw.githubusercontent.com/dhakersghaier/tracker-release/main/macos/timetracker-macos.dmg}"

APP_NAME="TimeTracker"
INSTALL_DIR="/Applications"
MIN_DMG_BYTES=1000000

TMP=$(mktemp -d)
trap 'hdiutil detach "/Volumes/$APP_NAME" -quiet 2>/dev/null || true; rm -rf "$TMP"' EXIT

echo "Downloading TimeTracker..."
curl -fsSL --progress-bar -L -o "$TMP/timetracker.dmg" "$DMG_URL"

DMG="$TMP/timetracker.dmg"
if [[ ! -s "$DMG" ]] || [[ "$(wc -c < "$DMG" | tr -d ' ')" -lt "$MIN_DMG_BYTES" ]]; then
  echo "error: download failed or returned an HTML page instead of a DMG"
  echo "Check DMG_URL in install-macos.sh and try again."
  exit 1
fi

if ! hdiutil attach "$DMG" -nobrowse -quiet; then
  echo "error: could not mount DMG — file may be corrupt"
  exit 1
fi

VOLUME="/Volumes/$APP_NAME"
if [[ ! -d "$VOLUME/$APP_NAME.app" ]]; then
  echo "error: could not find $APP_NAME.app on mounted volume at $VOLUME"
  exit 1
fi

echo "Installing to $INSTALL_DIR..."
if ! ditto "$VOLUME/$APP_NAME.app" "$INSTALL_DIR/$APP_NAME.app"; then
  echo ""
  echo "error: could not copy to $INSTALL_DIR (permission denied?)"
  echo "Re-run with admin rights, or after the DMG mounts drag TimeTracker.app to Applications manually,"
  echo "then run: xattr -cr /Applications/TimeTracker.app"
  exit 1
fi

xattr -cr "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true

QT_CORE_BIN="$INSTALL_DIR/$APP_NAME.app/Contents/Frameworks/PyQt6/Qt6/lib/QtCore.framework/Versions/A/QtCore"
if [[ ! -f "$QT_CORE_BIN" ]]; then
  echo ""
  echo "error: this DMG has broken Qt libraries (QtCore.framework is empty)."
  echo "Rebuild with the latest build-macos.sh and publish a new DMG, then install again."
  exit 1
fi

# PyQt6 needs LC_RPATH to find Qt frameworks when launched from Finder (DYLD_* is stripped).
fix_qt_rpaths() {
  local app="$1"
  local exe="$app/Contents/MacOS/timetracker"
  local pyqt="$app/Contents/Frameworks/PyQt6"

  add_rpath_if_missing() {
    local bin="$1" rpath="$2"
    [[ -f "$bin" ]] || return 0
    if otool -l "$bin" 2>/dev/null | grep -Fq "path $rpath"; then
      return 0
    fi
    codesign --remove-signature "$bin" 2>/dev/null || true
    install_name_tool -add_rpath "$rpath" "$bin"
  }

  add_rpath_if_missing "$exe" "@executable_path/../Frameworks/PyQt6/Qt6/lib"
  shopt -s nullglob
  for so in "$pyqt"/*.so "$pyqt"/*.abi3.so; do
    add_rpath_if_missing "$so" "@loader_path/Qt6/lib"
  done
  shopt -u nullglob
  if [[ -d "$pyqt/Qt6/plugins" ]]; then
    find "$pyqt/Qt6/plugins" -name '*.dylib' -print0 2>/dev/null | while IFS= read -r -d '' dylib; do
      add_rpath_if_missing "$dylib" "@loader_path/../../lib"
    done
  fi

  # @rpath/QtCore expects Qt6/lib/QtCore — symlinks + rewrite linked paths on sip modules.
  local qt_lib="$pyqt/Qt6/lib"
  if [[ -d "$qt_lib" ]]; then
    for fw_dir in "$qt_lib"/Qt*.framework; do
      [[ -d "$fw_dir" ]] || continue
      fw="$(basename "$fw_dir" .framework)"
      [[ -e "$qt_lib/$fw" ]] && continue
      [[ -f "$fw_dir/Versions/A/$fw" ]] || continue
      (cd "$qt_lib" && ln -sf "$fw.framework/Versions/A/$fw" "$fw")
    done
    shopt -s nullglob
    for so in "$pyqt"/*.so "$pyqt"/*.abi3.so; do
      [[ -f "$so" ]] || continue
      for fw_dir in "$qt_lib"/Qt*.framework; do
        fw="$(basename "$fw_dir" .framework)"
        old="@rpath/$fw"
        new="@loader_path/Qt6/lib/$fw.framework/Versions/A/$fw"
        if otool -L "$so" 2>/dev/null | grep -Fq "$old"; then
          codesign --remove-signature "$so" 2>/dev/null || true
          install_name_tool -change "$old" "$new" "$so" 2>/dev/null || true
        fi
      done
    done
    shopt -u nullglob
  fi
}
fix_qt_rpaths "$INSTALL_DIR/$APP_NAME.app"

# install_name_tool invalidates PyInstaller's signature — re-sign or launchd error 162.
resign_app() {
  local app="$1"
  local ent="$app/Contents/Resources/entitlements.plist"
  xattr -cr "$app" 2>/dev/null || true
  if [[ -f "$ent" ]]; then
    codesign --force --sign - --options runtime --entitlements "$ent" "$app/Contents/MacOS/timetracker" 2>/dev/null || true
  fi
  codesign --force --deep --sign - "$app"
}
resign_app "$INSTALL_DIR/$APP_NAME.app"

echo ""
echo "Done. TimeTracker installed to $INSTALL_DIR/$APP_NAME.app"
echo ""
echo "Next steps:"
echo "  1. Open TimeTracker from Applications"
echo "  2. Grant Screen Recording and Accessibility in System Settings → Privacy & Security"
echo "  3. Enroll the device: timetracker enroll --code tt_enrl_..."
