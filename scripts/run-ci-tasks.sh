#!/bin/bash -ex
set -o pipefail

SCRIPT_DIRECTORY=`dirname "$0"`
ROOT_PATH=`dirname "${0}"`/../

start_time=`date +%s`

source "${SCRIPT_DIRECTORY}/configure-xcode-version.sh"

"${ROOT_PATH}/Deploy/distribute.sh"

# Set a derived data path for all scheme-based builds (for tests)
DERIVED_DATA=$(mktemp -d /tmp/ci-derived-data-XXXXX)

# Build All Sample Projects
# Use Debug configurations and a simulator SDK so the build process doesn't attempt to sign the output

# Build Distrbution Projects First
# InboxSample targets
xcrun xcodebuild -project "${ROOT_PATH}/InboxSample/InboxSample.xcodeproj" -configuration Debug -sdk iphonesimulator8.2

# PushSample targets
xcrun xcodebuild -project "${ROOT_PATH}/PushSample/PushSample.xcodeproj" -configuration Debug -sdk iphonesimulator8.2

# Build 'lib' projects and targets
# build InboxSampleLib targets - use scheme so that AirshipLib is built
xcrun xcodebuild -project "${ROOT_PATH}/InboxSample/InboxSampleLib.xcodeproj" -derivedDataPath "${DERIVED_DATA}" -scheme InboxSample -configuration Debug -sdk iphonesimulator8.2
xcrun xcodebuild -project "${ROOT_PATH}/InboxSample/InboxSampleLib.xcodeproj" -derivedDataPath "${DERIVED_DATA}" -scheme InboxSampleKit -configuration Debug -sdk iphonesimulator8.2

# build PushSampleLib targets - use scheme so that AirshipLib is built
xcrun xcodebuild -project "${ROOT_PATH}/PushSample/PushSampleLib.xcodeproj" -derivedDataPath "${DERIVED_DATA}" -scheme PushSample -configuration Debug -sdk iphonesimulator8.2
xcrun xcodebuild -project "${ROOT_PATH}/PushSample/PushSampleLib.xcodeproj" -derivedDataPath "${DERIVED_DATA}" -scheme PushSampleKit -configuration Debug -sdk iphonesimulator8.2

##################################################################################################
# Run the Tests!
##################################################################################################

"${SCRIPT_DIRECTORY}/mock_setup.sh"

rm -rf "${ROOT_PATH}/test-output"
mkdir -p "${ROOT_PATH}/test-output"

# Run our Logic Tests
xcrun xcodebuild -destination 'platform=iOS Simulator,OS=8.2,name=iPhone 5s' -project "${ROOT_PATH}/AirshipLib/AirshipLib.xcodeproj" -derivedDataPath "${DERIVED_DATA}" -scheme AirshipLib test | tee "${ROOT_PATH}/test-output/XCTEST-LOGIC.out"

# Run AirshipKit Tests
xcrun xcodebuild -destination 'platform=iOS Simulator,OS=8.2,name=iPhone 5s' -project "${ROOT_PATH}/AirshipLib/AirshipLib.xcodeproj" -derivedDataPath "${DERIVED_DATA}" -scheme AirshipKit test | tee "${ROOT_PATH}/test-output/XCTEST-AIRSHIPKIT.out"

# Run our Application Tests
xcrun xcodebuild -destination 'platform=iOS Simulator,OS=8.2,name=iPhone 5s' -project "${ROOT_PATH}/PushSample/PushSampleLib.xcodeproj" -derivedDataPath "${DERIVED_DATA}" -scheme PushSample test | tee "${ROOT_PATH}/test-output/XCTEST-APPLICATION.out"

# delete derived data
rm -rf "${DERIVED_DATA}"

end_time=`date +%s`
echo execution time was `expr $end_time - $start_time` s.
