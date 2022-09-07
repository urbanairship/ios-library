#!/bin/bash

set -o pipefail
set -e

ROOT_PATH=`dirname "${0}"`/..

SAMPLE="$1"
DERIVED_DATA="$2"

if [ $SAMPLE == "tvOSSample" ]
then
  TARGET_SDK='appletvsimulator'
else
  TARGET_SDK='iphonesimulator'
fi

echo -ne "\n\n *********** BUILDING SAMPLE $SAMPLE *********** \n\n"

# Make sure AirshipConfig.plist exists
cp -np "${ROOT_PATH}/$SAMPLE/AirshipConfig.plist.sample" "${ROOT_PATH}/$SAMPLE/AirshipConfig.plist" || true

# Use Debug configurations and a simulator SDK so the build process doesn't attempt to sign the output
xcrun xcodebuild \
-configuration Debug \
-workspace "${ROOT_PATH}/Airship.xcworkspace" \
-scheme "${SAMPLE}" \
-sdk $TARGET_SDK \
-derivedDataPath "$DERIVED_DATA"
