#!/bin/bash

set -o pipefail
set -e

SCRIPT_DIRECTORY=`dirname "$0"`
ROOT_PATH=`dirname "${0}"`/../

# Target iOS SDK when building the projects
TARGET_SDK='iphonesimulator'
TEST_DESTINATION='platform=iOS Simulator,OS=latest,name=iPhone SE'

# Set a derived data path for all scheme-based builds (for tests)
DERIVED_DATA=$(mktemp -d /tmp/ci-derived-data-XXXXX)

start_time=`date +%s`

MODE="all"

TESTS=false
SAMPLES=false
POD_LINT=false
FULL_SDK_BUILD=false

# Parse arguments
OPTS=`getopt hm: $*`
if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi
eval set -- "$OPTS"

while true; do
  case "$1" in
    -h  ) echo -ne "-m to set the mode. \n  Available modes: all, merge, pr. Defaults to all. \n"; exit 0;;
    -m  ) MODE=$2; shift;;
    --  ) ;;
    *   ) break ;;
  esac
  shift
done

# Enable steps based on mode
shopt -s nocasematch
case $MODE in
  all   ) FULL_SDK_BUILD=true;SAMPLES=true;TESTS=true;POD_LINT=true;;
  merge ) FULL_SDK_BUILD=true;SAMPLES=true;POD_LINT=true;;
  pr    ) TESTS=true;;
  *   ) echo "invalid mode"; exit 1;;
esac
shopt -u nocasematch

echo -ne "Runnig CI tasks in mode:${MODE} \n\n";


##################################################################################################
# Build SDK
##################################################################################################
echo -ne "\n\n *********** BUILDING SDK *********** \n\n"

if [ $FULL_SDK_BUILD = true ]
then
  # Build all
  ./${SCRIPT_DIRECTORY}/build.sh -a
else
  # Only the framework
  ./${SCRIPT_DIRECTORY}/build.sh -f
fi

##################################################################################################
# Build All Sample Projects
##################################################################################################

if [ $SAMPLES = true ]
then
  echo -ne "\n\n *********** BUILDING SAMPLES *********** \n\n"

  # Make sure AirshipConfig.plist exists
  cp -np ${ROOT_PATH}/Sample/AirshipConfig.plist.sample ${ROOT_PATH}/Sample/AirshipConfig.plist || true
  cp -np ${ROOT_PATH}/SwiftSample/AirshipConfig.plist.sample ${ROOT_PATH}/SwiftSample/AirshipConfig.plist || true

  # Use Debug configurations and a simulator SDK so the build process doesn't attempt to sign the output
  xcrun xcodebuild -project "${ROOT_PATH}/Sample/Sample.xcodeproj" -derivedDataPath "${DERIVED_DATA}" -scheme Sample -configuration Debug -sdk $TARGET_SDK -destination "${TEST_DESTINATION}"
  xcrun xcodebuild -project "${ROOT_PATH}/SwiftSample/SwiftSample.xcodeproj" -derivedDataPath "${DERIVED_DATA}" -scheme SwiftSample -configuration Debug -sdk $TARGET_SDK  -destination "${TEST_DESTINATION}"
fi

##################################################################################################
# Tests
##################################################################################################

if [ $TESTS = true ]
then
  echo -ne "\n\n *********** RUNNING TESTS *********** \n\n"
  pod install --project-directory=$ROOT_PATH

  rm -rf "${ROOT_PATH}/test-output"
  mkdir -p "${ROOT_PATH}/test-output"

  # Run our Logic Tests
  xcrun xcodebuild -destination "${TEST_DESTINATION}" -workspace "${ROOT_PATH}/Airship.xcworkspace" -derivedDataPath "${DERIVED_DATA}" -scheme AirshipKitTests test | tee "${ROOT_PATH}/test-output/XCTEST-LOGIC.out"
fi

##################################################################################################
# POD LINT
##################################################################################################

if [ $POD_LINT = true ]
then
  echo -ne "\n\n *********** RUNNING POD LINT *********** \n\n"

  # Run pod lib lint
  cd $ROOT_PATH
  pod lib lint
  cd -
fi

end_time=`date +%s`
echo execution time was `expr $end_time - $start_time` s.

GREEN='\033[0;32m'
NC='\033[0m' # No Color
printf "\n${GREEN}*** CI TASKS COMPLETED SUCCESSFULLY ***${NC}\n\n"
