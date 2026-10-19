#!/bin/bash
# Builds build/Dropwheel.app. Use --install to copy it to /Applications and launch it.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Dropwheel"
APP="build/Dropwheel.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/engine"
cp "$BIN" "$APP/Contents/MacOS/Dropwheel"
cp engine/engine.py "$APP/Contents/Resources/engine/engine.py"

mkdir -p build docs
rm -rf build/AppIcon.iconset
swift scripts/make_icon.swift build/AppIcon.iconset "${ICON_THEME:-lilac}"
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
cp build/AppIcon.iconset/icon_512x512.png docs/icon.png

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Dropwheel</string>
    <key>CFBundleIdentifier</key><string>com.dropwheel.app</string>
    <key>CFBundleName</key><string>Dropwheel</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
    pkill -x Dropwheel 2>/dev/null || true
    rm -rf /Applications/Dropwheel.app
    cp -R "$APP" /Applications/
    open /Applications/Dropwheel.app
    echo "Installed in /Applications"
fi
