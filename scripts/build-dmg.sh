#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DERIVED_DATA_DIR="$BUILD_DIR/DerivedData"
RELEASE_APP_PATH="$DERIVED_DATA_DIR/Build/Products/Release/LazyClip.app"
STAGING_DIR="$BUILD_DIR/dmg"
DMG_PATH="$BUILD_DIR/LazyClip.dmg"
VOLUME_NAME="LazyClip"

rm -rf "$DERIVED_DATA_DIR" "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$BUILD_DIR" "$STAGING_DIR"

xcodebuild build \
  -project "$ROOT_DIR/LazyClip.xcodeproj" \
  -scheme LazyClip \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  -destination 'platform=macOS'

cp -R "$RELEASE_APP_PATH" "$STAGING_DIR/LazyClip.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

printf 'Built app: %s\n' "$RELEASE_APP_PATH"
printf 'Packaged dmg: %s\n' "$DMG_PATH"
