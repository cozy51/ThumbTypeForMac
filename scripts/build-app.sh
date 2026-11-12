#!/bin/bash
# ThumbType.app を作成します（macOS・Xcodeコマンドラインツールが必要）。
#   ./scripts/build-app.sh            … Apple Silicon / Intel 両対応（Universal）
#   ARCHS=arm64 ./scripts/build-app.sh … 自分のMac用だけ（高速）
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0}"
ARCHS="${ARCHS:-arm64 x86_64}"
args=(-c release)
for arch in $ARCHS; do args+=(--arch "$arch"); done

swift build "${args[@]}"
BIN_DIR="$(swift build "${args[@]}" --show-bin-path)"

APP=build/ThumbType.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/layouts"
cp "$BIN_DIR/ThumbType" "$APP/Contents/MacOS/ThumbType"
cp layouts/NICOLA.yab layouts/NICOLA.tsv "$APP/Contents/Resources/layouts/"
sed "s/__VERSION__/$VERSION/g" scripts/Info.plist > "$APP/Contents/Info.plist"

# アイコン（assets/app-icon.png 1024px から .icns を作成）
ICONSET=build/AppIcon.iconset
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" assets/app-icon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" assets/app-icon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

# アドホック署名（未公証）。ビルドし直すとアクセシビリティの許可をやり直す必要があります。
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"

(cd build && ditto -c -k --keepParent ThumbType.app ThumbType-mac.zip)
echo "作成しました: $APP"
echo "配布用zip: build/ThumbType-mac.zip"
