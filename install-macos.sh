#!/usr/bin/env bash
# Install TimeTracker on macOS. The DMG is already rpath-fixed and ad-hoc signed
# at build time (build-macos.sh) — install just copies it and clears quarantine.
# Usage: curl -fsSL "https://raw.githubusercontent.com/dhakersghaier/tracker-release/main/install-macos.sh" | bash
set -euo pipefail

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
rm -rf "$INSTALL_DIR/$APP_NAME.app"
if ! ditto "$VOLUME/$APP_NAME.app" "$INSTALL_DIR/$APP_NAME.app"; then
  echo ""
  echo "error: could not copy to $INSTALL_DIR (permission denied?)"
  echo "Drag $APP_NAME.app to Applications manually, then run: xattr -cr $INSTALL_DIR/$APP_NAME.app"
  exit 1
fi

# Strip Gatekeeper quarantine so the unsigned app opens without a prompt.
xattr -cr "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true

echo ""
echo "Done. TimeTracker installed to $INSTALL_DIR/$APP_NAME.app"
echo ""
echo "Next steps:"
echo "  1. Open TimeTracker from Applications"
echo "  2. Grant Screen Recording and Accessibility in System Settings → Privacy & Security"
echo "  3. Enroll the device: timetracker enroll --code tt_enrl_..."
