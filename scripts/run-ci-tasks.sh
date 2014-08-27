#!/bin/bash -ex
set -o pipefail

SCRIPT_DIRECTORY=`dirname $0`
ROOT_PATH=`dirname "${0}"`/../

source "${SCRIPT_DIRECTORY}/configure-xcode-version.sh"

"${ROOT_PATH}/Deploy/distribute.sh"

"${SCRIPT_DIRECTORY}/mock_setup.sh"

rm -rf "${ROOT_PATH}/test-output"
mkdir -p "${ROOT_PATH}/test-output"

# Run our Logic Tests
xcrun xcodebuild -destination 'platform=iOS Simulator,OS=8.0,name=iPhone 5s' -project "${ROOT_PATH}/AirshipLib/AirshipLib.xcodeproj" -scheme AirshipLib test | tee "${ROOT_PATH}/test-output/XCTEST-LOGIC.out"

# Run our Application Tests
xcrun xcodebuild -destination 'platform=iOS Simulator,OS=8.0,name=iPhone 5s' -project "${ROOT_PATH}/PushSample/PushSampleLib.xcodeproj" -scheme PushSample test | tee "${ROOT_PATH}/test-output/XCTEST-APPLICATION.out"
