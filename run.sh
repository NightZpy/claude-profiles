#!/bin/sh
# Builds "Claude Profiles.app", installs it in ~/Applications and opens it.
# With --build-only it only builds build/Claude Profiles.app (used by the release workflow).
set -e
cd "$(dirname "$0")"

command -v swiftc >/dev/null || { echo "swiftc not found. Run: xcode-select --install"; exit 1; }

APP="build/Claude Profiles.app"
rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Universal binary, so the same app runs on Apple silicon and Intel Macs.
for arch in arm64 x86_64; do
  swiftc -O -parse-as-library -target "$arch-apple-macos14" Sources/ClaudeProfiles.swift -o "build/ClaudeProfiles-$arch"
done
lipo -create build/ClaudeProfiles-arm64 build/ClaudeProfiles-x86_64 -output "$APP/Contents/MacOS/ClaudeProfiles"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

[ "$1" = "--build-only" ] && { echo "Built $APP"; exit 0; }

[ -d /Applications/Claude.app ] || echo "Note: Claude Desktop is not in /Applications; the app needs it to open profiles."
mkdir -p ~/Applications
pkill -x ClaudeProfiles || true
rm -rf ~/Applications/"Claude Profiles.app"
cp -R "$APP" ~/Applications/
open ~/Applications/"Claude Profiles.app"
echo "Installed ~/Applications/Claude Profiles.app (look for its icon in the menu bar)"
