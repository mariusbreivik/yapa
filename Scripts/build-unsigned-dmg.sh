#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROJECT="$REPO_ROOT/Yapa.xcodeproj"
SCHEME="Yapa"
CONFIGURATION="Release"
DERIVED_DATA="$REPO_ROOT/build/derived-data"
STAGING_ROOT="$REPO_ROOT/build/dmg-root"
DIST_DIR="$REPO_ROOT/dist"
APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/Yapa.app"
VERSION="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" -showBuildSettings | awk -F ' = ' '/MARKETING_VERSION = / { print $2; exit }')"
if [ -z "$VERSION" ]; then
  VERSION="1.0.0"
fi
DMG_NAME="Yapa-${VERSION}-unsigned.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

rm -rf "$DERIVED_DATA" "$STAGING_ROOT" "$DMG_PATH"
mkdir -p "$DERIVED_DATA" "$STAGING_ROOT" "$DIST_DIR"

echo "Building unsigned app..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM=""

if [ ! -d "$APP_PATH" ]; then
  echo "Error: app was not built at $APP_PATH" >&2
  exit 1
fi

echo "Staging DMG contents..."
ditto "$APP_PATH" "$STAGING_ROOT/Yapa.app"
ln -s /Applications "$STAGING_ROOT/Applications"

echo "Creating DMG..."
hdiutil create \
  -volname "Yapa" \
  -srcfolder "$STAGING_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Done: $DMG_PATH"
