#!/bin/bash -ex
set -o pipefail

SCRIPT_DIRECTORY=`dirname "$0"`
ROOT_PATH=`dirname "${0}"`/../

# Target iOS SDK when building the projects
TARGET_SDK='iphonesimulator'
TEST_DESTINATION='platform=iOS Simulator,OS=latest,name=iPhone SE'

start_time=`date +%s`

# Make sure everything builds
source "${SCRIPT_DIRECTORY}/build.sh"

# Set a derived data path for all scheme-based builds (for tests)
DERIVED_DATA=$(mktemp -d /tmp/ci-derived-data-XXXXX)

# Build All Sample Projects
# Use Debug configurations and a simulator SDK so the build process doesn't attempt to sign the output
xcrun xcodebuild -project "${ROOT_PATH}/Sample/Sample.xcodeproj" -derivedDataPath "${DERIVED_DATA}" -scheme Sample -configuration Debug -sdk $TARGET_SDK -destination "${TEST_DESTINATION}"
xcrun xcodebuild -project "${ROOT_PATH}/SwiftSample/SwiftSample.xcodeproj" -derivedDataPath "${DERIVED_DATA}" -scheme SwiftSample -configuration Debug -sdk $TARGET_SDK  -destination "${TEST_DESTINATION}"

##################################################################################################
# Run the Tests!
##################################################################################################

source "${SCRIPT_DIRECTORY}/mock_setup.sh"

rm -rf "${ROOT_PATH}/test-output"
mkdir -p "${ROOT_PATH}/test-output"

# Run our Logic Tests
xcrun xcodebuild -destination "${TEST_DESTINATION}" -project "${ROOT_PATH}/AirshipKit/AirshipKit.xcodeproj" -derivedDataPath "${DERIVED_DATA}" -scheme AirshipKitTests test | tee "${ROOT_PATH}/test-output/XCTEST-LOGIC.out"

# delete derived data
rm -rf "${DERIVED_DATA}"

end_time=`date +%s`
echo execution time was `expr $end_time - $start_time` s.
