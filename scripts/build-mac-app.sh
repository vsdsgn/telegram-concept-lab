#!/bin/zsh
# Build and install a native macOS SwiftUI front-end for the existing local Python orchestrator.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$HOME/Applications/Telegram Concept Lab.app"
SOURCE="$ROOT/mac-app/Sources/TelegramConceptLab.swift"
BINARY="$APP/Contents/MacOS/TelegramConceptLab"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
echo "[1/4] Compiling native SwiftUI app"
/usr/bin/xcrun swiftc -swift-version 5 -parse-as-library -O \
  -module-name TelegramConceptLab \
  -framework SwiftUI -framework AppKit -framework Combine \
  "$SOURCE" -o "$BINARY"
echo "[2/4] Writing app metadata"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>ru</string>
  <key>CFBundleExecutable</key><string>TelegramConceptLab</string>
  <key>CFBundleIdentifier</key><string>id.vsdsgn.telegram-concept-lab</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>Telegram Concept Lab</string>
  <key>CFBundleDisplayName</key><string>Telegram Concept Lab</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
/usr/bin/plutil -lint "$APP/Contents/Info.plist"
echo "[3/4] Ad-hoc signing local build"
/usr/bin/codesign --force --sign - --deep "$APP"
echo "[4/4] Adding desktop shortcut"
if [[ ! -e "$HOME/Desktop/Telegram Concept Lab.app" && ! -L "$HOME/Desktop/Telegram Concept Lab.app" ]]; then
  /bin/ln -s "$APP" "$HOME/Desktop/Telegram Concept Lab.app"
fi
# Remove only the obsolete Desktop shortcut we created, not other user files.
OLD_SHORTCUT="$HOME/Desktop/Telegram Concept Lab.command"
OLD_TARGET="$ROOT/scripts/Telegram Concept Lab.command"
if [[ -L "$OLD_SHORTCUT" && "$(/usr/bin/readlink "$OLD_SHORTCUT")" == "$OLD_TARGET" ]]; then
  /bin/rm "$OLD_SHORTCUT"
fi
echo "INSTALLED: $APP"
