#!/bin/bash
#
# run_ci_tasks.sh [MODE] [XCODE_PATH]
#  - MODE: Which tests to run. Must be one of - all, tests, or pod_lint. Defaults to all.
#  - XCODE_PATH: Used to override the Xcode version. Defaults to the version in config.sh.


set -o pipefail
set -e
set -x

ROOT_PATH=`dirname "${0}"`/..
AIRSHIP_VERSION=$(bash "$ROOT_PATH/scripts/airship_version.sh")

source "$ROOT_PATH/scripts/config.sh"

DEVELOPER_DIR=$(bash "$ROOT_PATH/scripts/get_xcode_path.sh" $2)

# Target iOS SDK when building the projects
TARGET_SDK='iphonesimulator'
TARGET_SDK_TVOS='appletvsimulator'

start_time=`date +%s`

TESTS=false
SAMPLES=false
POD_LINT=false

if [ -z $1 ]; then
  MODE="all"
else
  MODE=$1
fi

# Enable steps based on mode
shopt -s nocasematch
case $MODE in
  all       ) SAMPLES=true;TESTS=true;POD_LINT=true;;
  tests     ) TESTS=true;;
  pod_lint  ) POD_LINT=true;;
  samples   ) SAMPLES=true;;
  *         ) echo "invalid mode $MODE"; exit 1;;
esac
shopt -u nocasematch

echo -ne "Running CI tasks in mode:${MODE} \n\n";

bash $ROOT_PATH/scripts/install_pods.sh

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
  -scheme AirshipTests \
  test

  # Run AirshipAccengage Tests
  xcrun xcodebuild \
  -destination "${TEST_DESTINATION}" \
  -workspace "${ROOT_PATH}/Airship.xcworkspace" \
  -scheme AirshipAccengageTests \
  test

  #   # Run AirshipLocationKitTest Tests
  # xcrun xcodebuild \
  # -destination "${TEST_DESTINATION}" \
  # -workspace "${ROOT_PATH}/Airship.xcworkspace" \
  # -scheme AirshipLocationKitTests \
  # test
fi

##################################################################################################
# Build All Sample Projects
##################################################################################################

if [ $SAMPLES = true ]
then
  echo -ne "\n\n *********** BUILDING SAMPLES *********** \n\n"

  # Make sure AirshipConfig.plist exists
  cp -np "${ROOT_PATH}/Sample/AirshipConfig.plist.sample" "${ROOT_PATH}/Sample/AirshipConfig.plist" || true
  cp -np "${ROOT_PATH}/SwiftSample/AirshipConfig.plist.sample" "${ROOT_PATH}/SwiftSample/AirshipConfig.plist" || true
  cp -np "${ROOT_PATH}/tvOSSample/AirshipConfig.plist.sample" "${ROOT_PATH}/tvOSSample/AirshipConfig.plist" || true

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
  cd "$ROOT_PATH"
  bundle exec pod lib lint Airship.podspec
  bundle exec pod lib lint AirshipExtensions.podspec
  cd -
fi

end_time=`date +%s`
echo execution time was `expr $end_time - $start_time` s.

GREEN='\033[0;32m'
NC='\033[0m' # No Color
printf "\n${GREEN}*** CI TASKS COMPLETED SUCCESSFULLY ***${NC}\n\n"
