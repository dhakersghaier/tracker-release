#!/usr/bin/env bash
# Install TimeTracker on macOS (unsigned build — strips Gatekeeper quarantine).
# Usage: curl -fsSL "https://raw.githubusercontent.com/dhakersghaier/tracker-release/main/install-macos.sh" | bash
set -euo pipefail

# Stable URL — always serves the latest public release (see dhakersghaier/tracker-release).
DMG_URL="${TT_DMG_URL:-https://github.com/dhakersghaier/tracker-release/releases/latest/download/timetracker-macos.dmg}"

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

echo ""
echo "Done. TimeTracker installed to $INSTALL_DIR/$APP_NAME.app"
echo ""
echo "Next steps:"
echo "  1. Open TimeTracker from Applications"
echo "  2. Grant Screen Recording and Accessibility in System Settings → Privacy & Security"
echo "  3. Enroll the device: timetracker enroll --code tt_enrl_..."
