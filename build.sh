#!/bin/bash
# Builds Pomodoro.app. No Xcode required — Command Line Tools are enough.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Pomodoro"
BUNDLE_ID="com.jinwo.pomodoro"
APP="build/${APP_NAME}.app"
TARGET="arm64-apple-macosx14.0"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <!-- Menu bar accessory: no Dock icon. -->
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

echo "Compiling…"
swiftc \
  -target "$TARGET" \
  -parse-as-library \
  -O \
  -o "$APP/Contents/MacOS/${APP_NAME}" \
  Sources/*.swift

# Ad-hoc signature: enough for local notifications and the login item.
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP" 2>/dev/null

echo "Built $APP"
