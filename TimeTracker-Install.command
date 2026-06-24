#!/bin/bash
# TimeTracker macOS installer — double-click in Finder to run in Terminal.
set -euo pipefail

curl -fsSL "https://raw.githubusercontent.com/dhakersghaier/tracker-release/main/install-macos.sh" | bash

echo ""
read -r -p "Press Enter to close…"
