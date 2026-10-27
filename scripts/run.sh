#!/usr/bin/env bash
# Builds BetterShot, replaces any running copy and launches it. It appears as an icon in the menu bar (no Dock icon).
# Usage: scripts/run.sh [debug|release]   (default: debug, which builds fastest)
#
# Optional, read by scripts/bundle.sh and baked into the app's Info.plist:
#   BETTERSHOT_GOOGLE_CLIENT_ID / BETTERSHOT_GOOGLE_CLIENT_SECRET / BETTERSHOT_ONEDRIVE_CLIENT_ID   cloud linking
#   BETTERSHOT_UPDATE_FEED_URL                                                                       Check for Updates
#   SIGN_IDENTITY   a stable signing certificate, so macOS keeps the Screen Recording permission across rebuilds
set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/BetterShot.app"

"$ROOT/scripts/bundle.sh" "$CONFIG"

# Only one copy can own the menu-bar icon and the global shortcuts, so stop the old one first.
if pgrep -x BetterShot >/dev/null; then
    pkill -x BetterShot
    for _ in $(seq 1 20); do
        pgrep -x BetterShot >/dev/null || break
        sleep 0.25
    done
fi

open "$APP"

cat <<'EOF'

BetterShot is running: look for its icon in the menu bar.
First capture: macOS asks for Screen Recording permission. Grant it in System Settings > Privacy & Security,
then quit BetterShot from its menu and run this script again. Rebuilding with the default ad-hoc signature can
make macOS ask again; set SIGN_IDENTITY to avoid that.
Scrolling Capture also needs the Accessibility permission.
Logs:  /usr/bin/log stream --predicate 'subsystem == "com.bettershot.app"'
Stop:  use Quit in the menu-bar menu, or run: pkill -x BetterShot
EOF
