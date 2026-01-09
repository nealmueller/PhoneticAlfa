#!/usr/bin/env bash
set -euo pipefail

DEVICE_NAME="${1:-iPhone 15}"
OUT_DIR="${2:-screenshots}"

mkdir -p "$OUT_DIR"

# Boot device and open the app. If already running, the commands are harmless.
UDID=$(xcrun simctl list devices | grep -F "$DEVICE_NAME" | grep -Eo '[0-9A-F\-]{36}' | head -n1 || true)
if [[ -z "$UDID" ]]; then
  echo "Device not found: $DEVICE_NAME" >&2
  exit 1
fi

xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl launch "$UDID" com.nealmueller.PhoneticConverter >/dev/null 2>&1 || true

# Wait a moment for the UI to settle.
sleep 2

# Capture a screenshot of the current simulator state.
STAMP=$(date +"%Y%m%d_%H%M%S")
OUT_FILE="$OUT_DIR/${DEVICE_NAME// /_}_${STAMP}.png"

xcrun simctl io "$UDID" screenshot "$OUT_FILE"

echo "Saved screenshot: $OUT_FILE"
