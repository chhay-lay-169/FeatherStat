#!/bin/bash
set -e

APP_DIR="build/TinyStats.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cat << 'PLIST' > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>TinyStats</string>
    <key>CFBundleIdentifier</key><string>com.tinystats.app</string>
    <key>CFBundleName</key><string>TinyStats</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

swiftc -O Sources/main.swift -o "$APP_DIR/Contents/MacOS/TinyStats"

DMG_STAGING="/tmp/TinyStats_DMG"
rm -rf "$DMG_STAGING" build/TinyStats.dmg
mkdir -p "$DMG_STAGING"
cp -R "$APP_DIR" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create -volname "TinyStats" -srcfolder "$DMG_STAGING" -ov -format UDZO build/TinyStats.dmg
rm -rf "$DMG_STAGING"
echo "Built build/TinyStats.dmg successfully."
