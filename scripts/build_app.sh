#!/bin/bash
# Build NuKey.app (menu bar, không hiện Dock). Chạy từ thư mục gốc dự án.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product NuKey
APP="build/NuKey.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/NuKey "$APP/Contents/MacOS/NuKey"
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
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Đã tạo: $(pwd)/$APP"
