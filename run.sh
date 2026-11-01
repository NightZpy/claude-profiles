#!/bin/sh
# Builds "Claude Profiles.app", installs it in ~/Applications and opens it.
set -e
cd "$(dirname "$0")"

CLAUDE_APP=/Applications/Claude.app
[ -d "$CLAUDE_APP" ] || { echo "Claude Desktop not found in /Applications. Install it first."; exit 1; }
command -v swiftc >/dev/null || { echo "swiftc not found. Run: xcode-select --install"; exit 1; }

APP="build/Claude Profiles.app"
rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -parse-as-library Sources/ClaudeProfiles.swift -o "$APP/Contents/MacOS/ClaudeProfiles"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

mkdir -p ~/Applications
pkill -x ClaudeProfiles || true
rm -rf ~/Applications/"Claude Profiles.app"
cp -R "$APP" ~/Applications/
open ~/Applications/"Claude Profiles.app"
echo "Installed ~/Applications/Claude Profiles.app (look for its icon in the menu bar)"
