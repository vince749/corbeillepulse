#!/bin/bash
# Publishes the version set in Resources/Info.plist: tag, GitLab release, GitHub release.
# Needs: glab-nt (Northern Tech GitLab account), gh logged in as vince749,
# and docs/release-notes/<version>.md.
set -euo pipefail
cd "$(dirname "$0")/.."

gitlab_project="northerntech1/mac-apps/corbeillepulse"
github_repo="vince749/corbeillepulse"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
tag="v$version"
notes="docs/release-notes/$version.md"

fail() { echo "release: $*" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || fail "commit your changes first"
[ "$(git branch --show-current)" = main ] || fail "release from main"
[ -f "$notes" ] || fail "write $notes first"
git rev-parse -q --verify "refs/tags/$tag" >/dev/null && fail "$tag already exists: bump the version in Resources/Info.plist"
gh auth status >/dev/null 2>&1 || fail "log in to GitHub first: gh auth login"

swift test
scripts/check-localization.sh
scripts/build-app.sh
scripts/make-dmg.sh
dmg="dist/CorbeillePulse-$version.dmg"

# GitLab over HTTPS with the Northern Tech token; GitHub with gh's credentials.
gitlab_push() {
    git -c credential.helper= \
        -c 'credential.helper=!f() { echo username=oauth2; echo "password=$(security find-generic-password -s glab-nt -a nt -w)"; }; f' \
        push "$@"
}
git tag -a "$tag" -m "CorbeillePulse $version"
gitlab_push origin main "$tag"
git -c credential.helper= -c 'credential.helper=!gh auth git-credential' push github main "$tag"

glab-nt release create "$tag" "$dmg#CorbeillePulse-$version.dmg" -R "$gitlab_project" \
    --name "CorbeillePulse $version" --notes-file "$notes"
# Stable path, so .../releases/permalink/latest/downloads/CorbeillePulse.dmg always serves the latest DMG.
project=${gitlab_project//\//%2F}
link_id=$(glab-nt api "projects/$project/releases/$tag/assets/links" | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["id"])')
glab-nt api -X PUT "projects/$project/releases/$tag/assets/links/$link_id" \
    -f name="CorbeillePulse-$version.dmg" -f direct_asset_path=/CorbeillePulse.dmg -f link_type=package >/dev/null

gh release create "$tag" "$dmg" -R "$github_repo" --verify-tag --title "CorbeillePulse $version" --notes-file "$notes"
echo "Released $tag"
