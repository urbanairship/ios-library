#!/bin/bash

set -o pipefail
set -e
set -x

ROOT_PATH=`dirname "${0}"`/..

echo -ne "\n\n *********** RUNNING TESTS $1 *********** \n\n"

xcrun xcodebuild \
-destination "${TEST_DESTINATION}" \
-workspace "${ROOT_PATH}/Airship.xcworkspace" \
-scheme $1 \
-derivedDataPath $2 \
test | xcbeautify --renderer $XCBEAUTIY_RENDERER