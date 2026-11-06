#!/bin/bash
# Builds dist/CorbeillePulse.app (universal, ad hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."

flags=(-c release --arch arm64 --arch x86_64)
swift build "${flags[@]}"
binary="$(swift build "${flags[@]}" --show-bin-path)/CorbeillePulse"

app="dist/CorbeillePulse.app"
command rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp -X "$binary" "$app/Contents/MacOS/CorbeillePulse"
cp -X Resources/Info.plist "$app/Contents/Info.plist"
cp -X Resources/app-icon.icns "$app/Contents/Resources/app-icon.icns"
printf 'APPL????' > "$app/Contents/PkgInfo"

codesign --force --sign - --options runtime --entitlements Resources/CorbeillePulse.entitlements "$app"
codesign --verify --deep --strict "$app"
echo "$app"
