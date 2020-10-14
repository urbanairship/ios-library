#!/bin/bash

set -o pipefail
set -e
set -x

ROOT_PATH=`dirname "${0}"`/..

echo -ne "\n\n *********** RUNNING TESTS *********** \n\n"

# Run AirshipCore Tests
xcrun xcodebuild \
-destination "${TEST_DESTINATION}" \
-workspace "${ROOT_PATH}/Airship.xcworkspace" \
-scheme AirshipCore \
test

# Run AirshipAccengage Tests
xcrun xcodebuild \
-destination "${TEST_DESTINATION}" \
-workspace "${ROOT_PATH}/Airship.xcworkspace" \
-scheme AirshipAccengage \
test

# Run AirshipServiceExtension Tests
xcrun xcodebuild \
-destination "${TEST_DESTINATION}" \
-workspace "${ROOT_PATH}/Airship.xcworkspace" \
-scheme AirshipNotificationServiceExtension \
test

# Run AirshipServiceExtension Tests
xcrun xcodebuild \
-destination "${TEST_DESTINATION}" \
-workspace "${ROOT_PATH}/Airship.xcworkspace" \
-scheme AirshipNotificationContentExtension \
test