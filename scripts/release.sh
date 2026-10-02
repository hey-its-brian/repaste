#!/usr/bin/env bash
# Builds a Developer ID signed, notarized, stapled Repaste-<version>.zip in ./build/release.
#
# One-time setup:
#   1. A "Developer ID Application" certificate for team L6X8U2TQ6F in your login keychain.
#   2. Notary credentials saved under a keychain profile (default name below):
#        xcrun notarytool store-credentials repaste-notary --apple-id <you> --team-id L6X8U2TQ6F
#      (it prompts for an app-specific password from account.apple.com)
#      Use NOTARY_PROFILE=<name> to point at a profile saved under another name.
set -euo pipefail

cd "$(dirname "$0")/.."
TEAM=L6X8U2TQ6F
PROFILE="${NOTARY_PROFILE:-repaste-notary}"
OUT=build/release

IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' "/Developer ID Application:.*\\($TEAM\\)/ {print \$2; exit}")"
if [[ -z "$IDENTITY" ]]; then
  echo "error: no 'Developer ID Application' certificate for team $TEAM in the keychain." >&2
  exit 1
fi

echo "==> Building"
./scripts/build-app.sh
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' build/Repaste.app/Contents/Info.plist)"
APP="$OUT/Repaste.app"
ZIP="$OUT/Repaste-$VERSION.zip"
rm -rf "$OUT" && mkdir -p "$OUT"
cp -R build/Repaste.app "$APP"

echo "==> Signing with $IDENTITY"
# Notarization requires the hardened runtime and a secure timestamp. Repaste needs no
# entitlements: sending ⌘V for auto-paste is gated by Accessibility permission instead.
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Notarizing (usually a few minutes)"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait

echo "==> Stapling"
xcrun stapler staple "$APP"
rm "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
spctl --assess --type execute --verbose "$APP"

shasum -a 256 "$ZIP"
echo "Done: $ZIP"
