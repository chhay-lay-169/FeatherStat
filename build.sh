#!/bin/bash
set -e

APP_DIR="build/FeatherStat.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cat << 'PLIST' > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>FeatherStat</string>
    <key>CFBundleIdentifier</key><string>com.featherstat.app</string>
    <key>CFBundleName</key><string>FeatherStat</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

swiftc -O Sources/main.swift -o "$APP_DIR/Contents/MacOS/FeatherStat"

DMG_STAGING="/tmp/FeatherStat_DMG"
rm -rf "$DMG_STAGING" build/FeatherStat.dmg
mkdir -p "$DMG_STAGING"
cp -R "$APP_DIR" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create -volname "FeatherStat" -srcfolder "$DMG_STAGING" -ov -format UDZO build/FeatherStat.dmg
rm -rf "$DMG_STAGING"
echo "Built build/FeatherStat.dmg successfully."
