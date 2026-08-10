#!/bin/zsh
# SPDX-License-Identifier: MPL-2.0

set -euo pipefail

SCRIPT_DIR=${0:A:h}
REPO_ROOT=${SCRIPT_DIR:h:h:h}
OUTPUT_DIR=${1:-"$REPO_ROOT/docs/app-store/screenshots/en-US"}
DERIVED_DATA=${FITKIKU_SCREENSHOT_DERIVED_DATA:-/tmp/fitkiku-app-store-screenshots}
SIMULATOR_ID=${FITKIKU_SCREENSHOT_SIMULATOR_ID:-}

if [[ -z "$SIMULATOR_ID" ]]; then
  SIMULATOR_ID=$(xcrun simctl list devices available \
    | awk -F '[()]' '/iPhone 17 Pro Max/ { print $2; exit }')
fi
if [[ -z "$SIMULATOR_ID" ]]; then
  print -u2 "An available iPhone 17 Pro Max simulator is required."
  exit 1
fi

CAPTURE_TMP=$(mktemp -d /tmp/fitkiku-screenshots.XXXXXX)
cleanup() {
  xcrun simctl status_bar "$SIMULATOR_ID" clear >/dev/null 2>&1 || true
  xcrun simctl ui "$SIMULATOR_ID" appearance light >/dev/null 2>&1 || true
  xcrun simctl ui "$SIMULATOR_ID" content_size medium >/dev/null 2>&1 || true
  rm -r -- "$CAPTURE_TMP"
}
trap cleanup EXIT

xcrun simctl boot "$SIMULATOR_ID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIMULATOR_ID" -b
xcrun simctl ui "$SIMULATOR_ID" appearance light
xcrun simctl ui "$SIMULATOR_ID" content_size medium
xcrun simctl status_bar "$SIMULATOR_ID" override \
  --time '9:41' --batteryLevel 100 --wifiBars 3 --cellularBars 4

xcodebuild \
  -project "$REPO_ROOT/ios/FitKiku/FitKiku.xcodeproj" \
  -scheme FitKiku \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  build >/tmp/fitkiku-screenshot-build.log

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/FitKiku.app"
xcrun simctl uninstall "$SIMULATOR_ID" com.kikuai.fitkiku.health >/dev/null 2>&1 || true
xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
mkdir -p "$OUTPUT_DIR"

SCENARIOS=(
  'first-run:01-first-run'
  'consent:02-consent'
  'current:03-current-delivery'
  'partial:04-partial-delivery'
)

for item in $SCENARIOS; do
  scenario=${item%%:*}
  filename=${item##*:}
  raw="$CAPTURE_TMP/$filename.png"
  output="$OUTPUT_DIR/$filename.jpg"

  xcrun simctl terminate "$SIMULATOR_ID" com.kikuai.fitkiku.health \
    >/dev/null 2>&1 || true
  SIMCTL_CHILD_FITKIKU_DEMO_SCENARIO="$scenario" \
    xcrun simctl launch "$SIMULATOR_ID" com.kikuai.fitkiku.health >/dev/null
  sleep 2
  xcrun simctl io "$SIMULATOR_ID" screenshot "$raw" >/dev/null
  sips -s format jpeg -s formatOptions 100 "$raw" --out "$output" >/dev/null

  width=$(sips -g pixelWidth "$output" | awk '/pixelWidth/ { print $2 }')
  height=$(sips -g pixelHeight "$output" | awk '/pixelHeight/ { print $2 }')
  if [[ "$width" != 1320 || "$height" != 2868 ]]; then
    print -u2 "$output has unexpected dimensions: ${width}x${height}"
    exit 1
  fi
  print "$output"
done
