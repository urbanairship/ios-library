#!/bin/bash
# build_sdk.sh <scheme> <destination> <derived_data_path>
#  - scheme: xcodebuild scheme to build (e.g. "AirshipRelease", "AirshipRelease tvOS")
#  - destination: xcodebuild destination (e.g. "generic/platform=visionOS")
#  - derived_data_path: derived data path
#
# Plain `build` of the whole SDK for a single platform. Unlike the release
# (`build_xcframeworks.sh`), this does not archive, package XCFrameworks, or
# sign — it just compiles every framework for one destination, so it's fast
# enough for CI and catches platform-specific compile breaks (tvOS/visionOS)
# long before the release build would.

set -o pipefail
set -e
set -x

ROOT_PATH=`dirname "${0}"`/..

SCHEME="$1"
DESTINATION="$2"
DERIVED_DATA_PATH="$3"

if [[ -z "$SCHEME" || -z "$DESTINATION" || -z "$DERIVED_DATA_PATH" ]]; then
    echo "Usage: build_sdk.sh <scheme> <destination> <derived_data_path>"
    exit 1
fi

echo -ne "\n\n *********** BUILDING $SCHEME ($DESTINATION) *********** \n\n"

xcrun xcodebuild build \
  -workspace "${ROOT_PATH}/Airship.xcworkspace" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO | xcbeautify --renderer $XCBEAUTIFY_RENDERER
