#!/bin/bash -ex
set -o pipefail

SCRIPT_DIRECTORY=`dirname "$0"`
ROOT_PATH=`dirname "${0}"`/../

# Destination for tests
TEST_DESTINATION='platform=iOS Simulator,OS=latest,name=iPhone 6s'

# Target iOS SDK when building the projects
TARGET_SDK='iphonesimulator'

start_time=`date +%s`

source "${SCRIPT_DIRECTORY}/configure-xcode-version.sh"

"${ROOT_PATH}/Deploy/distribute.sh"

# Set a derived data path for all scheme-based builds (for tests)
DERIVED_DATA=$(mktemp -d /tmp/ci-derived-data-XXXXX)

# Build All Sample Projects
# Use Debug configurations and a simulator SDK so the build process doesn't attempt to sign the output

# Build Distrbution Projects First
# InboxSample targets
xcrun xcodebuild -project "${ROOT_PATH}/InboxSample/InboxSample.xcodeproj" -configuration Debug -sdk $TARGET_SDK

# PushSample targets
xcrun xcodebuild -project "${ROOT_PATH}/PushSample/PushSample.xcodeproj" -configuration Debug -sdk $TARGET_SDK

# Build 'lib' projects and targets
# build InboxSampleLib targets - use scheme so that AirshipLib is built
xcrun xcodebuild -project "${ROOT_PATH}/InboxSample/InboxSampleLib.xcodeproj" -derivedDataPath "${DERIVED_DATA}" -scheme InboxSample -configuration Debug -sdk $TARGET_SDK
xcrun xcodebuild -project "${ROOT_PATH}/InboxSample/InboxSample.xcodeproj" -derivedDataPath "${DERIVED_DATA}" -scheme InboxSample-Kit -configuration Debug -sdk $TARGET_SDK

# build PushSampleLib targets - use scheme so that AirshipLib is built
xcrun xcodebuild -project "${ROOT_PATH}/PushSample/PushSampleLib.xcodeproj" -derivedDataPath "${DERIVED_DATA}" -scheme PushSample -configuration Debug -sdk $TARGET_SDK
xcrun xcodebuild -project "${ROOT_PATH}/PushSample/PushSample.xcodeproj" -derivedDataPath "${DERIVED_DATA}" -scheme PushSample-Kit -configuration Debug -sdk $TARGET_SDK

##################################################################################################
# Run the Tests!
##################################################################################################

"${SCRIPT_DIRECTORY}/mock_setup.sh"

rm -rf "${ROOT_PATH}/test-output"
mkdir -p "${ROOT_PATH}/test-output"

# Run our Logic Tests
xcrun xcodebuild -destination "${TEST_DESTINATION}" -project "${ROOT_PATH}/AirshipLib/AirshipLib.xcodeproj" -derivedDataPath "${DERIVED_DATA}" -scheme AirshipLib test | tee "${ROOT_PATH}/test-output/XCTEST-LOGIC.out"

# Run our Application Tests
xcrun xcodebuild -destination "${TEST_DESTINATION}" -project "${ROOT_PATH}/PushSample/PushSampleLib.xcodeproj" -derivedDataPath "${DERIVED_DATA}" -scheme PushSample test | tee "${ROOT_PATH}/test-output/XCTEST-APPLICATION.out"

# delete derived data
rm -rf "${DERIVED_DATA}"

end_time=`date +%s`
echo execution time was `expr $end_time - $start_time` s.
