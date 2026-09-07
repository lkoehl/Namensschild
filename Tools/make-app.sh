#!/bin/bash
# Baut Namensschild.app als Universal-Binary (Apple Silicon + Intel),
# ohne Fremdabhängigkeiten.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
BUILD="$ROOT/build"
APP="$BUILD/Namensschild.app"
VERSION="1.0"

echo "› Release bauen (arm64 + x86_64)"
swift build -c release --arch arm64 --arch x86_64 --product NamensschildApp
swift build -c release --arch arm64 --arch x86_64 --product badgectl

BINARY="$ROOT/.build/apple/Products/Release/NamensschildApp"
CLI="$ROOT/.build/apple/Products/Release/badgectl"
[ -f "$BINARY" ] || { echo "Binary nicht gefunden: $BINARY" >&2; exit 1; }

echo "› Symbol erzeugen"
rm -rf "$BUILD/icon"
mkdir -p "$BUILD/icon"
swift Tools/make-icon.swift "$BUILD/icon" >/dev/null
iconutil -c icns "$BUILD/icon/AppIcon.iconset" -o "$BUILD/icon/AppIcon.icns"

echo "› Bundle zusammensetzen"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/Namensschild"
cp "$BUILD/icon/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
# Das Kommandozeilenwerkzeug reist im Bundle mit, damit ein einziges
# weitergegebenes Paket beides enthält.
cp "$CLI" "$APP/Contents/MacOS/badgectl"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Namensschild</string>
    <key>CFBundleDisplayName</key><string>Namensschild</string>
    <key>CFBundleIdentifier</key><string>de.lkoehl.namensschild</string>
    <key>CFBundleExecutable</key><string>Namensschild</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>ALLNET LED-Namensschild für macOS</string>
</dict>
</plist>
PLIST

echo "› Ad-hoc signieren"
codesign --force --deep --sign - --timestamp=none "$APP" >/dev/null 2>&1

echo
echo "Fertig: $APP  ($(lipo -archs "$APP/Contents/MacOS/Namensschild"))"
echo "  Installieren:  cp -R \"$APP\" /Applications/"
echo "  Weitergeben:   ./Tools/make-dmg.sh"
