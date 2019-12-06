#!/bin/bash

set -o pipefail
set -e
set -x

SCRIPT_DIRECTORY=`dirname "$0"`
ROOT_PATH=`dirname "${0}"`/../
LATEST='13.0'

# Target iOS SDK when building the projects
TARGET_SDK='iphonesimulator'
TARGET_SDK_TVOS='appletvsimulator'

TEST_DESTINATION='platform=iOS Simulator,OS=latest,name=iPhone 11'
TEST_DESTINATION_TVOS='platform=tvOS Simulator,OS=latest,name=Apple TV'

start_time=`date +%s`

MODE="all"

TESTS=false
SAMPLES=false
POD_LINT=false
BUILD_SDK=false

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
  all       ) BUILD_SDK=true;SAMPLES=true;TESTS=true;POD_LINT=true;;
  merge     ) BUILD_SDK=true;SAMPLES=true;POD_LINT=true;;
  pr        ) BUILD_SDK=true;TESTS=true;;
  tests     ) TESTS=true;;
  pod_lint  ) POD_LINT=true;;
  samples   ) SAMPLES=true;;
  *         ) echo "invalid mode"; exit 1;;
esac
shopt -u nocasematch

echo -ne "Running CI tasks in mode:${MODE} \n\n";

pod update --project-directory=$ROOT_PATH
pod install --project-directory=$ROOT_PATH

##################################################################################################
# Tests
##################################################################################################

if [ $TESTS = true ]
then

  echo -ne "\n\n *********** RUNNING TESTS *********** \n\n"

  # Run AirshipCore Tests
  xcrun xcodebuild \
  -destination "${TEST_DESTINATION}" \
  -workspace "${ROOT_PATH}/Airship.xcworkspace" \
  -scheme AirshipCoreTests \
  test

  #   # Run AirshipLocationKitTest Tests
  # xcrun xcodebuild \
  # -destination "${TEST_DESTINATION}" \
  # -workspace "${ROOT_PATH}/Airship.xcworkspace" \
  # -scheme AirshipLocationKitTests \
  # test
fi

##################################################################################################
# Build SDK
##################################################################################################

if [ $BUILD_SDK = true ]
then
  ./${SCRIPT_DIRECTORY}/build.sh
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
  cp -np ${ROOT_PATH}/tvOSSample/AirshipConfig.plist.sample ${ROOT_PATH}/tvOSSample/AirshipConfig.plist || true

  # Use Debug configurations and a simulator SDK so the build process doesn't attempt to sign the output

  echo -ne "\n\n *********** BUILDING Sample *********** \n\n"


  xcrun xcodebuild \
  -configuration Debug \
  -workspace "${ROOT_PATH}/Airship.xcworkspace" \
  -scheme Sample \
  -sdk $TARGET_SDK \
  -destination "${TEST_DESTINATION}"

  echo -ne "\n\n *********** BUILDING SwiftSample *********** \n\n"

  xcrun xcodebuild \
  -configuration Debug \
  -workspace "${ROOT_PATH}/Airship.xcworkspace" \
  -scheme SwiftSample \
  -sdk $TARGET_SDK  \
  -destination "${TEST_DESTINATION}"

  echo -ne "\n\n *********** BUILDING tvOSSample *********** \n\n"

  xcrun xcodebuild \
  -configuration Debug \
  -workspace "${ROOT_PATH}/Airship.xcworkspace" \
  -scheme tvOSSample \
  -sdk $TARGET_SDK_TVOS  \
  -destination "${TEST_DESTINATION_TVOS}"
fi

##################################################################################################
# POD LINT
##################################################################################################

if [ $POD_LINT = true ]
then
  echo -ne "\n\n *********** RUNNING POD LINT *********** \n\n"

  # Run pod lib lint
  cd $ROOT_PATH
  pod lib lint Airship.podspec
  pod lib lint AirshipExtensions.podspec
  cd -
fi

end_time=`date +%s`
echo execution time was `expr $end_time - $start_time` s.

GREEN='\033[0;32m'
NC='\033[0m' # No Color
printf "\n${GREEN}*** CI TASKS COMPLETED SUCCESSFULLY ***${NC}\n\n"
