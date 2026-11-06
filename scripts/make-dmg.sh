#!/bin/bash
# Builds dist/CorbeillePulse-<version>.dmg from dist/CorbeillePulse.app.
set -euo pipefail
cd "$(dirname "$0")/.."

app="dist/CorbeillePulse.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
output="dist/CorbeillePulse-$version.dmg"
volume="CorbeillePulse"

work=$(mktemp -d)
trap 'command rm -rf "$work"' EXIT
mkdir "$work/stage"
ditto "$app" "$work/stage/CorbeillePulse.app"
ln -s /Applications "$work/stage/Applications"
cp -X "Resources/Read me - Lisez-moi.txt" "$work/stage/Read me - Lisez-moi.txt"

hdiutil create -quiet -volname "$volume" -srcfolder "$work/stage" -fs APFS -format UDRW -ov "$work/rw.dmg"
mount=$(hdiutil attach -noverify -noautoopen "$work/rw.dmg" 2>/dev/null | awk -F'\t' '/\/Volumes\//{print $NF}')

# The window layout is cosmetic: if Finder is busy, the DMG still works without it.
osascript 2>&1 <<APPLESCRIPT || echo "warning: window layout not applied"
with timeout of 30 seconds
  tell application "Finder"
    tell disk "$volume"
      open
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set bounds of container window to {200, 120, 840, 520}
      set viewOptions to icon view options of container window
      set arrangement of viewOptions to not arranged
      set icon size of viewOptions to 112
      set position of item "CorbeillePulse.app" of container window to {170, 170}
      set position of item "Applications" of container window to {470, 170}
      set position of item "Read me - Lisez-moi.txt" of container window to {320, 320}
      update without registering applications
      delay 2
      close
    end tell
  end tell
end timeout
APPLESCRIPT

sync
hdiutil detach -quiet "$mount" || { sleep 3; hdiutil detach "$mount"; }
hdiutil convert -quiet "$work/rw.dmg" -format ULFO -ov -o "$output"
hdiutil verify -quiet "$output"
echo "$output"
