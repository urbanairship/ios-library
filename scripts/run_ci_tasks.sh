#!/bin/bash -ex
set -o pipefail

SCRIPT_DIRECTORY=`dirname "$0"`
ROOT_PATH=`dirname "${0}"`/../
MAX_TEST_RETRIES=2
SECONDS_TO_WAIT_BEFORE_RETRY=10

# Target iOS SDK when building the projects
TARGET_SDK='iphonesimulator'
TEST_DESTINATION='platform=iOS Simulator,OS=latest,name=iPhone SE'

start_time=`date +%s`

# Make sure everything builds
source "${SCRIPT_DIRECTORY}/build.sh"

# Set a derived data path for all scheme-based builds (for tests)
DERIVED_DATA=$(mktemp -d /tmp/ci-derived-data-XXXXX)

##################################################################################################
# Build All Sample Projects
##################################################################################################
# Make sure AirshipConfig.plist exists
cp -np ${ROOT_PATH}/Sample/AirshipConfig.plist.sample ${ROOT_PATH}/Sample/AirshipConfig.plist || true
cp -np ${ROOT_PATH}/SwiftSample/AirshipConfig.plist.sample ${ROOT_PATH}/SwiftSample/AirshipConfig.plist || true

# Use Debug configurations and a simulator SDK so the build process doesn't attempt to sign the output
xcrun xcodebuild -project "${ROOT_PATH}/Sample/Sample.xcodeproj" -derivedDataPath "${DERIVED_DATA}" -scheme Sample -configuration Debug -sdk $TARGET_SDK -destination "${TEST_DESTINATION}"
xcrun xcodebuild -project "${ROOT_PATH}/SwiftSample/SwiftSample.xcodeproj" -derivedDataPath "${DERIVED_DATA}" -scheme SwiftSample -configuration Debug -sdk $TARGET_SDK  -destination "${TEST_DESTINATION}"

##################################################################################################
# Run the Tests!
##################################################################################################

pod install --project-directory=$ROOT_PATH

rm -rf "${ROOT_PATH}/test-output"
mkdir -p "${ROOT_PATH}/test-output"

# Run our Logic Tests
retryNumber=0

xcrun xcodebuild -destination "${TEST_DESTINATION}" -workspace "${ROOT_PATH}/Airship.xcworkspace" -derivedDataPath "${DERIVED_DATA}" -scheme AirshipKitTests build-for-testing 2>&1 | tee "${ROOT_PATH}/test-output/XCTEST-LOGIC.out"
while [ 1 ]
do
    if [ $retryNumber -lt $MAX_TEST_RETRIES ]
    then
        # except for the last retry, don't fail the job if the test fails
        set +e
    fi
    xcrun xcodebuild -destination "${TEST_DESTINATION}" -workspace "${ROOT_PATH}/Airship.xcworkspace" -derivedDataPath "${DERIVED_DATA}" -scheme AirshipKitTests test | tee -a "${ROOT_PATH}/test-output/XCTEST-LOGIC.out"
    testResult=$?
    echo "Logic test result = $testResult"
    set -e

    # if the tests passed or we've retried enough times, exit retry loop
    if [ $testResult -eq 0 -o $retryNumber -gt $MAX_TEST_RETRIES ]
    then
        break
    fi
    
    # wait before trying again
    sleep $SECONDS_TO_WAIT_BEFORE_RETRY

    retryNumber=$((retryNumber+1))
done

# Run pod lib lint
cd $ROOT_PATH
pod lib lint
cd -

# delete derived data
rm -rf "${DERIVED_DATA}"

end_time=`date +%s`
echo execution time was `expr $end_time - $start_time` s.

