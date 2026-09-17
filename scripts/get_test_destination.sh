#!/bin/bash
# get_test_destination.sh
#
# Resolves an `xcodebuild -destination` for an iPhone simulator from whatever is actually
# installed, rather than a hardcoded model name -- the runner image's simulator instances roll
# out gradually per Xcode/OS version, so a given tier (e.g. "iPhone 17 Pro Max") can be present
# on one runner and missing on another running the identical Xcode.

set -o pipefail
set -e

# Anchored to the active Xcode's own SDK version, not whatever's newest installed on the
# machine -- multiple Xcodes can leave multiple iOS runtimes side by side, and picking the
# global max would silently test against a runtime this build's Xcode never shipped with.
SDK_VERSION=$(xcrun --sdk iphonesimulator --show-sdk-version)

RUNTIME_ID=$(xcrun simctl list runtimes available -j | jq -r --arg sdk "$SDK_VERSION" '
  [.runtimes[] | select(.platform == "iOS")] as $runtimes
  | ($runtimes | map(select(.version == $sdk)) | first.identifier) //
    ($runtimes | sort_by(.version | split(".") | map(tonumber)) | last.identifier)
')

if [ -z "$RUNTIME_ID" ] || [ "$RUNTIME_ID" == "null" ]; then
  echo "No available iOS Simulator runtime found." 1>&2
  xcrun simctl list runtimes 1>&2
  exit 1
fi

DEVICES_JSON=$(xcrun simctl list devices available -j | jq --arg runtime "$RUNTIME_ID" '
  .devices[$runtime] // [] | map(select(.name | test("^iPhone")))
')

# Prefer the current flagship, but fall back to whatever iPhone simulator this runtime actually
# has rather than failing outright -- exact model has no bearing on what a test run exercises.
DEVICE_UDID=""
for pattern in "Pro Max$" "Pro$" "."; do
  DEVICE_UDID=$(echo "$DEVICES_JSON" | jq -r --arg p "$pattern" '[.[] | select(.name | test($p))] | first.udid // empty')
  if [ -n "$DEVICE_UDID" ]; then
    break
  fi
done

if [ -z "$DEVICE_UDID" ]; then
  echo "No available iPhone simulator found for runtime $RUNTIME_ID." 1>&2
  xcrun simctl list devices available 1>&2
  exit 1
fi

echo "platform=iOS Simulator,id=$DEVICE_UDID"
