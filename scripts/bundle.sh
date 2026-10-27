#!/usr/bin/env bash
# Builds BetterShot and wraps the executable in a menu-bar-agent .app bundle at build/BetterShot.app.
# Usage: scripts/bundle.sh [debug|release]   (default: release)
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/BetterShot.app"
BUNDLE_ID="com.bettershot.app"
# Set SIGN_IDENTITY to a stable dev certificate to keep Screen Recording permission across rebuilds.
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

cd "$ROOT"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/BetterShot"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/BetterShot"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>BetterShot</string>
    <key>CFBundleDisplayName</key><string>BetterShot</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>BetterShot</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>BetterShot needs screen recording access to capture screenshots and recordings.</string>
</dict>
</plist>
PLIST

# Optional OAuth client IDs for Google Drive / OneDrive linking (never committed; see docs/PLAN.md §4).
# The same names also work as plain environment variables when running the binary directly.
for pair in "BetterShotGoogleClientID:BETTERSHOT_GOOGLE_CLIENT_ID" \
            "BetterShotGoogleClientSecret:BETTERSHOT_GOOGLE_CLIENT_SECRET" \
            "BetterShotOneDriveClientID:BETTERSHOT_ONEDRIVE_CLIENT_ID"; do
    key="${pair%%:*}"; var="${pair##*:}"
    if [ -n "${!var:-}" ]; then
        /usr/libexec/PlistBuddy -c "Add :$key string ${!var}" "$APP/Contents/Info.plist"
    fi
done

codesign --force --sign "$SIGN_IDENTITY" "$APP"
echo "Built $APP"
