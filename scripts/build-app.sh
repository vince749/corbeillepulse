#!/bin/bash
# Builds dist/CorbeillePulse.app (universal), signed with a real identity so macOS keeps
# its permissions (Automation > Finder) from one build to the next. CP_SIGN_IDENTITY overrides
# the choice; otherwise Developer ID Application, then Apple Development, then ad hoc.
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
cp -R Resources/en.lproj Resources/fr.lproj "$app/Contents/Resources/"
printf 'APPL????' > "$app/Contents/PkgInfo"

# An ad hoc signature is pinned to the binary's hash, which changes with every build:
# macOS then sees a new app and asks for the Finder permission again.
find_identity() {
    security find-identity -v -p codesigning | awk -v kind="$1" 'index($0, "\"" kind ":") {print $2; exit}'
}
identity=${CP_SIGN_IDENTITY:-$(find_identity "Developer ID Application")}
identity=${identity:-$(find_identity "Apple Development")}
if [ -z "$identity" ]; then
    echo "warning: no signing identity found, signing ad hoc: macOS will ask for Finder access again after each update" >&2
    identity=-
fi
echo "signing with: $identity"
codesign --force --sign "$identity" --options runtime --entitlements Resources/CorbeillePulse.entitlements "$app"
codesign --verify --deep --strict "$app"
echo "$app"
