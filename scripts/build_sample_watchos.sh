#!/bin/bash

set -o pipefail
set -e

ROOT_PATH=`dirname "${0}"`/..

SAMPLE="$1"
DERIVED_DATA="$2"

echo -ne "\n\n *********** BUILDING SAMPLE $SAMPLE *********** \n\n"

# Make sure AirshipConfig.plist exists
cp -np "${ROOT_PATH}/$SAMPLE/AirshipConfig.plist.sample" "${ROOT_PATH}/$SAMPLE/AirshipConfig.plist" || true

# Use Debug configurations and a simulator SDK so the build process doesn't attempt to sign the output
xcrun xcodebuild \
-configuration Debug \
-workspace "${ROOT_PATH}/Airship.xcworkspace" \
-scheme $SAMPLE \
-derivedDataPath "$DERIVED_DATA" | xcbeautify --renderer $XCBEAUTIFY_RENDERER
