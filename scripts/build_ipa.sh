#!/usr/bin/env bash
# Builds an UNSIGNED PulseFit.ipa for sideloading (Sideloadly / AltStore / SideStore).
# Run this on a Mac with Xcode installed:
#   ./scripts/build_ipa.sh [output.ipa]
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="${1:-PulseFit-unsigned.ipa}"
CONFIGURATION="${CONFIGURATION:-Release}"

ZIP_PATH="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"

echo "==> Archiving PulseFit ($CONFIGURATION, unsigned)..."
rm -rf build
mkdir -p build
xcodebuild archive \
  -project PulseFit.xcodeproj \
  -scheme PulseFit \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=iOS" \
  -archivePath build/PulseFit.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" CODE_SIGN_ENTITLEMENTS=""

APP="build/PulseFit.xcarchive/Products/Applications/PulseFit.app"
if [ ! -d "$APP" ]; then
  echo "ERROR: archive did not produce $APP" >&2
  exit 1
fi

echo "==> Packaging $ZIP_PATH ..."
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
mkdir -p "$STAGING/Payload"
cp -R "$APP" "$STAGING/Payload/"
(cd "$STAGING" && zip -qry "$ZIP_PATH" Payload)

echo ""
echo "Done: $ZIP_PATH"
echo "Sideload it with your signer (Sideloadly, AltStore, SideStore, ...)."
