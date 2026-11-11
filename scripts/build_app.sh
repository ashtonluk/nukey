#!/bin/bash
# Build NuKey.app (menu bar, không hiện Dock). Chạy từ thư mục gốc dự án.
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_PATH="${NUKEY_BUILD_PATH:-.build}"
VERSION="$(tr -d '\n' < VERSION)"
swift build -c release --product NuKey --arch arm64 --arch x86_64 --scratch-path "$BUILD_PATH"
APP="build/NuKey.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BUILD_PATH/release/NuKey" "$APP/Contents/MacOS/NuKey"
mkdir -p "$APP/Contents/Resources"
cp Resources/AppIcon.icns Resources/MenuIcon.png Resources/MenuIcon@2x.png Resources/MenuIcon-EN-generated.png Resources/MenuIcon-VI-generated.png "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>NuKey</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>local.nukey.vni</string>
    <key>CFBundleName</key><string>NuKey</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null
echo "Đã tạo: $(pwd)/$APP"
