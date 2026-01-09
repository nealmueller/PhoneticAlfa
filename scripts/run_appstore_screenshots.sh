#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-/Users/nealmueller/dev/PhoneticConverter/screenshots/appstore}"
DEVICE_NAME="${2:-iPhone 17}"
PROJECT="/Users/nealmueller/dev/PhoneticConverter/PhoneticConverter/PhoneticConverter.xcodeproj"
SCHEME="PhoneticConverter"
DESTINATION="platform=iOS Simulator,name=${DEVICE_NAME},OS=26.2"

mkdir -p "$OUT_DIR"

xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -only-testing:PhoneticConverterUITests/PhoneticConverterUITests/testAppStoreScreenshots \
  SCREENSHOT_OUTPUT_DIR="$OUT_DIR"

echo "Saved screenshots to: $OUT_DIR"
