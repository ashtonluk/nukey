#!/bin/bash
set -euo pipefail

VERSION="0.1.0"
SHA256="b26e5a2d3edb63c709500fc28df32bec5e5b8ab54570055e5f1451d3f6bd4436"
ARCHIVE="NuKey-${VERSION}-macos.zip"
URL="https://github.com/ashtonluk/nukey/releases/download/v${VERSION}/${ARCHIVE}"
INSTALL_DIR="${NUKEY_INSTALL_DIR:-$HOME/Applications}"
TARGET="$INSTALL_DIR/NuKey.app"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "NuKey chỉ hỗ trợ macOS." >&2
    exit 1
fi
if [ -e "$TARGET" ]; then
    echo "Đã có NuKey tại $TARGET. Hãy thoát ứng dụng và đổi tên hoặc xóa bản cũ trước khi cài." >&2
    exit 1
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/nukey-install.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Đang tải NuKey ${VERSION}…"
curl -fsSL "$URL" -o "$TMP_DIR/$ARCHIVE"
ACTUAL_SHA256="$(shasum -a 256 "$TMP_DIR/$ARCHIVE" | awk '{print $1}')"
if [ "$ACTUAL_SHA256" != "$SHA256" ]; then
    echo "Mã SHA-256 không khớp. Đã dừng cài đặt." >&2
    exit 1
fi

echo "Đã kiểm tra SHA-256. Đang cài đặt…"
ditto -x -k "$TMP_DIR/$ARCHIVE" "$TMP_DIR/unpacked"
codesign --verify --deep --strict "$TMP_DIR/unpacked/NuKey.app"
mkdir -p "$INSTALL_DIR"
ditto "$TMP_DIR/unpacked/NuKey.app" "$TMP_DIR/NuKey.app"
mv "$TMP_DIR/NuKey.app" "$TARGET"
echo "Đã cài NuKey vào: $TARGET"
echo "Mở ứng dụng: open \"$TARGET\""
