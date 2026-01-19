#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

OUT_DIR="${1:-$ROOT_DIR/screenshots/appstore/iphone_6_1}"
DEVICE_NAME="${2:-iPhone 17}"
PROJECT="$ROOT_DIR/Phonetic.xcodeproj"
SCHEME="Phonetic"
DESTINATION="platform=iOS Simulator,name=${DEVICE_NAME},OS=26.2"
FILENAME_PREFIX="$(basename "$OUT_DIR")_"

mkdir -p "$OUT_DIR"

xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -only-testing:PhoneticUITests/PhoneticUITests/testAppStoreScreenshots \
  SCREENSHOT_OUTPUT_DIR="$OUT_DIR" \
  SCREENSHOT_FILENAME_PREFIX="$FILENAME_PREFIX"

echo "Saved screenshots to: $OUT_DIR"
