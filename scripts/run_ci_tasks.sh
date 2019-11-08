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
  all       ) FULL_SDK_BUILD=true;SAMPLES=true;TESTS=true;POD_LINT=true;;
  merge     ) FULL_SDK_BUILD=true;SAMPLES=true;POD_LINT=true;;
  pr        ) TESTS=true;;
  tests     ) TESTS=true;;
  pod_lint  ) POD_LINT=true;;
  samples   ) SAMPLES=true;;
  *         ) echo "invalid mode"; exit 1;;
esac
shopt -u nocasematch

echo -ne "Running CI tasks in mode:${MODE} \n\n";


##################################################################################################
# Tests
##################################################################################################

if [ $TESTS = true ]
then
  set +e
  pod install --project-directory=$ROOT_PATH
  if [ $? != 0 ]; then
    # Cocoapods failed. Try updating the repo and then installing again
    set -e
    pod repo update
    pod install --project-directory=$ROOT_PATH
  else
    set -e
  fi
  echo -ne "\n\n *********** RUNNING TESTS *********** \n\n"

  # Run AirshipKitTest Tests
  xcrun xcodebuild \
  -destination "${TEST_DESTINATION}" \
  -workspace "${ROOT_PATH}/Airship.xcworkspace" \
  -scheme AirshipKitTests \
  test

    # Run AirshipLocationKitTest Tests
  xcrun xcodebuild \
  -destination "${TEST_DESTINATION}" \
  -workspace "${ROOT_PATH}/Airship.xcworkspace" \
  -scheme AirshipLocationKitTests \
  test
fi

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
  cp -np ${ROOT_PATH}/tvOSSample/AirshipConfig.plist.sample ${ROOT_PATH}/tvOSSample/AirshipConfig.plist || true

  # Use Debug configurations and a simulator SDK so the build process doesn't attempt to sign the output
  xcrun xcodebuild \
  -configuration Debug \
  -project "${ROOT_PATH}/Sample/Sample.xcodeproj" \
  -scheme Sample \
  -sdk $TARGET_SDK \
  -destination "${TEST_DESTINATION}"

  xcrun xcodebuild \
  -configuration Debug \
  -project "${ROOT_PATH}/SwiftSample/SwiftSample.xcodeproj" \
  -scheme SwiftSample \
  -sdk $TARGET_SDK  \
  -destination "${TEST_DESTINATION}"

  xcrun xcodebuild \
  -configuration Debug \
  -project "${ROOT_PATH}/tvOSSample/tvOSSample.xcodeproj" \
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
